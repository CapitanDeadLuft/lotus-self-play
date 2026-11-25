local bb = {}
local JSON = require("assets.JSON")
local json = JSON.new and JSON:new({assert = function() end}) or JSON

bb.FILE = "build_brain_builds.txt"
bb.MIRRORS = {
	"https://raw.githubusercontent.com/BraVoEw/Scripts-Umbrella/%s/%s",
	"https://gcore.jsdelivr.net/gh/BraVoEw/Scripts-Umbrella@%s/%s",
	"https://fastly.jsdelivr.net/gh/BraVoEw/Scripts-Umbrella@%s/%s",
	"https://cdn.jsdelivr.net/gh/BraVoEw/Scripts-Umbrella@%s/%s",
}
bb.BRANCH = "build-brain-data"
bb.CHECK = 3600
bb.BUY_MIN = 3
bb.PASS_COST = 1500
bb.PASS_LATE = 600
bb.CORE_LIMIT = 11

bb.BOOTS = {item_boots = true, item_phase_boots = true, item_power_treads = true, item_tranquil_boots = true,
	item_arcane_boots = true, item_guardian_greaves = true, item_boots_of_bearing = true, item_travel_boots = true, item_travel_boots_2 = true}
bb.SKIP = {item_tpscroll = true, item_ward_observer = true, item_ward_sentry = true, item_ward_dispenser = true, item_smoke_of_deceit = true,
	item_dust = true, item_gem = true, item_tome_of_knowledge = true}

bb.FOE_TAGS = {
	abaddon = "save heal", abyssal_underlord = "ctl tank", alchemist = "heal tank ctl", ancient_apparition = "mag ctl", antimage = "esc",
	arc_warden = "eva", axe = "ctl brk tgt tank", bane = "ctl tgt", batrider = "ctl tgt esc", beastmaster = "ill ctl tgt",
	bloodseeker = "sil heal tgt", bounty_hunter = "inv", brewmaster = "ctl eva", bristleback = "brk tank", broodmother = "ill heal esc",
	centaur = "ctl brk tank", chaos_knight = "ill ctl tgt heal", chen = "heal ill", clinkz = "inv phys", crystal_maiden = "ctl mag",
	dark_seer = "ill ctl", dark_willow = "ctl mag tgt", dawnbreaker = "heal ctl", dazzle = "save heal", death_prophet = "sil heal mag",
	disruptor = "ctl sil mag", doom_bringer = "ctl tgt sil", dragon_knight = "brk tank heal ctl", drow_ranger = "phys sil brk", earth_spirit = "ctl sil esc",
	earthshaker = "ctl mag", elder_titan = "ctl", ember_spirit = "esc mag ctl", enchantress = "heal brk", enigma = "ctl ill",
	faceless_void = "ctl esc brk", furion = "ill esc", grimstroke = "ctl mag tgt sil", gyrocopter = "mag phys", hoodwink = "esc inv",
	huskar = "heal brk sil", invoker = "mag inv ctl", jakiro = "mag ctl", juggernaut = "heal phys brk", keeper_of_the_light = "mag",
	kez = "esc phys sil", kunkka = "ctl phys", largo = "save", legion_commander = "ctl tgt phys", leshrac = "mag ctl",
	lich = "mag ctl", life_stealer = "heal brk", lina = "mag tgt", lion = "ctl mag tgt", lone_druid = "phys ctl",
	luna = "phys mag", lycan = "ill phys heal", magnataur = "ctl", marci = "phys heal ctl", mars = "ctl brk tank",
	medusa = "phys ctl", meepo = "ill ctl esc", mirana = "inv ctl", monkey_king = "phys esc heal", morphling = "esc",
	muerta = "mag sil", naga_siren = "ill eva ctl", necrolyte = "heal mag tgt", nevermore = "phys mag", night_stalker = "ctl phys sil heal",
	nyx_assassin = "inv mag ctl", obsidian_destroyer = "mag", ogre_magi = "ctl tgt", omniknight = "save heal", oracle = "save heal",
	pangolier = "esc ctl", phantom_assassin = "eva phys brk", phantom_lancer = "ill esc", phoenix = "mag heal", primal_beast = "ctl tgt tank",
	puck = "esc mag sil", pudge = "ctl tgt tank heal", pugna = "mag heal", queenofpain = "esc mag heal", rattletrap = "ctl",
	razor = "phys", riki = "inv brk sil", ringmaster = "ctl save", rubick = "mag ctl tgt", sand_king = "ctl mag inv",
	shadow_demon = "save ctl", shadow_shaman = "ctl tgt", shredder = "mag esc tank brk", silencer = "sil", skeleton_king = "brk heal tgt",
	skywrath_mage = "mag tgt sil", slardar = "ctl phys", slark = "esc brk heal", snapfire = "mag ctl", sniper = "phys tgt",
	spectre = "brk phys", spirit_breaker = "ctl tgt", storm_spirit = "esc mag", sven = "phys ctl", techies = "mag ctl",
	templar_assassin = "phys inv", terrorblade = "ill phys", tidehunter = "ctl brk tank", tinker = "mag esc", tiny = "ctl phys",
	treant = "heal ctl inv save", troll_warlord = "phys brk heal", tusk = "ctl", undying = "heal", ursa = "phys brk",
	vengefulspirit = "ctl tgt", venomancer = "mag ill", viper = "brk mag", visage = "ill ctl", void_spirit = "esc mag",
	warlock = "ctl heal", weaver = "inv esc", windrunner = "eva ctl tgt", winter_wyvern = "save ctl tgt heal", wisp = "heal save",
	witch_doctor = "mag heal ctl", zuus = "mag",
}

