local hunt = {}
local fightSim = require("self_play.fight_sim")
local engagement = require("self_play.engagement")
local value = require("self_play.value")
local brain = require("self_play.brain")
local intent = require("self_play.intent")
local awareness = require("self_play.awareness")

hunt.radius = 6000
hunt.maxApproach = 12
hunt.seekAge = 8
hunt.teleportFrom = 3500
hunt.recheck = 0.4
hunt.engageRange = 1000

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function huntable(enemy)
	return visible(enemy) and NPC.IsHero(enemy) and not NPC.IsIllusion(enemy)
		and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
end

local function teleportReady(ctx)
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false) or NPC.GetItem(ctx.hero, "item_travel_boots", true)
		or NPC.GetItem(ctx.hero, "item_travel_boots_2", true)
	return scroll and Ability.IsReady(scroll) and Ability.IsCastable(scroll, NPC.GetMana(ctx.hero)) or false
end

function hunt.evaluate(ctx, enemy, position, confidence)
	local seen = visible(enemy)
	position = position or Entity.GetAbsOrigin(enemy)
	confidence = confidence or 1
	local distance = ctx.distance(ctx.position, position)
	if distance > hunt.radius then return nil, "too far" end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local record = ctx.history and ctx.history[Entity.GetIndex(enemy)]
	local away = 0
	if seen and record and record.vx and NPC.IsRunning(enemy) then
		away = ((position.x - ctx.position.x) * record.vx + (position.y - ctx.position.y) * record.vy) / math.max(1, distance)
	end
	local gap = math.max(0, distance - range)
	local closing = speed - math.max(0, away)
	if gap > 0 and closing < 40 then return nil, "cannot catch" end
	local approach = gap > 0 and gap / closing or 0
	local teleport = false
	if distance > hunt.teleportFrom and teleportReady(ctx) then
		local hop = 3.5 + 1400 / speed
		if hop < approach then approach, teleport = hop, true end
	end
	if approach > hunt.maxApproach then return nil, string.format("approach %.1fs", approach) end
	local strike = seen and engagement.attackPosition(ctx, enemy) or position
	if ctx.unsafePosition(strike) then return nil, "under enemy tower" end
	local horizon = math.min(20, approach + 8)
	local outcome = fightSim.evaluate(ctx, position, {target = enemy, selfDelay = approach, horizon = horizon, memoryAge = hunt.seekAge})
	if not outcome then return nil, "no simulation" end
	if not outcome.targetDead and not outcome.selfDead and outcome.favorable then
		local longer = fightSim.evaluate(ctx, position, {target = enemy, selfDelay = approach, horizon = math.min(26, approach + 14), memoryAge = hunt.seekAge})
		if longer and longer.targetDead and not longer.selfDead then outcome = longer end
	end
	if not outcome.targetDead or outcome.selfDead then
		return nil, string.format("simulation finds no clean kill (approach %.1fs, target %s, self %s at %.0f%%, %d units)", approach,
			outcome.targetDead and string.format("dies %.1fs", outcome.targetDeathTime or 0) or string.format("survives at %.0f%%", (outcome.targetFraction or 1) * 100),
			outcome.selfDead and "dies" or "lives", (outcome.selfFraction or 0) * 100, outcome.units or 0)
	end
	local killTime = math.max(0.5, (outcome.targetDeathTime or 6) - approach)
	local danger = brain.danger and brain.danger(ctx, position, enemy) or 0
	local tolerance = 0.8 + math.max(0, math.min(1, outcome.selfFraction or 0)) * 0.8
	if danger >= tolerance then return nil, string.format("dangerous area (danger %.2f, limit %.2f)", danger, tolerance) end
	local missing = ctx.strategy and ctx.strategy.enemiesMissing or 0
	local enemySide = ctx.enemyHome and ctx.distance(position, ctx.enemyHome) < ctx.distance(position, ctx.home)
	local fog = enemySide and missing * 0.08 or missing * 0.03
	local risk = math.min(1, math.max(0, 1 - (outcome.selfFraction or 0)) * 0.3 + math.max(0, danger - 0.5) * 0.15 + (1 - confidence) * 0.1 + fog * 0.5)
	if risk > 0.45 then return nil, string.format("too risky %.0f%% (danger %.2f, %d missing)", risk * 100, danger, missing) end
	local worth = value.kill(ctx, enemy) * confidence
	local cost = value.time(ctx, approach + killTime + (seen and 2 or 5))
	local net = worth - cost - risk * value.deathCost(ctx)
	return {target = enemy, net = net, worth = worth, cost = cost, risk = risk, approach = approach, killTime = killTime,
		distance = distance, started = ctx.now, position = position, seen = seen, confidence = confidence, teleport = teleport}
end

