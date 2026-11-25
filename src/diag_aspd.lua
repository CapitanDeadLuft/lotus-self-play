local loader = require("loader")
local ffi = require("ffi")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[aspd] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local schema = package.loaded["schema"]
local function off(n, fb) local o; if schema and schema.offsetOf then local ok,v=pcall(schema.offsetOf,"C_DOTA_BaseNPC",n); if ok then o=v end end; return o or fb end
local function rd(n, fb, typ)
  local ok, v = pcall(function()
    local i = Entity.GetIndex(hero)
    return nil
  end)
  return nil
end
-- use api field via NPC getters + raw schema offsets through a helper export if present
L("GetAttackSpeed=%s GetSecondsPerAttack=%s", tostring(NPC.GetAttackSpeed(hero)), tostring(NPC.GetSecondsPerAttack(hero)))
L("schema: m_iBaseAttackSpeed=%s m_flBaseAttackTime=%s m_flAgilityTotal(hero)=%s",
  tostring(off("m_iBaseAttackSpeed",0xCE4)), tostring(off("m_flBaseAttackTime",0xCE8)), tostring(off("m_flAgilityTotal",0x1AF0)))
L("GetMoveSpeed=%s GetHullRadius=%s", tostring(NPC.GetMoveSpeed(hero)), tostring(NPC.GetHullRadius(hero)))
L("done")
