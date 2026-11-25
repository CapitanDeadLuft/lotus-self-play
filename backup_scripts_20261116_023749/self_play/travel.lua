local travel = {}
local supportPolicy = require("self_play.support_policy")
local helpRotation = require("self_play.help_rotation")
local awareness = require("self_play.awareness")
local abilityKV = XHelpers and XHelpers.xkv and XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities

travel.channel = 3
travel.rules = {
	fight = {saved = 4, walk = 3000, backward = true},
	defend = {saved = 6, walk = 3000, backward = true},
	recover = {saved = 6, walk = 3000, backward = true, home = true},
	escape = {saved = 0, walk = 3000, backward = true, home = true},
	farm = {saved = 10, walk = 4500},
	lane = {saved = 10, walk = 4500},
	rotate = {saved = 10, walk = 4500},
}

local function valid(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function visible(unit)
	return valid(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function travel.length(ctx, from, to)
	local straight = ctx.distance(from, to)
	if straight < 300 then return straight end
	local path = GridNav.BuildPath(from, to, false)
	if not path or #path == 0 then return straight * 1.2 end
	local length, previous = 0, from
	for _, node in ipairs(path) do length, previous = length + ctx.distance(previous, node), node end
	return length + ctx.distance(previous, to)
end

function travel.speed(ctx)
	return math.max(200, NPC.GetMoveSpeed(ctx.hero))
end

function travel.worth(ctx, destination, arrival, purpose)
	local rule = travel.rules[purpose] or travel.rules.rotate
	if ctx.regroupTask and purpose ~= "fight" and purpose ~= "defend" then return false, "regrouping" end
	local fromBase = ctx.distance(ctx.position, ctx.home) < 2000
	local routine = purpose == "lane" or purpose == "rotate"
	if not rule.backward and not fromBase then
		if routine and (ctx.intent and ctx.intent.kind == "structure" or ctx.distance(ctx.position, ctx.enemyHome) < 4500) then return false, "busy near enemy base" end
		local progress = ctx.distance(ctx.position, ctx.home)
		if ctx.distance(destination, ctx.home) < progress - 1200 or ctx.distance(arrival, ctx.home) < progress - 1800 then return false, "backward" end
	end
	local currentLane = math.abs(ctx.position.x - ctx.position.y) < 2000 and 2 or ctx.position.y > ctx.position.x and 1 or 3
	if purpose == "lane" and not fromBase and currentLane == ctx.lane then return false, "same lane" end
	local straight = ctx.distance(ctx.position, destination)
	local minimum = fromBase and math.min(rule.walk, 3000) or rule.walk
	if straight < minimum then return false, "short walk" end
	local speed = travel.speed(ctx)
	local walk = travel.length(ctx, ctx.position, destination) / speed
	local land = travel.channel + 0.3 + travel.length(ctx, arrival, destination) / speed
	local saved = walk - land
	if saved < rule.saved then return false, string.format("saves %.1fs", saved), saved end
	return true, string.format("saves %.1fs", saved), saved
end

function travel.scroll(ctx)
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	local special = ctx.heroModule and ctx.heroModule.travelAbility and ctx.heroModule.travelAbility(ctx)
	scroll = special or scroll
	if not scroll or not special and not Item.IsItemEnabled(scroll) or Ability.CanBeExecuted(scroll) ~= -1
		or not Ability.IsReady(scroll) or not Ability.IsCastable(scroll, NPC.GetMana(ctx.hero)) then return nil end
	return scroll
end

function travel.blocked(ctx, destination, purpose)
	if ctx.settings.teleport == false then return "disabled" end
	if not supportPolicy.midTeleport(ctx, destination) then return "mid lane belongs to mid" end
	if purpose == "fight" and ctx.role == 2 and NPC.GetCurrentLevel(ctx.hero) < 6 and not ctx.baseDefense then return "mid before level 6" end
	if ctx.helpRotation or purpose ~= "fight" and purpose ~= "defend" and ctx.now < (ctx.helpLaneUntil or 0) then return "help rotation" end
	if ctx.now < (ctx.nextTeleport or 0) then return "cooldown" end
	if ctx.nearEnemies > 0 or Hero.GetRecentDamage(ctx.hero) > 0 then return "enemies near" end
	if (purpose == "recover" or purpose == "escape" or purpose == "defend") and travel.interruptible(ctx) then return "could be interrupted" end
	return nil
end

function travel.interruptible(ctx)
	for _, enemy in ipairs(ctx.enemies or {}) do
		if visible(enemy) and not NPC.IsIllusion(enemy) then
			local gap = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) - NPC.GetAttackRange(enemy) - NPC.GetAttackRangeBonus(enemy) - 250
			if gap < math.max(100, NPC.GetMoveSpeed(enemy)) * (travel.channel + 0.3) then return true end
		end
	end
	local _, count = awareness.forecast(ctx, ctx.position)
	return (count or 0) > 0
end

function travel.enemyCenter(ctx, destination)
	local x, y, count = 0, 0, 0
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), destination) < 2200 then
			local position = Entity.GetAbsOrigin(enemy)
			x, y, count = x + position.x, y + position.y, count + 1
		end
	end
	if count == 0 then return nil, 0 end
	return Vector(x / count, y / count, destination.z), count
