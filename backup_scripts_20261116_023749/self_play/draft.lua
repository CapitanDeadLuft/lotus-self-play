local draft = {}
local catalog = require("self_play.catalog")
local planner = require("self_play.planner")
local JSON = require("assets.JSON")
local localization = require("self_play.localization")
local draftData = require("self_play.draft_data")

local roleFlags = {1, 4, 2, 8, 16}
local defaults = {
	"juggernaut, luna, phantom_assassin, sven, drow_ranger",
	"sniper, lina, dragon_knight, nevermore, zuus",
	"axe, centaur, tidehunter, bristleback, dragon_knight",
	"hoodwink, lion, shadow_shaman, rubick, spirit_breaker",
	"crystal_maiden, lich, witch_doctor, jakiro, treant",
}
local state = {nextPick = 0, role = nil}
local attributes = {str = "Strength", agi = "Agility", int = "Intelligence", all = "Universal"}
local avoid = {npc_dota_hero_wisp = true, npc_dota_hero_visage = true, npc_dota_hero_chen = true,
	npc_dota_hero_meepo = true, npc_dota_hero_broodmother = true, npc_dota_hero_enchantress = true}
local laneBits = {[1] = 1, [2] = 3, [4] = 2, [8] = 4, [16] = 5}

function draft.merge(full, visible)
	local present, nextIndex = {}, 1
	for _, entry in ipairs(visible) do present[entry[1]] = true end
	for index, entry in ipairs(full) do
		if present[entry[1]] then full[index], nextIndex = visible[nextIndex], nextIndex + 1 end
	end
end

