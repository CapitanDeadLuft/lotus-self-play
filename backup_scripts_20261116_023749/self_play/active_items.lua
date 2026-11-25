local items = {}
local awareness = require("self_play.awareness")
local domination = require("self_play.domination")
local prediction = require("self_play.prediction")
local engagement = require("self_play.engagement")
local dive = require("self_play.dive")
local focus = require("self_play.focus")
local kv = XHelpers.xkv:GetKV("items").DOTAAbilities

items.managed = {}
for _, name in ipairs({"glimmer_cape", "soul_ring", "force_staff", "hurricane_pike", "lotus_orb", "sphere",
	"pipe", "crimson_guard", "ancient_janggo", "boots_of_bearing", "phase_boots", "blade_mail", "black_king_bar",
	"manta", "satanic", "bloodstone", "shivas_guard", "urn_of_shadows", "spirit_vessel", "diffusal_blade", "disperser", "nullifier", "dust",
	"invis_sword", "silver_edge", "ghost", "ethereal_blade", "refresher", "refresher_shard", "mask_of_madness", "armlet",
	"sheepstick", "abyssal_blade", "orchid", "bloodthorn", "rod_of_atos", "gungir",
	"dagon", "dagon_2", "dagon_3", "dagon_4", "dagon_5", "helm_of_the_dominator", "helm_of_the_overlord",
	"hand_of_midas", "cyclone", "wind_waker", "heavens_halberd", "solar_crest", "harpoon", "blood_grenade"}) do
	items.managed["item_" .. name] = true
end

local function value(name, key, fallback)
	local record = kv[name]
	local result = record and record.AbilityValues and record.AbilityValues[key]
	if type(result) == "table" then result = result.value end
	return tonumber(result) or fallback
end

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function get(ctx, api, name)
	local item = NPC.GetItem(ctx.hero, name, true)
	if item and api.ready(ctx, item, true) and (ctx.abilityAttempts[name] or 0) <= ctx.now then return item end
end

local function targetCast(ctx, api, item, target)
	return live(target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) <= Ability.GetCastRange(item)
		and api.allowed(ctx, item, target) and api.cast(ctx, item, "target", target)
end

function items.fuel(ctx, api, ability)
	local ring = get(ctx, api, "item_soul_ring")
	if not ring or ctx.retreating or NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff")
		or NPC.HasModifier(ctx.hero, "modifier_item_soul_ring_buff") then return false end
	local gain = value("item_soul_ring", "mana_gain", 170)
	local cost, mana = Ability.GetManaCost(ability), NPC.GetMana(ctx.hero)
	local healthCost = tonumber(kv.item_soul_ring and kv.item_soul_ring.AbilityHealthCost) or 170
	local remaining = Entity.GetHealth(ctx.hero) - healthCost
	if cost < gain * 0.45 or mana + gain < cost or NPC.GetMaxMana(ctx.hero) - mana < gain * 0.6
		or remaining < Entity.GetMaxHealth(ctx.hero) * 0.5
		or awareness.damage(ctx, ctx.position, 1.5) > remaining * 0.3 then return false end
	return api.cast(ctx, ring, "none")
end

local function usable(ctx, item)
	return item and Ability.IsReady(item) and Item.IsItemEnabled(item) and not Ability.IsHidden(item)
		and not NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_MUTED)
		and Ability.IsCastable(item, NPC.GetMana(ctx.hero)) and (ctx.abilityAttempts[Ability.GetName(item)] or 0) <= ctx.now
end

local function disabled(unit)
	return NPC.IsStunned(unit) or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_HEXED)
		or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED)
end

local function magicImmune(unit)
	return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
end

local function enemiesNear(ctx, radius)
	local count, burst, disablers = 0, 0, 0
	for _, unit in ipairs(ctx.enemies) do
		if live(unit) and not NPC.IsIllusion(unit) and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < radius then
			count = count + 1
			burst = burst + awareness.burst(ctx, unit, ctx.hero, ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)), 3)
			for index = 0, 5 do
				local ability = NPC.GetAbilityByIndex(unit, index)
				local effect = ability and ctx.catalog.abilities[Ability.GetName(ability)]
				if effect and effect.disable and Ability.GetLevel(ability) > 0 and Ability.GetCooldown(ability) < 1 then disablers = disablers + 1; break end
			end
		end
	end
	return count, burst, disablers
