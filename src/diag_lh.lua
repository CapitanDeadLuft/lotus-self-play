local ffi = require("ffi")
local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[lh] " .. tostring(s or fmt) .. "\n"); f:flush() end end
local ok, script, err = pcall(loader.load)
L("load ok=%s err=%s", tostring(ok), tostring(err))
if not ok then return end
for i = 1, 6 do ffi.C.Sleep(150); pcall(loader.tick) end
-- locate ctx through OnUpdate upvalues
local ctx
if type(script) == "table" and type(script.OnUpdate) == "function" then
  local i = 1
  while true do
    local name, val = debug.getupvalue(script.OnUpdate, i)
    if not name then break end
    if type(val) == "table" and type(val.ctx) == "table" then ctx = val.ctx; L("ctx via upvalue %s", name); break end
    i = i + 1
  end
end
if not ctx then L("no ctx"); return end
local lh = package.loaded["self_play.last_hit"]
L("ctx.hero=%s lane=%s role=%s pos=%.0f,%.0f creeps=%d", tostring(ctx.hero and NPC.GetUnitName(ctx.hero)),
  tostring(ctx.lane), tostring(ctx.role), ctx.position and ctx.position.x or 0, ctx.position and ctx.position.y or 0, #(ctx.creeps or {}))
if lh and lh.plan then
  local okp, res = pcall(lh.plan, ctx)
  L("plan ok=%s cand=%s farm=%s", tostring(okp), tostring(ctx.hits and ctx.hits.candidateCount),
    tostring(ctx.farmCandidate and ctx.farmCandidate.target and NPC.GetUnitName(ctx.farmCandidate.target)))
end
local shown = 0
for _, c in ipairs(ctx.creeps or {}) do
  if shown < 5 then
    shown = shown + 1
    local cp = Entity.GetAbsOrigin(c)
    local d = (cp and ctx.position) and math.sqrt((cp.x - ctx.position.x)^2 + (cp.y - ctx.position.y)^2) or -1
    local same = Entity.IsSameTeam(ctx.hero, c)
    local tOk, delay = false, nil
    if lh and lh.timing then tOk, delay = pcall(lh.timing, ctx, c) end
    L("  creep %s dist=%.0f same=%s hp=%.0f/%.0f vis=%s alive=%s hide=%s timing(ok=%s d=%s)",
      NPC.GetUnitName(c), d, tostring(same), Entity.GetHealth(c) or -1, Entity.GetMaxHealth(c) or -1,
      tostring(NPC.IsVisible(c)), tostring(Entity.IsAlive(c)), tostring(Entity.IsDormant(c)),
      tostring(tOk), tostring(delay))
  end
end
L("done")
