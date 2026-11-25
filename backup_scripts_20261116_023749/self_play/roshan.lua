local roshan = {}
local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function value(kv, key, fallback)
	local result = kv and kv.AbilityValues and kv.AbilityValues[key]
	if type(result) == "table" then result = result.value end
	if type(result) == "number" then return result end
	return type(result) == "string" and tonumber(result:match("%-?%d+%.?%d*")) or fallback
end

local function clear(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 2200 then return false end
	end
	for _, sighting in pairs(ctx.memory) do
		if ctx.now - sighting.time < 6 and ctx.distance(position, sighting.position) < 2400 then return false end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		if ctx.distance(position, arrival.position) < 2600 then return false end
	end
	return true
end

function roshan.hurt(ctx, data)
	local state = ctx.roshanState
	if not state or data.damage <= 0 then return end
	local outgoing = data.source == ctx.hero and data.target == state.target
	local incoming = data.source == state.target and data.target == ctx.hero
	if not outgoing and not incoming then return end
	state.samples = state.samples or {}
	state.samples[#state.samples + 1] = {time = GameRules.GetGameTime(), outgoing = outgoing and data.damage or 0, incoming = incoming and data.damage or 0}
end

function roshan.attack(ctx, target, reason)
	if not live(target) or not NPC.IsRoshan(target) or NPC.IsRunning(target) or NPC.IsChannellingAbility(target) then return false end
	local position = Entity.GetAbsOrigin(target)
	if ctx.distance(ctx.position, position) > 220 then
		local goal = ctx.toward(position, ctx.position, 140)
		return ctx.move(goal, "Enter Roshan pit before attacking", 35)
	end
	return ctx.attack(target, reason)
end

function roshan.assess(ctx, target)
	local result = {safe = false, reason = "Roshan unavailable", timeToKill = 0, remainingHealth = 0}
	if not live(target) or not NPC.IsRoshan(target) or NPC.IsWaitingToSpawn(target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then return result end
	result.reason = "Recover before Roshan"
	if ctx.retreating or ctx.health < 0.55 or not Entity.IsAlive(ctx.hero)
		or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return result end
	local position = Entity.GetAbsOrigin(target)
	result.reason = "Roshan is moving or contested"
	if NPC.IsRunning(target) or NPC.IsChannellingAbility(target) or not clear(ctx, position) or not clear(ctx, ctx.position) then return result end
	for _, fight in pairs(ctx.allyFights or {}) do
		if ctx.now - fight.time < 3 then result.reason = "Allied fight takes priority"; return result end
	end
	local distance = ctx.distance(ctx.position, position)
	result.reason = "Roshan too far away"
	if distance > 3800 then return result end
	local goal = ctx.toward(position, ctx.position, 140)
	local exit, exitScore, exitDistance
	result.reason = "No safe Roshan approach or exit"
	for step = 0, 7 do
		local angle = step * math.pi / 4
		local x, y = position.x + math.cos(angle) * 1050, position.y + math.sin(angle) * 1050
		local point = Vector(x, y, World.GetGroundZ(x, y))
		local score = ctx.distance(point, ctx.home)
		if GridNav.IsTraversable(point) and clear(ctx, point) and (not exitScore or score < exitScore) then
			local escapePath = GridNav.BuildPath(goal, point, false)
			local length, previous, safePath = 0, goal, true
			for _, waypoint in ipairs(escapePath) do
				length, previous = length + ctx.distance(previous, waypoint), waypoint
				if not clear(ctx, waypoint) then safePath = false end
			end
			if safePath and length < 1800 and #escapePath > 0 and ctx.distance(escapePath[#escapePath], point) < 150 then
				exit, exitScore, exitDistance = point, score, length
			end
		end
	end
	if not exit then return result end
	local path = ctx.distance(ctx.position, goal) < 100 and {ctx.position} or GridNav.BuildPath(ctx.position, goal, false)
	if #path == 0 or ctx.distance(path[#path], goal) > 150 then return result end
	local travelDistance, previous = 0, ctx.position
	for _, point in ipairs(path) do
		if not clear(ctx, point) then return result end
		travelDistance, previous = travelDistance + ctx.distance(previous, point), point
	end
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local travel = travelDistance / speed
	local period = math.max(0.25, NPC.GetSecondsPerAttack(target, false))
	local chance = value(abilityKV.roshan_bash, "bash_chance", 15) / 100
	local downtime = math.max(0.55, 1 - chance * value(abilityKV.roshan_bash, "stun_duration", 1.65) / period)
	local damage = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
	local dps = damage / math.max(0.2, NPC.GetSecondsPerAttack(ctx.hero, true)) * downtime * 0.85
	local hit = NPC.GetTrueMaximumDamage(target) * NPC.GetArmorDamageMultiplier(ctx.hero)
	local magic = NPC.GetMagicalArmorDamageMultiplier(ctx.hero)
	local minutes = math.floor(math.max(0, ctx.clock) / 60)
	local slam = (value(abilityKV.roshan_slam, "damage", 70) + minutes * value(abilityKV.roshan_slam, "damage_growth", 10)) * magic
	local incoming = hit / period * 1.25 + chance * value(abilityKV.roshan_bash, "bonus_damage", 50) * magic / period + slam / 10
	local state = ctx.roshanState
	if state and state.target == target then
		local outgoing, taken = 0, 0
		for i = #(state.samples or {}), 1, -1 do
			local sample = state.samples[i]
			if ctx.now - sample.time > 4 then table.remove(state.samples, i)
			else outgoing, taken = outgoing + sample.outgoing, taken + sample.incoming end
		end
		local window = math.min(4, ctx.now - (state.contact or ctx.now))
		if window >= 2.5 then
			dps = math.max(dps, math.min(dps * 2, outgoing / window * 0.8))
			incoming = math.max(incoming, taken / window * 1.15)
		end
	end
	local lifesteal = 0
	for slot = 0, 5 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		if item and Item.IsItemEnabled(item) then lifesteal = math.max(lifesteal, value(itemKV[Ability.GetName(item)], "lifesteal_percent", 0) / 100) end
	end
	local sustain = NPC.GetHealthRegen(ctx.hero) + dps * math.min(0.35, lifesteal) * 0.5
	local regen = math.max(0, NPC.GetHealthRegen(target))
	result.reason, result.damageDps, result.incomingDps = "Cannot overcome Roshan regeneration", dps, incoming
	if dps <= regen + 5 then return result end
	local kill = (Entity.GetHealth(target) + regen * travel) / (dps - regen) + 0.8
	local health, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local burst = slam + hit * 2 + 80 * magic
	local loss = math.max(0, incoming - sustain) * kill + burst
	local escapeReserve = incoming * (exitDistance / speed + 1)
	result.timeToKill, result.remainingHealth = kill, health - loss
	result.goal, result.exit, result.travel = goal, exit, travel
	result.reason = "Roshan would take too long"
	local known = 0
	for _, enemy in ipairs(ctx.enemies) do if live(enemy) and not NPC.IsIllusion(enemy) then known = known + 1 end end
	if kill > (known >= 3 and 40 or 20) or travel + kill > (known >= 3 and 48 or 28) then return result end
	result.reason = "Insufficient health to finish and escape"
	if health - loss < math.max(maximum * 0.3, escapeReserve) then return result end
	result.safe, result.reason = true, Entity.GetHealth(target) <= Entity.GetMaxHealth(target) * 0.3 and "Finish weakened Roshan" or "Solo Roshan within survival budget"
	return result
end

roshan.shareFloor = 0.22

function roshan.tanks(ctx, target)
	local position = Entity.GetAbsOrigin(target)
	local count, nearest = 0, math.huge
	for _, hero in ipairs(ctx.allies) do
		if hero ~= ctx.hero and live(hero) and not NPC.IsIllusion(hero)
			and Entity.GetHealth(hero) > Entity.GetMaxHealth(hero) * 0.35 then
			local distance = ctx.distance(Entity.GetAbsOrigin(hero), position)
			if distance < 900 then count, nearest = count + 1, math.min(nearest, distance) end
		end
	end
	return count, nearest
end

function roshan.targeting(ctx, target)
	return NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 30, 450) == ctx.hero
end

function roshan.shareable(ctx, target)
	if not live(target) or not NPC.IsRoshan(target) or ctx.hardRetreat then return false end
	if Entity.GetHealth(ctx.hero) < Entity.GetMaxHealth(ctx.hero) * roshan.shareFloor then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), Entity.GetAbsOrigin(target)) < 1600 then return false end
	end
	return roshan.tanks(ctx, target) > 0
