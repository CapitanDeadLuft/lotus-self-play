local spots = {}

spots.vision = 1500
spots.overlap = 1450
spots.campMargin = 170

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function ground(x, y)
	return Vector(x, y, World.GetGroundZ(x, y))
end

local function camps()
	return type(JungleCampsManager) == "table" and type(JungleCampsManager.camps) == "table" and JungleCampsManager.camps or {}
end

function spots.campAt(point, team, margin)
	margin = margin or spots.campMargin
	for _, camp in pairs(camps()) do
		local box = camp.box
		if box and box.min and box.max and (not team or tonumber(camp.team_) == team)
			and point.x >= box.min.x - margin and point.x <= box.max.x + margin
			and point.y >= box.min.y - margin and point.y <= box.max.y + margin then return camp end
	end
	return nil
end

function spots.clear(ctx, point)
	for _ = 1, 6 do
		local camp = spots.campAt(point)
		if not camp then return point end
		local center = camp.position_
		local dx, dy = point.x - center.x, point.y - center.y
		local length = math.sqrt(dx * dx + dy * dy)
		if length < 1 then dx, dy, length = ctx.home.x - center.x, ctx.home.y - center.y, 1 end
		local length2 = math.sqrt(dx * dx + dy * dy)
		local box = camp.box
		local reach = math.max(box.max.x - box.min.x, box.max.y - box.min.y) * 0.5 + spots.campMargin + 60
		point = ground(center.x + dx / length2 * reach, center.y + dy / length2 * reach)
	end
	return nil
end

local function treeBlocked(point)
	if not Trees or not Trees.InRadius then return false end
	local trees = Trees.InRadius(point, 70, true)
	if trees and #trees > 0 then return true end
	if TempTrees and TempTrees.InRadius then
		local temp = TempTrees.InRadius(point, 70)
		if temp and #temp > 0 then return true end
	end
	return false
end

