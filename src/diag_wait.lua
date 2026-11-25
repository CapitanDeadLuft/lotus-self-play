require("loader")
local schema = require("schema")
local entity = require("entity")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[wait] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local ok, off, err = pcall(schema.offsetOf, "C_DOTA_BaseNPC", "m_bIsWaitingToSpawn")
L("schema.offsetOf m_bIsWaitingToSpawn ok=%s off=%s err=%s", tostring(ok), tostring(off), tostring(err))
local shown = 0
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn:find("creep", 1, true) and not dn:find("neutral", 1, true) then
    local inst = entity.instance(idn)
    if inst then
      local b1730 = entity.debugReadQ(inst, 0x1730)
      local b17a8 = entity.debugReadQ(inst, 0x17A8)
      local d1730 = b1730 and (b1730 % 256) or nil
      local d17a8 = b17a8 and (b17a8 % 256) or nil
      if shown < 10 then
        shown = shown + 1
        L("  %s team=%s @0x1730=%s @0x17A8=%s IsWaitingToSpawn=%s", dn,
          tostring(Entity.GetTeamNum(idn)), tostring(d1730), tostring(d17a8), tostring(NPC.IsWaitingToSpawn(idn)))
      end
    end
  end
end
L("done")