end

function roshan.slam(ctx)
	local minutes = math.floor(math.max(0, ctx.clock) / 60)
	return (value(abilityKV.roshan_slam, "damage", 70) + minutes * value(abilityKV.roshan_slam, "damage_growth", 10))
		* NPC.GetMagicalArmorDamageMultiplier(ctx.hero)
end

function roshan.support(ctx, target)
	local position = Entity.GetAbsOrigin(target)
	ctx.roshanShare = ctx.now
	local dx, dy = ctx.position.x - position.x, ctx.position.y - position.y
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 50 then dx, dy = ctx.home.x - position.x, ctx.home.y - position.y; length = math.max(1, math.sqrt(dx * dx + dy * dy)) end
	local ox, oy = position.x + dx / length * 520, position.y + dy / length * 520
	local outside = Vector(ox, oy, World.GetGroundZ(ox, oy))
	if not GridNav.IsTraversable(outside) then outside = ctx.toward(position, ctx.home, 520) end
	if roshan.targeting(ctx, target) then
		return ctx.move(outside, "Roshan: step out of the pit so an ally tanks", 40)
	end
	if Entity.GetHealth(ctx.hero) < roshan.slam(ctx) * 1.4 + 100 then
		return ctx.move(outside, "Roshan: wait outside Slam range while allies tank", 40)
	end
	return roshan.attack(ctx, target, "Roshan: hit while an ally tanks")
