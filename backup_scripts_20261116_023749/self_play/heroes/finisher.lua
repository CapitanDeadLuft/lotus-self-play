local finisher = {}
local common = require("self_play.heroes.common")

finisher.protected = {"modifier_dazzle_shallow_grave", "modifier_oracle_false_promise_timer", "modifier_item_aeon_disk_buff",
	"modifier_abaddon_borrowed_time", "modifier_winter_wyvern_winters_curse_aura", "modifier_templar_assassin_refraction_absorb"}

function finisher.saved(target)
	for _, name in ipairs(finisher.protected) do
		if NPC.HasModifier(target, name) then return true end
	end
	return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
end

function finisher.magic(ctx, target, damage, delay, pierces)
	if not common.visible(target) or NPC.IsIllusion(target) or finisher.saved(target) then return false end
	if not pierces and NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then return false end
	local barriers = NPC.GetBarriers and NPC.GetBarriers(target)
	local shield = barriers and ((barriers.magic and barriers.magic.current or 0) + (barriers.all and barriers.all.current or 0)) or 0
	local health = Entity.GetHealth(target) + math.max(0, NPC.GetHealthRegen(target)) * (delay or 0.5) + shield
	return damage * NPC.GetMagicalArmorDamageMultiplier(target) >= health + 10
end

function finisher.enemies(ctx)
	local list = {}
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy) then list[#list + 1] = enemy end
	end
	return list
end

function finisher.ready(ctx, name)
	local ability = NPC.GetAbility(ctx.hero, name)
	if not ability or Ability.GetLevel(ability) < 1 or Ability.IsHidden(ability) or not Ability.IsReady(ability)
		or not Ability.IsCastable(ability, NPC.GetMana(ctx.hero)) or (ctx.abilityAttempts[name] or 0) > ctx.now then return nil end
	return ability
end

function finisher.chaser(ctx, range)
	local best, distance
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local current = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		if current < range and (not distance or current < distance) then best, distance = enemy, current end
	end
	return best
end

function finisher.disabled(target)
	return NPC.IsStunned(target) or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_HEXED)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED)
end

function finisher.threat(ctx, target)
	return NPC.GetTrueDamage(target) / math.max(0.3, NPC.GetSecondsPerAttack(target, false)) + NPC.GetCurrentLevel(target) * 8
end

return finisher