function hunt.blocked(ctx)
	if ctx.retreating or ctx.hardRetreat or ctx.baseDefense or ctx.clock < 600 then return "busy or early" end
	if ctx.health < 0.55 then return "health" end
	if ctx.fightSession or ctx.teamTask and ctx.teamTask.fighting or ctx.intent and ctx.intent.kind == "hero" then return "already fighting" end
	if brain.feeding and brain.feeding(ctx) then return "feeding guard" end
	return nil
end

function hunt.plan(ctx)
	local reason = hunt.blocked(ctx)
	if reason then
		if ctx.hunt and reason ~= "already fighting" then ctx.hunt = nil end
		return ctx.hunt
	end
	if ctx.now < (ctx.nextHunt or 0) then return ctx.hunt end
	ctx.nextHunt = ctx.now + hunt.recheck
	local current = ctx.hunt
	local best, notes = nil, {}
	local candidates = {}
	for _, enemy in ipairs(ctx.enemies) do
		if huntable(enemy) then candidates[#candidates + 1] = {unit = enemy}
		elseif enemy and Entity.IsEntity(enemy) and Entity.IsAlive(enemy) and NPC.IsHero(enemy) and not NPC.IsIllusion(enemy) then
			local point, confidence = awareness.fogPosition(ctx, enemy, hunt.seekAge)
			if point and confidence >= 0.3 then candidates[#candidates + 1] = {unit = enemy, position = point, confidence = confidence} end
		end
	end
	for _, candidate in ipairs(candidates) do
		local enemy = candidate.unit
		if ctx.distance(ctx.position, candidate.position or Entity.GetAbsOrigin(enemy)) < hunt.radius then
			local result, why = hunt.evaluate(ctx, enemy, candidate.position, candidate.confidence)
			if result then
				if current and current.target == enemy then result.net, result.started = result.net + 300, current.started end
				if result.net > 0 and (not best or result.net > best.net) then best = result end
			end
			notes[#notes + 1] = string.format("%s: %s", (NPC.GetUnitName(enemy) or "?"):gsub("npc_dota_hero_", ""),
				result and string.format("net %+.0fg (kill %.0f, time %.0f, risk %.0f%%)", result.net, result.worth, result.cost, result.risk * 100) or why)
		end
	end
	if best and current and current.target == best.target and ctx.now - current.started > best.approach * 1.6 + 6 then
		best, notes[#notes + 1] = nil, "hunt timed out"
		ctx.huntBlocked = {target = current.target, until_ = ctx.now + 8}
	end
	if best and ctx.huntBlocked and ctx.huntBlocked.target == best.target and ctx.now < ctx.huntBlocked.until_ then best = nil end
	ctx.hunt = best
	ctx.huntNote = #notes > 0 and table.concat(notes, "; ") or nil
	return best
end

function hunt.run(ctx)
	local task = ctx.hunt
	if not task or not task.target or not Entity.IsEntity(task.target) or not Entity.IsAlive(task.target) then ctx.hunt = nil; return false end
	local name = (NPC.GetUnitName(task.target) or "enemy"):gsub("npc_dota_hero_", "")
	if not huntable(task.target) then
		local point = awareness.fogPosition(ctx, task.target, hunt.seekAge) or task.position
		if not point or ctx.distance(ctx.position, point) < 300 then
			ctx.huntBlocked, ctx.hunt = {target = task.target, until_ = ctx.now + 15}, nil
			ctx.huntNote = "lost " .. name .. " at the predicted spot"
			return false
		end
		if task.teleport and ctx.distance(ctx.position, point) > hunt.teleportFrom and ctx.teleport(point, "fight") then return true end
		return ctx.move(point, "Seek " .. name .. ": last seen alone", 80)
	end
	local position = Entity.GetAbsOrigin(task.target)
	local distance = ctx.distance(ctx.position, position)
	ctx.target = task.target
	if task.teleport and distance > hunt.teleportFrom and ctx.teleport(position, "fight") then return true end
	if distance <= hunt.engageRange then
		intent.begin(ctx, task.target, "hero", true)
		ctx.intent.opportunity, task.engaged = 120, ctx.now
		if intent.run(ctx) then return true end
		local release = ctx.combatRelease
		if release and release.target == task.target and ctx.now - release.time < 0.2 then
			ctx.huntBlocked, ctx.hunt = {target = task.target, until_ = ctx.now + 6}, nil
			ctx.huntNote = "fight check rejected the hunt: " .. tostring(release.reason)
			return false
		end
	end
	local lead = ctx.predict and ctx.predict(task.target, math.min(1.2, task.approach * 0.4)) or position
	return ctx.move(lead, "Hunt " .. name .. ": close in for a favorable kill", 60)
end

return hunt
