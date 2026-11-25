local coordination = {list = {}}

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function coordination.set(contexts)
	coordination.list = contexts or {}
end

function coordination.partners(ctx)
	local result = {}
	for _, other in ipairs(coordination.list) do
		if other ~= ctx and other.active and other.hero and Entity.IsEntity(other.hero) and Entity.IsAlive(other.hero) then
			result[#result + 1] = other
		end
	end
	return result
end

function coordination.controls(ctx, hero)
	for _, other in ipairs(coordination.list) do
		if other ~= ctx and other.hero == hero then return true end
	end
	return false
end

function coordination.ownedByPartner(ctx, unit)
	if #coordination.list < 2 or not NPC.GetOwnerNPC then return false end
	local owner = NPC.GetOwnerNPC(unit)
	return owner ~= nil and owner ~= ctx.hero and coordination.controls(ctx, owner)
end

local function near(a, b, radius)
	if not a or not b then return false end
	local dx, dy = a.x - b.x, a.y - b.y
	return dx * dx + dy * dy < radius * radius
end

function coordination.farmTaken(ctx, point, radius)
	for _, other in ipairs(coordination.partners(ctx)) do
		local task = other.mapFarm
		if task and near(task.point or task.goal, point, radius or 900) then return true end
		local jungle = other.jungleState
		local walk = jungle and (jungle.walk or jungle.task)
		local camp = walk and walk.camp
		if camp and near(camp.position_, point, radius or 900) then return true end
		if jungle and jungle.task and near(jungle.task.origin, point, radius or 900) then return true end
	end
	return false
end

function coordination.campTaken(ctx, camp)
	for _, other in ipairs(coordination.partners(ctx)) do
		local task = other.campTask
		if task and task.camp and task.camp.index_ == camp.index_ then return true end
		local jungle = other.jungleState
		local walk = jungle and (jungle.walk or jungle.task)
		if walk and walk.camp and walk.camp.index_ == camp.index_ then return true end
	end
	return false
end

function coordination.runeTaken(ctx, position)
	for _, other in ipairs(coordination.partners(ctx)) do
		local task = other.runeTask
		local point = task and (task.position or task.target and Entity.IsEntity(task.target) and Entity.GetAbsOrigin(task.target))
		if point and near(point, position, 400) and ctx.distance(other.position, position) < ctx.distance(ctx.position, position) + 200 then return true end
	end
	return false
end

function coordination.defenseTaken(ctx, structure, arrival)
	for _, other in ipairs(coordination.partners(ctx)) do
		local task = other.baseDefense or other.towerDefense
		if task and task.structure == structure then return true end
		local plan = other.siege and other.siege.by and other.siege.by[Entity.GetIndex(structure)]
		if plan and plan.defend and plan.arrival < (arrival or math.huge) then return true end
	end
	return false
end

function coordination.update(ctx)
	local partners = coordination.partners(ctx)
	if #partners == 0 then return end
	ctx.fightEvidence = ctx.fightEvidence or {}
	for _, other in ipairs(partners) do
		local target = other.intent and other.intent.kind == "hero" and other.intent.target
			or other.fightSession and other.fightSession.target
		if live(target) and not Entity.IsSameTeam(ctx.hero, target)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) < 2500 then
			local id = Entity.GetIndex(target)
			local record = ctx.fightEvidence[id] or {target = target, allies = {}}
			record.allies[Entity.GetIndex(other.hero)] = {unit = other.hero, time = ctx.now}
			ctx.fightEvidence[id] = record
			ctx.nextFightPlan = 0
		end
	end
end

function coordination.takenRoles(ctx)
	local roles = {}
	for _, other in ipairs(coordination.list) do
		if other ~= ctx and other.role then roles[other.role] = true end
	end
	return roles
end

return coordination
