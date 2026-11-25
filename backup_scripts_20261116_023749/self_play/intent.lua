local intent = {}
local engagement = require("self_play.engagement")
local profile = require("self_play.profile")
local awareness = require("self_play.awareness")

local function alive(target)
	return target and Entity.IsEntity(target) and Entity.IsAlive(target)
end

intent.cooldown = 2.5

local function clear(ctx)
	local task = ctx.intent
	if task and task.kind == "hero" and task.target and Entity.IsEntity(task.target) then
		ctx.intentReleased = ctx.intentReleased or {}
		ctx.intentReleased[Entity.GetIndex(task.target)] = ctx.now
	end
	if ctx.parent then ctx.intent = false else ctx.intent = nil end
end

function intent.cooling(ctx, target)
	if not target or not Entity.IsEntity(target) then return false end
	local released = ctx.intentReleased and ctx.intentReleased[Entity.GetIndex(target)]
	if not released or ctx.now - released >= intent.cooldown then return false end
	local health = Entity.GetHealth(target)
	if health <= NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target) then return false end
	if NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 30,
		NPC.GetAttackRange(target) + NPC.GetAttackRangeBonus(target) + 150) == ctx.hero then return false end
	return true
end

function intent.caster(ctx)
	if ctx.role and ctx.role >= 4 then return true end
	return Hero.GetPrimaryAttribute ~= nil and Enum.Attributes ~= nil
		and Hero.GetPrimaryAttribute(ctx.hero) == Enum.Attributes.DOTA_ATTRIBUTE_INTELLECT
end

function intent.primed(ctx)
	local profile = ctx.heroModule
	if not profile or not profile.preAttack or not ctx.settings or not ctx.settings.spells then return false end
	for name in pairs(profile.preAttack) do
		local ability = NPC.GetAbility(ctx.hero, name)
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) and Ability.IsReady(ability)
			and Ability.IsCastable(ability, NPC.GetMana(ctx.hero)) then return true end
	end
	return false
end

function intent.chasing(ctx, target)
	if ctx.intent and ctx.intent.followUntil and ctx.now < ctx.intent.followUntil then return false end
	local reach = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 100
	return ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > reach
end

function intent.begin(ctx, target, kind, followAttack)
	local old = ctx.intent
	if old and old.target == target and old.kind == kind and (old.expires or 0) > ctx.now then
		old.followAttack = old.followAttack or followAttack
		return
	end
	ctx.intent = {target = target, kind = kind, expires = ctx.now + (kind == "hero" and 3 or 2),
		followAttack = followAttack, started = ctx.now, health = Entity.GetHealth(target),
		distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target)), progressAt = ctx.now}
end

function intent.follow(ctx, target)
	intent.begin(ctx, target, "hero", true)
	local task = ctx.intent
	task.followUntil = math.min(ctx.now + 1.8, task.progressAt + 2.4)
	task.expires = math.max(task.expires, task.followUntil)
end

function intent.target(ctx)
	local task = ctx.intent
	if not task then return nil end
	if task.kind == "hero" and alive(task.target) and not Entity.IsDormant(task.target) and NPC.IsVisible(task.target) then
		local health, position = Entity.GetHealth(task.target), Entity.GetAbsOrigin(task.target)
		local distance = ctx.distance(ctx.position, position)
		if health < task.health - 1 or distance < task.distance - 60 then task.progressAt, task.health, task.distance = ctx.now, health, distance end
		local finishing = health <= math.max(Entity.GetMaxHealth(task.target) * 0.18,
			NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(task.target) * 2)
		local reachable = math.max(0, distance - NPC.GetAttackRange(ctx.hero) - NPC.GetAttackRangeBonus(ctx.hero)) / math.max(100, NPC.GetMoveSpeed(ctx.hero)) < 2.5
		local winning = ctx.combatDecision and ctx.combatDecision.target == task.target and ctx.combatDecision.safe
		if ctx.now - task.progressAt < 2 and (finishing and reachable or task.progressAt > task.started)
			and (ctx.health > 0.35 or winning) and distance < 1400 and not ctx.unsafePosition(engagement.attackPosition(ctx, task.target)) then
			task.expires = math.max(task.expires, ctx.now + 1.6)
		end
	end
	if ctx.now >= task.expires or not alive(task.target) then clear(ctx); return nil end
	if not Entity.IsDormant(task.target) and NPC.IsVisible(task.target) then return task.target end
	return nil
end

function intent.run(ctx)
	local task = ctx.intent
	if not task then return false end
	local target = intent.target(ctx)
	if not ctx.intent then return false end
	if ctx.hardRetreat then clear(ctx); return false end
	if not target then
		local memory = ctx.memory[Entity.GetIndex(task.target)]
		if task.kind ~= "hero" or not memory or ctx.now - memory.time > 2.5 then clear(ctx); return false end

		local position, confidence = awareness.fogPosition(ctx, task.target)
		if not position or confidence < 0.35 then clear(ctx); return false end
		if ctx.distance(ctx.position, position) > 1300 or ctx.unsafePosition(position)
			or ctx.distance(ctx.position, position) < 90 then clear(ctx); return false end
		return ctx.move(position, "Pursue briefly lost target", 60)
	end
	local position = Entity.GetAbsOrigin(target)
	if ctx.unsafePosition(engagement.attackPosition(ctx, target)) or ctx.distance(ctx.position, position) > 1400 then clear(ctx); return false end
	if task.kind == "structure" and not ctx.pushSafe(target) then clear(ctx); return false end
	if task.kind == "hero" then
		local decision = engagement.assess(ctx, target)
		if not engagement.keep(decision) then
			ctx.combatRelease = {time = ctx.now, target = target, reason = decision and "Fight no longer favorable; follow-through exhausted" or "Target outside safe pursuit reach"}
			clear(ctx)
			return false
		end
		ctx.target = target
		local order = ctx.hits.ordered
		if order and order.target == target and order.confirmed and order.release <= ctx.now then task.followAttack = false end
		if (not task.followAttack or intent.caster(ctx) or intent.chasing(ctx, target) or intent.primed(ctx)) and ctx.fightAbilities() then return true end
	end
	if task.kind == "hero" and not profile.shouldHit(ctx, target) then return profile.hold(ctx, target, "Commit: hold spell range") end
	local acted = ctx.attack(target, task.kind == "hero" and "Commit to hero attack" or "Push behind creep wave")
	if not acted then clear(ctx) end
	return acted
end

return intent
