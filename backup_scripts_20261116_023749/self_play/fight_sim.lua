local sim = {}
local awareness = require("self_play.awareness")
local brain = require("self_play.brain")

local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local hardControl = {"stun", "hex", "sheep", "sleep", "fear", "taunt", "cyclone", "frozen", "petrif"}
local partialControl = {"root", "ensnare", "entangle", "leash"}
local controlCache = {}

local function kvNumber(value, level)
	if type(value) == "table" then value = value.value end
	if type(value) == "number" then return value end
	if type(value) ~= "string" then return 0 end
	local result, index = 0, 0
	for number in value:gmatch("%-?%d+%.?%d*") do
		index, result = index + 1, tonumber(number)
		if index >= math.max(1, level) then break end
	end
	return result
end

local function matches(key, words)
	for _, word in ipairs(words) do if key:find(word, 1, true) then return true end end
	return false
end

function sim.controlSeconds(name, level, isItem, flagged)
	local cacheKey = name .. ":" .. level
	local cached = controlCache[cacheKey]
	if cached then return cached end
	local kv = (isItem and itemKV or abilityKV)[name]
	local values = kv and kv.AbilityValues
	local best = 0
	if type(values) == "table" then
		local generic = 0
		for key, raw in pairs(values) do
			local lower = string.lower(tostring(key))
			if lower:find("duration", 1, true) and not lower:find("tooltip", 1, true) then
				local seconds = kvNumber(raw, level)
				if matches(lower, hardControl) then best = math.max(best, seconds)
				elseif matches(lower, partialControl) then best = math.max(best, seconds * 0.35)
				elseif lower == "duration" then generic = seconds end
			end
		end
		if best == 0 and flagged then best = math.min(2.5, generic) end
	end
	best = math.max(0, math.min(5, best))
	controlCache[cacheKey] = best
	return best
end

local function clone(unit)
	local copy = {}
	for key, value in pairs(unit) do copy[key] = value end
	return copy
end

