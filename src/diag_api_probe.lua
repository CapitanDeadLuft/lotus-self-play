-- diag_api_probe.lua — live evidence dump for the API-core parity work (owner: api-core).
-- Purpose: verify every offset/semantic that api.lua relies on, from inside Dota.
-- Run via run.txt (one-shot, fresh Lua state). Writes a marked block into host.log:
--   grep  "API_P1"  D:\hake\lotus\host.log
-- Safe in menu and in match: each section guards on available objects and prints "n/a".
-- Sections:
--   1 build/state, 2 entity list + names, 3 player resource discovery, 4 team data records,
--   5 local player/controller/hero, 6 time sources (GameTime epoch), 7 dormancy flags,
--   8 class-name resolution (identity/instance pointer scan + CSchemaClassInfoData),
--   9 schema runtime classes (CDOTA_Buff / strides), 10 NPC field matrix, 11 modifier manager,
--   12 ability/KV availability.
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path

local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
  typedef struct { void* BaseAddress; void* AllocationBase; unsigned long AllocProtect;
                   size_t RegionSize; unsigned long State; unsigned long Protect; unsigned long Type; } API_MBI;
  size_t VirtualQuery(const void* addr, API_MBI* mbi, size_t len);
  void* GetModuleHandleA(const char* name);
  unsigned long long GetTickCount64(void);
]]

