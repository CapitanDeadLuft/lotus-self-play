local camps = {}
local geometry = require("self_play.lane_geometry")
local navigation = require("self_play.navigation")
local awareness = require("self_play.awareness")
local lastHit = require("self_play.last_hit")
local coordination = require("self_play.coordination")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function inside(box, point, margin)
	return point.x >= box.min.x - margin and point.x <= box.max.x + margin
		and point.y >= box.min.y - margin and point.y <= box.max.y + margin
end

local function units(ctx, camp)
	local found = {}
	for _, unit in ipairs(ctx.worldNPCs) do
		if live(unit) and NPC.IsNeutral(unit) and NPC.IsCreep(unit) and not NPC.IsWaitingToSpawn(unit)
			and (camp.camp_type == 3 or not NPC.IsAncient(unit)) and inside(camp.box, Entity.GetAbsOrigin(unit), 120) then found[#found + 1] = unit end
	end
	return found
end

local function finish(ctx, reason)
	ctx.campStatus, ctx.campTask, ctx.nextCampPlan = reason, nil, ctx.now + 2
	return false
end

local function destination(ctx, camp, kind, route)
	if kind == "pull" then
		if not route then return nil end
		local point, progress, distance = geometry.project(ctx, route, camp.position_)
		if distance < 350 or distance > 1400 then return nil end
		return point, progress
	end
	local best, score
	local shelter = navigation.coverAnchor(ctx)
	for index = 0, 15 do
		local angle = index * math.pi / 8
		local x, y = math.cos(angle), math.sin(angle)
		local edgeX = x > 0 and camp.box.max.x or camp.box.min.x
		local edgeY = y > 0 and camp.box.max.y or camp.box.min.y
		local extent = math.min(math.abs(x) > 0.01 and math.abs((edgeX - camp.position_.x) / x) or math.huge,
			math.abs(y) > 0.01 and math.abs((edgeY - camp.position_.y) / y) or math.huge)
		local point = Vector(camp.position_.x + x * (extent + 450), camp.position_.y + y * (extent + 450), camp.position_.z)
		if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
			local value = extent + ctx.distance(point, shelter) * 0.3 + awareness.risk(ctx, point) * 4
			if not score or value < score then best, score = point, value end
		end
	end
	return best
end

local function centre(camp, members)
	if #members == 0 then return camp.position_ end
	local x, y, z = 0, 0, 0
	for _, unit in ipairs(members) do
		local point = Entity.GetAbsOrigin(unit)
		x, y, z = x + point.x, y + point.y, z + point.z
	end
	return Vector(x / #members, y / #members, z / #members)
end

function camps.clear(ctx, from, to)
	local distance = ctx.distance(from, to)
	for step = 1, math.max(1, math.floor(distance / 50)) do
		local point = ctx.toward(from, to, math.min(distance - 80, step * 50))
		if ctx.distance(point, to) > 80 and not GridNav.IsTraversable(point) then return false end
	end
	return World.GetGroundZ(from.x, from.y) >= World.GetGroundZ(to.x, to.y) - 60
end

function camps.stand(ctx, camp, members, goal)
	local target = centre(camp, members)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local direction = math.atan2(goal.y - target.y, goal.x - target.x)
	for _, reach in ipairs({math.max(150, range - 60), math.max(150, range - 220), 220}) do
		for _, turn in ipairs({0, 0.26, -0.26, 0.52, -0.52, 0.79, -0.79}) do
			local angle = direction + turn
			local x, y = target.x + math.cos(angle) * reach, target.y + math.sin(angle) * reach
			local point = Vector(x, y, World.GetGroundZ(x, y))
			if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) and camps.clear(ctx, point, target) then return point end
		end
	end
	return ctx.toward(target, goal, math.max(100, range - 60))
end

local function dragTime(ctx, camp, members, goal)
	local length, previous = 0, camp.position_
	local path = GridNav.BuildPath(previous, goal)
	if #path == 0 then return nil end
	for _, point in ipairs(path) do length, previous = length + ctx.distance(previous, point), point end
	length = length + ctx.distance(previous, goal)
	local speed = 300
	for _, unit in ipairs(members) do speed = math.min(speed, NPC.GetMoveSpeed(unit), NPC.GetMoveSpeed(ctx.hero)) end
	return length / math.max(100, speed) + 0.65
end

local function trigger(ctx, task, members)
	local travel = dragTime(ctx, task.camp, members, task.destination)
	if not travel then return nil end
	local delay = members[1] and lastHit.timing(ctx, members[1]) or 0.6
	if not delay then return nil end
	if task.kind == "stack" then return task.spawn - travel - delay end
	local earliest = math.huge
	for _, creep in ipairs(ctx.waves[ctx.lane]) do
		if live(creep) and not NPC.IsRanged(creep) and NPC.IsRunning(creep) and not NPC.IsAttacking(creep) then
			local _, progress, offset = geometry.project(ctx, task.route, Entity.GetAbsOrigin(creep))
			if progress < task.crossing - 150 and offset < 350 then
				earliest = math.min(earliest, (task.crossing - progress) / math.max(100, NPC.GetMoveSpeed(creep)))
			end
		end
	end
	if earliest == math.huge then return nil end
	return ctx.clock + earliest - travel - delay
end

local function dedicated(ctx)
	local mode = ctx.settings.mode or 0
	return mode == 3 or mode == 4
end

local function kinds(ctx)
	local mode = ctx.settings.mode or 0
	return ctx.settings.stack ~= false and mode ~= 4, ctx.settings.pull ~= false and mode ~= 3
end

local function blocked(ctx)
	local stack, pull = kinds(ctx)
	if not stack and not pull then return "stacking and pulling switched off" end
	if not dedicated(ctx) and ctx.role < 4 then return "core role" end
	if not dedicated(ctx) and (ctx.intent or ctx.runeTask or ctx.objectiveTask) then return "busy with another task" end
	if not dedicated(ctx) and ctx.teamTask and (ctx.teamTask.fighting or ctx.teamTask.kind ~= "protect") then return "team task" end
	if ctx.clock < 60 then return "too early" end
	local resting = ctx.recoveryTask and ctx.recoveryTask.phase == "regen" and not ctx.hardRetreat
	if ctx.health < (resting and 0.35 or 0.55) or ctx.retreating and not resting then return "low health" end
	if ctx.laneThreat and (ctx.laneThreat.avoid or ctx.laneThreat.attacked) then return "lane pressure" end
	for _, ally in ipairs(ctx.allies) do
		if live(ally) and ally ~= ctx.hero and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 1300 and Hero.GetRecentDamage(ally) > 0 then return "ally trading nearby" end
	end
	return nil
end

local function allowed(ctx)
	local reason = blocked(ctx)
	ctx.campPlanNote = reason
	return reason == nil
end

function camps.plan(ctx, lookahead)
	if not lookahead and ctx.now < (ctx.nextCampPlan or 0) or not allowed(ctx) then return nil end
	if not lookahead then ctx.nextCampPlan = ctx.now + 0.5 end
	local allowStack, allowPull = kinds(ctx)
	local radius = dedicated(ctx) and 7000 or ctx.role >= 4 and ctx.clock >= 600 and not ctx.escortTarget and 4500 or 2000
	local ancients = allowStack and (dedicated(ctx) or ctx.clock >= 600)
		and (NPC.IsRanged(ctx.hero) or Entity.GetMaxHealth(ctx.hero) >= 1100)
	ctx.campAttempts = ctx.campAttempts or {}
	for key, expiry in pairs(ctx.campAttempts) do
		if type(expiry) ~= "number" or expiry < ctx.clock then ctx.campAttempts[key] = nil end
	end
	local route = geometry.route(ctx, ctx.lane)
	local best, score
	local candidates = 0
	for _, camp in pairs(JungleCampsManager.camps) do
		local sturdy = Entity.GetMaxHealth(ctx.hero) >= 900 or ctx.clock >= 300
		if camp.team_ == ctx.team and not camp.is_farmed_ and not coordination.campTaken(ctx, camp) and (camp.camp_type <= 1 or camp.camp_type == 2 and sturdy or ancients and camp.camp_type == 3)
			and ctx.distance(ctx.position, camp.position_) < radius then
			candidates = candidates + 1
			local members = units(ctx, camp)
			local pullable = camp.camp_type == 0 or camp.camp_type == 1 and dedicated(ctx)
			local kind = allowPull and pullable and (ctx.clock < 1200 or dedicated(ctx)) and route and "pull" or "stack"
			local goal, crossing = destination(ctx, camp, kind, route)
			if kind == "pull" and not goal and allowStack then
				kind = "stack"
				goal, crossing = destination(ctx, camp, kind, route)
			end
			if kind == "stack" and not allowStack then goal = nil end
			local key = tostring(camp.index_) .. ":" .. kind .. ":" .. math.floor(ctx.clock / (kind == "pull" and 30 or 60))
			if goal and not ctx.campAttempts[key] and not ctx.unsafePosition(goal) then
				local task = {camp = camp, kind = kind, destination = goal, crossing = crossing, route = route, key = key,
					spawn = (math.floor(ctx.clock / 60) + 1) * 60, phase = "stage", members = members}
				task.stage = camps.stand(ctx, camp, members, goal)
				task.trigger = trigger(ctx, task, members)
				local length = GridNav.IsTraversable(task.stage) and navigation.safePath(ctx, task.stage, 20)
				local arrival = length and length / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				local remaining = task.trigger and task.trigger - ctx.clock
				local waveAtTower = false
				if kind == "pull" then
					for _, creep in ipairs(ctx.creeps) do
						if live(creep) and not Entity.IsSameTeam(ctx.hero, creep) and ctx.distance(Entity.GetAbsOrigin(creep), Entity.GetAbsOrigin(route.front)) < 950 then waveAtTower = true; break end
					end
				end
				local slack = kind == "stack" and 15 or 5
				if arrival and remaining and remaining >= arrival - 0.2 and (lookahead or remaining <= arrival + slack) and not waveAtTower then
					local value = arrival + remaining * 0.3 + (kind == "stack" and 2 or 0)
					if not score or value < score then best, score = task, value end
				end
			end
		end
	end
	if not lookahead then
		ctx.campPlanNote = best and ("chose " .. best.kind) or (candidates == 0 and "no allied camp within " .. radius
			or "no camp timing reachable (" .. candidates .. " camps checked)")
	end
	return best
end

function camps.next(ctx)
	if ctx.campTask then return nil end
	local task = camps.plan(ctx, true)
	return task and task.stage, task
end

function camps.hurt(ctx, data)
	local task = ctx.campTask
	if task and task.phase == "aggro" and data.source == ctx.hero and data.target == task.target and data.damage > 0 then task.hit = true end
end

function camps.run(ctx)
	if not allowed(ctx) then if ctx.campTask then finish(ctx, "Camp interrupted by lane danger") end; return false end
	local task = ctx.campTask
	if not task then
		local farm = ctx.farmCandidate
		if farm and not farm.allied and farm.start < ctx.now + 1.2 then return false end
		task = camps.plan(ctx)
		if not task then return false end
		ctx.campTask, ctx.campAttempts[task.key] = task, ctx.clock + 65
		task.expires = ctx.now + math.max(0, task.trigger - ctx.clock) + 18
	end
	if ctx.now > task.expires or ctx.unsafePosition(task.destination) then return finish(ctx, "Camp attempt expired or became unsafe") end
	if task.phase == "stage" then
		local members = units(ctx, task.camp)
		if #members > 0 then
			task.members = members
			local revised = trigger(ctx, task, members)
			if not revised or revised < ctx.clock - 0.6 then return finish(ctx, "Missed camp timing") end
			task.trigger = revised
		elseif ctx.distance(ctx.position, task.camp.position_) < 500 then return finish(ctx, "Camp is empty") end
		if #members > 0 and not task.restaged then
			task.stage, task.restaged = camps.stand(ctx, task.camp, members, task.destination), true
		end
		if ctx.distance(ctx.position, task.stage) <= 60 and #members == 0 and not FogOfWar.IsPointVisible(task.camp.position_)
			and ctx.distance(task.stage, task.camp.position_) > 260 then
			task.stage = ctx.toward(task.stage, task.camp.position_, 120)
		end
		if ctx.distance(ctx.position, task.stage) > 60 then return ctx.move(task.stage, "Prepare support " .. task.kind, 40) end
		if ctx.clock < task.trigger then ctx.mode = "Wait for measured " .. task.kind .. " timing"; return ctx.stop() end
		local target = task.members[1]
		if not live(target) then return finish(ctx, "No visible neutral to pull") end
		local acted, issued = ctx.attack(target, "Aggro neutral for " .. task.kind)
		if issued then
			task.target, task.phase, task.aggroAt = target, "aggro", ctx.now
			task.ids = {}
			for _, unit in ipairs(task.members) do task.ids[Entity.GetIndex(unit)] = true end
		end
		return acted
	end
	if task.phase == "aggro" then
		if not live(task.target) then return finish(ctx, "Neutral target lost") end
		local facing = NPC.FindFacingNPC(task.target, nil, Enum.TeamType.TEAM_ENEMY, 30, 1000)
		local swing = ctx.hits and ctx.hits.ordered
		local released = swing and swing.target == task.target and swing.confirmed and swing.release <= ctx.now
		if task.hit or released or Hero.GetRecentDamage(ctx.hero) > 0 or facing == ctx.hero and NPC.IsRunning(task.target) then
			task.phase, task.followedAt = "drag", ctx.now
		elseif ctx.now - task.aggroAt > 1.5 then return finish(ctx, "Neutral did not follow attack")
		else ctx.mode = "Release aggro attack"; return true end
	end
	if task.kind == "pull" then
		for _, creep in ipairs(ctx.waves[ctx.lane]) do
			if live(creep) and NPC.IsAttacking(creep) then
				local target = NPC.FindFacingNPC(creep, nil, Enum.TeamType.TEAM_ENEMY, 35, NPC.GetAttackRange(creep) + 150)
				if live(target) and NPC.IsNeutral(target) and task.ids[Entity.GetIndex(target)] then return finish(ctx, "Pull connected to allied wave") end
			end
		end
	elseif ctx.clock >= task.spawn + 0.3 then
		for _, unit in ipairs(units(ctx, task.camp)) do
			if not task.ids[Entity.GetIndex(unit)] then return finish(ctx, "New neutral spawn confirmed") end
		end
		if ctx.clock > task.spawn + 2 then return finish(ctx, "Spawn not confirmed after stack") end
	end
	if ctx.distance(ctx.position, task.destination) < 65 then ctx.mode = "Hold neutral " .. task.kind .. " exit"; return ctx.stop() end
	return ctx.move(task.destination, task.kind == "pull" and "Pull neutrals into approaching wave" or "Stack: lead neutrals clear of spawn box", 40)
end

return camps
