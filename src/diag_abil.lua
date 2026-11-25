local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[abil] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
L("hero=%s level=%s mana=%s", NPC.GetUnitName(hero), tostring(NPC.GetCurrentLevel(hero)), tostring(NPC.GetMana(hero)))
for i = 0, 10 do
  local ok, a = pcall(NPC.GetAbilityByIndex, hero, i)
  if ok and a then
    L("ab%d %s lvl=%s ready=%s cd=%s cdr=%s mana=%s castPoint=%s", i, tostring(Ability.GetName(a)), tostring(Ability.GetLevel(a)),
      tostring(Ability.IsReady(a)), tostring(Ability.GetCooldown(a)), tostring(Ability.GetCooldownRemaining and Ability.GetCooldownRemaining(a)),
      tostring(Ability.GetManaCost(a)), tostring(Ability.GetCastPoint(a)))
  end
end
for _, st in ipairs({ "modifier_treant_living_armor", "modifier_treant_natures_grasp" }) do
  L("hasModifier(hero,%s)=%s", st, tostring(NPC.HasModifier(hero, st)))
end
local mods = NPC.GetModifiers and NPC.GetModifiers(hero) or nil
if type(mods) == "table" then
  local names = {}
  for i = 1, math.min(#mods, 10) do names[#names + 1] = tostring(Modifier.GetName(mods[i])) end
  L("modifiers(%d)=%s", #mods, table.concat(names, ","))
end
L("done")
