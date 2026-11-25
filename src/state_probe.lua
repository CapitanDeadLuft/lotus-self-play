package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local entity = require("entity")
local schema = require("schema")
local orders = require("orders")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== STATE PROBE ===")
local ok, err = entity.init()
log("entity.init", ok, err)
log("schema isLocal", schema.offsetOf("CBasePlayerController", "m_bIsLocalPlayerController"))
log("schema heroPID", schema.offsetOf("C_DOTA_BaseNPC_Hero", "m_iPlayerID"))
local ok2, err2 = orders.init()
log("orders.init", ok2, err2)
local h = entity.getLocalHero()
log("hero", h and h.name or "nil", h and h.health or "-")
local c = orders.localController()
log("ctrl", c)
log("state", GameRules and GameRules.GetGameState and GameRules.GetGameState() or "noapi")
log("=== STATE PROBE done ===")
