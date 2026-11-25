local field = {}
local awareness = require("self_play.awareness")

field.treeRadius = 170
field.creepBuffer = 140
field.cacheTime = 0.25
field.keepBonus = 6

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function field.trees(point)
	if not Trees or not Trees.InRadius then return 0 end
	local ok, list = pcall(Trees.InRadius, point, field.treeRadius, true)
	return ok and type(list) == "table" and #list or 0
end

function field.heroes(ctx, point)
	local cost, hp = 0, math.max(200, Entity.GetHealth(ctx.hero))
	for _, enemy in ipairs(ctx.enemies or {}) do
		if visible(enemy) and not NPC.IsStunned(enemy) then
			local distance = ctx.distance(point, Entity.GetAbsOrigin(enemy))
			local reach = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 100 + NPC.GetMoveSpeed(enemy) * 0.35
			if distance < reach then
				local dps = NPC.GetTrueDamage(enemy) * NPC.GetArmorDamageMultiplier(ctx.hero) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
				cost = cost + (1 - distance / reach) * (60 + dps * 300 / hp)
			end
		end
	end
	return cost
end

function field.creeps(ctx, point)
	local cost = 0
	local allies, enemies = {}, {}
	for _, creep in ipairs(ctx.creeps or {}) do
		if visible(creep) and NPC.IsLaneCreep(creep) then
			if Entity.IsSameTeam(ctx.hero, creep) then allies[#allies + 1] = Entity.GetAbsOrigin(creep)
			else enemies[#enemies + 1] = creep end
		end
	end
	for _, creep in ipairs(enemies) do
		local position = Entity.GetAbsOrigin(creep)
		local distance = ctx.distance(point, position)
		local reach = NPC.GetAttackRange(creep) + field.creepBuffer
		if distance < reach then
			local covered = false
			for _, ally in ipairs(allies) do
				if ctx.distance(ally, position) < math.min(distance, 500) then covered = true; break end
			end
			cost = cost + (covered and 4 or 18) * (1 - distance / reach) + (covered and 0 or 4)
		end
	end
	return cost
end

function field.cost(ctx, point)
	local hp = math.max(200, Entity.GetHealth(ctx.hero))
	local cost = field.heroes(ctx, point) + field.creeps(ctx, point)
	cost = cost + awareness.forecast(ctx, point) * 120 / hp
	if ctx.unsafePosition and ctx.unsafePosition(point) then cost = cost + 400 end
	cost = cost + math.min(5, field.trees(point)) * 3
	return cost
end

function field.best(ctx, desired, options)
	options = options or {}
	local held = ctx.standPoint
	if held and ctx.now - held.time < field.cacheTime and ctx.distance(held.desired, desired) < 60 then return held.point, held.cost end
	local radius = options.radius or 240
	local pull = options.pull or 0.08
	local candidates = {desired}
	for _, ring in ipairs({radius * 0.5, radius}) do
		for index = 0, 9 do
			local angle = index * math.pi / 5
			local x, y = desired.x + math.cos(angle) * ring, desired.y + math.sin(angle) * ring
			candidates[#candidates + 1] = Vector(x, y, World.GetGroundZ(x, y))
		end
	end
	local keep = held and ctx.distance(held.desired, desired) < 160 and held.point or nil
	if keep then candidates[#candidates + 1] = keep end
	local best, bestCost
	for _, point in ipairs(candidates) do
		if GridNav.IsTraversable(point) then
			local cost = field.cost(ctx, point) + ctx.distance(point, desired) * pull + ctx.distance(ctx.position, point) * 0.01
			if point == keep then cost = cost - field.keepBonus end
			if not bestCost or cost < bestCost then best, bestCost = point, cost end
		end
	end
	best = best or desired
	ctx.standPoint = {point = best, desired = desired, cost = bestCost or 0, time = ctx.now}
	return best, bestCost
end

function field.positional(ctx)
	if ctx.exactMove == ctx.now then return false end
	if ctx.intent or ctx.runeTask or ctx.aggroTask or ctx.campTask or ctx.wardTask or ctx.dewardTask or ctx.objectiveTask then return false end
	if ctx.teamTask and ctx.teamTask.fighting or ctx.fightSession or ctx.helpRotation or ctx.baseCounterattack then return false end
	if ctx.hardRetreat or ctx.recoveryTask and ctx.recoveryTask.phase == "escape" then return false end
	if ctx.hits and ctx.hits.ordered then return false end
	if ctx.farmCandidate and ctx.farmCandidate.start and ctx.farmCandidate.start < ctx.now + 1.5 then return false end
	return true
end

return field
