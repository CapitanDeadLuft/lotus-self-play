local sniper = {}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local awareness = require("self_play.awareness")
local intent = require("self_play.intent")

sniper.reserved = {sniper_shrapnel = true, sniper_assassinate = true, sniper_take_aim = true,
	sniper_take_aim_stop = true, sniper_concussive_grenade = true}
sniper.preAttack = {sniper_take_aim = true}

local function available(ctx, api, name)
	local ability = NPC.GetAbility(ctx.hero, name)
	return ability and (ctx.abilityAttempts[name] or 0) <= ctx.now and api.ready(ctx, ability, false) and ability or nil
end

local function protected(enemy)
	return NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
end

function sniper.covered(ctx, point, radius)
	local zones = ctx.heroState.shrapnelZones or {}
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if ctx.now >= zone.expires then table.remove(zones, index)
		elseif ctx.distance(point, zone.position) < math.min(radius, zone.radius) * 1.15 then return true end
	end
	return false
end

function sniper.scenarios(ctx, enemy, delay)
	local now = Entity.GetAbsOrigin(enemy)
	local predicted = ctx.predict(enemy, delay)
	local span = math.max(0.3, delay)
	local vx, vy = (predicted.x - now.x) / span, (predicted.y - now.y) / span
	local moving = math.sqrt(vx * vx + vy * vy)
	local record = ctx.history and ctx.history[Entity.GetIndex(enemy)]
	local steady = record and record.steady or 0
	local speed = math.max(200, NPC.GetMoveSpeed(enemy))
	local list = {}
	local continueWeight = moving > 60 and 0.3 + 0.4 * math.min(1, steady / 1.5) or 0
	list[#list + 1] = {weight = moving > 60 and 0.25 or 0.55, vx = 0, vy = 0}
	if continueWeight > 0 then list[#list + 1] = {weight = continueWeight, vx = vx, vy = vy} end
	if ctx.enemyHome then
		local dx, dy = ctx.enemyHome.x - now.x, ctx.enemyHome.y - now.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		local chased = ctx.intent and ctx.intent.target == enemy
		list[#list + 1] = {weight = chased and 0.35 or 0.2, vx = dx / length * speed, vy = dy / length * speed}
	end
	list[#list + 1] = {weight = 0.25, dodge = true, speed = speed}
	local total = 0
	for _, scenario in ipairs(list) do total = total + scenario.weight end
	for _, scenario in ipairs(list) do scenario.weight = scenario.weight / total end
	return list, now
end

function sniper.dwell(ctx, point, scenario, origin, delay, radius, slow)
	local inside, x, y = 0, origin.x, origin.y
	local reach = radius * 0.9
	local step = 0.25
	local t = 0
	while t < delay + 3 do
		local vx, vy = scenario.vx or 0, scenario.vy or 0
		if scenario.dodge then
			if t < 0.8 then vx, vy = 0, 0
			else
				local dx, dy = x - point.x, y - point.y
				local length = math.sqrt(dx * dx + dy * dy)
				if length < 1 then dx, dy, length = 1, 0, 1 end
				vx, vy = dx / length * scenario.speed, dy / length * scenario.speed
			end
		end
		local gap = math.sqrt((x - point.x) ^ 2 + (y - point.y) ^ 2)
		local factor = (t >= delay and gap <= reach) and (1 - slow) or 1
		if t >= delay and gap <= reach then inside = inside + step end
		x, y, t = x + vx * step * factor, y + vy * step * factor, t + step
	end
	return inside
end

function sniper.shrapnelPoint(ctx, enemy, delay, radius, castRange, slow)
	local scenarios, origin = sniper.scenarios(ctx, enemy, delay)
	local candidates = {origin}
	for _, scenario in ipairs(scenarios) do
		if not scenario.dodge then
			for _, t in ipairs({delay * 0.5, delay, delay + 0.8, delay + 1.6}) do
				candidates[#candidates + 1] = Vector(origin.x + scenario.vx * t, origin.y + scenario.vy * t, origin.z)
			end
		end
	end
	local count = #candidates
	for i = 2, count do
		local a = candidates[i]
		candidates[#candidates + 1] = Vector((a.x + origin.x) * 0.5, (a.y + origin.y) * 0.5, origin.z)
	end
	local others = {}
	for _, other in ipairs(ctx.enemies or {}) do
		if other ~= enemy and common.visible(other) and not NPC.IsIllusion(other) and ctx.distance(Entity.GetAbsOrigin(other), origin) < radius * 2.5 then
			others[#others + 1] = Entity.GetAbsOrigin(other)
		end
	end
	local best, bestScore
	for _, candidate in ipairs(candidates) do
		if ctx.distance(ctx.position, candidate) <= castRange and GridNav.IsTraversable(candidate) then
			local score = 0
			for _, scenario in ipairs(scenarios) do score = score + scenario.weight * sniper.dwell(ctx, candidate, scenario, origin, delay, radius, slow) end
			for _, position in ipairs(others) do
				if ctx.distance(position, candidate) <= radius * 0.9 then score = score + 0.8 end
			end
			if not bestScore or score > bestScore + 0.01 then best, bestScore = candidate, score end
		end
	end
	return best, bestScore or 0
end

function sniper.urgent(ctx)
	local ability = NPC.GetAbility(ctx.hero, "sniper_assassinate")
	if not ability or Ability.GetLevel(ability) < 1 or not Ability.IsReady(ability) or not Ability.IsCastable(ability, NPC.GetMana(ctx.hero)) then return false end
	local base = math.max(common.value(ability, "damage", 0), Ability.GetDamage(ability) or 0)
	for _, enemy in ipairs(ctx.enemies or {}) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy) and not protected(enemy)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= Ability.GetCastRange(ability)
			and Entity.GetHealth(enemy) + 15 < base * NPC.GetMagicalArmorDamageMultiplier(enemy) then return true end
	end
	return false
end

function sniper.assassinate(ctx, api)
	local ability = available(ctx, api, "sniper_assassinate")
	if not ability or ctx.retreating or ctx.hardRetreat then return false end
	local point = Ability.GetCastPoint(ability)
	local threat = awareness.damage(ctx, ctx.position, point + 0.4) + awareness.forecast(ctx, ctx.position)
	if threat > Entity.GetHealth(ctx.hero) * 0.35 then return false end
	local best, bestHealth
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy) and not protected(enemy) and api.allowed(ctx, ability, enemy)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= Ability.GetCastRange(ability) then
			local delay = point + ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) / common.value(ability, "projectile_speed", 2500)
			local damage = math.max(common.value(ability, "damage", 0), Ability.GetDamage(ability) or 0) * NPC.GetMagicalArmorDamageMultiplier(enemy)
			local barriers = NPC.GetBarriers(enemy)
			local health = Entity.GetHealth(enemy) + math.max(0, NPC.GetHealthRegen(enemy)) * delay + 15
			if barriers then health = health + (barriers.magical and barriers.magical.current or 0) + (barriers.all and barriers.all.current or 0) end
			local secured = 0
			for _, shot in pairs(ctx.projectiles or {}) do
				if shot.target == enemy and shot.impact > ctx.now and shot.impact < ctx.now + delay then secured = secured + shot.damage end
			end
			if damage >= health and secured < Entity.GetHealth(enemy) and (not bestHealth or health < bestHealth) then best, bestHealth = enemy, health
			elseif Entity.GetHealth(enemy) < damage * 1.6 and ctx.now >= (ctx.heroState.nextAssassinateNote or 0) then
				ctx.heroState.nextAssassinateNote = ctx.now + 3
				ctx.heroState.aimNote = string.format("Assassinate skip %s: damage %.0f vs effective HP %.0f (secured %.0f, threat %.0f)",
					(NPC.GetUnitName(enemy) or "?"):gsub("npc_dota_hero_", ""), damage, health, secured, threat)
			end
		end
	end
	if best then
		ctx.heroState.aimNote = string.format("Assassinate %s at %.0f HP", (NPC.GetUnitName(best) or "?"):gsub("npc_dota_hero_", ""), Entity.GetHealth(best))
		return tactics.cast(ctx, api, "sniper_assassinate", "target", best)
	end
	return false
end

function sniper.update(ctx, api, retreat)
	if api.busy(ctx) then return false end
	local enemy = tactics.enemy(ctx, 1800)
	local stop = available(ctx, api, "sniper_take_aim_stop")
	if stop and (retreat or enemy and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 450) then return api.cast(ctx, stop, "none") end
	if not enemy and sniper.assassinate(ctx, api) then return true end
	if not enemy or protected(enemy) then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	local grenade = available(ctx, api, "sniper_concussive_grenade")
	if grenade and distance < 350 and (retreat or ctx.laneThreat and ctx.laneThreat.attacked)
		and not ctx.unsafePosition(ctx.toward(ctx.position, ctx.home, 450)) then
		return tactics.cast(ctx, api, "sniper_concussive_grenade", "point", enemy, Entity.GetAbsOrigin(enemy))
	end
	if sniper.assassinate(ctx, api) then return true end
	local committed = retreat or tactics.committed(ctx, enemy)
	local shrapnel = available(ctx, api, "sniper_shrapnel")
	if committed and shrapnel and ctx.now >= (ctx.heroState.nextShrapnel or 0)
		and NPC.GetMana(ctx.hero) - Ability.GetManaCost(shrapnel) >= NPC.GetMaxMana(ctx.hero) * (ctx.settings.manaReserve or 22) / 100 then
		local delay = Ability.GetCastPoint(shrapnel) + common.value(shrapnel, "damage_delay", 1.2)
		local radius = common.value(shrapnel, "radius", 400)
		local slow = math.min(0.6, common.value(shrapnel, "slow_movement_speed", 15) / 100)
		local castRange = Ability.GetCastRange(shrapnel) > 0 and Ability.GetCastRange(shrapnel) or 1800
		local point, score = sniper.shrapnelPoint(ctx, enemy, delay, radius, castRange, math.abs(slow))
		if retreat and point then point = ctx.toward(point, ctx.position, radius * 0.3) end
		ctx.heroState.shrapnelScore = score
		if point and score >= (retreat and 0.6 or 1.0) and not sniper.covered(ctx, point, radius)
			and not NPC.HasModifier(enemy, "modifier_sniper_shrapnel_slow") then
			local acted, casted = tactics.cast(ctx, api, "sniper_shrapnel", "point", enemy, point)
			if casted then
				ctx.heroState.shrapnelZones = ctx.heroState.shrapnelZones or {}
				ctx.heroState.shrapnelZones[#ctx.heroState.shrapnelZones + 1] = {position = point, radius = radius,
					expires = ctx.now + delay + common.value(shrapnel, "duration", 10)}
				ctx.heroState.nextShrapnel = ctx.now + math.max(3, delay + 1)
			end
			if acted then return true end
		end
	end
	local aim = available(ctx, api, "sniper_take_aim")
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	if not retreat and aim and not ctx.unsafePosition(ctx.position) then
		local bonus = common.value(aim, "active_attack_range_bonus", 75)
		local closest = math.huge
		for _, other in ipairs(ctx.enemies) do
			if common.visible(other) and not NPC.IsIllusion(other) then closest = math.min(closest, ctx.distance(ctx.position, Entity.GetAbsOrigin(other))) end
		end
		local decision = ctx.combatDecision
		local nearKill = decision and decision.target == enemy and (decision.killTime or math.huge) < 5
		local trade = ctx.tradeSafe and not (ctx.laneThreat and (ctx.laneThreat.attacked or ctx.laneThreat.avoid))
		local record = ctx.history and ctx.history[Entity.GetIndex(enemy)]
		local away = 0
		if record and record.vx and NPC.IsRunning(enemy) then
			local position = Entity.GetAbsOrigin(enemy)
			away = ((position.x - ctx.position.x) * record.vx + (position.y - ctx.position.y) * record.vy) / math.max(1, distance)
		end
		local reach = away > 120 and range - 50 or range + bonus - 80
		if (committed or nearKill or trade) and distance > 400 and closest > 400 and distance <= reach
			and ctx.health > 0.4 and awareness.damage(ctx, ctx.position, 2) < Entity.GetHealth(ctx.hero) * 0.35 then
			ctx.heroState.aimNote = string.format("Take Aim: %s at %.0f (range %.0f+%.0f, moving away %.0f)", committed and "fight" or nearKill and "near kill" or "lane trade", distance, range, bonus, away)
			local acted, casted = tactics.cast(ctx, api, "sniper_take_aim", "none", enemy)
			if casted and not ctx.parent then
				intent.begin(ctx, enemy, "hero", false)
				if ctx.intent then ctx.intent.expires = math.max(ctx.intent.expires or 0, ctx.now + 3) end
			end
			return acted
		end
	end
	return false
end

return sniper
