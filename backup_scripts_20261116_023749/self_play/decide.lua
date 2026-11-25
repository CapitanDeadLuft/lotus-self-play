local decide = {}

decide.stick = 40
decide.dwell = 1.5
decide.dwellBonus = 60
decide.flipHold = 3
decide.flipBonus = 80
decide.cap = 845
decide.flipWindow = 6
decide.flipLimit = 4
decide.rest = 1.2
decide.probeRest = 0.6

local function evaluate(ctx, behavior)
	local ok, score = pcall(behavior.score, ctx)
	if not ok then
		ctx.decideError = behavior.name .. ": " .. tostring(score)
		return nil
	end
	return score
end

function decide.rank(ctx, behaviors)
	local current = ctx.decision and ctx.decision.name
	local list = {}
	local resting = ctx.decideRest or {}
	for index, behavior in ipairs(behaviors) do
		local score = evaluate(ctx, behavior)
		if score and score < decide.cap and ctx.now < (resting[behavior.name] or 0) then score = nil end
		if score then
			local effective = score
			if behavior.name == current and score < decide.cap then
				if behavior.sticky then effective = effective + decide.stick end
				local since = ctx.decision and ctx.decision.since or ctx.now
				if behavior.sticky and ctx.now - since < decide.dwell then effective = effective + decide.dwellBonus end
				local flip = ctx.decisionFlip
				if flip and ctx.now - flip.time < decide.flipHold and (flip.a == current or flip.b == current) then
					effective = effective + decide.flipBonus
				end
				effective = math.min(math.max(score, decide.cap), effective)
			end
			list[#list + 1] = {behavior = behavior, score = score, effective = effective, index = index}
		end
	end
	table.sort(list, function(a, b)
		if a.effective ~= b.effective then return a.effective > b.effective end
		return a.index < b.index
	end)
	return list
end

local function remember(ctx, name, score)
	local previous = ctx.decision
	if previous and previous.name == name then
		previous.score = score
		return previous
	end
	local history = ctx.decisionHistory or {}
	ctx.decisionHistory = history
	history[#history + 1] = {name = name, time = ctx.now}
	while #history > 0 and ctx.now - history[1].time > decide.flipWindow do table.remove(history, 1) end
	if #history >= decide.flipLimit then
		local a, b, alternating = history[#history].name, history[#history - 1].name, true
		for i = #history, math.max(1, #history - decide.flipLimit + 1), -1 do
			local expected = (#history - i) % 2 == 0 and a or b
			if history[i].name ~= expected then alternating = false; break end
		end
		if alternating and a ~= b then ctx.decisionFlip = {a = a, b = b, time = ctx.now} end
	end
	ctx.decision = {name = name, score = score, since = ctx.now}
	return ctx.decision
end

function decide.run(ctx, behaviors)
	local ranked = decide.rank(ctx, behaviors)
	local trace = {}
	for i = 1, math.min(4, #ranked) do
		trace[#trace + 1] = string.format("%s=%.0f", ranked[i].behavior.name, ranked[i].effective)
	end
	ctx.decisionTrace = table.concat(trace, " ")
	local top = {}
	for i = 1, math.min(3, #ranked) do top[i] = {name = ranked[i].behavior.name, score = ranked[i].effective} end
	ctx.decisionRanked = top
	local passed, skipped = {}, {}
	local current = ctx.decision and ctx.decision.name
	for _, entry in ipairs(ranked) do
		if entry.behavior.run(ctx) then
			remember(ctx, entry.behavior.name, entry.score)
			ctx.decisionRan = entry.behavior.name
			if #passed > 0 then ctx.decisionPassed = {names = table.concat(passed, ","), time = ctx.now} end
			ctx.decideRest = ctx.decideRest or {}
			for _, skip in ipairs(skipped) do
				ctx.decideRest[skip.behavior.name] = ctx.now + (skip.behavior.name == current and decide.rest or decide.probeRest)
			end
			return entry.behavior.name
		end
		if entry.score < decide.cap then skipped[#skipped + 1] = entry end
		if #passed < 3 then passed[#passed + 1] = entry.behavior.name end
	end
	ctx.decisionRan = nil
	return nil
end

return decide
