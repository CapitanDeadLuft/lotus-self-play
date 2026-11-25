local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[dorm] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local hp = Entity.GetAbsOrigin(hero)
L("heroTeam=%s pos=%.0f,%.0f gt=%.1f", tostring(Entity.GetTeamNum(hero)), hp.x, hp.y, GameRules.GetGameTime() or -1)
local shown = 0
for _, u in ipairs(NPCs.GetAll() or {}) do
  if shown < 6 and NPC.IsLaneCreep(u) then
    shown = shown + 1
    local p = Entity.GetAbsOrigin(u)
    local d = p and math.sqrt((p.x - hp.x)^2 + (p.y - hp.y)^2) or -1
    L("creep %s team=%s dormant=%s visible=%s alive=%s dist=%.0f", NPC.GetUnitName(u), tostring(Entity.GetTeamNum(u)),
      tostring(Entity.IsDormant(u)), tostring(NPC.IsVisible(u)), tostring(Entity.IsAlive(u)), d)
  end
end
L("total npcs=%d", #(NPCs.GetAll() or {}))
L("done")
