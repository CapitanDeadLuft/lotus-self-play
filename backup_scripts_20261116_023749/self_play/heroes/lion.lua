local lion = {reserved = {lion_finger_of_death = true, lion_voodoo = true, lion_impale = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local finisher = require("self_play.heroes.finisher")

function lion.fingerDamage(ctx, finger)
	local damage = common.value(finger, "damage", 600)
	local counter = NPC.GetModifier(ctx.hero, "modifier_lion_finger_of_death_kill_counter")
	if counter and Modifier.GetStackCount then damage = damage + Modifier.GetStackCount(counter) * common.value(finger, "damage_per_kill", 25) end
	return damage
end

function lion.finger(ctx, api)
	local finger = finisher.ready(ctx, "lion_finger_of_death")
	if not finger then return false end
	local damage = lion.fingerDamage(ctx, finger)
	local range = Ability.GetCastRange(finger) + 100
	local best, bestHealth
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		if ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= range and finisher.magic(ctx, enemy, damage, 0.6)
			and not NPC.IsLinkensProtected(enemy) and (not bestHealth or Entity.GetMaxHealth(enemy) > bestHealth) then
			best, bestHealth = enemy, Entity.GetMaxHealth(enemy)
		end
	end
	return best ~= nil and tactics.cast(ctx, api, "lion_finger_of_death", "target", best)
end

function lion.hex(ctx, api, retreat)
	local hex = finisher.ready(ctx, "lion_voodoo")
	if not hex then return false end
	local range = Ability.GetCastRange(hex)
	local best, bestScore
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		if distance <= range and not finisher.disabled(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
			local score = finisher.threat(ctx, enemy)
			if NPC.IsChannellingAbility(enemy) then score = score + 1000 end
			if retreat and distance < 500 then score = score + 300 end
			local attacking = NPC.IsAttacking(enemy) and NPC.FindFacingNPC(enemy, nil, Enum.TeamType.TEAM_ENEMY, 30, NPC.GetAttackRange(enemy) + 150)
			if attacking and NPC.IsHero(attacking) then score = score + 200 end
			if tactics.committed(ctx, enemy) then score = score + 150 end
			if (retreat and distance < 500 or tactics.committed(ctx, enemy) or NPC.IsChannellingAbility(enemy) or attacking and NPC.IsHero(attacking))
				and (not bestScore or score > bestScore) then best, bestScore = enemy, score end
		end
	end
	return best ~= nil and tactics.cast(ctx, api, "lion_voodoo", "target", best)
end

function lion.spike(ctx, api, retreat)
	local spike = finisher.ready(ctx, "lion_impale")
	if not spike then return false end
	local range = Ability.GetCastRange(spike)
	local target
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		if distance <= range + 100 and not finisher.disabled(enemy)
			and (NPC.IsChannellingAbility(enemy) or retreat and distance < 550 or not retreat and tactics.committed(ctx, enemy)) then
			target = enemy
			break
		end
	end
	if not target then return false end
	local point = tactics.point(ctx, spike, target, common.value(spike, "speed", 2800))
	if ctx.distance(ctx.position, point) > range then point = ctx.toward(ctx.position, point, range) end
	return tactics.cast(ctx, api, "lion_impale", "point", nil, point)
end

function lion.update(ctx, api, retreat)
	if lion.finger(ctx, api) then return true end
	if lion.hex(ctx, api, retreat) then return true end
	return lion.spike(ctx, api, retreat)
end

function lion.emergency(ctx, api)
	if lion.finger(ctx, api) then return true end
	if ctx.retreating and lion.hex(ctx, api, true) then return true end
	return false
end

return lion
