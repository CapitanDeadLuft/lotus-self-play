package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local loader = require("loader")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}; for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== GATE ===")
local script = loader.load()
if not script then log("load fail"); return end
log("Engine.IsInGame =", Engine.IsInGame())
log("GameRules.IsPaused =", GameRules.IsPaused())
log("GameRules.GetGameState =", GameRules.GetGameState())
log("GameState.PRE_GAME =", Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME, "IN_PROGRESS =", Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS)
log("GameRules.GetGameTime =", GameRules.GetGameTime())
local h = Heroes.GetLocal()
local p = Players.GetLocal()
log("Heroes.GetLocal =", h, h and Entity.GetClassName(h) or "")
log("Players.GetLocal =", p)
log("Entity.IsEntity(hero) =", h and Entity.IsEntity(h) or "nohero")
log("=== GATE done ===")