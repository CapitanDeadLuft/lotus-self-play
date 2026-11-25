local loader = require("loader")
local ffi = require("ffi")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[cd] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local a = NPC.GetAbility(hero, "treant_living_armor")
L("living_armor found=%s", tostring(a ~= nil))
for i = 1, 12 do
  local ok, raw, gt, len, phase, castStart = pcall(Ability.__cdRaw, a)
  L("t%d raw=%s gt=%.2f len=%s phase=%s castStart=%s IsReady=%s GetCd=%.2f", i, tostring(raw), gt or -1,
    tostring(len), tostring(phase), tostring(castStart), tostring(Ability.IsReady(a)), Ability.GetCooldown(a) or -1)
  ffi.C.Sleep(1000)
end
L("done")
