local loader = require("loader")
local ffi = require("ffi")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[ctx1] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local ok, script, err = pcall(loader.load)
L("load ok=%s err=%s", tostring(ok), tostring(err))
if not ok then return end
L("tick 1 start")
local t0 = os.clock()
pcall(loader.tick)
L("tick 1 done %.1fs", os.clock() - t0)
for i = 1, 3 do ffi.C.Sleep(60); pcall(loader.tick) end
L("warm done")
local okH, helpers = pcall(require, "self_play.helpers")
L("helpers ok=%s", tostring(okH))
if not okH then return end
local ctxs = helpers.contexts()
L("contexts=%d", #ctxs)
for i, ctx in ipairs(ctxs) do
  local hp = ctx.position
  L("ctx[%d] active=%s role=%s lane=%s now=%.1f hero=%s pos=%.0f,%.0f", i, tostring(ctx.active), tostring(ctx.role), tostring(ctx.lane),
    tonumber(ctx.now) or -1, tostring(ctx.hero and NPC.GetUnitName(ctx.hero) or "nil"), hp and hp.x or 0, hp and hp.y or 0)
  for lane = 1, 3 do
    local w = ctx.waves and ctx.waves[lane]
    local n = type(w) == "table" and #w or -1
    local d1, d2 = -1, -1
    if n > 0 then
      local p, hpp = Entity.GetAbsOrigin(w[1]), ctx.position
      if p and hpp then d1 = math.sqrt((p.x - hpp.x)^2 + (p.y - hpp.y)^2) end
    end
    local e = ctx.enemyWaves and ctx.enemyWaves[lane]
    L("   lane%d allies=%d firstDist=%.0f enemyWaves=%s", lane, n, d1, tostring(type(e) == "table" and #e or "nil"))
  end
  L("   creeps=%d enemies=%d allies=%d candidates=%s anchor=%s", #(ctx.creeps or {}), #(ctx.enemies or {}), #(ctx.allies or {}),
    tostring(ctx.hits and ctx.hits.candidateCount), tostring(ctx.laneGoal and "goal" or "nil"))
  local minD = 1e9
  for _, c in ipairs(ctx.creeps or {}) do
    local p = Entity.GetAbsOrigin(c)
    if p and ctx.position then
      local d = math.sqrt((p.x - ctx.position.x)^2 + (p.y - ctx.position.y)^2)
      if d < minD then minD = d end
    end
  end
  L("   nearestCreepDist=%.0f", minD)
end
L("done")