end

function travel.crosses(from, to, point, width)
	local dx, dy = to.x - from.x, to.y - from.y
	local length = dx * dx + dy * dy
	if length < 1 then return false end
	local t = ((point.x - from.x) * dx + (point.y - from.y) * dy) / length
	if t <= 0.05 or t >= 0.95 then return false end
	local x, y = from.x + dx * t - point.x, from.y + dy * t - point.y
	return x * x + y * y < width * width
end

function travel.landingSafe(ctx, position, purpose)
	local friendly = 0
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and valid(ally) and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.45
			and ctx.distance(position, Entity.GetAbsOrigin(ally)) < 1200 then friendly = friendly + 1 end
	end
	local close, near = 0, 0
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsIllusion(enemy) then
			local distance = ctx.distance(position, Entity.GetAbsOrigin(enemy))
			if distance < 900 then close = close + 1 end
			if distance < 1600 then near = near + 1 end
		end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		if ctx.distance(position, arrival.position) < 1400 then return false, friendly end
	end
	if close > 0 and not (purpose == "fight" and friendly >= 2 and friendly > close) then return false, friendly end
	if near > friendly then return false, friendly end
	return true, friendly
end

function travel.fightTask(ctx)
	local task = ctx.teamTask
	if task and task.fighting then return task end
	local session = ctx.fightSession
	if session and session.target then
		return {kind = "group", fighting = true, target = session.target, members = session.members or {}, goal = session.goal}
	end
	return task
end

function travel.landing(ctx, destination, purpose)
	local rule = travel.rules[purpose] or travel.rules.rotate
	local best, bestScore, estimate
	if rule.home and ctx.fountain and ctx.distance(destination, ctx.home) < 600 then return ctx.home, nil end
	local contested = purpose == "fight" or purpose == "defend"
	local radius = contested and 3600 or 2200
	local center = contested and travel.enemyCenter(ctx, destination) or nil
	local speed = travel.speed(ctx)
	for _, structure in ipairs(ctx.structures) do
		if valid(structure) and Entity.IsSameTeam(structure, ctx.hero) then
			local position = Entity.GetAbsOrigin(structure)
			if ctx.distance(position, destination) < radius then
				local safe = travel.landingSafe(ctx, position, purpose)
				local score = travel.length(ctx, position, destination) / speed
				if safe and center and travel.crosses(position, destination, center, 700) then score = score + 6 end
				local prediction
				if safe and purpose == "fight" then
					prediction, ctx.helpStatus = helpRotation.evaluate(ctx, travel.fightTask(ctx), position)
					safe = prediction ~= nil
					if prediction then score = math.max(score, prediction.eta) end
				end
				if safe and (not bestScore or score < bestScore) then best, bestScore, estimate = position, score, prediction end
			end
		end
	end
	return best, estimate
end

local function note(ctx, purpose, text)
	ctx.travelStatus = {time = ctx.now, text = purpose .. ": " .. text}
	return false
end

travel.gatePurposes = {lane = true, rotate = true, farm = true, defend = true}

