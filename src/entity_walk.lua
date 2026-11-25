-- entity_walk.lua — traverse CEntityIdentity linked list (m_pNext@0x58) from gamerules identity.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local schema = require("schema")
local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function hex(v) return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v))) end
ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  typedef struct { void* BaseAddress; void* AllocationBase; unsigned long AllocProtect;
                   size_t RegionSize; unsigned long State; unsigned long Protect; unsigned long Type; } MBI;
  size_t VirtualQuery(const void* addr, MBI* mbi, size_t len);
]]
local function readable(p, n)
  if p == nil then return false end
  local a = ffi.cast("uintptr_t", p)
  if a < 0x10000 or a > 0x7FFFFFFFFFFF then return false end
  local mbi = ffi.new("MBI")
  if C.VirtualQuery(p, mbi, ffi.sizeof(mbi)) == 0 then return false end
  if mbi.State ~= 0x1000 then return false end
  local prot = tonumber(mbi.Protect)
  if not (prot == 0x02 or prot == 0x04 or prot == 0x08 or prot == 0x20 or prot == 0x40) then return false end
  return (a + (n or 8)) <= (ffi.cast("uintptr_t", mbi.BaseAddress) + mbi.RegionSize)
end
local function rq(p, off)
  local addr = ffi.cast("uintptr_t", p) + (off or 0)
  if not readable(ffi.cast("void*", addr), 8) then return nil end
  return tonumber(ffi.cast("uintptr_t*", addr)[0])
end
local function ri32(p, off)
  local addr = ffi.cast("uintptr_t", p) + (off or 0)
  if not readable(ffi.cast("void*", addr), 4) then return nil end
  return tonumber(ffi.cast("int32_t*", addr)[0])
end
local function rs(p)
  if not readable(p, 1) then return nil end
  local ok, s = pcall(ffi.string, p, 80); if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end
local function designerOf(idn)
  if not idn then return nil end
  local sp = rq(idn, 0x20); if not sp then return nil end
  return rs(ffi.cast("void*", sp))
end
schema.init()
local oHealth = schema.offsetOf("C_BaseEntity", "m_iHealth") or 0x34C
local oTeam   = schema.offsetOf("C_BaseEntity", "m_iTeamNum") or 0x3E7
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
log("=== entity WALK === client =", hex(client))

-- gamerules global -> proxy entity(+0x08) -> identity(+0x10)
local gr = rq(cb + 0x6219008, 0)
local proxy = rq(gr, 0x08)
local seed = rq(proxy, 0x10)
log("gamerules identity seed =", hex(seed), "designer =", designerOf(seed) or "?")
if not seed then log("no seed"); return end
-- verify identity back-pointer +0x00 -> instance
log("seed+0x00 (back-ptr?) =", hex(rq(seed, 0)), " (proxy was " .. hex(proxy) .. ")")

-- walk to head via m_pPrev@0x50
local head = seed
for i = 1, 4096 do
  local prev = rq(head, 0x50)
  if not prev or prev == 0 or not readable(ffi.cast("void*", prev), 0x70) then break end
  head = prev
end
log("list head =", hex(head), "designer =", designerOf(head) or "?")

-- traverse m_pNext@0x58
local cur = head
local count, heroes, npcs = 0, 0, 0
local seen = {}
while cur and cur ~= 0 and count < 8192 do
  if seen[cur] then log("cycle detected at", hex(cur)); break end
  seen[cur] = true
  if not readable(ffi.cast("void*", cur), 0x70) then break end
  count = count + 1
  local dn = designerOf(cur)
  local inst = rq(cur, 0x0)   -- back-pointer to CEntityInstance
  local hp, team = nil, nil
  if inst and readable(ffi.cast("void*", inst), oHealth + 4) then
    hp = ri32(inst, oHealth); team = ri32(inst, oTeam)
  end
  if dn and dn:find("npc_dota_hero") then
    heroes = heroes + 1
    if heroes <= 12 then log(string.format("  HERO %s inst=%s hp=%s team=%s", dn, hex(inst), tostring(hp), tostring(team))) end
  elseif dn and dn:find("npc_dota") then
    npcs = npcs + 1
    if npcs <= 12 then log(string.format("  NPC %s hp=%s team=%s", dn, tostring(hp), tostring(team))) end
  end
  cur = rq(cur, 0x58)
end
log(string.format("WALK total=%d heroes=%d npcs=%d", count, heroes, npcs))
log("=== entity WALK done ===")