local loader = require("loader")
local ffi = require("ffi")
local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...) local ok, s = pcall(string.format, fmt, ...) if f then f:write(os.date("%H:%M:%S ") .. "[cast] " .. tostring(s or fmt) .. "\n"); f:flush() end end
pcall(loader.tick)
local hero = Heroes.GetLocal()
local player = Players.GetLocal()
if not hero or not player then L("no hero/player"); return end
local function manaOf() local ok, m = pcall(NPC.GetMana, hero); return ok and m or -1 end
local function cdRaw(a) local ok, r = pcall(Ability.__cdRaw, a); return ok and tostring(r) or "err" end
local og = NPC.GetAbility(hero, "treant_overgrowth")
local la = NPC.GetAbility(hero, "treant_living_armor")
L("overgrowth=%s livingArmor=%s mana=%.0f", tostring(og ~= nil), tostring(la ~= nil), manaOf())
L("before og cd=%s la cd=%s", cdRaw(og), cdRaw(la))
local ok1 = Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, Vector(0, 0, 0), og,
  Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false)
L("overgrowth order ok=%s", tostring(ok1))
ffi.C.Sleep(500)
L("after og mana=%.0f og cd=%s", manaOf(), cdRaw(og))
local ok2 = Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, hero, Vector(0, 0, 0), la,
  Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false)
L("livingArmor order ok=%s", tostring(ok2))
ffi.C.Sleep(600)
L("after la mana=%.0f la cd=%s", manaOf(), cdRaw(la))
L("done")