function travel.gates(ctx)
	local cached = ctx.twinGates
	if cached and #cached >= 2 and valid(cached[1]) and valid(cached[2]) then return cached end
	local list = {}
	for _, unit in ipairs(NPCs.GetAll()) do
		if Entity.IsEntity(unit) and NPC.GetUnitName(unit) == "npc_dota_unit_twin_gate" then list[#list + 1] = unit end
	end
	ctx.twinGates = list
	return list
end

function travel.gateChannel(ability)
	local kv = abilityKV and abilityKV.twin_gate_portal_warp
	local raw = kv and (kv.AbilityChannelTime or kv.AbilityValues and kv.AbilityValues.channel_time)
	if type(raw) == "table" then raw = raw.value end
	return tonumber(raw) or 6
end

function travel.gatePlan(ctx, destination, purpose)
	if not travel.gatePurposes[purpose] then return nil, "purpose" end
	local ability = NPC.GetAbility(ctx.hero, "twin_gate_portal_warp")
	if not ability or Ability.IsHidden(ability) or not Ability.IsReady(ability) or not Ability.IsActivated(ability) then return nil, "gate on cooldown" end
	local gates = travel.gates(ctx)
	if #gates < 2 then return nil, "no gates" end
	local entry, exit = gates[1], gates[2]
	if ctx.distance(ctx.position, Entity.GetAbsOrigin(exit)) < ctx.distance(ctx.position, Entity.GetAbsOrigin(entry)) then entry, exit = exit, entry end
	local speed = travel.speed(ctx)
	local direct = travel.length(ctx, ctx.position, destination) / speed
	local via = travel.length(ctx, ctx.position, Entity.GetAbsOrigin(entry)) / speed + travel.gateChannel(ability) + 0.5
		+ travel.length(ctx, Entity.GetAbsOrigin(exit), destination) / speed
	if direct - via < 10 then return nil, string.format("gate saves %.1fs", direct - via) end
	if not travel.landingSafe(ctx, Entity.GetAbsOrigin(exit), purpose) then return nil, "gate exit unsafe" end
	return {ability = ability, entry = entry, exit = exit, destination = destination, purpose = purpose,
		expires = ctx.now + via + 4, saved = direct - via}
end

function travel.gate(ctx, destination, purpose)
	local task = ctx.gateTask
	if task and (ctx.now > task.expires or ctx.distance(task.destination, destination) > 2500 or not valid(task.entry)) then task, ctx.gateTask = nil, nil end
	if not task then
		local plan, why = travel.gatePlan(ctx, destination, purpose)
		if not plan then return note(ctx, purpose, "no scroll ready; " .. why) end
		task, ctx.gateTask = plan, plan
		note(ctx, purpose, string.format("walk to twin gate (saves %.0fs)", plan.saved))
	end
	if ctx.distance(ctx.position, Entity.GetAbsOrigin(task.exit)) < 600 then ctx.gateTask = nil; return false end
	local gate = Entity.GetAbsOrigin(task.entry)
	if ctx.distance(ctx.position, gate) > 280 then return ctx.move(gate, "Walk to twin gate", 150) end
	if not Ability.IsReady(task.ability) then ctx.gateTask = nil; return false end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, task.entry, Vector(0, 0, 0), task.ability,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_gate", false)
	ctx.teleportOrder = {started = ctx.now, ability = task.ability}
	ctx.attackTarget, ctx.hits.ordered = nil, nil
	ctx.busyUntil, ctx.mode, ctx.lastOrder = ctx.now + 0.6, "Channel twin gate", "cast"
	task.expires = ctx.now + travel.gateChannel(task.ability) + 3
	return true
end

function travel.teleport(ctx, destination, purpose)
	local reason = travel.blocked(ctx, destination, purpose)
	if reason then ctx.gateTask = nil; return false end
	if ctx.distance(ctx.position, destination) < 3000 then return false end
	local scroll = travel.scroll(ctx)
	if not scroll then return travel.gate(ctx, destination, purpose) end
	local landing, estimate = travel.landing(ctx, destination, purpose)
	if not landing then return note(ctx, purpose, "no safe landing") end
	if purpose == "fight" and not estimate then return note(ctx, purpose, "fight would end before arrival") end
	local worth, why = travel.worth(ctx, destination, landing, purpose)
	if not worth then return note(ctx, purpose, "walk instead (" .. why .. ")") end
	Ability.CastPosition(scroll, landing, false, false, true)
	ctx.teleportOrder = {started = ctx.now, ability = scroll}
	ctx.attackTarget, ctx.hits.ordered = nil, nil
	if purpose == "fight" then helpRotation.commit(ctx, travel.fightTask(ctx), landing, estimate) end
	ctx.nextTeleport = ctx.now + 8
	ctx.busyUntil, ctx.mode, ctx.lastOrder = ctx.now + 0.6, purpose == "fight" and "Teleport to allied fight" or "Teleport: " .. purpose, "cast"
	note(ctx, purpose, string.format("teleport to %.0f,%.0f (%s)", landing.x, landing.y, why))
	return true
end

return travel
