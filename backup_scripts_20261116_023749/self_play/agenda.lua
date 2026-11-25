local agenda = {}

agenda.slack = 2

local function entries(ctx)
	ctx.agenda = ctx.agenda or {}
	return ctx.agenda
end

function agenda.travel(ctx, from, to)
	return ctx.distance(from, to) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
end

function agenda.book(ctx, key, entry)
	local list = entries(ctx)
	local previous = list[key]
	entry.key, entry.booked = key, previous and previous.booked or ctx.now
	list[key] = entry
	return entry
end

function agenda.cancel(ctx, key)
	entries(ctx)[key] = nil
end

function agenda.prune(ctx)
	for key, entry in pairs(entries(ctx)) do
		if ctx.now > entry.at + (entry.window or 3) then entries(ctx)[key] = nil end
	end
end

function agenda.leave(ctx, entry, from)
	return entry.at - agenda.travel(ctx, from or ctx.position, entry.position) - agenda.slack
end

function agenda.due(ctx, key)
	local entry = entries(ctx)[key]
	return entry ~= nil and ctx.now >= agenda.leave(ctx, entry)
end

function agenda.fits(ctx, seconds, finish, worth, ignore)
	agenda.prune(ctx)
	for key, entry in pairs(entries(ctx)) do
		if key ~= ignore and (entry.value or 0) > (worth or 0) then
			local arrive = ctx.now + math.max(0, seconds) + agenda.travel(ctx, finish or ctx.position, entry.position)
			if arrive > entry.at + (entry.late or 0) then return false, entry end
		end
	end
	return true
end

function agenda.free(ctx)
	agenda.prune(ctx)
	local earliest
	for _, entry in pairs(entries(ctx)) do
		local leave = agenda.leave(ctx, entry) - ctx.now
		if not earliest or leave < earliest then earliest = leave end
	end
	return earliest
end

function agenda.describe(ctx)
	local parts = {}
	for _, entry in pairs(entries(ctx)) do
		parts[#parts + 1] = string.format("%s in %.0fs (leave in %.0fs) worth %.0fg", entry.label or entry.key, entry.at - ctx.now,
			agenda.leave(ctx, entry) - ctx.now, entry.value or 0)
	end
	table.sort(parts)
	return table.concat(parts, "; ")
end

return agenda
