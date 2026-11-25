local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[threat] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local hp = Entity.GetAbsOrigin(hero)
L("hero=%s team=%s pos=%.0f,%.0f", NPC.GetUnitName(hero), tostring(Entity.GetTeamNum(hero)), hp.x, hp.y)
local all = Heroes.GetAll() or {}
L("heroes=%d", #all)
for _, e in ipairs(all) do
  if Entity.IsSameTeam(hero, e) == false then
    local ep = Entity.GetAbsOrigin(e)
    local d = ep and math.sqrt((ep.x - hp.x)^2 + (ep.y - hp.y)^2) or -1
    local atk = NPC.IsAttacking(e)
    local face = NPC.FindFacingNPC(e, nil, Enum.TeamType.TEAM_ENEMY, 35, 20000)
    L("enemy %s dist=%.0f attacking=%s facing=%s hero?=%s atkRange=%.0f dead=%s", NPC.GetUnitName(e), d, tostring(atk),
      tostring(face and NPC.GetUnitName(face) or "nil"), tostring(face == hero), NPC.GetAttackRange(e) or -1,
      tostring(not Entity.IsAlive(e)))
  end
end
L("done")