function draft.priority(ui, role)
	local result = {}
	for _, entry in ipairs(ui.models[role]) do if entry[2] then result[#result + 1] = entry[1] end end
	return result
end

function draft.create(group)
	local ui = {enabled = group:Switch("Auto pick", false), priorities = {}, models = {}, updating = false}
	ui.source = group:Combo("Hero choice", {"Draft model + priorities", "Priority lists only"}, 0)
	ui.bracket = group:Combo("Draft statistics bracket", {"All ranks", "Legend+", "Ancient+", "Divine+"}, 3)
	ui.editRole = group:Combo("Edit hero priorities", {"Carry", "Mid", "Offlane", "Soft support", "Hard support"}, 0)
	ui.attributes = group:MultiSelect("Attributes", {
		{"Strength", "panorama/images/primary_attribute_icons/primary_attribute_icon_strength_psd.vtex_c", true},
		{"Agility", "panorama/images/primary_attribute_icons/primary_attribute_icon_agility_psd.vtex_c", true},
		{"Intelligence", "panorama/images/primary_attribute_icons/primary_attribute_icon_intelligence_psd.vtex_c", true},
		{"Universal", "panorama/images/primary_attribute_icons/primary_attribute_icon_all_psd.vtex_c", true},
	}, true)
	local labels = {"Carry priority", "Mid priority", "Offlane priority", "Soft support priority", "Hard support priority"}
	for role, label in ipairs(labels) do
		local entries, preferred, names = {}, {}, {}
		for token in defaults[role]:gmatch("[%w_]+") do
			local name = "npc_dota_hero_" .. token
			if catalog.heroes[name] then
				preferred[name] = true
				entries[#entries + 1] = {name, "panorama/images/heroes/icons/" .. name .. "_png.vtex_c", true}
			end
		end
		for name in pairs(catalog.heroes) do if not preferred[name] then names[#names + 1] = name end end
		table.sort(names)
		for _, name in ipairs(names) do entries[#entries + 1] = {name, "panorama/images/heroes/icons/" .. name .. "_png.vtex_c", false} end
		ui.priorities[role] = group:MultiSelect(label .. " heroes", entries, true)
		ui.priorities[role]:DragAllowed(true)
		localization.bind(ui.priorities[role], label .. " heroes", nil, "draft.priorityHelp")
		local saved = Config.ReadString("self_play_draft", "role_" .. role, "")
		local model, known = {}, {}
		for _, entry in ipairs(saved ~= "" and JSON:decode(saved) or {}) do
			if catalog.heroes[entry[1]] and not known[entry[1]] then model[#model + 1], known[entry[1]] = {entry[1], entry[2] == true}, true end
		end
		for _, name in ipairs(ui.priorities[role]:List()) do
			if not known[name] then model[#model + 1], known[name] = {name, ui.priorities[role]:Get(name)}, true end
		end
		for _, entry in ipairs(entries) do
			if not known[entry[1]] then model[#model + 1] = {entry[1], false} end
		end
		ui.models[role] = model
		Config.WriteString("self_play_draft", "role_" .. role, JSON:encode(model))
		ui.priorities[role]:SetCallback(function(widget)
			if ui.updating then return end
			local visible = {}
			for _, name in ipairs(widget:List()) do visible[#visible + 1] = {name, widget:Get(name)} end
			draft.merge(ui.models[role], visible)
			Config.WriteString("self_play_draft", "role_" .. role, JSON:encode(ui.models[role]))
		end)
	end
	local function filter()
		ui.updating = true
		for role, widget in ipairs(ui.priorities) do
			local entries = {}
			for _, entry in ipairs(ui.models[role]) do
				if ui.attributes:Get(attributes[catalog.heroes[entry[1]].attribute]) then
					entries[#entries + 1] = {entry[1], "panorama/images/heroes/icons/" .. entry[1] .. "_png.vtex_c", entry[2]}
				end
			end
			widget:Update(entries, true, false)
			widget:Visible(role == ui.editRole:Get() + 1)
		end
		ui.updating = false
	end
	ui.editRole:SetCallback(filter)
	ui.attributes:SetCallback(filter)
	localization.listen(function()
		local tips = {}
		for _, name in pairs(attributes) do tips[name] = localization.text(name) end
		ui.attributes:UpdateToolTips(tips)
	end)
	filter()
	return ui
end

function draft.role(selected)
	if selected > 0 then return selected end
	local player = Players.GetLocal()
	if player then
		local data = Player.GetTeamData(player)
		for role, flag in ipairs(roleFlags) do
			if data and data.lane_selection_flags == flag then return role end
		end
	end
	return state.role
end

function draft.team()
	local localPlayer = Players.GetLocal()
	if not localPlayer then return {} end
	local byID, allies = {}, {}
	for _, entry in pairs(catalog.heroes) do byID[entry.id] = entry end
	for _, player in ipairs(Players.GetAll()) do
		if player ~= localPlayer and Entity.GetTeamNum(player) == Entity.GetTeamNum(localPlayer) and #allies < 4 then
			local data = Player.GetTeamData(player)
			if data then
				local role
				for index, flag in ipairs(roleFlags) do if data.lane_selection_flags == flag then role = index; break end end
				local hero = byID[data.selected_hero_id]
				if hero or role then allies[#allies + 1] = {role = role, scores = planner.roleScores(hero)} end
			end
		end
	end
	return allies
end

function draft.auto(ui, available, allies)
	local reserved = {}
	for _, ally in ipairs(allies) do if ally.role then reserved[ally.role] = true end end
	local bestRole, bestHero, bestScore
	for role = 1, 5 do
		local name = draft.choose(available, draft.priority(ui, role), role)
		if name and not reserved[role] then
			local used = {[role] = true}
			local function scoreTeam(index)
				if index > #allies then return 0 end
				local ally, best = allies[index], -math.huge
				for slot = 1, 5 do
					if not used[slot] and (not ally.role or ally.role == slot) then
						used[slot] = true
						best = math.max(best, ally.scores[slot] + scoreTeam(index + 1))
						used[slot] = nil
					end
				end
				return best
			end
			local score = planner.roleScores(catalog.heroes[name])[role] + scoreTeam(1)
			if not bestScore or score > bestScore then bestRole, bestHero, bestScore = role, name, score end
		end
	end
	return bestRole, bestHero
end

function draft.picks()
	local localPlayer = Players.GetLocal()
	local allies, enemies = {}, {}
	if not localPlayer then return allies, enemies end
	local team = Entity.GetTeamNum(localPlayer)
	for _, player in ipairs(Players.GetAll()) do
		local data = player ~= localPlayer and Player.GetTeamData(player)
		local id = type(data) == "table" and tonumber(data.selected_hero_id) or 0
		local name = id > 0 and Engine.GetHeroNameByID(id)
		if name and name ~= "" then
			local entry = {name = name, pos = laneBits[tonumber(data.lane_selection_flags) or 0]}
			local list = Entity.GetTeamNum(player) == team and allies or enemies
			list[#list + 1] = entry
		end
	end
	return allies, enemies
end

function draft.best(ui, available, role)
	local priority = draft.priority(ui, role)
	if ui.source:Get() == 1 then return draft.choose(available, priority, role) end
	draftData.rank = ui.bracket:Get() + 1
	local allies, enemies = draft.picks()
	local ranked = draftData.rankPicks(role, available, allies, enemies, 5 - #enemies)
	if not ranked or #ranked == 0 then return draft.choose(available, priority, role) end
	local bonus = {}
	for index, name in ipairs(priority) do bonus[name] = math.max(1, 6 - (index - 1) * 0.5) end
	local best, bestScore
	for _, entry in ipairs(ranked) do
		if not avoid[entry.name] or bonus[entry.name] then
			local score = entry.score + (bonus[entry.name] or 0)
			if not bestScore or score > bestScore then best, bestScore = entry.name, score end
		end
	end
	return best or draft.choose(available, priority, role)
end

function draft.choose(available, priority, role)
	for _, name in ipairs(priority) do
		if available[name] then return name end
	end
	local best, score
	for name in pairs(available) do
		local entry = catalog.heroes[name]
		if entry then
			local value = planner.roleScores(entry)[role]
			if not score or value > score or value == score and name < best then best, score = name, value end
		end
	end
	return best
end

function draft.available(root)
	local result, visited = {}, 0
	local function walk(panel, depth)
		visited = visited + 1
		if depth > 12 or visited > 3000 then return end
		if panel:HasClass("HeroCard") then
			if panel:HasClass("Unavailable") or panel:HasClass("AlreadyPicked") or panel:HasClass("Banned") or panel:HasClass("Hidden") then return end
			local picture = panel:FindChildTraverse("HeroImage")
			local source = picture and picture:GetImageSrc()
			local name = source and source:match("(npc_dota_hero_[%w_]+)%.")
			if name and catalog.heroes[name] then result[name] = true end
			return
		end
		for index = 0, panel:GetChildCount() - 1 do
			local child = panel:GetChild(index)
			if child then walk(child, depth + 1) end
		end
	end
	walk(root, 0)
	return result
end

function draft.update(ui, selectedRole, now)
	if not ui.enabled:Get() then return end
	if ui.source:Get() == 0 then draftData.tick() end
	if now < state.nextPick then return end
	state.nextPick = now + 0.75
	local mode = GameRules.GetGameMode()
	if mode ~= 1 and mode ~= 22 and mode ~= 4 and mode ~= 3 and mode ~= 23 then return end
	local root = Panorama.GetPanelByName("DOTAHudPreGame", true)
	if not root or not root:HasClass("DOTA_GAMERULES_STATE_HERO_SELECTION") or root:HasClass("Hidden")
		or root:HasClass("HasSelectedHero") or root:HasClass("IsInBanPhase")
		or not root:HasClass("LocalPlayerInControl") then return end
	local grid = root:FindChildTraverse("HeroGrid")
	if not grid then return end
	local available = draft.available(grid)
	local count = 0
	for _ in pairs(available) do count = count + 1 end
	if mode == 4 and (count == 0 or count > 4) then return end
	local role = draft.role(selectedRole)
	local name
	if role then name = draft.best(ui, available, role)
	else role, name = draft.auto(ui, available, draft.team()) end
	if not name then return end
	local heroID = catalog.heroes[name].id
	if Engine.RunScript(string.format("$.DispatchEvent('DOTAPickHeroID', %d, false);", heroID), root) then
		state.role, state.nextPick = role, now + 2
		Log.Write("[SelfPlay draft] Pick requested: " .. name .. " role=" .. role)
	end
end

function draft.reset()
	state.nextPick, state.role = 0, nil
end

return draft
