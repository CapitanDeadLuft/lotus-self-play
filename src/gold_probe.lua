package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local entity = require("entity")
local orders = require("orders")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function i32(p, o) return tonumber(ffi.cast("int32_t*", p + o)[0]) end
local function u64(p, o) return tonumber(ffi.cast("uintptr_t*", p + o)[0]) end
entity.init(); orders.init()
local ctrl = orders.localController()
local pid = ctrl and i32(ctrl, 2320) or -1
log("=== GOLD2 === pid", pid)
for idn in entity.iter() do
  local dn = entity.designerName(idn) or ""
  if dn == "player" or dn == "dota_data_radiant" or dn == "dota_data_dire" then
    local inst = entity.instance(idn)
    for _, off in ipairs({ 0x5F0, 0x608, 0x670 }) do
      local cnt = i32(inst + off, 0)
      local ptr = u64(inst + off, 8)
      if cnt > 0 and cnt <= 24 and ptr and ptr > 0x10000 then
        local rec = ptr + math.max(0, pid) * 0x12F0
        local rel = i32(rec, 0x30)
        local unrel = i32(rec, 0x34)
        local earned = i32(rec, 0x3C)
        log(string.format("%s +0x%X cnt=%d ptr=0x%X rel=%s unrel=%s earned=%s", dn, off, cnt, ptr, tostring(rel), tostring(unrel), tostring(earned)))
        -- first few records gold
        if cnt >= 2 then
          log(string.format("  r0 rel=%d unrel=%d r1 rel=%d unrel=%d",
            i32(ptr, 0x30), i32(ptr, 0x34), i32(ptr + 0x12F0, 0x30), i32(ptr + 0x12F0, 0x34)))
        end
      else
        log(string.format("%s +0x%X cnt=%s ptr=%s", dn, off, tostring(cnt), tostring(ptr and string.format("0x%X", ptr) or "nil")))
      end
    end
  end
end
log("=== GOLD2 done ===")
