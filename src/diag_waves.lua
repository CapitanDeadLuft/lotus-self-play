require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[waves] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local team = Entity.GetTeamNum(hero)
L("hero team=%s", tostring(team))
local all = NPCs.GetAll() or {}
local shown, laneAll, pass = 0, 0, 0
for _, u in ipairs(all) do
  local dn = NPC.GetUnitName(u) or ""
  if dn:find("creep", 1, true) and not dn:find("neutral", 1, true) then
    laneAll = laneAll + 1
    local waiting = NPC.IsWaitingToSpawn(u)
    local alive = Entity.IsAlive(u)
    local ent = Entity.IsEntity(u)
    local vis = NPC.IsVisible(u)
    local dorm = Entity.IsDormant(u)
    local okAll = ent and alive and not waiting
    if okAll then pass = pass + 1 end
    if shown < 8 then
      shown = shown + 1
      L("  %s team=%s waiting=%s alive=%s isEntity=%s visible=%s dormant=%s passes=%s",
        dn, tostring(Entity.GetTeamNum(u)), tostring(waiting), tostring(alive), tostring(ent),
        tostring(vis), tostring(dorm), tostring(okAll))
    end
  end
end
L("lane creeps=%d passWavesFilter=%d", laneAll, pass)
L("done")
