local fights = {}
local awareness = require("self_play.awareness")
local engagement = require("self_play.engagement")
local navigation = require("self_play.navigation")
local intent = require("self_play.intent")
local taskPolicy = require("self_play.task_policy")
local fightSim = require("self_play.fight_sim")
local profile = require("self_play.profile")

local function alive(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function visible(unit)
	return alive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function fights.hurt(ctx, data)
	if data.damage <= 0 or not visible(data.source) or not visible(data.target) or not NPC.IsHero(data.source) or not NPC.IsHero(data.target)
		or Entity.IsSameTeam(data.source, data.target) then return end
	local ally = Entity.IsSameTeam(ctx.hero, data.source) and data.source or data.target
	local enemy = ally == data.source and data.target or data.source
	if ally == ctx.hero or not Entity.IsSameTeam(ctx.hero, ally) then return end
	ctx.fightEvidence = ctx.fightEvidence or {}
	local id = Entity.GetIndex(enemy)
	local record = ctx.fightEvidence[id] or {target = enemy, allies = {}}
	record.allies[Entity.GetIndex(ally)] = {unit = ally, time = GameRules.GetGameTime()}
	ctx.fightEvidence[id] = record
	ctx.nextFightPlan = 0
end

fights.searchTime = 6
fights.grace = 2
fights.commit = 3

local function position(ctx, target)
	if visible(target) then return Entity.GetAbsOrigin(target), 1 end
	return awareness.fogPosition(ctx, target, fights.searchTime)
end

local function strength(unit)
	return NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false))
end

function fights.canJoin(ctx, point)
	return ctx.role ~= 2 or NPC.GetCurrentLevel(ctx.hero) >= 6 or ctx.baseDefense ~= nil
		or ctx.distance(ctx.position, point) <= 1350
end

