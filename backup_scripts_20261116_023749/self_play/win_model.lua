local model = {}
local strategy = require("self_play.strategy")

model.sampleEvery = 10
model.limit = 720
model.weights = {gold = 3.2, level = 0.22, buildings = 0.12, kills = 0.025, alive = 0.28, draft = 1, lane = 0.45, mega = 1.2, ancient = 3}
model.buildingValue = {tower1 = 1, tower2 = 1.5, tower3 = 2.5, tower4 = 2, melee = 3, range = 1.5}

local function sigmoid(x) return 1 / (1 + math.exp(-x)) end

local function real(hero)
	return Entity.IsEntity(hero) and not NPC.IsIllusion(hero) and not NPC.IsMeepoClone(hero)
		and Hero.GetReplicatingOtherHeroModel(hero) == nil and not NPC.HasModifier(hero, "modifier_arc_warden_tempest_double")
end

function model.cost(ctx, item)
	local name = (Ability.GetName(item) or ""):gsub("^item_", "")
	local record = ctx and ctx.catalog and ctx.catalog.items and ctx.catalog.items[name]
	if record and record.cost then return record.cost end
	return math.min(12000, math.max(0, Item.GetCost(item) or 0))
end

function model.inventory(hero, ctx)
	local total = 0
	for slot = 0, 16 do
		if slot < 9 or slot >= 15 then
			local item = NPC.GetItemByIndex(hero, slot)
			if item then total = total + model.cost(ctx, item) end
		end
	end
	return total
end

function model.building(unit)
	local name = NPC.GetUnitName(unit) or ""
	if NPC.IsBarracks(unit) then return name:find("melee", 1, true) and model.buildingValue.melee or model.buildingValue.range end
	if NPC.IsTower(unit) then
		local tier = tonumber(name:match("tower(%d)")) or 1
		return model.buildingValue["tower" .. tier] or 1
	end
	return 0
end

function model.state(ctx)
	ctx.winModel = ctx.winModel or {heroes = {}, history = {}, markers = {}, loaded = false}
	return ctx.winModel
end

function model.key(ctx)
	local match = GameRules.GetMatchID and GameRules.GetMatchID() or 0
	local start = GameRules.GetGameStartTime and math.floor(GameRules.GetGameStartTime()) or 0
	return tostring(match) .. ":" .. tostring(start) .. ":" .. tostring(ctx.team)
end