local function opponents(units, side)
	local result = {}
	for _, unit in ipairs(units) do
		if unit.side ~= side and not unit.structure then result[#result + 1] = unit end
	end
	return result
end

local function effectiveHealth(unit, magical)
	return unit.hp / math.max(0.05, magical and unit.magicMult or unit.armorMult)
end

local function reach(attacker, unit)
	if not attacker.position or not unit.position then return 0 end
	local dx, dy = attacker.position.x - unit.position.x, attacker.position.y - unit.position.y
	local distance = math.sqrt(dx * dx + dy * dy)
	return math.max(0, distance - (attacker.range or 0) - 50) / math.max(100, attacker.speed or 300)
end

local function pickTarget(attacker, candidates, time)
	local current = attacker.target
	if current and current.hp > 0 and current.arrival <= time + 0.5 and not current.untargetable then return current end
	local best, bestScore, bestReach
	for _, unit in ipairs(candidates) do
		if unit.hp > 0 and unit.arrival <= time + 0.5 and not unit.untargetable then
			local seconds = effectiveHealth(unit, false) / math.max(1, attacker.dps)
			local walk = reach(attacker, unit)
			local score = seconds / math.max(0.3, unit.value) + walk * 2.5 - (unit.focus and attacker.side == "ally" and 6 or 0)
			if not bestScore or score < bestScore then best, bestScore, bestReach = unit, score, walk end
		end
	end
	if best and best ~= current then
		attacker.walkUntil = current and time + (bestReach or 0) or math.max(attacker.arrival, bestReach or 0)
		if attacker.position and best.position then
			local dx, dy = best.position.x - attacker.position.x, best.position.y - attacker.position.y
			local distance = math.sqrt(dx * dx + dy * dy)
			local keep = math.min(distance, (attacker.range or 0) + 50)
			local fraction = distance > 1 and (distance - keep) / distance or 0
			attacker.pending = {x = attacker.position.x + dx * fraction, y = attacker.position.y + dy * fraction}
		end
	end
	attacker.target = best
	return best
end

local function controlTarget(candidates, time)
	local best, bestScore
	for _, unit in ipairs(candidates) do
		if unit.hp > 0 and unit.arrival <= time + 0.5 and time >= unit.stunnedUntil and time >= unit.immuneUntil then
			local score = (unit.dps + unit.burst / 3) * unit.value
			if not bestScore or score > bestScore then best, bestScore = unit, score end
		end
	end
	return best
end

function sim.run(input, options)
	options = options or {}
	local horizon, step = options.horizon or 8, options.step or 0.1
	local units = {}
	for _, unit in ipairs(input) do
		local copy = clone(unit)
		copy.maxHp = math.max(1, copy.maxHp or copy.hp)
		copy.hp = math.max(0, copy.hp)
		copy.dps, copy.burst, copy.regen = copy.dps or 0, copy.burst or 0, copy.regen or 0
		copy.armorMult, copy.magicMult = copy.armorMult or 1, copy.magicMult or 1
		copy.arrival, copy.value = math.max(0, copy.arrival or 0), copy.value or 1
		copy.stunnedUntil, copy.immuneUntil = copy.stunnedUntil or 0, copy.immuneUntil or 0
		copy.burstAt, copy.disableAt = copy.burstAt or 0, copy.disableAt or 0
		copy.disable, copy.burstRef = copy.disable or 0, copy.burstRef or 1
		copy.startHp = copy.hp
		units[#units + 1] = copy
	end
	local lists = {ally = opponents(units, "ally"), enemy = opponents(units, "enemy")}
	local time = 0
	while time < horizon do
		time = time + step
		local alive = {ally = false, enemy = false}
		for _, unit in ipairs(units) do
			if unit.hp > 0 and not unit.structure then alive[unit.side] = true end
		end
		if not alive.ally or not alive.enemy then break end
		local damage = {}
		for _, unit in ipairs(units) do
			if unit.hp > 0 and time >= unit.arrival and time >= unit.stunnedUntil then
				local foes = lists[unit.side]
				if unit.disable > 0 and not unit.disableUsed and time >= unit.arrival + unit.disableAt then
					local victim = controlTarget(foes, time)
					if victim then
						victim.stunnedUntil = math.max(victim.stunnedUntil, time) + unit.disable
						unit.disableUsed = true
					end
				end
				local target = pickTarget(unit, foes, time)
				if unit.pending and time >= (unit.walkUntil or 0) then unit.position, unit.pending = unit.pending, nil end
				if target and time >= target.arrival and time >= (unit.walkUntil or 0) then
					local amount = unit.dps * step * target.armorMult
					if unit.burst > 0 and not unit.burstUsed and time >= unit.arrival + unit.burstAt then
						unit.burstUsed = true
						if time >= target.immuneUntil then amount = amount + unit.burst * target.magicMult / math.max(0.05, unit.burstRef) end
					end
					damage[target] = (damage[target] or 0) + amount
				end
			end
		end
		for _, unit in ipairs(units) do
			if unit.hp > 0 and not unit.structure then
				unit.hp = math.min(unit.maxHp, unit.hp + unit.regen * step) - (damage[unit] or 0)
				if unit.hp <= 0 then unit.hp, unit.deathTime = 0, time end
			end
		end
	end
	local result = {allyLoss = 0, enemyLoss = 0, allyValue = 0, enemyValue = 0, allyDeaths = 0, enemyDeaths = 0,
		duration = time, selfDead = false, selfHp = nil, targetDead = false}
	for _, unit in ipairs(units) do
		if not unit.structure then
			local loss = unit.hp <= 0 and unit.value or unit.value * 0.5 * math.max(0, unit.startHp - unit.hp) / unit.maxHp
			if unit.side == "ally" then
				result.allyLoss, result.allyValue = result.allyLoss + loss, result.allyValue + unit.value
				if unit.hp <= 0 then result.allyDeaths = result.allyDeaths + 1 end
			else
				result.enemyLoss, result.enemyValue = result.enemyLoss + loss, result.enemyValue + unit.value
				if unit.hp <= 0 then result.enemyDeaths = result.enemyDeaths + 1 end
			end
			if unit.self then
				result.selfDead, result.selfHp, result.selfDeathTime = unit.hp <= 0, unit.hp, unit.deathTime
				result.selfFraction = unit.hp / unit.maxHp
			end
			if unit.focus then
				result.targetDead, result.targetDeathTime = unit.hp <= 0, unit.deathTime
				result.targetFraction = unit.hp / math.max(1, unit.maxHp)
			end
		end
	end
	local allyFraction = result.allyLoss / math.max(0.01, result.allyValue)
	local enemyFraction = result.enemyLoss / math.max(0.01, result.enemyValue)
	result.margin = enemyFraction - allyFraction
	result.allyFraction, result.enemyFraction = allyFraction, enemyFraction
	if result.enemyDeaths ~= result.allyDeaths then
		result.favorable = result.enemyDeaths > result.allyDeaths
	else
		local edge = options.edge or 1.3
		result.favorable = result.enemyValue > 0 and enemyFraction >= math.max(allyFraction * edge, allyFraction + 0.04 * edge)
	end
	return result
end

local function alive(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function visible(unit)
	return alive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function modifierRemaining(ctx, unit, name, fallback)
	local modifier = NPC.GetModifier(unit, name)
	if not modifier then return fallback end
	return math.max(0, Modifier.GetDieTime(modifier) - ctx.now)
end

local function controlKit(ctx, unit, distance)
	local total, castAt = 0, nil
	local mana = NPC.GetMana(unit)
	local silenced = NPC.IsSilenced(unit)
	local muted = NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MUTED)
	local function consider(ability, isItem)
		if not ability or Ability.GetLevel(ability) < 1 or Ability.IsHidden(ability) or Ability.IsPassive(ability) then return end
		if isItem and (muted or not Item.IsItemEnabled(ability)) or not isItem and silenced then return end
		if Ability.GetCooldown(ability) > 1.5 or Ability.GetManaCost(ability) > mana then return end
		local name = Ability.GetName(ability)
		local record = isItem and ctx.catalog.items[name:gsub("^item_", "")]
		local effect = isItem and record and record.effects or ctx.catalog.abilities[name] or {}
		local seconds = sim.controlSeconds(name, Ability.GetLevel(ability), isItem, effect.disable)
		local reach = math.max(Ability.GetCastRange(ability), ctx.planner.levelValue(effect.radius, Ability.GetLevel(ability)), 200)
		if seconds > 0 and distance < reach + 900 then
			mana = mana - Ability.GetManaCost(ability)
			total = total + seconds
			castAt = math.min(castAt or math.huge, Ability.GetCastPoint(ability))
		end
	end
	for index = 0, 23 do consider(NPC.GetAbilityByIndex(unit, index), false) end
	for index = 0, 5 do consider(NPC.GetItemByIndex(unit, index), true) end
	return math.min(6, total), castAt or 0
end

local function immunity(ctx, unit)
	if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
		return modifierRemaining(ctx, unit, "modifier_black_king_bar_immune", 2.5)
	end
	local bkb = NPC.GetItem(unit, "item_black_king_bar", true)
	if bkb and Ability.IsReady(bkb) and Item.IsItemEnabled(bkb) and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MUTED) then
		local values = itemKV.item_black_king_bar and itemKV.item_black_king_bar.AbilityValues
		return values and kvNumber(values.duration, 1) or 6, true
	end
	return 0
end

local function heroValue(unit)
	return 1 + NPC.GetCurrentLevel(unit) * 0.08
end

local function profile(ctx, unit, side, position, center, opponent, extraDelay)
	local range = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit)
	local distance = ctx.distance(position, center)
	local travel = math.max(0, distance - range - 80) / math.max(100, NPC.GetMoveSpeed(unit))
	local control = awareness.control(ctx, unit)
	local stunned = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0)
	local average = (NPC.GetTrueDamage(unit) + NPC.GetTrueMaximumDamage(unit)) * 0.5
	local dps = average / math.max(0.2, NPC.GetSecondsPerAttack(unit, false))
	if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_DISARMED) then
		dps = dps * (1 - math.min(1, math.max(0, control[Enum.ModifierState.MODIFIER_STATE_DISARMED] or 0) / 4))
	end
	local burst = 0
	if opponent and alive(opponent) then burst = awareness.burst(ctx, unit, opponent, math.min(distance, 600), 4) end
	ctx.simKits = ctx.simKits and ctx.simKits.time == ctx.now and ctx.simKits or {time = ctx.now, units = {}}
	local kitKey = Entity.GetIndex(unit) .. ":" .. math.floor(distance / 300) .. ":" .. math.floor(NPC.GetMana(unit))
	local kit = ctx.simKits.units[kitKey]
	if not kit then
		local disable, disableAt = controlKit(ctx, unit, distance)
		local immune, pending = immunity(ctx, unit)
		kit = {disable = disable, disableAt = disableAt, immune = immune, pending = pending}
		ctx.simKits.units[kitKey] = kit
	end
	local disable, disableAt, immune, pending = kit.disable, kit.disableAt, kit.immune, kit.pending
	local arrival = travel + (extraDelay or 0)
	local barriers = NPC.GetBarriers(unit)
	local shield = barriers and barriers.all and barriers.all.current or 0
	return {side = side, unit = unit, hp = Entity.GetHealth(unit) + shield, maxHp = Entity.GetMaxHealth(unit) + shield,
		regen = math.max(0, NPC.GetHealthRegen(unit)), dps = dps, burst = burst, burstAt = 0.3,
		burstRef = opponent and alive(opponent) and NPC.GetMagicalArmorDamageMultiplier(opponent) or 1,
		disable = disable, disableAt = disableAt, armorMult = NPC.GetArmorDamageMultiplier(unit),
		magicMult = NPC.GetMagicalArmorDamageMultiplier(unit), arrival = arrival, stunnedUntil = stunned,
		immuneUntil = pending and arrival + immune or immune, value = heroValue(unit),
		position = position, range = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit), speed = NPC.GetMoveSpeed(unit)}
