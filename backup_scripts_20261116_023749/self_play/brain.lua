local brain = {}

brain.halfLife = 300
brain.deathWeight = 0.28
brain.feedWindow = 420
brain.deathZone = 1600
brain.deathMemory = 200

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function state(ctx)
	local s = ctx.brain
	if not s then
		s = {deaths = {}, caution = 0, nextUpdate = 0, alive = true, zones = {}}
		ctx.brain = s
	end
	return s
end

function brain.died(ctx)
	local s = state(ctx)
	local killers = {}
	for _, enemy in ipairs(ctx.enemies or {}) do
		if visible(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1600 then killers[#killers + 1] = Entity.GetIndex(enemy) end
	end
	s.deaths[#s.deaths + 1] = {time = ctx.now, position = ctx.position, clock = ctx.clock, killers = killers}
end

function brain.update(ctx)
	local s = state(ctx)
	local alive = Entity.IsAlive(ctx.hero)
	if s.alive and not alive then brain.died(ctx) end
	s.alive = alive
	if ctx.now < s.nextUpdate then return s end
	s.nextUpdate = ctx.now + 0.5
	local caution, recent = 0, 0
	for _, death in ipairs(s.deaths) do
		local age = ctx.now - death.time
		caution = caution + brain.deathWeight * 0.5 ^ (age / brain.halfLife)
		if age < brain.feedWindow then recent = recent + 1 end
	end
	local win = ctx.winModel and ctx.winModel.smooth
	if win then caution = caution + math.max(0, 0.5 - win) * 0.6 end
	local strategy = ctx.strategy
	if strategy and strategy.phase ~= "laning" then caution = caution + math.max(0, strategy.enemiesMissing - 1) * 0.06 end
	if strategy and strategy.pushWindow then caution = caution - 0.15 end
	s.caution = math.max(0, math.min(1, caution))
	s.feeding = recent >= 3 or recent >= 2 and ctx.role <= 3 and ctx.clock < 1200
	s.recentDeaths = recent
	s.zones = {}
	for _, death in ipairs(s.deaths) do
		if ctx.now - death.time < brain.deathMemory then s.zones[#s.zones + 1] = {position = death.position, radius = brain.deathZone, weight = 1} end
	end
	return s
end

function brain.caution(ctx)
	return ctx.brain and ctx.brain.caution or 0
end

function brain.feeding(ctx)
	return ctx.brain and ctx.brain.feeding or false
end

function brain.danger(ctx, point, ignore)
	local danger = 0
	for _, enemy in ipairs(ctx.enemies or {}) do
		if enemy ~= ignore and visible(enemy) and not NPC.IsIllusion(enemy) then
			local distance = ctx.distance(point, Entity.GetAbsOrigin(enemy))
			local reach = NPC.GetAttackRange(enemy) + 1100
			if distance < reach then danger = danger + (1 - distance / reach) * 1.5 end
		end
	end
	local strategy = ctx.strategy
	for _, enemy in ipairs(strategy and strategy.known or {}) do
		if enemy.age > 0.5 and (not ignore or enemy.unit ~= ignore) then
			local spread = 900 + enemy.age * math.min(enemy.speed or 300, 350) * 0.7
			local distance = ctx.distance(point, enemy.position)
			if distance < spread then danger = danger + (1 - distance / spread) * math.max(0.25, 1 - enemy.age / 30) end
		end
	end
	for _, tower in ipairs(ctx.towers or {}) do
		if Entity.IsEntity(tower) and Entity.IsAlive(tower) and not Entity.IsSameTeam(ctx.hero, tower) then
			local distance = ctx.distance(point, Entity.GetAbsOrigin(tower))
			if distance < 1500 then danger = danger + (1 - distance / 1500) * 1.2 end
		end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		local distance = ctx.distance(point, arrival.position)
		if distance < 1800 then danger = danger + (1 - distance / 1800) end
	end
	for _, zone in ipairs(ctx.brain and ctx.brain.zones or {}) do
		local distance = ctx.distance(point, zone.position)
		if distance < zone.radius then danger = danger + (1 - distance / zone.radius) * 0.6 * zone.weight end
	end
	if strategy and strategy.phase ~= "laning" then
		local depth = ctx.distance(point, ctx.home) / math.max(1, ctx.distance(point, ctx.home) + ctx.distance(point, ctx.enemyHome))
		if depth > 0.5 then danger = danger + (depth - 0.5) * 2 * (0.4 + math.max(0, (strategy.enemiesMissing or 0) - 1) * 0.25) end
	end
	return danger
end

function brain.limit(ctx)
	local caution = brain.caution(ctx)
	local limit = 1.1 - caution * 0.7
	if brain.feeding(ctx) then limit = math.min(limit, 0.35) end
	return math.max(0.2, limit)
end

function brain.safeFarm(ctx, point)
	return brain.danger(ctx, point) <= brain.limit(ctx)
end

function brain.retreatShift(ctx)
	return brain.caution(ctx) * 0.15 + (brain.feeding(ctx) and 0.08 or 0)
end

function brain.helping(ctx)
	local settings = ctx.settings or {}
	if settings.fights == false or (settings.mode or 0) ~= 0 then return nil end
	if ctx.helpRotation then return ctx.helpRotation end
	local session = ctx.fightSession
	if session and #(session.members or {}) > 0 then return session end
	local task = ctx.teamTask
	if task and task.fighting then return task end
	return nil
end

brain.helpFloor = 0.3

function brain.aggressionShift(ctx)
	return -brain.caution(ctx) * 35 - (brain.feeding(ctx) and 15 or 0)
end

function brain.summary(ctx)
	local s = ctx.brain
	if not s then return "no data" end
	return string.format("caution=%.2f feeding=%s recentDeaths=%d deaths=%d limit=%.2f", s.caution, tostring(s.feeding), s.recentDeaths or 0, #s.deaths, brain.limit(ctx))
end

return brain
