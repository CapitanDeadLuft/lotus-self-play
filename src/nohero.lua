package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local loader = require("loader")
local entity = require("entity")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}; for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function ru8(p,o) if not p then return nil end; local a=p+o; if a<0x10000 or a>0x7FFFFFFFFFFF then return nil end; return tonumber(ffi.cast("uint8_t*",a)[0]) end
local function ri32(p,o) if not p then return nil end; local a=p+o; if a<0x10000 or a>0x7FFFFFFFFFFF then return nil end; return tonumber(ffi.cast("int32_t*",a)[0]) end
log("=== NOHERO DIAG ===")
local script = loader.load()
if not script then log("load fail"); return end
local oIsLocal = schema.offsetOf("CBasePlayerController","m_bIsLocalPlayerController")
local oCtrlPID = schema.offsetOf("C_DOTAPlayerController","m_nPlayerID")
local oHeroPID = schema.offsetOf("C_DOTA_BaseNPC_Hero","m_iPlayerID")
local function snap(tag)
  local nctrl, nhero, localFound = 0, 0, false
  for idn in entity.iter() do
    local dn = entity.designerName(idn) or ""
    local inst = entity.instance(idn)
    if dn:find("player_controller") then
      nctrl = nctrl + 1
      local il = ru8(inst, oIsLocal)
      if il == 1 then localFound = true; log(tag.." LOCAL ctrl pid="..tostring(ri32(inst,oCtrlPID))) end
    end
    if dn:find("npc_dota_hero_") and not dn:find("announcer") then
      nhero = nhero + 1
      if nhero <= 3 then log(tag.." hero "..dn.." pid="..tostring(ri32(inst,oHeroPID))) end
    end
  end
  log(tag.." controllers="..nctrl.." heroes="..nhero.." localFound="..tostring(localFound))
end
snap("BEFORE")
loader.tick()
snap("AFTER")
log("=== NOHERO DIAG done ===")