end

local function situation(ctx)
	local s = {}
	s.enemy = live(ctx.target) and NPC.IsHero(ctx.target) and not Entity.IsSameTeam(ctx.hero, ctx.target) and ctx.target or nil
	s.early = ctx.clock < 600
	s.hurt = Hero.GetRecentDamage(ctx.hero) > 0 or ctx.laneThreat and ctx.laneThreat.attacked
	s.danger = ctx.hardRetreat or s.hurt or awareness.damage(ctx, ctx.position, 1.2) > Entity.GetHealth(ctx.hero) * 0.18
	s.debuffed = NPC.IsSilenced(ctx.hero) or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ROOTED)
	s.candidates = {ctx.hero}
	for _, ally in ipairs(ctx.allies) do if ally ~= ctx.hero and live(ally) then s.candidates[#s.candidates + 1] = ally end end
	local enemy = s.enemy
	if not enemy then return s end
	s.distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	s.fighting = ctx.intent and ctx.intent.kind == "hero" and (ctx.intent.target == enemy or ctx.intent.target == nil)
		or ctx.fightSession and ctx.fightSession.target == enemy or false
	local decision = ctx.combatDecision
	s.winning = decision and decision.target == enemy and (decision.safe or decision.teamWin) or false
	s.attackedBy = ctx.laneThreat and ctx.laneThreat.attacked and ctx.laneThreat.enemy == enemy
		or NPC.IsAttacking(enemy) and NPC.FindFacingNPC(enemy, nil, Enum.TeamType.TEAM_ENEMY, 30,
			NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 150) == ctx.hero
	local physical = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(enemy)
	s.quick = physical * 2 + awareness.burst(ctx, ctx.hero, enemy, s.distance, 2)
	s.kill = s.distance < 1000 and Entity.GetHealth(enemy) <= s.quick
	s.channel = NPC.IsChannellingAbility(enemy)
	s.commit = s.fighting and (not s.early or s.kill or s.winning or s.attackedBy or s.channel)
	s.followUp = function()
		if s.kill or s.channel or not ctx.unsafePosition(engagement.attackPosition(ctx, enemy)) then return true end
		if dive.contested(ctx, enemy) then return true end
		local state = dive.update(ctx, enemy)
		return state ~= nil and state.target == enemy
	end
	return s
end

local function armlet(ctx, api)
	local item = get(ctx, api, "item_armlet")
	return item and ctx.health < 0.4 and not Ability.GetToggleState(item) and api.cast(ctx, item, "toggle")
end

local function saves(ctx, api, s)
	for _, name in ipairs({"item_glimmer_cape", "item_lotus_orb", "item_sphere", "item_force_staff", "item_hurricane_pike"}) do
		local item = get(ctx, api, name)
		if item then
			local best, bestScore
			for _, ally in ipairs(s.candidates) do
				local point = Entity.GetAbsOrigin(ally)
				local hp = Entity.GetHealth(ally) / math.max(1, Entity.GetMaxHealth(ally))
				local incoming = awareness.damage(ctx, point, 1.2)
				local flying = prediction.incoming(ctx, ally, 1.2, {enemies = true})
				if flying and flying > incoming then incoming = flying end
				local attacked = Hero.GetRecentDamage(ally) > 0 or ally == ctx.hero and s.hurt or (flying or 0) > 0
				local threatened = incoming > Entity.GetHealth(ally) * 0.18 or attacked and hp < 0.8
				local legal = ctx.distance(ctx.position, point) <= Ability.GetCastRange(item) and api.allowed(ctx, item, ally)
				if name == "item_glimmer_cape" then legal = legal and not NPC.HasModifier(ally, "modifier_item_glimmer_cape_fade")
				elseif name == "item_lotus_orb" then
					legal = legal and not NPC.HasModifier(ally, "modifier_item_lotus_orb_active")
					threatened = threatened or NPC.IsSilenced(ally) or NPC.HasState(ally, Enum.ModifierState.MODIFIER_STATE_ROOTED)
				elseif name == "item_sphere" then legal = legal and ally ~= ctx.hero and not NPC.IsLinkensProtected(ally) and not s.danger
				else
					local forward = Entity.GetRotation(ally):GetForward()
					local length = value(name, "push_length", 600)
					local destination = Vector(point.x + forward.x * length, point.y + forward.y * length, point.z)
					legal = legal and GridNav.IsTraversable(destination) and not ctx.unsafePosition(destination)
						and awareness.damage(ctx, destination, 1.2) + 40 < incoming
				end
				local score = incoming + (1 - hp) * 300
				if legal and threatened and (not bestScore or score > bestScore) then best, bestScore = ally, score end
			end
			if best and targetCast(ctx, api, item, best) then return true end
		end
	end
	return false
end

local function blackKingBar(ctx, api, s)
	local bkb = NPC.GetItem(ctx.hero, "item_black_king_bar", true)
	if not usable(ctx, bkb) or magicImmune(ctx.hero) or not s.fighting and not s.danger then return false end
	local count, burst, disablers = enemiesNear(ctx, 900)
	if count == 0 then return false end
	local hp = Entity.GetHealth(ctx.hero)
	local doomed = ctx.localFight and ctx.localFight.selfDead and (ctx.localFight.selfDeathTime or 99) < 5
	local teamfight = count >= 2 and s.fighting and (disablers >= 1 or burst > hp * 0.3)
	if teamfight or doomed and (disablers >= 1 or burst > hp * 0.25) or s.debuffed and s.fighting or burst > hp * 0.55 then
		return api.cast(ctx, bkb, "none")
	end
	return false
end

local function defensive(ctx, api, s)
	local dispel = ctx.settings.dispelItems ~= false
	if dispel and blackKingBar(ctx, api, s) then return true end
	local incoming = awareness.damage(ctx, ctx.position, 1.2)
	for _, name in ipairs({"item_wind_waker", "item_cyclone"}) do
		local item = NPC.GetItem(ctx.hero, name, true)
		if usable(ctx, item) then
			if s.danger and (ctx.health < 0.35 or incoming > Entity.GetHealth(ctx.hero) * 0.6) and ctx.nearEnemies > 0 and not magicImmune(ctx.hero) then
				return api.cast(ctx, item, "target", ctx.hero)
			end
			for _, unit in ipairs(ctx.enemies) do
				if live(unit) and NPC.IsChannellingAbility(unit) and not NPC.IsLinkensProtected(unit) and targetCast(ctx, api, item, unit) then return true end
			end
		end
	end
	for _, name in ipairs({"item_manta", "item_blade_mail", "item_pipe", "item_crimson_guard", "item_satanic", "item_bloodstone"}) do
		local item = get(ctx, api, name)
		local use = false
		if item then
			if name == "item_manta" then
				if ctx.heroName == "npc_dota_hero_arc_warden" then
					use = NPC.HasModifier(ctx.hero, "modifier_arc_warden_tempest_double")
						and (s.debuffed or not s.defensiveOnly and s.fighting and NPC.IsAttacking(ctx.hero))
				elseif dispel then
					local projectile = 0
					for _, entry in pairs(ctx.projectiles or {}) do
						if entry.target == ctx.hero and entry.impact > ctx.now and entry.impact < ctx.now + 0.35 then projectile = projectile + entry.damage end
					end
					use = s.debuffed and (s.danger or s.fighting) or projectile > Entity.GetHealth(ctx.hero) * 0.25
						or not s.defensiveOnly and s.fighting and NPC.IsAttacking(ctx.hero) and (s.distance or math.huge) < 700
				end
			elseif name == "item_satanic" then use = s.debuffed or ctx.health < 0.65 and NPC.IsAttacking(ctx.hero)
			elseif name == "item_bloodstone" then use = s.fighting and ctx.health < 0.75
			elseif name == "item_blade_mail" then use = s.hurt and ctx.nearEnemies > 0
			else
				local count = 0
				for _, ally in ipairs(s.candidates) do
					if ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= 1200 and (Hero.GetRecentDamage(ally) > 0
						or awareness.damage(ctx, Entity.GetAbsOrigin(ally), 1.2) > Entity.GetHealth(ally) * 0.18) then count = count + 1 end
				end
				use = count >= 2 or s.danger and ctx.health < 0.65 and ctx.nearEnemies > 0
			end
			if use and api.cast(ctx, item, "none") then return true end
		end
	end
	for _, name in ipairs({"item_invis_sword", "item_silver_edge", "item_ghost"}) do
		local item = get(ctx, api, name)
		if item and s.danger and ctx.nearEnemies > 0 then
			local use = ctx.retreating and not NPC.HasModifier(ctx.hero, "modifier_invisible")
			if name == "item_ghost" then
				local enemy = s.enemy
				use = s.hurt and ctx.health < 0.65 and not NPC.HasModifier(ctx.hero, "modifier_ghost_state")
					and enemy and NPC.IsAttacking(enemy) and awareness.burst(ctx, enemy, ctx.hero, s.distance, 2) < Entity.GetHealth(ctx.hero) * 0.15
			end
			if use and api.cast(ctx, item, "none") then return true end
		end
	end
	if s.enemy and s.attackedBy and s.danger and not s.fighting and ctx.health < 0.6 and not disabled(s.enemy) and not magicImmune(s.enemy) then
		for _, name in ipairs({"item_sheepstick", "item_abyssal_blade", "item_heavens_halberd", "item_rod_of_atos", "item_gungir"}) do
			local item = get(ctx, api, name)
			if item then
				if name == "item_gungir" then
					local point = ctx.predict(s.enemy, 0.25)
					if ctx.distance(ctx.position, point) <= Ability.GetCastRange(item) then return api.cast(ctx, item, "point", nil, point) end
				elseif targetCast(ctx, api, item, s.enemy) then return true end
			end
		end
	end
	return false
end

local function grenade(ctx, api, s)
	local item = get(ctx, api, "item_blood_grenade")
	local enemy = s.enemy
	if not item or not enemy or magicImmune(enemy) or NPC.HasModifier(enemy, "modifier_item_blood_grenade") then return false end
	if ctx.health < 0.4 or Entity.GetHealth(ctx.hero) < 250 or s.distance > Ability.GetCastRange(item) then return false end
	local damage = value("item_blood_grenade", "impact_damage", 50) * NPC.GetMagicalArmorDamageMultiplier(enemy)
	local finish = Entity.GetHealth(enemy) <= damage + NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(enemy)
	local motion = ctx.history and ctx.history[Entity.GetIndex(enemy)]
	local point = Entity.GetAbsOrigin(enemy)
	local fleeing = motion and NPC.IsRunning(enemy) and not disabled(enemy)
		and (point.x - ctx.position.x) * motion.vx + (point.y - ctx.position.y) * motion.vy > 0
		and s.distance > NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local decision = ctx.combatDecision
	local close = decision and decision.target == enemy and (decision.killTime or math.huge) < 3.5
	local chase = (s.kill or s.winning and close) and fleeing and Entity.GetHealth(enemy) < Entity.GetMaxHealth(enemy) * 0.4
	if not finish and not chase then return false end
	return api.cast(ctx, item, "point", nil, ctx.predict(enemy, 0.25))
end

local function offensive(ctx, api, s)
	local enemy = s.enemy
	if not enemy or not s.commit then return false end
	if grenade(ctx, api, s) then return true end
	local lockTarget = focus.disableTarget(ctx, enemy, 1000)
	if lockTarget and not disabled(lockTarget) and (lockTarget ~= enemy or s.followUp()) then
		if lockTarget ~= enemy then ctx.splitNote = "disable " .. NPC.GetUnitName(lockTarget) .. " while " .. NPC.GetUnitName(enemy) .. " is covered" end
		for _, name in ipairs({"item_sheepstick", "item_abyssal_blade", "item_bloodthorn", "item_orchid", "item_gungir", "item_rod_of_atos"}) do
			local item = get(ctx, api, name)
			local silence = name == "item_bloodthorn" or name == "item_orchid"
			if item and not (silence and NPC.IsSilenced(lockTarget)) then
				if name == "item_gungir" then
					local point = ctx.predict(lockTarget, 0.25)
					if not magicImmune(lockTarget) and ctx.distance(ctx.position, point) <= Ability.GetCastRange(item) then return api.cast(ctx, item, "point", nil, point) end
				elseif targetCast(ctx, api, item, lockTarget) then return true end
			end
		end
		for _, name in ipairs({"item_nullifier", "item_disperser", "item_diffusal_blade"}) do
			local item = get(ctx, api, name)
			if item and not NPC.HasModifier(lockTarget, "modifier_item_nullifier_mute") and targetCast(ctx, api, item, lockTarget) then return true end
		end
	end
	for _, name in ipairs({"item_spirit_vessel", "item_urn_of_shadows"}) do
		local item = get(ctx, api, name)
		if item and Item.GetCurrentCharges(item) > 0 and not NPC.HasModifier(enemy, "modifier_" .. name .. "_damage")
			and targetCast(ctx, api, item, enemy) then return true end
	end
	local shiva = get(ctx, api, "item_shivas_guard")
	if shiva and ctx.distance(ctx.position, ctx.predict(enemy, 0.5)) < value("item_shivas_guard", "blast_radius", 825) - 100 then
		return api.cast(ctx, shiva, "none")
	end
	if not ctx.retreating and (s.kill or not s.early) then
		for _, name in ipairs({"item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon"}) do
			local item = get(ctx, api, name)
			if item and targetCast(ctx, api, item, enemy) then return true end
		end
		local ethereal = get(ctx, api, "item_ethereal_blade")
		if ethereal and not NPC.HasModifier(enemy, "modifier_item_ethereal_blade_ethereal") then
			local magic = 0
			for index = 0, 7 do
				local spell = NPC.GetAbilityByIndex(ctx.hero, index)
				if spell and api.ready(ctx, spell, false) and Ability.GetManaCost(spell) + Ability.GetManaCost(ethereal) <= NPC.GetMana(ctx.hero) then
					magic = magic + math.max(Ability.GetDamage(spell), ctx.planner.levelValue((ctx.catalog.abilities[Ability.GetName(spell)] or {}).damage, Ability.GetLevel(spell)))
				end
			end
			if magic > NPC.GetTrueDamage(ctx.hero) * 3 and targetCast(ctx, api, ethereal, enemy) then return true end
		end
	end
	for _, name in ipairs({"item_refresher_shard", "item_refresher"}) do
		local item = get(ctx, api, name)
		if item and ctx.health > 0.4 and s.distance < 1100 then
			local count, ultimate, cost = 0, false, Ability.GetManaCost(item)
			for index = 0, 7 do
				local spell = NPC.GetAbilityByIndex(ctx.hero, index)
				if spell and Ability.GetLevel(spell) > 0 and not Ability.IsHidden(spell) and not Ability.IsPassive(spell)
					and Ability.IsActivated(spell) and Ability.GetCooldown(spell) > 15 then
					count, cost = count + 1, cost + Ability.GetManaCost(spell)
					ultimate = ultimate or Ability.IsUltimate(spell)
				end
			end
			if (ultimate or count >= 2) and NPC.GetMana(ctx.hero) >= cost and Entity.GetHealth(enemy) > NPC.GetTrueDamage(ctx.hero) * 2
				and api.cast(ctx, item, "none") then return true end
		end
	end
	local halberd = get(ctx, api, "item_heavens_halberd")
	if halberd then
		local best, bestDps
		for _, unit in ipairs(ctx.enemies) do
			if live(unit) and not NPC.IsIllusion(unit) and NPC.IsAttacking(unit) and not magicImmune(unit)
				and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_DISARMED)
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) <= Ability.GetCastRange(halberd) then
				local dps = NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false))
				if not bestDps or dps > bestDps then best, bestDps = unit, dps end
			end
		end
		if best and bestDps > NPC.GetTrueDamage(ctx.hero) * 0.8 and targetCast(ctx, api, halberd, best) then return true end
	end
	local crest = get(ctx, api, "item_solar_crest")
	if crest and not NPC.HasModifier(enemy, "modifier_item_solar_crest_armor_reduction") and targetCast(ctx, api, crest, enemy) then return true end
	local harpoon = get(ctx, api, "item_harpoon")
	if harpoon and ctx.health > 0.5 and s.winning
		and s.distance > NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 150 and targetCast(ctx, api, harpoon, enemy) then return true end
	return false
