package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local loader = require("loader")
local entity = require("entity")
local menu = require("menu")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}; for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
log("=== DIAG ===")
local script, err = loader.load()
if not script then log("LOAD FAILED:", err); return end
log("switch widgets:")
for _, w in ipairs(menu.widgets) do
  if w.kind == "switch" then log("  switch: [" .. tostring(w.name) .. "] = " .. tostring(w.value)) end
end
local ok, h = pcall(entity.getLocalHero)
log("getLocalHero:", ok, h and h.name or "nil", h and h.health or "")
local ok2, st = pcall(function() return require("api") end)
local n = 0; for _ in entity.iter() do n = n + 1 end
log("entity count:", n)
log("=== DIAG done ===")