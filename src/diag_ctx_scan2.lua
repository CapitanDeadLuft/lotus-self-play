-- diag_ctx_scan.lua — live diagnostic: what does the Self Play context scan see?
-- Runs inside the injected loader state (require "loader" first), prints one
-- compact report per second to host.log. Read-only: issues no orders.
require("loader")

local function L(fmt, ...)
  local ok, line = pcall(string.format, fmt, ...)
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. "[ctxdiag] " .. tostring(line or fmt) .. "\n"); f:close() end
end

local api = _G.api
local NPC, Entity, Heroes = _G.NPC, _G.Entity, _G.Heroes
local NPCs = _G.NPCs or {}
local GameRules = _G.GameRules

local step = 0
local function tick()
  step = step + 1
  local hero = Heroes and Heroes.GetLocal()
  if not hero then L("tick %d: no local hero", step); return end
  local hpos = Entity.GetAbsOrigin(hero)
  local all = (NPCs.GetAll and NPCs.GetAll()) or {}
  local nAll = #all
  local lane, visible, dormant, sameTeam, inRange2400 = 0, 0, 0, 0, 0
  local sample = {}
  for i, u in ipairs(all) do
    local dn = NPC.GetUnitName(u) or "?"
    if dn:find("npc_dota_creep_lane") then
      lane = lane + 1
      local d = Entity.IsDormant(u)
      if d then dormant = dormant + 1 else visible = visible + 1 end
      local same = Entity.IsSameTeam(hero, u)
      if same then sameTeam = sameTeam + 1 end
      local p = Entity.GetAbsOrigin(u)
      local dist = math.sqrt((p.x - hpos.x) ^ 2 + (p.y - hpos.y) ^ 2)
      if dist < 2400 then inRange2400 = inRange2400 + 1 end
      if #sample < 5 then
        sample[#sample + 1] = string.format("%s dorm=%s vis=%s same=%s dist=%.0f",
          dn, tostring(d), tostring(NPC.IsVisible(u)), tostring(same), dist)
      end
    end
  end
  L("tick %d: npcs=%d laneCreeps=%d dormant=%d visible=%d sameTeam=%d within2400=%d hero=%s",
    step, nAll, lane, dormant, visible, sameTeam, inRange2400, NPC.GetUnitName(hero) or "?")
  for _, s in ipairs(sample) do L("   %s", s) end
  -- also: what the Self Play scan would put into ctx.creeps (same filters)
  local scanCreeps = 0
  for _, u in ipairs(all) do
    if not Entity.IsDormant(u) then
      local p = Entity.GetAbsOrigin(u)
      local dist = math.sqrt((p.x - hpos.x) ^ 2 + (p.y - hpos.y) ^ 2)
      local same = Entity.IsSameTeam(hero, u)
      if NPC.IsLaneCreep(u) and dist < 2400 then scanCreeps = scanCreeps + 1 end
    end
  end
    L("   selfplay-scan creeps=%d", scanCreeps)
  local ent = package.loaded["entity"] or require("entity")
  local okInit, errInit = ent.init()
  local st = ent.debugStats and ent.debugStats() or {}
  if ent.debugNames and step % 2 == 1 then
    local dn = ent.debugNames(6)
    L("   names total=%d named=%d npc=%d", dn.total, dn.named, dn.npc)
    for _, s in ipairs(dn.sample) do L("      sample name=%s", tostring(s.name)) end
  end
  if ent.debugStrings and step % 2 == 1 then
    local hits = ent.debugStrings(hero, 0x200, 8)
    L("   identity npc_ strings at %d offsets", #hits)
    for i = 1, math.min(#hits, 6) do L("      identity+0x%X -> %s", hits[i].off, hits[i].s) end
  end
  L("   entity.init ok=%s err=%s head=0x%X list=%d tickDriven=%s caching=%s builds=%s",
    tostring(okInit), tostring(errInit), tonumber(st.head) or 0, tonumber(st.list) or 0,
    tostring(st.tickDriven), tostring(st.caching),
    tostring(st.stats and st.stats.tickBuilds))
end

L("=== ctxdiag start (hero=%s) ===", tostring(Heroes and Heroes.GetLocal()))
while true do
  local ok, err = pcall(tick)
  if not ok then L("tick error: %s", tostring(err)) end
  local stop = io.open("D:\\hake\\lotus\\stop.txt", "r")
  if stop then stop:close(); L("stop.txt seen, exiting"); break end
  -- 100 ms poll, report ~1/s
  local t0 = os.clock()
  while os.clock() - t0 < 1 do end
end

