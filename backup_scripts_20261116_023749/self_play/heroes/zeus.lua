local zeus = {reserved = {zuus_thundergods_wrath = true, zuus_lightning_bolt = true, zuus_heavenly_jump = true, zuus_cloud = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local finisher = require("self_play.heroes.finisher")

function zeus.wrath(ctx, api)
	local wrath = finisher.ready(ctx, "zuus_thundergods_wrath")
	if not wrath then return false end
	local damage = common.value(wrath, "damage", 300)
	local kills, wounded, near = 0, 0, 0
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		if finisher.magic(ctx, enemy, damage, Ability.GetCastPoint(wrath) + 0.2) then kills = kills + 1 end
		if Entity.GetHealth(enemy) < Entity.GetMaxHealth(enemy) * 0.45 then wounded = wounded + 1 end
		if ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1500 then near = near + 1 end
	end
	local teamfight = wounded >= 3 or wounded >= 2 and near >= 2 and ctx.fightSession ~= nil
	if kills >= 1 or teamfight then
		ctx.heroState.wrathReason = string.format("kills=%d wounded=%d", kills, wounded)
		return tactics.cast(ctx, api, "zuus_thundergods_wrath", "none")
	end
	return false
end

function zeus.bolt(ctx, api, retreat)
	local bolt = finisher.ready(ctx, "zuus_lightning_bolt")
	if not bolt then return false end
	local range = Ability.GetCastRange(bolt)
	local damage = common.value(bolt, "damage", 140)
	local committed
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		if distance <= range then
			if finisher.magic(ctx, enemy, damage, 0.4) or NPC.IsChannellingAbility(enemy) then
				return tactics.cast(ctx, api, "zuus_lightning_bolt", "target", enemy)
			end
			if retreat and distance < 600 and not finisher.disabled(enemy) then committed = enemy
			elseif not retreat and tactics.committed(ctx, enemy) then committed = committed or enemy end
		end
	end
	if committed and NPC.GetMana(ctx.hero) - Ability.GetManaCost(bolt) > NPC.GetMaxMana(ctx.hero) * 0.25 then
		return tactics.cast(ctx, api, "zuus_lightning_bolt", "target", committed)
	end
	return false
end

function zeus.jump(ctx, api)
	local jump = finisher.ready(ctx, "zuus_heavenly_jump")
	local chaser = finisher.chaser(ctx, 650)
	if not jump or not chaser or ctx.health > 0.6 then return false end
	local forward = Entity.GetRotation(ctx.hero):GetForward()
	local dx, dy = ctx.home.x - ctx.position.x, ctx.home.y - ctx.position.y
	local length = math.max(1, math.sqrt(dx * dx + dy * dy))
	local landing = Vector(ctx.position.x + forward.x * 450, ctx.position.y + forward.y * 450, ctx.position.z)
	if (forward.x * dx + forward.y * dy) / length > 0.75 and GridNav.IsTraversable(landing) and not ctx.unsafePosition(landing) then
		return tactics.cast(ctx, api, "zuus_heavenly_jump", "none")
	end
	return tactics.steer(ctx, ctx.toward(ctx.position, ctx.home, 120), "Turn to escape with Heavenly Jump")
end

function zeus.nimbusTarget(ctx, retreat)
	local best, bestScore
	local function consider(enemy, score)
		if common.visible(enemy) and not NPC.IsIllusion(enemy) and not finisher.saved(enemy)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
			and (not bestScore or score > bestScore) then best, bestScore = enemy, score end
	end
	for _, enemy in ipairs(finisher.enemies(ctx)) do
		local position = Entity.GetAbsOrigin(enemy)
		local score = 0
		local fight = ctx.allyFights and ctx.allyFights[Entity.GetIndex(enemy)]
		if fight and ctx.now - fight.time < 2.5 then score = score + 3 end
		if ctx.fightSession and ctx.fightSession.target == enemy then score = score + 3 end
		if tactics.committed(ctx, enemy) then score = score + 2 end
		if retreat and ctx.distance(ctx.position, position) < 900 then score = score + 4 end
		for _, tower in ipairs(ctx.towers or {}) do
			if common.visible(tower) and Entity.IsSameTeam(ctx.hero, tower) and ctx.distance(position, Entity.GetAbsOrigin(tower)) < 1100 then score = score + 2; break end
		end
		if finisher.disabled(enemy) or not NPC.IsRunning(enemy) then score = score + 1 end
		score = score + (1 - Entity.GetHealth(enemy) / math.max(1, Entity.GetMaxHealth(enemy))) * 2
		if score >= 3 then consider(enemy, score) end
	end
	return best
end

function zeus.nimbus(ctx, api, retreat)
	local cloud = NPC.GetAbility(ctx.hero, "zuus_cloud")
	if not cloud or Ability.IsHidden(cloud) or Ability.GetLevel(cloud) < 1 or not finisher.ready(ctx, "zuus_cloud") then return false end
	local target = zeus.nimbusTarget(ctx, retreat)
	if not target then return false end
	local point = ctx.predict(target, Ability.GetCastPoint(cloud) + 0.5)
	ctx.heroState.nimbusTarget = NPC.GetUnitName(target)
	local range = Ability.GetCastRange(cloud)
	return tactics.cast(ctx, api, "zuus_cloud", "point", nil, point, range > 0 and range or 99999)
end

function zeus.update(ctx, api, retreat)
	if zeus.wrath(ctx, api) then return true end
	if zeus.nimbus(ctx, api, retreat) then return true end
	if retreat and zeus.jump(ctx, api) then return true end
	return zeus.bolt(ctx, api, retreat)
end

zeus.emergency = function(ctx, api)
	if zeus.wrath(ctx, api) then return true end
	if zeus.nimbus(ctx, api, ctx.retreating) then return true end
	if ctx.retreating and zeus.jump(ctx, api) then return true end
	return false
end

return zeus
