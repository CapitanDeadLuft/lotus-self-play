-- xhelpers.lua — Umbrella XHelpers namespace: game KV data + ability radius tables + script loader.
local json = require("json")
local M = {}
local GAMEDATA = "D:\\hake\\lotus\\gamedata\\"
local kvCache = {}

local xkv = {}
function xkv:GetKV(name)
  if kvCache[name] then return kvCache[name] end
  local fileMap = {
    npc_abilities = "npc_abilities.json",
    items = "items.json",
    npc_units = "npc_units.json",
    npc_heroes = "npc_heroes.json",
    neutral_items = "neutral_items.json",
  }
  local fname = fileMap[name]
  local data = {}
  if fname then
    local loaded = json.loadfile(GAMEDATA .. fname)
    if loaded then data = loaded end
  end
  -- wrap with the KV root key the script expects per file
  local rootKey = (name == "neutral_items") and "neutral_items" or "DOTAAbilities"
  local wrapped = {}
  wrapped[rootKey] = data
  kvCache[name] = wrapped
  return wrapped
end
M.xkv = xkv

-- ability geometry tables (script uses `or` fallbacks; populated empty for now)
M.XAbility = {
  aoe_radiuses = {},
  radiuses = {},
  start_widths = {},
  end_widths = {},
}

function M.GetScript(name)
  -- optional helper scripts (e.g. WardHelper); not bundled -> nil (callers pcall)
  return nil
end

return M