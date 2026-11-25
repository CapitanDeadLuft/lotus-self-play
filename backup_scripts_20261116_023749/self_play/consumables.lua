local consumables = {}

local combat = require("self_play.combat")
local planner = require("self_play.planner")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function healing(ability)
	local values = itemKV[Ability.GetName(ability)].AbilityValues
	return tonumber(values.health_regen) * tonumber(values.buff_duration), tonumber(values.buff_duration)
end

local function item(ctx, name)
	local ability = NPC.GetItem(ctx.hero, name, true)
	if ability and combat.ready(ctx, ability, true) and (ctx.abilityAttempts[name] or 0) <= ctx.now then return ability end
	return nil
end

local function use(ctx, ability, kind, target, reason, position)
	combat.cast(ctx, ability, kind, target, position)
	ctx.mode = reason
	return true
end

function consumables.shareTango(ctx, quiet, enemyDistance)
	if ctx.role < 4 or not quiet or enemyDistance < 900 or ctx.retreating or ctx.intent or ctx.health < 0.45
		or ctx.laneThreat and ctx.laneThreat.attacked or ctx.now < (ctx.nextTangoShare or 0)
		or ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.6 then return false end
	local tango = item(ctx, "item_tango")
	if not tango or Item.GetCurrentCharges(tango) <= 0 or Item.GetCurrentCharges(tango) == 1 and ctx.health < 0.7 then return false end
	if not ctx.runeRoles or ctx.now >= (ctx.nextRuneRoles or 0) then
		local entries = {}
		for _, ally in ipairs(ctx.allies) do
			if Entity.IsEntity(ally) and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally) then
				entries[#entries + 1] = {id = Entity.GetIndex(ally), scores = planner.roleScores(ctx.catalog.heroes[NPC.GetUnitName(ally)])}
			end
		end
		ctx.runeRoles, ctx.nextRuneRoles = planner.assignRoles(entries), ctx.now + 5
	end
	ctx.tangoShares = ctx.tangoShares or {}
	local best, bestScore
	for _, ally in ipairs(ctx.allies) do
		local id = Entity.GetIndex(ally)
		local role = ctx.runeRoles[id]
		if ally ~= ctx.hero and role and role <= 3 and Entity.IsAlive(ally) and not Entity.IsDormant(ally) and NPC.IsVisible(ally)
			and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally) and Entity.IsSameTeam(ctx.hero, ally)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= Ability.GetCastRange(tango)
			and Entity.GetHealth(ally) < Entity.GetMaxHealth(ally) * 0.7 and Entity.GetMaxHealth(ally) - Entity.GetHealth(ally) >= 100
			and not NPC.HasModifier(ally, "modifier_tango_heal") and not NPC.HasModifier(ally, "modifier_flask_healing")
			and not NPC.HasModifier(ally, "modifier_fountain_aura_buff") and ctx.now >= (ctx.tangoShares[id] or 0) then
			local hasTango, free = false, false
			for slot = 0, 8 do
				local carried = NPC.GetItemByIndex(ally, slot)
				if not carried and slot <= 5 then free = true end
				local name = carried and Ability.GetName(carried)
				if (name == "item_tango" or name == "item_tango_single") and Item.GetCurrentCharges(carried) > 0 then hasTango = true end
			end
			if free and not hasTango then
				local score = 1 - Entity.GetHealth(ally) / Entity.GetMaxHealth(ally)
				if not bestScore or score > bestScore then best, bestScore = ally, score end
			end
		end
	end
	if not best then return false end
	ctx.tangoShares[Entity.GetIndex(best)], ctx.nextTangoShare = ctx.now + 40, ctx.now + 3
	return use(ctx, tango, "target", best, "Share tango with injured core")
end

function consumables.resting(ctx)
	return ctx.recoveryTask ~= nil and ctx.recoveryTask.phase == "regen" and not ctx.hardRetreat
end

local function eatTree(ctx, tango, tree)
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE, tree, Entity.GetAbsOrigin(tree), tango,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true)
	ctx.busyUntil, ctx.abilityAttempts[Ability.GetName(tango)], ctx.lastOrder = ctx.now + 0.25, ctx.now + 1, "cast"
	ctx.mode = "Use tango on tree"
	return true
end