end

local function utility(ctx, api, s)
	local enemy = s.enemy
	local ring = get(ctx, api, "item_soul_ring")
	if ring and not ctx.retreating and not NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff") then
		local mana, hp = NPC.GetMana(ctx.hero), Entity.GetHealth(ctx.hero)
		local gain = value("item_soul_ring", "mana_gain", 170)
		local healthCost = tonumber(kv.item_soul_ring and kv.item_soul_ring.AbilityHealthCost) or 170
		local need
		for index = 0, 31 do
			local ability = NPC.GetAbilityByIndex(ctx.hero, index)
			if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) and Ability.IsActivated(ability)
				and not Ability.IsPassive(ability) and Ability.IsReady(ability) and (ctx.abilityAttempts[Ability.GetName(ability)] or 0) <= ctx.now then
				local cost = Ability.GetManaCost(ability)
				if cost > mana and cost <= mana + gain and enemy and (s.fighting or s.hurt)
					and s.distance <= math.max(Ability.GetCastRange(ability), 500) then need = true end
			end
		end
		if need and NPC.GetMaxMana(ctx.hero) - mana >= gain * 0.6 and hp - healthCost > Entity.GetMaxHealth(ctx.hero) * 0.5
			and awareness.damage(ctx, ctx.position, 1.5) < (hp - healthCost) * 0.3 then return api.cast(ctx, ring, "none") end
	end
	for _, name in ipairs({"item_spirit_vessel", "item_urn_of_shadows"}) do
		local item = get(ctx, api, name)
		if item and Item.GetCurrentCharges(item) > 0 then
			for _, ally in ipairs(s.candidates) do
				if Entity.GetMaxHealth(ally) - Entity.GetHealth(ally) > value(name, "soul_heal_amount", 30) * 6
					and Hero.GetRecentDamage(ally) == 0 and awareness.damage(ctx, Entity.GetAbsOrigin(ally), 2) == 0
					and not NPC.HasModifier(ally, "modifier_" .. name .. "_heal") and targetCast(ctx, api, item, ally) then return true end
			end
		end
	end
	for _, name in ipairs({"item_phase_boots", "item_boots_of_bearing", "item_ancient_janggo"}) do
		local item = get(ctx, api, name)
		if item then
			local use
			if name == "item_phase_boots" then use = NPC.IsRunning(ctx.hero) and (ctx.retreating or s.fighting or ctx.moveGoal and ctx.distance(ctx.position, ctx.moveGoal) > 650)
			else use = ctx.nearAllies >= 2 and (s.fighting or s.danger) end
			if use and api.cast(ctx, item, "none") then return true end
		end
	end
	local midas = NPC.GetItem(ctx.hero, "item_hand_of_midas", true)
	local owned = ctx.heroModule and ctx.heroModule.reserved and ctx.heroModule.reserved.item_hand_of_midas
	if usable(ctx, midas) and not owned and not ctx.retreating and not s.fighting then
		local best, bestValue
		for _, list in ipairs({ctx.creeps, ctx.neutrals or {}}) do
			for _, creep in ipairs(list) do
				if live(creep) and not Entity.IsSameTeam(ctx.hero, creep) and not NPC.IsAncient(creep)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) <= Ability.GetCastRange(midas) + 50 and api.allowed(ctx, midas, creep) then
					local worth = NPC.GetBountyXP(creep) + Entity.GetMaxHealth(creep) * 0.02
					if not bestValue or worth > bestValue then best, bestValue = creep, worth end
				end
			end
		end
		if best then return api.cast(ctx, midas, "target", best) end
	end
	if items.madness(ctx, api, s) then return true end
	if items.static(ctx, api, s) then return true end
	return false
