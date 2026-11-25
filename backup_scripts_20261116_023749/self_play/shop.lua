local shop = {}
local protracker = require("self_play.protracker")
local draftData = require("self_play.draft_data")
local buildBrain = require("self_play.build_brain")
local strategy = require("self_play.strategy")
local heroModules = require("self_play.heroes.registry")
local vision = require("self_play.vision")
local deward = require("self_play.deward")
local detection = require("self_play.detection")
local inventoryCleanup = require("self_play.inventory_cleanup")

local cfg = {buyInterval = 1.5, courierInterval = 2, requestTimeout = 25, retryDelay = 40, cacheAge = 21600}
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function outOfStock(name, team)
	local kv = itemKV["item_" .. name]
	return kv and tonumber(kv.ItemStockMax or "0") > 0 and Item.GetStockCount(tonumber(kv.ID), team) <= 0
end

function shop.inventory(ctx)
	local counts, entries, seen = {}, {}, {}
	local courier = Couriers.GetLocal()
	local function scan(unit, lastSlot, localCargo)
		if not unit then return end
		for slot = 0, lastSlot do
			local item = NPC.GetItemByIndex(unit, slot)
			if item and not seen[item] and (unit == ctx.hero or localCargo or Item.GetPlayerOwnerID(item) == ctx.playerId) then
				seen[item] = true
				local name = Ability.GetName(item):gsub("^item_", "")
				local kv = itemKV["item_" .. name]
				local quantity = kv and kv.ItemRecipe == "1" and math.max(1, Item.GetCurrentCharges(item)) or 1
				counts[name] = (counts[name] or 0) + quantity
				entries[#entries + 1] = {item = item, name = name, slot = slot, unit = unit}
			end
		end
	end
	scan(ctx.hero, 16)
	scan(courier, 8, true)
	for _, unit in ipairs(Couriers.GetAll()) do
		if unit ~= courier and Entity.IsEntity(unit) and Entity.IsSameTeam(ctx.hero, unit) then scan(unit, 8, false) end
	end
	if ctx.heroModule and ctx.heroModule.inventoryUnits then
		for _, unit in ipairs(ctx.heroModule.inventoryUnits(ctx)) do scan(unit, 8) end
	end
	if NPC.HasShard(ctx.hero) then counts.aghanims_shard = math.max(1, counts.aghanims_shard or 0) end
	if NPC.HasModifier(ctx.hero, "modifier_item_ultimate_scepter_consumed")
		or NPC.HasScepter(ctx.hero) and not counts.ultimate_scepter and not counts.ultimate_scepter_2 then
		counts.ultimate_scepter_2 = math.max(1, counts.ultimate_scepter_2 or 0)
	end
	return counts, entries
end

function shop.init(ctx)
	ctx.shop = {
		items = ctx.planner.gameItems(ctx.catalog.items, itemKV),
		plan = ctx.planner.build(ctx.catalog, nil, ctx.role, ctx.clock),
		index = 1, completed = {}, quantities = {}, sells = {}, splits = {}, consume = {}, pinned = {},
		nextBuy = 0, nextCourier = 0, nextRequest = 0, nextSupply = 0, nextInventory = 0, nextPlan = 0,
		attempts = 0, buildWaitUntil = ctx.now + 12, source = "Offline role build", status = "Starting",
	}
	local hero = ctx.catalog.heroes[ctx.heroName]
	if hero then
		for _, role in ipairs(protracker.roles[ctx.role]) do
			local key = ctx.heroName .. "_pos" .. role
			local cached = Config.ReadString("self_play_protracker", key, "")
			local fetched = Config.ReadInt("self_play_protracker", key .. "_time", 0)
			local data = cached ~= "" and os.time() - fetched < 86400 and protracker.parse(cached, hero.id, role)
			local parsed = data and protracker.guide(ctx, data)
			if parsed then
				ctx.shop.guide, ctx.shop.protrackerRole = parsed, role
				ctx.shop.skillSource = protracker.source(role, ctx.role, true)
				if role == ctx.role and os.time() - fetched < cfg.cacheAge then ctx.shop.nextRequest = ctx.now + cfg.cacheAge end
				break
			end
		end
	end
	ctx.shop.plan = heroModules.plan(ctx, ctx.shop.plan)
	ctx.shop.restored = shop.restore(ctx)
end

local function applyPlan(ctx, plan, source)
	local state = ctx.shop
	plan = heroModules.plan(ctx, plan)
	if state.pending then
		state.deferredPlan, state.deferredSource = plan, source
	else
		if state.startedGoal and not ctx.planner.owns(ctx.shop.items, shop.inventory(ctx), state.startedGoal) then
			for index = #plan, 1, -1 do if plan[index] == state.startedGoal then table.remove(plan, index) end end
			table.insert(plan, 1, state.startedGoal)
		end
		state.plan, state.index, state.source = plan, 1, source
	end
end

function shop.enemyState(ctx)
	local enemies, items = {}, {}
	for _, unit in ipairs(Heroes.GetAll()) do
		if Entity.IsEntity(unit) and not Entity.IsSameTeam(ctx.hero, unit) and not NPC.IsIllusion(unit) and not NPC.IsMeepoClone(unit) then
			local name = draftData.shortName(NPC.GetUnitName(unit))
			if not items[name] then
				enemies[#enemies + 1] = name
				local owned = {}
				for slot = 0, 8 do
					local item = NPC.GetItemByIndex(unit, slot)
					if item then owned[(Ability.GetName(item):gsub("^item_", ""))] = true end
				end
				items[name] = owned
			end
		end
	end
	return enemies, items
end

function shop.hurt(ctx, data)
	if data.target ~= ctx.hero or not data.damage or data.damage <= 0 or not data.source or not Entity.IsEntity(data.source)
		or Entity.IsSameTeam(ctx.hero, data.source) or not NPC.IsHero(data.source) then return end
	local kind, types = "phys", Enum.DamageTypes or {}
	if data.ability then
		local damageType = Ability.GetDamageType(data.ability)
		if damageType == types.DAMAGE_TYPE_MAGICAL then kind = "mag"
		elseif damageType == types.DAMAGE_TYPE_PURE then kind = "pure" end
	end
	ctx.damageTaken = ctx.damageTaken or {phys = 0, mag = 0, pure = 0}
	ctx.damageTaken[kind] = ctx.damageTaken[kind] + data.damage
end

local function short(name) return (name:gsub("^item_", "")) end

local abilityNames
function shop.talentNames(counts)
	local out = {}
	if type(counts) ~= "table" or not next(counts) then return out end
	if not abilityNames then
		abilityNames = {}
		local kv = XHelpers.xkv:GetKV("npc_abilities")
		for name, entry in pairs(kv and kv.DOTAAbilities or {}) do
			local id = type(entry) == "table" and tonumber(entry.ID)
			if id and name:find("^special_bonus_") then abilityNames[id] = name end
		end
	end
	for id, count in pairs(counts) do
		local name = abilityNames[tonumber(id)]
		if name then out[name] = tonumber(count) or 0 end
	end
	return out
end

function shop.brainInfo(ctx, enemies, items)
	local catalog, state = ctx.catalog, ctx.shop
	local inventory
	local function heroId(name)
		local hero = catalog.heroes[name] or catalog.heroes["npc_dota_hero_" .. tostring(name)]
		return hero and hero.id
	end
	local function catalogItem(name) return catalog.items[short(name)] end
	return {hero = ctx.heroName, pos = ctx.role, enemies = enemies, enemyItems = ctx.settings.counterItems ~= false and items or {},
		damage = ctx.settings.counterItems ~= false and ctx.damageTaken or nil, clock = ctx.clock, heroId = heroId,
		exists = function(name) return state.items[short(name)] ~= nil end,
		itemId = function(name) local item = catalogItem(name); return item and item.id end,
		cost = function(name) local item = catalogItem(name); return item and item.cost or 0 end,
		owned = function(name)
			if state.completed[short(name)] then return true end
			inventory = inventory or state.counts or shop.inventory(ctx)
			return ctx.planner.owns(state.items, inventory, short(name))
		end,
		counters = ctx.settings.counterItems ~= false}
end

function shop.brainPlan(ctx, enemies, items)
	local state = ctx.shop
	buildBrain.tick(true)
	local info = shop.brainInfo(ctx, enemies, items)
	state.counterKeep = state.counterKeep or {}
	local keep = {}
	for name, expires in pairs(state.counterKeep) do
		local short = name:gsub("^item_", "")
		local started = state.startedGoal == short or state.plan and state.plan[state.index] == short
		if state.completed[short] then state.counterKeep[name] = nil
		elseif expires > ctx.now or started then keep[#keep + 1] = name
		else state.counterKeep[name] = nil end
	end
	table.sort(keep)
	info.keep = keep
	local plan = buildBrain.plan(info)
	if not plan then return false end
	for _, name in ipairs(plan.counters or {}) do
		local full = name:find("^item_") and name or "item_" .. name
		state.counterKeep[full] = math.max(state.counterKeep[full] or 0, ctx.now + 240)
	end
	local names, seen, quantities, rows = {}, {}, {}, {}
	local function add(name)
		name = short(name)
		if seen[name] or not state.items[name] or not ctx.planner.missing(state.items, name, {}) then return false end
		seen[name], names[#names + 1] = true, name
		return true
	end
	if ctx.clock < 90 then
		local counts = {}
		for _, name in ipairs(plan.start) do counts[short(name)] = (counts[short(name)] or 0) + 1 end
		for _, name in ipairs(plan.start) do
			if not buildBrain.SKIP[name] and add(name) then quantities[short(name)] = counts[short(name)] end
		end
	end
	for _, step in ipairs(plan.route) do
		if not step.passed and not buildBrain.SKIP[step.name] and add(step.name) then rows[#rows + 1] = {name = short(step.name), min = (step.tm or 0) / 60} end
	end
	if #names == 0 then return false end
	local key = table.concat(names, ",")
	state.providerError, state.nextPlan = nil, ctx.now + 15
	if not state.brainGuide and next(plan.skills) then
		state.brainGuide = {hero = ctx.heroName, support = ctx.role >= 4, title = "Build Brain pos " .. plan.pos, provider = "build_brain",
			role = plan.pos, groups = {}, skills = plan.skills, talents = {}, talentCounts = shop.talentNames(plan.talents)}
		state.guide, state.protrackerRole = state.brainGuide, plan.pos
		state.skillSource = "Skill order: Build Brain pos " .. plan.pos .. (plan.pos ~= ctx.role and " (fallback for pos " .. ctx.role .. ")" or "")
	end
	if key == state.brainKey then return true end
	state.brainKey, state.draftPlan = key, plan
	local sells, splits, consume = {}, {}, {}
	for _, x in ipairs(draftData.acts(rows) or {}) do
		for _, act in ipairs(x.acts or {}) do
			if act.kind == "sell" then sells[act.item] = x.name
			elseif act.kind == "split" then splits[act.item] = x.name
			elseif act.kind == "consume" then consume[act.item] = true end
		end
	end
	if seen.moon_shard then consume.moon_shard = true end
	local summary = table.concat(heroModules.plan(ctx, {table.unpack(names)}), ", ")
	if Log and summary ~= state.loggedBuild then
		state.loggedBuild = summary
		local counters = #plan.counters > 0 and " | counters: " .. table.concat(plan.counters, ", ") or ""
		Log.Write(string.format("[SelfPlay build] Build Brain %s pos %s: %s%s", tostring(ctx.heroName), tostring(plan.pos), summary, counters))
	end
	state.quantities, state.sells, state.splits, state.consume = quantities, sells, splits, consume
	state.counterItems = plan.counters
	applyPlan(ctx, names, "Build Brain " .. buildBrain.version() .. " pos " .. plan.pos
		.. (plan.pos ~= ctx.role and " (fallback for pos " .. ctx.role .. ")" or "")
		.. (#plan.counters > 0 and " +" .. #plan.counters .. " counters" or ""))
	return true
end

function shop.refreshPlan(ctx)
	local state = ctx.shop
	if not ctx.settings.online or ctx.now < state.nextPlan then return end
	draftData.tick()
	state.nextPlan = ctx.now + 2
	local enemies, items = shop.enemyState(ctx)
	if (ctx.settings.buildSource or 0) == 0 and shop.brainPlan(ctx, enemies, items) then return end
	local plan = draftData.plan(ctx.heroName, ctx.role, enemies, items)
	if not plan then
		if ctx.now >= state.buildWaitUntil then state.providerError = draftData.status() end
		return
	end
	state.providerError, state.nextPlan = nil, ctx.now + 15
	if plan == state.draftPlan then return end
	state.draftPlan, state.brainKey = plan, nil
	local names, seen, quantities, sells, splits, consume = {}, {}, {}, {}, {}, {}
	local function add(name)
		if seen[name] or not state.items[name] or not ctx.planner.missing(state.items, name, {}) then return false end
		seen[name], names[#names + 1] = true, name
		return true
	end
	if ctx.clock < 90 then
		for _, entry in ipairs(plan.start) do
			if add(entry.name) then quantities[entry.name] = entry.q or 1 end
		end
	end
	for _, entry in ipairs(plan.row) do
		add(entry.name)
		for _, act in ipairs(entry.acts or {}) do
			if act.kind == "sell" then sells[act.item] = entry.name
			elseif act.kind == "split" then splits[act.item] = entry.name
			elseif act.kind == "consume" then consume[act.item] = true end
		end
	end
	if #names == 0 then return end
	local summary = table.concat(heroModules.plan(ctx, {table.unpack(names)}), ", ")
	if Log and summary ~= state.loggedBuild then
		state.loggedBuild = summary
		Log.Write(string.format("[SelfPlay build] %s pos %s: %s", tostring(ctx.heroName), tostring(plan.fallbackPos or ctx.role), summary))
	end
	state.quantities, state.sells, state.splits, state.consume = quantities, sells, splits, consume
	applyPlan(ctx, names, "Draft Helper " .. draftData.key() .. " pos " .. (plan.fallbackPos or ctx.role)
		.. (plan.fallbackPos and " (fallback for pos " .. ctx.role .. ")" or ""))
end

function shop.fetch(ctx)
	local state = ctx.shop
	shop.refreshPlan(ctx)
	if state.requesting and ctx.now - state.requestStart > cfg.requestTimeout + 5 then
		state.requesting = false
		state.requestVersion = state.requestVersion + 1
		state.skillSource = "Skill order: Dota2ProTracker timed out"
	end
	if not ctx.settings.online or state.brainGuide or state.requesting or state.attempts >= 2 or ctx.now < state.nextRequest then return end
	local hero = ctx.catalog.heroes[ctx.heroName]
	if not hero then return end
	state.requestRoleIndex = state.requestRoleIndex or 1
	local role = protracker.roles[ctx.role][state.requestRoleIndex]
	if not role then return end
	state.attempts, state.requesting = state.attempts + 1, true
	state.requestStart = ctx.now
	state.requestVersion = (state.requestVersion or 0) + 1
	local version = state.requestVersion
	state.nextRequest = ctx.now + cfg.retryDelay
	local sent = HTTP.Request("GET", "https://dota2protracker.com/api/hero/" .. hero.id .. "/builds?position=pos%20" .. role,
		{timeout = cfg.requestTimeout, headers = {Accept = "application/json", ["User-Agent"] = protracker.userAgent,
			Referer = "https://dota2protracker.com/"}}, function(response)
			if not ctx.active or ctx.shop ~= state or version ~= state.requestVersion then return end
			state.requesting = false
			if not ctx.settings.online or state.brainGuide then return end
			local data, reason
			if tonumber(response.code) == 200 then data, reason = protracker.parse(response.response, hero.id, role) end
			local guide = data and protracker.guide(ctx, data)
			if guide then
				state.attempts, state.protrackerRole, state.guide = 2, role, guide
				state.skillSource = protracker.source(role, ctx.role, false)
				local key = ctx.heroName .. "_pos" .. role
				Config.WriteString("self_play_protracker", key, response.response)
				Config.WriteInt("self_play_protracker", key .. "_time", os.time())
			elseif reason == "empty" and state.requestRoleIndex < #protracker.roles[ctx.role] then
				state.requestRoleIndex, state.attempts, state.nextRequest = state.requestRoleIndex + 1, 0, ctx.now
				shop.fetch(ctx)
			else
				if reason == "empty" then state.attempts = 2 end
				state.skillSource = "Skill order unavailable: " .. tostring(reason or "HTTP " .. tostring(response.code))
			end
		end)
	if not sent then
		state.requesting = false
		state.skillSource = "Skill order request could not start"
	end
end

function shop.manageInventory(ctx)
	local state = ctx.shop
	if ctx.now < state.nextInventory or ctx.now < ctx.busyUntil or not Entity.IsAlive(ctx.hero) or NPC.IsChannellingAbility(ctx.hero) then return end
	state.nextInventory = ctx.now + 2
	state.pinned = state.pinned or {}
	local _, entries = shop.inventory(ctx)
	if ctx.heroModule and ctx.heroModule.inventory and ctx.heroModule.inventory(ctx, entries) then return end
	local lowest, highest, freeSlot = nil, nil, nil
	local goal = state.plan[state.index]
	for _, entry in ipairs(entries) do
		if goal and entry.unit ~= Couriers.GetLocal() and Item.IsCombineLocked(entry.item)
			and ctx.planner.contains(state.items, goal, entry.name) then
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK, 0, Vector(0, 0, 0), entry.item,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, entry.unit, false, false, false, true, "self_play_combine", false)
			return
		end
	end
	for _, entry in ipairs(entries) do
		if entry.unit == ctx.hero and entry.slot <= 5 and (state.consume[entry.name] or entry.name == "moon_shard")
			and Ability.IsReady(entry.item) then
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, ctx.hero, Vector(0, 0, 0), entry.item,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_consume", false)
			return
		end
	end
	for slot = 0, 5 do if not NPC.GetItemByIndex(ctx.hero, slot) then freeSlot = slot; break end end
	for _, entry in ipairs(entries) do
		if entry.unit == ctx.hero and entry.slot <= 8 then
			local record = ctx.catalog and ctx.catalog.items and entry.name and ctx.catalog.items[entry.name]
			entry.cost = record and record.cost or math.min(12000, Item.GetCost(entry.item))
			if vision.responsible(ctx) and vision.observers(entry.item) > 0 then entry.cost = entry.cost + 5000 end
			if vision.sentries(entry.item) > 0 and (deward.needed(ctx) and not ctx.intent or detection.opportunity(ctx)) then entry.cost = entry.cost + 5500 end
			if entry.name == "dust" and Item.GetCurrentCharges(entry.item) > 0 and detection.needed(ctx) then entry.cost = entry.cost + 6000 end
			if goal and ctx.planner.contains(ctx.shop.items, goal, entry.name) then entry.cost = entry.cost + 2000 end
			if entry.slot <= 5 and (state.pinned[entry.name] or 0) > ctx.now then entry.cost = entry.cost + 20000 end
			if entry.slot <= 5 and (not lowest or entry.cost < lowest.cost) then lowest = entry end
			if entry.slot >= 6 and (not highest or entry.cost > highest.cost) then highest = entry end
		end
	end
	local fighting = ctx.intent and ctx.intent.kind == "hero" or ctx.fightSession or ctx.retreating
		or Hero.GetRecentDamage(ctx.hero) > 0
	if highest and not fighting and (freeSlot or lowest and highest.cost > lowest.cost + 250) then
		Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, freeSlot or lowest.slot, Vector(0, 0, 0), highest.item,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true)
		state.pinned[highest.name] = ctx.now + 20
		return
	end
end

function shop.regeneration(ctx, inventory)
	if ctx.clock < 0 or ctx.clock >= 600 or not Entity.IsAlive(ctx.hero)
		or NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff") then return nil end
	local health, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local healthMissing = maximum - health - math.max(0, NPC.GetHealthRegen(ctx.hero)) * 25
	if healthMissing > 250 and not inventory.tango and not inventory.tango_single and not inventory.flask and not inventory.bottle
		and not NPC.HasModifier(ctx.hero, "modifier_tango_heal") and not NPC.HasModifier(ctx.hero, "modifier_flask_healing") then return "tango" end
	local mana, maximumMana = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero)
	local restored = math.max(0, NPC.GetManaRegen(ctx.hero)) * 25
	if inventory.soul_ring and health > maximum * 0.55 then restored = restored + 150 end
	if mana + restored < maximumMana * 0.4 and maximumMana - mana - restored >= 180
		and not inventory.clarity and not inventory.bottle and not inventory.arcane_boots and not inventory.guardian_greaves
		and not NPC.HasModifier(ctx.hero, "modifier_clarity_potion") then return "clarity" end
	return nil
end

shop.visionGoods = {ward_observer = true, ward_sentry = true, dust = true, smoke_of_deceit = true}

function shop.coreSkipsVision(ctx)
	if ctx.role >= 4 then return false end
	local main = 0
	for slot = 0, 5 do if NPC.GetItemByIndex(ctx.hero, slot) then main = main + 1 end end
	return ctx.clock >= 1500 or main >= 6
end

local function supply(ctx, inventory)
	local state = ctx.shop
	if ctx.clock < 0 then return false end
	local _, entries = shop.inventory(ctx)
	local detectionSupply = detection.supply(ctx, entries)
	local emergency = state.emergencyFlask and ctx.now < state.emergencyFlask and not inventory.flask
		and not NPC.HasModifier(ctx.hero, "modifier_flask_healing")
	if ctx.now < state.nextSupply and not detectionSupply and not emergency then state.supplyNote = "throttled"; return false end
	local name = shop.regeneration(ctx, inventory)
	if not inventory.tpscroll and Player.GetTotalGold(ctx.player) >= 200 then name = "tpscroll" end
	local observers = 0
	if vision.responsible(ctx) then
		local _, entries = shop.inventory(ctx)
		for _, entry in ipairs(entries) do observers = observers + vision.observers(entry.item) end
	end
	local carrier = vision.responsible(ctx) and ctx.role >= 4 and ctx.clock >= 600
	if (vision.needed(ctx) or carrier) and observers == 0
		and ctx.now >= (state.nextObserver or 0) then
		local observer = ctx.catalog.items.ward_observer
		if Item.GetStockCount(observer.id, ctx.team) > 0 then name = "ward_observer" end
	end
	if ctx.now >= (state.nextSentry or 0) and deward.needed(ctx) then
		local _, entries = shop.inventory(ctx)
		local sentries = 0
		for _, entry in ipairs(entries) do sentries = sentries + vision.sentries(entry.item) end
		if sentries == 0 then name = "ward_sentry" end
	end
	name = detectionSupply or emergency and "flask" or name
	if name and shop.visionGoods[name] and shop.coreSkipsVision(ctx) then
		state.supplyNote = "core leaves " .. name .. " to supports"
		return false
	end
	if not name then state.supplyNote = "nothing needed"; return false end
	local item = ctx.catalog.items[name]
	if outOfStock(name, ctx.team) or Player.GetTotalGold(ctx.player) < item.cost then state.supplyNote = "cannot buy " .. name; return false end
	state.supplyNote = "buy " .. name
	state.nextSupply = ctx.now + 30
	if name == "ward_observer" then state.nextObserver = ctx.now + (ctx.role == 2 and 240 or 180) end
	if name == "ward_sentry" then state.nextSentry = ctx.now + 60 end
	if name == "dust" then state.nextDust = ctx.now + 30 end
	if name == "flask" then state.emergencyFlask = nil end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, item.id, Vector(0, 0, 0), item.id,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_supply", false)
	return true
end

local function courierCast(ctx, courier, name)
	local ability = NPC.GetAbility(courier, name)
	if ability and Ability.IsReady(ability) then
		Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, Vector(0, 0, 0), ability,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, courier, false, false, false, true, "self_play_courier", false)
		return true
	end
	return false
end

function shop.freeSlot(ctx)
	for slot = 0, 8 do if not NPC.GetItemByIndex(ctx.hero, slot) then return true end end
	return false
end

function shop.cargo(holder, first, last)
	local names = {}
	for slot = first, last do
		local item = NPC.GetItemByIndex(holder, slot)
		if item then names[#names + 1] = Ability.GetName(item) end
	end
	table.sort(names)
	return table.concat(names, ",")
end

function shop.fits(ctx, holder, first, last)
	if shop.freeSlot(ctx) then return true end
	local owned = {}
	for slot = 0, 16 do
		local item = (slot <= 8 or slot >= 15) and NPC.GetItemByIndex(ctx.hero, slot)
		if item then owned[Ability.GetName(item)] = true end
	end
	local teleport = NPC.GetItemByIndex(ctx.hero, 15)
	for slot = first, last do
		local item = NPC.GetItemByIndex(holder, slot)
		if item then
			local name = Ability.GetName(item)
			if name == "item_tpscroll" and (not teleport or owned[name]) then return true end
			if name:find("^item_recipe_") then return true end
			if owned[name] and Item.IsStackable(item) then return true end
		end
	end
	return false
end

function shop.courier(ctx, secret)
	if ctx.now < ctx.shop.nextCourier then return end
	ctx.shop.nextCourier = ctx.now + cfg.courierInterval
	local courier = Couriers.GetLocal()
	if not courier or not Entity.IsAlive(courier) then return end
	local position = Entity.GetAbsOrigin(courier)
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsEntity(enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy)
			and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 1000 then
			courierCast(ctx, courier, "courier_return_stash_items")
			return
		end
	end
	if secret then
		if not NPC.IsInRangeOfShop(courier, Enum.ShopType.DOTA_SHOP_SECRET, true) then
			courierCast(ctx, courier, "courier_go_to_secretshop")
		end
		return
	end
	local hasItems, hasStash = false, false
	for slot = 0, 5 do if NPC.GetItemByIndex(courier, slot) then hasItems = true end end
	for slot = 9, 14 do if NPC.GetItemByIndex(ctx.hero, slot) then hasStash = true end end
	local stashFits = hasStash and shop.fits(ctx, ctx.hero, 9, 14)
	local carriedFits = hasItems and shop.fits(ctx, courier, 0, 5)
	if not hasItems or carriedFits then ctx.shop.fullDeliveryAt = nil end
	if hasItems and not carriedFits and ctx.shop.fullDeliveryAt and ctx.now - ctx.shop.fullDeliveryAt > 3 then
		ctx.shop.status = "Delivery paused: inventory has no free slot"
		ctx.shop.triedStash = shop.cargo(courier, 0, 5)
		courierCast(ctx, courier, "courier_return_stash_items")
		return
	end
	if hasStash and not hasItems and not stashFits then
		local signature = shop.cargo(ctx.hero, 9, 14)
		if ctx.shop.triedStash == signature then
			ctx.shop.status = "Stash waits: inventory and backpack are full"
			if not NPC.IsInRangeOfShop(courier, Enum.ShopType.DOTA_SHOP_HOME, true) then courierCast(ctx, courier, "courier_return_stash_items") end
			return
		end
	end
	local atBase = not Entity.IsAlive(ctx.hero) or NPC.IsInRangeOfShop(ctx.hero, Enum.ShopType.DOTA_SHOP_HOME, true)
	if atBase then
		ctx.shop.status = Entity.IsAlive(ctx.hero) and "Collect items from stash at base" or "Dead: keep items in stash for respawn"
		if hasItems and not NPC.IsInRangeOfShop(courier, Enum.ShopType.DOTA_SHOP_HOME, true) then courierCast(ctx, courier, "courier_return_stash_items") end
		return
	end
	if hasStash and not hasItems then
		if NPC.IsInRangeOfShop(courier, Enum.ShopType.DOTA_SHOP_HOME, true) then
			if not stashFits then ctx.shop.triedStash = shop.cargo(ctx.hero, 9, 14) end
			courierCast(ctx, courier, "courier_take_stash_items")
		else
			courierCast(ctx, courier, "courier_return_stash_items")
		end
	elseif hasItems and Entity.IsAlive(ctx.hero) and (not ctx.retreating or ctx.recoveryTask and ctx.recoveryTask.phase == "regen") then
		if not carriedFits and ctx.distance(Entity.GetAbsOrigin(courier), ctx.position) < 400 then
			ctx.shop.fullDeliveryAt = ctx.shop.fullDeliveryAt or ctx.now
		end
		courierCast(ctx, courier, "courier_transfer_items")
	end
end

function shop.duplicate(ctx, inventory, goal, name)
	if ctx.shop.quantities and ctx.shop.quantities[name] then return nil end
	local kv = itemKV["item_" .. name]
	if kv and (kv.ItemStackable == "1" or kv.ItemPermanent == "0") then return nil end
	local tree = ctx.planner.missing(ctx.shop.items, goal, {}) or {}
	local needed = 0
	for _, leaf in ipairs(tree) do if leaf == name then needed = needed + 1 end end
	local owned = inventory[name] or 0
	if owned == 0 and NPC.GetItem(ctx.hero, "item_" .. name, false) then
		owned = 1
		if owned >= math.max(1, needed) then return "game reports it in the hero's slots" end
	end
	if name:find("^recipe_") and owned >= math.max(1, needed) then return "a loose copy is already owned" end
	return nil
end

function shop.progressKey(ctx)
	local match = GameRules.GetMatchID and GameRules.GetMatchID() or 0
	local start = GameRules.GetGameStartTime and math.floor(GameRules.GetGameStartTime()) or 0
	return tostring(match) .. ":" .. tostring(start) .. ":" .. tostring(ctx.heroName) .. ":" .. tostring(ctx.role)
end

function shop.restore(ctx)
	if not Config then return 0 end
	local saved = Config.ReadString("self_play_shop", "progress", "")
	local key, names = saved:match("^([^|]*)|(.*)$")
	if key ~= shop.progressKey(ctx) then return 0 end
	ctx.shop.savedKey = key
	local count = 0
	for name in names:gmatch("[^,]+") do ctx.shop.completed[name], count = true, count + 1 end
	return count
end

function shop.saveProgress(ctx)
	if not Config then return end
	ctx.shop.savedKey = shop.progressKey(ctx)
	local names = {}
	for name in pairs(ctx.shop.completed) do names[#names + 1] = name end
	table.sort(names)
	Config.WriteString("self_play_shop", "progress", shop.progressKey(ctx) .. "|" .. table.concat(names, ","))
end

shop.extras = {
	{name = "aghanims_shard", clock = 900, owned = function(ctx, counts) return counts.aghanims_shard or NPC.HasShard(ctx.hero) end},
	{name = "ultimate_scepter_2", clock = 1200, owned = function(ctx, counts)
		return counts.ultimate_scepter_2 or NPC.HasModifier(ctx.hero, "modifier_item_ultimate_scepter_consumed") end},
	{name = "moon_shard", clock = 1800, owned = function(ctx, counts)
		return counts.moon_shard or NPC.HasModifier(ctx.hero, "modifier_item_moon_shard_consumed") end},
}

function shop.extra(ctx, counts)
	for _, entry in ipairs(shop.extras) do
		if ctx.clock >= entry.clock and not ctx.shop.completed[entry.name] and not entry.owned(ctx, counts or {})
			and (not ctx.shop.items or ctx.shop.items[entry.name]) then return entry.name end
	end
	return nil
end

local function complete(ctx, name)
	local state = ctx.shop
	local fresh = not state.completed[name]
	state.completed[name] = true
	if fresh then shop.saveProgress(ctx) end
	state.startedGoal, state.pending = nil, nil
	state.secretShopping = false
	state.index = state.index + 1
	if state.deferredPlan then
		state.plan, state.source, state.index = state.deferredPlan, state.deferredSource, 1
		state.deferredPlan, state.deferredSource = nil, nil
	end
end

function shop.pending(ctx, inventory)
	local state, pending = ctx.shop, ctx.shop.pending
	if not pending then return false end
	if ctx.planner.componentCount(state.items, inventory, pending.name) > pending.count
		or ctx.planner.owns(state.items, inventory, pending.goal) then state.pending = nil; return false end
	if pending.cost > 0 and Player.GetTotalGold(ctx.player) < pending.gold - pending.cost * 0.5 then pending.spent = true end
	local wait = pending.spent and 120 or 8
	if ctx.now - pending.time < wait then
		state.status = (pending.spent and "Await paid item delivery: " or "Confirm purchase: ") .. pending.name
		shop.courier(ctx, false)
		return true
	end
	if pending.spent then
		state.purchaseBlocked = state.purchaseBlocked or {}
		state.purchaseBlocked[pending.name] = ctx.now + 60
	end
	state.pending = nil
	return false
end

function shop.disassemble(ctx, goal, entries)
	if ctx.settings.sell == false then return false end
	for victim, trigger in pairs(ctx.shop.splits or {}) do
		if trigger == goal and not (ctx.shop.counts and ctx.shop.counts[goal]) then
			for _, entry in ipairs(entries) do
				if entry.name == victim and entry.unit == ctx.hero and entry.slot <= 8 and Item.IsSellable(entry.item) then
					Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM, nil, Vector(0, 0, 0), entry.item,
						Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_disassemble", false)
					ctx.shop.splits[victim] = nil
					ctx.shop.status = "Disassemble " .. victim .. " for " .. goal
					return true
				end
			end
		end
	end
	return false
end

function shop.run(ctx)
	shop.fetch(ctx)
	if not ctx.settings.buy or ctx.now < ctx.shop.nextBuy then return end
	local state = ctx.shop
	state.nextBuy = ctx.now + cfg.buyInterval
	if next(state.completed) and state.savedKey ~= shop.progressKey(ctx) then shop.saveProgress(ctx) end
	local counts, entries = shop.inventory(ctx)
	state.counts = counts
	if inventoryCleanup.run(ctx, entries) then state.supplyNote = "inventory cleanup busy"; return end
	shop.manageInventory(ctx)
	local inventory = shop.inventory(ctx)
	if shop.pending(ctx, inventory) then state.supplyNote = "waiting for pending purchase"; return end
	if ctx.settings.online and not state.draftPlan and ctx.now < state.buildWaitUntil then
		state.status = "Loading hero build"
		shop.courier(ctx, false)
		return
	end
	if supply(ctx, inventory) then shop.courier(ctx, state.secretShopping); return end
	local function satisfied(goal)
		if state.completed[goal] or inventoryCleanup.retired(ctx, goal) then return true end
		local quantity = state.quantities[goal]
		if quantity then return (inventory[goal] or 0) >= quantity or ctx.clock >= 120 end
		return ctx.planner.owns(ctx.shop.items, inventory, goal)
	end
	local name = state.plan[state.index]
	while name and satisfied(name) do
		complete(ctx, name)
		name = state.plan[state.index]
	end
	if not name then
		local extra = shop.extra(ctx, counts)
		if extra then
			state.index = #state.plan + 1
			state.plan[state.index] = extra
			name = extra
			if Log then Log.Write("[SelfPlay buy] build complete, adding late-game extra " .. extra) end
		end
	end
	if not name then
		state.status = "Build complete"
		shop.courier(ctx, false)
		return
	end
	if shop.disassemble(ctx, name, entries) then return end
	local missing = state.quantities[name] and {name} or ctx.planner.missing(ctx.shop.items, name, inventory)
	if not missing then
		state.status = "Unsupported recipe: " .. name
		complete(ctx, name)
		return
	end
	local nextItem = missing[1]
	if not nextItem then
		state.status = "Waiting for assembly: " .. name
		shop.courier(ctx, false)
		return
	end
	local duplicate = shop.duplicate(ctx, inventory, name, nextItem)
	if duplicate then
		state.status = "Already own " .. nextItem .. "; waiting for assembly: " .. name
		if ctx.now >= (state.nextDuplicateNote or 0) and Log then
			state.nextDuplicateNote = ctx.now + 10
			Log.Write(string.format("[SelfPlay buy] skip duplicate %s for %s (%s)", nextItem, name, duplicate))
		end
		shop.courier(ctx, false)
		return
	end
	if state.purchaseBlocked and (state.purchaseBlocked[nextItem] or 0) > ctx.now then
		state.status = "Purchase unresolved; wait before retry: " .. nextItem
		shop.courier(ctx, false)
		return
	end
	state.status = name .. " > " .. nextItem
	local kv = itemKV["item_" .. nextItem]
	if not kv then state.status = "Item unavailable in this game: " .. nextItem; complete(ctx, name); return end
	local cost, itemId = tonumber(kv.ItemCost or "0"), tonumber(kv.ID)
	local reserve = cost >= 500 and strategy.buybackReserve(ctx) or 0
	local affordable = Player.GetTotalGold(ctx.player) >= cost + reserve
	if not affordable and reserve > 0 and Player.GetTotalGold(ctx.player) >= cost then state.status = "Keep buyback gold: " .. name end
	local secret = kv.SecretShop == "1" and affordable and not NPC.IsInRangeOfShop(ctx.hero, Enum.ShopType.DOTA_SHOP_SECRET, true)
	state.secretShopping = secret
	shop.courier(ctx, secret)
	if not affordable then return end
	if outOfStock(nextItem, ctx.team) then
		state.status = "Out of stock: " .. nextItem
		if not state.stockWait then state.stockWait = ctx.now end
		if ctx.now - state.stockWait > 30 then complete(ctx, name); state.stockWait = nil end
		return
	end
	state.stockWait = nil
	local buyer = ctx.hero
	if secret then
		buyer = Couriers.GetLocal()
		if not buyer or not Entity.IsAlive(buyer) then state.status = "Waiting for courier: " .. nextItem; return end
		if not NPC.IsInRangeOfShop(buyer, Enum.ShopType.DOTA_SHOP_SECRET, true) then
			state.status = "Courier to secret shop: " .. nextItem
			return
		end
	end
	local free = false
	local firstSlot, lastSlot = 0, buyer == ctx.hero and 14 or 5
	if buyer == ctx.hero and not NPC.IsInRangeOfShop(ctx.hero, Enum.ShopType.DOTA_SHOP_HOME, true) then firstSlot = 9 end
	for slot = firstSlot, lastSlot do if not NPC.GetItemByIndex(buyer, slot) then free = true; break end end
	if not free then state.status = "Inventory full; waiting for space"; return end

	local goldBefore = Player.GetTotalGold(ctx.player)
	if Log then
		local owned = {}
		for key, count in pairs(inventory) do owned[#owned + 1] = count > 1 and key .. "x" .. count or key end
		table.sort(owned)
		Log.Write(string.format("[SelfPlay buy] %s for %s; own: %s", nextItem, name, table.concat(owned, ",")))
	end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, itemId, Vector(0, 0, 0), itemId,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, buyer, false, false, false, true, "self_play_purchase", false)
	state.startedGoal = name
	state.pending = {name = nextItem, goal = name, count = ctx.planner.componentCount(state.items, inventory, nextItem), time = ctx.now,
		gold = goldBefore, cost = cost}
end

return shop
