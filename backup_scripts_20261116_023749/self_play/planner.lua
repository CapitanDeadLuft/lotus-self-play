local planner = {}

local fallback = {
	{"magic_wand", "power_treads", "maelstrom", "black_king_bar", "manta", "greater_crit", "satanic"},
	{"magic_wand", "arcane_boots", "witch_blade", "black_king_bar", "shivas_guard", "sheepstick"},
	{"magic_wand", "phase_boots", "blink", "pipe", "black_king_bar", "assault"},
	{"magic_wand", "arcane_boots", "force_staff", "glimmer_cape", "lotus_orb", "sheepstick"},
	{"magic_wand", "tranquil_boots", "glimmer_cape", "force_staff", "ghost", "lotus_orb"},
}

function planner.hasFlag(mask, flag)

	return flag > 0 and math.floor(mask / flag) % 2 == 1
end

function planner.levelValue(values, level)
	if not values or #values == 0 then return 0 end
	return values[math.max(1, math.min(level, #values))]
end

function planner.contains(items, parent, child, visited)
	if parent == child then return true end
	local record = items[parent]
	if not record then return false end
	visited = visited or {}
	if visited[parent] then return false end
	visited[parent] = true
	for _, part in ipairs(record.components) do
		if planner.contains(items, part, child, visited) then return true end
	end
	return false
end

function planner.owns(items, inventory, name)
	for owned, count in pairs(inventory) do
		if count > 0 and planner.contains(items, owned, name) then return true end
	end
	return false
end

function planner.componentCount(items, inventory, name)
	local function count(key, visiting)
		if key == name then return 1 end
		if visiting[key] or not items[key] then return 0 end
		visiting[key] = true
		local total = 0
		for _, part in ipairs(items[key].components) do total = total + count(part, visiting) end
		visiting[key] = nil
		return total
	end
	local total = 0
	for key, quantity in pairs(inventory) do total = total + quantity * count(key, {}) end
	return total
end

function planner.missing(items, name, inventory)
	local available, leaves, visiting = {}, {}, {}
	for key, count in pairs(inventory) do available[key] = count end
	local function expand(key)
		if (available[key] or 0) > 0 then
			available[key] = available[key] - 1
			return true
		end
		local record = items[key]
		if not record or record.neutral or visiting[key] then return false end
		if #record.components == 0 then
			if record.cost <= 0 then return false end
			leaves[#leaves + 1] = key
			return true
		end
		visiting[key] = true
		for _, component in ipairs(record.components) do
			if not expand(component) then return false end
		end
		visiting[key] = nil
		return true
	end
	if not expand(name) then return nil end
	return leaves
end

function planner.gameItems(items, kv)
	local result = {}
	for name, record in pairs(items) do
		local copy = {}
		for key, value in pairs(record) do copy[key] = value end
		local current = kv["item_" .. name]
		if current then
			copy.id = tonumber(current.ID) or copy.id
			copy.cost = tonumber(current.ItemCost) or copy.cost
		end
		result[name] = copy
	end
	for name, recipe in pairs(kv) do
		local parent = type(recipe) == "table" and recipe.ItemResult and recipe.ItemResult:gsub("^item_", "")
		local requirement = type(recipe) == "table" and recipe.ItemRequirements and recipe.ItemRequirements["01"]
		if parent and result[parent] and type(requirement) == "string" then
			local parts, valid = {}, true
			for part in requirement:gmatch("[^;]+") do
				local trimmed = part:match("^%s*(.-)%s*$")
				local key = trimmed:match("^item_([%w_]+)%*?$")
				if not key or not result[key] then valid = false; break end
				parts[#parts + 1] = key
			end
			local recipeName = name:gsub("^item_", "")
			if valid and #parts > 0 then
				if tonumber(recipe.ItemCost or "0") > 0 and result[recipeName] then parts[#parts + 1] = recipeName end
				result[parent].components = parts
			end
		end
	end
	return result
end

function planner.build(catalog, guide, role, clock)
	local result, seen = {}, {}
	local function append(name)
		local item = catalog.items[name]
		if seen[name] or not item or item.neutral or item.cost <= 0 then return end
		if not planner.missing(catalog.items, name, {}) then return end
		seen[name] = true
		result[#result + 1] = name
	end
	if guide then
		for _, group in ipairs(guide.groups) do
			local start = group.title:find("Starting", 1, true)
			if not start or clock < 120 then
				local limit = group.title:lower():find("late", 1, true) and 2 or 8
				for index, name in ipairs(group.items) do
					if index <= limit then append(name) end
				end
			end
		end
	end
	if #result == 0 then
		if clock < 120 then append("tango") end
		for _, name in ipairs(fallback[role]) do append(name) end
	end
	return result
end

function planner.lastHit(health, incoming, damage, allied, maxHealth)
	if allied and health > maxHealth * 0.5 then return false end
	local predicted = health - incoming
	return predicted > 0 and predicted <= damage
end

function planner.closestApproach(dx, dy, vx, vy, horizon)
	local speedSquared = vx * vx + vy * vy
	if speedSquared < 1 then return 0, math.sqrt(dx * dx + dy * dy) end
	local time = math.max(0, math.min(horizon, -(dx * vx + dy * vy) / speedSquared))
	local x, y = dx + vx * time, dy + vy * time
	return time, math.sqrt(x * x + y * y)
end

function planner.pullWindow(clock, second, travel)
	if clock < 60 then return false end
	local remaining = (second - clock % 60 + 60) % 60
	return remaining <= travel + 3 and remaining >= math.max(0, travel - 2), remaining
end

function planner.roleScores(hero)
	local tags = {}
	for _, name in ipairs(hero and hero.roles or {}) do tags[name] = true end
	local support = tags.Support and not tags.Carry
	return {
		(tags.Carry and 8 or 0) + (hero and hero.attribute == "agi" and 2 or 0) - (support and 6 or 0),
		(tags.Nuker and 5 or 0) + (tags.Escape and 2 or 0) + (tags.Nuker and tags.Carry and 4 or 0)
			+ (hero and hero.attribute == "int" and not tags.Support and 3 or 0) - (support and 6 or 0),
		(tags.Durable and 6 or 0) + (tags.Initiator and 4 or 0),
		(tags.Support and 5 or 0) + (tags.Disabler and 4 or 0) + (tags.Initiator and 2 or 0) + (tags.Escape and 1 or 0),
		(tags.Support and 8 or 0) + (support and 3 or 0) - (tags.Carry and 3 or 0)
			- (tags.Initiator and 1 or 0) - (tags.Escape and 1 or 0),
	}
end

function planner.assignRoles(heroes)

	table.sort(heroes, function(a, b) return a.id < b.id end)
	local best, bestScore, selected, used = {}, -math.huge, {}, {}
	local function search(index, score)
		if index > #heroes then
			if score > bestScore then
				bestScore = score
				for key, value in pairs(selected) do best[key] = value end
			end
			return
		end
		for role = 1, 5 do
			if not used[role] then
				used[role], selected[heroes[index].id] = true, role
				search(index + 1, score + heroes[index].scores[role])
				used[role] = nil
			end
		end
	end
	search(1, 0)
	return best
end

return planner