end

local function towerProfile(ctx, tower, side)
	local dps = NPC.GetTrueDamage(tower) / math.max(0.4, NPC.GetSecondsPerAttack(tower, false))
	return {side = side, unit = tower, structure = true, untargetable = true, hp = 1, maxHp = 1, dps = dps, value = 0}
end

function sim.scene(ctx, center, options)
	options = options or {}
	local radius = options.radius or 1500
	local entries, enemies, seen = {}, {}, {}
	local focus = options.target
	local reference
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsIllusion(enemy) then
			local position = Entity.GetAbsOrigin(enemy)
			if ctx.distance(position, center) < radius then
				enemies[#enemies + 1], seen[enemy] = {unit = enemy, position = position, delay = 0}, true
			end
		end
	end
	for _, entry in pairs(ctx.memory or {}) do
		local enemy = entry.source
		if enemy and not seen[enemy] and alive(enemy) and ctx.now - entry.time < (options.memoryAge or 5) then
			local position = awareness.fogPosition(ctx, enemy) or entry.position
			local age = ctx.now - entry.time
			if ctx.distance(position, center) < radius + age * 120 then
				enemies[#enemies + 1], seen[enemy] = {unit = enemy, position = position, delay = 0.4 + age * 0.15}, true
			end
		end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		local enemy = arrival.source
		if enemy and not seen[enemy] and alive(enemy) and ctx.distance(arrival.position, center) < radius then
			enemies[#enemies + 1], seen[enemy] = {unit = enemy, position = arrival.position, delay = arrival.remaining or 0}, true
		end
	end
	if #enemies == 0 then return nil end
	local allies = {}
	if not options.excludeSelf and Entity.IsAlive(ctx.hero) then
		allies[#allies + 1] = {unit = ctx.hero, position = ctx.position, delay = options.selfDelay or 0, self = true}
	end
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) and not NPC.HasModifier(ally, "modifier_teleporting") then
			local position = Entity.GetAbsOrigin(ally)
			if ctx.distance(position, center) < radius then
				local facing = NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 30,
					NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 200)
				local engaged = facing and NPC.IsHero(facing) or Hero.GetRecentDamage(ally) > 0
				for _, fight in pairs(ctx.allyFights or {}) do
					if fight.ally == ally and ctx.now - fight.time < 2.5 then engaged = true end
				end
				allies[#allies + 1] = {unit = ally, position = position, delay = engaged and 0 or 1}
			end
		end
	end
	local listed = {}
	for _, entry in ipairs(allies) do listed[entry.unit] = true end
	for _, unit in ipairs(ctx.summons or {}) do
		if not listed[unit] and visible(unit) and Entity.IsSameTeam(ctx.hero, unit) and not NPC.IsIllusion(unit)
			and (NPC.IsHero(unit) or NPC.GetTrueDamage(unit) >= 40) then
			local position = Entity.GetAbsOrigin(unit)
			if ctx.distance(position, center) < radius then
				listed[unit] = true
				allies[#allies + 1] = {unit = unit, position = position, delay = 0, summon = true}
			end
		end
	end
	if #allies == 0 then return nil end
	reference = focus and alive(focus) and focus or enemies[1].unit
	local allyReference = allies[1].unit
	for _, entry in ipairs(allies) do
		local record = profile(ctx, entry.unit, "ally", entry.position, center, reference, entry.delay)
		record.self = entry.self
		if entry.summon then record.value = record.value * 0.5 end
		entries[#entries + 1] = record
	end
	for _, entry in ipairs(enemies) do
		local record = profile(ctx, entry.unit, "enemy", entry.position, center, allyReference, entry.delay)
		record.focus = entry.unit == focus
		entries[#entries + 1] = record
	end
	if not options.ignoreTowers then
		for _, tower in ipairs(ctx.towers or {}) do
			if visible(tower) and ctx.distance(Entity.GetAbsOrigin(tower), center) < NPC.GetAttackRange(tower) + 200 then
				entries[#entries + 1] = towerProfile(ctx, tower, Entity.IsSameTeam(ctx.hero, tower) and "ally" or "enemy")
			end
		end
	end
	return entries
end

function sim.evaluate(ctx, center, options)
	options = options or {}
	if ctx.settings and ctx.settings.simulate == false then return nil end
	local ok, entries = pcall(sim.scene, ctx, center, options)
	if not ok then
		ctx.simError = tostring(entries)
		return nil
	end
	if not entries then return nil end
	local aggression = math.max(0, math.min(100, (ctx.settings and ctx.settings.aggression or 50) + brain.aggressionShift(ctx)))
	local horizon = options.horizon or 8 + math.min(10, math.max(0, options.selfDelay or 0))
	local result = sim.run(entries, {horizon = horizon, edge = 1.6 - aggression / 100 * 0.6})
	result.units = #entries
	ctx.lastFightSim = {time = ctx.now, result = result}
	return result
end

return sim