function fights.plan(ctx)
	if ctx.settings.fights == false or (ctx.settings.mode or 0) ~= 0 then ctx.fightSession = nil; return nil end
	if ctx.now < (ctx.nextFightPlan or 0) then return ctx.fightSession end
	ctx.nextFightPlan = ctx.now + 0.15
	ctx.fightEvidence = ctx.fightEvidence or {}
	ctx.fightBlocked = ctx.fightBlocked or {}
	for id, expiry in pairs(ctx.fightBlocked) do if expiry <= ctx.now then ctx.fightBlocked[id] = nil end end
	local targets, seen = {}, {}
	for _, target in ipairs(ctx.enemies) do targets[#targets + 1], seen[target] = target, true end
	for _, record in pairs(ctx.memory) do
		if record.source and not seen[record.source] and ctx.now - record.time < 2.5 then targets[#targets + 1], seen[record.source] = record.source, true end
	end
	for id, record in pairs(ctx.fightEvidence) do
		for allyId, hit in pairs(record.allies) do if ctx.now - hit.time > fights.searchTime or not alive(hit.unit) then record.allies[allyId] = nil end end
		if not alive(record.target) or next(record.allies) == nil then ctx.fightEvidence[id] = nil end
	end
	local best, bestScore, rejected
	ctx.planningFight = true
	for _, target in ipairs(targets) do
		local point, confidence = position(ctx, target)
		local hidden = not visible(target)
		local fought = ctx.allyFights and ctx.allyFights[Entity.GetIndex(target)]
		if fought and ctx.now - fought.time < 3 and not rejected then
			local name = (NPC.GetUnitName(target):gsub("npc_dota_hero_", ""))
			if not point or confidence < (hidden and 0.25 or 0.4) then rejected = name .. ": lost track of the enemy"
			elseif not fights.canJoin(ctx, point) then rejected = name .. ": mid joins fights from level 6"
			elseif ctx.fightBlocked[Entity.GetIndex(target)] then rejected = name .. ": target blocked for a few seconds"
			elseif ctx.distance(ctx.position, point) >= 6500 then rejected = name .. ": fight is too far" end
		end
		if point and confidence >= (hidden and 0.25 or 0.4) and fights.canJoin(ctx, point) and not ctx.fightBlocked[Entity.GetIndex(target)] and not NPC.IsIllusion(target) and ctx.distance(ctx.position, point) < 6500 then
			local id = Entity.GetIndex(target)
			local record = ctx.fightEvidence[id] or {target = target, allies = {}}
			local recent = ctx.allyFights and ctx.allyFights[id]
			if recent and ctx.now - recent.time < 3 and alive(recent.ally) then
				record.allies[Entity.GetIndex(recent.ally)] = {unit = recent.ally, time = recent.time}
				ctx.fightEvidence[id] = record
			end
			local members, dps, lastEvidence = {}, 0, 0
			for _, ally in ipairs(ctx.allies) do
				if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) and Hero.GetReplicatingOtherHeroModel(ally) == nil
					and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.15 and ctx.distance(Entity.GetAbsOrigin(ally), point) < 1300 then
					local attacking = visible(target) and (NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 30,
						NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 200) == target
						or NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 30, NPC.GetAttackRange(target) + 200) == ally)
					local allyId = Entity.GetIndex(ally)
					if attacking then record.allies[allyId] = {unit = ally, time = ctx.now}; ctx.fightEvidence[id] = record end
					local evidence = record.allies[allyId]
					if evidence and ctx.now - evidence.time < (hidden and fights.searchTime or 3) then
						members[#members + 1] = ally
						dps, lastEvidence = dps + strength(ally), math.max(lastEvidence, evidence.time)
					end
				end
			end
			local worthChasing = not hidden or #members >= 2
				or (record.health and record.maxHealth and record.health < record.maxHealth * 0.4)
			if visible(target) then record.health, record.maxHealth = Entity.GetHealth(target), Entity.GetMaxHealth(target); ctx.fightEvidence[id] = record end
			if #members == 0 and fought and ctx.now - fought.time < 3 and not rejected then
				rejected = (NPC.GetUnitName(target):gsub("npc_dota_hero_", "")) .. ": no ally confirmed in that fight right now"
			end
			if #members > 0 and worthChasing then
				local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
				local spacing = visible(target) and profile.standoff(ctx, target) or 150
				local goal = ctx.distance(ctx.position, point) <= spacing and ctx.position or ctx.toward(point, ctx.position, spacing)
				if ctx.unsafePosition(goal) and visible(target) then
					local reach = math.max(range, profile.spellRange(ctx)) + 60
					for edge = spacing + 100, math.min(reach, ctx.distance(ctx.position, point)), 100 do
						local candidate = ctx.toward(point, ctx.position, edge)
						if not ctx.unsafePosition(candidate) then goal = candidate; break end
					end
				end
				local incoming = math.max(awareness.damage(ctx, goal, 2) + awareness.forecast(ctx, goal) * 0.5, ctx.recentLoss or 0)
				local instant = awareness.damage(ctx, ctx.position, 0.75) + awareness.forecast(ctx, ctx.position) * 0.2
				local hostile, foes = 0, 0
				for _, enemy in ipairs(ctx.enemies) do if visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1200 then hostile, foes = hostile + strength(enemy), foes + 1 end end
				local burst = visible(target) and awareness.burst(ctx, ctx.hero, target, range, 2) or 0
				local hp = Entity.GetHealth(ctx.hero)
				local support = dps + strength(ctx.hero) + burst / 3 >= hostile * 0.85
				local travel = math.max(0, ctx.distance(ctx.position, goal) - 40) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				local outcome = fightSim.evaluate(ctx, point, {target = target, selfDelay = travel, radius = 1700})
				local retained = ctx.fightSession and ctx.fightSession.target == target
				local committed = retained and ctx.now - (ctx.fightSession.since or ctx.now) < fights.commit
				local alone
				if outcome then
					support = outcome.favorable and not outcome.selfDead
						or retained and not outcome.selfDead and (outcome.selfFraction or 0) > 0.25
					if not support and not outcome.selfDead and (outcome.selfFraction or 0) > 0.3 then
						alone = fightSim.evaluate(ctx, point, {target = target, radius = 1700, excludeSelf = true})
						if alone and ((alone.allyDeaths or 0) > (outcome.allyDeaths or 0) or (outcome.enemyDeaths or 0) > (alone.enemyDeaths or 0)) then
							support = true
						end
					end
				end
				local useful = incoming < hp * (retained and 0.55 or 0.4) and instant < hp * (retained and 0.6 or 0.45)
					and (support or visible(target) and Entity.GetHealth(target) < burst and not (outcome and outcome.selfDead))
				if not useful then
					rejected = string.format("%s: %s", (NPC.GetUnitName(target):gsub("npc_dota_hero_", "")),
						incoming >= hp * 0.4 and string.format("approach takes %.0f damage", incoming)
						or instant >= hp * 0.45 and "too much damage right now"
						or outcome and string.format("simulation says %s (%d allies v %d enemies, deaths %d-%d, self %s %.0f%%%s)",
							outcome.selfDead and "we die" or "the fight is lost", #members + 1, foes, outcome.allyDeaths or 0, outcome.enemyDeaths or 0,
							outcome.selfDead and "dies" or "lives", (outcome.selfFraction or 0) * 100,
							alone and string.format(", without us %d-%d", alone.allyDeaths or 0, alone.enemyDeaths or 0) or "")
						or "not enough damage to matter")
				elseif ctx.unsafePosition(goal) then
					rejected = (NPC.GetUnitName(target):gsub("npc_dota_hero_", "")) .. ": no safe spot within spell range of the tower"
				end
				if useful and not ctx.unsafePosition(goal) and GridNav.IsTraversable(goal) then
					local score = #members * 120 + (retained and (committed and 600 or 220) or 0) + (visible(target) and NPC.IsChannellingAbility(target) and 160 or 0)
						+ (visible(target) and math.max(0, 1 - Entity.GetHealth(target) / math.max(1, Entity.GetMaxHealth(target))) * 220 or 0)
						- ctx.distance(ctx.position, goal) * 0.08
					if not bestScore or score > bestScore then
						best, bestScore = {target = target, members = members, goal = goal, evidence = lastEvidence,
							confidence = confidence, incoming = incoming, distance = ctx.distance(ctx.position, point), stage = visible(target) and "engage" or "search"}, score
					end
				end
			end
		end
	end
	ctx.planningFight = nil
	local old = ctx.fightSession
	if not best and old and visible(old.target) and not ctx.retreating and not ctx.hardRetreat
		and ctx.now - (old.lastGood or 0) < fights.grace and #(old.members or {}) > 0
		and awareness.damage(ctx, ctx.position, 0.75) + awareness.forecast(ctx, ctx.position) * 0.2 < Entity.GetHealth(ctx.hero) * 0.45 then
		ctx.fightStatus = "Hold confirmed allied fight through a noisy estimate"
		return old
	end
	if not best then
		ctx.fightSession, ctx.fightStatus = nil, rejected and ("Not joining " .. rejected) or "No confirmed allied fight with a survivable approach"
		return nil
	end
	best.lastGood = ctx.now
	best.since = old and old.target == best.target and old.since or ctx.now
	if old and old.target == best.target then
		best.progressAt, best.progressPosition = old.progressAt, old.progressPosition
		best.route = old.route
	end
	taskPolicy.progress(ctx, best, best.goal)
	best.health = visible(best.target) and Entity.GetHealth(best.target) or old and old.health or 0
	if ctx.now - best.progressAt > 4 and ctx.distance(ctx.position, best.goal) > 250 then
		ctx.fightBlocked[Entity.GetIndex(best.target)] = ctx.now + 3
		ctx.fightSession, ctx.fightStatus = nil, "Fight approach obstructed; reassess route"
		return nil
	end
	ctx.fightSession = best
	ctx.fightStatus = best.stage == "search" and "Follow recent fight observation" or "Confirmed allied combat owns current task"
	ctx.regroupTask, ctx.campTask, ctx.clearTask, ctx.runeTask, ctx.riverTask, ctx.objectiveTask, ctx.aggroTask = nil, nil, nil, nil, nil, nil, nil
	return best
end

function fights.task(ctx)
	local fight = ctx.fightSession
	return fight and {kind = "group", combat = true, fighting = true, target = fight.target, members = fight.members,
		goal = fight.goal, expires = ctx.now + 0.5}
end

function fights.run(ctx)
	local task = ctx.fightSession
	if not task or ctx.retreating or ctx.hardRetreat then return false end
	if not alive(task.target) then ctx.fightSession, ctx.teamTask = nil, nil; return false end
	local point, confidence = position(ctx, task.target)
	if not point or confidence < 0.25 or not fights.canJoin(ctx, point) then ctx.fightSession, ctx.teamTask = nil, nil; return false end
	if not visible(task.target) then
		if ctx.distance(ctx.position, point) < 90 then ctx.mode = "Search fog: predicted position reached"; return ctx.stop() end
		return ctx.move(point, "Search fog: follow predicted enemy path", 60)
	end
	ctx.target = task.target
	local distance = ctx.distance(ctx.position, point)
	if distance > 1350 then
		if ctx.fightAbilities() then return true end
		if distance > 3000 and ctx.teleport(task.goal, "fight") then return true end
		local route = task.route
		if not route or ctx.now >= route.expires or ctx.distance(route.goal, task.goal) > 180
			or ctx.distance(ctx.position, route.point) < 100 then
			local length = navigation.safePath(ctx, task.goal)
			local point = length and task.goal or navigation.detour(ctx, task.goal)
			if not point then
				ctx.fightBlocked = ctx.fightBlocked or {}
				ctx.fightBlocked[Entity.GetIndex(task.target)] = ctx.now + 3
				ctx.fightSession, ctx.teamTask = nil, nil
				ctx.fightStatus = "No traversable approach to allied fight"
				return false
			end
			route = {point = point, goal = task.goal, expires = ctx.now + 0.5}
			task.route = route
		end
		return ctx.move(route.point, "Approach enemy in allied fight", 60)
	end
	if ctx.unsafePosition(engagement.attackPosition(ctx, task.target)) then
		if ctx.fightAbilities() then return true end
		local edge = task.goal
		if edge and not ctx.unsafePosition(edge) and ctx.distance(ctx.position, edge) > 80 then
			return ctx.move(edge, "Fight with allies: hold at enemy tower edge", 60)
		end
		ctx.mode = "Fight with allies: hold at enemy tower edge"
		return ctx.stop()
	end
	intent.begin(ctx, task.target, "hero", false)
	ctx.intent.expires, ctx.intent.opportunity = ctx.now + 2, 100
	local swing = ctx.hits.ordered
	if swing and swing.target == task.target and swing.confirmed and swing.release <= ctx.now then ctx.intent.followAttack = false end
	local locked = ctx.heroModule and ctx.heroModule.locked and ctx.heroModule.locked(ctx)
	if (not ctx.intent.followAttack or locked or intent.caster(ctx) or intent.chasing(ctx, task.target) or intent.primed(ctx)) and ctx.fightAbilities() then return true end
	if NPC.HasState(task.target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) or NPC.HasState(task.target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then
		ctx.mode = "Keep attack access while enemy is temporarily untargetable"
		return ctx.stop()
	end
	if not profile.shouldHit(ctx, task.target) then return profile.hold(ctx, task.target, "Fight with allies: hold spell range behind cores") end
	return ctx.attack(task.target, "Fight with allies: focus confirmed opponent")
end

return fights
