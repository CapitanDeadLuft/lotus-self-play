local maiden = {reserved = {crystal_maiden_freezing_field = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local finisher = require("self_play.heroes.finisher")
local awareness = require("self_play.awareness")

function maiden.protected(ctx)
	return NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
		or NPC.HasModifier(ctx.hero, "modifier_item_glimmer_cape_fade")
		or NPC.HasModifier(ctx.hero, "modifier_item_ghost_state")
end

maiden.inner = 420

local function disabledFor(ctx, enemy)
	local control = awareness.control(ctx, enemy)
	local left = 0
	for _, state in ipairs({Enum.ModifierState.MODIFIER_STATE_STUNNED, Enum.ModifierState.MODIFIER_STATE_ROOTED,
		Enum.ModifierState.MODIFIER_STATE_HEXED}) do
		if state then left = math.max(left, control[state] or 0) end
	end
	return left
end

function maiden.field(ctx, api)
	local field = finisher.ready(ctx, "crystal_maiden_freezing_field")
	if not field then ctx.heroState.fieldApproach = nil; return false end
	local radius = common.value(field, "radius", 810)
	local reach = radius - 200
	local hits, locked, center, held = 0, 0, 0, {}
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		if distance < radius + 150 then
			local left = finisher.disabled(enemy) and disabledFor(ctx, enemy) or 0
			if distance < reach then hits = hits + 1 end
			if distance < maiden.inner then center = center + 1 end
			if finisher.disabled(enemy) and distance < reach then locked = locked + 1 end
			if left > 0 then held[#held + 1] = {enemy = enemy, distance = distance, left = left} end
		end
	end
	local allies = tactics.count(ctx, ctx.position, 900, true)
	local incoming = awareness.damage(ctx, ctx.position, 3)
	local survivable = incoming < Entity.GetHealth(ctx.hero) * 0.5 or maiden.protected(ctx)
	local speed = math.max(200, NPC.GetMoveSpeed(ctx.hero))
	local target
	for _, entry in ipairs(held) do
		local walk = math.max(0, entry.distance - maiden.inner + 60) / speed
		if entry.distance >= maiden.inner and walk + Ability.GetCastPoint(field) + 0.15 < entry.left
			and (not target or entry.distance < target.distance) then target = entry end
	end
	if target and survivable then
		local point = Entity.GetAbsOrigin(target.enemy)
		local goal = ctx.toward(ctx.position, point, target.distance - maiden.inner + 80)
		if GridNav.IsTraversable(goal) and not ctx.unsafePosition(goal)
			and awareness.damage(ctx, goal, 3) < Entity.GetHealth(ctx.hero) * 0.5 then
			ctx.heroState.fieldApproach = {target = target.enemy, time = ctx.now}
			return tactics.steer(ctx, goal, "Step in before Freezing Field")
		end
	end
	ctx.heroState.fieldApproach = nil
	if hits == 0 then return false end
	local edgeOnly = center == 0 and locked == 0 and hits <= 1
	if survivable and not edgeOnly and (hits >= 3 or hits >= 2 and (allies >= 2 or locked >= 1) or hits >= 1 and locked >= 1 and allies >= 2) then
		ctx.heroState.fieldStarted = ctx.now
		return tactics.cast(ctx, api, "crystal_maiden_freezing_field", "none")
	end
	return false
end

function maiden.channel(ctx, ability, state)
	local radius = common.value(ability, "radius", 810)
	local inside = 0
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		if ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < radius + 40 then inside = inside + 1 end
	end
	if inside == 0 then state.emptySince = state.emptySince or ctx.now else state.emptySince = nil end
	if state.emptySince and ctx.now - state.started > 0.5 and ctx.now - state.emptySince > 0.5 then
		ctx.heroState.fieldStarted = nil
		return "no enemy hero left in Freezing Field"
	end
	local maximum = Entity.GetMaxHealth(ctx.hero)
	if not maiden.protected(ctx) and Entity.GetHealth(ctx.hero) < maximum * 0.22 and Hero.GetRecentDamage(ctx.hero) > maximum * 0.15 then
		ctx.heroState.fieldStarted = nil
		return "about to die in Freezing Field"
	end
	return nil
end

function maiden.locked(ctx)
	local started = ctx.heroState.fieldStarted
	if not started or ctx.now - started >= 10.5 then return false end
	return NPC.IsChannellingAbility(ctx.hero) or ctx.now - started < 1
end

function maiden.update(ctx, api, retreat)
	if maiden.locked(ctx) then
		ctx.mode = "Channel Freezing Field"
		return true
	end
	if retreat then return false end
	return maiden.field(ctx, api)
end

return maiden
