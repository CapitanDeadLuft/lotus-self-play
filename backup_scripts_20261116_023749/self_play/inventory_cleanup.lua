local cleanup = {}

local obsolete = {branches = 900, faerie_fire = 900, circlet = 1200, slippers = 1200, gauntlets = 1200, mantle = 1200,
	bracer = 1800, wraith_band = 1800, null_talisman = 1800, magic_stick = 1500,
	tango = 900, tango_single = 900, magic_wand = 1800}

local function needed(ctx, name)
	for index = ctx.shop.index, #ctx.shop.plan do
		local goal = ctx.shop.plan[index]
		if not ctx.shop.completed[goal] and ctx.planner.contains(ctx.shop.items, goal, name) then return true end
	end
	return false
end

local function slotsFull(ctx)
	for slot = 0, 8 do if not NPC.GetItemByIndex(ctx.hero, slot) then return false end end
	return true
end

local function cheapest(ctx, entry)
	local price = Item.GetCost(entry.item)
	for slot = 0, 8 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		if item and item ~= entry.item and Item.IsSellable(item) and Item.GetCost(item) < price then return false end
	end
	return true
end

local function counterTrigger(ctx, trigger)
	for _, name in ipairs(ctx.shop.counterItems or {}) do
		if name:gsub("^item_", "") == trigger then return true end
	end
	return false
end

local function replaced(ctx, entry)
	if ctx.settings.sell == false then return false end
	local trigger = ctx.shop.sells and ctx.shop.sells[entry.name]
	if trigger == nil or ctx.shop.counts == nil or not ctx.planner.owns(ctx.shop.items, ctx.shop.counts, trigger) then return false end
	if obsolete[entry.name] then return true end
	local record = ctx.shop.items and ctx.shop.items[trigger]
	local triggerCost = record and record.cost or 0
	return slotsFull(ctx) and cheapest(ctx, entry) and Item.GetCost(entry.item) < triggerCost and not counterTrigger(ctx, trigger)
end

function cleanup.retired(ctx, name)
	if obsolete[name] and ctx.clock >= obsolete[name] then return true end
	local trigger = ctx.settings.sell ~= false and ctx.shop.sells and ctx.shop.sells[name]
	return trigger ~= nil and ctx.shop.counts ~= nil and ctx.planner.owns(ctx.shop.items, ctx.shop.counts, trigger)
end

local function junk(ctx, entry)
	return (obsolete[entry.name] and ctx.clock >= obsolete[entry.name] or replaced(ctx, entry)) and Item.IsSellable(entry.item)
		and Item.GetPlayerOwnerID(entry.item) == ctx.playerId and not needed(ctx, entry.name)
end

local function courierHome(ctx, courier)
	local ability = NPC.GetAbility(courier, "courier_return_stash_items")
	if ability and Ability.IsReady(ability) then
		Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, Vector(0, 0, 0), ability,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, courier, false, false, false, true, "self_play_courier_cleanup", false)
	end
end

local function order(ctx, kind, unit, item, target)
	Player.PrepareUnitOrders(ctx.player, kind, target, Vector(0, 0, 0), item,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit, false, false, false, true, "self_play_inventory_cleanup", false)
	if unit == ctx.hero then ctx.busyUntil = ctx.now + 0.25 end
end

function cleanup.run(ctx, entries)
	local state, courier = ctx.shop, Couriers.GetLocal()
	local task = state.cleanup
	if ctx.now < (state.nextCleanup or 0) then return task ~= nil end
	state.nextCleanup = ctx.now + 1
	local held, candidate, courierJunk, occupied, cargo = nil, nil, nil, 0, 0
	for _, entry in ipairs(entries) do
		if task and entry.item == task.item then held = entry end
		if entry.unit == ctx.hero and entry.slot <= 8 then
			occupied = occupied + 1
			if junk(ctx, entry) and (not candidate or Item.GetCost(entry.item) < Item.GetCost(candidate.item)) then candidate = entry end
		elseif entry.unit == courier then
			cargo = cargo + 1
			if junk(ctx, entry) then courierJunk = entry end
		end
	end
	if task and not held then
		state.status, state.cleanup = "Inventory space recovered: " .. task.name, nil
		return false
	end
	if candidate and (candidate.name == "magic_wand" or candidate.name == "tango" or candidate.name == "tango_single")
		and occupied < 8 then candidate = nil end
	if not task then
		local entry = courierJunk or candidate
		local home = Entity.IsAlive(ctx.hero) and NPC.IsInRangeOfShop(ctx.hero, Enum.ShopType.DOTA_SHOP_HOME, true)
		if not entry or entry.unit == ctx.hero and not home and occupied < 8 then return false end
		if entry.unit == ctx.hero and (not Entity.IsAlive(ctx.hero) or ctx.retreating or ctx.nearEnemies > 0
			or ctx.intent and ctx.intent.kind == "hero") then return false end
		task = {item = entry.item, name = entry.name, expires = ctx.now + 90}
		state.cleanup, held = task, entry
	end
	if ctx.now > task.expires or not junk(ctx, held) then
		state.cleanup, state.nextCleanup = nil, ctx.now + 10
		return false
	end
	local holder = held.unit
	if held.unit == ctx.hero and held.slot >= 9 and held.slot <= 14
		or NPC.IsInRangeOfShop(holder, Enum.ShopType.DOTA_SHOP_HOME, true) then
		if holder ~= ctx.hero or ctx.now >= ctx.busyUntil and not NPC.IsChannellingAbility(ctx.hero) then
			order(ctx, Enum.UnitOrder.DOTA_UNIT_ORDER_SELL_ITEM, holder, held.item)
			state.status = "Sell obsolete " .. held.name
		end
		return true
	end
	if not courier or not Entity.IsAlive(courier) then
		state.cleanup, state.nextCleanup = nil, ctx.now + 10
		return false
	end
	local position = Entity.GetAbsOrigin(courier)
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsEntity(enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy)
			and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 1000 then
			courierHome(ctx, courier)
			state.status = "Courier retreat during inventory cleanup"
			return true
		end
	end
	if holder == courier then
		if not task.delivered and occupied < 9 and ctx.distance(position, ctx.position) < 200 and not ctx.retreating then
			for _, entry in ipairs(entries) do
				if entry.unit == courier and entry.item ~= held.item and not junk(ctx, entry) then
					order(ctx, Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM, courier, entry.item, ctx.hero)
					task.delivered = true
					state.status = "Deliver upgrade through recovered slot"
					return true
				end
			end
		end
		courierHome(ctx, courier)
		state.status = "Courier returning obsolete " .. held.name
		return true
	end
	if holder ~= ctx.hero or not Entity.IsAlive(ctx.hero) then state.cleanup = nil; return false end
	if ctx.retreating or ctx.nearEnemies > 0 then
		courierHome(ctx, courier)
		state.cleanup, state.nextCleanup = nil, ctx.now + 5
		return false
	end
	if cargo >= 6 then
		courierHome(ctx, courier)
		state.status = "Unload courier before collecting obsolete items"
		return true
	end
	if ctx.distance(position, ctx.position) > 180 then
		NPC.MoveTo(courier, ctx.position, false, false, false, true)
		state.status = "Courier collect obsolete " .. held.name
		return true
	end
	if ctx.now < ctx.busyUntil or NPC.IsChannellingAbility(ctx.hero) then return true end
	Player.HoldPosition(ctx.player, courier, false, false, true)
	order(ctx, Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM, ctx.hero, held.item, courier)
	state.status = "Give obsolete " .. held.name .. " to courier"
	return true
end

return cleanup
