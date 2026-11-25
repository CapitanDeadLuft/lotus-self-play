local loader = require("loader")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[tower] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local dnSeen, unSeen = {}, {}
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  local un = NPC.GetUnitName(idn) or ""
  local interesting = dn:find("tower", 1, true) or dn:find("fort", 1, true) or dn:find("barracks", 1, true)
    or un:find("tower", 1, true) or un:find("fort", 1, true) or un:find("barracks", 1, true)
  if interesting then
    local key = dn .. " | " .. un
    if not dnSeen[key] then
      dnSeen[key] = true
      L("designer=%s unit=%s team=%s isTower=%s isStructure=%s", dn, un, tostring(Entity.GetTeamNum(idn)),
        tostring(NPC.IsTower(idn)), tostring(NPC.IsStructure(idn)))
    end
  end
end
L("done (%d distinct)", (function() local c = 0 for _ in pairs(dnSeen) do c = c + 1 end return c end)())
