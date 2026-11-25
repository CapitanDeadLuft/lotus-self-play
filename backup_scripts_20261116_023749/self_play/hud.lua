local hud = {}
local localization = require("self_play.localization")

hud.name = "BOTCAST"

local fonts = {}
local palette = {}
local cache = {}

local function buildPalette()
	return {
		text = Color(236, 240, 246, 255),
		dim = Color(170, 180, 194, 235),
		label = Color(128, 140, 158, 235),
		shadow = Color(0, 0, 0, 200),
		ours = Color(92, 205, 132, 255),
		theirs = Color(226, 88, 80, 255),
		even = Color(232, 190, 90, 255),
		track = Color(0, 0, 0, 120),
		line = Color(255, 255, 255, 40),
		accent = Color(255, 196, 72, 255),
		goal = Color(120, 190, 255, 170),
		target = Color(226, 88, 80, 220),
		focus = Color(232, 190, 90, 200),
	}
end

function hud.init()
	palette = buildPalette()
	local flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
	fonts.text = Render.LoadFont("Bahnschrift", flags, 400)
	fonts.bold = Render.LoadFont("Bahnschrift", flags, 700)
end

local function text(key) return localization.text(key) end

local function write(font, size, value, x, y, color, align)
	local width = 0
	if align then
		width = Render.TextSize(font, size, value).x
		if align == "right" then x = x - width elseif align == "center" then x = x - width / 2 end
	end
	Render.Text(font, size, value, Vec2(x + 1, y + 1), palette.shadow)
	Render.Text(font, size, value, Vec2(x, y), color)
	return width
end

local function fit(font, size, value, width)
	if Render.TextSize(font, size, value).x <= width then return value end
	local cut = #value
	while cut > 4 and Render.TextSize(font, size, value:sub(1, cut) .. "...").x > width do cut = cut - 1 end
	return value:sub(1, cut) .. "..."
end

