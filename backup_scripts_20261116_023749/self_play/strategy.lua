local strategy = {}
local brain = require("self_play.brain")

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function real(ctx, hero)
	return Entity.IsEntity(hero) and not NPC.IsIllusion(hero) and not NPC.IsMeepoClone(hero)
		and Hero.GetReplicatingOtherHeroModel(hero) == nil
end

function strategy.dead(ctx, hero)
	if Entity.IsAlive(hero) then return false end
	local respawn = Hero.GetRespawnTime(hero)
	if not respawn or respawn <= 0 then return not Entity.IsDormant(hero) end
	local left = respawn - ctx.now
	return left > 0 and left < 160
end

function strategy.update(ctx)
	if ctx.now < (ctx.nextStrategy or 0) then return ctx.strategy end
	ctx.nextStrategy = ctx.now + 0.5
	local state = {phase = ctx.clock < 600 and "laning" or ctx.clock < 1800 and "mid" or "late",
		enemiesDead = 0, enemiesAlive = 0, enemiesMissing = 0, alliesAlive = 0, respawn = math.huge, known = {}}
	for _, hero in ipairs(Heroes.GetAll()) do
		if real(ctx, hero) then
			if Entity.IsSameTeam(ctx.hero, hero) then
				if Entity.IsAlive(hero) then state.alliesAlive = state.alliesAlive + 1 end
			elseif strategy.dead(ctx, hero) then
				state.enemiesDead = state.enemiesDead + 1
				state.respawn = math.min(state.respawn, math.max(0, Hero.GetRespawnTime(hero) - ctx.now))
			else
				state.enemiesAlive = state.enemiesAlive + 1
				local seen = visible(hero)
				local point = seen and Entity.GetAbsOrigin(hero) or Hero.GetLastMaphackPos(hero)
				local last = seen and ctx.now or Hero.GetLastVisibleTime(hero)
				local age = last and math.max(0, ctx.now - last) or math.huge
				if point and age < 20 then
					state.known[#state.known + 1] = {position = point, age = age, speed = NPC.GetMoveSpeed(hero), unit = hero}
				end
				if age > 6 then state.enemiesMissing = state.enemiesMissing + 1 end
			end
		end
	end
	local advantage = state.alliesAlive - state.enemiesAlive
	state.pushWindow = state.phase ~= "laning" and state.respawn > 18
		and (state.enemiesDead >= 2 or state.enemiesDead >= 1 and advantage >= 2)
	ctx.strategy = state
	return state
end

function strategy.farmSafe(ctx, point)
	local state = ctx.strategy
	if not state or state.phase == "laning" then return true end
	if not brain.safeFarm(ctx, point) then return false end
	local ownSide = ctx.distance(point, ctx.home) < ctx.distance(point, ctx.enemyHome)
	for _, enemy in ipairs(state.known) do
		local reach = 1500 + enemy.age * math.min(enemy.speed, 350) * 0.6
		if ctx.distance(point, enemy.position) < reach and (not ownSide or enemy.age < 4) then return false end
	end
	if ownSide or state.pushWindow then return true end
	local limit = state.phase == "late" and 1 or 2
	return state.enemiesMissing <= limit
end

function strategy.siegeGoal(ctx)
	local state = ctx.strategy
	if not state or not state.pushWindow or ctx.health < 0.6 then return nil end
	local best, bestScore
	for lane, wave in ipairs(ctx.waves) do
		local front, frontDistance
		for _, creep in ipairs(wave) do
			if Entity.IsEntity(creep) and Entity.IsAlive(creep) then
				local p = Entity.GetAbsOrigin(creep)
				local distance = ctx.distance(p, ctx.enemyHome)
				if not frontDistance or distance < frontDistance then front, frontDistance = p, distance end
			end
		end
		if front then
			local structure
			for _, unit in ipairs(ctx.structures) do
				if visible(unit) and not Entity.IsSameTeam(ctx.hero, unit) and ctx.distance(Entity.GetAbsOrigin(unit), front) < 2200 then structure = unit; break end
			end
			if structure then
				local score = ctx.distance(ctx.position, front) + ctx.distance(front, Entity.GetAbsOrigin(structure)) * 0.5
				if not bestScore or score < bestScore then best, bestScore = {lane = lane, goal = ctx.toward(front, ctx.home, 250), structure = structure}, score end
			end
		end
	end
	return best
end

function strategy.farming(ctx, ally)
	local position = Entity.GetAbsOrigin(ally)
	for _, unit in ipairs(ctx.worldNPCs or {}) do
		if visible(unit) and not Entity.IsSameTeam(ctx.hero, unit) and (NPC.IsLaneCreep(unit) or NPC.IsNeutral(unit) and NPC.IsCreep(unit))
			and ctx.distance(position, Entity.GetAbsOrigin(unit)) < 900 then return true end
	end
	return false
end

function strategy.threatNear(ctx, position, radius)
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < radius then return true end
	end
	for _, entry in pairs(ctx.memory or {}) do
		if ctx.now - entry.time < 4 and ctx.distance(position, entry.position) < radius then return true end
	end
	return false
end

function strategy.pushing(ctx, ally)
	local position = Entity.GetAbsOrigin(ally)
	for _, unit in ipairs(ctx.structures) do
		if visible(unit) and not Entity.IsSameTeam(ctx.hero, unit) and ctx.distance(position, Entity.GetAbsOrigin(unit)) < 1400 then return true end
	end
	return ctx.distance(position, ctx.enemyHome) < ctx.distance(position, ctx.home) * 0.7
end

function strategy.escort(ctx)
	local best, bestScore
	local previous = ctx.escortTarget
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally)
			and ctx.distance(Entity.GetAbsOrigin(ally), ctx.home) > 2500 then
			local position = Entity.GetAbsOrigin(ally)
			local farming = strategy.farming(ctx, ally)
			local ownSide = ctx.distance(position, ctx.home) < ctx.distance(position, ctx.enemyHome)
			local closeDanger = strategy.threatNear(ctx, position, 1500)
			local danger = closeDanger or not farming and strategy.threatNear(ctx, position, 2600)
			local pushing = strategy.pushing(ctx, ally)
			local roaming = not farming and not ownSide and ctx.strategy and ctx.strategy.phase ~= "laning" and NPC.IsRunning(ally)
			if danger or pushing or roaming then
				local role = ctx.runeRoles and ctx.runeRoles[Entity.GetIndex(ally)]
				local score = ctx.distance(ctx.position, position) - NPC.GetCurrentLevel(ally) * 120
					- (role and role <= 3 and 1500 or 0) - (danger and 1200 or 0) - (pushing and 800 or 0)
					- (ally == previous and 600 or 0)
				if not bestScore or score < bestScore then best, bestScore = ally, score end
			end
		end
	end
	return best
