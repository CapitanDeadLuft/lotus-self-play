local prediction = {}

prediction.ttl = 0.1

local function library()
	local ok, value = pcall(function() return LIB_DAMAGE_PREDICTION end)
	if ok and type(value) == "table" then return value end
	return nil
end

function prediction.available()
	return library() ~= nil
end

local function alive(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function store(ctx)
	local cache = ctx.predictionCache
	if not cache then
		cache = {units = {}, attackersAt = -1, byTarget = {}}
		ctx.predictionCache = cache
	end
	return cache
end

function prediction.attacks(ctx, unit)
	local lib = library()
	if not lib or not alive(unit) then return nil end
	local cache = store(ctx)
	local key = Entity.GetIndex(unit)
	local cached = cache.units[key]
	if cached and ctx.now - cached.time < prediction.ttl then return cached.list or nil end
	local ok, result = pcall(function()
		lib:begin_outgoing(unit, Entity.GetHealth(unit), Entity.GetMaxHealth(unit))
		lib:collect_attacks(unit, true)
		lib:collect_predictions(unit)
		lib:collect_projectiles(unit)
		lib:collect_ability_projectiles(unit)
		lib:collect_ability_animations(unit)
		lib:collect_modifiers(unit)
		local entry = lib.targets and lib.targets[unit]
		local list = {}
		for _, attack in ipairs(entry and entry.attacks or {}) do
			local impact, amount = tonumber(attack.time_to_damage), tonumber(attack.damage)
			if impact and amount and amount > 0 then
				list[#list + 1] = {source = attack.attacker, impact = impact, minimum = amount,
					maximum = math.max(amount, tonumber(attack.max_damage) or amount),
					tower = attack.is_tower == true, risk = attack.is_risk == true, kind = attack.type}
			end
		end
		table.sort(list, function(a, b) return a.impact < b.impact end)
		return list
	end)
	if not ok then
		ctx.predictionError = tostring(result)
		result = nil
	end
	cache.units[key] = {time = ctx.now, list = result}
	return result
end

local function hostile(source, unit)
	return source and Entity.IsEntity(source) and not Entity.IsSameTeam(source, unit)
end

function prediction.incoming(ctx, unit, horizon, options)
	local list = prediction.attacks(ctx, unit)
	if not list then return nil end
	options = options or {}
	local total, count = 0, 0
	for _, attack in ipairs(list) do
		if attack.impact > ctx.now - 0.05 and attack.impact <= ctx.now + horizon
			and (not options.enemies or hostile(attack.source, unit))
			and (not options.allies or attack.source and Entity.IsEntity(attack.source) and Entity.IsSameTeam(attack.source, ctx.hero))
			and (not options.exclude or attack.source ~= options.exclude) then
			total = total + (options.low and attack.minimum or attack.maximum)
			count = count + 1
		end
	end
	return total, count
end

function prediction.attackers(ctx, target)
	local lib = library()
	if not lib or not target then return {} end
	local cache = store(ctx)
	if cache.attackersAt ~= ctx.now then
		cache.attackersAt, cache.byTarget = ctx.now, {}
		local ok, err = pcall(function()
			for unit, attack in pairs(lib.unit_attack or {}) do
				local victim = type(attack) == "table" and attack.target
				if alive(victim) and alive(unit) then
					local key = Entity.GetIndex(victim)
					local list = cache.byTarget[key] or {}
					list[#list + 1] = {source = unit, impact = tonumber(attack.time_to_damage), tower = attack.is_tower == true}
					cache.byTarget[key] = list
				end
			end
		end)
		if not ok then ctx.predictionError = tostring(err) end
	end
	return cache.byTarget[Entity.GetIndex(target)] or {}
end

function prediction.merge(ctx, target, events, exclude)
	local list = prediction.attacks(ctx, target)
	if not list then return events, 0 end
	local added = 0
	for _, attack in ipairs(list) do
		if attack.source ~= exclude and attack.impact > ctx.now then
			local duplicate = false
			for _, event in ipairs(events) do
				if event.source == attack.source and math.abs(event.impact - attack.impact) < 0.35 then duplicate = true; break end
			end
			if not duplicate then
				events[#events + 1] = {source = attack.source, impact = attack.impact, minimum = attack.minimum, maximum = attack.maximum, predicted = true}
				added = added + 1
			end
		end
	end
	if added > 0 then table.sort(events, function(a, b) return a.impact < b.impact end) end
	return events, added
end

return prediction
