local objectives = {}
local agenda = require("self_play.agenda")
local value = require("self_play.value")

local combat = require("self_play.combat")
local vision = require("self_play.vision")
local wardSpots = require("self_play.ward_spots")
local awareness = require("self_play.awareness")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

local function safe(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time < 6 and ctx.distance(position, entry.position) < 1500 then return false end
	end
	return true
end

local function covered(ctx, position)
	for _, unit in ipairs(NPCs.InRadius(position, 1300, ctx.team, Enum.TeamType.TEAM_FRIEND)) do
		if live(unit) and NPC.GetUnitName(unit) == "npc_dota_observer_wards" then return true end
	end
	for _, entry in ipairs(ctx.placedWards or {}) do
		if ctx.now - entry.time < 330 and ctx.distance(position, entry.position) < 1300 then return true end
	end
	return false
end

local function wardSafe(ctx, position, range)
	local approach = ctx.distance(ctx.position, position) > range - 25
		and ctx.toward(position, ctx.position, math.max(100, range - 80)) or ctx.position
	if ctx.role ~= 2 or ctx.clock >= 1200 then
		for _, enemy in ipairs(ctx.enemies) do
			if live(enemy) and NPC.IsVisible(enemy) and not NPC.IsIllusion(enemy)
				and ctx.distance(approach, Entity.GetAbsOrigin(enemy)) < NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 500 then return false end
		end
		if awareness.risk(ctx, approach) > 90 then return false end
		return safe(ctx, position)
	end
	if ctx.unsafePosition(approach) or awareness.risk(ctx, approach) > 90 then return false end
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time < 4 and ctx.distance(approach, entry.position) < 550 then return false end
	end
	return true
end

local function helperSpots(ctx)
	return wardSpots.helper(ctx).observer
end

local function wardSpot(ctx, anchor, range)
	return wardSpots.choose(ctx, anchor, range, function(point) return wardSafe(ctx, point, range) end, helperSpots(ctx))
end

function objectives.ward(ctx, anchor)
	local contested = ctx.nearEnemies > 0 and (ctx.role ~= 2 or ctx.nearEnemies > ctx.nearAllies
		or ctx.health < 0.7 or ctx.laneThreat and ctx.laneThreat.attacked)
	if not vision.responsible(ctx) or ctx.clock < 30 or contested or ctx.health < 0.55
		or ctx.farmCandidate and ctx.farmCandidate.start < ctx.now + 1 then
		if contested and ctx.wardTask then ctx.nextWard = math.max(ctx.nextWard or 0, ctx.now + 8) end
		ctx.wardTask, ctx.wardStatus = nil, contested and "contested" or ctx.health < 0.55 and "low health" or "waiting"
		return false
	end
	ctx.placedWards = ctx.placedWards or {}
	for index = #ctx.placedWards, 1, -1 do if ctx.now - ctx.placedWards[index].time > 360 then table.remove(ctx.placedWards, index) end end
	local pending = ctx.wardPending
	if pending then
		if covered(ctx, pending.position) then
			ctx.placedWards[#ctx.placedWards + 1] = {position = pending.position, time = ctx.now}
			ctx.wardPending, ctx.nextWard = nil, ctx.now + 25
		elseif ctx.now > pending.expires then ctx.wardPending, ctx.nextWard = nil, ctx.now + 10 end
		return false
	end
	if ctx.now < ctx.nextWard then return false end
	local ward = NPC.GetItem(ctx.hero, "item_ward_observer", true) or NPC.GetItem(ctx.hero, "item_ward_dispenser", true)
	if not ward or not combat.ready(ctx, ward, true) then ctx.wardStatus = ward and "ward not ready" or "no ward"; return false end
	if Ability.GetName(ward) == "item_ward_dispenser" then
		local observers = Ability.GetToggleState(ward) and Item.GetCurrentCharges(ward) or Item.GetSecondaryCharges(ward)
		if observers <= 0 then return false end
		if not Ability.GetToggleState(ward) then Ability.Toggle(ward, false, false, true); ctx.nextWard = ctx.now + 0.3; return true end
	end
	if not ctx.wardTask then
		if ctx.role == 2 and ctx.clock < 1200 then
			if vision.midCovered(ctx) or ctx.distance(ctx.position, Vector(0, 0, 0)) > 3200 then return false end
			anchor = Vector(0, 0, 0)
		end
		local position = wardSpot(ctx, anchor, Ability.GetCastRange(ward))
		if not position then ctx.nextWard, ctx.wardStatus = ctx.now + 10, "no useful spot"; return false end
		ctx.wardTask = {position = position, expires = ctx.now + math.max(20, ctx.distance(ctx.position, position) / math.max(200, NPC.GetMoveSpeed(ctx.hero)) + 8)}
	end
	local task = ctx.wardTask
	if ctx.now > task.expires or not wardSafe(ctx, task.position, Ability.GetCastRange(ward)) or covered(ctx, task.position) then
		ctx.wardTask, ctx.nextWard, ctx.wardStatus = nil, ctx.now + 10, "spot expired, unsafe or covered"
		return false
	end
	local range = Ability.GetCastRange(ward)
	if ctx.distance(ctx.position, task.position) > range - 25 then
		return ctx.move(ctx.toward(task.position, ctx.position, math.max(100, range - 80)), "Travel to ward position")
	end
	combat.cast(ctx, ward, "point", nil, task.position)
	ctx.wardPending = {position = task.position, expires = ctx.now + 3}
	ctx.wardTask, ctx.mode, ctx.wardStatus = nil, "Place observer vision", "placed"
	return true
end

function objectives.teamBusy(ctx)
	if ctx.fightSession then return true end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and NPC.IsVisible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1800 then return true end
	end
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and live(ally) and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 2500 then
			local fight = ctx.allyFights
			for _, record in pairs(fight or {}) do
				if record.ally == ally and ctx.now - record.time < 2 then return true end
			end
			local target = NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 30, NPC.GetAttackRange(ally) + 200)
			if live(target) and NPC.IsHero(target) then return true end
		end
	end
	return false
end

function objectives.collect(ctx, wisdomOnly)
	local current = ctx.objectiveTask
	local granting = current and current.kind == "wisdom" and current.arrived and ctx.now - current.arrived <= 8 and live(current.unit)
		and Entity.GetField(current.unit, "m_bIsBeingGranted") and Entity.GetField(current.unit, "m_bActive")
	local threatened = ctx.laneThreat and (ctx.laneThreat.attacked or ctx.laneThreat.ambush or ctx.laneThreat.lethal) or ctx.hardRetreat
	if granting and not threatened and ctx.health >= 0.3 then
		ctx.mode = "Collect wisdom: countdown"
		if ctx.distance(ctx.position, current.position) > 240 then return ctx.move(ctx.toward(current.position, ctx.position, 160), "Collect wisdom: countdown") end
		return true
	end
	if ctx.intent and ctx.intent.kind == "hero" or ctx.teamTask and (ctx.teamTask.kind == "push" or ctx.teamTask.fighting)
		or objectives.teamBusy(ctx) then
		ctx.objectiveTask = nil
		return false
	end
	if not ctx.settings.objectives or ctx.clock < 0 or ctx.nearEnemies > 0 or ctx.health < 0.55 or ctx.retreating then
		ctx.objectiveTask = nil
		return false
	end
	ctx.objectiveVisits = ctx.objectiveVisits or {}
	local task = ctx.objectiveTask
	if wisdomOnly and task and task.kind ~= "wisdom" then return false end
	if task then
		if not live(task.unit) or ctx.now > task.expires or not safe(ctx, task.position) then
			ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + (task.kind == "wisdom" and 12 or 40), nil
			return false
		end
		if task.kind == "wisdom" then
			if not Entity.GetField(task.unit, "m_bActive") then
				ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + 5, nil
				ctx.mode = "Wisdom collection complete"
				return false
			end
			local distance = ctx.distance(ctx.position, task.position)
			local remaining = distance / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + 8 - (task.arrived and ctx.now - task.arrived or 0)
			local fits, blocking = agenda.fits(ctx, remaining, task.position, value.wisdom(ctx))
			if not fits and not task.arrived then
				ctx.agendaNote = "drop wisdom: misses " .. (blocking.label or blocking.key)
				ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + 6, nil
				return false
			end
			if distance > 240 then
				task.arrived = nil
				return ctx.move(ctx.toward(task.position, ctx.position, 160), "Travel to wisdom")
			end
			if not task.arrived then
				task.arrived, task.expires = ctx.now, math.max(task.expires, ctx.now + 8.5)
				ctx.stop()
			end
			if ctx.now - task.arrived > 8 then
				ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + 12, nil
				return false
			end
			ctx.mode = Entity.GetField(task.unit, "m_bIsBeingGranted") and "Collect wisdom: countdown" or "Hold wisdom radius"
			return true
		end
		local distance = ctx.distance(ctx.position, task.position)
		if distance > 220 then return ctx.move(ctx.toward(task.position, ctx.position, 140), "Travel to " .. task.kind) end
		if not task.arrived then
			task.arrived = ctx.now
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET, task.unit, task.position, nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true)
			ctx.lastOrder = "objective"
		end
		ctx.mode = "Collect " .. task.kind

		if ctx.now - task.arrived < 4 then return true end
		local period = task.kind == "wisdom" and 420 or 180
		ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + period - ctx.clock % period, nil
		return false
	end
	if ctx.now < (ctx.nextObjective or 0) then return false end
	ctx.nextObjective = ctx.now + 2
	local best, bestScore
	for _, unit in ipairs(ctx.mapObjectives) do
		if live(unit) then
			local position = Entity.GetAbsOrigin(unit)
			local wisdom = NPC.GetUnitName(unit) == "npc_dota_xp_fountain"
			local period = wisdom and 420 or 180
			local epoch = math.floor(ctx.clock / period)
			local key = Entity.GetIndex(unit)
			local distance = ctx.distance(ctx.position, position)
			local ownSide = ctx.distance(position, ctx.home) < ctx.distance(position, ctx.enemyHome)
			local available = not wisdom or Entity.GetField(unit, "m_bActive")
			local limit = ownSide and ctx.role >= 4 and 4200 or 2400
			local relevant = wisdom and distance < limit or not wisdom and not wisdomOnly and distance < 1400
			for _, ally in ipairs(ctx.allies) do
				if wisdom and ally ~= ctx.hero and live(ally) and not NPC.IsIllusion(ally)
					and ctx.distance(Entity.GetAbsOrigin(ally), position) < 450 and distance > 500 then relevant = false end
			end
			local trip = distance / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + (wisdom and 8 or 2)
			local fits, blocking = agenda.fits(ctx, trip, position, wisdom and value.wisdom(ctx) or 150)
			if not fits and relevant and available then ctx.agendaNote = string.format("skip %s: misses %s", wisdom and "wisdom" or "lotus", blocking.label or blocking.key) end
			if epoch > 0 and relevant and available and fits and ctx.now >= (ctx.objectiveVisits[key] or 0) and safe(ctx, position) then
				local score = (wisdom and 3000 or 1000) - distance * 0.5
				if not bestScore or score > bestScore then
					best, bestScore = {unit = unit, position = position, kind = wisdom and "wisdom" or "lotus",
						key = key, expires = ctx.now + distance / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + 8}, score
				end
			end
		end
	end
	if best then ctx.objectiveTask = best; return ctx.move(ctx.toward(best.position, ctx.position, 140), "Travel to " .. best.kind) end
	return false
end

return objectives