function model.load(ctx, state)
	state.loaded = true
	if not Config then return end
	local known = Config.ReadString("self_play_winchance", "heroes_v2", "")
	local heroKey, heroBody = known:match("^([^|]*)|(.*)$")
	if heroKey == model.key(ctx) then
		state.saved = {}
		for name, items, level, clock in heroBody:gmatch("([%w_]+):(%d+):(%d+):(%-?%d+)") do
			state.saved[name] = {items = tonumber(items), level = tonumber(level), clock = tonumber(clock)}
		end
	end
	local saved = Config.ReadString("self_play_winchance", "history", "")
	local key, body = saved:match("^([^|]*)|(.*)$")
	if key ~= model.key(ctx) then return end
	for time, value in body:gmatch("(%-?%d+):(%d+)") do
		state.history[#state.history + 1] = {time = tonumber(time), chance = tonumber(value) / 1000}
	end
end

function model.save(ctx, state)
	if not Config then return end
	local known = {}
	for _, record in pairs(state.heroes) do
		if not record.ally and record.seenClock and record.name then
			known[#known + 1] = string.format("%s:%d:%d:%d", record.name, math.floor(record.items), record.level, math.floor(record.seenClock))
		end
	end
	Config.WriteString("self_play_winchance", "heroes_v2", model.key(ctx) .. "|" .. table.concat(known, ","))
	local parts = {}
	for index, sample in ipairs(state.history) do parts[index] = string.format("%d:%d", sample.time, math.floor(sample.chance * 1000 + 0.5)) end
	Config.WriteString("self_play_winchance", "history", model.key(ctx) .. "|" .. table.concat(parts, ","))
end

function model.draftEdge(ctx, ours, theirs)
	if ctx.draftEdge ~= nil and ctx.draftEdgeCount == #ours + #theirs then return ctx.draftEdge end
	ctx.draftEdgeCount = #ours + #theirs
	ctx.draftEdge = 0
	local ok, data = pcall(require, "self_play.draft_data")
	if ok and data and data.edge then
		local success, value = pcall(data.edge, ours, theirs)
		if success and type(value) == "number" then ctx.draftEdge = math.max(-0.35, math.min(0.35, value)) end
	end
	return ctx.draftEdge
end

function model.observe(ctx, state)
	local teams = {ally = {items = 0, levels = 0, count = 0, alive = 0}, enemy = {items = 0, levels = 0, count = 0, alive = 0}}
	local names = {ally = {}, enemy = {}}
	local seen = {}
	for _, hero in ipairs(Heroes.GetAll()) do
		if real(hero) then
			local id = Entity.GetIndex(hero)
			local ally = Entity.IsSameTeam(ctx.hero, hero)
			local record = state.heroes[id] or {ally = ally, items = 0, level = 1, seen = -math.huge}
			state.heroes[id] = record
			seen[id] = true
			local fresh = ally or not Entity.IsDormant(hero) and NPC.IsVisible(hero)
			if fresh then
				local value = model.inventory(hero, ctx)
				record.items = ally and value or math.max(record.items, value)
				record.level, record.seen = math.max(record.level, NPC.GetCurrentLevel(hero)), ctx.now
				if not ally then record.seenClock, record.empty = ctx.clock, record.items == 0 end
			end
			record.alive = ally and Entity.IsAlive(hero) or not ally and not strategy.dead(ctx, hero)
			record.name = NPC.GetUnitName(hero)
			local saved = not ally and state.saved and state.saved[record.name]
			if saved and not record.seenClock then
				record.items, record.level, record.seenClock = math.max(record.items, saved.items), math.max(record.level, saved.level), saved.clock
				record.seen = ctx.now - math.max(0, ctx.clock - saved.clock)
				state.saved[record.name] = nil
			end
			local side = ally and "ally" or "enemy"
			names[side][#names[side] + 1] = record.name
		end
	end
	for id in pairs(state.heroes) do if not seen[id] then state.heroes[id] = nil end end
	local allyItems, allyCount = 0, 0
	for _, record in pairs(state.heroes) do
		if record.ally then allyItems, allyCount = allyItems + record.items, allyCount + 1 end
	end
	local income = ctx.clock > 60 and allyCount > 0 and allyItems / allyCount / ctx.clock or 0
	for _, record in pairs(state.heroes) do
		local side = teams[record.ally and "ally" or "enemy"]
		local items, level = record.items, record.level
		if not record.ally then
			local stale = ctx.now - record.seen
			if record.empty and ctx.clock > 600 or stale == math.huge or stale ~= stale then
				items, level = allyCount > 0 and allyItems / allyCount or 0, nil
			elseif stale > 5 then
				items = items + income * math.min(stale, 600) * 0.8
			end
		end
		side.items, side.count = side.items + items, side.count + 1
		if level then side.levels, side.levelCount = side.levels + level, (side.levelCount or 0) + 1 end
		if record.alive then side.alive = side.alive + 1 end
	end
	return teams, names
end

function model.structures(ctx)
	local result = {ours = 0, theirs = 0, ourLanes = {}, theirLanes = {}, ourFort = 1, theirFort = 1}
	for _, unit in ipairs(NPCs.GetAll()) do
		if Entity.IsEntity(unit) and Entity.IsAlive(unit) then
			local same = Entity.IsSameTeam(ctx.hero, unit)
			if NPC.IsTower(unit) or NPC.IsBarracks(unit) then
				local value = model.building(unit)
				if same then result.ours = result.ours + value else result.theirs = result.theirs + value end
				if NPC.IsBarracks(unit) then
					local lane = (NPC.GetUnitName(unit) or ""):match("_(%a+)$") or "?"
					local lanes = same and result.ourLanes or result.theirLanes
					lanes[lane] = true
				end
			elseif NPC.IsFort(unit) then
				local fraction = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))
				if same then result.ourFort = fraction else result.theirFort = fraction end
			end
		end
	end
	local function count(lanes)
		local total = 0
		for _ in pairs(lanes) do total = total + 1 end
		return total
	end
	result.ourRax, result.theirRax = count(result.ourLanes), count(result.theirLanes)
	return result
end

function model.networth(ctx)
	local total, gold, found = 0, 0, false
	for _, player in ipairs(Players.GetAll()) do
		if Entity.IsEntity(player) and Entity.GetTeamNum(player) == Entity.GetTeamNum(ctx.hero) then
			local ok, data = pcall(Player.GetTeamPlayer, player)
			if ok and data and (data.networth or 0) > 0 then
				total, found = total + data.networth, true
				gold = gold + (data.reliable_gold or 0) + (data.unreliable_gold or 0)
			end
		end
	end
	if not found then return nil end
	return total, gold
end

function model.kills(ctx)
	local kills, deaths = 0, 0
	for _, player in ipairs(Players.GetAll()) do
		if Entity.IsEntity(player) and Entity.GetTeamNum(player) == Entity.GetTeamNum(ctx.hero) then
			local ok, data = pcall(Player.GetTeamData, player)
			if ok and data then kills, deaths = kills + (data.kills or 0), deaths + (data.deaths or 0) end
		end
	end
	return kills, deaths
end

function model.evaluate(ctx)
	local state = model.state(ctx)
	if not state.loaded then model.load(ctx, state) end
	local teams, names = model.observe(ctx, state)
	local ally, enemy = teams.ally, teams.enemy
	local minutes = math.max(0, ctx.clock / 60)
	local weights = model.weights
	local factors = {}
	local total = 0
	local function add(key, label, value, detail)
		factors[#factors + 1] = {key = key, label = label, value = value, detail = detail}
		total = total + value
	end
	local allyWorth, allyGold = model.networth(ctx)
	allyWorth, allyGold = allyWorth or ally.items, allyGold or 0
	local correction = ally.items > 0 and math.max(0.6, math.min(1.4, (allyWorth - allyGold) / ally.items)) or 1
	local enemyWorth = enemy.items * correction + allyGold * enemy.count / math.max(1, ally.count)
	state.correction = correction
	local scale = math.max(8000, (allyWorth + enemyWorth) / 2)
	local goldDiff = allyWorth - enemyWorth
	add("gold", "Net worth", weights.gold * goldDiff / scale, string.format("%+.1fk", goldDiff / 1000))
	state.enemySeen = 0
	for _, record in pairs(state.heroes) do if not record.ally and record.seenClock then state.enemySeen = state.enemySeen + 1 end end
	local allyLevel = ally.levelCount and ally.levels / ally.levelCount or 1
	local enemyLevel = enemy.levelCount and enemy.levels / enemy.levelCount or allyLevel
	add("level", "Levels", weights.level * (allyLevel - enemyLevel), string.format("%+.1f", allyLevel - enemyLevel))
	local map = model.structures(ctx)
	local ours, theirs = map.ours, map.theirs
	state.buildingsOurs, state.buildingsTheirs, state.map = ours, theirs, map
	add("buildings", "Buildings", weights.buildings * (ours - theirs), string.format("%.0f v %.0f", ours, theirs))
	local lostOurs, lostTheirs = 3 - map.ourRax, 3 - map.theirRax
	local creeps = weights.lane * (lostTheirs - lostOurs) + (lostTheirs == 3 and weights.mega or 0) - (lostOurs == 3 and weights.mega or 0)
	if creeps ~= 0 then
		add("creeps", lostOurs == 3 and "Enemy megas" or lostTheirs == 3 and "Our megas" or "Super creeps", creeps,
			string.format("%d v %d lanes", lostTheirs, lostOurs))
	end
	if map.ourFort < 1 or map.theirFort < 1 then
		add("ancient", "Ancient", weights.ancient * (map.ourFort - map.theirFort),
			string.format("%d%% v %d%%", math.floor(map.ourFort * 100 + 0.5), math.floor(map.theirFort * 100 + 0.5)))
	end
	local kills, deaths = model.kills(ctx)
	state.kills, state.deaths = kills, deaths
	add("kills", "Kills", math.max(-0.6, math.min(0.6, weights.kills * (kills - deaths))), string.format("%d-%d", kills, deaths))
	local late = math.min(1, minutes / 30)
	add("alive", "Alive now", weights.alive * (ally.alive - enemy.alive) * (0.3 + 0.7 * late), string.format("%d v %d", ally.alive, enemy.alive))
	local fade = math.max(0, 1 - minutes / 30)
	if fade > 0 then
		local edge = model.draftEdge(ctx, names.ally, names.enemy)
		add("draft", "Draft", weights.draft * edge * fade, string.format("%+.0f%%", (sigmoid(edge) - 0.5) * 100))
	end
	local chance = math.max(0.02, math.min(0.98, sigmoid(total)))
	state.raw = chance
	state.smooth = state.smooth and state.smooth + (chance - state.smooth) * 0.35 or chance
	state.factors, state.logit = factors, total
	state.allyItems, state.enemyItems = allyWorth, enemyWorth
	if state.lastKills and (kills > state.lastKills or deaths > state.lastDeaths) then
		state.markers[#state.markers + 1] = {time = ctx.clock, gain = kills - state.lastKills, loss = deaths - state.lastDeaths}
		while #state.markers > 120 do table.remove(state.markers, 1) end
	end
	state.lastKills, state.lastDeaths = kills, deaths
	return state
end

function model.update(ctx)
	if ctx.now < (ctx.nextWinModel or 0) or ctx.clock < 0 then return ctx.winModel end
	ctx.nextWinModel = ctx.now + 1
	local ok, state = pcall(model.evaluate, ctx)
	if not ok then ctx.winModelError = tostring(state); return ctx.winModel end
	local last = state.history[#state.history]
	if not last or ctx.clock - last.time >= model.sampleEvery then
		state.history[#state.history + 1] = {time = math.floor(ctx.clock), chance = state.smooth}
		while #state.history > model.limit do table.remove(state.history, 1) end
		if ctx.now >= (state.nextSave or 0) then
			state.nextSave = ctx.now + 30
			model.save(ctx, state)
		end
	end
	return state
end

return model
