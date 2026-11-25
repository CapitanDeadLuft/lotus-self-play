require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(s) if f then f:write(os.date("%H:%M:%S ") .. "[names] " .. s .. "\n"); f:flush() end end
local counts, order = {}, {}
local all = NPCs.GetAll() or {}
for _, u in ipairs(all) do
  local dn = NPC.GetUnitName(u) or "?"
  counts[dn] = (counts[dn] or 0) + 1
  if counts[dn] == 1 then order[#order + 1] = dn end
end
L("NPCs.GetAll n=" .. #all)
table.sort(order, function(a, b) return (counts[a] or 0) > (counts[b] or 0) end)
for i = 1, math.min(#order, 25) do L(string.format("  %-42s x%d isLaneCreep=%s isCreep=%s isNeutral=%s", order[i], counts[order[i]],
  tostring(NPC.IsLaneCreep(NPC.GetAll()[1] and order[i] and nil or nil)), "-", "-")) end
-- simpler: flag each name with our predicates using a fresh entity lookup by name
for i = 1, math.min(#order, 25) do
  local nm = order[i]
  local ent
  for _, u in ipairs(all) do if (NPC.GetUnitName(u) or "?") == nm then ent = u; break end end
  if ent then L(string.format("  %-42s x%-3d lane=%s creep=%s neutral=%s ranged=%s", nm, counts[nm],
    tostring(NPC.IsLaneCreep(ent)), tostring(NPC.IsCreep(ent)), tostring(NPC.IsNeutral(ent)), tostring(NPC.IsRanged(ent)))) end
end
L("done")
