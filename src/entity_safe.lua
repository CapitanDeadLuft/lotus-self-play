-- entity_safe.lua — guarded in-game entity reader: chunked list, identity->instance, hero fields.
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
local function designer(idn)
  if idn == nil then return nil end
  local sp = rq(idn, 0x20); if sp == nil then return nil end
  return rs(ffi.cast("void*", sp))
end

schema.init()
local oHealth = schema.offsetOf("C_BaseEntity", "m_iHealth") or 0x34C
local oTeam   = schema.offsetOf("C_BaseEntity", "m_iTeamNum") or 0x3E7
local client = C.GetModuleHandleA("client.dll")
local cb = ffi.cast("uintptr_t", client)
log("=== entity SAFE (in-game) === client =", hex(client))

local lcPtr = rq(cb + 0x6219008, 0)
log("dwLocalPlayerController =", hex(lcPtr))
if lcPtr then
  local idn = rq(lcPtr, 0x10)
  log("  local controller designer =", designer(idn) or "?")
end

local elPtr = rq(cb + 0x662FFE8, 0)
log("dwEntityList head =", hex(elPtr))
if not elPtr then log("no entity list"); return end

-- chunk array: elPtr -> [chunk0, chunk1, ...]; find first non-null chunk
local totalHeroes, totalNpcs = 0, 0
for ci = 0, 63 do
  local chunk = rq(elPtr, ci * 8)
  if chunk and readable(ffi.cast("void*", chunk), 0x40) then
    -- try identity pointer array within chunk (stride 8)
    local found = 0
    for ei = 0, 511 do
      local idn = rq(chunk, ei * 8)
      local dn = designer(idn)
      if dn then
        found = found + 1
        -- identity->instance back-pointer at identity+0x00
        local inst = rq(idn, 0x0)
        local hp, team = nil, nil
        if inst and readable(ffi.cast("void*", inst), oHealth + 4) then
          hp = ri32(inst, oHealth); team = ri32(inst, oTeam)
        end
        if dn:find("npc_dota_hero") then
          totalHeroes = totalHeroes + 1
          if totalHeroes <= 12 then
            log(string.format("  HERO chunk%d[%d] %s inst=%s hp=%s team=%s", ci, ei, dn, hex(inst), tostring(hp), tostring(team)))
          end
        elseif dn:find("npc_dota") then
          totalNpcs = totalNpcs + 1
          if totalNpcs <= 10 then
            log(string.format("  NPC chunk%d[%d] %s hp=%s team=%s", ci, ei, dn, tostring(hp), tostring(team)))
          end
        end
      end
    end
    if found > 0 then log(string.format("  chunk%d: %d identities", ci, found)) end
  end
end
log(string.format("TOTAL heroes=%d npcs=%d", totalHeroes, totalNpcs))
log("=== entity SAFE done ===")