end

function roshan.cancel(ctx)
	local state = ctx.roshanState
	if not state then return end
	ctx.roshanState, ctx.nextSoloRoshan = nil, ctx.now + 20
	if live(state.target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(state.target)) < 1100 then
		ctx.roshanExit = {goal = state.exit, expires = ctx.now + 5}
		ctx.stop()
		ctx.hits.ordered, ctx.busyUntil = nil, ctx.now
	end
end

function roshan.plan(ctx, target)
	if ctx.now < (ctx.nextSoloRoshan or 0) then return nil end
	local result = roshan.assess(ctx, target)
	ctx.roshanAssessment = result
	if not result.safe then
		if ctx.roshanState and ctx.roshanState.target == target then roshan.cancel(ctx) end
		return nil
	end
	local state = ctx.roshanState
	if not state or state.target ~= target then
		state = {target = target, started = ctx.now, progress = ctx.now, health = Entity.GetHealth(target), distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target))}
		ctx.roshanState = state
	end
	local distance, health = ctx.distance(ctx.position, Entity.GetAbsOrigin(target)), Entity.GetHealth(target)
	if distance < 600 then state.contact = state.contact or ctx.now end
	if distance < state.distance - 60 or distance < 600 and health < state.health - 1 then
		state.progress, state.distance, state.health = ctx.now, distance, health
	end
	state.exit = result.exit
	if ctx.now - state.progress > 4 or ctx.now - state.started > 55 then
		result.safe, result.reason = false, "Roshan attempt made no reliable progress"
		roshan.cancel(ctx)
		return nil
	end
	return {kind = "roshan", solo = true, target = target, goal = result.goal, expires = ctx.now + 0.8}
end

function roshan.escape(ctx)
	local task = ctx.roshanExit
	if not task then return false end
	if ctx.now > task.expires or ctx.distance(ctx.position, task.goal) < 120 then ctx.roshanExit = nil; return false end
	return ctx.move(task.goal, "Leave unsafe Roshan attempt", 100)
end

function roshan.run(ctx, task)
	if not live(task.target) then
		if Entity.IsEntity(task.target) and not Entity.IsAlive(task.target) then ctx.roshanLoot = {position = Entity.GetAbsOrigin(task.target), expires = ctx.now + 12} end
		ctx.roshanState, ctx.teamTask = nil, nil
		return false
	end
	local result = ctx.roshanAssessment
	if not result then ctx.teamTask = nil; return false end
	if not result.safe then roshan.cancel(ctx); ctx.teamTask = nil; return roshan.escape(ctx) end
	return roshan.attack(ctx, task.target, result.reason)
end

roshan.dropNames = {item_aegis = "core", item_cheese = "core", item_refresher_shard = "core", item_ultimate_scepter_roshan = "core",
	item_aghanims_shard_roshan = "core", item_pocket_roshan = "core", item_roshans_banner = "support"}
roshan.dropLabels = {item_aegis = "Aegis", item_cheese = "Cheese", item_refresher_shard = "Refresher Shard",
	item_ultimate_scepter_roshan = "Aghanim's Blessing", item_aghanims_shard_roshan = "Aghanim's Shard", item_pocket_roshan = "Pocket Roshan",
	item_roshans_banner = "Roshan's Banner"}
roshan.grace = 4

local function worth(hero)
	local total = 0
	for slot = 0, 16 do
		local item = NPC.GetItemByIndex(hero, slot)
		if item then total = total + (Item.GetCost(item) or 0) end
	end
	return total
end

local function eligible(ctx, hero, name)
	if not live(hero) or not Entity.IsSameTeam(ctx.hero, hero) or not NPC.IsHero(hero) or NPC.IsIllusion(hero)
		or NPC.HasModifier(hero, "modifier_arc_warden_tempest_double") then return false end
	if name == "item_aegis" and NPC.GetItem(hero, "item_aegis", true) then return false end
	return true
end

