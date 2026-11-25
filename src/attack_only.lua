package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local entity = require("entity")
local orders = require("orders")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function i32(p, o) return tonumber(ffi.cast("int32_t*", p + o)[0]) end
log("=== ATTACK ONLY ===")
entity.init(); orders.init()
local h = entity.getLocalHero()
local hx, hy, hz = orders.heroPosition(h.instance)
local team = entity.team(h.identity)
local enemy
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if (dn:find("npc_dota_creep") or dn:find("npc_dota_hero_")) and not dn:find("announcer") and idn ~= h.identity and entity.team(idn) ~= team then
    local inst = entity.instance(idn)
    local x, y, z = orders.heroPosition(inst)
    if x then
      local d = math.sqrt((x - hx) ^ 2 + (y - hy) ^ 2)
      if d > 300 and d < 2500 and (not enemy or d < enemy.d) then
        enemy = { idn = idn, x = x, y = y, z = z, d = d, dn = dn }
      end
    end
  end
end
if not enemy then
  for idn in entity.iter() do
    local dn = entity.designerName(idn) or ""
    if dn:find("npc_dota_creep") and entity.team(idn) ~= team then
      local inst = entity.instance(idn)
      local x, y, z = orders.heroPosition(inst)
      if x then
        local d = math.sqrt((x - hx) ^ 2 + (y - hy) ^ 2)
        if not enemy or d < enemy.d then enemy = { idn = idn, x = x, y = y, z = z, d = d, dn = dn } end
      end
    end
  end
end
if not enemy then log("no enemy"); return end
local handle = i32(enemy.idn, 0x10)
local idx = handle % 0x8000; if idx < 0 then idx = idx + 0x8000 end
log(string.format("enemy %s dist=%.0f at %.0f %.0f idx=%d", enemy.dn, enemy.d, enemy.x, enemy.y, idx))
log(string.format("hero at %.0f %.0f", hx, hy))
local ok = orders.prepare(4, idx, { enemy.x, enemy.y, enemy.z }, 0, h.instance, false, true)
log("attack", tostring(ok))
ffi.C.Sleep(1500)
local x, y = orders.heroPosition(entity.getLocalHero().instance)
local dx, dy = x - hx, y - hy
local toward = ((enemy.x - hx) * dx + (enemy.y - hy) * dy) / math.max(1, enemy.d)
log(string.format("after %.0f %.0f moved %.0f toward %.0f", x, y, math.sqrt(dx*dx+dy*dy), toward))
log("=== ATTACK ONLY done ===")
