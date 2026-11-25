require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[items] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local hero = Heroes.GetLocal()
local n, mine, named = 0, 0, 0
local samples = 0
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn:sub(1, 5) == "item_" then
    n = n + 1
    local own = Entity.GetOwner(idn)
    if own == hero then mine = mine + 1 end
    if samples < 8 then
      samples = samples + 1
      L("  %s owner=%s hero?=%s", dn, own and (NPC.GetUnitName(own) or "(noname)") or "nil", tostring(own == hero))
    end
  end
end
L("items in world=%d ownedByHero=%d", n, mine)
L("done")
