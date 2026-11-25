local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[ctx] " .. tostring(s or fmt) .. "\n"); f:flush() end end
ffi = require("ffi")
local ok, script, err = pcall(loader.load)
L("loader.load ok=%s err=%s", tostring(ok), tostring(err))
if not ok then return end
-- let the script build its context
for i = 1, 40 do
  pcall(loader.tick)
  ffi.C.Sleep(50)
end
local okH, helpers = pcall(require, "self_play.helpers")
L("require helpers ok=%s err=%s", tostring(okH), tostring(helpers))
if not okH then return end
local ctxs = helpers.contexts()
L("contexts=%d", #ctxs)
for i, ctx in ipairs(ctxs) do
  local hp = ctx.position
  L("ctx[%d] role=%s lane=%s now=%.1f hero=%s pos=%.0f,%.0f", i, tostring(ctx.role), tostring(ctx.lane),
    tonumber(ctx.now) or -1, tostring(ctx.hero and NPC.GetUnitName(ctx.hero) or "nil"),
    hp and hp.x or 0, hp and hp.y or 0)
  for lane = 1, 3 do
    local w = ctx.waves and ctx.waves[lane]
    L("   waves[%d]=%d%s", lane, type(w) == "table" and #w or -1, (type(w) == "table" and #w > 0) and
      (" first=" .. string.format("%.0f,%.0f", Entity.GetAbsOrigin(w[1]).x, Entity.GetAbsOrigin(w[1]).y)) or "")
  end
  L("   creeps=%d enemies=%d allies=%d candidateCount=%s hits.confirmed=%s",
    #(ctx.creeps or {}), #(ctx.enemies or {}), #(ctx.allies or {}),
    tostring(ctx.hits and ctx.hits.candidateCount), tostring(ctx.hits and ctx.hits.confirmed))
  local anchor = helpers.rawLaneAnchor and helpers.rawLaneAnchor(ctx)
  L("   rawLaneAnchor=%s", anchor and string.format("%.0f,%.0f", anchor.x, anchor.y) or "nil")
end
L("done")
