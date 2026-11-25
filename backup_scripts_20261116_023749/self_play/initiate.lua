local initiate = {}
local fightSim = require("self_play.fight_sim")

initiate.blinks = {"item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink"}

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function initiate.ultimate(ctx, combat)
	for index = 0, 23 do
		local ability = NPC.GetAbilityByIndex(ctx.hero, index)
		if ability and Ability.IsUltimate(ability) and combat.ready(ctx, ability, false) then
			local effect = ctx.catalog.abilities[Ability.GetName(ability)] or {}
			local radius = ctx.planner.levelValue(effect.radius, Ability.GetLevel(ability))
			local damage = ctx.planner.levelValue(effect.damage, Ability.GetLevel(ability))
			if radius > 0 and (damage > 0 or effect.disable) then return ability, radius end
		end
	end
	return nil
end

function initiate.blink(ctx, combat)
	for _, name in ipairs(initiate.blinks) do
		local item = NPC.GetItem(ctx.hero, name, false)
		if item and combat.ready(ctx, item, true) then return item end
	end
	return nil
end

function initiate.plan(ctx, combat)
	if not ctx.settings.spells or ctx.settings.fights == false or ctx.retreating or ctx.hardRetreat or ctx.health < 0.6
		or ctx.clock < 300 or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return nil end
	local blink = initiate.blink(ctx, combat)
	if not blink then return nil end
	local ultimate, radius = initiate.ultimate(ctx, combat)
	if not ultimate then return nil end
	local range = Ability.GetCastRange(blink) - 50
	local enemies = {}
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsIllusion(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
			enemies[#enemies + 1] = enemy
		end
	end
	if #enemies < 2 then return nil end
	local best, bestCount, bestTarget
	for _, anchor in ipairs(enemies) do
		local x, y, n = 0, 0, 0
		local anchorPosition = Entity.GetAbsOrigin(anchor)
		for _, enemy in ipairs(enemies) do
			local position = Entity.GetAbsOrigin(enemy)
			if ctx.distance(position, anchorPosition) < radius * 1.2 then x, y, n = x + position.x, y + position.y, n + 1 end
		end
		local point = Vector(x / n, y / n, anchorPosition.z)
		local inside = 0
		for _, enemy in ipairs(enemies) do
			if ctx.distance(Entity.GetAbsOrigin(enemy), point) < radius * 0.75 then inside = inside + 1 end
		end
		if inside >= 2 and (not bestCount or inside > bestCount) and ctx.distance(ctx.position, point) <= range
			and ctx.distance(ctx.position, point) > 350 and GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
			best, bestCount, bestTarget = point, inside, anchor
		end
	end
	if not best then return nil end
	local support = 0
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.4
			and ctx.distance(Entity.GetAbsOrigin(ally), best) < 1400 then support = support + 1 end
	end
	if support == 0 then return nil end
	local outcome = fightSim.evaluate(ctx, best, {target = bestTarget, radius = 1700})
	if not outcome or not outcome.favorable or outcome.selfDead then return nil end
	local channelled = Enum.AbilityBehavior and Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_CHANNELLED or 128
	local channel = ctx.planner.hasFlag(Ability.GetBehavior(ultimate), channelled)
	local bkb = channel and NPC.GetItem(ctx.hero, "item_black_king_bar", false)
	if bkb and not combat.ready(ctx, bkb, true) then bkb = nil end
	return {blink = blink, ultimate = ultimate, point = best, target = bestTarget, count = bestCount, bkb = bkb}
end

function initiate.run(ctx, combat, plan)
	plan = plan or initiate.plan(ctx, combat)
	if not plan then return false end
	if plan.bkb and not NPC.HasModifier(ctx.hero, "modifier_black_king_bar_immune") then
		combat.cast(ctx, plan.bkb, "none")
		ctx.mode = "Initiate: Black King Bar before blink"
		return true
	end
	combat.cast(ctx, plan.blink, "point", nil, plan.point)
	ctx.channelFollowup = {spell = plan.ultimate, target = plan.target, expires = ctx.now + 0.9, notBefore = ctx.now + 0.12}
	ctx.initiateStatus = {time = ctx.now, text = string.format("blink into %d enemies, then %s", plan.count, Ability.GetName(plan.ultimate))}
	ctx.mode = "Initiate: blink into enemies"
	return true
end

return initiate
