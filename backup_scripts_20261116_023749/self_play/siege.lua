local siege = {}
local waves = require("self_play.waves")
local coordination = require("self_play.coordination")

siege.values = {tower1 = 900, tower2 = 1200, tower3 = 1800, tower4 = 2000, melee_rax = 2200, range_rax = 1600, fort = 60000}
siege.labels = {tower1 = "T1", tower2 = "T2", tower3 = "T3", tower4 = "T4", melee_rax = "melee barracks", range_rax = "ranged barracks", fort = "Ancient"}
siege.laneNames = {"top", "mid", "bot"}
siege.attackType = {melee = 0.7, ranged = 0.35, siege = 2.5, hero = 0.5}
siege.creepStats = {melee = {550, 21, 1}, ranged = {300, 23.5, 1}, siege = {935, 40.5, 2.7}}
siege.creepSpeed = 325
siege.horizon = 40
siege.reach = 5200
siege.partial = 0.55
siege.bounty = 40
siege.lastHitShare = 0.5
siege.minimum = 0.06

local function alive(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function visible(unit)
	return alive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function siege.laneOf(point)
	return math.abs(point.x - point.y) < 2000 and 2 or point.y > point.x and 1 or 3
end

function siege.kind(structure)
	local name = NPC.GetUnitName(structure) or ""
	local lane = name:find("_top", 1, true) and 1 or name:find("_mid", 1, true) and 2 or name:find("_bot", 1, true) and 3 or nil
	if NPC.IsFort(structure) or name:find("_fort", 1, true) then return "fort", nil end
	local tier = name:match("tower(%d)")
	if tier then return "tower" .. tier, tier ~= "4" and lane or nil end
	if name:find("melee_rax", 1, true) then return "melee_rax", lane end
	if name:find("range_rax", 1, true) then return "range_rax", lane end
	return nil, lane
end

function siege.label(entry)
	local name = siege.labels[entry.kind] or "building"
	local lane = entry.lane and siege.laneNames[entry.lane]
	if entry.kind == "fort" or entry.kind == "tower4" or not lane then return name end
	return name .. " " .. lane
end

function siege.fronts(ctx)
	local lanes, base = {{}, {}, {}}, {}
	for _, unit in ipairs(ctx.structures or {}) do
		if alive(unit) and Entity.IsSameTeam(ctx.hero, unit) then
			local kind, lane = siege.kind(unit)
			if kind == "tower4" or kind == "fort" then base[#base + 1] = {unit = unit, kind = kind}
			elseif kind and lane then lanes[lane][#lanes[lane] + 1] = {unit = unit, kind = kind} end
		end
	end
	local fronts = {}
	for lane = 1, 3 do
		local towers, rax = {}, {}
		for _, entry in ipairs(lanes[lane]) do
			if entry.kind:find("^tower") then towers[#towers + 1] = entry else rax[#rax + 1] = entry end
		end
		local list = rax
		if #towers > 0 then
			table.sort(towers, function(a, b)
				return ctx.distance(Entity.GetAbsOrigin(a.unit), ctx.home) > ctx.distance(Entity.GetAbsOrigin(b.unit), ctx.home)
			end)
			list = {towers[1]}
		elseif #list == 0 then
			local outer = {}
			for _, entry in ipairs(base) do if entry.kind == "tower4" then outer[#outer + 1] = entry end end
			list = #outer > 0 and outer or base
		end
		for _, entry in ipairs(list) do fronts[#fronts + 1] = {unit = entry.unit, kind = entry.kind, lane = lane} end
	end
	return fronts
end

local function growth(clock)
	return 1 + math.floor(math.max(0, clock or 0) / 450) * 0.06
end

function siege.creep(ctx, unit)
	local name = NPC.GetUnitName(unit) or ""
	local kind = name:find("siege", 1, true) and "siege" or name:find("ranged", 1, true) and "ranged" or "melee"
	local base, scale = siege.creepStats[kind], growth(ctx.clock)
	local hp, damage, interval
	if visible(unit) then
		hp, damage, interval = Entity.GetHealth(unit), NPC.GetTrueDamage(unit), NPC.GetSecondsPerAttack(unit, false)
	end
	hp = hp and hp > 0 and hp or base[1] * scale
	damage = damage and damage > 0 and damage or base[2] * scale
	interval = interval and interval > 0.2 and interval or base[3]
	return {kind = kind, hp = hp, dps = damage / interval}
end

function siege.estimate(ctx, count, hasSiege)
	local list, scale = {}, growth(ctx.clock)
	local siegeCount = hasSiege and 1 or 0
	local rest = math.max(0, count - siegeCount)
	local ranged = rest >= 2 and math.max(1, math.floor(rest * 0.25 + 0.5)) or 0
	local function add(kind, number)
		local base = siege.creepStats[kind]
		for _ = 1, number do list[#list + 1] = {kind = kind, hp = base[1] * scale, dps = base[2] * scale / base[3]} end
	end
	add("melee", rest - ranged)
	add("ranged", ranged)
	add("siege", siegeCount)
	return list
end

function siege.groups(ctx)
	local out = {}
	for _, group in ipairs(waves.enemy(ctx)) do
		local creeps, units = {}, group.units or {}
		for _, unit in ipairs(units) do creeps[#creeps + 1] = siege.creep(ctx, unit) end
		if #units < group.count then
			local hasSiege = group.siege
			for _, creep in ipairs(creeps) do if creep.kind == "siege" then hasSiege = false end end
			for _, creep in ipairs(siege.estimate(ctx, group.count - #units, hasSiege)) do creeps[#creeps + 1] = creep end
		end
		out[#out + 1] = {lane = siege.laneOf(group.position), position = group.position, creeps = creeps}
	end
	if #out > 0 then return out end
	for _, unit in ipairs(ctx.worldNPCs or {}) do
		if visible(unit) and NPC.IsLaneCreep(unit) and not Entity.IsSameTeam(ctx.hero, unit) then
			local point = Entity.GetAbsOrigin(unit)
			local lane = siege.laneOf(point)
			local joined
			for _, group in ipairs(out) do
				if group.lane == lane and ctx.distance(group.anchor, point) < 1000 then joined = group; break end
			end
			if not joined then
				joined = {lane = lane, position = point, anchor = point, creeps = {}}
				out[#out + 1] = joined
			end
			joined.creeps[#joined.creeps + 1] = siege.creep(ctx, unit)
			if ctx.distance(point, ctx.home) < ctx.distance(joined.position, ctx.home) then joined.position = point end
		end
	end
	return out
end

function siege.defenders(ctx, point)
	local dps = 0
	for _, tower in ipairs(ctx.towers or {}) do
		if alive(tower) and Entity.IsSameTeam(ctx.hero, tower) and ctx.distance(Entity.GetAbsOrigin(tower), point) < 950 then
			dps = dps + NPC.GetTrueDamage(tower) * 0.9 / math.max(0.3, NPC.GetSecondsPerAttack(tower, false))
		end
	end
	return dps
end

function siege.simulate(creeps, defenders, hero, heroStart, horizon)
	local list = {}
	for i, creep in ipairs(creeps) do list[i] = {hp = creep.hp, hit = creep.hit} end
	table.sort(list, function(a, b) return a.hp < b.hp end)
	local function strike(amount)
		while amount > 0 and #list > 0 do
			local first = list[1]
			if first.hp > amount then first.hp = first.hp - amount; return end
			amount = amount - first.hp
			table.remove(list, 1)
		end
	end
	heroStart = heroStart or math.huge
	if hero > 0 and heroStart < 0 then
		strike(hero * math.min(-heroStart, 12))
		heroStart = 0
	end
	local t, loss, dt = 0, 0, 0.25
	horizon = horizon or siege.horizon
	while t < horizon and #list > 0 do
		local rate = 0
		for _, creep in ipairs(list) do rate = rate + creep.hit end
		loss = loss + rate * dt
		strike((defenders + (t >= heroStart and hero or 0)) * dt)
		t = t + dt
	end
	return loss, t, #list
end

function siege.observe(ctx)
	ctx.structureHealth = ctx.structureHealth or {}
	local samples = ctx.structureHealth
	for _, unit in ipairs(ctx.structures or {}) do
		if alive(unit) and Entity.IsSameTeam(ctx.hero, unit) then
			local id = Entity.GetIndex(unit)
			local list = samples[id] or {}
			samples[id] = list
			local last = list[#list]
			if not last or ctx.now - last.time >= 0.2 then list[#list + 1] = {time = ctx.now, hp = Entity.GetHealth(unit)} end
			while #list > 1 and ctx.now - list[1].time > 3 do table.remove(list, 1) end
		end
	end
end

function siege.rate(ctx, structure)
	local list = ctx.structureHealth and ctx.structureHealth[Entity.GetIndex(structure)]
	if not list or #list < 2 then return 0 end
	local span = list[#list].time - list[1].time
	if span < 0.6 then return 0 end
	return math.max(0, (list[1].hp - list[#list].hp) / span)
end

function siege.goldRate(ctx)
	local info = not ctx.ally and Player.GetTeamPlayer and Player.GetTeamPlayer(ctx.player)
	local earned = info and info.totalearned_gold or 0
	if earned > 0 and (ctx.clock or 0) > 180 then return math.max(1.2, earned / ctx.clock) end
	return 1.2 + NPC.GetCurrentLevel(ctx.hero) * 0.12
end

function siege.arrival(ctx, point)
	local speed = math.max(200, NPC.GetMoveSpeed(ctx.hero))
	local distance = ctx.distance(ctx.position, point)
	local walk = distance * 1.15 / speed
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	if ctx.settings.teleport ~= false and distance > 3000 and scroll and Ability.IsReady(scroll) then
		local teleport = 4 + 500 / speed
		if teleport < walk then return teleport, true end
	end
	return walk, false
end

function siege.heroDps(ctx)
	local dps = NPC.GetTrueDamage(ctx.hero) * 0.9 / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false))
	if ctx.settings.spells and ctx.clearAbilities then dps = dps * 1.35 end
	return dps
end

function siege.value(ctx, kind)
	local value = siege.values[kind] or 900
	local clock = ctx.clock or 0
	if kind == "tower1" and clock < 900 then value = value + 400 end
	if kind == "tower2" and clock < 1500 then value = value + 200 end
	return value
end

local function worth(value, loss, maxHp, hp)
	if loss >= hp then return value end
	return value * siege.partial * loss / math.max(1, maxHp)
end

local function percent(amount, maxHp)
	return math.floor(amount / math.max(1, maxHp) * 100 + 0.5)
end

function siege.assess(ctx, entry, groups)
	local structure = entry.unit
	local point = Entity.GetAbsOrigin(structure)
	local hp, maxHp = Entity.GetHealth(structure), Entity.GetMaxHealth(structure)
	local armor = NPC.GetArmorDamageMultiplier(structure)
	local value = siege.value(ctx, entry.kind)
	local matched, eta, nearest, front = {}, nil, nil, nil
	for _, group in ipairs(groups) do
		local distance = ctx.distance(group.position, point)
		if (group.lane == entry.lane or distance < 1400) and distance < siege.reach and #group.creeps > 0 then
			local arrive = math.max(0, distance * 1.1 - 450) / siege.creepSpeed
			matched[#matched + 1] = {group = group, arrive = arrive}
			if not eta or arrive < eta then eta, nearest, front = arrive, distance, group end
		end
	end
	if not eta then return nil end
	local creeps, pool, raw = {}, 0, 0
	for _, match in ipairs(matched) do
		if match.arrive <= eta + 8 then
			for _, creep in ipairs(match.group.creeps) do
				creeps[#creeps + 1] = {kind = creep.kind, hp = creep.hp, dps = creep.dps,
					hit = creep.dps * (siege.attackType[creep.kind] or 0.7) * armor}
				pool, raw = pool + creep.hp, raw + creep.dps
			end
		end
	end
	local allyPool = 0
	for _, unit in ipairs(ctx.waves and ctx.waves[entry.lane] or {}) do
		if alive(unit) then
			local position = Entity.GetAbsOrigin(unit)
			if ctx.distance(position, point) <= nearest + 300 and ctx.distance(position, front.position) <= nearest + 300 then
				allyPool = allyPool + Entity.GetHealth(unit)
			end
		end
	end
	local residual = pool > 0 and math.max(0, 1 - allyPool * 0.9 / pool) or 0
	if residual < 1 then
		for _, creep in ipairs(creeps) do creep.hp, creep.hit = creep.hp * residual, creep.hit * residual end
		eta = eta + math.min(10, allyPool / math.max(1, raw)) * 0.5
	end
	if NPC.HasState(structure, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then eta = eta + 5 end
	local heroes, heroHit = 0, 0
	for _, enemy in ipairs(ctx.enemies or {}) do
		if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1600 then
			heroes = heroes + 1
			heroHit = heroHit + NPC.GetTrueDamage(enemy) * siege.attackType.hero * armor
				/ math.max(0.3, NPC.GetSecondsPerAttack(enemy, false)) * 0.6
		end
	end
	local defenders = siege.defenders(ctx, point)
	local loss0, duration0 = siege.simulate(creeps, defenders, 0)
	if residual <= 0 then loss0, duration0 = 0, 0 end
	loss0 = loss0 + heroHit * duration0
	local rate = siege.rate(ctx, structure)
	if rate > 0 and nearest < 900 then loss0 = math.max(loss0, rate * duration0) end
	local arrival, teleport = siege.arrival(ctx, point)
	local lossA, durationA = siege.simulate(creeps, defenders, siege.heroDps(ctx), arrival - eta)
	if residual <= 0 then lossA, durationA = 0, 0 end
	lossA = lossA + heroHit * durationA
	if rate > 0 and nearest < 900 then lossA = math.max(lossA, rate * math.min(duration0, math.max(0, arrival - eta))) end
	lossA = math.min(lossA, loss0)
	local saved = worth(value, loss0, maxHp, hp) - worth(value, lossA, maxHp, hp)
	local here = ctx.distance(ctx.position, point) < 1500
	local trip = arrival + math.min(arrival, 25)
	local cost = here and 0 or trip * siege.goldRate(ctx) * (ctx.role <= 3 and 1.15 or 0.8) + (teleport and 100 or 0)
	if not here and ctx.role <= 3 and (ctx.clock or 0) < 600 then cost = cost * 2.5 + (teleport and 150 or 0) end
	local _, _, left = siege.simulate(creeps, defenders, 0, nil, math.max(0, arrival - eta))
	if residual <= 0 then left = 0 end
	local bounty = here and 0 or left * siege.bounty * siege.lastHitShare
	local current = ctx.baseDefense and ctx.baseDefense.structure == structure or ctx.towerDefense and ctx.towerDefense.structure == structure
	if current then cost = cost * 0.5 end
	local meaningful = saved >= value * siege.minimum or loss0 >= hp
	local profitable = bounty > cost and loss0 >= maxHp * 0.08
	local taken = not here and coordination.defenseTaken and coordination.defenseTaken(ctx, structure, arrival)
	local defend = (meaningful or profitable) and saved + bounty > cost and not taken
	local label = siege.label(entry)
	local reason
	if loss0 < 1 then reason = "wave dies before it reaches the " .. label
	elseif taken then reason = "an ally we control is covering the " .. label
	elseif defend then
		reason = string.format("defend the %s: loss %d%% -> %d%%, saves ~%dg + ~%dg creep gold vs ~%dg trip", label,
			percent(loss0, maxHp), percent(lossA, maxHp), math.floor(saved), math.floor(bounty), math.floor(cost))
	elseif not meaningful and loss0 < maxHp * 0.08 then reason = string.format("let the wave slide: the %s only loses ~%d%%", label, percent(loss0, maxHp))
	elseif not meaningful then reason = string.format("let the wave slide: arriving in %.0fs barely helps the %s (loss %d%% -> %d%%)", arrival, label, percent(loss0, maxHp), percent(lossA, maxHp))
	elseif loss0 >= hp and lossA >= hp then reason = "the " .. label .. " falls before we can arrive"
	else reason = string.format("not worth the trip: saves ~%dg + ~%dg creep gold, trip costs ~%dg", math.floor(saved), math.floor(bounty), math.floor(cost)) end
	return {structure = structure, kind = entry.kind, lane = entry.lane, label = label, position = point, eta = eta,
		arrival = arrival, teleport = teleport, loss = loss0, lossDefended = lossA, falls = loss0 >= hp, fallsDefended = lossA >= hp,
		duration = duration0, saved = saved, bounty = bounty, cost = cost, value = value, heroes = heroes, creeps = #creeps,
		defend = defend, reason = reason}
end

function siege.plan(ctx)
	local cache = ctx.siege
	if cache and ctx.now < cache.next and cache.position and ctx.distance(cache.position, ctx.position) < 300 then return cache end
	local groups = siege.groups(ctx)
	local result = {next = ctx.now + 0.5, list = {}, by = {}, position = ctx.position}
	for _, entry in ipairs(siege.fronts(ctx)) do
		local assessment = siege.assess(ctx, entry, groups)
		if assessment then
			local id = Entity.GetIndex(entry.unit)
			local old = result.by[id]
			if not old or assessment.saved > old.saved then result.by[id] = assessment end
		end
	end
	for _, assessment in pairs(result.by) do result.list[#result.list + 1] = assessment end
	table.sort(result.list, function(a, b) return a.saved + a.bounty - a.cost > b.saved + b.bounty - b.cost end)
	result.top = result.list[1]
	ctx.siege = result
	local top = result.top
	ctx.siegeNote = top and top.loss >= 1 and top.reason or nil
	return result
end

function siege.assessment(ctx, structure)
	return siege.plan(ctx).by[Entity.GetIndex(structure)]
end

function siege.glyph(ctx)
	if not ctx.settings or ctx.settings.glyph == false or ctx.ally or not GameRules then return false end
	local ready = ctx.team == 2 and GameRules.GetGoodGlyphCD or GameRules.GetBadGlyphCD
	local now = GameRules.GetGameTime()
	if not ready or ready() > now or now < (ctx.nextGlyph or 0) then return false end
	for _, unit in ipairs(ctx.structures or {}) do
		if alive(unit) and Entity.IsSameTeam(ctx.hero, unit) and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
			local kind = siege.kind(unit)
			local rate, hp = siege.rate(ctx, unit), Entity.GetHealth(unit)
			if kind and rate > 0 and hp < rate * 3.5 then
				local point = Entity.GetAbsOrigin(unit)
				local attackers, heroes, allies = 0, 0, 0
				for _, other in ipairs(ctx.worldNPCs or {}) do
					if visible(other) and not Entity.IsSameTeam(ctx.hero, other) and NPC.IsLaneCreep(other)
						and ctx.distance(Entity.GetAbsOrigin(other), point) < 900 then attackers = attackers + 1 end
				end
				for _, enemy in ipairs(ctx.enemies or {}) do
					if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1200 then heroes = heroes + 1 end
				end
				for _, ally in ipairs(ctx.allies or {}) do
					if alive(ally) and not NPC.IsIllusion(ally) and ctx.distance(Entity.GetAbsOrigin(ally), point) < 2500 then allies = allies + 1 end
				end
				local important = kind ~= "tower1" and (kind ~= "tower2" or allies > 0 or heroes == 0) or allies > 0
				if attackers + heroes > 0 and important then
					Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_GLYPH, nil, Vector(0, 0, 0), nil,
						Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_glyph", false)
					ctx.nextGlyph = now + 5
					ctx.glyphNote = string.format("Glyph to save the %s (%.0f HP, losing %.0f/s)", siege.label({kind = kind, lane = select(2, siege.kind(unit))}), hp, rate)
					if Log then Log.Write("[SelfPlay siege] " .. ctx.glyphNote) end
					return true
				end
			end
		end
	end
	return false
end

return siege
