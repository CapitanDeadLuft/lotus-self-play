local loader = require("loader")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[aspd2] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
if not hero then L("no hero"); return end
local b, t, g, ob, ot, oa = NPC.__aspdDebug(hero)
L("hero base=%s bat=%s agi=%s offs(base=0x%X bat=0x%X agi=0x%X)", tostring(b), tostring(t), tostring(g), ob or 0, ot or 0, oa or 0)
L("GetAttackSpeed=%s secAtk=%s (expected secAtk ~ bat*100/(100+agi))", tostring(NPC.GetAttackSpeed(hero)), tostring(NPC.GetSecondsPerAttack(hero)))
if b and t and g then L("computed secAtk = %.3f", t * 100 / (b + g)) end
L("done")