local logf = io.open("D:\\hake\\lotus\\host.log", "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  logf:write(os.date("%H:%M:%S ") .. table.concat(t, "\t") .. "\n"); logf:flush()
end
local function hex(v)
  if v == nil then return "nil" end
  return string.format("0x%X", tonumber(ffi.cast("uintptr_t", v)) or 0)
end

-- readable(): cached VirtualQuery over committed readable regions
local regions, regionN = {}, 0
local function readable(p, n)
  if p == nil then return false end
  local a = tonumber(ffi.cast("uintptr_t", p))
  if a < 0x10000 or a > 0x7FFFFFFFFFFF then return false end
  local need = a + (n or 8)
  for i = 1, regionN do
    local r = regions[i]
    if a >= r[1] and need <= r[2] then return true end
  end
  local mbi = ffi.new("API_MBI")
  if C.VirtualQuery(ffi.cast("void*", a), mbi, ffi.sizeof(mbi)) == 0 then return false end
  if mbi.State ~= 0x1000 then return false end
  local prot = tonumber(mbi.Protect)
  if not (prot == 0x02 or prot == 0x04 or prot == 0x08 or prot == 0x20 or prot == 0x40) then return false end
  local b = tonumber(ffi.cast("uintptr_t", mbi.BaseAddress))
  local e = b + tonumber(mbi.RegionSize)
  if regionN < 64 then regionN = regionN + 1; regions[regionN] = { b, e } end
  return need <= e
end
local function i8(p, o)  return readable(p + o, 1) and tonumber(ffi.cast("int8_t*",  p + o)[0]) or nil end
local function u8(p, o)  return readable(p + o, 1) and tonumber(ffi.cast("uint8_t*", p + o)[0]) or nil end
local function i32(p, o) return readable(p + o, 4) and tonumber(ffi.cast("int32_t*", p + o)[0]) or nil end
local function u32(p, o) return readable(p + o, 4) and tonumber(ffi.cast("uint32_t*", p + o)[0]) or nil end
local function u64(p, o)
  if not readable(p + o, 8) then return nil end
  local v = ffi.cast("uint64_t*", p + o)[0]
  local n = tonumber(v)
  if n == nil then return nil end
  return n
end
local function q(p, o) return u64(p, o) end                       -- qword as number (may lose >2^53)
local function f32(p, o)
  if not readable(p + o, 4) then return nil end
  local v = tonumber(ffi.cast("float*", p + o)[0])
  if v ~= v then return nil end
  return v
end
local function cstr(p, max)
  if p == nil or not readable(p, 4) then return nil end
  local ok, s = pcall(ffi.string, ffi.cast("const char*", p), max or 64)
  if not ok then return nil end
  local z = s:find("\0")
  if z then s = s:sub(1, z - 1) end
  if #s < 2 or #s > (max or 64) then return nil end
  if not s:match("^[%w_:<>%.%s%-%+%[%]/]+$") then return nil end
  return s
end
local function short(v, n) if v == nil then return "nil" end local s = tostring(v) if #s > (n or 60) then return s:sub(1, n) .. ".." end return s end
local function vec(p, o)
  local x, y, z = f32(p, o), f32(p, o + 4), f32(p, o + 8)
  if not (x and y and z) then return "nil" end
  if math.abs(x) > 1e6 or math.abs(y) > 1e6 or math.abs(z) > 1e6 then return string.format("odd(%g,%g,%g)", x, y, z) end
  return string.format("%.0f,%.0f,%.0f", x, y, z)
end

local schema = require("schema")
local entity = require("entity")
local okSchema = schema.init()
local clientBase = ffi.cast("uintptr_t", C.GetModuleHandleA("client.dll"))
local okEnt = entity.init()

-- standalone dry-run (outside Dota): no client.dll -> print, do not touch host.log
if clientBase == 0 and not okSchema then
  print("API_P1 DRYRUN OK (outside Dota: schema/client.dll unavailable, probe body skipped)")
  return
end

log("")
log("=== API_P1 BEGIN === okSchema=", tostring(okSchema), "okEntity=", tostring(okEnt),
    "client=", hex(clientBase), "wall=", string.format("%.1f", tonumber(C.GetTickCount64()) / 1000))

-- every section runs under this pcall so a missing object can never truncate the dump
local function body()

-- helper: schema offset with fallback
local function off(cls, field, fb)
  local o = schema.offsetOf and schema.offsetOf(cls, field)
  return o or fb
end
-- entity helpers (identity pointers, like api.lua)
local function inst(idn) if not idn or not readable(idn, 0x18) then return nil end return entity.instance(idn) end
local function name(idn) return entity.designerName(idn) or "" end
local function entIndex(idn)
  local h = i32(idn, 0x10)
  if h == nil then return -1 end
  if h < 0 then h = h + 4294967296 end
  return h % 0x8000
end
local function entByHandle(h)
  if h == nil then return nil end
  if h < 0 then h = h + 4294967296 end
  if h == 0 or h == 0xFFFFFFFF then return nil end
  local idx = h % 0x8000
  if idx == 0 then return nil end
  -- local scan: index -> identity using the same handle field
  for idn in entity.iter() do
    if entIndex(idn) == idx then return idn end
  end
  return nil
end

-- =========================================================================
-- 1. build / state
-- =========================================================================
local function gamerules()
  if clientBase == 0 then return nil end
  local gr = q(clientBase + 0x6219008, 0)
  if not gr then return nil end
  local proxy = q(gr, 0x08)
  if not proxy then return nil end
  local real = q(proxy, 0x5F0)
  if not real then return nil end
  return real, proxy, gr
end
local gr, proxy = gamerules()
local function grField(field, fb, typ)
  if not gr then return nil end
  local o = off("C_DOTAGamerules", field, fb)
  if typ == "bool" then return u8(gr, o) end
  if typ == "f32" then return f32(gr, o) end
  return i32(gr, o)
end
log("[1] gamerules=", hex(gr), "proxy=", hex(proxy),
    "state=", tostring(grField("m_nGameState", 0x7c)),
    "mode=", tostring(grField("m_iGameMode", 0xe4)),
    "matchid=", tostring(u64(gr or 0, off("C_DOTAGamerules", "m_unMatchID64", 0x858))),
    "gamestart=", string.format("%.3f", tonumber(grField("m_flGameStartTime", 0x594, "f32")) or -1),
    "pregame=", string.format("%.3f", tonumber(grField("m_flPreGameStartTime", 0x590, "f32")) or -1),
    "creepspawn=", string.format("%.3f", tonumber(grField("m_flCreepSpawntime", 0x580, "f32")) or -1),
    "gameend=", string.format("%.3f", tonumber(grField("m_flGameEndTime", 0x598, "f32")) or -1),
    "goldtime=", string.format("%.3f", tonumber(grField("m_flGoldTime", 0x578, "f32")) or -1),
    "glyphgood=", string.format("%.3f", tonumber(grField("m_fGoodGlyphCooldown", 0x5b8, "f32")) or -1),
    "glyphbad=", string.format("%.3f", tonumber(grField("m_fBadGlyphCooldown", 0x5bc, "f32")) or -1))
log("[1] gamerules sim/anim (C_BaseEntity 0x3B4/0x3B8)=",
    string.format("%.3f/%.3f", tonumber(f32(gr or 0, 0x3b4)) or -1, tonumber(f32(gr or 0, 0x3b8)) or -1))

-- =========================================================================
-- 2. entity list + names
-- =========================================================================
local total, seen = 0, {}
local withPlayerVec = {}
for idn in entity.iter() do
  total = total + 1
  local n = name(idn)
  if n ~= "" then seen[n] = (seen[n] or 0) + 1 end
  -- player-resource candidate: plausible C_UtlVectorEmbeddedNetworkVar at +0x608
  local i = inst(idn)
  if i then
    local c608, p608 = i32(i, 0x608), q(i, 0x608 + 8)
    local c670, p670 = i32(i, 0x670), q(i, 0x670 + 8)
    if c608 and c608 >= 5 and c608 <= 64 and p608 and readable(p608, 8) then
      withPlayerVec[#withPlayerVec + 1] = string.format("%s idx=%d cnt608=%d ptr608=%s cnt670=%s",
        n, entIndex(idn), c608, hex(p608), tostring(c670))
    end
  end
end
local names = {}
for n, c in pairs(seen) do names[#names + 1] = string.format("%s x%d", n, c) end
table.sort(names)
log("[2] entities=", total, "uniqueNames=", #names)
log("[2] names=", table.concat(names, " | "):sub(1, 3000))
log("[2] playerVecCandidates=", #withPlayerVec)
for k = 1, math.min(#withPlayerVec, 20) do log("[2]   cand ", withPlayerVec[k]) end

-- =========================================================================
-- 3. local player controller, hero, team
-- =========================================================================
local ctrl, pid, cteam, assigned
for idn in entity.iter() do
  if name(idn):find("player_controller") then
    local i = inst(idn)
    if u8(i, off("CBasePlayerController", "m_bIsLocalPlayerController", 0x778)) == 1 then
      ctrl = i; assigned = entByHandle(i32(i, off("C_DOTAPlayerController", "m_hAssignedHero", 0x914)))
      pid = i32(i, off("C_DOTAPlayerController", "m_nPlayerID", 0x910))
      cteam = u8(i, off("C_BaseEntity", "m_iTeamNum", 0x3e7))
      log("[3] localController inst=", hex(i), "pid=", tostring(pid), "team=", tostring(cteam),
          "assigned=", tostring(assigned and name(assigned)),
          "steamid=", tostring(u64(i, off("CBasePlayerController", "m_steamID", 0x770))),
          "name=", tostring(cstr(i + off("CBasePlayerController", "m_iszPlayerName", 0x6e4), 64)),
          "sim=", string.format("%.3f", tonumber(f32(i, 0x3b8)) or -1))
      log("[3] ctrl order times 0x940=", string.format("%.3f", tonumber(f32(i, 0x940)) or -1),
          "0x944=", string.format("%.3f", tonumber(f32(i, 0x944)) or -1),
          "0x948(latency)=", string.format("%.3f", tonumber(f32(i, 0x948)) or -1),
          "nextSeq(0x9B8)=", tostring(i32(i, 0x9B8)), "ordersCnt(0x9A0)=", tostring(i32(i, 0x9A0)))
      break
    end
  end
end
if not ctrl then log("[3] localController: n/a (menu/not assigned)") end
local heroIdn = assigned
if not heroIdn then
  for idn in entity.iter() do
    if name(idn):find("npc_dota_hero_") and not name(idn):find("announcer") then
      local i = inst(idn)
      if pid and i32(i, off("C_DOTA_BaseNPC_Hero", "m_iPlayerID", 0x1b68)) == pid then heroIdn = idn; break end
    end
  end
end
local hero = heroIdn and inst(heroIdn) or nil
log("[3] localHero idn=", hex(heroIdn), "inst=", hex(hero), "name=", heroIdn and name(heroIdn) or "n/a",
    "sim(0x3B8)=", string.format("%.3f", tonumber(f32(hero or 0, 0x3b8)) or -1),
    "anim(0x3B4)=", string.format("%.3f", tonumber(f32(hero or 0, 0x3b4)) or -1),
    "create(0x3E0)=", string.format("%.3f", tonumber(f32(hero or 0, 0x3e0)) or -1),
    "hp=", tostring(i32(hero or 0, off("C_BaseEntity", "m_iHealth", 0x34c))))

-- =========================================================================
-- 4. team data entities (dota_data_radiant/dire) and record indexing
-- =========================================================================
local function readDataTeamEntities()
  local out = {}
  for idn in entity.iter() do
    local n = name(idn)
    if n == "dota_data_radiant" or n == "dota_data_dire" then
      local i = inst(idn)
      local cnt, ptr = i32(i, 0x5F0), q(i, 0x5F0 + 8)
      out[#out + 1] = { name = n, inst = i, cnt = cnt, ptr = ptr }
    end
  end
  return out
end
local dts = readDataTeamEntities()
log("[4] dataTeamEntities=", #dts, " localPid=", tostring(pid), " localTeam=", tostring(cteam))
local DTP = 0x12F0  -- DataTeamPlayer_t stride (hpp: m_nSelectedBlessing 0x12E8 -> 0x12F0)
for _, dt in ipairs(dts) do
  log("[4] ", dt.name, " inst=", hex(dt.inst), " cnt=", tostring(dt.cnt), " ptr=", hex(dt.ptr))
  if dt.cnt and dt.ptr and dt.cnt >= 1 and dt.cnt <= 24 then
    for r = 0, dt.cnt - 1 do
      local rec = dt.ptr + r * DTP
      log(string.format("[4]   r%d rel=%s unrel=%s earned=%s xp=%s nw=%s lh=%s dn=%s kills=%s slot?=%s",
        r, tostring(i32(rec, 0x30)), tostring(i32(rec, 0x34)), tostring(i32(rec, 0x3c)),
        tostring(i32(rec, 0x40)), tostring(i32(rec, 0x90)), tostring(i32(rec, 0x98)),
        tostring(i32(rec, 0x94)), tostring(i32(rec, 0x208)), tostring(i32(rec, 0x23c))))
    end
  end
end
-- 4b: player resource discovery — scan gamerules/proxy pointers for a C_DOTA_PlayerResource-like object
local function looksLikePlayerResource(p)
  if not p or not readable(p, 0x700) then return false end
  local c = i32(p, 0x608)
  if not (c and c >= 5 and c <= 64) then return false end
  local ptr = q(p, 0x610)
  if not (ptr and readable(ptr, 0x240)) then return false end
  -- record 0 sanity: kills/assists/deaths small ints, lane flags byte
  local k, a, d = i32(ptr, 0xa8), i32(ptr, 0xac), i32(ptr, 0xb0)
  if not (k and a and d) then return false end
  if k < 0 or k > 500 or a < 0 or a > 500 or d < 0 or d > 500 then return false end
  return true
end
local foundRes = nil
do
  for _, base in ipairs({ gr or 0, proxy or 0, clientBase }) do
    if base and base > 0 then
      for o = 0, 0x200, 8 do
        local p = q(base, o)
        if p and p > 0x10000 and p ~= base and looksLikePlayerResource(p) then
          foundRes = p
          log("[4b] playerResource FOUND base=", hex(base), "+0x", string.format("%X", o), "=", hex(p))
          break
        end
      end
    end
    if foundRes then break end
  end
  if not foundRes then
    -- broader: scan all entity instances +0..0x40 for pointer to a resource-like object
    for idn in entity.iter() do
      local i = inst(idn)
      if i then
        for o = 0, 0x40, 8 do
          local p = q(i, o)
          if p and p > 0x10000 and looksLikePlayerResource(p) then
            log("[4b] playerResource FOUND via entity ", name(idn), " +0x", string.format("%X", o), "=", hex(p))
            foundRes = p
            break
          end
        end
      end
      if foundRes then break end
    end
  end
  if not foundRes then log("[4b] playerResource NOT FOUND (GetTeamData must use fallback)") end
end
if foundRes then
  local cnt = i32(foundRes, 0x608)
  local ptr = q(foundRes, 0x610)
  log("[4b] PR m_vecPlayerTeamData cnt=", tostring(cnt), " ptr=", hex(ptr))
  local STRIDE = 0x238
  for r = 0, math.min((cnt or 0) - 1, 23) do
    local rec = ptr + r * STRIDE
    log(string.format("[4b]   pr%d heroId=%s facet=%s kills=%s assists=%s deaths=%s streak=%s lvl=%s respawn=%s buyback=%.1f laneFlags=%s teamSlot=%s",
      r, tostring(i32(rec, 0x98)), tostring(i32(rec, 0xa0)), tostring(i32(rec, 0xa8)), tostring(i32(rec, 0xac)),
      tostring(i32(rec, 0xb0)), tostring(i32(rec, 0xb4)), tostring(i32(rec, 0xb8)), tostring(i32(rec, 0xc0)),
      tonumber(f32(rec, 0xc4)) or -1, tostring(u8(rec, 0x1d1)), tostring(i32(rec, 0x108))))
  end
  -- player data vector
  local pcnt, pptr = i32(foundRes, 0x670), q(foundRes, 0x678)
  log("[4b] PR m_vecPlayerData cnt=", tostring(pcnt), " ptr=", hex(pptr))
  if pcnt and pptr and pcnt >= 1 and pcnt <= 24 then
    for r = 0, math.min(pcnt - 1, 11) do
      local rec = pptr + r * 0xF0
      log(string.format("[4b]   pd%d valid=%s name=%s team=%s slot=%s steamid=%s",
        r, tostring(u8(rec, 0x30)), tostring(cstr(q(rec, 0x38))), tostring(i32(rec, 0x40)),
        tostring(i32(rec, 0xd0)), tostring(u64(rec, 0x58))))
    end
  end
end

-- =========================================================================
-- 5. time-source cross-check (GameTime epoch)
-- =========================================================================
do
  local sims = {}
  local n = 0
  for idn in entity.iter() do
    local i = inst(idn)
    if i then
      local s = f32(i, 0x3b8)
      if s and s > 0 and s < 1e7 then
        n = n + 1
        if n <= 4000 then sims[#sims + 1] = s end
      end
    end
  end
  table.sort(sims)
  local med = (#sims > 0) and sims[math.floor(#sims / 2)] or nil
  log("[5] simTime samples=", n, "min=", string.format("%.2f", sims[1] or -1),
      "med=", string.format("%.3f", med or -1),
      "max=", string.format("%.3f", sims[#sims] or -1),
      "| gamerules gamestart=", string.format("%.3f", tonumber(grField("m_flGameStartTime", 0x594, "f32")) or -1),
      "| heroSim=", string.format("%.3f", tonumber(f32(hero or 0, 0x3b8)) or -1))
end

-- =========================================================================
-- 6. dormancy / visibility flags
-- =========================================================================
do
  local identFlags, nodeDormant, shown = {}, {}, 0
  local samples = {}
  for idn in entity.iter() do
    local n = name(idn)
    if n:find("npc_dota") or n:find("player_controller") then
      local i = inst(idn)
      local fl = u32(idn, 0x30)
      local node = q(i, off("C_BaseEntity", "m_pGameSceneNode", 0x330))
      local dorm = node and u8(node, off("CGameSceneNode", "m_bDormant", 0x113))
      if #samples < 12 then
        samples[#samples + 1] = string.format("%s(idx%d flags=0x%X dorm=%s)", n, entIndex(idn),
          fl or 0, tostring(dorm))
      end
      if fl then identFlags[fl % 0x100] = (identFlags[fl % 0x100] or 0) + 1 end
      if dorm ~= nil then nodeDormant[dorm] = (nodeDormant[dorm] or 0) + 1 end
      shown = shown + 1
    end
  end
  local fparts, dparts = {}, {}
  for k, v in pairs(identFlags) do fparts[#fparts + 1] = string.format("%d:%d", k, v) end
  for k, v in pairs(nodeDormant) do dparts[#dparts + 1] = string.format("%d:%d", k, v) end
  table.sort(fparts); table.sort(dparts)
  log("[6] npc/ctrl=", shown, " identityFlagsLowByte=", table.concat(fparts, ","), " nodeDormant=", table.concat(dparts, ","))
  log("[6] samples: ", table.concat(samples, " | "))
end

-- =========================================================================
-- 7. class-name resolution: scan identity/instance qwords for CSchemaClassInfoData
-- =========================================================================
local function classInfoName(p)
  if not p or not readable(p, 0x40) then return nil end
  -- CSchemaClassInfoData: +0x08 = class name string
  local sp = q(p, 0x08)
  if not sp then return nil end
  local s = cstr(sp, 96)
  if s and s:find("^C_") then return s end
  -- maybe +0x00 is name string
  local s2 = cstr(q(p, 0x00), 96)
  if s2 and s2:find("^C_") then return s2 end
  return nil
end
if heroIdn then
  for _, tag in ipairs({ "identity", "instance" }) do
    local base = (tag == "identity") and heroIdn or hero
    local parts = {}
    local limit = (tag == "identity") and 0x70 or 0x30
    for o = 0, limit, 8 do
      local p = q(base, o)
      local cls = p and classInfoName(p)
      parts[#parts + 1] = string.format("+%X=%s%s", o, hex(p), cls and ("[" .. cls .. "]") or "")
    end
    log("[7] hero ", tag, ": ", table.concat(parts, " "))
  end
  -- candidate class-info pointer -> base classes?
  local ci = nil
  for o = 0, 0x30, 8 do
    local p = q(hero, o)
    if classInfoName(p) then ci = p; log("[7] classInfo from instance+0x", string.format("%X", o), "=", hex(p), " name=", classInfoName(p)); break end
  end
  if ci then
    local parts = {}
    for o = 0, 0x48, 8 do
      local p = q(ci, o)
      local nm = classInfoName(p)
      local s = cstr(p, 96)
      parts[#parts + 1] = string.format("+%X=%s%s%s", o, hex(p), nm and ("[cls:" .. nm .. "]") or "", (not nm and s) and ("[str:" .. s .. "]") or "")
    end
    log("[7] classInfo fields: ", table.concat(parts, " "))
    log("[7] classInfo size@0x20=", tostring(u32(ci, 0x20)), " objSize@0x24=", tostring(u32(ci, 0x24)),
        " fieldCount(w16@0x24)=", tostring(u32(ci, 0x24) % 65536), " fieldCount(w16@0x26)=", tostring(math.floor((u32(ci, 0x24) or 0) / 65536)))
  end
end

-- =========================================================================
-- 8. schema runtime classes (fields we need for GetField / modifiers / strides)
-- =========================================================================
local function dumpSchema(cls, max)
  local rec, err = schema.getClass(cls)
  if not rec then log("[8] schema ", cls, " MISSING: ", tostring(err)); return nil end
  local out = {}
  local n = 0
  for f, o in pairs(rec.fields) do
    n = n + 1
    if n <= (max or 200) then out[#out + 1] = f .. "=" .. o end
  end
  table.sort(out)
  log("[8] schema ", cls, " size=0x", string.format("%X", rec.size), " fields=", n, ": ", table.concat(out, " "))
  return rec
end
dumpSchema("CDOTA_Buff", 200)
dumpSchema("CDOTA_ModifierManager", 60)
dumpSchema("C_DOTA_PlayerResource", 40)
local prt = dumpSchema("PlayerResourcePlayerTeamData_t", 120)
local dtp = dumpSchema("DataTeamPlayer_t", 8)
log("[8] strides: PlayerResourcePlayerTeamData_t size=", prt and string.format("0x%X", prt.size) or "?",
    " DataTeamPlayer_t size=", dtp and string.format("0x%X", dtp.size) or "?")
-- field type name probe for one known class (to implement typed Entity.GetField)
do
  local rec = schema.getClass("C_DOTA_BaseNPC")
  if rec and rec.raw then
    local cls = rec.raw
    local count = tonumber(ffi.cast("uint16_t*", cls)[18])
    local arr = ffi.cast("uintptr_t*", ffi.cast("uintptr_t*", cls)[6])
    log("[8] C_DOTA_BaseNPC fieldCount=", count)
    for idx = 0, math.min(count - 1, 6) do
      local e = arr + idx * 4
      local fnm = cstr(ffi.cast("void*", e[0]), 64)
      local tp = e[1]
      local offv = tonumber(ffi.cast("int32_t*", e)[4])
      local tname = tp and cstr(q(tp, 0x08), 64)
      local tname0 = tp and cstr(tp, 64)
      local tname10 = tp and cstr(q(tp, 0x10), 64)
      log(string.format("[8] field[%d] %s off=0x%X type=%s t+8=%s t+0=%s t+10=%s", idx, tostring(fnm), offv or -1,
        hex(tp), tostring(tname), tostring(tname0), tostring(tname10)))
    end
  end
end

-- =========================================================================
-- 9. NPC field matrix (validates every NPC.* offset api.lua will use)
-- =========================================================================
do
  local units = 0
  for idn in entity.iter() do
    local n = name(idn)
    if n:find("npc_dota") and units < 6 then
      local i = inst(idn)
      units = units + 1
      log(string.format("[9] %s idx=%d hp=%s/%s mana=%s/%s lvl=%s ms=%s bat=%s bas=%s dmg=%s/%s bonus=%s basedmg=%s/%s range=%s acq=%s hull=%s hregen=%s mregen=%s armor=%s mres=%s bountyxp=%s gold=%s/%s moving=%s act=%s atkcap=0x%X nearShop=%s waitSpawn=%s scepter=%s/%s shard=%s/%s ownerNPC=%s controllable=0x%s dead=%s",
        n, entIndex(idn),
        tostring(i32(i, off("C_BaseEntity", "m_iHealth", 0x34c))), tostring(i32(i, off("C_BaseEntity", "m_iMaxHealth", 0x348))),
        tostring(f32(i, 0xcfc)), tostring(f32(i, 0xd00)),
        tostring(i32(i, 0xc9c)), tostring(i32(i, 0xce0)), tostring(f32(i, 0xce8)), tostring(i32(i, 0xce4)),
        tostring(i32(i, 0xe18)), tostring(i32(i, 0xe1c)), tostring(i32(i, 0xe20)), tostring(i32(i, 0xe24)), tostring(i32(i, 0xe28)),
        tostring(i32(i, 0xcc8)), tostring(i32(i, 0x12d4)), tostring(f32(i, 0xd60)),
        tostring(f32(i, 0x1744)), tostring(f32(i, 0x1740)),
        tostring(f32(i, 0x162c)), tostring(f32(i, 0x1630)),
        tostring(i32(i, 0x1754)), tostring(i32(i, 0x175c)), tostring(i32(i, 0x1760)),
        tostring(u8(i, 0x1748)), tostring(i32(i, 0x18e8)), u32(i, 0x13b4) or 0,
        tostring(i32(i, 0x13ec)), tostring(u8(i, 0x1730)),
        tostring(u8(i, 0x12ed)), tostring(u8(i, 0x12ee)), tostring(u8(i, 0x12ec)), tostring(u8(i, 0x12ef)),
        tostring(entByHandle(i32(i, 0x1764)) and name(entByHandle(i32(i, 0x1764))) or nil),
        string.format("%X", (u64(i, 0xcb8) or 0) % 0x100000000),
        tostring(f32(i, 0x1624))))
    end
  end
  if units == 0 then log("[9] no npc_dota entities (menu/lobby)") end
end

-- =========================================================================
-- 10. modifier manager layout + CDOTA_Buff field probe
-- =========================================================================
do
  local target = heroIdn
  if target then
    local i = inst(target)
    local mgr = i and (i + 0xe30)
    log("[10] hero mgr=", hex(mgr))
    if mgr then
      local parts = {}
      for o = 0, 0x40, 4 do parts[#parts + 1] = string.format("+%X=%d", o, i32(mgr, o) or 0) end
      log("[10] mgr dwords: ", table.concat(parts, " "))
      -- candidate vector layouts: (count@0, ptr@8) or (count@8, ptr@0x10) etc.
      for _, lay in ipairs({ { 0, 8 }, { 8, 0x10 }, { 0x10, 0x18 }, { 0, 0x10 } }) do
        local c, pp = i32(mgr, lay[1]), q(mgr, lay[2])
        if c and c > 0 and c <= 64 and pp and readable(pp, c * 8) then
          local names, n = {}, 0
          for k = 0, c - 1 do
            local e4 = u32(pp, k * 4)
            local e8 = q(pp, k * 8)
            local byh = e4 and entByHandle(e4)
            local byp = e8 and entity.designerName(e8)
            if byh or byp then
              n = n + 1
              if n <= 12 then names[#names + 1] = string.format("%d:%s%s", k, tostring(byh and name(byh) or "-"), byp and ("/" .. tostring(byp)) or "") end
            end
          end
          log(string.format("[10] layout cnt@%X ptr@%X c=%d resolved=%d: %s", lay[1], lay[2], c, n, table.concat(names, " | ")))
        end
      end
    end
  else
    log("[10] no local hero (menu) — modifier probe skipped")
  end
end

-- =========================================================================
-- 11. ability / KV availability
-- =========================================================================
do
  local okx, x = pcall(require, "xhelpers")
  log("[11] xhelpers=", tostring(okx), " xkv=", tostring(okx and type(x.xkv)))
  if okx and x.xkv then
    local ok1, items = pcall(function() return x.xkv:GetKV("items") end)
    local ok2, abils = pcall(function() return x.xkv:GetKV("npc_abilities") end)
    local ok3, units = pcall(function() return x.xkv:GetKV("npc_units") end)
    local ok4, heroes = pcall(function() return x.xkv:GetKV("npc_heroes") end)
    log("[11] KV items=", tostring(ok1 and items and items.DOTAAbilities and #items.DOTAAbilities or 0),
        " abilities=", tostring(ok2 and abils and abils.DOTAAbilities and #abils.DOTAAbilities or 0),
        " units=", tostring(ok3 and type(units)),
        " heroes=", tostring(ok4 and type(heroes)))
    if ok2 and abils and abils.DOTAAbilities then
      local kvs = abils.DOTAAbilities
      for _, nm in ipairs({ "treant_natures_grasp", "axe_berserkers_call", "item_blink", "nevermore_shadowraze1" }) do
        local kv = kvs[nm]
        if kv then
          log("[11] abilKV ", nm, " keys=", (function()
            local t = {}; local n = 0
            for k in pairs(kv) do n = n + 1; if n <= 14 then t[#t + 1] = k end end
            return table.concat(t, ",")
          end)())
        else
          log("[11] abilKV ", nm, " ABSENT")
        end
      end
    end
    if ok3 and units then
      local u = units.DOTAUnits
      if u then
        for _, nm in ipairs({ "npc_dota_creep_lane_melee", "npc_dota_creep_lane_ranged" }) do
          local kv = u[nm]
          if kv then
            log("[11] unitKV ", nm, " dmg=", tostring(kv.AttackDamageMin), "/", tostring(kv.AttackDamageMax),
                " acq=", tostring(kv.AttackAcquisitionRange), " range=", tostring(kv.AttackRange),
                " bat=", tostring(kv.BaseAttackTime), " proj=", tostring(kv.ProjectileSpeed),
                " anim=", tostring(kv.AttackAnimationPoint))
          end
        end
      end
    end
  end
end

-- =========================================================================
-- 12. api.lua current behaviour on live objects (doc-vs-implementation deltas)
-- =========================================================================
do
  local okA, api = pcall(require, "api")
  if not okA then log("[12] api require failed: ", tostring(api)) else
    local okR, errR = pcall(api.register)
    log("[12] api.register ok=", tostring(okR), okR and "" or tostring(errR))
    if okR then
      local G = function(n) return rawget(_G, n) end
      local E, N, P = G("Entity"), G("NPC"), G("Player")
      local h = G("Heroes") and G("Heroes").GetLocal()
      log("[12] Heroes.GetLocal=", hex(h), " Entity.GetIndex=", tostring(h and E.GetIndex(h)))
      if h then
        local o = E.GetAbsOrigin(h)
        log("[12] GetAbsOrigin=", o and string.format("%.0f,%.0f,%.0f", o.x, o.y, o.z) or "nil",
            " team=", tostring(E.GetTeamNum(h)), " dormant=", tostring(E.IsDormant(h)),
            " alive=", tostring(E.IsAlive(h)), " hp=", tostring(E.GetHealth(h)),
            " className=", tostring(E.GetClassName(h)))
        log("[12] NPC unitName=", tostring(N.GetUnitName(h)), " attackRange=", tostring(N.GetAttackRange(h)),
            " bonusRange=", tostring(N.GetAttackRangeBonus(h)), " trueDmg/min/max=",
            tostring(N.GetTrueDamage(h)), "/", tostring(N.GetTrueMaximumDamage(h)),
            " hull=", tostring(N.GetHullRadius(h)), " spAttack=", tostring(N.GetSecondsPerAttack(h)),
            " animPoint=", tostring(N.GetAttackAnimPoint(h)), " projSpeed=", tostring(N.GetAttackProjectileSpeed(h)),
            " hregen=", tostring(N.GetHealthRegen(h)), " mregen=", tostring(N.GetManaRegen(h)),
            " isRunning=", tostring(N.IsRunning(h)), " isAttacking=", tostring(N.IsAttacking(h)),
            " scepter=", tostring(N.HasScepter(h)), " shard=", tostring(N.HasShard(h)),
            " barriers=", short(N.GetBarriers(h)), " statesDur=", short(N.GetStatesDuration(h, { [0] = true, [5] = true })))
        log("[12] Entity.GetField(hero,'m_bIsWaitingToSpawn')=", tostring(E.GetField(h, "m_bIsWaitingToSpawn")))
        log("[12] Hero xp=", tostring(G("Hero").GetCurrentXP(h)), " respawn=", tostring(G("Hero").GetRespawnTime(h)),
            " playerId=", tostring(G("Hero").GetPlayerID(h)), " primaryAttr=", tostring(G("Hero").GetPrimaryAttribute(h)),
            " recentDmg=", tostring(G("Hero").GetRecentDamage(h)), " lastVisible=", tostring(G("Hero").GetLastVisibleTime(h)))
      end
      local players = G("Players") and G("Players").GetAll() or {}
      log("[12] Players.GetAll=", #players)
      for pi, p in ipairs(players) do
        if pi <= 12 then
          local okd, data = pcall(P.GetTeamData, p)
          local okt, info = pcall(P.GetTeamPlayer, p)
          local d = okd and type(data) == "table" and data or {}
          local t = okt and type(info) == "table" and info or {}
          log(string.format("[12]   player%d class=%s team=%s pid=%s | teamData{kills=%s deaths=%s assists=%s lvl=%s lane=%s heroId=%s respawn=%s} | teamPlayer{nw=%s lh=%s dn=%s rel=%s unrel=%s earned=%s xp=%s}",
            pi, tostring(E.GetClassName(p)), tostring(E.GetTeamNum(p)), tostring(P.GetPlayerID(p)),
            tostring(d.kills), tostring(d.deaths), tostring(d.assists), tostring(d.level), tostring(d.lane_selection_flags),
            tostring(d.selected_hero_id), tostring(d.respawnTime),
            tostring(t.networth), tostring(t.lasthit_count), tostring(t.deny_count), tostring(t.reliable_gold),
            tostring(t.unreliable_gold), tostring(t.totalearned_gold), tostring(t.totalearned_xp)))
        end
      end
      log("[12] GameRules gt=", tostring(G("GameRules").GetGameTime()),
          " gs=", tostring(G("GameRules").GetGameStartTime()),
          " state=", tostring(G("GameRules").GetGameState()),
          " match=", tostring(G("GameRules").GetMatchID()))
    end
  end
end

-- =========================================================================
-- 13. clock source cross-check (used to validate GameRules.GetGameTime)
-- =========================================================================
do
  local gs = tonumber(grField("m_flGameStartTime", 0x594, "f32")) or -1
  local function inGame(v) if not v or v ~= v or v < 1 then return -1 end return v - gs end
  local function show(tag, i2)
    if not i2 then log("[13] ", tag, " n/a") return end
    local sim, anim, cre = f32(i2, 0x3b8), f32(i2, 0x3b4), f32(i2, 0x3e0)
    log(string.format("[13] %-18s sim=%.3f anim=%.3f create=%.3f | simClock=%s animClock=%s",
      tag, sim or -1, anim or -1, cre or -1,
      string.format("%.2f", inGame(sim)), string.format("%.2f", inGame(anim))))
  end
  show("localHero", hero)
  if ctrl then show("controllerInst", ctrl) end
  for idn in entity.iter() do
    local n = name(idn)
    if n == "dota_gamerules" or n == "dota_gamemanager" or n == "dota_data_radiant" then
      show(n, inst(idn))
    end
  end
  local maxSim, maxAnim, npcMaxSim, npcMaxAnim, n = 0, 0, 0, 0, 0
  for idn in entity.iter() do
    local i = inst(idn)
    if i then
      local s, a = f32(i, 0x3b8), f32(i, 0x3b4)
      n = n + 1
      if s and s > maxSim then maxSim = s end
      if a and a > maxAnim then maxAnim = a end
      if name(idn):find("npc_dota") then
        if s and s > npcMaxSim then npcMaxSim = s end
        if a and a > npcMaxAnim then npcMaxAnim = a end
      end
    end
  end
  log(string.format("[13] ALL maxSim=%.3f (clock %.2f) maxAnim=%.3f (clock %.2f) n=%d",
    maxSim, inGame(maxSim), maxAnim, inGame(maxAnim), n))
  log(string.format("[13] npcOnly maxSim=%.3f (clock %.2f) maxAnim=%.3f (clock %.2f)",
    npcMaxSim, inGame(npcMaxSim), npcMaxAnim, inGame(npcMaxAnim)))
  -- last attack / damage timestamps = clock source used for mid-join fallback
  local bestA, bestD = 0, 0
  for idn in entity.iter() do
    if name(idn):find("^npc_dota") then
      local i = inst(idn)
      if i then
        local a, d = f32(i, 0x13c8), f32(i, 0x13c4)
        if a and a > bestA then bestA = a end
        if d and d > bestD then bestD = d end
      end
    end
  end
  log(string.format("[13] lastAttack=%.3f (clock %.2f) lastDamage=%.3f (clock %.2f) gs=%.3f state=%s",
    bestA, inGame(bestA), bestD, inGame(bestD), gs, tostring(grField("m_nGameState", 0x7c))))
  log("[13] HUD CHECK: compare the in-game clock mm:ss with the 'clock' values above")
end

-- =========================================================================
-- 14. modifier list layout: CDOTA_ModifierManager (NPC+0xE30) -> CDOTA_Buff objects
--    runtime schema fields (verified): m_name=0x28, m_flCreationTime=0x54,
--    m_flDieTime=0x64, m_flDuration=0x60, m_iStackCount=0x84, m_iSerialNumber=0x48
-- =========================================================================
do
  local function probeUnit(tag, idn2)
    if not idn2 then log("[14] ", tag, " n/a") return end
    local i = inst(idn2)
    local mgr = i and (i + 0xe30)
    if not mgr then log("[14] ", tag, " no inst/mgr") return end
    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or -1
    local dwords = {}
    for o = 0, 0x28, 4 do dwords[#dwords + 1] = string.format("%X=%d", o, i32(mgr, o) or 0) end
    log("[14] ", tag, " (", name(idn2), ") mgr dwords: ", table.concat(dwords, " "))
    for _, lay in ipairs({ { 0x10, 0x18 }, { 0x08, 0x10 }, { 0, 8 }, { 0x18, 0x20 }, { 0x20, 0x28 } }) do
      local c, pp = i32(mgr, lay[1]), q(mgr, lay[2])
      if c and c > 0 and c <= 64 and pp and readable(pp, c * 8) then
        local parts = {}
        for k = 0, math.min(c - 1, 10) do
          local obj = q(pp, k * 8)
          if obj and obj > 0x10000 and readable(obj, 0x1a8) then
            local namePtr = q(obj, 0x28)
            local s = namePtr and cstr(namePtr, 96)
            local die = f32(obj, 0x64)
            local cre = f32(obj, 0x54)
            local dur = f32(obj, 0x60)
            local stk = i32(obj, 0x84)
            parts[#parts + 1] = string.format("%d{name=%s die=%.2f cre=%.2f dur=%.2f stk=%s rem=%.2f}",
              k, tostring(s), tonumber(die) or -1, tonumber(cre) or -1, tonumber(dur) or -1, tostring(stk),
              (tonumber(die) or 0) - now)
          else
            parts[#parts + 1] = k .. "{nil}"
          end
        end
        log(string.format("[14]   layout cnt@0x%X ptr@0x%X cnt=%d: %s", lay[1], lay[2], c, table.concat(parts, " ")))
      end
    end
    -- state bitmask (exact) + which states are on
    local mask = u64(i, 0x12b8) or 0
    local on = {}
    for st = 0, 63 do
      if math.floor(mask / 2 ^ st) % 2 == 1 then on[#on + 1] = st end
    end
    log("[14] ", tag, " m_nUnitState64=", string.format("0x%X", mask), " states=", table.concat(on, ","),
        " schemaMask=", tostring(u64(i, 0x12c8)))
  end
  probeUnit("hero", heroIdn)
  local n = 0
  for idn in entity.iter() do
    local dn = name(idn)
    if dn:find("npc_dota") and n < 2 then n = n + 1; probeUnit("npc" .. n, idn) end
  end
end

-- =========================================================================
-- 15. client NPC visibility bitmask C_DOTA_DataNonSpectator::m_bNPCVisibleState
--     (uint64[256] @0xE58) — validates Entity.IsDormant / NPC.IsVisible
-- =========================================================================
do
  local mi
  for idn in entity.iter() do
    local dn = name(idn)
    if dn == "dota_data_radiant" or dn == "dota_data_dire" then mi = inst(idn) end
  end
  if not mi then log("[15] no dota_data entity") else
    local set, total = 0, 0
    local visSamples, invSamples = {}, {}
    for idn in entity.iter() do
      local dn = name(idn)
      if dn:find("npc_dota") then
        local idx = entIndex(idn)
        local word = idx > 0 and u64(mi, 0xE58 + math.floor(idx / 64) * 8)
        if word then
          total = total + 1
          local vis = math.floor(word / 2 ^ (idx % 64)) % 2 == 1
          if vis then set = set + 1 end
          local entry = string.format("%s(idx%d team=%s hp=%s)", dn, idx,
            tostring(i32(inst(idn) or 0, 0x3e7)), tostring(i32(inst(idn) or 0, 0x34c)))
          if vis and #visSamples < 6 then visSamples[#visSamples + 1] = entry end
          if not vis and #invSamples < 6 then invSamples[#invSamples + 1] = entry end
        end
      end
    end
    log(string.format("[15] m_bNPCVisibleState visible=%d/%d", set, total))
    log("[15] VISIBLE samples: ", table.concat(visSamples, " | "))
    log("[15] HIDDEN  samples: ", table.concat(invSamples, " | "))
    local words = {}
    for k = 0, 7 do words[#words + 1] = string.format("w%d=0x%X", k, u64(mi, 0xE58 + k * 8) or 0) end
    log("[15] words: ", table.concat(words, " "))
  end
end

-- =========================================================================
-- 16. attack timing calibration (task-12): client fields vs KV vs API values
-- =========================================================================
do
  local okA, api = pcall(require, "api")
  if okA then pcall(api.register) end
  local N = rawget(_G, "NPC")
  local E = rawget(_G, "Entity")
  local okx, x = pcall(require, "xhelpers")
  local hkv = okx and x.xkv:GetKV("npc_heroes").DOTAAbilities or {}
  local ukv = okx and x.xkv:GetKV("npc_units").DOTAAbilities or {}
  local function kvnum(kv, k)
    local v = kv and kv[k]
    if type(v) == "table" then v = v.value end
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v:match("%-?%d+%.?%d*")) end
    return nil
  end
  local function show(tag, idn2)
    if not idn2 or not N then log("[16] ", tag, " n/a") return end
    local i = inst(idn2)
    local namePtr = i and q(i, 0xD70)
    local unitName = namePtr and cstr(namePtr, 96) or name(idn2)
    local kv = hkv[unitName] or ukv[unitName] or {}
    log(string.format("[16] %-22s unitName=%s baseAS(0xCE4)=%s bat(0xCE8)=%s dmg=%s/%s bonus=%s basedmg=%s/%s",
      tag, tostring(unitName), tostring(i32(i, 0xCE4)), tostring(f32(i, 0xCE8)),
      tostring(i32(i, 0xE18)), tostring(i32(i, 0xE1C)), tostring(i32(i, 0xE20)),
      tostring(i32(i, 0xE24)), tostring(i32(i, 0xE28))))
    log(string.format("[16]   KV rate=%s animPoint=%s range=%s proj=%s turn=%s | API aps=%.3f spa=%.3f anim=%s proj=%s rangeBonus=%s ttf=%.3f recentDmg=%s",
      tostring(kvnum(kv, "AttackRate")), tostring(kvnum(kv, "AttackAnimationPoint")),
      tostring(kvnum(kv, "AttackRange")), tostring(kvnum(kv, "ProjectileSpeed")), tostring(kvnum(kv, "MovementTurnRate")),
      tonumber(N.GetAttackSpeed and N.GetAttackSpeed(idn2)) or -1,
      tonumber(N.GetSecondsPerAttack and N.GetSecondsPerAttack(idn2)) or -1,
      tostring(N.GetAttackAnimPoint and N.GetAttackAnimPoint(idn2)),
      tostring(N.GetAttackProjectileSpeed and N.GetAttackProjectileSpeed(idn2)),
      tostring(N.GetAttackRangeBonus and N.GetAttackRangeBonus(idn2)),
      tonumber(N.GetTimeToFace and N.GetTimeToFace(idn2, idn2)) or -1,
      tostring(rawget(_G, "Hero") and rawget(_G, "Hero").GetRecentDamage and rawget(_G, "Hero").GetRecentDamage(idn2))))
  end
  show("localHero", heroIdn)
  local n = 0
  for idn in entity.iter() do
    if name(idn):find("npc_dota_creep") then
      n = n + 1
      if n <= 3 then show("creep" .. n, idn) end
    end
  end
  -- states duration sample on the hero (may be empty when unbuffed)
  if heroIdn and N and N.GetStatesDuration then
    local st = { [0] = true, [1] = true, [3] = true, [5] = true, [6] = true, [19] = true, [47] = true }
    local d = N.GetStatesDuration(heroIdn, st, true)
    local parts = {}
    for k, v in pairs(d or {}) do parts[#parts + 1] = string.format("%d=%.2f", k, v) end
    log("[16] hero statesDuration: ", table.concat(parts, " "))
    log("[16] hero modifiers: ", table.concat((function()
      local t = {}
      for _, m in ipairs(N.GetModifiers and N.GetModifiers(heroIdn) or {}) do
        local nm = (rawget(_G, "Modifier") and rawget(_G, "Modifier").GetName) and rawget(_G, "Modifier").GetName(m) or "?"
        t[#t + 1] = tostring(nm) .. "@0x" .. string.format("%X", tonumber(ffi.cast("uintptr_t", m)) or 0)
      end
      return t
    end)(), " | "))
  end
end

-- =========================================================================
-- 17. player <-> hero mapping + teammate positions (task-18 acceptance)
--     required: 10 controllers, 10 DISTINCT heroes, ally origins NOT all equal/
--     fountain, GetOwner direction, Players.GetAll cost
-- =========================================================================
do
  local okA, api = pcall(require, "api")
  if okA then pcall(api.register) end
  local P, E, H, HS = rawget(_G, "Player"), rawget(_G, "Entity"), rawget(_G, "Hero"), rawget(_G, "Heroes")
  if not (P and E and HS) then log("[17] api not registered") else
    local t0 = os.clock()
    local controllers = HS and rawget(_G, "Players").GetAll() or {}
    local cost = (os.clock() - t0) * 1000
    local t1 = os.clock()
    for _ = 1, 10 do rawget(_G, "Players").GetAll() end
    local cost10 = (os.clock() - t1) * 1000
    log(string.format("[17] Players.GetAll n=%d firstCall=%.2fms x10=%.2fms (cached TTL 0.5s)", #controllers, cost, cost10))
    local localHero = HS.GetLocal()
    local lx, ly = E.GetAbsOrigin(localHero).x, E.GetAbsOrigin(localHero).y
    local seenHero, distinct, dup = {}, 0, 0
    for i, p in ipairs(controllers) do
      local pid = P.GetPlayerID(p)
      local team = E.GetTeamNum(p)
      local hero = P.GetAssignedHero(p)
      local hx, hy, hz = nil, nil, nil
      if hero then
        local o = E.GetAbsOrigin(hero)
        hx, hy, hz = o.x, o.y, o.z
        if not seenHero[hero] then seenHero[hero] = true; distinct = distinct + 1 else dup = dup + 1 end
      end
      local owner = hero and E.GetOwner(hero)
      log(string.format("[17] ctrl[%d] pid=%s team=%s assigned=%s heroOrigin=%s owner=%s isLocalCtrl=%s samePosAsLocalHero=%s",
        i, tostring(pid), tostring(team),
        hero and tostring(E.GetUnitName(hero)) or "NIL",
        hero and string.format("%.0f,%.0f,%.0f", hx, hy, hz) or "-",
        owner and tostring(E.GetUnitName(owner)) or "nil",
        tostring(p == rawget(_G, "Players").GetLocal()),
        tostring(hero and hero == localHero)))
      local d = P.GetTeamData and P.GetTeamData(p) or {}
      log(string.format("[17]   teamData kills=%s deaths=%s assists=%s lvl=%s laneFlags=%s heroId=%s respawn=%s",
        tostring(d.kills), tostring(d.deaths), tostring(d.assists), tostring(d.level), tostring(d.lane_selection_flags),
        tostring(d.selected_hero_id), tostring(d.respawnTime)))
    end
    log(string.format("[17] distinctAssignedHeroes=%d duplicateAssignments=%d", distinct, dup))
    local heroes = HS.GetAll()
    log("[17] Heroes.GetAll n=", #heroes)
    for i, h in ipairs(heroes) do
      local pid = H and H.GetPlayerID and H.GetPlayerID(h) or -1
      local o = E.GetAbsOrigin(h)
      local owner = E.GetOwner(h)
      local rec = H and H.GetReplicatingOtherHeroModel and H.GetReplicatingOtherHeroModel(h)
      log(string.format("[17] hero[%d] %s playerID=%s team=%s pos=%.0f,%.0f alive=%s dormant=%s visible=%s owner=%s replicating=%s hp=%s/%s",
        i, tostring(E.GetUnitName(h)), tostring(pid), tostring(E.GetTeamNum(h)), o.x, o.y,
        tostring(E.IsAlive(h)), tostring(E.IsDormant(h)), tostring(rawget(_G, "NPC") and rawget(_G, "NPC").IsVisible(h)),
        owner and tostring(E.GetUnitName(owner)) or "nil", tostring(rec),
        tostring(E.GetHealth(h)), tostring(E.GetMaxHealth(h))))
    end
    -- distinct origins sanity: teammates in lanes at 25min must not share the fountain
    local posCount, fountainLike = {}, 0
    for _, h in ipairs(heroes) do
      local o = E.GetAbsOrigin(h)
      local key = string.format("%.0f:%.0f", o.x, o.y)
      posCount[key] = (posCount[key] or 0) + 1
      if math.abs(o.x + 7195) < 400 and math.abs(o.y + 6582) < 400 then fountainLike = fountainLike + 1 end
    end
    local dupPos = 0
    for _, c in pairs(posCount) do if c > 1 then dupPos = dupPos + c end end
    log(string.format("[17] heroOrigins distinct=%d heroesAtRadiantFountain=%d heroesSharingPositions=%d",
      (function() local n = 0 for _ in pairs(posCount) do n = n + 1 end return n end)(), fountainLike, dupPos))
    -- role inputs used by the support branch (Self Play.lua:1543 `ctx.role >= 4`)
    local p = rawget(_G, "Players").GetLocal()
    if p then
      local d = P.GetTeamData(p)
      local tp = P.GetTeamPlayer(p)
      log(string.format("[17] localPlayer roleInputs laneFlags=%s heroId=%s networth=%s lasthits=%s denies=%s",
        tostring(d.lane_selection_flags), tostring(d.selected_hero_id),
        tostring(tp.networth), tostring(tp.lasthit_count), tostring(tp.deny_count)))
    end
  end
end

-- =========================================================================
-- 19. task-19 + GetTeamData forensics:
--     A) find the REAL C_DOTA_PlayerResource (vector @0x608 cnt = vector @0x670)
--        and dump its per-player records to validate every offset GetTeamData uses
--     B) inventory layout: C_DOTA_UnitInventory.m_hItems is a
--        C_NetworkUtlVectorBase<CHandle> @0x20 (count@+0x20, ptr@+0x28) — NOT an
--        inline array; dump raw + resolved item names vs NPC.GetItemByIndex
--     C) CDOTA_Buff timing field identification: dump f32 window 0x40..0x98
--        against game clock / known creation times
--     D) hero level: m_iCurrentLevel vs XP-derived level
-- =========================================================================
do
  local okA, api = pcall(require, "api")
  if okA then pcall(api.register) end
  local N = rawget(_G, "NPC")
  local E = rawget(_G, "Entity")
  local P = rawget(_G, "Player")
  local HS = rawget(_G, "Heroes")

  -- A) locate real player resource by entity-instance signature
  local cands = {}
  for idn in entity.iter() do
    local i = inst(idn)
    if i then
      local c608, p608 = i32(i, 0x608), q(i, 0x610)
      local c670, p670 = i32(i, 0x670), q(i, 0x678)
      if c608 and p608 and c670 and p670 and c608 >= 5 and c608 <= 24 and c670 == c608
        and readable(p608, c608 * 0x238 + 0x100) and readable(p670, c670 * 0xF0 + 0x100) then
        local ok = 0
        for pid = 0, math.min(c608 - 1, 9) do
          local h = i32(i, 0x760 + pid * 4)
          local ctrl = h and entByHandle(h)
          if ctrl and name(ctrl):find("player_controller") then ok = ok + 1 end
        end
        cands[#cands + 1] = { idn = idn, idx = entIndex(idn), inst = i, cnt = c608,
          teamCnt = c670, ctrls = ok, nm = name(idn) }
      end
    end
  end
  log("[19] PR candidates=", #cands)
  for k = 1, math.min(#cands, 5) do
    local c = cands[k]
    log(string.format("[19]   cand%d idx=%d name='%s' cnt608=%d cnt670=%d playerIDToPlayerHits=%d/%d",
      k, c.idx, c.nm, c.cnt, c.teamCnt, c.ctrls, c.cnt))
  end
  table.sort(cands, function(a, b) return a.ctrls > b.ctrls end)
  local best = cands[1]
  if best then
    local t = q(best.inst, 0x610)
    local pd = q(best.inst, 0x678)
    log(string.format("[19] BEST PR idx=%d inst=0x%X teamData=0x%X playerData=0x%X", best.idx,
      tonumber(ffi.cast("uintptr_t", best.inst)) or 0, t or 0, pd or 0))
    -- playerIDToPlayer / names
    local hs, names = {}, {}
    for pid = 0, math.min(best.cnt - 1, 9) do
      local h = i32(best.inst, 0x760 + pid * 4)
      local ctrl = h and entByHandle(h)
      hs[#hs + 1] = string.format("%d:%s", pid, ctrl and name(ctrl) or "-")
      local np = q(best.inst, 0x960 + pid * 8)
      names[#names + 1] = string.format("%d:%s", pid, tostring(np and cstr(np, 40) or "-"))
    end
    log("[19] playerIDToPlayer=", table.concat(hs, " "))
    log("[19] m_iszName=", table.concat(names, " "))
    -- m_vecPlayerData[pid]: name/team/slot/steamid — strong identity check for the locator
    local pds = {}
    for pid = 0, math.min(best.teamCnt - 1, 9) do
      local rec = pd + pid * 0xF0
      pds[#pds + 1] = string.format("%d{valid=%s namePtr=%s team=%s slot=%s steamid=%s}", pid,
        tostring(u8(rec, 0x30)), (function() local np = q(rec, 0x38); return np and cstr(np, 24) or "-" end)(),
        tostring(i32(rec, 0x40)), tostring(i32(rec, 0xD0)), tostring(u64(rec, 0x58)))
    end
    log("[19] m_vecPlayerData=", table.concat(pds, " | "))
    -- per-record raw dump: all players 0..9 (compact row) + full dump for 0/1/5/6
    local compact = {}
    for pid = 0, math.min(best.cnt, 10) - 1 do
      local rec = t + pid * 0x238
      compact[#compact + 1] = string.format("%d{k=%s d=%s a=%s lvl=%s heroId=%s team=%s slot=%s lane=%s nw?}", pid,
        tostring(i32(rec, 0xA8)), tostring(i32(rec, 0xB0)), tostring(i32(rec, 0xAC)),
        tostring(i32(rec, 0xB8)), tostring(i32(rec, 0x98)), tostring(i32(rec, 0x40) or 0),
        tostring(i32(rec, 0x108)), tostring(u8(rec, 0x1D1)))
    end
    log("[19] teamData RAW all pids: ", table.concat(compact, " "))
    for _, pid in ipairs({ 0, 1, 5, 6 }) do
      if pid < best.cnt then
        local rec = t + pid * 0x238
        local function f(o) return f32(rec, o) end
        local function d(o) return i32(rec, o) end
        local function b(o) return u8(rec, o) end
        log(string.format("[19] rec[pid=%d] heroId=%s facet=%s kills=%s assists=%s deaths=%s streak=%s level=%s respawn=%s buyback=%.1f teamSlot=%s laneFlags=%s draftRoles=%s hSelHero=%s",
          pid, tostring(d(0x98)), tostring(d(0xA0)), tostring(d(0xA8)), tostring(d(0xAC)), tostring(d(0xB0)),
          tostring(d(0xB4)), tostring(d(0xB8)), tostring(d(0xC0)), f(0xC4) or -1,
          tostring(d(0x108)), tostring(b(0x1D1)), tostring(b(0x1D2)), tostring(d(0xCC))))
        -- raw helper: any field we're unsure about, dump as 8 dwords around it
        local w = {}
        for o = 0x90, 0xD8, 4 do w[#w + 1] = string.format("%X=%d", o, d(o) or 0) end
        log("[19]   dwords 0x90..0xD8: ", table.concat(w, " "))
        local w2 = {}
        for o = 0x1C8, 0x1E0, 1 do w2[#w2 + 1] = string.format("%X=%d", o, b(o) or 0) end
        log("[19]   bytes 0x1C8..0x1E0: ", table.concat(w2, " "))
        -- cross-check against the API result
        local pl = nil
        for _, c in ipairs(rawget(_G, "Players").GetAll()) do
          if P.GetPlayerID(c) == pid then pl = c break end
        end
        if pl then
          local td = P.GetTeamData(pl)
          log(string.format("[19]   API GetTeamData pid=%d kills=%s deaths=%s assists=%s lvl=%s lane=%s heroId=%s",
            pid, tostring(td.kills), tostring(td.deaths), tostring(td.assists), tostring(td.level),
            tostring(td.lane_selection_flags), tostring(td.selected_hero_id)))
        end
      end
    end
  end

  -- B) inventory layout for the local hero
  local hero = HS and HS.GetLocal()
  local hi = hero and inst(hero)
  local IT = rawget(_G, "Item")
  local function itemCharges(it)
    if it and IT and IT.GetCurrentCharges then
      local okc, ch = pcall(IT.GetCurrentCharges, it)
      if okc then return tostring(ch) end
    end
    return "-"
  end
  if hi then
    local inv = hi + 0x11C0
    local cap, ptr28 = i32(inv, 0x20), q(inv, 0x28)
    log(string.format("[19] inventory @NPC+0x11C0: inst=0x%X capacity@+0x20=%s ptr@+0x28=0x%X (invalid ptr => inline handle array)",
      tonumber(ffi.cast("uintptr_t", hi)) or 0, tostring(cap), ptr28 or 0))
      local gateTaken = (cap and cap > 0 and cap <= 25)
      log(string.format("[19] itemAt gate: cnt=%s 0<cnt<=25 => %s (bounds 0..16)", tostring(cap), tostring(gateTaken)))
    -- CORRECT mapping used by api.lua: inline CHandle slots start at +0x24, 25 x 4 bytes,
    -- ending exactly at m_bItemQueried @+0x88 (hpp). Probe prints slots 0..16 (documented).
    for i = 0, 16 do
      local off = 0x24 + i * 4
      local handle = u32(inv, off)
      local it = handle and entByHandle(handle)
      local api = N.GetItemByIndex and N.GetItemByIndex(hero, i)
      local apiFalse = N.GetItemByIndex and N.GetItemByIndex(hero, i, false)
      local apiInst = (i == 15) and N.GetItemByIndex and N.GetItemByIndex(hi, 15) or nil
      log(string.format("[19] slot[%d] off=0x%X handle=0x%X item=%s charges=%s apiGetItemByIndex=%s apiIsRealFalse=%s apiByInstance=%s",
        i, off, handle or 0, it and name(it) or "-", itemCharges(it),
        api and name(api) or "nil", apiFalse and name(apiFalse) or "nil", apiInst and name(apiInst) or "nil"))
    end
    -- capacity diagnostics + full raw handle window 0x20..0x88
    do
      local h60 = u32(inv, 0x60)
      local apiH, entH = nil, nil
      if h60 then
        apiH = entByHandle(h60)
        local okE, ent2 = pcall(require, "entity")
        if okE and ent2 and ent2.byHandle then
          local okB, e2 = pcall(ent2.byHandle, h60)
          if okB then entH = e2 end
        end
      end
      log(string.format("[19] +0x60 raw=0x%X sentinel: ==0?%s ==0xFFFFFFFF?%s oldRule(>=0xFFFFFF)?%s idx=%s | probeEntByHandle=%s entity.byHandle=%s",
        h60 or 0, tostring(h60 == 0), tostring(h60 == 0xFFFFFFFF), tostring((h60 or 0) >= 0xFFFFFF),
        h60 and (h60 % 0x8000) or -1,
        apiH and name(apiH) or "nil", entH and name(entH) or "nil"))
    end
    local rawH = {}
    for o = 0x20, 0x88, 4 do rawH[#rawH + 1] = string.format("%X=%d", o, i32(inv, o) or 0) end
    log("[19] inventory handles window 0x20..0x88: ", table.concat(rawH, " "))
    -- OLD (off-by-one) base +0x20: kept for the mapping-vs-reference proof
    local old = {}
    for i = 0, 18 do
      local handle = u32(inv, 0x20 + i * 4)
      local it = handle and entByHandle(handle)
      old[#old + 1] = string.format("%d:%s", i, it and name(it) or "-")
    end
    log("[19] OLD +0x20-base reads (i*4 from 0x20): ", table.concat(old, " "))
    -- expected from reference consumers: slot15 must be the TP scroll (shop.lua:550),
    -- slot16 the neutral item (neutral_items.lua:167, empty before 7:00 in a fresh game)
    local tp = N.GetItemByIndex and N.GetItemByIndex(hero, 15)
    local neutral = N.GetItemByIndex and N.GetItemByIndex(hero, 16)
    log(string.format("[19] reference check: GetItemByIndex(hero,15)=%s (expect item_tpscroll) GetItemByIndex(hero,16)=%s (expect nil before 7:00)",
      tp and name(tp) or "nil", neutral and name(neutral) or "nil"))
      local byName = N.GetItem and N.GetItem(hero, "item_tpscroll", false)
      log(string.format("[19] name path: NPC.GetItem(hero,'item_tpscroll',false)=%s ; reference form note: scripts call GetItemByIndex(npc,index) 2-arg (shop.lua:550) and GetItem(npc,name,isReal) (Self Play.lua:1011 uses false for tpscroll)",
        byName and name(byName) or "nil"))
  else
    log("[19] no local hero for inventory probe")
  end

  -- C) CDOTA_Buff timing field identification (first hero buff)
  local nowC = rawget(_G, "GameRules").GetGameTime()
  log(string.format("[19] clock now=%.3f gs=%.3f in_game=%.1f", nowC,
    rawget(_G, "GameRules").GetGameStartTime(), nowC - rawget(_G, "GameRules").GetGameStartTime()))
  local buffs = N and N.GetModifiers and hi and N.GetModifiers(hero) or {}
  for k = 1, math.min(#buffs, 3) do
    local obj = buffs[k]
    local cre, la, dur, die = f32(obj, 0x54), f32(obj, 0x5C), f32(obj, 0x60), f32(obj, 0x64)
    local bname = tostring(Modifier and Modifier.GetName and Modifier.GetName(obj))
    if bname == "?" or bname == "nil" then
      local np = q(obj, 0x28)
      bname = tostring(np and cstr(np, 80))
    end
    log(string.format("[19] buff%d %s cre=%.3f lastApplied=%.3f dur=%.3f die=%.3f prevTick(0xA0)=%.3f | die-now=%.2f | idx=%s ser=%s stk=%s creationFrame=%s",
      k, bname, cre or -1, la or -1, dur or -1, die or -1, f32(obj, 0xA0) or -1,
      (die or 0) - nowC,
      tostring(i32(obj, 0x50)), tostring(i32(obj, 0x48)), tostring(i32(obj, 0x84)), tostring(i32(obj, 0x58))))
    local parts = {}
    for o = 0x40, 0x98, 4 do
      parts[#parts + 1] = string.format("%X=%.3f|%d", o, tonumber(f32(obj, o)) or -1, i32(obj, o) or 0)
    end
    log("[19]   raw 0x40..0x98 (f32|i32): ", table.concat(parts, " "))
    -- locate LIVE timestamp fields: any f32 in [now-30, now+30] is a same-epoch
    -- GameTime candidate (dieTime for short buffs, lastApplied, creation)
    local hits = {}
    for o = 0x00, 0x160, 4 do
      local v = f32(obj, o)
      if v and v > nowC - 30 and v < nowC + 30 then
        hits[#hits + 1] = string.format("%X=%.3f", o, v)
      end
    end
    log("[19]   floats near clock +/-30s: ", table.concat(hits, " "))
  end
  -- runtime schema offsets for CDOTA_Buff timing fields (single source of truth)
  local okcd, rec = pcall(schema.getClass, "CDOTA_Buff")
  if okcd and rec then
    local keys = { "m_name", "m_flCreationTime", "m_flDieTime", "m_flDuration", "m_iStackCount",
                   "m_flLastAppliedTime", "m_iSerialNumber", "m_hCaster", "m_iIndex", "m_iTeam" }
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(rec.fields[k]) end
    log("[19] schema CDOTA_Buff: size=0x", string.format("%X", rec.size), " ", table.concat(parts, " "))
  end
  -- epoch-candidate clocks next to our now (contract-review item, NO patch):
  -- gamerules/map entities expose m_flAnimTime(0x3B4)/m_flSimulationTime(0x3B8)/m_flCreateTime(0x3E0)
  do
    local function clk(e)
      if not e then return "nil" end
      return string.format("anim=%.3f sim=%.3f create=%.3f", f32(e, 0x3B4) or -1, f32(e, 0x3B8) or -1, f32(e, 0x3E0) or -1)
    end
    local greN = nil
    for idn2 in entity.iter() do
      if name(idn2):find("dota_gamerules", 1, true) then greN = inst(idn2) break end
    end
    log(string.format("[19] epoch candidates: now=%.3f | localHero %s | gamerulesEntity %s",
      nowC, clk(hi), clk(greN)))
    log(string.format("[19] tick-derived check: now*30=%.3f | buff cre/die*30 integer test below",
      nowC * 30))
  end
  -- 3-sample trace >=2 s apart: do buff cre/die/lastApplied/prevTick advance with wall,
  -- or are they static template values? (fresh short-duration buff preferred)
  do
    local wall0 = tonumber(C.GetTickCount64())
    local function sample(tag)
      local n = 0
      for k = 1, math.min(#buffs, 3) do
        local o = buffs[k]
        local nm = tostring(Modifier and Modifier.GetName and Modifier.GetName(o))
        log(string.format("[19] bufftrace %s k=%d name=%s cre=%.3f(x30=%.1f) die=%.3f(x30=%.1f) dur=%.3f la=%.3f prevTick=%.3f now=%.3f wall=%.3f",
          tag, k, nm, f32(o, 0x54) or -1, (f32(o, 0x54) or 0) * 30,
          f32(o, 0x64) or -1, (f32(o, 0x64) or 0) * 30,
          f32(o, 0x60) or -1, f32(o, 0x5C) or -1, f32(o, 0xA0) or -1,
          rawget(_G, "GameRules").GetGameTime(), (tonumber(C.GetTickCount64()) - wall0) / 1000))
      end
      return n
    end
    sample("t0")
    local target = wall0 + 2200
    while tonumber(C.GetTickCount64()) < target do end
    sample("t1")
    target = tonumber(C.GetTickCount64()) + 2200
    while tonumber(C.GetTickCount64()) < target do end
    sample("t2")
  end

  -- D) hero level cross-check + GetRecentDamage raw + GetOwner contract lines
  if hero then
    local lvl = N.GetCurrentLevel(hero)
    local xp = rawget(_G, "Hero").GetCurrentXP(hero)
    local td = P.GetTeamData(rawget(_G, "Players").GetLocal() or hero)
    log(string.format("[19] hero level API=%s xp=%s teamData.level=%s teamPlayer.xp=%s",
      tostring(lvl), tostring(xp), tostring(td and td.level),
      tostring(P.GetTeamPlayer(rawget(_G, "Players").GetLocal() or hero).totalearned_xp)))
    log("[19] hero raw 0xC90..0xCB0: ", (function()
      local w = {}
      for o = 0xC90, 0xCB0, 4 do w[#w + 1] = string.format("%X=%d", o, i32(hi, o) or 0) end
      return table.concat(w, " ")
    end)())
    log("[19] hero raw 0x1AE0..0x1B50 (i32|f32): ", (function()
      local w = {}
      for o = 0x1AE0, 0x1B50, 4 do
        w[#w + 1] = string.format("%X=%d|%.2f", o, i32(hi, o) or 0, tonumber(f32(hi, o)) or -1)
      end
      return table.concat(w, " ")
    end)())
    -- GetRecentDamage raw for hero and for a creep (QA flagged 2059206657)
    local recHero = i32(hi, 0x1B28)
    local creep
    for idn in entity.iter() do
      if name(idn):find("npc_dota_creep") then creep = idn break end
    end
    local recCreep = creep and i32(inst(creep), 0x1B28) or nil
    log(string.format("[19] GetRecentDamage hero API=%s raw0x1B28=%s | creep API=%s raw0x1B28=%s (expect creep->0 after guard)",
      tostring(rawget(_G, "Hero").GetRecentDamage(hero)), tostring(recHero),
      creep and tostring(rawget(_G, "Hero").GetRecentDamage(creep)) or "-", tostring(recCreep)))
    -- GetOwner contract probe: entity.md requires hero -> CPlayer
    local ownH = E.GetOwner(hero)
    local ownRaw = u32(hi, 0x514)
    log(string.format("[19] GetOwner(localHero)=%s raw m_hOwnerEntity=0x%X | RecursiveGetOwner(localHero)=%s",
      ownH and tostring(E.GetUnitName(ownH)) or "nil", ownRaw or 0,
      tostring(E.RecursiveGetOwner(hero) and E.GetUnitName(E.RecursiveGetOwner(hero)) or "nil")))
    -- per-hero owner raw table (remote heroes are nil today -> documented limitation)
    local parts = {}
    for _, hh in ipairs(HS.GetAll()) do
      local o = E.GetOwner(hh)
      parts[#parts + 1] = string.format("%s(pid%s):%s/raw0x%X", name(hh), tostring(rawget(_G, "Hero").GetPlayerID(hh)),
        o and "ctrl" or "nil", u32(inst(hh), 0x514) or 0)
    end
    log("[19] hero owners: ", table.concat(parts, " | "))
  end
end

end -- body()

local okBody, errBody = pcall(body)
if not okBody then log("=== API_P1 ERROR === ", tostring(errBody)) end
log("=== API_P1 END === (wall=", string.format("%.1f", tonumber(C.GetTickCount64()) / 1000), ")")