package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local entity = require("entity")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== HERO DUMP ===")
local ok, err = entity.init()
log("init", tostring(ok), tostring(err))
local oIsLocal = schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController")
local oAssigned = schema.offsetOf("C_DOTAPlayerController", "m_hAssignedHero") or 2324
local oPid = schema.offsetOf("C_DOTAPlayerController", "m_nPlayerID")
local oHeroPID = schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iPlayerID")
log("offs", "isLocal", oIsLocal, "assigned", oAssigned, "pid", oPid, "heroPid", oHeroPID)
local n, nctrl, nhero, nlocal = 0, 0, 0, 0
local names = {}
for idn in entity.iter() do
  n = n + 1
  local dn = entity.designerName(idn) or ""
  if n <= 8 then names[#names+1] = dn end
  if dn:find("player_controller") then
    nctrl = nctrl + 1
    local inst = entity.instance(idn)
    local isLocal = inst and tonumber(ffi.cast("uint8_t*", inst + oIsLocal)[0]) or -1
    if isLocal == 1 then nlocal = nlocal + 1 end
    if nctrl <= 12 then
      local pid = inst and tonumber(ffi.cast("int32_t*", inst + oPid)[0]) or -1
      local ah = inst and tonumber(ffi.cast("int32_t*", inst + oAssigned)[0]) or -1
      log(string.format("ctrl %s local=%s pid=%s assigned=%s inst=%s", dn, tostring(isLocal), tostring(pid), tostring(ah), tostring(inst)))
    end
  end
  if dn:find("npc_dota_hero_") and not dn:find("announcer") then
    nhero = nhero + 1
    if nhero <= 12 then
      local inst = entity.instance(idn)
      local pid = inst and tonumber(ffi.cast("int32_t*", inst + oHeroPID)[0]) or -1
      local hp = entity.health(idn)
      log(string.format("hero %s pid=%s hp=%s", dn, tostring(pid), tostring(hp)))
    end
  end
end
log("counts", "ents", n, "ctrl", nctrl, "local", nlocal, "heroes", nhero)
log("first", table.concat(names, " | "))
log("getLocalHero", tostring((entity.getLocalHero() or {}).name))
log("=== HERO DUMP done ===")
