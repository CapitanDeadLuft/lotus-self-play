require("loader")
local schema = require("schema")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[off] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local function probe(cls, names)
  L("class %s", cls)
  for _, n in ipairs(names) do
    local ok, off, err = pcall(schema.offsetOf, cls, n)
    if ok and off then L("   %-28s = 0x%X (%d)", n, off, off)
    else L("   %-28s = MISSING %s", n, tostring(ok and err or off)) end
  end
end
probe("C_DOTA_DataTeamPlayer", {
  "m_iReliableGold","m_iUnreliableGold","m_iTotalEarnedGold","m_iTotalEarnedXP",
  "m_iCreepKillGold","m_iNeutralKillGold","m_iNetWorth","m_iDenyCount","m_iLastHitCount",
  "m_iHeroDamage","m_iObserverWardsPlaced","m_iSentryWardsPlaced","m_iCampsStacked",
  "m_iGoldLostToDeath","m_flCustomStats","m_iTowerKills","m_iRoshanKills" })
-- inventory check
local hero = Heroes.GetLocal()
if hero then
  local items = NPC.GetItems and NPC.GetItems(hero) or {}
  L("NPC.GetItems count=%d", #items)
  for i = 0, 8 do
    local it = NPC.GetItemByIndex(hero, i)
    L("   slot %d -> %s", i, it and (NPC.GetUnitName(it) or "?") or "nil")
  end
end
L("done")
