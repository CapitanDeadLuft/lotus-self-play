local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[stats] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
L("hero=%s range=%s secAtk=%s animPoint=%s dmg=%s minDmg=%s maxDmg=%s bat=%s",
  NPC.GetUnitName(hero), tostring(NPC.GetAttackRange(hero)), tostring(NPC.GetSecondsPerAttack(hero)),
  tostring(NPC.AttackAnimPoint and NPC.AttackAnimPoint(hero)), tostring(NPC.GetAttackDamage and NPC.GetAttackDamage(hero)),
  tostring(NPC.GetBaseDamageMin and NPC.GetBaseDamageMin(hero)), tostring(NPC.GetBaseDamageMax and NPC.GetBaseDamageMax(hero)),
  tostring(NPC.GetBaseAttackTime and NPC.GetBaseAttackTime(hero)))
L("health=%.1f max=%.1f mana=%.1f", Entity.GetHealth(hero) or -1, Entity.GetMaxHealth(hero) or -1, Entity.GetMana(hero) or -1)
local c
for _, u in ipairs(NPCs.GetAll() or {}) do if NPC.IsLaneCreep(u) then c = u; break end end
if c then L("creep %s hp=%s/%s armor=%s hull=%s", NPC.GetUnitName(c), tostring(Entity.GetHealth(c)), tostring(Entity.GetMaxHealth(c)),
  tostring(NPC.GetPhysicalArmorValue and NPC.GetPhysicalArmorValue(c)), tostring(NPC.GetHullRadius(c))) end
L("done")