bb.RULES = {
	{tag = "brk", items = {"item_silver_edge"}},
	{tag = "eva", items = {"item_monkey_king_bar", "item_bloodthorn"}},
	{tag = "heal", items = {"item_spirit_vessel", "item_skadi", "item_crellas_crozier", "item_orb_of_corrosion"}},
	{tag = "inv", items = {"item_dust", "item_ward_sentry"}},
	{tag = "ill", items = {"item_mjollnir", "item_bfury", "item_radiance", "item_shivas_guard", "item_maelstrom"}},
	{tag = "save", items = {"item_nullifier", "item_disperser", "item_sheepstick"}},
	{tag = "tgt", items = {"item_sphere", "item_lotus_orb", "item_aeon_disk", "item_black_king_bar"}},
	{tag = "sil", items = {"item_manta", "item_black_king_bar", "item_lotus_orb", "item_disperser", "item_cyclone", "item_guardian_greaves"}},
	{tag = "esc", items = {"item_orchid", "item_bloodthorn", "item_abyssal_blade", "item_sheepstick", "item_rod_of_atos", "item_gungir", "item_harpoon", "item_disperser", "item_diffusal_blade"}},
	{tag = "ctl", items = {"item_black_king_bar", "item_sphere", "item_lotus_orb", "item_manta", "item_aeon_disk", "item_glimmer_cape", "item_force_staff", "item_cyclone", "item_wind_waker"}},
	{tag = "mag", items = {"item_black_king_bar", "item_pipe", "item_mage_slayer", "item_glimmer_cape"}},
	{tag = "phys", items = {"item_ghost", "item_heavens_halberd", "item_shivas_guard", "item_crimson_guard", "item_assault", "item_blade_mail", "item_butterfly", "item_solar_crest", "item_force_staff", "item_ethereal_blade"}},
	{tag = "tank", items = {"item_desolator", "item_assault", "item_spirit_vessel", "item_skadi"}},
}

