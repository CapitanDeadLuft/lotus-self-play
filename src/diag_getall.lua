require("loader")
local ent = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[getall] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local n = 0
for idn in ent.iter() do n = n + 1 end
local e = Entities.GetAll() or {}
local npcs = NPCs.GetAll() or {}
local dn = ent.debugNames(3)
L("iter=%d Entities.GetAll=%d NPCs.GetAll=%d debugNames.total=%d named=%d", n, #e, #npcs, dn.total, dn.named)
-- manual replication of loader NPCs.GetAll filter
local m, na = 0, 0
for idn in ent.iter() do
  local name = ent.designerName(idn)
  if name then na = na + 1; if name:find("npc_dota") then m = m + 1 end end
end
L("manual: named=%d npc_dota=%d", na, m)
-- how many are lane creeps by name
local lane = 0
for idn in ent.iter() do
  local name = ent.designerName(idn) or ""
  if name:find("npc_dota_creep_lane") then lane = lane + 1 end
end
L("lane creeps by name=%d", lane)
L("done")