end

function items.static(ctx, api, s)
	local item = get(ctx, api, "item_mjollnir")
	if not item then return false end
	local function attacked(unit, heroesOnly)
		for _, attack in ipairs(prediction.attackers(ctx, unit)) do
			local source = attack.source
			if source and Entity.IsEntity(source) and not Entity.IsSameTeam(ctx.hero, source) and (not heroesOnly or NPC.IsHero(source)) then return true end
		end
		return false
	end
	local busy = NPC.IsAttacking(ctx.hero) or ctx.intent or ctx.fightSession
	if not NPC.HasModifier(ctx.hero, "modifier_item_mjollnir_static") and busy
		and (attacked(ctx.hero, false) or Hero.GetRecentDamage(ctx.hero) > 0 or (ctx.creepPressure or 0) > 0) then
		ctx.itemNote = "Mjollnir: Static Charge on self while taking hits"
		return api.cast(ctx, item, "target", ctx.hero)
	end
	local range = Ability.GetCastRange(item)
	for _, ally in ipairs(ctx.allies or {}) do
		if ally ~= ctx.hero and live(ally) and NPC.IsHero(ally) and not NPC.IsIllusion(ally)
			and not NPC.HasModifier(ally, "modifier_item_mjollnir_static")
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= range and attacked(ally, true) then
			ctx.itemNote = "Mjollnir: Static Charge on " .. (NPC.GetUnitName(ally) or "ally"):gsub("npc_dota_hero_", "")
			return api.cast(ctx, item, "target", ally)
		end
	end
	return false
