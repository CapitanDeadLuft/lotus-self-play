local arc = {pending = {}, notes = {}, reserved = {arc_warden_tempest_double = true, arc_warden_tempest_recall = true,
	arc_warden_flux = true, arc_warden_magnetic_field = true, arc_warden_spark_wraith = true, item_hand_of_midas = true}}
local common = require("self_play.heroes.common")
local tasks = require("self_play.heroes.arc_tasks")
local towerSafety = require("self_play.tower_safety")
local intent = require("self_play.intent")
local awareness = require("self_play.awareness")
local focus = require("self_play.focus")

arc.skip = {bottle = true}

function arc.build(ctx, plan)
	local result, midas = {}, false
	for _, name in ipairs(plan) do
		if name == "hand_of_midas" then midas = true
		elseif not arc.skip[name] then result[#result + 1] = name end
	end
	if not midas and ctx.role > 3 then return result end
	local at = math.min(#result + 1, 2)
	for index, name in ipairs(result) do
		if name == "boots" then at = index + 1; break end
	end
	table.insert(result, at, "hand_of_midas")
	return result
end

local function isDouble(ctx, unit)
	return unit ~= ctx.hero and NPC.GetUnitName(unit) == ctx.heroName and NPC.HasModifier(unit, "modifier_arc_warden_tempest_double")
end

local function ownFlux(ctx, enemy)
	for _, modifier in ipairs(NPC.GetModifiers(enemy)) do
		if Modifier.GetName(modifier) == "modifier_arc_warden_flux" and Modifier.GetCaster(modifier) == ctx.hero then return true end
	end
	return false
end

local function midas(ctx, api, approach)
	local item = common.ability(ctx, api, "item_hand_of_midas")
	if not item or ctx.nearEnemies > 0 then return false end
	local state = (ctx.parent or ctx).heroState
	state.midasClaims = state.midasClaims or {}
	for id, expiry in pairs(state.midasClaims) do if expiry <= ctx.now then state.midasClaims[id] = nil end end
	local best, score
	local range = Ability.GetCastRange(item)
	for _, creep in ipairs(ctx.worldNPCs) do
		if common.visible(creep) and not NPC.IsWaitingToSpawn(creep) and not Entity.IsSameTeam(ctx.hero, creep)
			and (NPC.IsLaneCreep(creep) or not ctx.temporaryUnit and NPC.IsNeutral(creep) and NPC.IsCreep(creep)
				and not NPC.IsAncient(creep) and not NPC.IsRoshan(creep) and not NPC.IsTormentor(creep))
			and not state.midasClaims[Entity.GetIndex(creep)] and api.allowed(ctx, item, creep) then
			local position = Entity.GetAbsOrigin(creep)
			local distance = ctx.distance(ctx.position, position)
			if distance <= range + (approach and 300 or 0) and not ctx.unsafePosition(position) then
				local value = NPC.GetBountyXP(creep) - math.max(0, distance - range) * 0.5
				if not score or value > score then best, score = creep, value end
			end
		end
	end
	if not best then return false end
	if ctx.distance(ctx.position, Entity.GetAbsOrigin(best)) > range then
		return ctx.move(ctx.toward(Entity.GetAbsOrigin(best), ctx.position, math.max(100, range - 40)))
	end
	if common.cast(ctx, api, item, "target", best) then
		state.midasClaims[Entity.GetIndex(best)] = ctx.now + 1
		return true
	end
	return false
end

local function farm(ctx, api)
	if ctx.nearEnemies > 0 or ctx.retreating or not ctx.temporaryUnit and ctx.clock < 600 then return false end
	local creeps = {}
	for _, unit in ipairs(ctx.worldNPCs) do
		if common.visible(unit) and not NPC.IsWaitingToSpawn(unit) and not Entity.IsSameTeam(ctx.hero, unit)
			and (NPC.IsLaneCreep(unit) or not ctx.temporaryUnit and NPC.IsNeutral(unit) and NPC.IsCreep(unit) and not NPC.IsAncient(unit)
				and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit))
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < 950 and not ctx.unsafePosition(Entity.GetAbsOrigin(unit)) then
			creeps[#creeps + 1] = unit
		end
	end
	if #creeps == 0 then return false end
	if midas(ctx, api, false) then return true end
	local mana = NPC.GetMana(ctx.hero)
	local reserve = NPC.GetMaxMana(ctx.hero) * (ctx.temporaryUnit and 0.1 or 0.4)
	local shield = common.ability(ctx, api, "item_mjollnir")
	if shield and #creeps >= 3 and NPC.IsAttacking(ctx.hero) and Hero.GetRecentDamage(ctx.hero) > 0
		and mana - Ability.GetManaCost(shield) >= reserve and not NPC.HasModifier(ctx.hero, "modifier_item_mjollnir_static") then
		return common.cast(ctx, api, shield, "target", ctx.hero)
	end
	local field = common.ability(ctx, api, "arc_warden_magnetic_field")
	if field and #creeps >= 3 and NPC.IsAttacking(ctx.hero) and ctx.now >= (ctx.heroState.fieldUntil or 0)
		and mana - Ability.GetManaCost(field) >= reserve then
		ctx.heroState.fieldUntil = ctx.now + common.value(field, "duration", 5)
		return api.cast(ctx, field, "point", nil, ctx.position)
	end
	local spark = common.ability(ctx, api, "arc_warden_spark_wraith")
	if spark and ctx.now >= (ctx.heroState.nextSpark or 0) and mana - Ability.GetManaCost(spark) >= reserve then
		local target, health = nil, 0
		for _, creep in ipairs(creeps) do
			local value = Entity.GetHealth(creep)
			if value > math.max(health, NPC.GetTrueDamage(ctx.hero) * 2) then target, health = creep, value end
		end
		if target then
			local delay = common.value(spark, "base_activation_delay", 1.5) + Ability.GetCastPoint(spark)
			local point = ctx.predict(target, delay)
			if ctx.distance(ctx.position, point) < Ability.GetCastRange(spark) then
				ctx.heroState.nextSpark = ctx.now + (ctx.temporaryUnit and 4.5 or 8)
				return api.cast(ctx, spark, "point", nil, point)
			end
		end
	end
	return false
end

local function pendingSparks(target)
	local count = 0
	for _, entry in ipairs(arc.pending) do if entry.target == target then count = count + 1 end end
	return count
end

local function sparkAt(ctx, api, enemy)
	local spark = common.ability(ctx, api, "arc_warden_spark_wraith")
	if not spark or ctx.now < (ctx.heroState.nextSpark or 0) then return false end
	local damage = common.value(spark, "spark_damage_base", 100) * NPC.GetMagicalArmorDamageMultiplier(enemy)
	enemy = focus.split(ctx, enemy, ctx.position, Ability.GetCastRange(spark), pendingSparks(enemy) * damage) or enemy
	local delay = common.value(spark, "base_activation_delay", 1.5) + Ability.GetCastPoint(spark)
	local best, bestScore = arc.sparkPoint(ctx, enemy, delay, common.value(spark, "radius", 375), Ability.GetCastRange(spark))
	if best and bestScore > 0.42 and api.cast(ctx, spark, "point", nil, best) then
		ctx.heroState.nextSpark = ctx.now + (ctx.clock < 600 and not ctx.temporaryUnit and 12 or delay + 0.5)
		local kinds = {}
		for _, scenario in ipairs(ctx.heroState.sparkAim and ctx.heroState.sparkAim.scenarios or {}) do
			kinds[#kinds + 1] = string.format("%s=%.2f", scenario.kind, scenario.weight)
		end
		arc.pending[#arc.pending + 1] = {target = enemy, point = best, expires = ctx.now + delay + 3.5, score = bestScore,
			by = ctx.temporaryUnit and "double" or "hero", kinds = table.concat(kinds, " "), cast = ctx.now}
		return true
	end
	return false
end

local function sparked(unit)
	if not NPC.GetModifiers or not Modifier.GetName then return false end
	for _, modifier in ipairs(NPC.GetModifiers(unit) or {}) do
		local name = Modifier.GetName(modifier)
		if name and name:find("spark_wraith", 1, true) then return true end
	end
	return false
end

function arc.trackSparks(ctx)
	for index = #arc.pending, 1, -1 do
		local entry = arc.pending[index]
		local alive = Entity.IsEntity(entry.target) and Entity.IsAlive(entry.target)
		local hit = alive and ctx.now >= entry.cast + 1.6 and sparked(entry.target)
		if hit or not alive or ctx.now > entry.expires then
			local gap = alive and ctx.distance(Entity.GetAbsOrigin(entry.target), entry.point) or -1
			arc.notes[#arc.notes + 1] = string.format("%s by=%s target=%s score=%.2f after=%.1fs gap=%.0f %s",
				hit and "hit" or alive and "miss" or "target died", entry.by, NPC.GetUnitName(entry.target), entry.score,
				ctx.now - entry.cast, gap, entry.kinds)
			table.remove(arc.pending, index)
		end
	end
	while #arc.notes > 12 do table.remove(arc.notes, 1) end
end

local function control(ctx, api, retreat)
	if api.busy(ctx) then return true end
	local enemy = common.enemy(ctx, 1800)
	if enemy and not NPC.IsHero(enemy) then enemy = nil end
	local following = not ctx.parent and not retreat and ctx.intent and ctx.intent.kind == "hero" and ctx.intent.followAttack
	if enemy and not (retreat and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 700) then
		local flux = common.ability(ctx, api, "arc_warden_flux")
		local fluxTarget = enemy
		if flux and ownFlux(ctx, enemy) then fluxTarget = focus.secondary(ctx, enemy, ctx.position, Ability.GetCastRange(flux)) end
		if flux and fluxTarget and not ownFlux(ctx, fluxTarget) and common.cast(ctx, api, flux, "target", fluxTarget) then return true end
	end
	if following then
		local chased = common.visible(ctx.intent.target) and NPC.IsHero(ctx.intent.target) and ctx.intent.target or enemy
		return chased ~= nil and sparkAt(ctx, api, chased)
	end
	local structure = common.visible(ctx.target) and NPC.IsStructure(ctx.target)
	if common.items(ctx, api, enemy, retreat) then return true end
	local field = common.ability(ctx, api, "arc_warden_magnetic_field")
	if field and ctx.now >= (ctx.heroState.fieldUntil or 0) then
		local reach = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 60
		local hitting = enemy and ctx.attackTarget == enemy and NPC.IsAttacking(ctx.hero)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= reach
		local pressed = enemy and ctx.laneThreat and ctx.laneThreat.attacked and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 700
		local sieging = not enemy and NPC.IsAttacking(ctx.hero) and (structure or ctx.intent and ctx.intent.kind == "structure")
		if hitting or pressed or sieging then
			local position = ctx.toward(ctx.position, ctx.home, 65)
			ctx.heroState.fieldUntil = ctx.now + common.value(field, "duration", 5)
			return api.cast(ctx, field, "point", nil, position)
		end
	end
	if not enemy then return farm(ctx, api) end
	if retreat and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 700 then return false end
	return sparkAt(ctx, api, enemy)
end

function arc.update(ctx, api, retreat)
	arc.trackSparks(ctx)
	local enemy = common.enemy(ctx, 1200)
	if enemy and not NPC.IsHero(enemy) then enemy = nil end
	local defending = enemy and ctx.laneThreat and ctx.laneThreat.attacked
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 900
	local session = ctx.fightSession and common.visible(ctx.fightSession.target) and ctx.fightSession.target
	local fighting = enemy and (ctx.intent and ctx.intent.kind == "hero" or ctx.attackTarget == enemy and NPC.IsAttacking(ctx.hero)
		or session and ctx.distance(ctx.position, Entity.GetAbsOrigin(session)) < 1000 or defending)
	local danger = retreat or ctx.nearEnemies > 0 or Hero.GetRecentDamage(ctx.hero) > 0 or ctx.teamTask
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		if ctx.distance(ctx.position, arrival.position) < 3000 then danger = true end
	end
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time < 6 and ctx.distance(ctx.position, entry.position) < 2500 then danger = true end
	end
	if danger then ctx.heroState.quietSince = ctx.now
	else ctx.heroState.quietSince = ctx.heroState.quietSince or ctx.now end
	local active = false
	for _, unit in ipairs(ctx.summons) do if common.visible(unit) and isDouble(ctx, unit) then active = true; break end end
	local double = not active and (not retreat or fighting) and common.ability(ctx, api, "arc_warden_tempest_double")
	if double and (fighting or ctx.health > 0.55) and not api.busy(ctx) then
		local farming = false
		if not danger and ctx.clock > 600 and ctx.health > 0.75 and ctx.now - ctx.heroState.quietSince >= 10 then
			local laneCount = 0
			for _, creep in ipairs(ctx.creeps) do
				if common.visible(creep) and NPC.IsLaneCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 1000 then laneCount = laneCount + 1 end
			end
			local working = NPC.IsAttacking(ctx.hero) and ctx.attackTarget and not NPC.IsHero(ctx.attackTarget)
			local remote = tasks.choose(ctx, api, common.value(double, "duration", 18))
			farming = working and (laneCount >= 3 or remote ~= nil)
		end
		if fighting or farming then
			local position = ctx.toward(ctx.position, ctx.home, 180)
			if not ctx.unsafePosition(position) then
				ctx.mode = fighting and "Summon Double for committed fight" or "Summon Double for quiet lane pressure"
				if api.cast(ctx, double, "point", nil, position) then
					if fighting and not retreat then intent.follow(ctx, enemy) end
					return true
				end
			end
		end
	end
	return control(ctx, api, retreat)
end

function arc.sparkScenarios(ctx, enemy, delay)
	local now = Entity.GetAbsOrigin(enemy)
	local predicted = ctx.predict(enemy, delay)
	local span = math.max(0.3, delay)
	local vx, vy = (predicted.x - now.x) / span, (predicted.y - now.y) / span
	local moving = math.sqrt(vx * vx + vy * vy)
	local record = ctx.history and ctx.history[Entity.GetIndex(enemy)]
	local steady = record and record.steady or 0
	local speed = math.max(200, NPC.GetMoveSpeed(enemy))
	local continueWeight = moving > 60 and 0.3 + 0.5 * math.min(1, steady / 1.5) or 0
	local stayWeight = moving > 60 and (1 - continueWeight) * 0.55 or 0.7
	if NPC.IsAttacking(enemy) then stayWeight = stayWeight + 0.2 end
	local fleeWeight = math.max(0.1, 1 - continueWeight - stayWeight)
	local chased = ctx.intent and ctx.intent.kind == "hero" and ctx.intent.target == enemy
	if chased or Entity.GetHealth(enemy) < Entity.GetMaxHealth(enemy) * 0.4 then fleeWeight = fleeWeight + 0.25 end
	local list = {{kind = "stay", weight = stayWeight, vx = 0, vy = 0}}
	if continueWeight > 0 then list[#list + 1] = {kind = "continue", weight = continueWeight, vx = vx, vy = vy} end
	local home = ctx.enemyHome
	if home then
		local dx, dy = home.x - now.x, home.y - now.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		list[#list + 1] = {kind = "flee", weight = fleeWeight, vx = dx / length * speed, vy = dy / length * speed}
	end
	list[#list + 1] = {kind = "dodge", weight = 0.25, dodge = true, vx = 0, vy = 0, react = 0.8, pace = speed}
	local total = 0
	for _, scenario in ipairs(list) do total = total + scenario.weight end
	for _, scenario in ipairs(list) do
		scenario.weight = scenario.weight / total
		scenario.speed = scenario.dodge and scenario.pace or math.sqrt(scenario.vx * scenario.vx + scenario.vy * scenario.vy)
	end
	return list, now
end

function arc.sparkCoverage(ctx, point, scenarios, origin, delay, radius, blockers)
	local reach = radius * 0.85
	local score = 0
	for _, scenario in ipairs(scenarios) do
		local quality = 0
		local ax, ay = scenario.vx, scenario.vy
		if scenario.dodge then
			local dx, dy = origin.x - point.x, origin.y - point.y
			local length = math.sqrt(dx * dx + dy * dy)
			if length < 1 then dx, dy, length = 1, 0, 1 end
			ax, ay = dx / length * scenario.pace, dy / length * scenario.pace
		end
		for step = 0, 8 do
			local t = delay + step * 0.2
			local moved = scenario.dodge and math.max(0, t - scenario.react) or t
			local x, y = origin.x + ax * moved, origin.y + ay * moved
			local dx, dy = x - point.x, y - point.y
			local gap = math.sqrt(dx * dx + dy * dy)
			local blocked = false
			for _, blocker in ipairs(blockers) do
				local distance = ctx.distance(blocker, point)
				if distance <= radius and distance < gap + 50 then blocked = true; break end
			end
			if blocked then break end
			if gap <= reach then
				local chase = gap / math.max(150, 550 - scenario.speed)
				quality = math.max(0, 1 - 0.08 * step - 0.1 * chase)
				break
			end
		end
		score = score + scenario.weight * quality
	end
	return score
end

function arc.sparkPoint(ctx, enemy, delay, radius, castRange)
	local now = Entity.GetAbsOrigin(enemy)
	local control = awareness.control(ctx, enemy)
	local held = 0
	for _, state in ipairs({Enum.ModifierState.MODIFIER_STATE_STUNNED, Enum.ModifierState.MODIFIER_STATE_ROOTED}) do
		if state then held = math.max(held, control[state] or 0) end
	end
	if held >= delay * 0.85 and ctx.distance(ctx.position, now) <= castRange and GridNav.IsTraversable(now) then return now, 1 end
	local scenarios, origin = arc.sparkScenarios(ctx, enemy, delay)
	local blockers = {}
	for _, creep in ipairs(ctx.creeps or {}) do
		if common.visible(creep) and not Entity.IsSameTeam(ctx.hero, creep) and not NPC.IsHero(creep)
			and ctx.distance(Entity.GetAbsOrigin(creep), now) < 1600 then blockers[#blockers + 1] = Entity.GetAbsOrigin(creep) end
	end
	local candidates = {now}
	for _, scenario in ipairs(scenarios) do
		for _, t in ipairs({delay * 0.5, delay, delay + 0.4, delay + 0.8}) do
			candidates[#candidates + 1] = Vector(origin.x + scenario.vx * t, origin.y + scenario.vy * t, origin.z)
		end
	end
	local count = #candidates
	for i = 2, count do
		for j = i + 1, count do
			local a, b = candidates[i], candidates[j]
			candidates[#candidates + 1] = Vector((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, origin.z)
		end
		local a = candidates[i]
		candidates[#candidates + 1] = Vector((a.x + now.x) * 0.5, (a.y + now.y) * 0.5, origin.z)
	end
	local best, bestScore = nil, -math.huge
	for _, candidate in ipairs(candidates) do
		if GridNav.IsTraversable(candidate) and ctx.distance(ctx.position, candidate) <= castRange then
			local score = arc.sparkCoverage(ctx, candidate, scenarios, origin, delay, radius, blockers)
			if score > bestScore + 0.005 then best, bestScore = candidate, score end
		end
	end
	if best then ctx.heroState.sparkAim = {score = bestScore, scenarios = scenarios} end
	return best, bestScore
end

function arc.doubleReady(ctx)
	for _, unit in ipairs(ctx.summons or {}) do
		if common.visible(unit) and isDouble(ctx, unit) then return unit, 0 end
	end
	local double = NPC.GetAbility(ctx.hero, "arc_warden_tempest_double")
	if double and Ability.GetLevel(double) > 0 and Ability.IsReady(double)
		and Ability.IsCastable(double, NPC.GetMana(ctx.hero)) then return nil, 0.6 end
	return nil, nil
end

function arc.attackDamage(ctx, target, seconds)
	local unit, delay = arc.doubleReady(ctx)
	if not delay then return 0, 0 end
	if unit and ctx.distance(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target)) > 1400 then return 0, 0 end
	local active = math.max(0, seconds - delay)
	if active <= 0 then return 0, 0 end
	local hit = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
	local damage = hit / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false)) * active
	local magic = NPC.GetMagicalArmorDamageMultiplier(target)
	local flux = NPC.GetAbility(ctx.hero, "arc_warden_flux")
	if flux and Ability.GetLevel(flux) > 0 then
		damage = damage + common.value(flux, "damage_per_second", 0) * math.min(active, common.value(flux, "duration", 6)) * magic
	end
	local spark = NPC.GetAbility(ctx.hero, "arc_warden_spark_wraith")
	if spark and Ability.GetLevel(spark) > 0 and active >= common.value(spark, "activation_delay", 2) then
		damage = damage + common.value(spark, "spark_damage", 0) * magic * 0.6
	end
	return damage, 0
end

function arc.runeReach(ctx)
	if not ctx.settings.spells or ctx.retreating or ctx.intent then return 0 end
	local field = NPC.GetAbility(ctx.hero, "arc_warden_magnetic_field")
	if not field or Ability.GetLevel(field) == 0 or Ability.GetCooldown(field) > 0
		or NPC.GetMana(ctx.hero) - Ability.GetManaCost(field) < NPC.GetMaxMana(ctx.hero) * 0.35 then return 0 end
	return Ability.GetCastRange(field) + Ability.GetLevelSpecialValueFor(field, "rune_pull_radius") - 50
end

function arc.rune(ctx, api, task, enemyETA, remaining)
	if ctx.parent or ctx.retreating or ctx.intent or api.busy(ctx) or not ctx.settings.spells then return false end
	local farm = ctx.farmCandidate
	if farm and farm.inRange and farm.start <= ctx.now + 0.35 then return false end
	local previous = ctx.heroState.runeField
	if previous and previous.cycle == task.cycle then
		if ctx.now < previous.expires then task.remoteUntil = previous.expires end
		return false
	end
	local field = NPC.GetAbility(ctx.hero, "arc_warden_magnetic_field")
	if field and api.ready(ctx, field) and (ctx.abilityAttempts.arc_warden_magnetic_field or 0) <= ctx.now
		and NPC.GetMana(ctx.hero) - Ability.GetManaCost(field) >= NPC.GetMaxMana(ctx.hero) * 0.35 then
		local duration = Ability.GetLevelSpecialValueFor(field, "duration")
		local pull = Ability.GetLevelSpecialValueFor(field, "rune_pull_radius")
		local activation = Ability.GetLevelSpecialValueFor(field, "radius") + Ability.GetLevelSpecialValueFor(field, "rune_activate_radius_buffer")
		local castRange = Ability.GetCastRange(field)
		if pull > 0 and remaining < duration - 1.4 then
			local spots = {task.position}
			if remaining > 0 then
				for _, point in pairs(ctx.runeSpots or {}) do
					if ctx.distance(point, task.position) > 400 then spots[#spots + 1] = point end
				end
			end
			local points = {ctx.position, task.position, ctx.toward(ctx.position, task.position, castRange - 25)}
			if #spots == 2 then
				local middle = Vector((spots[1].x + spots[2].x) * 0.5, (spots[1].y + spots[2].y) * 0.5, ctx.position.z)
				points[#points + 1] = ctx.toward(ctx.position, middle, castRange - 25)
			end
			local best, bestScore
			for _, point in ipairs(points) do
				if ctx.distance(ctx.position, point) <= castRange and not ctx.unsafePosition(point) then
					local covered, farthest = 0, 0
					for _, spot in ipairs(spots) do
						local distance = ctx.distance(point, spot)
						if distance < pull - 40 then covered, farthest = covered + 1, math.max(farthest, distance) end
					end
					local primary = ctx.distance(point, task.position)
					if primary < pull - 40 and (enemyETA > 0.6 or primary <= activation) then
						local score = covered * 1000 - farthest * 0.5 - ctx.distance(ctx.position, point) * 0.1
						if not bestScore or score > bestScore then best, bestScore = point, score end
					end
				end
			end
			if best then
				ctx.defensiveCast = true
				local cast = api.cast(ctx, field, "point", nil, best)
				ctx.defensiveCast = nil
				if cast then
					ctx.heroState.fieldUntil = ctx.now + duration
					ctx.heroState.runeField = {cycle = task.cycle, expires = ctx.now + duration, position = best}
					task.remoteUntil, task.expires = ctx.now + duration, math.max(task.expires, ctx.now + duration + 2)
					ctx.mode = "Magnetic Field rune control"
					return true
				end
			end
		end
	end
	local spark = NPC.GetAbility(ctx.hero, "arc_warden_spark_wraith")
	if spark and enemyETA < math.huge and api.ready(ctx, spark) and (ctx.abilityAttempts.arc_warden_spark_wraith or 0) <= ctx.now
		and ctx.now >= (ctx.heroState.nextSpark or 0) and ctx.distance(ctx.position, task.position) <= Ability.GetCastRange(spark)
		and NPC.GetMana(ctx.hero) - Ability.GetManaCost(spark) >= NPC.GetMaxMana(ctx.hero) * 0.45 then
		local delay = Ability.GetLevelSpecialValueFor(spark, "base_activation_delay") + Ability.GetCastPoint(spark)
		if enemyETA >= delay and enemyETA < delay + 3 and not ctx.unsafePosition(task.position) then
			for _, creep in ipairs(ctx.creeps) do
				if common.visible(creep) and not Entity.IsSameTeam(ctx.hero, creep)
					and ctx.distance(Entity.GetAbsOrigin(creep), task.position) < Ability.GetLevelSpecialValueFor(spark, "radius") then return false end
			end
			ctx.defensiveCast = true
			local cast = api.cast(ctx, spark, "point", nil, task.position)
			ctx.defensiveCast = nil
			if cast then ctx.heroState.nextSpark = ctx.now + 8; ctx.mode = "Trap enemy rune approach"; return true end
		end
	end
	return false
end

function arc.unit(ctx, api, unit)
	if not isDouble(ctx, unit) then return false end
	local id = Entity.GetIndex(unit)
	if NPC.IsChannellingAbility(unit) or ctx.now < (ctx.heroState.unitBusy[id] or 0) then return true end
	local actor = common.actor(ctx, unit)
	actor.temporaryUnit = true
	actor.retreating, actor.farmCandidate, actor.teamTask, actor.runeTask = false, false, false, false
	actor.nearEnemies, actor.nearAllies, actor.creeps = 0, 1, {}
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and ctx.distance(actor.position, Entity.GetAbsOrigin(enemy)) < 1400 then actor.nearEnemies = actor.nearEnemies + 1 end
	end
	for _, ally in ipairs(ctx.allies) do
		if ally ~= unit and common.visible(ally) and ctx.distance(actor.position, Entity.GetAbsOrigin(ally)) < 1100 then actor.nearAllies = actor.nearAllies + 1 end
	end
	for _, creep in ipairs(ctx.worldNPCs) do
		if common.visible(creep) and NPC.IsLaneCreep(creep) and ctx.distance(actor.position, Entity.GetAbsOrigin(creep)) < 1800 then actor.creeps[#actor.creeps + 1] = creep end
	end
	actor.unsafePosition = function(point)
		for _, tower in ipairs(ctx.structures) do
			if common.visible(tower) and NPC.IsTower(tower) and not Entity.IsSameTeam(unit, tower)
				and ctx.distance(point, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 160
				and not towerSafety.cover(actor, tower) then return true end
		end
		return false
	end
	local function firingSafe(enemy)
		local position = Entity.GetAbsOrigin(enemy)
		local range = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit)
		local firing = ctx.distance(actor.position, position) <= range and actor.position
			or ctx.toward(position, actor.position, math.max(50, range - 35))
		return not actor.unsafePosition(firing)
	end
	local retained = intent.target(actor)
	if retained and (ctx.distance(actor.position, Entity.GetAbsOrigin(retained)) > 1400 or not firingSafe(retained)) then
		actor.intent, retained = false, nil
	end
	local shared = ctx.intent and ctx.intent.kind == "hero" and ctx.intent.target
		or ctx.fightSession and ctx.fightSession.target or ctx.teamTask and ctx.teamTask.fighting and ctx.teamTask.target
	local diving = ctx.dive and ctx.dive.target == shared or actor.health > 0.45 and ctx.distance(ctx.position, Entity.GetAbsOrigin(shared or ctx.hero)) < 1200
	if common.visible(shared) and ctx.distance(actor.position, Entity.GetAbsOrigin(shared)) < 2500 and (firingSafe(shared) or diving) then
		retained = shared
		if focus.covered(ctx, shared) then
			local other = focus.secondary(ctx, shared, actor.position, 1200)
			if other and firingSafe(other) then retained = other; actor.heroState.splitFrom = shared end
		end
	end
	actor.teamFight = (ctx.fightSession or ctx.helpRotation or ctx.teamTask and ctx.teamTask.fighting) and true or false
	if not retained then
		local score
		for _, enemy in ipairs(ctx.enemies) do
			if common.visible(enemy) and firingSafe(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
				and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then
				local distance = ctx.distance(actor.position, Entity.GetAbsOrigin(enemy))
				local value = distance + Entity.GetHealth(enemy) * 0.1
				if distance < 1400 and (not score or value < score) then retained, score = enemy, value end
			end
		end
	end
	actor.target = retained or common.unitTarget(actor, unit) or false
	if common.visible(actor.target) and NPC.IsHero(actor.target) and (firingSafe(actor.target) or actor.target == shared and diving) then
		intent.begin(actor, actor.target, "hero", false)
		actor.heroState.travelReason = "Fight " .. NPC.GetUnitName(actor.target)
		actor.heroState.farmTask = nil
	end
	if actor.target and NPC.IsNeutral(actor.target) then
		actor.target = false
		local nearest = 1100
		for _, creep in ipairs(actor.creeps) do
			local distance = ctx.distance(actor.position, Entity.GetAbsOrigin(creep))
			if not Entity.IsSameTeam(unit, creep) and distance < nearest and not actor.unsafePosition(Entity.GetAbsOrigin(creep)) then
				actor.target, nearest = creep, distance
			end
		end
	end
	local position = actor.position
	if api.busy(actor) then return true end
	if actor.health < 0.3 or actor.nearEnemies > actor.nearAllies then
		actor.retreating, actor.heroState.farmTask, actor.intent = true, nil, false
		actor.heroState.travelReason = actor.health < 0.3 and "Withdraw: Double low health" or "Withdraw: Double locally outnumbered"
		if control(actor, api, true) then return true end
		return actor.move(ctx.toward(position, ctx.home, 700))
	end
	if actor.intent and actor.intent.kind == "hero" and not common.visible(actor.intent.target) then
		local enemy = actor.intent.target
		local point, confidence = awareness.fogPosition(actor, enemy)
		if point and confidence >= 0.35 and ctx.distance(actor.position, point) > 90 and ctx.distance(actor.position, point) < 1200
			and not actor.unsafePosition(point) then
			actor.heroState.travelReason = "Pursue briefly lost combat target"
			return actor.move(point)
		end
		actor.intent = false
	end
	local modifier = NPC.GetModifier(unit, "modifier_kill")
	local double = NPC.GetAbility(ctx.hero, "arc_warden_tempest_double")
	actor.heroState.expires = actor.heroState.expires or ctx.now + (double and common.value(double, "duration", 18) or 18)
	local remaining = modifier and common.remaining(modifier, ctx.now) or math.max(0, actor.heroState.expires - ctx.now)
	actor.heroState.remaining = remaining
	if not actor.target or not NPC.IsHero(actor.target) then
		if midas(actor, api, true) then return true end
	end
	if (not actor.target or not NPC.IsHero(actor.target)) and actor.teamFight then
		local goal = ctx.toward(ctx.position, actor.position, 250)
		actor.heroState.travelReason = "Stay with the hero during a team fight"
		if ctx.distance(actor.position, goal) > 200 then return actor.move(goal) end
	elseif not actor.target or not NPC.IsHero(actor.target) then
		if (actor.heroState.farmTask or not actor.target or ctx.distance(actor.position, ctx.position) < 1200)
			and tasks.travel(actor, api, remaining) then return true end
	end
	if actor.target and (actor.unitFollowAttack or not ctx.heroState.unitOrders[id] and not NPC.IsAttacking(unit)) then
		actor.unitFollowAttack = false
		actor.attackTarget = actor.target
		return common.unitAttack(ctx, unit, actor.target)
	end
	if control(actor, api, actor.health < 0.3) then return true end
	if actor.target then return common.unitAttack(ctx, unit, actor.target) end
	for _, structure in ipairs(ctx.structures) do
		if common.visible(structure) and not Entity.IsSameTeam(unit, structure) and ctx.distance(position, Entity.GetAbsOrigin(structure)) < 1100
			and not actor.unsafePosition(Entity.GetAbsOrigin(structure)) then return common.unitAttack(ctx, unit, structure) end
	end
	local destination, score
	for _, front in ipairs(tasks.fronts(actor)) do
		local creep = front.target
		local point = ctx.toward(Entity.GetAbsOrigin(creep), ctx.home, 180)
		local distance = ctx.distance(position, point)
		if distance < 3000 and not actor.unsafePosition(point) then
			local value = distance + ctx.distance(point, ctx.enemyHome) * 0.1
			if not score or value < score then destination, score = point, value end
		end
	end
	if destination then return actor.move(destination) end
	actor.stop()
	return true
end

return arc
