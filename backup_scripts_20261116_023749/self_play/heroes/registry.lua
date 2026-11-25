local registry = {}

registry.paths = {
	npc_dota_hero_sniper = "self_play.heroes.sniper",
	npc_dota_hero_treant = "self_play.heroes.treant",
	npc_dota_hero_ancient_apparition = "self_play.heroes.ancient_apparition",
	npc_dota_hero_phoenix = "self_play.heroes.phoenix",
	npc_dota_hero_primal_beast = "self_play.heroes.primal_beast",
	npc_dota_hero_dazzle = "self_play.heroes.dazzle",
	npc_dota_hero_snapfire = "self_play.heroes.snapfire",
	npc_dota_hero_dawnbreaker = "self_play.heroes.dawnbreaker",
	npc_dota_hero_morphling = "self_play.heroes.morphling",
	npc_dota_hero_broodmother = "self_play.heroes.broodmother",
	npc_dota_hero_chen = "self_play.heroes.chen",
	npc_dota_hero_shadow_demon = "self_play.heroes.shadow_demon",
	npc_dota_hero_winter_wyvern = "self_play.heroes.winter_wyvern",
	npc_dota_hero_witch_doctor = "self_play.heroes.witch_doctor",
	npc_dota_hero_shredder = "self_play.heroes.timbersaw",
	npc_dota_hero_axe = "self_play.heroes.axe",
	npc_dota_hero_mars = "self_play.heroes.mars",
	npc_dota_hero_razor = "self_play.heroes.razor",

	npc_dota_hero_huskar = "self_play.heroes.huskar",
	npc_dota_hero_meepo = "self_play.heroes.meepo",
	npc_dota_hero_techies = "self_play.heroes.techies",
	npc_dota_hero_hoodwink = "self_play.heroes.hoodwink",
	npc_dota_hero_clinkz = "self_play.heroes.clinkz",
	npc_dota_hero_brewmaster = "self_play.heroes.brewmaster",
	npc_dota_hero_ember_spirit = "self_play.heroes.ember_spirit",
	npc_dota_hero_void_spirit = "self_play.heroes.void_spirit",
	npc_dota_hero_earth_spirit = "self_play.heroes.earth_spirit",
	npc_dota_hero_storm_spirit = "self_play.heroes.storm_spirit",
	npc_dota_hero_tinker = "self_play.heroes.tinker",
	npc_dota_hero_invoker = "self_play.heroes.invoker",
	npc_dota_hero_lone_druid = "self_play.heroes.lone_druid",
	npc_dota_hero_arc_warden = "self_play.heroes.arc_warden",
	npc_dota_hero_kez = "self_play.heroes.kez",
	npc_dota_hero_rubick = "self_play.heroes.rubick",
	npc_dota_hero_wisp = "self_play.heroes.io",
	npc_dota_hero_nevermore = "self_play.heroes.shadow_fiend",
	npc_dota_hero_zuus = "self_play.heroes.zeus",
	npc_dota_hero_lion = "self_play.heroes.lion",
	npc_dota_hero_lina = "self_play.heroes.lina",
	npc_dota_hero_crystal_maiden = "self_play.heroes.crystal_maiden",
}

function registry.attach(ctx)
	local path = registry.paths[ctx.heroName]
	ctx.heroModule = path and require(path) or nil
	ctx.heroState = {unitOrders = {}, unitBusy = {}}
end

function registry.reset(ctx)
	ctx.heroState = {unitOrders = {}, unitBusy = {}}
end

function registry.update(ctx, api, retreat)
	local profile = ctx.heroModule
	if not profile or not ctx.settings.spells then return false end
	if not retreat and not ctx.intent and not ctx.fightSession and ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.65
		and not (profile.locked and profile.locked(ctx)) and not (profile.urgent and profile.urgent(ctx)) then return false end
	if ctx.now >= (ctx.heroState.nextPrune or 0) then
		ctx.heroState.nextPrune = ctx.now + 5
		for id, actor in pairs(ctx.heroState.actors or {}) do
			if not Entity.IsEntity(actor.hero) or not Entity.IsAlive(actor.hero) then
				ctx.heroState.actors[id], ctx.heroState.unitOrders[id], ctx.heroState.unitBusy[id] = nil, nil, nil
			end
		end
	end
	local chased = ctx.intent and ctx.intent.target
	local chasing = chased and Entity.IsEntity(chased) and not (ctx.intent.followUntil and ctx.now < ctx.intent.followUntil) and ctx.distance(ctx.position, Entity.GetAbsOrigin(chased))
		> NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 100
	local primed = false
	for name in pairs(profile.preAttack or {}) do
		local ability = NPC.GetAbility(ctx.hero, name)
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) and Ability.IsReady(ability) then primed = true; break end
	end
	if not retreat and ctx.intent and ctx.intent.kind == "hero" and ctx.intent.followAttack and not chasing and not primed
		and not (profile.locked and profile.locked(ctx)) then return false end
	return profile.update and profile.update(ctx, api, retreat) or false
end

function registry.reserved(ctx, name)
	local profile = ctx.heroModule
	return profile and profile.reserved and profile.reserved[name] == true or false
end

function registry.skills(ctx, name)
	local profile = ctx.heroModule
	return profile and profile.skillPriority and profile.skillPriority(ctx, name) or 0
end

function registry.plan(ctx, plan)
	local profile = ctx.heroModule
	return profile and profile.build and profile.build(ctx, plan) or plan
end

function registry.unit(ctx, api, unit)
	local profile = ctx.heroModule
	return profile and profile.unit and profile.unit(ctx, api, unit) or false
end

function registry.remove(ctx, unit)
	local id = Entity.GetIndex(unit)
	ctx.heroState.unitOrders[id], ctx.heroState.unitBusy[id] = nil, nil
	if ctx.heroState.actors then ctx.heroState.actors[id] = nil end
end

return registry
