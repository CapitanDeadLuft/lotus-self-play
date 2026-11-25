local lina = {reserved = {lina_laguna_blade = true, lina_light_strike_array = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local finisher = require("self_play.heroes.finisher")

function lina.laguna(ctx, api)
	local laguna = finisher.ready(ctx, "lina_laguna_blade")
	if not laguna then return false end
	local damage = common.value(laguna, "damage", 400)
	local pierces = common.value(laguna, "pierce_immunity", 0) > 0
	local range = Ability.GetCastRange(laguna) + 100
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		if ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= range and finisher.magic(ctx, enemy, damage, 0.6, pierces)
			and not NPC.IsLinkensProtected(enemy) then
			return tactics.cast(ctx, api, "lina_laguna_blade", "target", enemy)
		end
	end
	return false
end

function lina.strike(ctx, api, retreat)
	local strike = finisher.ready(ctx, "lina_light_strike_array")
	if not strike then return false end
	local range = Ability.GetCastRange(strike)
	local delay = common.value(strike, "light_strike_array_delay_time", 0.5)
	local radius = common.value(strike, "light_strike_array_aoe", 250)
	local best, bestScore
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		if distance <= range + radius and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
			and (NPC.IsChannellingAbility(enemy) or retreat and distance < 600 or not retreat and tactics.committed(ctx, enemy)) then
			local locked = finisher.disabled(enemy)
			local remaining = 0
			if locked then
				local control = NPC.GetStatesDuration(enemy, {[Enum.ModifierState.MODIFIER_STATE_STUNNED] = true, [Enum.ModifierState.MODIFIER_STATE_ROOTED] = true}, true)
				for _, seconds in pairs(control or {}) do remaining = math.max(remaining, seconds) end
			end
			local point = ctx.predict(enemy, Ability.GetCastPoint(strike) + delay)
			local score = (locked and 2 or 1) + (NPC.IsChannellingAbility(enemy) and 3 or 0) - (NPC.IsRunning(enemy) and not locked and 0.5 or 0)
			if locked and remaining > Ability.GetCastPoint(strike) + delay - 0.1 then score = score + 1 end
			if ctx.distance(ctx.position, point) <= range and (not bestScore or score > bestScore) then best, bestScore = point, score end
		end
	end
	return best ~= nil and tactics.cast(ctx, api, "lina_light_strike_array", "point", nil, best)
end

function lina.update(ctx, api, retreat)
	if lina.laguna(ctx, api) then return true end
	return lina.strike(ctx, api, retreat)
end

function lina.emergency(ctx, api)
	return lina.laguna(ctx, api)
end

return lina
