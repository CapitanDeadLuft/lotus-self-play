local flips = {}

flips.window = 4
flips.prefixes = {"Stop short, enemies ahead: ", "Stop short, enemy heroes ahead: ", "Stop short, spot unreachable: ", "Stop outside enemy tower: ", "Regen: "}
flips.suffixes = {" (avoid enemy creeps)", " (outside enemy reach)", " (safer spot)", ": no safe route", ": path obstructed", ": cover", ": countdown"}

function flips.family(mode)
	mode = tostring(mode or "")
	for _, prefix in ipairs(flips.prefixes) do
		if mode:sub(1, #prefix) == prefix then mode = mode:sub(#prefix + 1) end
	end
	for _, suffix in ipairs(flips.suffixes) do
		if #mode > #suffix and mode:sub(-#suffix) == suffix then mode = mode:sub(1, #mode - #suffix) end
	end
	if mode:sub(1, 8) == "Last hit" or mode:sub(1, 12) == "Lane spacing" or mode:sub(1, 4) == "Deny"
		or mode == "Advance with wave" or mode == "Farm lane wave" then return "Lane farming" end
	if mode:sub(1, 6) == "block." then return "Creep block" end
	local head = mode:match("^([^:]+):")
	return head or mode
end

function flips.state(ctx)
	ctx.flips = ctx.flips or {history = {}, counts = {}, logged = {}, notes = {}, total = 0}
	return ctx.flips
end

function flips.observe(ctx)
	if not ctx or not ctx.mode then return end
	local state = flips.state(ctx)
	local family = flips.family(ctx.mode)
	local history = state.history
	local last = history[#history]
	if last and last.family == family then return end
	history[#history + 1] = {family = family, time = ctx.now, decision = ctx.decisionRan}
	while #history > 8 or #history > 0 and ctx.now - history[1].time > 12 do table.remove(history, 1) end
	local n = #history
	if n < 3 then return end
	local a, b, c = history[n - 2], history[n - 1], history[n]
	if a.family ~= c.family or c.time - a.time > flips.window then return end
	local first, second = a.family, b.family
	if second < first then first, second = second, first end
	local key = first .. " <-> " .. second
	state.counts[key] = (state.counts[key] or 0) + 1
	state.total = state.total + 1
	if ctx.now >= (state.logged[key] or 0) then
		state.logged[key] = ctx.now + 3
		state.notes[#state.notes + 1] = string.format("%s -> %s -> %s in %.1fs (decide %s/%s) seen=%d",
			a.family, b.family, c.family, c.time - a.time, tostring(b.decision), tostring(c.decision), state.counts[key])
		while #state.notes > 10 do table.remove(state.notes, 1) end
	end
end

function flips.summary(ctx, limit)
	local state = flips.state(ctx)
	local list = {}
	for key, count in pairs(state.counts) do list[#list + 1] = {key = key, count = count} end
	table.sort(list, function(a, b) return a.count > b.count end)
	local parts = {}
	for i = 1, math.min(limit or 5, #list) do parts[#parts + 1] = string.format("%dx %s", list[i].count, list[i].key) end
	return string.format("total=%d %s", state.total, table.concat(parts, " | "))
end

return flips
