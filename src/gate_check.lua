package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local loader = require("loader")
local menu = require("menu")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
loader.load()
local enabled = false
for _, w in ipairs(menu.widgets) do
  if w.kind == "switch" and w.name and w.name:find("Enable Self Play") then
    w.value = true
    enabled = true
    log("found widget", w.name, "value", w:Get())
  end
end
if not enabled then log("NO Enable Self Play widget found") end
log("=== GATE CHECK ===")
log("Engine.IsInGame", Engine.IsInGame())
log("GameRules.GetGameState", GameRules.GetGameState())
log("GameRules.IsPaused", GameRules.IsPaused())
log("Heroes.GetLocal", Heroes.GetLocal())
log("Players.GetLocal", Players.GetLocal())
local h = Heroes.GetLocal()
log("Entity.IsEntity(hero)", h and Entity.IsEntity(h) or "no hero")
log("=== GATE CHECK done ===")
