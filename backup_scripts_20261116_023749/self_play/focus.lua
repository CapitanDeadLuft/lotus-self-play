local focus = {}
local prediction = require("self_play.prediction")

focus.horizon = 1.5

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function targetable(unit)
	return visible(unit) and NPC.IsHero(unit) and not NPC.IsIllusion(unit)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
end

function focus.disabledFor(unit)
	local remaining = 0
	if NPC.GetStatesDuration then
		local ok, durations = pcall(NPC.GetStatesDuration, unit, {Enum.ModifierState.MODIFIER_STATE_STUNNED,
			Enum.ModifierState.MODIFIER_STATE_HEXED})
		if ok and type(durations) == "table" then
			for _, value in pairs(durations) do if type(value) == "number" then remaining = math.max(remaining, value) end end
		end
	end
	if remaining == 0 and (NPC.IsStunned(unit) or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_HEXED)) then remaining = 0.5 end
	return remaining
end

function focus.pending(ctx, target, extra)
	local incoming = prediction.incoming(ctx, target, focus.horizon, {allies = true, low = true}) or 0
	return incoming + (extra or 0)
end

function focus.covered(ctx, target, extra)
	if not targetable(target) then return true end
	local health = Entity.GetHealth(target)
	if focus.pending(ctx, target, extra) >= health then return true end
	local decision = ctx.combatDecision
	if decision and decision.target == target and (decision.killTime or math.huge) <= 1.2 then return true end
	return false
end

function focus.threat(ctx, enemy)
	local damage = NPC.GetTrueDamage(enemy) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
	if NPC.IsAttacking(enemy) then
		local victim = NPC.FindFacingNPC(enemy, nil, Enum.TeamType.TEAM_ENEMY, 30, NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 150)
		if victim and NPC.IsHero(victim) then damage = damage * 1.5 end
	end
	return damage
end

function focus.secondary(ctx, primary, origin, range)
	local best, bestScore
	origin = origin or ctx.position
	for _, enemy in ipairs(ctx.enemies or {}) do
		if enemy ~= primary and targetable(enemy) then
			local distance = ctx.distance(origin, Entity.GetAbsOrigin(enemy))
			if distance <= (range or 1200) then
				local fraction = Entity.GetHealth(enemy) / math.max(1, Entity.GetMaxHealth(enemy))
				local score = focus.threat(ctx, enemy) * 2 + (1 - fraction) * 250 - distance * 0.15
				if not bestScore or score > bestScore then best, bestScore = enemy, score end
			end
		end
	end
	return best
end

function focus.split(ctx, primary, origin, range, extra)
	if not targetable(primary) then return focus.secondary(ctx, nil, origin, range) end
	if not focus.covered(ctx, primary, extra) then return primary end
	return focus.secondary(ctx, primary, origin, range) or primary
end

function focus.disableTarget(ctx, primary, range)
	if not targetable(primary) then return nil end
	local locked = focus.disabledFor(primary) > 1
	if not locked and not focus.covered(ctx, primary) then return primary end
	local other = focus.secondary(ctx, primary, ctx.position, range)
	if other and focus.disabledFor(other) < 0.5 then return other end
	return not locked and primary or nil
end

return focus
