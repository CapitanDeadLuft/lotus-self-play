local loader = require("loader")
local ffi = require("ffi")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[attack] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local schema = package.loaded["schema"]
local function off(name, fb)
  local o
  if schema and schema.offsetOf then local ok, v = pcall(schema.offsetOf, "C_DOTA_BaseNPC", name); if ok then o = v end end
  return o or fb
end
local oAct, oLast = off("m_NetworkActivity", 0x18E8), off("m_flLastAttackTime", 0x13C8)
L("schema offsets: NetworkActivity=%s LastAttackTime=%s", tostring(oAct), tostring(oLast))
local inst = function(e) local ok, i = pcall(Entity.GetIndex, e) return i end
local gt = GameRules.GetGameTime()
L("gameTime=%.2f", gt or -1)
local function dump(tag, e)
  if not e then return end
  local okI, idn = pcall(function() return e end)
  local base
  local okb, b = pcall(EntityClass and function() return nil end or function() return nil end)
  local instPtr
  do
    local ok, v = pcall(function() return ffi.cast("uintptr_t", e) end)
  end
  local act, last
  do
    local ok, v = pcall(function() return NPC.IsAttacking(e) end)
  end
  -- raw reads through api internals are not exposed; use EntityClass/EC if available
  local a1, t1, gt1, oa1, ol1 = NPC.__attackDebug(e)
  L("%s unit=%s team=%s attacking=%s alive=%s act=%s lastAttack=%s gt=%.2f offs(%s/%s)", tag, tostring(NPC.GetUnitName(e)), tostring(Entity.GetTeamNum(e)),
    tostring(NPC.IsAttacking(e)), tostring(Entity.IsAlive(e)), tostring(a1), tostring(t1), gt1 or -1,
    tostring(oa1 and string.format("0x%X", oa1)), tostring(ol1 and string.format("0x%X", ol1)))
end
dump("hero", hero)
local enemies = Entity.GetHeroesInRadius(hero, 20000, Enum.TeamType.TEAM_ENEMY) or {}
L("enemiesIn20k=%d", #enemies)
for i = 1, math.min(3, #enemies) do dump("enemy" .. i, enemies[i]) end
local creeps = NPCs.GetAll() or {}
local shown = 0
for _, u in ipairs(creeps) do
  if shown < 3 and NPC.IsLaneCreep(u) then shown = shown + 1; dump("creep" .. shown, u) end
end
L("done")