function hud.trend(history, now, window)
	local latest = history[#history]
	if not latest then return 0 end
	for index = #history, 1, -1 do
		if now - history[index].time >= window then return latest.chance - history[index].chance end
	end
	return latest.chance - history[1].chance
end

function hud.graphPoints(history, current, now, left, top, width, height)
	local span = math.max(600, math.ceil(math.max(now, 1) / 600) * 600)
	local points = {}
	local function place(time, chance)
		return Vec2(left + math.max(0, time) / span * width, top + (1 - chance) * height)
	end
	for _, sample in ipairs(history) do points[#points + 1] = place(sample.time, sample.chance) end
	if current then points[#points + 1] = place(now, current) end
	return points, span
end

function hud.reasons(factors)
	local ahead, behind = {}, {}
	for _, factor in ipairs(factors or {}) do
		if factor.value >= 0.15 then ahead[#ahead + 1] = factor
		elseif factor.value <= -0.15 then behind[#behind + 1] = factor end
	end
	table.sort(ahead, function(a, b) return a.value > b.value end)
	table.sort(behind, function(a, b) return a.value < b.value end)
	return ahead, behind
end

function hud.pretty(name)
	name = tostring(name or ""):gsub("^item_", "")
	local words = {}
	for word in name:gmatch("[^_]+") do words[#words + 1] = word:sub(1, 1):upper() .. word:sub(2) end
	return table.concat(words, " ")
end

function hud.short(mode)
	local value = tostring(mode or "")
	return value:match("^([^:]+)") or value
end

local categories = {
	fight = "fight", initiate = "fight", ["base counterattack"] = "fight", ["hero combo"] = "fight",
	retreat = "safe", escape = "safe",
	lane = "farm", ["map farm"] = "farm", ["creep block"] = "farm",
}

local function categoryColor(name)
	local kind = categories[name or ""]
	if kind == "fight" then return palette.theirs end
	if kind == "safe" then return palette.even end
	if kind == "farm" then return palette.ours end
	return palette.text
end

function hud.stats(ctx)
	if cache.statsTime and ctx.now - cache.statsTime < 1 then return cache.stats end
	cache.statsTime = ctx.now
	local stats = {}
	if ctx.player and Entity.IsEntity(ctx.player) then
		local ok, data = pcall(Player.GetTeamPlayer, ctx.player)
		if ok and data then
			stats.lastHits, stats.denies = data.lasthit_count or 0, data.deny_count or 0
			stats.gold = (data.reliable_gold or 0) + (data.unreliable_gold or 0)
			stats.networth = data.networth or 0
		end
	end
	cache.stats = stats
	return stats
end

local function winBar(ctx, state, scale)
	local screen = Render.ScreenSize()
	local barWidth = 440 * scale
	local left = screen.x / 2 - barWidth / 2
	local top = 112 * scale
	local chance = state.smooth or 0.5
	local ours = math.floor(chance * 100 + 0.5)
	write(fonts.bold, 13 * scale, hud.name, left, top, palette.accent)
	write(fonts.text, 13 * scale, text("hud.winChance"), left + 72 * scale, top, palette.label)
	local trend = hud.trend(state.history, ctx.clock, 120)
	if math.abs(trend) >= 0.01 then
		write(fonts.text, 13 * scale, string.format(text("hud.trend"), trend >= 0 and "+" or "-", math.abs(trend) * 100),
			left + barWidth, top, trend >= 0 and palette.ours or palette.theirs, "right")
	end
	local y = top + 20 * scale
	write(fonts.bold, 22 * scale, ours .. "%", left - 8 * scale, y - 8 * scale, palette.ours, "right")
	write(fonts.bold, 22 * scale, (100 - ours) .. "%", left + barWidth + 8 * scale, y - 8 * scale, palette.theirs)
	local split = left + barWidth * chance
	Render.FilledRect(Vec2(left, y), Vec2(left + barWidth, y + 8 * scale), palette.track, 4)
	Render.FilledRect(Vec2(left, y), Vec2(split, y + 8 * scale), palette.ours, 4)
	Render.FilledRect(Vec2(split, y), Vec2(left + barWidth, y + 8 * scale), palette.theirs, 4)
	Render.FilledRect(Vec2(split - 1.5 * scale, y - 3 * scale), Vec2(split + 1.5 * scale, y + 11 * scale), palette.text, 1)
	local graphTop, graphHeight = y + 16 * scale, 34 * scale
	local key = #state.history .. ":" .. math.floor(ctx.clock / 2) .. ":" .. math.floor(chance * 200) .. ":" .. math.floor(left)
	if cache.graphKey ~= key then
		cache.graphKey = key
		cache.points, cache.span = hud.graphPoints(state.history, chance, ctx.clock, left, graphTop, barWidth, graphHeight)
	end
	local middle = graphTop + graphHeight / 2
	Render.Line(Vec2(left, middle), Vec2(left + barWidth, middle), palette.line, 1)
	local points = cache.points
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		Render.Line(a, b, (a.y + b.y) / 2 < middle and palette.ours or palette.theirs, 1.6 * scale)
	end
	for _, marker in ipairs(state.markers or {}) do
		local x = left + math.max(0, marker.time) / cache.span * barWidth
		if marker.gain > 0 then Render.FilledCircle(Vec2(x, graphTop - 2 * scale), (1.5 + math.min(3, marker.gain)) * scale, palette.ours) end
		if marker.loss > 0 then Render.FilledCircle(Vec2(x, graphTop + graphHeight + 2 * scale), (1.5 + math.min(3, marker.loss)) * scale, palette.theirs) end
	end
	local ahead, behind = hud.reasons(state.factors)
	local parts = {}
	for index = 1, math.min(2, #ahead) do parts[#parts + 1] = {"+ " .. text(ahead[index].label) .. " " .. (ahead[index].detail or ""), palette.ours} end
	for index = 1, math.min(2, #behind) do parts[#parts + 1] = {"- " .. text(behind[index].label) .. " " .. (behind[index].detail or ""), palette.theirs} end
	local total, gap = 0, 18 * scale
	for _, part in ipairs(parts) do part.width = Render.TextSize(fonts.text, 13 * scale, part[1]).x; total = total + part.width + gap end
	local x = screen.x / 2 - (total - gap) / 2
	for _, part in ipairs(parts) do
		write(fonts.text, 13 * scale, part[1], x, graphTop + graphHeight + 7 * scale, part[2])
		x = x + part.width + gap
	end
end

local function row(scale, x, y, width, label, value, color)
	write(fonts.text, 11 * scale, label, x, y, palette.label)
	write(fonts.bold, 15 * scale, fit(fonts.bold, 15 * scale, value, width), x, y + 13 * scale, color or palette.text)
	return y + 36 * scale
end

local function column(ctx, scale)
	local screen = Render.ScreenSize()
	local width = 290 * scale
	local x = screen.x - width - 24 * scale
	local y = screen.y * 0.27
	write(fonts.bold, 13 * scale, hud.name, x, y, palette.accent)
	y = y + 22 * scale
	y = row(scale, x, y, width, text("hud.now"), text(ctx.mode or ""), categoryColor(ctx.decisionRan))
	local ranked = ctx.decisionRanked or {}
	if #ranked > 1 then
		local options = {}
		for index = 1, math.min(3, #ranked) do
			options[#options + 1] = text("behavior." .. ranked[index].name) .. " " .. string.format("%.0f", ranked[index].score)
		end
		y = row(scale, x, y, width, text("hud.weighing"), table.concat(options, "  |  "), palette.dim)
	end
	local status = ctx.shop and ctx.shop.status or ""
	local target, part = status:match("^([%w_]+) > ([%w_]+)$")
	local stats = hud.stats(ctx)
	if target then
		local value = hud.pretty(target)
		if part ~= target then value = value .. "  >  " .. hud.pretty(part) end
		if stats.gold then value = value .. string.format("   (%d %s)", stats.gold, text("hud.gold")) end
		y = row(scale, x, y, width, text("hud.nextItem"), value)
	elseif status ~= "" then
		y = row(scale, x, y, width, text("hud.shop"), text(status), palette.dim)
	end
	local threat = ctx.laneThreat
	if threat and (threat.incoming or 0) > 0 and Entity.IsAlive(ctx.hero) then
		local share = threat.incoming / math.max(1, Entity.GetHealth(ctx.hero))
		local color = share > 0.6 and palette.theirs or share > 0.3 and palette.even or palette.text
		y = row(scale, x, y, width, text("hud.danger"), string.format(text("hud.dangerDetail"), threat.incoming, math.floor(share * 100)), color)
	end
	local strategy = ctx.strategy
	if strategy then
		local value = string.format(text("hud.enemiesDetail"), strategy.enemiesDead or 0, strategy.enemiesMissing or 0)
		y = row(scale, x, y, width, text("hud.enemies"), value, (strategy.enemiesMissing or 0) >= 3 and palette.even or palette.text)
	end
	local record = ctx.lastFightSim
	if record and ctx.now - record.time < 4 then
		local result = record.result
		y = row(scale, x, y, width, text("hud.forecast"), string.format(text("hud.forecastDetail"),
			result.favorable and text("hud.fightGood") or text("hud.fightBad"), result.enemyDeaths, result.allyDeaths),
			result.favorable and palette.ours or palette.theirs)
	end
	if stats.lastHits then
		local minutes = math.max(1, (ctx.clock or 0) / 60)
		y = row(scale, x, y, width, text("hud.farm"), string.format(text("hud.farmDetail"), stats.lastHits, stats.denies,
			stats.lastHits / minutes, stats.networth), palette.dim)
	end
	if ctx.shop and ctx.shop.providerError then
		row(scale, x, y, width, text("hud.problem"), ctx.shop.providerError, palette.theirs)
	end
end

local function marker(world, radius, color, thickness)
	local screen, visible = Render.WorldToScreen(world)
	if not visible then return nil end
	Render.Circle(screen, radius, color, thickness or 1.5)
	return screen
end

function hud.world(ctx, scale)
	if not ctx.hero or not Entity.IsAlive(ctx.hero) then return end
	local origin, onScreen = Render.WorldToScreen(Entity.GetAbsOrigin(ctx.hero))
	local goal = ctx.moveGoal
	if goal and ctx.lastOrder == "move" and ctx.distance(goal, ctx.position) > 80 then
		local screen, visible = Render.WorldToScreen(goal)
		if visible and onScreen then
			Render.Line(origin, screen, palette.goal, 1.5)
			Render.FilledCircle(screen, 3.5 * scale, palette.goal)
		end
	end
	local target = ctx.attackTarget
	if target and Entity.IsEntity(target) and Entity.IsAlive(target) and NPC.IsVisible(target) then
		marker(Entity.GetAbsOrigin(target), (NPC.IsHero(target) and 28 or 18) * scale, palette.target, 2)
	end
	local focus = ctx.hits and ctx.hits.focus
	if focus and focus ~= target and Entity.IsEntity(focus) and Entity.IsAlive(focus) and NPC.IsVisible(focus) then
		marker(Entity.GetAbsOrigin(focus), 16 * scale, palette.focus, 1.5)
	end
	if onScreen then
		write(fonts.bold, 14 * scale, hud.short(text(ctx.mode or "")), origin.x, origin.y + 26 * scale, categoryColor(ctx.decisionRan), "center")
	end
end

function hud.draw(ctx, state, options)
	if not fonts.text then hud.init() end
	local scale = math.max(0.75, Render.ScreenSize().y / 1080)
	if options.world then pcall(hud.world, ctx, scale) end
	if options.panel then column(ctx, scale) end
	if state and state.smooth then winBar(ctx, state, scale) end
end

return hud
