package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local entity = require("entity")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
entity.init()
local seen = {}
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn ~= "" and not dn:find("^npc_") and not dn:find("^item_") and not seen[dn] then
    seen[dn] = true
  end
end
local names = {}
for n in pairs(seen) do names[#names+1] = n end
table.sort(names)
log("=== NAMES", #names, "===")
for _, n in ipairs(names) do
  if n:find("dota") or n:find("player") or n:find("resource") or n:find("team") or n:find("data") then
    log(n)
  end
end
log("=== NAMES done ===")