function consumables.branchTango(ctx, tango, quiet, enemyDistance)
	local resting = consumables.resting(ctx)
	if not tango or Item.GetCurrentCharges(tango) <= 0 or not quiet or enemyDistance < 900 or ctx.retreating and not resting or ctx.intent
		or ctx.laneThreat and ctx.laneThreat.attacked or (ctx.creepPressure or 0) > 0 or NPC.HasModifier(ctx.hero, "modifier_tango_heal")
		or ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.7 then ctx.branchTango = nil; return false end
	local task = ctx.branchTango
	if task then
		if ctx.now > task.expires then ctx.branchTango = nil; return false end
		for _, tree in ipairs(Entity.GetTempTreesInRadius(ctx.hero, 450)) do
			if Tree.IsActive(tree) and not task.trees[Entity.GetIndex(tree)] and ctx.distance(Entity.GetAbsOrigin(tree), task.position) < 65
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(tree)) <= Ability.GetCastRange(tango)
				and not ctx.unsafePosition(Entity.GetAbsOrigin(tree)) then
				ctx.branchTango = nil
				return eatTree(ctx, tango, tree)
			end
		end
		ctx.mode = "Wait for planted tango tree"
		return true
	end
	if ctx.now < (ctx.nextBranchTango or 0) then return false end
	local branch = item(ctx, "item_branches")
	if not branch then return false end
	local amount, duration = healing(tango)
	local missing = Entity.GetMaxHealth(ctx.hero) - Entity.GetHealth(ctx.hero) - math.max(0, NPC.GetHealthRegen(ctx.hero)) * duration * 2
	if missing < amount * (resting and 1 or 1.7) or ctx.health < 0.35 and not resting then return false end
	if ctx.shop and not resting then
		for index = ctx.shop.index, #ctx.shop.plan do
			local goal = ctx.shop.plan[index]
			if goal ~= "branches" and not ctx.shop.completed[goal] and ctx.planner.contains(ctx.shop.items, goal, "branches") then return false end
		end
	end
	local position = ctx.toward(ctx.position, ctx.home, math.min(110, Ability.GetCastRange(tango) - 25, Ability.GetCastRange(branch)))
	if ctx.distance(ctx.position, position) < 60 or not GridNav.IsTraversable(position) or ctx.unsafePosition(position) then return false end
	local trees = {}
	for _, tree in ipairs(Entity.GetTempTreesInRadius(ctx.hero, 450)) do trees[Entity.GetIndex(tree)] = true end
	for _, tree in ipairs(Entity.GetTreesInRadius(ctx.hero, resting and 900 or 450, true)) do
		local point = Entity.GetAbsOrigin(tree)
		if (resting or Item.GetCurrentCharges(tango) > 1) and not ctx.unsafePosition(point) then return false end
		trees[Entity.GetIndex(tree)] = true
	end
	ctx.branchTango, ctx.nextBranchTango = {position = position, trees = trees, expires = ctx.now + 1.5}, ctx.now + 30
	return use(ctx, branch, "point", nil, "Plant spare branch for tango regeneration", position)
end

function consumables.bottle(ctx, ability, quiet, enemyDistance)
	if not ability or NPC.HasModifier(ctx.hero, "modifier_bottle_regeneration") then return false end
	local rune = Bottle.GetRuneType(ability)
	local stored = rune >= 0 and rune < Enum.RuneType.DOTA_RUNE_COUNT
	local healthMissing = Entity.GetMaxHealth(ctx.hero) - Entity.GetHealth(ctx.hero)
	local manaMissing = NPC.GetMaxMana(ctx.hero) - NPC.GetMana(ctx.hero)
	local refill = ctx.runeTask and ctx.distance(ctx.position, ctx.runeTask.position) < 900
	if stored then
		local fighting = ctx.intent and ctx.intent.kind == "hero"
		local restore = rune == Enum.RuneType.DOTA_RUNE_REGENERATION or rune == Enum.RuneType.DOTA_RUNE_WATER
		local escape = ctx.retreating and (rune == Enum.RuneType.DOTA_RUNE_HASTE or rune == Enum.RuneType.DOTA_RUNE_INVISIBILITY)
		if escape or not restore and fighting or quiet and (refill or restore and (healthMissing > 180 or manaMissing > 140)) then
			return use(ctx, ability, "none", nil, "Activate stored bottle rune")
		end
		return false
	end
	if Item.GetCurrentCharges(ability) <= 0 or not quiet or enemyDistance < 650
		or ctx.laneThreat and ctx.laneThreat.attacked or (ctx.creepPressure or 0) > 0 then return false end
	for _, projectile in pairs(ctx.projectiles or {}) do
		if projectile.target == ctx.hero and projectile.impact > ctx.now then return false end
	end
	local farm = ctx.farmCandidate
	if farm and farm.start <= ctx.now + 0.4 then return false end
	if healthMissing >= 110 or manaMissing >= 65 or refill and (healthMissing >= 50 or manaMissing >= 30) then
		return use(ctx, ability, "none", nil, refill and "Bottle before rune refill" or "Drink bottle")
	end
	return false
end

