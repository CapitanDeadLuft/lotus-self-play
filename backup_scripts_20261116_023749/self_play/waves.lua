local waves = {}

local function manager()
	return type(LaneGroupsManager) == "table" and LaneGroupsManager or nil
end

local function valid(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function position(group)
	local point = group.position_
	if group.predicted_position and (group.predicted_position.x ~= 0 or group.predicted_position.y ~= 0) then point = group.predicted_position end
	return point
end

function waves.allied(ctx)
	local lgm = manager()
	if not lgm or type(lgm.visible_ally) ~= "table" then return nil end
	local lanes, found = {{}, {}, {}}, false
	for _, group in pairs(lgm.visible_ally) do
		local lane = tonumber(group.lane)
		if lanes[lane] then
			for _, creep in pairs(group.creeps or {}) do
				local unit = creep.ref
				if valid(unit) and not creep.marked_dead and not NPC.IsWaitingToSpawn(unit) then
					lanes[lane][#lanes[lane] + 1], found = unit, true
				end
			end
		end
	end
	return found and lanes or nil
end

function waves.enemy(ctx, lane)
	local lgm = manager()
	local result = {}
	if not lgm then return result end
	for _, list in ipairs({lgm.visible_enemy, lgm.invisible_enemy}) do
		for _, group in pairs(type(list) == "table" and list or {}) do
			local groupLane = tonumber(group.lane)
			local point = position(group)
			if point and (not lane or groupLane == lane) then
				local count, units = 0, {}
				for _, creep in pairs(group.creeps or {}) do
					if not creep.marked_dead then
						count = count + 1
						if valid(creep.ref) then units[#units + 1] = creep.ref end
					end
				end
				if count > 0 then
					result[#result + 1] = {lane = groupLane, position = point, count = count, visible = list == lgm.visible_enemy,
						path = group.path or group.lane_path, siege = group.has_siege == true, units = units}
				end
			end
		end
	end
	return result
end

function waves.path(ctx, lane)
	local lgm = manager()
	if not lgm then return nil end
	for _, list in ipairs({lgm.visible_ally, lgm.w2s_ally}) do
		for _, group in pairs(type(list) == "table" and list or {}) do
			if tonumber(group.lane) == lane and type(group.lane_path) == "table" and #group.lane_path >= 2 then return group.lane_path end
		end
	end
	return nil
end

return waves