bb.ITEM_COUNTERS = {
	item_abyssal_blade = {"item_sphere", "item_lotus_orb", "item_aeon_disk"},
	item_aeon_disk = {"item_nullifier", "item_disperser"},
	item_black_king_bar = {"item_abyssal_blade", "item_ghost", "item_force_staff"},
	item_blade_mail = {"item_black_king_bar"},
	item_bloodstone = {"item_spirit_vessel", "item_skadi", "item_crellas_crozier", "item_orb_of_corrosion"},
	item_bloodthorn = {"item_manta", "item_lotus_orb", "item_black_king_bar"},
	item_butterfly = {"item_monkey_king_bar", "item_bloodthorn"},
	item_cyclone = {"item_sheepstick", "item_abyssal_blade"},
	item_dagon = {"item_black_king_bar", "item_lotus_orb", "item_glimmer_cape", "item_pipe"},
	item_desolator = {"item_ghost", "item_shivas_guard", "item_assault", "item_solar_crest"},
	item_ethereal_blade = {"item_nullifier", "item_disperser", "item_black_king_bar", "item_lotus_orb"},
	item_force_staff = {"item_sheepstick", "item_abyssal_blade", "item_harpoon"},
	item_ghost = {"item_nullifier", "item_disperser"},
	item_glimmer_cape = {"item_nullifier", "item_dust", "item_ward_sentry", "item_disperser"},
	item_greater_crit = {"item_ghost", "item_heavens_halberd", "item_shivas_guard", "item_butterfly"},
	item_guardian_greaves = {"item_spirit_vessel", "item_skadi", "item_crellas_crozier", "item_orb_of_corrosion"},
	item_gungir = {"item_manta", "item_cyclone", "item_black_king_bar"},
	item_heart = {"item_spirit_vessel", "item_skadi", "item_crellas_crozier", "item_orb_of_corrosion"},
	item_heavens_halberd = {"item_black_king_bar", "item_sphere", "item_lotus_orb"},
	item_holy_locket = {"item_spirit_vessel", "item_skadi", "item_crellas_crozier", "item_orb_of_corrosion"},
	item_hurricane_pike = {"item_sheepstick", "item_abyssal_blade", "item_harpoon"},
	item_invis_sword = {"item_dust", "item_ward_sentry"},
	item_lotus_orb = {"item_nullifier", "item_disperser"},
	item_manta = {"item_mjollnir", "item_bfury", "item_shivas_guard", "item_radiance"},
	item_monkey_king_bar = {"item_ghost", "item_heavens_halberd"},
	item_nullifier = {"item_sphere", "item_lotus_orb"},
	item_orchid = {"item_manta", "item_lotus_orb", "item_black_king_bar", "item_disperser"},
	item_refresher = {"item_black_king_bar", "item_aeon_disk"},
	item_rod_of_atos = {"item_manta", "item_cyclone", "item_black_king_bar", "item_disperser"},
	item_satanic = {"item_spirit_vessel", "item_skadi", "item_crellas_crozier", "item_heavens_halberd"},
	item_shadow_amulet = {"item_dust", "item_ward_sentry"},
	item_sheepstick = {"item_sphere", "item_lotus_orb", "item_black_king_bar"},
	item_silver_edge = {"item_dust", "item_ward_sentry"},
	item_sphere = {"item_rod_of_atos", "item_force_staff", "item_orchid", "item_cyclone", "item_dagon", "item_harpoon"},
	item_wind_waker = {"item_sheepstick", "item_abyssal_blade"},
}

bb.ROLE_ITEMS = {
	item_nullifier = "c", item_disperser = "c", item_diffusal_blade = "c", item_abyssal_blade = "c", item_black_king_bar = "c",
	item_manta = "c", item_sphere = "c", item_aeon_disk = "c", item_skadi = "c", item_crellas_crozier = "c", item_monkey_king_bar = "c",
	item_bloodthorn = "c", item_mjollnir = "c", item_bfury = "c", item_radiance = "c", item_maelstrom = "c", item_heavens_halberd = "c",
	item_assault = "c", item_butterfly = "c", item_silver_edge = "c", item_desolator = "c", item_mage_slayer = "c", item_harpoon = "c",
	item_hurricane_pike = "c", item_dagon = "c", item_ethereal_blade = "c", item_shivas_guard = "c", item_crimson_guard = "c",
	item_blade_mail = "c", item_orchid = "c", item_ward_sentry = "s", item_gem = "s", item_glimmer_cape = "s", item_solar_crest = "s",
	item_guardian_greaves = "s", item_urn_of_shadows = "s",
}
bb.ANYONE = {item_dust = true, item_ward_sentry = true, item_ward_observer = true, item_gem = true}
bb.UNIVERSAL = {item_dust = true, item_ward_sentry = true, item_ward_observer = true, item_gem = true, item_glimmer_cape = true,
	item_force_staff = true, item_ghost = true, item_spirit_vessel = true, item_black_king_bar = true}

local state = {text = nil, heroes = {}, loaded = false, busy = false, nextCheck = 0, error = nil, version = nil}
bb.state = state

local function clock() return os.clock() end