local function value(name, key, fallback)
	local record = itemKV[name]
	local raw = record and record.AbilityValues and record.AbilityValues[key]
	if type(raw) == "table" then raw = raw.value end
	return tonumber(raw) or fallback
end

local function friends(ctx, radius)
	local list = {}
	for _, ally in ipairs(ctx.allies) do
		if Entity.IsEntity(ally) and Entity.IsAlive(ally) and not Entity.IsDormant(ally) and not NPC.IsIllusion(ally)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= radius then list[#list + 1] = ally end
	end
	return list
end

local function underFire(ctx, ally)
	return Hero.GetRecentDamage(ally) > 0 or ally == ctx.hero and ctx.laneThreat and ctx.laneThreat.attacked
end

function consumables.team(ctx)
	local boots = item(ctx, "item_arcane_boots")
	if boots then
		local restore = value("item_arcane_boots", "replenish_amount", 175)
		local radius = value("item_arcane_boots", "replenish_radius", 1200)
		local gained, own = 0, NPC.GetMaxMana(ctx.hero) - NPC.GetMana(ctx.hero)
		for _, ally in ipairs(friends(ctx, radius)) do
			if ally == ctx.hero or NPC.GetMaxMana(ally) > 0 then gained = gained + math.min(restore, NPC.GetMaxMana(ally) - NPC.GetMana(ally)) end
		end
		local combatNeed = ctx.target and own >= restore * 0.5
		if own >= restore * 0.85 or gained >= restore * 1.6 or combatNeed then return use(ctx, boots, "none", nil, "Arcane Boots: restore team mana") end
	end
	for _, name in ipairs({"item_guardian_greaves", "item_mekansm"}) do
		local ability = item(ctx, name)
		if ability then
			local heal = value(name, "heal_amount", 275)
			local radius = value(name, "heal_radius", 1200)
			local total, critical = 0, false
			for _, ally in ipairs(friends(ctx, radius)) do
				local missing = Entity.GetMaxHealth(ally) - Entity.GetHealth(ally)
				total = total + math.min(heal, missing)
				if Entity.GetHealth(ally) < Entity.GetMaxHealth(ally) * 0.35 and underFire(ctx, ally) then critical = true end
			end
			local debuffed = name == "item_guardian_greaves" and (NPC.IsSilenced(ctx.hero) or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ROOTED))
				and ctx.laneThreat and ctx.laneThreat.attacked
			if total >= heal * 1.7 or critical or debuffed then return use(ctx, ability, "none", nil, "Team heal") end
		end
	end
	local locket = item(ctx, "item_holy_locket")
	if locket and Item.GetCurrentCharges(locket) >= 5 then
		local best, bestScore
		for _, ally in ipairs(friends(ctx, Ability.GetCastRange(locket) + 100)) do
			local fraction = Entity.GetHealth(ally) / math.max(1, Entity.GetMaxHealth(ally))
			if fraction < 0.5 and (ally ~= ctx.hero or ctx.health < 0.4) then
				local score = fraction - (underFire(ctx, ally) and 0.2 or 0)
				if not bestScore or score < bestScore then best, bestScore = ally, score end
			end
		end
		if best then return use(ctx, locket, "target", best, "Holy Locket: heal ally") end
	end
	local pavise = item(ctx, "item_pavise")
	if pavise then
		for _, ally in ipairs(friends(ctx, Ability.GetCastRange(pavise) + 50)) do
			if underFire(ctx, ally) and Entity.GetHealth(ally) < Entity.GetMaxHealth(ally) * 0.7
				and not NPC.HasModifier(ally, "modifier_item_pavise_shield") then return use(ctx, pavise, "target", ally, "Pavise: shield ally") end
		end
	end
	return false
end

