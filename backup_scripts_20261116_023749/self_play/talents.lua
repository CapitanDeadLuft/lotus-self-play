local talents = {}

local function click(ctx, ability)
	local selected = Player.GetQueryUnit(ctx.player)
	if selected and selected ~= ctx.hero then return nil end
	local branch = Panorama.GetPanelByName("DOTAStatBranch", false)
	if not branch then return nil end
	local index = 0
	for slot = 0, 31 do
		local entry = NPC.GetAbilityByIndex(ctx.hero, slot)
		local name = entry and Ability.GetName(entry)
		if name and name:find("^special_bonus_") and name ~= "special_bonus_attributes" then
			index = index + 1
			if entry == ability then
				local button = branch:FindChildTraverse("Upgrade" .. index)
				local row = branch:FindChildTraverse("UpgradeOption" .. math.ceil(index / 2))
				if not button or not row then return nil end
				if button:HasClass("Disabled") or button:HasClass("BranchChosen") or not row:HasClass("BranchActive") then return false end
				return Engine.RunScript("$.DispatchEvent('Activated', $.GetContextPanel(), 'mouse');", button)
			end
		end
	end
	return nil
end

local function upgrade(ability)
	local index = Entity.GetIndex and Entity.GetIndex(ability)
	if not index then return false end
	local hud = Panorama.GetPanelByName("Hud", false)
	local code = "Abilities.AttemptToUpgrade(" .. index .. ");"
	if hud then return Engine.RunScript(code, hud) end
	return Engine.RunScript(code)
end

local function order(ctx, ability)
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY, nil, Vector(0, 0, 0), ability,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_talent", false)
	return true
end

function talents.train(ctx, ability, attempt)
	local method = (attempt or 0) % 4
	if method == 0 or method == 2 then return order(ctx, ability) end
	if method == 1 then return upgrade(ability) end
	local clicked = click(ctx, ability)
	if clicked ~= nil then return clicked end
	return upgrade(ability)
end

return talents
