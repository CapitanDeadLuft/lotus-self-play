local choice = {}

choice.settle = 25
choice.confirm = 6
choice.cooldown = 60

function choice.laneOf(ctx, position)
	if ctx.distance(position, ctx.home) < 3500 or ctx.distance(position, ctx.enemyHome) < 3500 then return nil end
	if math.abs(position.x - position.y) < 2000 then return 2 end
	return position.y > position.x and 1 or 3
end

local function ally(ctx, unit)
	return unit ~= ctx.hero and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not NPC.IsIllusion(unit)
		and Entity.IsSameTeam(ctx.hero, unit)
end

function choice.counts(ctx)
	ctx.laneSeen = ctx.laneSeen or {}
	local counts, present = {0, 0, 0}, {}
	for _, unit in ipairs(ctx.allies) do
		local id = Entity.GetIndex(unit)
		local role = ctx.runeRoles and ctx.runeRoles[id]
		if ally(ctx, unit) and role ~= 2 then
			present[id] = true
			local lane = choice.laneOf(ctx, Entity.GetAbsOrigin(unit))
			local seen = ctx.laneSeen[id]
			if not seen or seen.lane ~= lane then
				seen = {lane = lane, since = ctx.now}
				ctx.laneSeen[id] = seen
			end
			if lane and ctx.now - seen.since >= choice.settle then counts[lane] = counts[lane] + 1 end
		end
	end
	for id in pairs(ctx.laneSeen) do if not present[id] then ctx.laneSeen[id] = nil end end
	return counts
end

function choice.update(ctx)
	if ctx.role < 4 or (ctx.laneSetting or 0) ~= 0 or ctx.clock < 30 or ctx.clock >= 480 then return nil end
	if ctx.fightSession or ctx.retreating or ctx.intent and ctx.intent.kind == "hero" then ctx.lanePending = nil; return nil end
	if ctx.now < (ctx.nextLaneChoice or 0) then return nil end
	ctx.nextLaneChoice = ctx.now + 1
	local counts = choice.counts(ctx)
	local current = ctx.lane
	local own = counts[current] or 0
	local best, bestCount
	if own >= 2 or own == 0 then
		for _, lane in ipairs({1, 3}) do
			if lane ~= current and counts[lane] == 1 and (not best or lane == (ctx.team == 2 and 1 or 3)) then best, bestCount = lane, counts[lane] end
		end
	end
	if not best then ctx.lanePending = nil; return nil end
	local pending = ctx.lanePending
	if not pending or pending.lane ~= best then
		ctx.lanePending = {lane = best, since = ctx.now}
		return nil
	end
	if ctx.now - pending.since < choice.confirm or ctx.now < (ctx.laneSwitchUntil or 0) then return nil end
	ctx.laneStatus = {time = ctx.now, text = string.format("switch %d -> %d (allies there %d, here %d)", current, best, bestCount, own)}
	ctx.lane, ctx.waveAnchor, ctx.waveLane, ctx.regroupTask, ctx.blockState = best, nil, nil, nil, nil
	ctx.lanePending, ctx.laneSwitchUntil = nil, ctx.now + choice.cooldown
	return best
end

return choice
