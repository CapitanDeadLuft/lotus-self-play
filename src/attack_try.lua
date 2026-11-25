package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local entity = require("entity")
local orders = require("orders")
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function ri32(p, o) return tonumber(ffi.cast("int32_t*", p + o)[0]) end
log("=== ATTACK TRY3 ===")
entity.init(); orders.init()
local h = entity.getLocalHero()
local hx, hy, hz = orders.heroPosition(h.instance)
local team = entity.team(h.identity)
log(string.format("hero %s team=%s at %.0f %.0f", h.name, tostring(team), hx, hy))
local enemy, ally
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn:find("npc_dota_creep_lane") or (dn:find("npc_dota_hero_") and not dn:find("announcer") and idn ~= h.identity) then
    local inst = entity.instance(idn)
    local x, y, z = orders.heroPosition(inst)
    if x then
      local d = math.sqrt((x - hx) ^ 2 + (y - hy) ^ 2)
      local t = entity.team(idn)
      local rec = { idn = idn, x = x, y = y, z = z, d = d, dn = dn, team = t }
      if t ~= team and d > 150 and (not enemy or d < enemy.d) then enemy = rec end
      if t == team and dn:find("creep") and d > 150 and (not ally or d < ally.d) then ally = rec end
    end
  end
end
local function idxOf(idn)
  local handle = ri32(idn, 0x10)
  local idx = handle % 0x8000
  if idx < 0 then idx = idx + 0x8000 end
  return idx, handle
end
local function pos()
  local x, y = orders.heroPosition(entity.getLocalHero().instance)
  return x, y
end
local function moved(tag, x0, y0)
  ffi.C.Sleep(800)
  local x, y = pos()
  log(string.format("%s %.0f %.0f delta %.0f", tag, x, y, math.sqrt((x-x0)^2+(y-y0)^2)))
  return x, y
end
if enemy then
  local idx, handle = idxOf(enemy.idn)
  log(string.format("enemy %s team=%s dist=%.0f idx=%d handle=%s", enemy.dn, tostring(enemy.team), enemy.d, idx, tostring(handle)))
else log("no enemy") end
if ally then log(string.format("ally creep %s dist=%.0f", ally.dn, ally.d)) end
-- control: position move 400 units toward enemy or +400
local tx, ty = hx + 400, hy + 200
if enemy then
  local k = 400 / math.max(enemy.d, 1)
  tx, ty = hx + (enemy.x - hx) * k, hy + (enemy.y - hy) * k
end
log("pos-move", tostring(orders.prepare(1, 0, { tx, ty, hz }, 0, h.instance, false, true)))
local x1, y1 = moved("after pos", hx, hy)
if enemy then
  local idx = idxOf(enemy.idn)
  log("attack enemy", tostring(orders.prepare(4, idx, { enemy.x, enemy.y, enemy.z }, 0, h.instance, false, true)))
  moved("after attack", x1, y1)
end
log("=== ATTACK TRY3 done ===")
