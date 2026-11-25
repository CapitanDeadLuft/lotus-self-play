-- entity_game.lua — run IN-GAME (hero demo). Decode entity list, find local hero + creeps, read fields.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
local C = ffi.C
local schema = require("schema")

local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n")
  logf:flush()
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
local function cstr(p)
  if not readable(p, 1) then return nil end
  local ok, s = pcall(ffi.string, p, 96); if not ok then return nil end
  local z = s:find("\0"); if z then s = s:sub(1, z - 1) end
  if #s > 0 and s:match("^[%w_:<>%.%s%-]+$") then return s end
  return nil
end

schema.init()
local eng = C.GetModuleHandleA("engine2.dll")
local esys = ffi.cast("void**", ffi.cast("uintptr_t", eng) + 0x8b3c60)[0]
log("=== entity GAME probe === esys =", hex(esys))
if esys == nil then log("no entity system"); return end

-- offsets verified earlier
local oHealth = schema.offsetOf("C_BaseEntity", "m_iHealth") or 0x34C
local oTeam   = schema.offsetOf("C_BaseEntity", "m_iTeamNum") or 0x3E7
local oLife   = schema.offsetOf("C_BaseEntity", "m_lifeState") or 0x354

local function dumpList(tag, countOff, arrOff)
  local count = tonumber(ffi.cast("uint32_t*", esys)[countOff / 4])
  local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", esys)[arrOff / 8])
  log(string.format("[%s] count=%d arr=%s", tag, count, hex(arr)))
  if not readable(arr, 24) then return end
  local heroes, npcs = 0, 0
  local base = ffi.cast("uintptr_t", arr)
  local n = math.min(count, 512)
  for i = 0, n - 1 do
    local e = base + i * 24
    if not readable(ffi.cast("void*", e), 24) then break end
    local q = ffi.cast("uintptr_t*", e)
    local nm = cstr(ffi.cast("void*", q[1]))
    -- try q0 as CEntityInstance* -> m_pEntity@0x10 -> identity -> designerName@0x20
    local inst = ffi.cast("void*", q[0])
    local designer, hp, team = nil, nil, nil
    if readable(inst, 0x20) then
      local idn = ffi.cast("void*", ffi.cast("uintptr_t*", inst)[2])  -- +0x10 m_pEntity
      if readable(idn, 0x28) then
        designer = cstr(ffi.cast("void*", ffi.cast("uintptr_t*", idn)[4]))  -- +0x20
      end
      -- health/team directly on instance (C_BaseEntity fields)
      if readable(inst, oHealth + 4) then hp = tonumber(ffi.cast("int32_t*", ffi.cast("uintptr_t", inst) + oHealth)[0]) end
      if readable(inst, oTeam + 1) then team = tonumber(ffi.cast("uint8_t*", ffi.cast("uintptr_t", inst) + oTeam)[0]) end
    end
    if nm and (nm:find("hero") or (designer and designer:find("npc_dota_hero"))) then
      heroes = heroes + 1
      if heroes <= 12 then
        log(string.format("  HERO[%d] name=%s designer=%s inst=%s hp=%s team=%s", i, nm or "?", designer or "?", hex(q[0]), tostring(hp), tostring(team)))
      end
    elseif designer and designer:find("npc_dota") then
      npcs = npcs + 1
      if npcs <= 8 then
        log(string.format("  NPC[%d] name=%s designer=%s hp=%s team=%s", i, nm or "?", designer, tostring(hp), tostring(team)))
      end
    end
  end
  log(string.format("[%s] scanned=%d heroes=%d npcs=%d", tag, n, heroes, npcs))
end

dumpList("list1", 0x50, 0x58)
dumpList("list2", 0x70, 0x78)
log("=== entity GAME probe done ===")