end

function strategy.finishing(ctx)
	local cached = ctx.finishingCache
	if cached and cached.time == ctx.now then return cached.target end
	local best, bestScore
	for _, unit in ipairs(ctx.structures or {}) do
		if visible(unit) and not Entity.IsSameTeam(ctx.hero, unit)
			and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
			local fort = NPC.IsFort(unit)
			local valuable = fort or NPC.IsBarracks(unit) or Entity.GetHealth(unit) < Entity.GetMaxHealth(unit) * 0.35
			local position = Entity.GetAbsOrigin(unit)
			if valuable and ctx.distance(ctx.position, position) < 1800 then
				local allies = 0
				for _, ally in ipairs(ctx.allies or {}) do
					if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) and ctx.distance(Entity.GetAbsOrigin(ally), position) < 1000 then allies = allies + 1 end
				end
				local pushing = ctx.teamTask and ctx.teamTask.kind == "push" and ctx.teamTask.target == unit
				if allies >= 1 or pushing then
					local score = (fort and 1000 or 0) + (1 - Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))) * 300
					if not bestScore or score > bestScore then best, bestScore = unit, score end
				end
			end
		end
	end
	ctx.finishingCache = {time = ctx.now, target = best}
	return best
end

function strategy.buybackReserve(ctx)
	if ctx.role > 3 or ctx.clock < 1800 or ctx.settings.buyback == false then return 0 end
	local info = Player.GetTeamPlayer(ctx.player)
	local networth = info and info.networth or 0
	return math.floor(200 + networth / 12)
end

return strategy