function bb.path()
	local dir = Engine.GetCheatDirectory() or ""
	if dir ~= "" and not dir:match("[\\/]$") then dir = dir .. "\\" end
	return dir .. bb.FILE
end

local function readFile(path)
	if not io or not io.open then return nil end
	local ok, f = pcall(io.open, path, "rb")
	if not ok or not f then return nil end
	local text = f:read("a")
	f:close()
	return text
end

function bb.setText(text)
	if type(text) ~= "string" or not text:match("^BB1\t") then return false end
	state.text, state.heroes, state.loaded = text, {}, true
	state.version = text:match("^BB1\t([^\t\n]+)")
	state.vision, state.matchups = nil, nil
	return true
end

function bb.load()
	if state.loaded then return state.text end
	if state.triedFile then return nil end
	state.triedFile = true
	local text = readFile(bb.path())
	if text and bb.setText(text) then return text end
	return nil
end

local function fetch(file, valid, done, index)
	index = index or 1
	local url = bb.MIRRORS[index]
	if not url then done(nil); return end
	local sent = HTTP.Request("GET", string.format(url, bb.BRANCH, file), {timeout = 30, headers = {["User-Agent"] = "Umbrella/self-play"}}, function(response)
		local body = tonumber(response.code) == 200 and response.response or nil
		if body and valid(body) then done(body) else fetch(file, valid, done, index + 1) end
	end, "self_play_bb_" .. file .. index)
	if not sent then fetch(file, valid, done, index + 1) end
end

function bb.tick(online)
	bb.load()
	if not online or state.busy or clock() < state.nextCheck then return end
	local checked = Config.ReadInt("self_play_build_brain", "checked", 0)
	if state.loaded and os.time() - checked < bb.CHECK then state.nextCheck = clock() + 600; return end
	state.busy, state.nextCheck = true, clock() + 120
	fetch("version.txt", function(body) return body:match("^%s*[^\t\n]+\t%d+%s*$") ~= nil end, function(body)
		local version = body and body:match("^%s*(.-)%s*$")
		if not version then state.busy, state.error = false, "version check failed"; return end
		Config.WriteInt("self_play_build_brain", "checked", os.time())
		if state.loaded and version == Config.ReadString("self_play_build_brain", "version", "") then state.busy = false; return end
		fetch("builds.txt", function(b) return b:match("^BB1\t") ~= nil and select(2, b:gsub("\n", "")) >= 100 end, function(text)
			state.busy = false
			if not text then state.error = "builds download failed"; return end
			bb.setText(text)
			Config.WriteString("self_play_build_brain", "version", version)
			local ok, f = pcall(io.open, bb.path(), "wb")
			if ok and f then f:write(text); f:close() end
			state.error = nil
		end)
	end)
end

function bb.hero(id)
	if not id or not bb.load() then return nil end
	local cached = state.heroes[id]
	if cached ~= nil then return cached or nil end
	local line = state.text:match("\n" .. id .. "\t([^\n]+)")
	local data = line and json:decode(line)
	state.heroes[id] = type(data) == "table" and data or false
	return state.heroes[id] or nil
end

function bb.vision()
	if state.vision ~= nil then return state.vision or nil end
	if not bb.load() then return nil end
	local out, any = {}, false
	for item, group, base, list in state.text:gmatch("\nE\t(item_[%w_]+)\t(%d)\t(%d+)\t([^\n]*)") do
		local foes = {}
		for id, lift in list:gmatch("(%d+):(%d+)") do foes[tonumber(id)] = tonumber(lift) end
		out[item] = out[item] or {}
		out[item][tonumber(group)] = {base = tonumber(base), foes = foes}
		any = true
	end
	state.vision = any and out or false
	return state.vision or nil
end

local function mainPosition(data)
	local best, count = nil, 0
	for p = 1, 5 do
		local entry = data[tostring(p)]
		if entry and (entry.n or 0) > count then best, count = p, entry.n end
	end
	return best
end

