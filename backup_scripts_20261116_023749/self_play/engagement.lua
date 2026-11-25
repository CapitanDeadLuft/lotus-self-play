local engagement = {}
local awareness = require("self_play.awareness")
local fightSim = require("self_play.fight_sim")
local brain = require("self_play.brain")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function strength(unit)
	local health = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))
	return NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false)) * (0.4 + health * 0.6)
end

function engagement.attackPosition(ctx, target)
	local position = Entity.GetAbsOrigin(target)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local travel = math.max(0, ctx.distance(ctx.position, position) - range + 20)
	return ctx.toward(ctx.position, position, travel)
end

local function supporters(ctx, target)
	local result, seen = {}, {}
	local position = Entity.GetAbsOrigin(target)
	local root = ctx.parent or ctx
	local state = root.heroState
	local recent = ctx.allyFights and ctx.allyFights[Entity.GetIndex(target)]
	for group, units in ipairs({ctx.allies, ctx.summons or {}}) do
		for _, ally in ipairs(units) do
			if ally ~= ctx.hero and visible(ally) and Entity.IsSameTeam(ctx.hero, ally) and not seen[ally]
				and (group == 2 or not NPC.IsIllusion(ally)) and not NPC.IsChannellingAbility(ally)
				and not NPC.HasModifier(ally, "modifier_teleporting")
				and not NPC.HasState(ally, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then
				local id = Entity.GetIndex(ally)
				local order = state and state.unitOrders and state.unitOrders[id]
				local actor = state and state.actors and state.actors[id]
				local ordered = order and order.target == target and ctx.now - order.time < 1.2
				local attacking = NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 25,
					NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 150) == target
				local hit = recent and recent.ally == ally and recent.outgoing and ctx.now - recent.time < 1.2
				local distance = ctx.distance(Entity.GetAbsOrigin(ally), position)
				local reach = NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally)
				local approach = math.max(0, distance - reach) / math.max(100, NPC.GetMoveSpeed(ally))
				if (attacking or ordered or hit) and approach <= (ordered and 1.2 or 0.7)
					and not (actor and actor.retreating) then
					seen[ally] = true
					local control = awareness.control(ctx, ally)
					local disabled = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0,
						control[Enum.ModifierState.MODIFIER_STATE_DISARMED] or 0)
					local unavailable = (NPC.IsStunned(ally) or NPC.HasState(ally, Enum.ModifierState.MODIFIER_STATE_DISARMED)) and disabled == 0
					local point = NPC.GetAttackAnimPoint(ally)
					local modifier = NPC.GetModifier(ally, "modifier_kill")
					local lifetime = modifier and math.max(0, Modifier.GetDieTime(modifier) - ctx.now) or math.huge
					if not unavailable and point and lifetime > disabled then
						local flight = 0
						if NPC.IsRanged(ally) then
							local speed = NPC.GetAttackProjectileSpeed(ally)
							if speed and speed > 0 then flight = math.min(distance, reach) / speed end
						end
						local burst, casting, burstAt = 0, 0, math.min(2, lifetime)
						if group == 2 and actor and actor.hero == ally and ctx.settings.spells and NPC.IsHero(ally) then
							burst, casting = awareness.burst(ctx, ally, target, distance, burstAt)
						end
						local first = math.max(approach, disabled) + NPC.GetTimeToFace(ally, target)
							+ point / math.max(0.2, NPC.GetAttackSpeed(ally)) + flight + casting
						if first < lifetime or burst > 0 then
							result[#result + 1] = {first = first, lifetime = lifetime, burst = burst, burstAt = burstAt,
								period = math.max(0.3, NPC.GetSecondsPerAttack(ally, false)),
								damage = NPC.GetTrueDamage(ally) * NPC.GetArmorDamageMultiplier(target) * 0.7}
						end
					end
				end
			end
		end
	end
	return result
end

local function supportDamage(units, elapsed)
	local damage = 0
	for _, unit in ipairs(units) do
		local duration = math.min(elapsed, unit.lifetime)
		if duration >= unit.first then damage = damage + unit.damage * (1 + math.floor((duration - unit.first) / unit.period)) end
		if elapsed >= unit.burstAt then damage = damage + unit.burst end
	end
	return damage
end