function spots.allied(ctx)
	local list = {}
	for _, unit in ipairs(ctx.worldNPCs or {}) do
		if live(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.GetUnitName(unit) == "npc_dota_observer_wards" then
			list[#list + 1] = Entity.GetAbsOrigin(unit)
		end
	end
	for _, entry in ipairs(ctx.placedWards or {}) do
		if ctx.now - entry.time < 360 then list[#list + 1] = entry.position end
	end
	return list
end

local function towers(ctx, allied)
	local list = {}
	for _, tower in ipairs(ctx.towers or {}) do
		if live(tower) and Entity.IsSameTeam(ctx.hero, tower) == allied then list[#list + 1] = Entity.GetAbsOrigin(tower) end
	end
	return list
end

local function laneFront(ctx, lane)
	local ours, theirs
	local own, enemy = towers(ctx, true), towers(ctx, false)
	local function laneOf(p)
		return math.abs(p.x - p.y) < 2000 and 2 or p.y > p.x and 1 or 3
	end
	for _, p in ipairs(own) do
		if laneOf(p) == lane and (not ours or ctx.distance(p, ctx.enemyHome) < ctx.distance(ours, ctx.enemyHome)) then ours = p end
	end
	for _, p in ipairs(enemy) do
		if laneOf(p) == lane and (not theirs or ctx.distance(p, ctx.home) < ctx.distance(theirs, ctx.home)) then theirs = p end
	end
	if ours and theirs then return Vector((ours.x + theirs.x) * 0.5, (ours.y + theirs.y) * 0.5, 0) end
	return ours or theirs
end

local function toward(ctx, from, to, distance)
	local p = ctx.toward(from, to, distance)
	return Vector(p.x, p.y, 0)
end

function spots.interests(ctx, anchor)
	local list = {}
	local function add(point, weight, label)
		if point then list[#list + 1] = {position = Vector(point.x, point.y, World.GetGroundZ(point.x, point.y)), weight = weight, label = label} end
	end
	local center = Vector(0, 0, 0)
	local winning = ctx.winModel and ctx.winModel.smooth or 0.5
	if ctx.clock < 720 then
		local front = laneFront(ctx, ctx.lane) or anchor
		if front then
			add(front, 1, "lane")
			if ctx.lane == 2 then
				add(Vector(front.x - 1100, front.y + 1100, 0), 2, "mid flank")
				add(Vector(front.x + 1100, front.y - 1100, 0), 2, "mid flank")
			else
				add(toward(ctx, front, center, 1300), 3, "gank route")
				add(toward(ctx, toward(ctx, front, center, 900), ctx.enemyHome, 900), 2, "enemy jungle exit")
			end
		end
	end
	for _, rune in pairs(ctx.runeSpots or {}) do add(rune, ctx.clock < 720 and 1 or 1.5, "rune") end
	if ctx.clock >= 600 then
		for _, camp in pairs(camps()) do
			local team = tonumber(camp.team_)
			local enemyCamp = team and team ~= ctx.team
			if enemyCamp and winning >= 0.5 then
				add(toward(ctx, camp.position_, ctx.home, 600), winning >= 0.62 and 1.5 or 0.8, "enemy jungle")
			elseif not enemyCamp and winning < 0.55 then
				add(toward(ctx, camp.position_, ctx.enemyHome, 700), 0.8, "own jungle entrance")
			end
		end
		local ally = ctx.escortTarget
		if live(ally) then add(toward(ctx, Entity.GetAbsOrigin(ally), ctx.enemyHome, 1300), 2.5, "ahead of core") end
		if ctx.teamTask and ctx.teamTask.goal then add(ctx.teamTask.goal, 2, "objective") end
	end
	if #list == 0 and anchor then add(anchor, 1, "anchor") end
	return list
end

local function elevation(point)
	local sum, count = 0, 0
	for index = 0, 7 do
		local angle = index * math.pi / 4
		sum, count = sum + World.GetGroundZ(point.x + math.cos(angle) * 260, point.y + math.sin(angle) * 260), count + 1
	end
	return point.z - sum / count
end

function spots.score(ctx, point, interests, existing, ownTowers, safe)
	if spots.campAt(point, ctx.team) or spots.campAt(point, nil, 40) then return nil, "camp" end
	if treeBlocked(point) then return nil, "tree" end
	if ctx.distance(point, ctx.home) < 3200 then return nil, "base" end
	for _, ward in ipairs(existing) do
		if ctx.distance(point, ward) < spots.overlap then return nil, "overlap" end
	end
	if safe and not safe(point) then return nil, "unsafe" end
	local lift = elevation(point)
	local high = lift > 60
	local coverage = 0
	for _, entry in ipairs(interests) do
		local distance = ctx.distance(point, entry.position)
		local reach = high and spots.vision or spots.vision * 0.75
		if distance <= reach then coverage = coverage + entry.weight * (1 - distance / (reach * 1.6)) end
	end
	if coverage <= 0 then return nil, "no coverage" end
	local redundant = 0
	for _, tower in ipairs(ownTowers) do
		if ctx.distance(point, tower) < 1700 then redundant = redundant + 1 end
	end
	local travel = ctx.distance(ctx.position, point)
	return coverage * 100 + math.min(4, math.max(0, lift) / 60) * 18 - redundant * 45 - travel * 0.012
end

function spots.helper(ctx)
	local cached = ctx.wardHelperData
	if cached and ctx.now < cached.expires then return cached end
	local result = {observer = {}, sentry = {}, expires = ctx.now + 20}
	ctx.wardHelperData = result
	if not XHelpers or not XHelpers.GetScript then return result end
	local ok, helper = pcall(XHelpers.GetScript, "WardHelper")
	if not ok or type(helper) ~= "table" then return result end
	local function read(entry)
		local p = type(entry) == "table" and entry.position
		local x, y = p and tonumber(p.x), p and tonumber(p.y)
		if not x or not y then return nil end
		return ground(x, y), tonumber(entry.team) or 0
	end
	for _, entry in pairs(type(helper.positions_observer) == "table" and helper.positions_observer or {}) do
		local point, team = read(entry)
		if point and (team == 0 or team == ctx.team) and not entry.at_base then
			local survivability = tonumber(entry.survivability) or 50
			local popularity = tonumber(entry.matches_pct) or 0
			result.observer[#result.observer + 1] = {position = point, survivability = survivability, popularity = popularity,
				bonus = survivability / 100 * 35 + math.min(35, popularity * 2.5)}
		end
	end
	for _, entry in pairs(type(helper.positions_sentry_camp_block) == "table" and helper.positions_sentry_camp_block or {}) do
		local point, team = read(entry)
		if point then result.sentry[#result.sentry + 1] = {position = point, team = team, enemyCamp = team ~= 0 and team ~= ctx.team} end
	end
	if #result.observer == 0 then result.expires = ctx.now + 2 end
	return result
end

function spots.choose(ctx, anchor, range, safe, helperSpots)
	local interests = spots.interests(ctx, anchor)
	local existing = spots.allied(ctx)
	local ownTowers = towers(ctx, true)
	local candidates = {}
	for _, spot in ipairs(helperSpots or {}) do
		if type(spot) == "table" and spot.position then candidates[#candidates + 1] = {point = spot.position, bonus = spot.bonus or 0, helper = true}
		else candidates[#candidates + 1] = {point = spot, bonus = 0, helper = true} end
	end
	for _, entry in ipairs(interests) do
		local origin = entry.position
		candidates[#candidates + 1] = {point = origin, bonus = 0}
		for radius = 250, 1050, 200 do
			for index = 0, 11 do
				local angle = index * math.pi / 6
				candidates[#candidates + 1] = {point = ground(origin.x + math.cos(angle) * radius, origin.y + math.sin(angle) * radius), bonus = 0}
			end
		end
	end
	local best, bestScore, fromHelper
	local checked = 0
	for _, candidate in ipairs(candidates) do
		local point = candidate.point
		if ctx.distance(ctx.position, point) < 5500 then
			local approach = ctx.toward(point, ctx.position, math.max(100, range - 80))
			if GridNav.IsTraversable(approach) then
				checked = checked + 1
				local score = spots.score(ctx, point, interests, existing, ownTowers, safe)
				if score then score = score + candidate.bonus end
				if score and (not bestScore or score > bestScore) then best, bestScore, fromHelper = point, score, candidate.helper end
			end
		end
	end
	ctx.wardPlan = {interests = #interests, checked = checked, score = bestScore, helper = fromHelper == true, helperSpots = #(helperSpots or {})}
	return best, bestScore
end

return spots
