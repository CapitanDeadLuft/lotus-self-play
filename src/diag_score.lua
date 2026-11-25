local loader = require("loader")
local entity = require("entity")
local ffi = require("ffi")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[score] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
local player = Players.GetLocal()
if not hero or not player then L("no hero/player"); return end
L("hero=%s team=%s playerID=%s", NPC.GetUnitName(hero), tostring(Entity.GetTeamNum(hero)), tostring(Player.GetPlayerID(player)))
-- current API values (what Self Play sees)
local okS, score = pcall(Player.GetTeamPlayer, player)
if okS and type(score) == "table" then
  L("API: lasthits=%s denies=%s networth=%s gold=%s xp=%s heroDamage=%s creepGold=%s",
    tostring(score.lasthit_count), tostring(score.deny_count), tostring(score.networth),
    tostring(score.totalearned_gold), tostring(score.totalearned_xp), tostring(score.hero_damage), tostring(score.creep_kill_gold))
end
-- combat math probe
L("COMBAT hero: trueDmg=%s maxDmg=%s atkSpeed=%s secAtk=%s range=%s rangeBonus=%s animPoint=%s armorMult=%s hull=%s mana=%s movespeed=%s",
  tostring(NPC.GetTrueDamage(hero)), tostring(NPC.GetTrueMaximumDamage(hero)),
  tostring(NPC.GetAttackSpeed(hero)), tostring(NPC.GetSecondsPerAttack(hero)),
  tostring(NPC.GetAttackRange(hero)), tostring(NPC.GetAttackRangeBonus(hero)),
  tostring(NPC.GetAttackAnimPoint(hero)), tostring(NPC.GetArmorDamageMultiplier(hero)),
  tostring(NPC.GetHullRadius(hero)), tostring(NPC.GetMana(hero)), tostring(NPC.GetMoveSpeed(hero)))
local creep
for _, u in ipairs(NPCs.GetAll() or {}) do if NPC.IsLaneCreep(u) then creep = u; break end end
if creep then
  L("COMBAT creep %s: trueDmg=%s maxDmg=%s atkSpeed=%s secAtk=%s range=%s animPoint=%s armorMult=%s hp=%s/%s",
    NPC.GetUnitName(creep), tostring(NPC.GetTrueDamage(creep)), tostring(NPC.GetTrueMaximumDamage(creep)),
    tostring(NPC.GetAttackSpeed(creep)), tostring(NPC.GetSecondsPerAttack(creep)),
    tostring(NPC.GetAttackRange(creep)), tostring(NPC.GetAttackAnimPoint(creep)),
    tostring(NPC.GetArmorDamageMultiplier(creep)), tostring(Entity.GetHealth(creep)), tostring(Entity.GetMaxHealth(creep)))
end
L("done")