function engagement.assess(ctx, target)
	if not visible(target) or not NPC.IsHero(target) or Entity.IsSameTeam(ctx.hero, target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) or NPC.IsStunned(ctx.hero) then return nil end
	local position = Entity.GetAbsOrigin(target)
	local distance = ctx.distance(ctx.position, position)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local travel = math.max(0, distance - range + 20)
	local approach = travel / math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local point = ctx.toward(ctx.position, position, travel)
	local committed = ctx.intent and ctx.intent.kind == "hero" and ctx.intent.target == target
	if distance > (committed and 1400 or 1100) or approach > 3.5 or ctx.unsafePosition(point)
		or not GridNav.IsTraversable(point) then return nil end
	local damage = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
	local dps = damage / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false))
	local support = supporters(ctx, target)
	local burst, casting, selfCost = awareness.burst(ctx, ctx.hero, target, distance, 2)
	local spellCost = selfCost
	local barriers = NPC.GetBarriers(target)
	local barrierHP = barriers and (barriers.all.current + barriers.physical.current + barriers.magic.current) or 0
	local killTime = approach + casting + math.max(0.25, (Entity.GetHealth(target) + barrierHP - burst) / math.max(1, dps - NPC.GetHealthRegen(target)))
	if #support > 0 or ctx.heroModule and ctx.heroModule.attackDamage then
		killTime = math.huge
		for step = 1, 32 do
			local elapsed = step * 0.25
			local seconds = math.max(0, elapsed - approach - casting)
			local extra, cost = 0, 0
			if ctx.heroModule and ctx.heroModule.attackDamage then extra, cost = ctx.heroModule.attackDamage(ctx, target, seconds) end
			if seconds > 0 and burst + extra + dps * seconds + supportDamage(support, elapsed) >= Entity.GetHealth(target) + barrierHP + NPC.GetHealthRegen(target) * elapsed then
				killTime, selfCost = elapsed, selfCost + cost
				break
			end
		end
		if killTime == math.huge then
			local seconds = math.max(0.25, 8 - approach - casting)
			local extra = ctx.heroModule and ctx.heroModule.attackDamage and (ctx.heroModule.attackDamage(ctx, target, seconds)) or 0
			local rate = (extra + dps * seconds + supportDamage(support, 8)) / seconds - NPC.GetHealthRegen(target)
			if rate > 1 then killTime = approach + casting + math.max(0.25, (Entity.GetHealth(target) + barrierHP - burst) / rate) end
		end
	end
	local horizon = math.min(8.5, killTime + 0.4)
	local creepDps = engagement.creepAggro(ctx, point)
	local incoming = math.max((awareness.damage(ctx, ctx.position, horizon)), (awareness.damage(ctx, point, horizon)))
		+ creepDps * math.min(horizon, 3)
	local future = awareness.forecast(ctx, point)
	local projectiles = 0
	for _, entry in pairs(ctx.projectiles or {}) do
		if entry.target == ctx.hero and entry.impact >= ctx.now and entry.impact <= ctx.now + horizon then projectiles = projectiles + entry.damage end
	end
	incoming = incoming + future + projectiles
	local hp, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local regen = NPC.GetHealthRegen(ctx.hero)
	local armlet = NPC.GetItem(ctx.hero, "item_armlet", true)
	if armlet and Item.IsItemEnabled(armlet) and Ability.GetToggleState(armlet) then
		regen = regen - tonumber(itemKV.item_armlet.AbilityValues.unholy_health_drain_per_second)
	end
	if NPC.GetModifierProperty(ctx.hero, Enum.ModifierFunction.MODIFIER_PROPERTY_DISABLE_HEALING) > 0 then regen = 0 end
	local healing = math.min(math.max(0, regen), maximum * 0.08) * math.max(0, horizon - 0.4)
	local immediate = awareness.damage(ctx, ctx.position, 0.65) + projectiles + future
	local ownBarriers = NPC.GetBarriers(ctx.hero)
	local shield = ownBarriers and ownBarriers.all.current or 0
	local remaining = hp + healing + shield - incoming - selfCost
	local safe = killTime <= 8 and immediate < (hp + shield) * 0.6 and remaining > math.max(maximum * 0.15, hp * 0.3)
	local exchange = 2.5
	local seconds = math.max(0, exchange - approach - casting)
	local extra, cost = 0, 0
	if ctx.heroModule and ctx.heroModule.attackDamage then extra, cost = ctx.heroModule.attackDamage(ctx, target, seconds) end
	local assisted = supportDamage(support, exchange)
	local dealt = math.max(0, burst + dps * seconds + extra + assisted - NPC.GetHealthRegen(target) * exchange - barrierHP)
	local received = math.max((awareness.damage(ctx, ctx.position, exchange)), (awareness.damage(ctx, point, exchange)))
		+ future + projectiles + cost + spellCost + creepDps * exchange
	local pursuer = NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 25,
		NPC.GetAttackRange(target) + NPC.GetAttackRangeBonus(target) + 150) == ctx.hero
		or ctx.heroHarass and ctx.heroHarass.source == target and ctx.now - ctx.heroHarass.time < 2
	local returnFire = pursuer and approach < 0.9 and future == 0 and hp > maximum * 0.4
		and received < (hp + shield) * 0.3 and dealt / math.max(1, Entity.GetHealth(target)) >= received / math.max(1, hp + shield)
	local trade = approach < 0.2 and hp > maximum * 0.65 and future == 0 and received < hp * 0.18
		and dealt / math.max(1, Entity.GetHealth(target)) > received / math.max(1, hp) * 1.2
	local assist = assisted > 0 and hp > maximum * 0.55 and future == 0 and received < hp * 0.22 and remaining > maximum * 0.3
	local follow = false
	if committed and ctx.intent.followUntil and ctx.now < ctx.intent.followUntil and hp > maximum * 0.55
		and future == 0 and received < hp * 0.22 and immediate < hp * 0.3 then
		local motion = ctx.history and ctx.history[Entity.GetIndex(target)]
		local away = motion and ((position.x - ctx.position.x) * motion.vx + (position.y - ctx.position.y) * motion.vy) / math.max(1, distance) or 0
		local closing = NPC.GetMoveSpeed(ctx.hero) - math.max(0, away)
		follow = travel < 100 or closing > 50 and travel / closing < 2
	end
	local outcome = fightSim.evaluate(ctx, position, {target = target, selfDelay = approach})
	local teamWin = false
	if outcome then
		local killFirst = outcome.targetDead and (not outcome.selfDead
			or (outcome.selfDeathTime or 0) > (outcome.targetDeathTime or math.huge) + 1.5)
		local survives = not outcome.selfDead and (outcome.selfFraction or 0) > 0.18
		teamWin = outcome.favorable and killFirst and (outcome.targetDeathTime or math.huge) <= 8
			and immediate < (hp + shield) * 0.6
		if not survives and not teamWin then
			safe, follow, assist, trade = false, false, false, false
			if outcome.selfDeathTime and outcome.selfDeathTime < 3 then returnFire = false end
		end
		if teamWin then safe = true end
	end
	local duel = false
	if not teamWin and outcome and not outcome.selfDead and not outcome.targetDead and hp > maximum * 0.45
		and immediate < (hp + shield) * 0.5 and engagement.isolated(ctx, target) then
		local long = engagement.duel(ctx, target, position, approach)
		local laning = ctx.clock < 600
		local ahead = Entity.GetHealth(target) < Entity.GetMaxHealth(target) * 0.5
			or NPC.GetCurrentLevel(ctx.hero) >= NPC.GetCurrentLevel(target) + 2
		if long and long.targetDead and not long.selfDead and (long.selfFraction or 0) > 0.25
			and (long.targetDeathTime or math.huge) <= engagement.duelLimit and (not laning or ahead) and creepDps < hp * 0.04 then
			duel, safe = true, true
			killTime = math.min(killTime, long.targetDeathTime or killTime)
		end
	end
	return {target = target, safe = safe, duel = duel, follow = follow, assist = assist, trade = trade, returnFire = returnFire, killTime = killTime,
		incoming = incoming, remaining = remaining, approach = approach, supportDamage = assisted, supportUnits = #support,
		sim = outcome, teamWin = teamWin}