function consumables.run(ctx, combatOnly)
	if not ctx.settings.spells then return false end
	local treads = NPC.GetItem(ctx.hero, "item_power_treads", true)
	if not combatOnly and treads and Item.IsItemEnabled(treads) and treads ~= ctx.treadsFinished and ctx.now >= (ctx.nextTreads or 0) then
		local attribute = Hero.GetPrimaryAttribute(ctx.hero)
		if attribute == Enum.Attributes.DOTA_ATTRIBUTE_ALL then attribute = Enum.Attributes.DOTA_ATTRIBUTE_STRENGTH end
		if PowerTreads.GetStats(treads) == attribute then ctx.treadsFinished = treads
		elseif not ctx.intent and not ctx.retreating and not ctx.fightSession and not combat.busy(ctx)
			and not (ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.5) then
			ctx.nextTreads = ctx.now + 0.3
			Ability.CastNoTarget(treads, false, false, true)
			return true
		end
	end
	local healthMissing = Entity.GetMaxHealth(ctx.hero) - Entity.GetHealth(ctx.hero)
	local manaMissing = NPC.GetMaxMana(ctx.hero) - NPC.GetMana(ctx.hero)
	local quiet = ctx.now - (ctx.lastDamaged or -10) > 3 and Hero.GetRecentDamage(ctx.hero) == 0
	local fountain = NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff")
	local enemyDistance = math.huge
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) then
			enemyDistance = math.min(enemyDistance, ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)))
		end
	end
	for _, name in ipairs({"item_magic_wand", "item_magic_stick", "item_holy_locket"}) do
		local ability = item(ctx, name)
		if ability then
			local restore = Item.GetCurrentCharges(ability) * 15
			if restore > 0 and not fountain and (ctx.health < 0.4 and healthMissing >= restore * 0.5
				or ctx.target and healthMissing >= restore and manaMissing >= restore) then
				return use(ctx, ability, name == "item_holy_locket" and "target" or "none", ctx.hero, "Use stored heal charges")
			end
		end
	end
	local fire = item(ctx, "item_faerie_fire")
	if fire and ctx.health < 0.4 and healthMissing >= 85 and not fountain then return use(ctx, fire, "none", nil, "Emergency faerie fire") end
	for _, name in ipairs({"item_healing_lotus", "item_greater_healing_lotus", "item_greatest_healing_lotus"}) do
		local ability = item(ctx, name)
		local amount = name == "item_healing_lotus" and 125 or name == "item_greater_healing_lotus" and 400 or 900
		if ability and not fountain and (healthMissing >= amount and manaMissing >= amount * 0.5 or ctx.health < 0.3 and healthMissing >= amount * 0.6) then
			return use(ctx, ability, "none", nil, "Restore with lotus")
		end
	end
	if not fountain and consumables.team(ctx) then return true end
	local mango = item(ctx, "item_enchanted_mango")
	if mango and ctx.target and manaMissing >= 100 and NPC.GetMana(ctx.hero) < 100 then return use(ctx, mango, "none", nil, "Mango for combat mana") end
	if combatOnly then return false end
	if fountain then return false end
	if consumables.shareTango(ctx, quiet, enemyDistance) then return true end
	if consumables.bottle(ctx, item(ctx, "item_bottle"), quiet, enemyDistance) then return true end
	if quiet and enemyDistance > 900 then
		local flask = item(ctx, "item_flask")
		if flask and healthMissing >= 350 and not NPC.HasModifier(ctx.hero, "modifier_flask_healing") then
			return use(ctx, flask, "target", ctx.hero, "Drink healing salve")
		end
		local clarity = item(ctx, "item_clarity")
		if clarity and manaMissing >= 180 and not NPC.HasModifier(ctx.hero, "modifier_clarity_potion") then
			return use(ctx, clarity, "target", ctx.hero, "Drink clarity")
		end
	end
	local tango = item(ctx, "item_tango") or item(ctx, "item_tango_single")
	if consumables.branchTango(ctx, tango, quiet, enemyDistance) then return true end
	local resting = consumables.resting(ctx)
	if tango and Item.GetCurrentCharges(tango) > 0 and healthMissing >= math.max(50, healing(tango) * (resting and 0.6 or 0.85))
		and enemyDistance > 450 and (not ctx.retreating or resting) and not ctx.intent and not NPC.HasModifier(ctx.hero, "modifier_tango_heal") then
		local search = resting and 900 or 450
		local nearest, distance = nil, search
		ctx.tangoSkip = ctx.tangoSkip or {}
		for _, tree in ipairs(Entity.GetTreesInRadius(ctx.hero, search, true)) do
			local position = Entity.GetAbsOrigin(tree)
			local current = ctx.distance(ctx.position, position)
			if current < distance and not ctx.unsafePosition(position) and ctx.now >= (ctx.tangoSkip[tree] or 0) then nearest, distance = tree, current end
		end
		if nearest then
			if distance > Ability.GetCastRange(tango) + 40 then
				local walk = ctx.tangoWalk
				if not walk or walk.tree ~= nearest then walk = {tree = nearest, best = distance, progress = ctx.now}; ctx.tangoWalk = walk end
				if distance < walk.best - 30 then walk.best, walk.progress = distance, ctx.now end
				if ctx.now - walk.progress > 3 then
					ctx.tangoSkip[nearest], ctx.tangoWalk = ctx.now + 20, nil
					return false
				end
				if enemyDistance > 1000 then
					ctx.exactMove = ctx.now
					return ctx.move(ctx.toward(Entity.GetAbsOrigin(nearest), ctx.position, 100), "Approach tree for tango")
				end
			else
				ctx.tangoWalk = nil
				return eatTree(ctx, tango, nearest)
			end
		end
	end
	return false
end

return consumables