end

function items.spellsPending(ctx, api, target)
	local distance = target and live(target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) or 0
	for index = 0, 7 do
		local spell = NPC.GetAbilityByIndex(ctx.hero, index)
		if spell and not Ability.IsPassive(spell) and api.ready(ctx, spell, false) and Ability.GetManaCost(spell) > 0
			and Ability.IsCastable(spell, NPC.GetMana(ctx.hero)) then
			local name = Ability.GetName(spell)
			local effect = ctx.catalog and ctx.catalog.abilities and ctx.catalog.abilities[name]
			local range = Ability.GetCastRange(spell)
			local primer = ctx.heroModule and ctx.heroModule.preAttack and ctx.heroModule.preAttack[name]
			if primer then return true end
			if (not effect or effect.damage or effect.disable) and (range <= 0 or distance <= range + 100) then return true end
		end
	end
	return false
end

function items.madness(ctx, api, s)
	local mask = get(ctx, api, "item_mask_of_madness")
	local standing = ctx.lastStand and ctx.now <= ctx.lastStand.expires
	if not mask or not NPC.IsAttacking(ctx.hero) or (ctx.retreating or ctx.hardRetreat) and not standing then return false end
	local target = live(ctx.attackTarget) and ctx.attackTarget or live(ctx.target) and ctx.target or nil
	if not target then return false end
	local hero = NPC.IsHero(target) and not Entity.IsSameTeam(ctx.hero, target)
	local hp = Entity.GetHealth(ctx.hero)
	local incoming = awareness.damage(ctx, ctx.position, 2)
	local spent = ctx.now - (ctx.spellCastAt or -100) < 3 or not items.spellsPending(ctx, api, target)
	local reason
	if standing and hero then reason = "last stand"
	elseif hero and spent and incoming < hp * 0.35 and (ctx.health > 0.4 or s.kill) then reason = "spells spent, hero fight"
	elseif ctx.health < 0.45 and incoming < hp * 0.15 and (hero and spent or not hero) then reason = "low HP lifesteal"
	elseif not hero and NPC.IsCreep(target) and ctx.nearEnemies == 0 and ctx.health > 0.45 and not s.danger then reason = "faster farming" end
	if not reason then return false end
	ctx.itemNote = "Mask of Madness: " .. reason
	return api.cast(ctx, mask, "none")
end

function items.run(ctx, api, defensiveOnly)
	if not ctx.settings.spells then return false end
	if armlet(ctx, api) then return true end
	local s = situation(ctx)
	s.defensiveOnly = defensiveOnly
	if saves(ctx, api, s) or defensive(ctx, api, s) then return true end
	if defensiveOnly then return false end
	if domination.run(ctx, api) then return true end
	return offensive(ctx, api, s) or utility(ctx, api, s)
end

return items