end

engagement.duelLimit = 7

function engagement.creepAggro(ctx, point)
	local dps = 0
	for _, creep in ipairs(ctx.creeps or {}) do
		if visible(creep) and NPC.IsLaneCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep)
			and ctx.distance(Entity.GetAbsOrigin(creep), point) < 550 then
			dps = dps + NPC.GetTrueDamage(creep) * NPC.GetArmorDamageMultiplier(ctx.hero) / math.max(0.5, NPC.GetSecondsPerAttack(creep, false))
		end
	end
	return dps
end

function engagement.isolated(ctx, target)
	local point = Entity.GetAbsOrigin(target)
	if ctx.unsafePosition(point) then return false end
	for _, tower in ipairs(ctx.towers or {}) do
		if visible(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(Entity.GetAbsOrigin(tower), point) < NPC.GetAttackRange(tower) + 450 then return false end
	end
	for _, enemy in ipairs(ctx.enemies) do
		if enemy ~= target and visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1800 then return false end
	end
	local missing = ctx.strategy and ctx.strategy.enemiesMissing or 0
	return missing < 3 or ctx.clock < 600
end

function engagement.duel(ctx, target, position, approach)
	ctx.duelCache = ctx.duelCache or {}
	local id = Entity.GetIndex(target)
	local cached = ctx.duelCache[id]
	if cached and ctx.now - cached.time < 0.5 then return cached.outcome end
	local outcome = fightSim.evaluate(ctx, position, {target = target, selfDelay = approach, horizon = 15, radius = 1300})
	ctx.duelCache[id] = {time = ctx.now, outcome = outcome}
	return outcome
end

function engagement.keep(decision)
	return decision and (decision.safe or decision.returnFire or decision.trade or decision.assist or decision.follow) == true
end

engagement.releaseCooldown = 4

function engagement.choose(ctx)
	if ctx.hardRetreat or ctx.recovering or ctx.health < 0.2 or ctx.clock < 35 then return nil end
	local best, bestScore = nil, 0
	local ownStrength = strength(ctx.hero)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	for _, target in ipairs(ctx.enemies) do
		if visible(target) and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
			and not ctx.unsafePosition(engagement.attackPosition(ctx, target)) then
			local position = Entity.GetAbsOrigin(target)
			local distance = ctx.distance(ctx.position, position)
			if distance <= 1100 then
				local assessment = engagement.assess(ctx, target)
				local winning = assessment and assessment.safe
				local retaliation = assessment and assessment.returnFire
				local approach = math.max(0, distance - range) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				local physical = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
				local burst = awareness.burst(ctx, ctx.hero, target, distance, 2)
				local kill = approach < 1.8 and Entity.GetHealth(target) <= burst + physical * math.max(1, (2.5 - approach) / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false)))
				local friendly, hostile, joining = ownStrength, 0, false
				for _, ally in ipairs(ctx.allies) do
					if ally ~= ctx.hero and visible(ally) and ctx.distance(Entity.GetAbsOrigin(ally), position) < 850 then
						friendly = friendly + strength(ally)
						if NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(ally) + 150) == target
							or Hero.GetRecentDamage(ally) > 0 and ctx.distance(Entity.GetAbsOrigin(ally), position) < 500 then joining = true end
					end
				end
				for _, enemy in ipairs(ctx.enemies) do
					if visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), position) < 900 then hostile = hostile + strength(enemy) end
				end
				local favorable = friendly >= hostile * 1.15
				local outcome = assessment and assessment.sim
				if outcome then favorable = outcome.favorable and not outcome.selfDead end
				local interrupt = NPC.IsChannellingAbility(target)
				local controlled = NPC.IsStunned(target) or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED)
				local facing = NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(target) + 100)
				local occupied = visible(facing) and NPC.IsLaneCreep(facing) and Entity.IsSameTeam(ctx.hero, facing)
				local trade = ctx.tradeSafe and ctx.health >= 0.68 and distance < range + 100
					and (favorable or occupied or range >= NPC.GetAttackRange(target) + 150)
				local advantage = favorable and ctx.health > 0.62 and approach < 1.6
				local incoming = ctx.laneThreat and ctx.laneThreat.incoming or 0
				local safe = winning or retaliation or ctx.health >= 0.4 and friendly >= hostile * (kill and 0.65 or 0.95) and ((ctx.creepPressure or 0) < 3 or kill)
					and incoming < Entity.GetHealth(ctx.hero) * (kill and 0.65 or 0.32)
				if outcome and outcome.selfDead and not retaliation then safe = false end
				local teamWin = assessment and assessment.teamWin
				local released = ctx.combatRelease and ctx.combatRelease.target == target and ctx.now - ctx.combatRelease.time < engagement.releaseCooldown
				if released and not (kill or interrupt or retaliation) then safe = false end
				if brain.feeding(ctx) and not (retaliation or assessment and assessment.teamWin or kill and ctx.health > 0.6) then safe = false end
				if safe and assessment and (winning or retaliation or assessment.trade or assessment.assist)
					and (winning or retaliation or kill or interrupt or joining or controlled or trade or advantage) then
					local score = (kill and 110 or 0) + (interrupt and 85 or 0) + (joining and 75 or 0)
						+ (winning and 65 or 0) + (retaliation and 80 or 0) + (controlled and 50 or 0) + (advantage and 45 or 0) + (trade and 30 or 0) + (teamWin and 70 or 0) + (assessment.duel and 60 or 0) - approach * 12
					if score > bestScore then
						local urgent = kill or interrupt or retaliation or winning and (assessment.killTime < 2.5 or ctx.laneThreat and ctx.laneThreat.avoid) or joining and (ctx.clock >= 600 or ctx.role >= 4
							or Entity.GetHealth(target) < Entity.GetMaxHealth(target) * 0.5)
							or teamWin and (outcome.targetDeathTime or math.huge) < 2.5
							or assessment.duel and ctx.health > 0.6
						best, bestScore = {target = target, score = score, approach = approach, urgent = urgent}, score
					end
				end
			end
		end
	end
	return best
end

return engagement
