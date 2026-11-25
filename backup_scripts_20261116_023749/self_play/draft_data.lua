local dd = {}
local JSON = require("assets.JSON")
local json = JSON.new and JSON:new({assert = function() end}) or JSON

local NET = {URL = "https://raw.githubusercontent.com/But3rflys/umbrella-work/draft-data/",
	HEADERS = {["User-Agent"] = "Umbrella/draft-helper"}, TIMEOUT = 60, RETRY = 60, CHECK = 3600}
local RANKS = {0, 50, 60, 70}
local MODEL = {PRIOR = 250, PAIR = 2000, POS_MIN = 15, RISK = 0.3, RISK_TOP = 2, NICHE = 0.05, THREAT = 0.15, BASE_W = 0.4,
	COVER = 1, LANE_REST = 0.25,
	LANE_VS = {{[3] = true, [4] = true}, {[2] = true}, {[1] = true, [5] = true}, {[1] = true, [5] = true}, {[3] = true, [4] = true}},
	LANE_WITH = {{[5] = true}, {}, {[4] = true}, {[3] = true}, {[1] = true}}}
local ITEM = {POS_MIN = 100, SHARE_MIN = 0, FILL = 0.25, AGHS = 0.3, FOLD_GAP = 5, UPGRADE = 0.15, BEAR = 0.5, SLOTS = 6,
	BEAR_HERO = "lone_druid", STEP_COST = 1500, LATE = 30, POOL = 0.05, COUNTERS = 2, COUNTERS_USED = 1, COUNTER_P = 0.2,
	COUNTER_S = 0.9, LUX_PR = 0.1, LUX_MIN = 25, KEEP = 0.08, CHEAP = 1000, PART_FINAL = 0.15, EARLY_PART = 15, HOLD = 5,
	EAT_MIN = 35, SELL_FINAL = 0.25, SOLD_SOON = 15, SPLIT_PART = 800, SPLIT_WAIT = 12, LEFT_W = 0.05, FINAL_MIN = 0.08,
	FINAL_FROM_PR = 0.7, SUNK = 0.15, LATE_EXTRA = 2, GROW = 0.03, HYPER_MIN = 50, BOOTS_W = 0.3, BOOTS_UP = 0.15,
	HYPER_SELL = {boots = true, power_treads = true, phase_boots = true, arcane_boots = true, tranquil_boots = true},
	LATE_SWAP_W = 0.6, HYPER_W = 0.08, HYPER_COST = 3500, TIE = 2, TIE_PR = 0.1, LATE_COST = 4000, LATE_W = 0.3,
	LATE_SWAP = 2500, LATE_DROP = 28, SCEPTER = "ultimate_scepter", SHARD = "aghanims_shard", BLESSING = "ultimate_scepter_2",
	CONSUME = {moon_shard = true}, TRAVEL = {travel_boots = true, travel_boots_2 = true}, FAMILY = {yasha = true, sange = true, kaya = true},
	BOOTS = {boots = true, power_treads = true, phase_boots = true, arcane_boots = true, tranquil_boots = true,
		travel_boots = true, travel_boots_2 = true, guardian_greaves = true, boots_of_bearing = true}}

local function logit(p) return math.log(p / (1 - p)) end
local function sigmoid(x) return 1 / (1 + math.exp(-x)) end
local function clock() return os.clock() end

local data = {heroes = {}, list = {}, by_id = {}, manifest = nil, sets = {}, busy = {}, wait = {}, next_check = 0, cache = nil}
dd.data = data
dd.rank = 4
dd.source = "ap"

local FILE, MAGIC = "self_play_draft_data.dat", "SPD1"

local function cachePath()
	local dir = Engine.GetCheatDirectory()
	if not dir:match("[\\/]$") then dir = dir .. "\\" end
	return dir .. "configs\\" .. FILE
end

