local localization = {}
local translations = require("self_play.translations")

local state = {language = "en", entries = {}, listeners = {}}

function localization.text(key)
	local entry = translations[key]
	return entry and (entry[state.language] or entry.en) or key
end

local function apply(entry)
	entry.widget:ForceLocalization(localization.text(entry.key))
	if entry.options then
		local selected, options = entry.widget:Get(), {}
		for index, key in ipairs(entry.options) do options[index] = localization.text(key) end
		entry.widget:Update(options, selected)
		entry.widget:Set(selected)
	end
	if entry.tooltip then entry.widget:ToolTip(localization.text(entry.tooltip)) end
end

localization.store = "self_play_menu"

local function readSaved(entry)
	local id = entry.id
	if entry.kind == "Combo" then
		local saved = Config.ReadInt(localization.store, id, -1)
		if saved >= 0 and saved < #(entry.options or {}) then return saved end
	elseif entry.kind == "Switch" then
		local saved = Config.ReadInt(localization.store, id, -1)
		if saved == 0 or saved == 1 then return saved == 1 end
	elseif entry.kind == "Slider" then
		local saved = Config.ReadFloat(localization.store, id, -1e9)
		if saved > -1e8 then return saved == math.floor(saved) and math.floor(saved) or saved end
	end
	return nil
end

local function writeSaved(entry, value)
	if entry.kind == "Combo" then Config.WriteInt(localization.store, entry.id, value)
	elseif entry.kind == "Switch" then Config.WriteInt(localization.store, entry.id, value and 1 or 0)
	elseif entry.kind == "Slider" then Config.WriteFloat(localization.store, entry.id, value) end
end

function localization.bind(widget, key, options, tooltip, persist)
	local entry = {widget = widget, key = key, options = options, tooltip = tooltip}
	if persist then entry.kind, entry.id = persist.kind, persist.id
	elseif options then entry.kind, entry.id = "Combo", key end
	state.entries[#state.entries + 1] = entry
	if entry.kind and Config then
		local saved = readSaved(entry)
		if saved ~= nil and widget:Get() ~= saved then widget:Set(saved) end
		entry.saved = widget:Get()
		if saved == nil then writeSaved(entry, entry.saved) end
	end
	apply(entry)
	return widget
end

function localization.persist()
	if not Config then return end
	for _, entry in ipairs(state.entries) do
		if entry.kind then
			local value = entry.widget:Get()
			if value ~= entry.saved then
				entry.saved = value
				writeSaved(entry, value)
			end
		end
	end
end

function localization.listen(callback)
	state.listeners[#state.listeners + 1] = callback
	callback()
end

function localization.language(code)
	if state.language == code then return end
	state.language = code
	for _, entry in ipairs(state.entries) do apply(entry) end
	for _, callback in ipairs(state.listeners) do callback() end
end

function localization.init()
	if state.languageWidget then return end
	local language = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
	if not language then return end
	state.languageWidget = language
	local function update()
		local name = language:List()[language:Get() + 1]
		local code = name and name:match("%a+")
		localization.language(code and code:lower() or "en")
	end
	language:SetCallback(update)
	update()
end

function localization.group(group, path)
	local wrapped = {}
	local function id(name) return (path and path .. "/" or "") .. name end
	function wrapped:Create(name, ...)
		local child = group:Create(name, ...)
		if child:Type() == Enum.WidgetType.MenuGroup then localization.bind(child, name) end
		return localization.group(child, name)
	end
	function wrapped:Combo(name, options, ...)
		return localization.bind(group:Combo(name, options, ...), name, options, nil, {kind = "Combo", id = id(name)})
	end
	for _, method in ipairs({"Switch", "Bind", "Slider", "Label", "MultiSelect", "MultiCombo"}) do
		wrapped[method] = function(_, name, ...)
			local persist = (method == "Switch" or method == "Slider") and {kind = method, id = id(name)} or nil
			return localization.bind(group[method](group, name, ...), name, nil, nil, persist)
		end
	end
	for _, method in ipairs({"Visible", "Disabled", "Type", "Name"}) do
		wrapped[method] = function(_, ...) return group[method](group, ...) end
	end
	return wrapped
end

function localization.queue(status)
	local base, seconds = status:match("^(.-) %((%d+)s%)$")
	if base then return localization.queue(base) .. " (" .. seconds .. localization.text("s)") end
	local mode = status:match("^Requesting (.+)$")
	if mode then return localization.text("Requesting ") .. localization.text(mode) end
	local reason = status:match("^Queue rejected: (.-); retry$")
	if reason then return localization.text("Queue rejected: ") .. reason .. localization.text("; retry") end
	return localization.text(status)
end

return localization
