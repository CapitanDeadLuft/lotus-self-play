-- diag_gaps.lua — ONE-SHOT live probe: values the Self Play last-hit planner needs.
require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...)
  local ok, s = pcall(string.format, fmt, ...)
  if f then f:write(os.date("%H:%M:%S ") .. "[gap] " .. tostring(s or fmt) .. "\n"); f:flush() end
end
local function V(x)
  if x == nil then return "nil" end
  if type(x) == "number" then return string.format("%.3f", x) end
  return tostring(x)
end

local hero = Heroes.GetLocal()
if not hero then L("no local hero"); return end
L("hero=%s team=%s lvl=%s", tostring(NPC.GetUnitName(hero)), tostring(Entity.GetTeamNum(hero)), tostring(Hero.GetLevel(hero)))

-- attack timing data used by last_hit.timing()
L("GetAttackAnimPoint      = %s", V(NPC.GetAttackAnimPoint and NPC.GetAttackAnimPoint(hero)))
L("GetAttackAnimPoint2     = %s", V(NPC.GetAttackAnimPoint and NPC.GetAttackAnimPoint(hero, 2)))
L("GetSecondsPerAttack     = %s", V(NPC.GetSecondsPerAttack and NPC.GetSecondsPerAttack(hero, false)))
L("GetAttackSpeed          = %s", V(NPC.GetAttackSpeed and NPC.GetAttackSpeed(hero, false)))
L("GetAttackRange          = %s", V(NPC.GetAttackRange and NPC.GetAttackRange(hero)))
L("GetTrueDamage           = %s", V(NPC.GetTrueDamage and NPC.GetTrueDamage(hero)))
L("GetTrueMaximumDamage    = %s", V(NPC.GetTrueMaximumDamage and NPC.GetTrueMaximumDamage(hero)))
L("GetArmorDamageMultiplier= %s", V(NPC.GetArmorDamageMultiplier and NPC.GetArmorDamageMultiplier(hero)))
L("GetAttackProjectileSpeed= %s", V(NPC.GetAttackProjectileSpeed and NPC.GetAttackProjectileSpeed(hero)))
L("NetChannel.GetAvgLatency= %s", V(NetChannel.GetAvgLatency and NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)))

-- lane creeps as the context scan sees them
local all = NPCs.GetAll() or {}
local lane, visible, same, near = 0, 0, 0, 0
local firstEnemy, firstAlly
local hp = Entity.GetAbsOrigin(hero)
for _, u in ipairs(all) do
  local dn = NPC.GetUnitName(u) or ""
  if dn:find("npc_dota_creep_lane") then
    lane = lane + 1
    local vis = NPC.IsVisible(u)
    if vis then visible = visible + 1 end
    if Entity.IsSameTeam(hero, u) then
      same = same + 1
      firstAlly = firstAlly or u
    else
      firstEnemy = firstEnemy or u
    end
    local p = Entity.GetAbsOrigin(u)
    if p and (p.x - hp.x) ^ 2 + (p.y - hp.y) ^ 2 < 2400 * 2400 then near = near + 1 end
  end
end
L("laneCreeps=%d visible=%d sameTeam=%d within2400=%d", lane, visible, same, near)

local function probe(tag, u)
  if not u then L("%s: none", tag); return end
  L("%s: %s hp=%s/%s vis=%s same=%s dist=%s", tag, tostring(NPC.GetUnitName(u)),
    V(Entity.GetHealth(u)), V(Entity.GetMaxHealth(u)), tostring(NPC.IsVisible(u)),
    tostring(Entity.IsSameTeam(hero, u)),
    V(NPC.IsEntityInRange and NPC.IsEntityInRange(hero, u, NPC.GetAttackRange(hero)) and 1 or 0))
  L("   immune=%s invuln=%s animPoint=%s secPerAtk=%s range=%s",
    tostring(NPC.HasState(u, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)),
    tostring(NPC.HasState(u, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)),
    V(NPC.GetAttackAnimPoint and NPC.GetAttackAnimPoint(u)),
    V(NPC.GetSecondsPerAttack and NPC.GetSecondsPerAttack(u, false)),
    V(NPC.GetAttackRange and NPC.GetAttackRange(u)))
  L("   armorMult=%s trueDmg=%s timeToFace=%s", V(NPC.GetArmorDamageMultiplier and NPC.GetArmorDamageMultiplier(u)),
    V(NPC.GetTrueDamage and NPC.GetTrueDamage(u)),
    V(NPC.GetTimeToFace and NPC.GetTimeToFace(hero, u)))
end
probe("enemyCreep", firstEnemy)
probe("allyCreep", firstAlly)
L("done")