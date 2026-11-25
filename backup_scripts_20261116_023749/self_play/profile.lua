local profile = {}

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function dps(unit)
	return NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false))
end

function profile.spellRange(ctx)
	local best = 0
	local level = ctx.planner and ctx.planner.levelValue
	for index = 0, 23 do
		local ability = NPC.GetAbilityByIndex(ctx.hero, index)
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsPassive(ability) and not Ability.IsHidden(ability) then
			local effect = ctx.catalog.abilities[Ability.GetName(ability)] or {}
			local damage = level and level(effect.damage, Ability.GetLevel(ability)) or 0
			if effect.disable or damage > 0 or effect.heal or effect.save then
				best = math.max(best, Ability.GetCastRange(ability))
			end
		end
	end
	return best
end

function profile.get(ctx)
	local cached = ctx.heroProfile
	if cached and ctx.now < cached.expires then return cached end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local own = dps(ctx.hero)
	local cores, total = 0, 0
	for _, ally in ipairs(ctx.allies or {}) do
		if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) then
			local role = ctx.runeRoles and ctx.runeRoles[Entity.GetIndex(ally)]
			if not role or role <= 3 then cores, total = cores + 1, total + dps(ally) end
		end
	end
	local average = cores > 0 and total / cores or 0
	local spell = profile.spellRange(ctx)
	local hitter = ctx.role <= 3 or average > 0 and own >= average * 0.6
	local result = {
		expires = ctx.now + 1,
		ranged = NPC.IsRanged(ctx.hero),
		range = range,
		dps = own,
		spellRange = spell,
		hitter = hitter,
		caster = not hitter,
	}
	ctx.heroProfile = result
	return result
end

function profile.frontline(ctx, target)
	local point = Entity.GetAbsOrigin(target)
	local nearest
	for _, ally in ipairs(ctx.allies or {}) do
		if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) then
			local role = ctx.runeRoles and ctx.runeRoles[Entity.GetIndex(ally)]
			local distance = ctx.distance(Entity.GetAbsOrigin(ally), point)
			if (not role or role <= 3) and distance < 1500 and (not nearest or distance < nearest) then nearest = distance end
		end
	end
	return nearest
end

function profile.standoff(ctx, target)
	local hero = profile.get(ctx)
	if not hero.caster then return math.max(100, hero.range - 40) end
	local distance = math.max(hero.range, math.min(hero.spellRange, 900)) - 50
	local front = profile.frontline(ctx, target)
	if front then distance = math.max(distance, math.min(front + 150, hero.spellRange - 50)) end
	return math.max(hero.range - 40, distance)
end

function profile.shouldHit(ctx, target)
	local hero = profile.get(ctx)
	if not hero.caster or not NPC.IsHero(target) then return true end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target))
	if distance <= hero.range + 20 then return true end
	return Entity.GetHealth(target) <= NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target) * 2
end

function profile.hold(ctx, target, mode)
	local spacing = profile.standoff(ctx, target)
	local point = Entity.GetAbsOrigin(target)
	local goal = ctx.toward(point, ctx.position, spacing)
	if ctx.distance(ctx.position, point) >= spacing - 60 and ctx.distance(ctx.position, point) <= spacing + 120 then
		ctx.mode = mode
		return ctx.stop()
	end
	return ctx.move(goal, mode, 40)
end

return profile