local function claimants(ctx, name, position)
	local list, seen = {}, {}
	local function add(hero, limit)
		if hero and not seen[hero] and eligible(ctx, hero, name) and ctx.distance(Entity.GetAbsOrigin(hero), position) < limit then
			seen[hero] = true
			list[#list + 1] = hero
		end
	end
	add(ctx.hero, name == "item_aegis" and 4500 or 2600)
	for _, ally in ipairs(ctx.allies or {}) do add(ally, 1600) end
	return list
end

function roshan.owner(ctx, name, position)
	local best, bestScore
	for _, hero in ipairs(claimants(ctx, name, position)) do
		local value = worth(hero)
		local score = roshan.dropNames[name] == "support" and -value or value
		if not bestScore or score > bestScore then best, bestScore = hero, score end
	end
	return best
end

function roshan.nearest(ctx, name, position)
	local best, distance
	for _, hero in ipairs(claimants(ctx, name, position)) do
		local gap = ctx.distance(Entity.GetAbsOrigin(hero), position)
		if not distance or gap < distance then best, distance = hero, gap end
	end
	return best
end

function roshan.lootSafe(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, enemy in ipairs(ctx.enemies or {}) do
		if live(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), position) < 1200 then return false end
	end
	return true
end

function roshan.lootPlan(ctx)
	local cached = ctx.lootTask
	if cached and (not Entity.IsEntity(cached.physical) or cached.name == "item_aegis" and NPC.GetItem(ctx.hero, "item_aegis", true)) then
		ctx.lootTask, ctx.nextLootPlan = nil, 0
	end
	if ctx.now < (ctx.nextLootPlan or 0) then return ctx.lootTask end
	ctx.nextLootPlan = ctx.now + 0.3
	ctx.lootSeen = ctx.lootSeen or {}
	local best
	for _, physical in ipairs(PhysicalItems.GetAll()) do
		if Entity.IsEntity(physical) and not Entity.IsDormant(physical) then
			local item = PhysicalItem.GetItem(physical)
			local name = item and Ability.GetName(item)
			if name and roshan.dropNames[name] then
				local position = Entity.GetAbsOrigin(physical)
				local key = Entity.GetIndex(physical)
				ctx.lootSeen[key] = ctx.lootSeen[key] or ctx.now
				local owner = roshan.owner(ctx, name, position)
				local waited = ctx.now - ctx.lootSeen[key]
				local mine = owner == ctx.hero or waited >= roshan.grace and roshan.nearest(ctx, name, position) == ctx.hero
				if mine and roshan.lootSafe(ctx, position) then
					local distance = ctx.distance(ctx.position, position)
					local priority = name == "item_aegis" and 3 or 1
					if not best or priority > best.priority or priority == best.priority and distance < best.distance then
						best = {physical = physical, name = name, position = position, distance = distance, priority = priority,
							owner = owner, designated = owner == ctx.hero, waited = waited}
					end
				end
			end
		end
	end
	if best and (not ctx.lootTask or ctx.lootTask.physical ~= best.physical) then
		ctx.lootNote = string.format("claim %s (%s, %.0f away, waited %.1fs)", roshan.dropLabels[best.name] or best.name,
			best.designated and "designated" or "unclaimed", best.distance, best.waited)
	end
	ctx.lootTask = best
	return best
end

local function makeRoom(ctx)
	for slot = 0, 5 do if not NPC.GetItemByIndex(ctx.hero, slot) then return false end end
	local backpack
	for slot = 6, 8 do if not NPC.GetItemByIndex(ctx.hero, slot) then backpack = slot; break end end
	if not backpack or ctx.now < (ctx.nextLootSwap or 0) then return false end
	local cheapest, cost
	for slot = 0, 5 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		local price = item and (Item.GetCost(item) or 0)
		if item and Ability.GetName(item) ~= "item_aegis" and (not cost or price < cost) then cheapest, cost = item, price end
	end
	if not cheapest then return false end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, backpack, Vector(0, 0, 0), cheapest,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true)
	ctx.nextLootSwap, ctx.mode = ctx.now + 0.5, "Make room for Roshan drop"
	return true
end

function roshan.loot(ctx)
	if ctx.hardRetreat then return false end
	local task = roshan.lootPlan(ctx)
	if not task or not Entity.IsEntity(task.physical) then ctx.lootTask, ctx.roshanLoot = nil, nil; return false end
	if makeRoom(ctx) then return true end
	ctx.mode = "Collect Roshan " .. (roshan.dropLabels[task.name] or task.name)
	if ctx.lootOrder and ctx.lootOrder.physical == task.physical and ctx.now < ctx.lootOrder.until_ then return true end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM, task.physical, task.position, nil,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_aegis", false)
	ctx.lootOrder = {physical = task.physical, until_ = ctx.now + 1}
	ctx.lastOrder = "pickup"
	return true
end

return roshan