function bb.route(id, pos, exists)
	local data = bb.hero(id)
	if not data then return nil end
	local shown, entry = pos, data[tostring(pos)]
	if not entry or (entry.n or 0) < 100 then
		shown = mainPosition(data)
		entry = shown and data[tostring(shown)]
	end
	if not entry then return nil end
	exists = exists or function() return true end
	local start, route, pop, buy = {}, {}, {}, {}
	for _, name in ipairs(entry.start or {}) do if exists(name) then start[#start + 1] = name end end
	for _, row in ipairs(entry.early or {}) do
		if exists(row[1]) then route[#route + 1] = {name = row[1], tm = row[2] or 0, share = (row[3] or 0) / 100, early = true} end
	end
	for _, row in ipairs(entry.core or {}) do
		if exists(row[1]) then route[#route + 1] = {name = row[1], tm = row[2] or 0, share = (row[3] or 0) / 100} end
	end
	table.sort(route, function(a, b) return a.tm < b.tm end)
	while #route > bb.CORE_LIMIT do table.remove(route) end
	for _, row in ipairs(entry.sit or {}) do if exists(row[1]) then pop[#pop + 1] = {name = row[1], share = (row[2] or 0) / 100} end end
	if type(entry.buy) == "string" then
		for itemId, pct in entry.buy:gmatch("(%d+):(%d+)") do buy[tonumber(itemId)] = tonumber(pct) end
	end
	local skills = {}
	for level, name in ipairs(entry.skills or {}) do
		if type(name) == "string" and name ~= "" then skills[level] = name end
	end
	return {start = start, route = route, pop = pop, buyById = buy, skills = skills, talents = entry.talents, pos = shown, wanted = pos, games = entry.n or 0,
		winrate = (entry.g or 0) > 0 and (entry.w or 0) / entry.g or nil}
end

local function shortHero(name) return (name or ""):gsub("^npc_dota_hero_", "") end

function bb.counters(info)
	local role = info.role
	local support = (role and role.wanted or 1) >= 4
	local have = {}
	for _, step in ipairs(role and role.route or {}) do have[step.name] = true end
	for _, entry in ipairs(role and role.pop or {}) do have[entry.name] = true end
	local function buyRate(name)
		local id = info.itemId and info.itemId(name)
		return id and role and role.buyById and role.buyById[id] or nil
	end
	local function fits(name)
		if role and next(role.buyById or {}) ~= nil and not bb.ANYONE[name] then return have[name] == true or (buyRate(name) or 0) >= bb.BUY_MIN end
		local who = bb.ROLE_ITEMS[name] or "a"
		return who == "a" or (who == "s") == support
	end
	local function owned(name)
		return info.owned and info.owned(name) or false
	end
	local function options(list)
		local out = {}
		for pass = 1, 2 do
			for _, name in ipairs(list) do
				if (not info.exists or info.exists(name)) and fits(name) and not owned(name) and (have[name] == true) == (pass == 1) then out[#out + 1] = name end
			end
		end
		return out
	end
	local picks, index, foeItem = {}, {}, nil
	local function add(name, weight, reason)
		local entry = index[name]
		if not entry then
			entry = {name = name, weight = 0, reasons = {}}
			index[name] = entry
			picks[#picks + 1] = entry
		end
		entry.weight = entry.weight + weight
		entry.reasons[#entry.reasons + 1] = reason
	end
	local damage = info.damage or {}
	local total = (damage.phys or 0) + (damage.mag or 0) + (damage.pure or 0)
	local rules = {}
	for _, rule in ipairs(bb.RULES) do rules[rule.tag] = rule end
	if total > 1500 and (damage.mag or 0) / total >= 0.5 then
		local list = options(rules.mag.items)
		if list[1] then add(list[1], 3, "taking mostly magic damage") end
	end
	if total > 1500 and (damage.phys or 0) / total >= 0.6 then
		local list = options(rules.phys.items)
		if list[1] then add(list[1], 3, "taking mostly physical damage") end
	end
	for _, enemy in ipairs(info.enemies or {}) do
		for item in pairs(info.enemyItems and info.enemyItems[enemy] or {}) do
			local counters = bb.ITEM_COUNTERS["item_" .. item]
			if counters then
				local list = options(counters)
				if list[1] then
					add(list[1], 4, enemy .. " has " .. item)
					foeItem = foeItem or {name = list[1], enemy = enemy, item = item}
				end
			end
		end
	end
	local covered = {}
	local vision = bb.vision()
	if vision and info.heroId then
		local group = support and 2 or 1
		for _, item in ipairs({"item_dust", "item_ward_sentry"}) do
			local row = vision[item] and vision[item][group]
			for _, enemy in ipairs(info.enemies or {}) do
				local id = info.heroId(enemy)
				if row and id and row.foes[id] then covered[enemy] = true end
			end
		end
	end
	for _, rule in ipairs(bb.RULES) do
		local count = 0
		for _, enemy in ipairs(info.enemies or {}) do
			local tags = " " .. (bb.FOE_TAGS[shortHero(enemy)] or "") .. " "
			if tags:find(" " .. rule.tag .. " ", 1, true) and not (rule.tag == "inv" and covered[enemy]) then count = count + 1 end
		end
		if count > 0 then
			local list = options(rule.items)
			for _, name in ipairs(list) do
				if have[name] or bb.UNIVERSAL[name] or role and next(role.buyById or {}) ~= nil then
					add(name, count, rule.tag .. " x" .. count)
					break
				end
			end
		end
	end
	table.sort(picks, function(a, b)
		if a.weight ~= b.weight then return a.weight > b.weight end
		return a.name < b.name
	end)
	return picks, foeItem
end

function bb.plan(info)
	local role = info.heroId and bb.route(info.heroId(info.hero), info.pos, info.exists)
	if not role or #role.route == 0 then return nil end
	local picks, foeItem = {}, nil
	if info.counters ~= false then
		picks, foeItem = bb.counters({role = role, enemies = info.enemies, enemyItems = info.enemyItems, damage = info.damage,
			owned = info.owned, exists = info.exists, itemId = info.itemId, heroId = info.heroId})
	end
	local route = {}
	for _, step in ipairs(role.route) do route[#route + 1] = step end
	local present = {}
	for _, step in ipairs(route) do present[step.name] = true end
	local clockSeconds = math.max(0, info.clock or 0)
	local later = false
	for i = #route, 1, -1 do
		local step = route[i]
		local done = info.owned and info.owned(step.name)
		local cost = info.cost and info.cost(step.name) or 0
		if not done and cost <= bb.PASS_COST and (later or step.tm > 0 and clockSeconds > step.tm + bb.PASS_LATE) then step.passed = true end
		if done then later = true end
	end
	local nextIndex
	for i, step in ipairs(route) do
		if not step.passed and not (info.owned and info.owned(step.name)) then nextIndex = i; break end
	end
	local counters = {}
	if foeItem and not present[foeItem.name] then
		local at = math.min((nextIndex or #route) + 1, #route + 1)
		local tm = route[at - 1] and route[at - 1].tm or clockSeconds
		table.insert(route, at, {name = foeItem.name, tm = tm, counter = foeItem.enemy .. " has " .. foeItem.item})
		present[foeItem.name] = true
		counters[#counters + 1] = foeItem.name
	end
	local added = 0
	for _, keep in ipairs(info.keep or {}) do
		local name = keep:find("^item_") and keep or "item_" .. keep
		if not present[name] and not (info.owned and info.owned(name)) then
			local at = math.min(#route + 1, math.max((nextIndex or 1) + 1, 4))
			local tm = route[at - 1] and route[at - 1].tm or clockSeconds
			table.insert(route, at, {name = name, tm = tm, counter = "kept from an earlier counter pick"})
			present[name] = true
			counters[#counters + 1] = name
			added = added + 1
		end
	end
	for _, pick in ipairs(picks) do
		if added >= 2 then break end
		if not present[pick.name] and not bb.SKIP[pick.name] and pick.weight >= 2 then
			local at = math.min(#route + 1, math.max((nextIndex or 1) + 1, 4))
			local tm = route[at - 1] and route[at - 1].tm or clockSeconds
			table.insert(route, at, {name = pick.name, tm = tm, counter = table.concat(pick.reasons, ", ")})
			present[pick.name] = true
			counters[#counters + 1] = pick.name
			added = added + 1
		end
	end
	return {start = role.start, route = route, pop = role.pop, skills = role.skills, talents = role.talents, pos = role.pos, wanted = role.wanted,
		games = role.games, counters = counters, picks = picks}
end

function bb.version() return state.version or "" end

function bb.status()
	if state.error then return "Build Brain: " .. state.error end
	if not state.loaded then return state.busy and "Build Brain: downloading builds" or "Build Brain: no data yet" end
	return "Build Brain: " .. (state.version or "ready")
end

return bb
