local dive = {}
local awareness = require("self_play.awareness")
local engagement = require("self_play.engagement")

dive.margin = 0.12
dive.maxKill = 4.5
dive.recheck = 0.2
dive.block = 3

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function dive.reach(ctx, tower)
	return NPC.GetAttackRange(tower) + NPC.GetAttackRangeBonus(tower) + NPC.GetHullRadius(ctx.hero) + 60
end

function dive.cover(ctx, point)
	local list = {}
	for _, tower in ipairs(ctx.towers or {}) do
		if visible(tower) and not Entity.IsSameTeam(ctx.hero, tower) then
			local reach = dive.reach(ctx, tower)
			local position = Entity.GetAbsOrigin(tower)
			if ctx.distance(point, position) < reach then list[#list + 1] = {unit = tower, reach = reach, position = position} end
		end
	end
	return list
end

local function tank(ctx, tower)
	local current = Tower and Tower.GetAttackTarget and Tower.GetAttackTarget(tower)
	if not visible(current) or current == ctx.hero or not Entity.IsSameTeam(ctx.hero, current) then return nil end
	local shots = Entity.GetHealth(current) / math.max(1, NPC.GetTrueDamage(tower) * NPC.GetArmorDamageMultiplier(current))
	if NPC.IsHero(current) and not NPC.IsIllusion(current) then
		return shots >= 4 and Entity.GetHealth(current) > Entity.GetMaxHealth(current) * 0.45 and "hero" or nil
	end
	return shots >= 2 and "creep" or nil
end

function dive.evaluate(ctx, target)
	local view = setmetatable({unsafePosition = function() return false end}, {__index = ctx})
	local decision = engagement.assess(view, target)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local killTime = decision and decision.killTime or math.huge
	local predicted = ctx.predict and ctx.predict(target, math.min(killTime, 3)) or Entity.GetAbsOrigin(target)
	local strike = ctx.distance(ctx.position, predicted) <= range and ctx.position or ctx.toward(predicted, ctx.position, math.max(0, range - 30))
	local towers = dive.cover(ctx, strike)
	if #towers == 0 then return {needed = false} end
	if not decision then return {needed = true, allowed = false, towers = towers, reason = "target out of reach under tower"} end
	local approach = decision.approach or 0
	local killPhase = math.max(0, killTime - approach)
	local towerDamage, timeIn, deepest = 0, 0, nil
	for _, entry in ipairs(towers) do
		local tower, reach = entry.unit, entry.reach
		local enter = math.max(0, ctx.distance(ctx.position, entry.position) - reach) / speed
		local before = math.max(0, approach - enter)
		local exit = math.max(0, reach + 80 - ctx.distance(strike, entry.position)) / speed
		local cover = tank(ctx, tower)
		local aggro = killPhase + exit + (cover and 0 or before)
		local share = cover == "hero" and 0.35 or 1
		local period = math.max(0.4, NPC.GetSecondsPerAttack(tower, false))
		local shot = NPC.GetTrueDamage(tower) * NPC.GetArmorDamageMultiplier(ctx.hero)
		towerDamage = towerDamage + math.ceil(aggro / period) * shot * share
		timeIn = math.max(timeIn, before + killPhase + exit)
		if not deepest or exit > deepest.exit then deepest = {tower = tower, exit = exit} end
	end
	local barriers = NPC.GetBarriers(ctx.hero)
	local hp = Entity.GetHealth(ctx.hero) + (barriers and barriers.all.current or 0)
	local heroDamage = (decision.incoming or 0) + awareness.damage(ctx, strike, deepest.exit) * 0.5
	local remaining = hp - towerDamage - heroDamage
	local maximum = Entity.GetMaxHealth(ctx.hero)
	local survive = remaining > maximum * dive.margin
	local sure = decision.safe or decision.teamWin or decision.sim and decision.sim.targetDead and not decision.sim.selfDead
	local killable = killTime <= dive.maxKill and sure
	local lowTarget = Entity.GetHealth(target) < Entity.GetMaxHealth(target) * 0.25
	local allowed = survive and killable and (remaining > maximum * 0.25 or lowTarget)
	local reason
	if not killable then reason = string.format("kill takes %.1fs under tower", killTime)
	elseif not survive then reason = string.format("tower %.0f + heroes %.0f would leave %.0f HP", towerDamage, heroDamage, remaining)
	elseif not allowed then reason = string.format("too thin: %.0f HP left for a healthy target", remaining)
	else reason = string.format("kill in %.1fs, %.1fs under tower, tower %.0f + heroes %.0f, %.0f HP left", killTime, timeIn, towerDamage, heroDamage, remaining) end
	return {needed = true, allowed = allowed, towers = towers, timeIn = timeIn, killTime = killTime, towerDamage = towerDamage,
		heroDamage = heroDamage, remaining = remaining, reason = reason}
end

function dive.update(ctx, target)
	local state = ctx.dive
	if state and (ctx.now > state.expires or not visible(state.target) or target and state.target ~= target) then
		ctx.dive, state = nil, nil
	end
	if not visible(target) or not NPC.IsHero(target) or Entity.IsSameTeam(ctx.hero, target) then return ctx.dive end
	if ctx.now < (ctx.nextDiveCheck or 0) then return ctx.dive end
	ctx.nextDiveCheck = ctx.now + dive.recheck
	local result = dive.evaluate(ctx, target)
	ctx.diveCheck = result
	if not result.needed then
		if state and state.target == target and #dive.cover(ctx, ctx.position) == 0 then ctx.dive = nil end
		return ctx.dive
	end
	if result.allowed then
		local set = {}
		for _, entry in ipairs(result.towers) do set[entry.unit] = true end
		ctx.dive = {target = target, towers = set, expires = ctx.now + math.max(1.2, result.timeIn) + 0.8,
			started = state and state.started or ctx.now, reason = result.reason}
		if not state then ctx.diveNote = "commit: " .. result.reason end
	else
		local id = Entity.GetIndex(target)
		ctx.dive = nil
		if not dive.contested(ctx, target) then
			ctx.fightBlocked = ctx.fightBlocked or {}
			ctx.fightBlocked[id] = math.max(ctx.fightBlocked[id] or 0, ctx.now + dive.block)
			if ctx.intent and ctx.intent.target == target then ctx.intent = ctx.parent and false or nil end
			ctx.diveNote = (state and "abort: " or "skip: ") .. result.reason
		else
			ctx.diveNote = "stay outside tower, allies are fighting: " .. result.reason
		end
	end
	return ctx.dive
end

function dive.contested(ctx, target)
	local id = Entity.GetIndex(target)
	local recent = ctx.allyFights and ctx.allyFights[id]
	if recent and ctx.now - recent.time < 3 then return true end
	local record = ctx.fightEvidence and ctx.fightEvidence[id]
	for _, hit in pairs(record and record.allies or {}) do
		if ctx.now - hit.time < 3 then return true end
	end
	if ctx.fightSession and ctx.fightSession.target == target and #(ctx.fightSession.members or {}) > 0 then return true end
	if ctx.helpRotation or ctx.teamTask and ctx.teamTask.fighting then return true end
	return false
end

function dive.allows(ctx, tower)
	local state = ctx.dive
	return state ~= nil and ctx.now <= state.expires and state.towers[tower] == true
end

return dive