local function loadCache()
	data.cache = {}
	local f = io.open(cachePath(), "rb")
	if not f then return end
	local blob = f:read("a")
	f:close()
	if not blob or blob:sub(1, #MAGIC + 1) ~= MAGIC .. "\n" then return end
	local i = #MAGIC + 2
	while i <= #blob do
		local name, len, start = blob:match("^([^\n]+)\n(%d+)\n()", i)
		if not name then break end
		len = tonumber(len)
		data.cache[name] = blob:sub(start, start + len - 1)
		i = start + len + 1
	end
end

local function saveCache()
	local names = {}
	for name in pairs(data.cache) do names[#names + 1] = name end
	table.sort(names)
	local parts = {MAGIC, "\n"}
	for _, name in ipairs(names) do
		local text = data.cache[name]
		parts[#parts + 1] = name .. "\n" .. #text .. "\n"
		parts[#parts + 1] = text
		parts[#parts + 1] = "\n"
	end
	local f = io.open(cachePath(), "wb")
	if not f then return end
	f:write(table.concat(parts))
	f:close()
end

function data.read(name)
	if not data.cache then loadCache() end
	return data.cache[name]
end

function data.write(name, text)
	if not data.cache then loadCache() end
	data.cache[name] = text
	saveCache()
end

function data.decode(text)
	if not text then return nil end
	local v = json:decode(text)
	return type(v) == "table" and v or nil
end

function data.fetch(name, done)
	if data.busy[name] or (data.wait[name] or 0) > clock() then return end
	data.busy[name] = true
	local sent = HTTP.Request("GET", NET.URL .. name, {headers = NET.HEADERS, timeout = NET.TIMEOUT}, function(r)
		data.busy[name] = nil
		local code = tonumber(r.code) or 0
		if code == 200 and type(r.response) == "string" and #r.response > 0 then
			data.error = nil
			done(r.response)
		else
			data.wait[name] = clock() + NET.RETRY
			data.error = name .. ": HTTP " .. code
			done(nil)
		end
	end, "self_play_" .. name)
	if not sent then
		data.busy[name] = nil
		data.wait[name] = clock() + NET.RETRY
		data.error = name .. ": request not sent"
		done(nil)
	end
end

function data.setHeroes(list)
	data.heroes, data.list, data.by_id = {}, {}, {}
	for _, e in ipairs(list) do
		if type(e) == "table" and e.name and e.id and type(e.pos) == "table" then
			local shares, main = e.pos, 1
			for p = 2, 5 do if (shares[p] or 0) > (shares[main] or 0) then main = p end end
			local hero = {h = e.name, id = e.id, attr = e.attr, pos = main, shares = shares}
			data.heroes[hero.h], data.by_id[hero.id] = hero, hero
			data.list[#data.list + 1] = hero
		end
	end
	table.sort(data.list, function(a, b) return a.h < b.h end)
	data.rolesFrom = nil
	if data.sets.items then data.useRoles(data.sets.items) end
end

function data.boot()
	if data.booted then return end
	data.booted = true
	data.manifest = data.decode(data.read("manifest.json"))
	local heroes = data.decode(data.read("heroes.json"))
	if heroes then data.setHeroes(heroes) end
end

function data.tick()
	data.boot()
	if clock() < data.next_check then return end
	data.next_check = clock() + NET.RETRY
	data.fetch("manifest.json", function(text)
		local m = data.decode(text)
		if not m or type(m.sets) ~= "table" then return end
		data.next_check = clock() + NET.CHECK
		if data.manifest and data.manifest.time == m.time and next(data.heroes) then data.prefetch(); return end
		data.fetch("heroes.json", function(body)
			local heroes = data.decode(body)
			if not heroes then return end
			data.cache["heroes.json"] = body
			data.write("manifest.json", text)
			data.manifest = m
			data.setHeroes(heroes)
			data.prefetch()
		end)
	end)
end

function data.prefetch()
	data.stats(dd.key())
	data.model(dd.key())
	data.items()
	data.counters()
	data.answers()
end

function data.parse(text, time)
	local st = {time = time, n = tonumber(text:match("^n (%d+)")) or 0, hg = {}, hw = {}, sg = {}, sw = {}, vg = {}, vw = {}, base = {}}
	for id, g, w in text:gmatch("\nh (%d+) (%d+) (%d+)") do
		local h = tonumber(id)
		st.hg[h], st.hw[h] = tonumber(g), tonumber(w)
	end
	for a, b, g, w in text:gmatch("\ns (%d+) (%d+) (%d+) (%d+)") do
		local k = tonumber(a) * 256 + tonumber(b)
		st.sg[k], st.sw[k] = tonumber(g), tonumber(w)
	end
	for a, b, g, w in text:gmatch("\nv (%d+) (%d+) (%d+) (%d+)") do
		local k = tonumber(a) * 256 + tonumber(b)
		st.vg[k], st.vw[k] = tonumber(g), tonumber(w)
	end
	return st
end

function data.parseItems(text, time)
	local it = {time = time, meta = {}, by_name = {}, up = {}, hero = {}, roles = {}}
	for h, a, b, c, d, e in text:gmatch("\nr (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)") do
		it.roles[tonumber(h)] = {tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(e)}
	end
	for id, name, cost in text:gmatch("\ni (%d+) ([%w_]+) (%d+)") do
		local i = tonumber(id)
		it.meta[i] = {name = name, cost = tonumber(cost)}
		it.by_name[name] = i
	end
	for id, list in text:gmatch("\nu (%d+) ([%d ]+)") do
		local up = {}
		for p in list:gmatch("%d+") do up[#up + 1] = tonumber(p) end
		it.up[tonumber(id)] = up
	end
	for h, p, n, wr, share in text:gmatch("\nh (%d+) (%d) (%d+) (%d+) (%d+)") do
		local hid = tonumber(h)
		it.hero[hid] = it.hero[hid] or {}
		it.hero[hid][tonumber(p)] = {n = tonumber(n), wr = tonumber(wr) / 1000, share = tonumber(share), start = {}, core = {}, mid = {}, final = {}, path = {}}
	end
	local function entry(h, p)
		local hero = it.hero[tonumber(h)]
		return hero and hero[tonumber(p)]
	end
	for h, p, n, list in text:gmatch("\ns (%d+) (%d) (%d+) ([%d,]+)") do
		local e = entry(h, p)
		if e then
			local ids = {}
			for x in list:gmatch("%d+") do ids[#ids + 1] = tonumber(x) end
			e.start[#e.start + 1] = {n = tonumber(n), ids = ids}
		end
	end
	local times = {}
	for tag, h, p, id, pr, m, wr in text:gmatch("\n([cm]) (%d+) (%d) (%d+) (%d+) (%d+) (%d+)") do
		local e = entry(h, p)
		if e then
			local list = tag == "c" and e.core or e.mid
			list[#list + 1] = {id = tonumber(id), pr = tonumber(pr) / 1000, min = tonumber(m) / 10, wr = tonumber(wr) / 1000}
		end
		local i = tonumber(id)
		times[i] = times[i] or {}
		table.insert(times[i], tonumber(m) / 10)
	end
	it.typical = {}
	for id, list in pairs(times) do
		table.sort(list)
		local n = #list
		it.typical[id] = n % 2 == 1 and list[(n + 1) // 2] or (list[n // 2] + list[n // 2 + 1]) / 2
	end
	for h, p, id, m in text:gmatch("\nb (%d+) (%d) (%d+) (%d+)") do
		local e = entry(h, p)
		if e then e.path[#e.path + 1] = {id = tonumber(id), min = tonumber(m) / 10} end
	end
	local gaps = {}
	for _, byPos in pairs(it.hero) do
		for _, e in pairs(byPos) do
			local at = {}
			for _, x in ipairs(e.path) do at[x.id] = at[x.id] or x.min end
			for c, m in pairs(at) do
				for _, x in ipairs(it.up[c] or {}) do
					if at[x] and at[x] > m then
						local k = c * 65536 + x
						gaps[k] = gaps[k] or {}
						table.insert(gaps[k], at[x] - m)
					end
				end
			end
		end
	end
	it.gap = {}
	for k, list in pairs(gaps) do
		if #list >= 2 then
			table.sort(list)
			local n = #list
			it.gap[k] = {n = n, v = n % 2 == 1 and list[(n + 1) // 2] or (list[n // 2] + list[n // 2 + 1]) / 2}
		end
	end
	for h, p, id, pr in text:gmatch("\nf (%d+) (%d) (%d+) (%d+)") do
		local e = entry(h, p)
		if e then e.final[tonumber(id)] = tonumber(pr) / 1000 end
	end
	return it
end

function data.parseModel(text, time)
	local m = {time = time, c = (tonumber(text:match("\nc (%-?%d+)")) or 0) / 10000, b = {}, s = {}, v = {}}
	for id, x in text:gmatch("\nb (%d+) (%-?%d+)") do m.b[tonumber(id)] = tonumber(x) / 10000 end
	for tag, a, b, x in text:gmatch("\n([sv]) (%d+) (%d+) (%-?%d+)") do m[tag][tonumber(a) * 256 + tonumber(b)] = tonumber(x) / 10000 end
	return m
end

function data.parseCounters(text, time)
	local ct = {time = time, bear = {}}
	for item, x in text:gmatch("\nk ([%w_]+) (%d+)") do ct.bear[item] = tonumber(x) / 1000 end
	return ct
end

function data.parseAnswers(text, time)
	local ans = {time = time, l = {}, e = {}, x = {}, p = {}, used = {}}
	for item, m in text:gmatch("\nl ([%w_]+) (%d+)") do ans.l[item] = tonumber(m) end
	for item, id, b in text:gmatch("\ne ([%w_]+) (%d+) (%-?%d+)") do
		ans.e[item] = ans.e[item] or {}
		ans.e[item][tonumber(id)] = tonumber(b) / 1000
	end
	for item, other, b in text:gmatch("\nx ([%w_]+) ([%w_]+) (%-?%d+)") do
		ans.x[item] = ans.x[item] or {}
		ans.x[item][other] = tonumber(b) / 1000
	end
	for id, tier, item, x in text:gmatch("\np (%d+) (%d) ([%w_]+) (%d+)") do
		local k = tonumber(id) * 10 + tonumber(tier)
		ans.p[k] = ans.p[k] or {}
		ans.p[k][item] = tonumber(x) / 1000
		ans.used[item] = true
	end
	return ans
end

function data.stats(key, parse)
	parse = parse or data.parse
	local info = data.manifest and data.manifest.sets and data.manifest.sets[key]
	local cur = data.sets[key]
	if not info then
		if cur == nil then
			local text = data.read(key .. ".txt")
			cur = text and parse(text, 0) or false
			data.sets[key] = cur
		end
		return cur or nil
	end
	if cur and cur.time == info.time then return cur end
	if Config.ReadInt("self_play_draft_data", "set_" .. key, 0) == info.time then
		local text = data.read(key .. ".txt")
		if text then
			data.sets[key] = parse(text, info.time)
			return data.sets[key]
		end
	end
	data.fetch("stats/" .. key .. ".txt", function(text)
		if not text then return end
		data.write(key .. ".txt", text)
		Config.WriteInt("self_play_draft_data", "set_" .. key, info.time)
		data.sets[key] = parse(text, info.time)
		if key == "items" then data.useRoles(data.sets[key]) end
	end)
	return cur or nil
end

function data.useRoles(it)
	if not it or data.rolesFrom == it then return end
	data.rolesFrom = it
	for _, hero in pairs(data.heroes) do
		local byPos, full = it.hero[hero.id], it.roles[hero.id]
		if byPos or full then
			local shares, sum, main = {}, 0, 1
			for p = 1, 5 do
				shares[p] = full and full[p] or (byPos[p] and byPos[p].share or 0)
				sum = sum + shares[p]
			end
			if sum > 0 then
				for p = 2, 5 do if shares[p] > shares[main] then main = p end end
				hero.shares, hero.pos = shares, main
			end
		end
	end
end

function data.items()
	local it = data.stats("items", data.parseItems)
	if it then data.useRoles(it) end
	return it
end
function data.model(key) return data.stats("model_" .. key, data.parseModel) end
function data.counters() return data.stats("counters", data.parseCounters) end
function data.answers() return data.stats("answers", data.parseAnswers) end

function dd.key() return dd.source .. "_" .. RANKS[dd.rank] end

function dd.tick() data.tick() end

function dd.ready() return next(data.heroes) ~= nil and data.items() ~= nil end

function dd.status()
	if data.error then return "Draft data: " .. data.error end
	if not next(data.heroes) then return "Draft data: loading heroes" end
	if not data.sets.items then return "Draft data: loading item stats" end
	return "Draft data: ready (" .. dd.key() .. ")"
end

local calc = {}
dd.calc = calc

function calc.base(st, id)
	if st.m then return st.m.b[id] or 0 end
	local v = st.base[id]
	if not v then
		v = logit(((st.hw[id] or 0) + MODEL.PRIOR * 0.5) / ((st.hg[id] or 0) + MODEL.PRIOR))
		st.base[id] = v
	end
	return v
end

function calc.pair(g, w, e) return logit((w + MODEL.PAIR * e) / (g + MODEL.PAIR)) - logit(e) end

function calc.with(st, a, b)
	local k = a < b and a * 256 + b or b * 256 + a
	if st.m then return st.m.s[k] or 0 end
	return calc.pair(st.sg[k] or 0, st.sw[k] or 0, sigmoid(calc.base(st, a) + calc.base(st, b)))
end

function calc.vs(st, a, b)
	local k = a < b and a * 256 + b or b * 256 + a
	if st.m then
		local v = st.m.v[k] or 0
		return a < b and v or -v
	end
	local g, w = st.vg[k] or 0, st.vw[k] or 0
	if a > b then w = g - w end
	return calc.pair(g, w, sigmoid(calc.base(st, a) - calc.base(st, b)))
end

function calc.team(st, team)
	local v = 0
	for i, a in ipairs(team) do
		v = v + calc.base(st, a)
		for j = i + 1, #team do v = v + calc.with(st, a, team[j]) end
	end
	return v
end

function calc.draft(st, ours, theirs)
	local v = calc.team(st, ours) - calc.team(st, theirs)
	for _, a in ipairs(ours) do
		for _, b in ipairs(theirs) do v = v + calc.vs(st, a, b) end
	end
	return v
end

function calc.row(st, hero, ours, theirs, base, need, risk, pos, lanePos)
	local function pp(x) return (sigmoid(base + x) - sigmoid(base)) * 100 end
	local id, cover = hero.id, 0
	local total = calc.base(st, id)
	for _, b in ipairs(theirs) do
		local x = calc.vs(st, id, b)
		total = total + x
		local v = pp(x)
		if v > 0 then cover = cover + v * need[b] end
	end
	for _, a in ipairs(ours) do total = total + calc.with(st, id, a) end
	local pick = st.n > 0 and (st.hg[id] or 0) / st.n or 0
	local k = -(1 - MODEL.BASE_W * math.min(1, pick / MODEL.NICHE)) * pp(calc.base(st, id)) + MODEL.COVER * cover
	if risk then
		local top = {}
		for _, y in ipairs(risk.foes) do
			if y.id ~= id then
				local x = calc.vs(st, y.id, id)
				if x > 0 then top[#top + 1] = x end
			end
		end
		table.sort(top, function(p, q) return p > q end)
		local sum = 0
		for i = 1, math.min(risk.n, MODEL.RISK_TOP, #top) do sum = sum + top[i] end
		k = k - MODEL.RISK * pp(sum)
	end
	local d = pp(total)
	local score = d + k
	if lanePos then
		local laneTotal, found = 0, false
		for _, b in ipairs(theirs) do
			if lanePos[b] and MODEL.LANE_VS[pos][lanePos[b]] then laneTotal, found = laneTotal + calc.vs(st, id, b), true end
		end
		for _, a in ipairs(ours) do
			if lanePos[a] and MODEL.LANE_WITH[pos][lanePos[a]] then laneTotal, found = laneTotal + calc.with(st, id, a), true end
		end
		if found then score = pp(laneTotal) + MODEL.LANE_REST * score end
	end
	return score
end

local function shortName(name) return (name or ""):gsub("^npc_dota_hero_", "") end
dd.shortName = shortName

function dd.edge(allies, enemies)
	local st = data.stats(dd.key())
	if not st or not next(data.heroes) then return 0 end
	st.m = data.model(dd.key())
	local ours, theirs = {}, {}
	for _, name in ipairs(allies) do
		local hero = data.heroes[shortName(name)]
		if hero then ours[#ours + 1] = hero.id end
	end
	for _, name in ipairs(enemies) do
		local hero = data.heroes[shortName(name)]
		if hero then theirs[#theirs + 1] = hero.id end
	end
	if #ours == 0 or #theirs == 0 then return 0 end
	return calc.draft(st, ours, theirs)
end

function dd.rankPicks(pos, available, allies, enemies, enemyPicksLeft)
	local st = data.stats(dd.key())
	if not st or not next(data.heroes) then return nil end
	st.m = data.model(dd.key())
	data.items()
	local ours, theirs, lanePos = {}, {}, {}
	for _, entry in ipairs(allies) do
		local hero = data.heroes[shortName(entry.name)]
		if hero then ours[#ours + 1] = hero.id; lanePos[hero.id] = entry.pos or hero.pos end
	end
	for _, entry in ipairs(enemies) do
		local hero = data.heroes[shortName(entry.name)]
		if hero then theirs[#theirs + 1] = hero.id; lanePos[hero.id] = entry.pos or hero.pos end
	end
	local base = (#ours + #theirs > 0) and calc.draft(st, ours, theirs) or 0
	local need = {}
	for _, b in ipairs(theirs) do
		local threat = calc.base(st, b)
		for _, a in ipairs(ours) do threat = threat + calc.vs(st, b, a) end
		need[b] = math.max(0, math.min(1, threat / MODEL.THREAT))
	end
	local risk
	if (enemyPicksLeft or 0) > 0 then
		local foes, used = {}, {}
		for _, id in ipairs(ours) do used[id] = true end
		for _, id in ipairs(theirs) do used[id] = true end
		for full in pairs(available) do
			local hero = data.heroes[shortName(full)]
			if hero and not used[hero.id] then foes[#foes + 1] = hero end
		end
		risk = {n = enemyPicksLeft, foes = foes}
	end
	local result = {}
	for full in pairs(available) do
		local hero = data.heroes[shortName(full)]
		if hero and (hero.shares[pos] or 0) >= MODEL.POS_MIN then
			result[#result + 1] = {name = "npc_dota_hero_" .. hero.h, score = calc.row(st, hero, ours, theirs, base, need, risk, pos, lanePos),
				share = hero.shares[pos]}
		end
	end
	table.sort(result, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.name < b.name end)
	return result
end

function dd.shares(name)
	local hero = data.heroes[shortName(name)]
	return hero and hero.shares
end

local build = {cache = {}, cached = 0}
dd.build = build

function build.baseName(it, id)
	local m = it.meta[id]
	return m and (m.name:gsub("^dagon_%d$", "dagon"))
end

function build.startKit(it, e, plan)
	local inStart, kit = {}, e.start[1]
	if not kit then return inStart end
	local order, count = {}, {}
	for _, id in ipairs(kit.ids) do
		if it.meta[id] then
			if not count[id] then order[#order + 1] = id end
			count[id] = (count[id] or 0) + 1
			inStart[id] = true
		end
	end
	for _, id in ipairs(order) do plan.start[#plan.start + 1] = {name = it.meta[id].name, q = count[id]} end
	return inStart
end

function build.rates(e)
	local pr, mins = {}, {}
	for _, list in ipairs({e.core, e.mid}) do
		for _, x in ipairs(list) do
			pr[x.id] = math.max(pr[x.id] or 0, x.pr)
			mins[x.id] = mins[x.id] or x.min
		end
	end
	return pr, mins
end

function build.popular(it, e, id)
	local m = it.meta[id]
	if not m then return false end
	if m.cost < ITEM.CHEAP then return true end
	local p = e.final[id] or 0
	for _, list in ipairs({e.core, e.mid}) do
		for _, x in ipairs(list) do if x.id == id and x.pr > p then p = x.pr end end
	end
	return p >= ITEM.KEEP
end

function build.add(route, x)
	if route.at[x.name] then return end
	route.list[#route.list + 1] = x
	route.at[x.name] = #route.list
end

function build.route(it, e, inStart)
	local src = e.path
	if #src == 0 then
		src = {}
		for _, x in ipairs(e.core) do src[#src + 1] = x end
		for _, x in ipairs(e.mid) do if x.pr >= ITEM.FILL then src[#src + 1] = x end end
		table.sort(src, function(p, q) return p.min < q.min end)
	end
	local path, at = {}, {}
	for _, x in ipairs(src) do
		local name = build.baseName(it, x.id)
		if name and not inStart[x.id] and build.popular(it, e, x.id) then
			local i = at[name]
			if not i then
				path[#path + 1] = {id = x.id, name = name, min = x.min, q = 1}
				at[name] = #path
			elseif name == it.meta[x.id].name and i == #path then
				path[i].q = path[i].q + 1
			end
		end
	end
	local function upgraded(i)
		for _, p in ipairs(it.up[path[i].id] or {}) do
			local j = at[build.baseName(it, p) or ""]
			if j and j > i and path[j].name ~= path[i].name and path[j].min - path[i].min <= ITEM.FOLD_GAP then return true end
		end
		return false
	end
	local route = {list = {}, at = {}}
	for i, x in ipairs(path) do if not upgraded(i) then build.add(route, x) end end
	return route
end

function build.steps(it, route, pr, mins)
	local list = {}
	for _, x in ipairs(route.list) do list[#list + 1] = x end
	for _, x in ipairs(list) do
		local id = it.by_name[x.name]
		local best, bp, has = nil, ITEM.UPGRADE, false
		for _, up in ipairs(id and it.up[id] or {}) do
			local name = build.baseName(it, up)
			if name and route.at[name] then has = true end
			if name and not route.at[name] and (pr[up] or 0) >= bp and mins[up] then best, bp = up, pr[up] end
		end
		if best and not has then build.add(route, {name = build.baseName(it, best), min = mins[best], q = 1}) end
	end
	for _, x in ipairs(list) do
		local id = it.by_name[x.name]
		local best, has = nil, false
		for c, ups in pairs(it.up) do
			for _, up in ipairs(ups) do
				if up == id then
					local name = build.baseName(it, c)
					if name and route.at[name] then has = true end
					local g = it.gap[c * 65536 + id]
					local m = it.meta[c]
					if g and g.v > ITEM.FOLD_GAP and m and m.cost >= ITEM.STEP_COST and (not best or g.n > best.n) then
						best = {name = name, n = g.n, min = x.min - g.v}
					end
				end
			end
		end
		if best and not has then build.add(route, {name = best.name, min = best.min, q = 1}) end
	end
end

function build.roleOk(e) return e ~= nil and e.n >= ITEM.POS_MIN and e.share >= ITEM.SHARE_MIN end

function build.walk(it, id, out)
	for _, p in ipairs(it.up[id] or {}) do
		if not out[p] then
			out[p] = true
			build.walk(it, p, out)
		end
	end
	return out
end

function build.chain(it, id)
	if build.chainsOf ~= it then build.chainsOf, build.chains = it, {} end
	local out = build.chains[id]
	if not out then
		out = build.walk(it, id, {})
		build.chains[id] = out
	end
	return out
end

function build.inside(it, name, route)
	local id = it.by_name[name]
	if not id then return false end
	for p in pairs(build.chain(it, id)) do
		if it.meta[p] and route.at[build.baseName(it, p)] then return true end
	end
	return false
end

function build.answers(it, hero, pos, enemies, pool, route, enemyItems)
	local ans = data.answers()
	if not ans then return {} end
	local base = ans.p[hero.id * 10 + (pos <= 3 and 1 or 2)] or {}
	local list, by = {}, {}
	for name, lm in pairs(ans.l) do
		local id = it.by_name[name]
		local p0 = (id and pool[id]) or base[name] or 0
		local own = route.at[name] ~= nil
		if (own or p0 >= ITEM.POOL) and not build.inside(it, name, route) then
			local s = 0
			for _, enemy in ipairs(enemies) do
				local hid = data.heroes[enemy] and data.heroes[enemy].id
				local w = hid and ans.e[name] and ans.e[name][hid] or 0
				for item in pairs(enemyItems[enemy] or {}) do
					local x = ans.x[name] and ans.x[name][item]
					if x then w = w + x end
				end
				if w > 0 then s = s + w end
			end
			if s > 0 then
				local q = math.min(math.max(p0, 0.0001), 0.95)
				local p = 1 / (1 + math.exp(-(math.log(q / (1 - q)) + s)))
				if s >= ITEM.COUNTER_S and p >= ITEM.COUNTER_P then
					local c = {name = name, id = id, gain = p - p0, min = lm, used = ans.used[name] == true, own = own}
					list[#list + 1] = c
					by[name] = c
				end
			end
		end
	end
	local out = {}
	for _, c in ipairs(list) do
		local up = false
		for p in pairs(c.id and build.chain(it, c.id) or {}) do
			local u = it.meta[p] and by[it.meta[p].name]
			if u and u.gain >= c.gain * 0.7 then up = true end
		end
		if not up then out[#out + 1] = c end
	end
	table.sort(out, function(a, b) return a.gain > b.gain end)
	local picked, items, used = {}, 0, 0
	for _, c in ipairs(out) do
		if c.own then picked[#picked + 1] = c
		elseif c.used and used < ITEM.COUNTERS_USED then used = used + 1; picked[#picked + 1] = c
		elseif not c.used and items < ITEM.COUNTERS then items = items + 1; picked[#picked + 1] = c end
	end
	return picked
end

function build.order(list)
	for i, x in ipairs(list) do x.i = i end
	table.sort(list, function(p, q)
		if p.min ~= q.min then return p.min < q.min end
		return p.i < q.i
	end)
	return list
end

function build.splits()
	if build.splitSet then return build.splitSet end
	local set = {}
	build.splitSet, build.recipes, build.prices = set, {}, {}
	for key, kv in pairs(XHelpers.xkv:GetKV("items").DOTAAbilities) do
		local name = type(key) == "string" and type(kv) == "table" and key:match("^item_([%w_]+)$")
		if name then
			if kv.ItemDisassembleRule == "DOTA_ITEM_DISASSEMBLE_ALWAYS" then set[name] = true end
			build.prices[name] = tonumber(kv.ItemCost or "0") or 0
			local result = name:match("^recipe_(.+)$")
			local requirements = type(kv.ItemRequirements) == "table" and kv.ItemRequirements["01"]
			if result and type(requirements) == "string" then
				local parts = {}
				for part in requirements:gmatch("item_([%w_]+)") do parts[#parts + 1] = part end
				build.recipes[result] = parts
			end
		end
	end
	return set
end

function build.cost(it, name)
	local m = it.meta[it.by_name[name] or -1]
	if m then return m.cost end
	build.splits()
	return build.prices[name] or 0
end

function build.parts(it, name)
	build.splits()
	local own = build.recipes[name]
	if own then return own end
	local id, out = it.by_name[name], {}
	if not id then return out end
	for c, ups in pairs(it.up) do
		for _, p in ipairs(ups) do if p == id and it.meta[c] then out[#out + 1] = it.meta[c].name end end
	end
	return out
end

function build.boots(name) return ITEM.BOOTS[name] == true end

function build.keepness(it, fin, name)
	local id = it.by_name[name]
	local w = build.weight or fin
	return (id and w[id] or 0) + build.cost(it, name) / 1e6 + (id and build.final and build.final[id] and 1 or 0)
end

function build.family(it, name)
	local out = nil
	if ITEM.FAMILY[name] then out = {[name] = true} end
	for _, p in ipairs(build.parts(it, name)) do
		if ITEM.FAMILY[p] then
			out = out or {}
			out[p] = true
		end
	end
	return out
end

function build.sameFamily(it, a, b)
	local fa = build.family(it, a)
	if not fa then return false end
	for f in pairs(build.family(it, b) or {}) do if fa[f] then return true end end
	return false
end

function build.uses(it, name, part)
	if name == part then return true end
	for _, p in ipairs(build.parts(it, name)) do if p == part then return true end end
	local pid, fid = it.by_name[part], it.by_name[name]
	return pid ~= nil and fid ~= nil and build.chain(it, pid)[fid] == true
end

function build.reuse(it, list, i, name)
	local keeps, missing, taken = {}, {}, {}
	for _, part in ipairs(build.parts(it, name)) do
		if build.cost(it, part) >= ITEM.SPLIT_PART then
			local target = nil
			for k = i, #list do
				if list[k].min - list[i].min > ITEM.SPLIT_WAIT then break end
				if not taken[k] and build.uses(it, list[k].name, part) then target = k; break end
			end
			if target then
				taken[target] = true
				keeps[#keeps + 1] = {part = part, ["for"] = list[target].name, now = target == i}
			else
				missing[#missing + 1] = part
			end
		end
	end
	return keeps, missing
end

function build.splitInto(held, x, victim, keeps)
	x.acts[#x.acts + 1] = {kind = "split", item = victim, keeps = keeps}
	for _, k in ipairs(keeps) do
		if not k.now then table.insert(held, #held + 1, {name = k.part, min = x.min}) end
	end
end

function build.simOne(it, list, fin)
	local held, splits = {}, build.splits()
	for i, x in ipairs(list) do
		x.acts = {}
		local id = it.by_name[x.name]
		if ITEM.CONSUME[x.name] then
			x.acts[1] = {kind = "consume", item = x.name}
		elseif id and x.name ~= ITEM.SHARD and not x.used then
			for j = #held, 1, -1 do
				local hid = it.by_name[held[j].name]
				if hid and build.chain(it, hid)[id] then table.remove(held, j) end
			end
			for _, part in ipairs(build.parts(it, x.name)) do
				local direct = false
				for _, y in ipairs(held) do direct = direct or y.name == part end
				if not direct then
					for j = #held, 1, -1 do
						local y = held[j]
						local yid = it.by_name[y.name]
						local has = false
						for _, inner in ipairs(splits[y.name] and build.parts(it, y.name) or {}) do has = has or inner == part end
						local later = false
						for k = i + 1, #list do later = later or build.uses(it, list[k].name, y.name) end
						if has and not later and held[j] == y then
							local keeps, missing = build.reuse(it, list, i, y.name)
							local final = yid and build.final and build.final[yid]
							local now = false
							for _, kp in ipairs(keeps) do now = now or (kp.now and kp.part == part) end
							if now and (not final or #missing == 0) then
								table.remove(held, j)
								build.splitInto(held, x, y.name, keeps)
							elseif now and build.blocked then
								build.blocked[#build.blocked + 1] = {missing = missing, at = x.bear, min = x.min}
							end
						end
					end
				end
			end
			if build.boots(x.name) then
				for j = #held, 1, -1 do
					if build.boots(held[j].name) then x.acts[#x.acts + 1] = {kind = "sell", item = table.remove(held, j).name} end
				end
			end
			for _ = 1, x.q or 1 do held[#held + 1] = {name = x.name, min = x.min} end
			local future = {}
			for k = i + 1, #list do
				local fid = it.by_name[list[k].name]
				if fid then future[fid] = true end
			end
			local function needed(name)
				local hid = it.by_name[name]
				for p in pairs(hid and build.chain(it, hid) or {}) do if future[p] then return true end end
				return false
			end
			while #held > ITEM.SLOTS do
				local vi, vs, aghs = nil, math.huge, nil
				if x.swap then
					for j = 1, #held - 1 do if held[j].name == x.swap then vi, vs = j, -1 end end
				end
				if x.hyper then
					for j = 1, #held - 1 do if build.boots(held[j].name) then vi, vs = j, -1 end end
				end
				for pass = 1, 2 do
					for j = 1, #held - 1 do if held[j].name == ITEM.SCEPTER then aghs = j end end
					if vi then break end
					for j = 1, #held - 1 do
						local y = held[j]
						if y.name == ITEM.SCEPTER then
							aghs = j
						elseif (not build.boots(y.name) or build.boots(x.name)) and (pass == 2 or (not needed(y.name) and x.min - y.min >= ITEM.HOLD)) then
							local v = build.keepness(it, fin, y.name)
							if v < vs then vi, vs = j, v end
						end
					end
					if vi then break end
				end
				local spare = not (build.final and build.final[it.by_name[ITEM.SCEPTER] or -1])
				if aghs and not x.swap and (x.blessing or (spare and (not vi or vs >= 1)) or (x.min >= ITEM.EAT_MIN and (not vi or vs >= build.keepness(it, fin, ITEM.SCEPTER)))) then
					x.acts[#x.acts + 1] = {kind = "eat", item = ITEM.SCEPTER}
					table.remove(held, aghs)
				elseif vi then
					local victim = table.remove(held, vi).name
					local keeps = splits[victim] and build.reuse(it, list, i, victim) or {}
					if #keeps > 0 then build.splitInto(held, x, victim, keeps)
					else x.acts[#x.acts + 1] = {kind = "sell", item = victim} end
				else
					x.over = true
					break
				end
			end
		end
	end
	return held
end

function build.sim(it, list, fin)
	local hero, bear = {}, {}
	for _, x in ipairs(list) do
		if x.bear then bear[#bear + 1] = x else hero[#hero + 1] = x end
	end
	local held = build.simOne(it, hero, fin)
	for _, y in ipairs(build.simOne(it, bear, fin)) do
		y.bear = true
		held[#held + 1] = y
	end
	return held
end

function build.finalSet(it, e, counters, route, start)
	local cand, pr, w = {}, build.rates(e), {}
	for id, p in pairs(e.final) do w[id] = p end
	for id, p in pairs(pr) do
		if (w[id] or 0) == 0 and p >= ITEM.UPGRADE then w[id] = p * ITEM.FINAL_FROM_PR end
	end
	local sunk = {}
	for _, x in ipairs(route.list) do
		local id = it.by_name[x.name]
		local m = id and it.meta[id]
		if m and m.cost >= ITEM.STEP_COST then
			for u in pairs(build.chain(it, id)) do sunk[u] = true end
		end
	end
	for id, p in pairs(w) do
		local m = it.meta[id]
		if m and p >= ITEM.FINAL_MIN and (m.cost >= ITEM.STEP_COST or build.boots(m.name)) and not ITEM.CONSUME[m.name] then
			cand[#cand + 1] = {id = id, w = p + (sunk[id] and ITEM.SUNK or 0)}
		end
	end
	table.sort(cand, function(a, b) if a.w ~= b.w then return a.w > b.w end return a.id < b.id end)
	local set, n, boots = {}, 0, false
	local walk, shoes = false, {}
	for _, list in ipairs({start or {}, route.list}) do
		for _, x in ipairs(list) do
			if build.boots(x.name) then
				walk = true
				local id = it.by_name[x.name]
				for u in pairs(id and build.chain(it, id) or {}) do shoes[u] = true end
			end
		end
	end
	if walk then
		n = 1
		local plain = it.by_name.boots
		for u in pairs(plain and build.chain(it, plain) or {}) do
			if it.meta[u] and ITEM.TRAVEL[it.meta[u].name] then shoes[u] = true end
		end
	end
	local function siblings(a, b)
		for _, ups in pairs(it.up) do
			local ha, hb = false, false
			for _, u in ipairs(ups) do ha, hb = ha or u == a, hb or u == b end
			if ha and hb then return true end
		end
		return false
	end
	local blink = it.by_name.blink
	local blinks = blink and build.chain(it, blink) or {}
	local function clash(id)
		local up = build.chain(it, id)
		for other, v in pairs(set) do
			if up[other] or build.chain(it, other)[id] then return true end
			if blinks[id] and blinks[other] then return true end
			if build.sameFamily(it, it.meta[id].name, it.meta[other].name) then return true end
			if v == 2 and not build.boots(it.meta[id].name) and siblings(id, other) then return true end
		end
		return false
	end
	if not walk then
		local total, best = 0, nil
		for _, c in ipairs(cand) do
			local name = it.meta[c.id].name
			if build.boots(name) then
				total = total + c.w
				if not best or (it.meta[best.id].name == "boots" and c.w >= ITEM.BOOTS_UP) then best = c end
			end
		end
		if best and total >= ITEM.BOOTS_W then
			set[best.id] = 1
			n, boots = n + 1, true
		end
	end
	for _, c in ipairs(counters) do
		if c.id and not c.used and not set[c.id] then
			set[c.id] = 2
			n = n + 1
			boots = boots or build.boots(c.name)
		end
	end
	for _, c in ipairs(cand) do
		if n >= ITEM.SLOTS then break end
		local name = it.meta[c.id].name
		local b = build.boots(name)
		if not set[c.id] and not clash(c.id) and not (b and boots) and not (b and walk and not shoes[c.id]) then
			set[c.id] = 1
			if not (b and walk) then n = n + 1 end
			boots = boots or b
		end
	end
	local function upgrade()
		local ids = {}
		for id in pairs(set) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local best, bp = nil, ITEM.UPGRADE
			for _, u in ipairs(it.up[id] or {}) do
				if it.meta[u] and not set[u] and (pr[u] or 0) >= bp then best, bp = u, pr[u] end
			end
			if best then set[best], set[id] = set[id], nil end
		end
	end
	upgrade()
	local aghs = it.by_name[ITEM.SCEPTER]
	if aghs and set[aghs] then
		for _, c in ipairs(cand) do
			local name = it.meta[c.id].name
			if not set[c.id] and not clash(c.id) and not build.boots(name) then set[c.id] = 4; break end
		end
		upgrade()
	end
	local cheap = {}
	for id, v in pairs(set) do
		local m = it.meta[id]
		local grows = false
		for u in pairs(build.chain(it, id)) do grows = grows or math.max(w[u] or 0, pr[u] or 0) >= ITEM.GROW end
		if v == 1 and m and m.cost < ITEM.LATE_SWAP and (w[id] or 0) < ITEM.LATE_SWAP_W and not build.boots(m.name) and not grows then
			cheap[#cheap + 1] = id
		end
	end
	table.sort(cheap, function(a, b) return (w[a] or 0) < (w[b] or 0) end)
	build.swaps = {}
	local extra = 0
	for _, c in ipairs(cand) do
		if extra >= math.min(#cheap, ITEM.LATE_EXTRA) then break end
		local m = it.meta[c.id]
		if not set[c.id] and not clash(c.id) and not build.boots(m.name) and m.cost >= ITEM.LATE_COST and c.w >= ITEM.LATE_W then
			set[c.id] = 3
			extra = extra + 1
			build.swaps[c.id] = it.meta[cheap[extra]].name
		end
	end
	upgrade()
	build.weight = w
	return set
end

function build.fill(it, e, route, mins, final)
	local keep = {}
	for _, x in ipairs(route.list) do
		local id = it.by_name[x.name]
		local ok = true
		if id and not final[id] and not x.counter and x.min >= ITEM.LATE_DROP and x.name ~= ITEM.SHARD and x.name ~= ITEM.SCEPTER then
			ok = false
			for f in pairs(final) do if build.chain(it, id)[f] then ok = true end end
		end
		if ok then keep[#keep + 1] = x end
	end
	route.list, route.at = {}, {}
	for _, x in ipairs(keep) do build.add(route, x) end
	local late = {}
	for id, v in pairs(final) do
		local m = it.meta[id]
		local name = m and build.baseName(it, id)
		if name and v >= 3 then
			late[#late + 1] = {name = name, w = build.weight[id] or 0, blessing = v == 4, swap = build.swaps[id]}
		elseif name and not route.at[name] then
			build.add(route, {name = name, min = math.max(mins[id] or it.typical[id] or ITEM.LATE, ITEM.LUX_MIN), q = 1, lux = true})
		end
	end
	table.sort(late, function(a, b) if a.w ~= b.w then return a.w > b.w end return a.name < b.name end)
	for _, x in ipairs(late) do
		local last = 0
		for _, y in ipairs(route.list) do last = math.max(last, y.min) end
		local i = route.at[x.name]
		if i then table.remove(route.list, i) end
		route.at = {}
		for j, y in ipairs(route.list) do route.at[y.name] = j end
		build.add(route, {name = x.name, min = math.max(last + 2, ITEM.EAT_MIN), q = 1, lux = true, blessing = x.blessing, swap = x.swap})
	end
	for name in pairs(ITEM.CONSUME) do
		local id = it.by_name[name]
		local p = 0
		for _, list in ipairs({e.core, e.mid}) do
			for _, x in ipairs(list) do if x.id == id then p = math.max(p, x.pr) end end
		end
		if id and p >= ITEM.LUX_PR and not route.at[name] then
			local last = 0
			for _, y in ipairs(route.list) do last = math.max(last, y.min) end
			build.add(route, {name = name, min = math.max(last, mins[id] or 0), q = 1})
		end
	end
end

function build.worth(it, fin, x)
	if x.over then return false end
	for _, act in ipairs(x.acts) do
		if act.kind == "sell" and build.keepness(it, fin, act.item) >= ITEM.SELL_FINAL then return false end
	end
	return true
end

function build.prune(it, e, plan)
	for _ = 1, 64 do
		build.sim(it, plan.row, e.final)
		local drop, at = nil, {}
		for i, x in ipairs(plan.row) do at[x.name] = i end
		for i, x in ipairs(plan.row) do
			local id = it.by_name[x.name]
			if not drop and not x.counter and not (id and build.final[id]) and not build.worth(it, e.final, x) then drop = i end
			for _, act in ipairs(x.acts) do
				local j = at[act.item]
				local y = j and plan.row[j]
				local yid = y and it.by_name[y.name]
				if not drop and act.kind == "sell" and y and not y.counter and not (yid and build.final[yid])
					and build.cost(it, y.name) >= ITEM.STEP_COST and x.min - y.min < ITEM.SOLD_SOON then drop = j end
			end
		end
		if not drop then return end
		table.remove(plan.row, drop)
	end
end

function build.stepping(it, e, route)
	local keep = {}
	for i, x in ipairs(route.list) do
		local id = it.by_name[x.name]
		local ok = true
		if id and it.up[id] and x.min > ITEM.EARLY_PART and (e.final[id] or 0) < ITEM.PART_FINAL and not x.counter then
			ok = false
			local ups = build.chain(it, id)
			for j = i + 1, #route.list do
				local u = it.by_name[route.list[j].name]
				if u and ups[u] then ok = true end
			end
		end
		if ok and id then
			local ups = build.chain(it, id)
			for j = 1, i - 1 do
				local u = it.by_name[route.list[j].name]
				if u and ups[u] then ok = false end
			end
		end
		if ok then keep[#keep + 1] = x end
	end
	route.list, route.at = {}, {}
	for _, x in ipairs(keep) do build.add(route, x) end
end

function build.blessing(plan)
	local row = {}
	for _, x in ipairs(plan.row) do
		local rest = {}
		for _, act in ipairs(x.acts or {}) do
			if act.kind == "eat" then
				row[#row + 1] = {name = ITEM.BLESSING, min = x.min, q = 1, used = true, acts = {act}, bear = x.bear}
			else
				rest[#rest + 1] = act
			end
		end
		x.acts = rest
		row[#row + 1] = x
	end
	plan.row = row
end

function build.grow(it, e, plan, mins)
	local pr, have, last = build.rates(e), {}, {}
	for _, x in ipairs(plan.row) do
		have[x.name] = true
		local k = x.bear and 2 or 1
		last[k] = math.max(last[k] or 0, x.min)
	end
	local added, held, shod = false, build.sim(it, plan.row, e.final), {}
	for _, y in ipairs(held) do if build.boots(y.name) then shod[y.bear and 2 or 1] = true end end
	for _, y in ipairs(held) do
		local id = it.by_name[y.name]
		local best, bp = nil, ITEM.GROW
		for _, u in ipairs(id and it.up[id] or {}) do
			local m = it.meta[u]
			local w = math.max(pr[u] or 0, e.final[u] or 0)
			local extraBoots = build.boots(m and m.name or "") and not build.boots(y.name) and shod[y.bear and 2 or 1]
			if m and not extraBoots and not have[build.baseName(it, u)] and w >= bp then best, bp = u, w end
		end
		if best then
			local name = build.baseName(it, best)
			local k = y.bear and 2 or 1
			have[name] = true
			plan.row[#plan.row + 1] = {name = name, min = math.max(mins[best] or it.typical[best] or 0, (last[k] or 0) + 1), q = 1, lux = true, bear = y.bear}
			added = true
		end
	end
	if added then
		build.order(plan.row)
		build.prune(it, e, plan)
	end
end

function build.hyper(it, e, plan, pos)
	local w, pr = build.weight or e.final, build.rates(e)
	local held, shoe, have, last = build.sim(it, plan.row, e.final), nil, {}, 0
	for _, x in ipairs(plan.row) do
		have[x.name] = true
		if not x.bear then last = math.max(last, x.min) end
	end
	for _, y in ipairs(held) do if not y.bear and build.boots(y.name) then shoe = y end end
	if pos > 3 or not shoe or not ITEM.HYPER_SELL[shoe.name] then return end
	for name in pairs(ITEM.TRAVEL) do
		local id = it.by_name[name]
		if id and math.max(w[id] or 0, pr[id] or 0) >= ITEM.LUX_PR then return end
	end
	local best, bv = nil, ITEM.HYPER_W
	local blink = it.by_name.blink
	local blinks = blink and build.chain(it, blink) or {}
	for id, v in pairs(w) do
		local m = it.meta[id]
		if m and v >= bv and m.cost >= ITEM.HYPER_COST and not build.boots(m.name) and not ITEM.CONSUME[m.name] and not have[build.baseName(it, id)] then
			local clash = false
			for _, y in ipairs(held) do
				local hid = it.by_name[y.name]
				if hid and (build.chain(it, hid)[id] or build.chain(it, id)[hid] or (blinks[id] and blinks[hid])) then clash = true end
				if build.sameFamily(it, y.name, m.name) then clash = true end
			end
			if not clash then best, bv = id, v end
		end
	end
	if not best then return end
	plan.row[#plan.row + 1] = {name = build.baseName(it, best), min = math.max(last + 3, ITEM.HYPER_MIN), q = 1, lux = true, hyper = true}
	build.sim(it, plan.row, e.final)
end

function build.alts(it, route, final)
	local drop = {}
	local function counter(id)
		local x = route.list[route.at[build.baseName(it, id)]]
		return x and x.counter ~= nil
	end
	for _, ups in pairs(it.up) do
		local here = {}
		for _, u in ipairs(ups) do
			local name = build.baseName(it, u)
			if name and route.at[name] then here[#here + 1] = u end
		end
		for i = 1, #here do
			for j = 1, #here do
				local a, b = here[i], here[j]
				if a ~= b and not build.chain(it, a)[b] and not build.chain(it, b)[a] and not build.boots(it.meta[a].name) then
					local wins = counter(b) and not counter(a)
					if wins or (not counter(a) and final[b] and not final[a]) then drop[build.baseName(it, a)] = true end
				end
			end
		end
	end
	local w = build.weight or {}
	for i, x in ipairs(route.list) do
		for j, y in ipairs(route.list) do
			local a, b = it.by_name[x.name], it.by_name[y.name]
			if i ~= j and a and b and not build.chain(it, a)[b] and not build.chain(it, b)[a] and build.sameFamily(it, x.name, y.name) then
				local fa, fb = final[a] ~= nil or x.counter ~= nil, final[b] ~= nil or y.counter ~= nil
				if (fb and not fa) or (fa == fb and ((w[b] or 0) > (w[a] or 0) or ((w[b] or 0) == (w[a] or 0) and j < i))) then drop[x.name] = true end
			end
		end
	end
	local keep = {}
	for _, x in ipairs(route.list) do if not drop[x.name] or x.counter then keep[#keep + 1] = x end end
	route.list, route.at = {}, {}
	for _, x in ipairs(keep) do build.add(route, x) end
end

function build.leftover(it, e, plan)
	build.blocked = {}
	build.sim(it, plan.row, e.final)
	local blocked = build.blocked
	build.blocked = nil
	if #blocked == 0 then return end
	local pr, w = build.rates(e), build.weight or e.final
	local have = {}
	for _, x in ipairs(plan.row) do have[x.name] = true end
	local added = false
	for _, b in ipairs(blocked) do
		local picks = {}
		for _, part in ipairs(b.missing) do
			local pid = it.by_name[part]
			local best, bv = nil, ITEM.LEFT_W
			for u in pairs(pid and build.chain(it, pid) or {}) do
				local m = it.meta[u]
				local v = math.max(pr[u] or 0, w[u] or 0)
				if m and v >= bv and m.cost >= ITEM.STEP_COST and not build.boots(m.name) and not have[build.baseName(it, u)] then best, bv = u, v end
			end
			if not best then picks = nil; break end
			picks[#picks + 1] = best
		end
		for _, u in ipairs(picks or {}) do
			local name = build.baseName(it, u)
			if not have[name] then
				have[name] = true
				plan.row[#plan.row + 1] = {name = name, min = b.min + 3, q = 1, lux = true, bear = b.at}
				added = true
			end
		end
	end
	if added then
		build.order(plan.row)
		build.prune(it, e, plan)
	end
end

function build.bears(it, ct, plan)
	for _, list in ipairs({plan.start, plan.row}) do
		for _, x in ipairs(list) do
			local v = ct.bear[x.name]
			if v then x.bear = v > ITEM.BEAR else x.bear = build.cost(it, x.name) >= ITEM.STEP_COST end
		end
	end
end

function build.tidy(it, row, pool)
	for i = 1, #row - 1 do
		local a, b = row[i], row[i + 1]
		local pa, pb = pool[it.by_name[a.name] or -1] or 0, pool[it.by_name[b.name] or -1] or 0
		if a.bear == b.bear and not a.used and not b.used and b.min - a.min < ITEM.TIE and pb > pa + ITEM.TIE_PR then
			row[i], row[i + 1] = b, a
			b.min, a.min = a.min, b.min
		end
	end
end

function build.levels(it, e, plan)
	local top = {}
	local function seen(id, pr)
		local m = it.meta[id]
		if not m then return end
		local base, n = m.name:match("^(.-)_(%d)$")
		if not base or base ~= build.baseName(it, id) then return end
		if pr ~= nil and pr < ITEM.LUX_PR then return end
		n = tonumber(n)
		if not top[base] or n > top[base].n then top[base] = {n = n, name = m.name} end
	end
	for _, x in ipairs(e.path) do seen(x.id) end
	for _, list in ipairs({e.core, e.mid}) do
		for _, x in ipairs(list) do seen(x.id, x.pr) end
	end
	for _, x in ipairs(plan.row) do if top[x.name] then x.name = top[x.name].name end end
end

function dd.plan(heroName, pos, enemies, enemyItems)
	local it = data.items()
	local hero = data.heroes[shortName(heroName)]
	if not it or not hero or not hero.id then return nil end
	enemyItems = enemyItems or {}
	local names, itemSig = {}, {}
	for _, enemy in ipairs(enemies or {}) do names[#names + 1] = shortName(enemy) end
	table.sort(names)
	for _, enemy in ipairs(names) do
		local owned = {}
		for item in pairs(enemyItems[enemy] or {}) do owned[#owned + 1] = item end
		table.sort(owned)
		itemSig[#itemSig + 1] = enemy .. "=" .. table.concat(owned, ",")
	end
	local ans, ct = data.answers(), data.counters()
	local key = table.concat({hero.h, tostring(pos), table.concat(itemSig, ";"), tostring(it.time), tostring(ans and ans.time), tostring(ct and ct.time)}, "|")
	if build.cache[key] then return build.cache[key] end
	if build.cached >= 16 then build.cache, build.cached = {}, 0 end
	local plan = {key = key, start = {}, row = {}, counters = {}}
	local e = it.hero[hero.id] and it.hero[hero.id][pos]
	if not build.roleOk(e) then
		local best
		for p = 1, 5 do
			local candidate = it.hero[hero.id] and it.hero[hero.id][p]
			if build.roleOk(candidate) and (not best or candidate.n > best.n) then best, pos = candidate, p end
		end
		e = best
		if not e then return nil end
		plan.fallbackPos = pos
	end
	local inStart = build.startKit(it, e, plan)
	local pr, mins = build.rates(e)
	local route = build.route(it, e, inStart)
	for _, name in ipairs({ITEM.SCEPTER, ITEM.SHARD}) do
		local id = it.by_name[name]
		if id and (pr[id] or 0) >= ITEM.AGHS then build.add(route, {name = name, min = mins[id] or ITEM.LATE, q = 1}) end
	end
	build.steps(it, route, pr, mins)
	local pool = {}
	for id, p in pairs(e.final) do pool[id] = p end
	for id, p in pairs(pr) do pool[id] = math.max(pool[id] or 0, p) end
	for i, c in ipairs(build.answers(it, hero, pos, names, pool, route, enemyItems)) do
		plan.counters[i] = c
		if c.own then
			route.list[route.at[c.name]].counter = c
		else
			local m = c.id and (mins[c.id] or it.typical[c.id]) or c.min + 2
			build.add(route, {name = c.name, min = m, q = 1, counter = c, used = c.used})
		end
	end
	build.order(route.list)
	route.at = {}
	for i, x in ipairs(route.list) do route.at[x.name] = i end
	build.stepping(it, e, route)
	local final = build.finalSet(it, e, plan.counters, route, plan.start)
	build.final = final
	build.fill(it, e, route, mins, final)
	build.alts(it, route, final)
	plan.row = build.order(route.list)
	build.tidy(it, plan.row, pool)
	plan.split = hero.h == ITEM.BEAR_HERO and ct ~= nil and next(ct.bear) ~= nil
	if plan.split then build.bears(it, ct, plan) end
	build.levels(it, e, plan)
	build.prune(it, e, plan)
	build.grow(it, e, plan, mins)
	build.leftover(it, e, plan)
	if plan.split then build.bears(it, ct, plan) end
	build.prune(it, e, plan)
	build.hyper(it, e, plan, pos)
	build.blessing(plan)
	build.cache[key], build.cached = plan, build.cached + 1
	return plan
end

function dd.acts(entries)
	local it = data.items()
	if not it then return nil end
	local row, final = {}, {}
	for i, entry in ipairs(entries) do row[i] = {name = entry.name, min = entry.min or i, q = 1} end
	for i, x in ipairs(row) do
		local id = it.by_name[x.name]
		local later = false
		for k = i + 1, #row do later = later or build.uses(it, row[k].name, x.name) end
		if id and not later and build.cost(it, x.name) >= ITEM.STEP_COST then final[id] = true end
	end
	local savedFinal, savedWeight = build.final, build.weight
	build.final, build.weight = final, {}
	local ok = pcall(build.simOne, it, row, final)
	build.final, build.weight = savedFinal, savedWeight
	return ok and row or nil
end

dd.ITEM = ITEM
return dd
