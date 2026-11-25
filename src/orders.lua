-- orders.lua — unit-order pipeline for the Self Play port (PrepareUnitOrders).
--
-- Umbrella API surface this implements (docs: docs/research/uczone_api_v2.md):
--   Player.PrepareUnitOrders(player, type, target, pos, ability, issuer, issuer_npc,
--                            [queue], [show_effects], [callback], [execute_fast],
--                            [identifier], [force_minimap])
--   Player.AttackTarget(player, issuer_npc, target, [queue], [push], [execute_fast], [identifier], [force_minimap])
--   Player.HoldPosition(player, issuer_npc, [queue], [push], [execute_fast], [identifier])
--   NPC.MoveTo(npc, position, [queue], [show], [callback], [executeFast], [identifier], [force_minimap])
--
-- Native call (reverse-engineered, verified live: hero walks, attack order recorded
-- by the engine with the target index we pass):
--   bool CDOTAPlayer::PrepareUnitOrders(CDOTAPlayerController* player, int orderType,
--        uint32 targetIndex, Vector* position, uint32 abilityIndex, int orderIssuer,
--        CBaseEntity* issuer, bool queue, bool showEffects)
--   RVA 0x1C191E0 on this build (was 0x1B5F860; client.dll moved PUO +0x150 - refresh via dump/signature after patches).
--   The engine records the order in the controller's CUtlOrders vector; we re-read
--   that record right after issuing (M.lastRecord) for live diagnostics.
--
-- Encoding rules (defensible, see diag_orders.lua for the live A/B test):
--   target  = entity index  (CHandle index = handle & 0x7FFF). Verified: the engine
--             records exactly this value in CUnitOrders::m_nTargetIndex@0x30.
--   ability = entity index of the C_DOTABaseAbility entity by default. Can be
--             switched to the ability-slot index for A/B testing:
--               orders.setAbilityEncoding("entity") -- default
--               orders.setAbilityEncoding("slot")   -- hero ability array slot / item slot
--   issuer  = CBaseEntity* of the unit that executes the order (instance pointer).
--   orderIssuer = Enum.PlayerOrderIssuer (scripts pass 2 or 3).
--
-- Safety: every native call is pcall-wrapped; the module never throws into the bot.

local ffi = require("ffi")
local C = ffi.C
local entity = require("entity")
local schema = require("schema")
local Enum = require("enums")

local M = {}

M.ORDER  = Enum.UnitOrder
M.ISSUER = Enum.PlayerOrderIssuer

-- order type names (for logs / diags); reverse of Enum.UnitOrder -------------
local ORDER_NAME = {}
for name, value in pairs(M.ORDER) do
  if type(value) == "number" and ORDER_NAME[value] == nil then ORDER_NAME[value] = name end
end
-- a few aliases that Umbrella's docs use loosely
ORDER_NAME[7] = "DOTA_UNIT_ORDER_CAST_TARGET_TREE"
M.ORDER_NAME = ORDER_NAME
function M.orderName(t) return ORDER_NAME[tonumber(t) or -1] or ("UNKNOWN(" .. tostring(t) .. ")") end

local ISSUER_NAME = {}
for name, value in pairs(M.ISSUER) do ISSUER_NAME[value] = name end
M.ISSUER_NAME = ISSUER_NAME

M.prepareUnitOrdersRVA = 0x1C191E0 -- UPDATED 2026-11-18: client.dll moved PUO +0x150 (was 0x1B5F860, mid-function now); verified by signature at M.init()

-- controller offsets (client.dll.hpp this build) ----------------------------
local O_CTRL_ORDERS_SIZE = 0x9A0 -- CUtlVector< CUnitOrders >
local O_CTRL_ORDERS_PTR  = 0x9A8
local O_CTRL_NEXT_SEQ    = 0x9B8
local ORDER_STRIDE       = 0x40
local O_ORDER_POS        = 0x18
local O_ORDER_ISSUER     = 0x24
local O_ORDER_SEQ        = 0x28
local O_ORDER_TYPE       = 0x2C
local O_ORDER_TARGET     = 0x30
local O_ORDER_ABILITY    = 0x34
local O_ORDER_FLAGS      = 0x38

ffi.cdef[[
  void* GetModuleHandleA(const char* name);
  void Sleep(unsigned long ms);
  // AI-14 fix: native PUO reads stack params past showEffects (arg9) up to arg13+
  // (callback/executeFast/identifier/forceMinimap). 9-arg calls left arg10+ as stack
  // garbage; a garbage pointer into LuaJIT memory got stored by the game and dispatched
  // during entity think, then dangled after p_close(L) -> AV. Pass explicit zero defaults
  // (uint64_t slots: 0 is benign for bool/int/pointer) so no garbage is ever stored.
  typedef bool (*PrepareUnitOrdersFn)(void* player, int orderType, uint32_t targetIndex,
      float* position, uint32_t abilityIndex, int orderIssuer, void* issuer, bool queue, bool showEffects,
      uint64_t callbackFlag, uint64_t executeFast, uint64_t identifier, uint64_t forceMinimap);
  void R11_Marker(void* hero, float gx, float gy, float gz, int has);
  // host16.dll export: critical-section queue drained by the DXGI Present hook
  int QueueOrder(void* player, int type, unsigned target, float x, float y, float z,
                 unsigned ability, void* issuer, int queue, int show);
  unsigned long long GetTickCount64(void);
  int QueryPerformanceCounter(int64_t* out);
  int QueryPerformanceFrequency(int64_t* out);
]]

local PUO, clientBase
local oIsLocal, oHeroPID, oCtrlPID, oSceneNode, oAbsOrigin
local initErr

-- Present-thread order queue (O1) -------------------------------------------
-- PrepareUnitOrders must run on the game's Present thread: host16.dll exports
-- QueueOrder (host.cpp) which appends to a critical-section queue drained inside
-- the DXGI Present hook, guarded by PtrOk. Calling the engine function directly
-- from the Lua HostThread races the game thread (host.cpp:107-110 documents it;
-- pcall cannot catch an access violation). Orders are queued by default and we
-- synchronously wait for the drain to bump the controller order sequence, so
-- M.lastSeq stays exact. Direct call remains only as a loud fallback.
M.orderMode = "direct"  -- direct: our own thread issues the order and we can mark the sequence immediately (queue drained later => Self Play saw "manual" orders and paused)
local hostlib, hostTried = nil, false
local drainTimeoutMs = 40
local drainTimeouts = 0
M.queueStats = { queued = 0, direct = 0, timeouts = 0, disabled = false,
  drainN = 0, drainSumMs = 0, drainMaxMs = 0 }

local function hostQueue()
  if hostTried then return hostlib end
  hostTried = true
  local ok, lib = pcall(ffi.load, "host16.dll")
  if not ok or not lib then
    local ok2, lib2 = pcall(ffi.load, "D:\\hake\\lotus\\src\\host16.dll")
    if ok2 then lib = lib2 end
  end
  if lib then
    local ok2, fn = pcall(function() return lib.QueueOrder end)
    if ok2 and fn ~= nil then hostlib = lib end
  end
  return hostlib
end
M.hostQueue = hostQueue

-- per-order entity scan caches (O2): localController/localHero otherwise walk
-- the whole entity list for every last-hit/attack/cast order.
local ctrlCache, heroCache = { at = -1e9, inst = nil }, { at = -1e9, inst = nil, identity = nil }
M.cacheTtl = 0.25
function M.invalidateCache()
  ctrlCache.at, heroCache.at = -1e9, -1e9
end

-- stats / diagnostics ------------------------------------------------------
M.stats = { sent = 0, failed = 0, byType = {}, lastAt = 0, verifyMismatch = 0 }
M.lastSeq = -1        -- outgoing order sequence after our last successful order
M.lastRecord = nil    -- record the engine wrote for our last order (see verifyLast)
M.history = {}        -- ring buffer of the last N order specs (diagnostics)
M.historyN = 0
M.historySize = 32
M.dedupeWindow = 0.05 -- suppress an identical order issued twice within this window
M._lastSpec = nil
M._mkLib = nil
M.logOrders = true    -- [order] PUO ... lines (always on for item orders / failures)
M.orderLogN = 0
local abilityEncoding = "entity" -- "entity" | "slot"

-- item definition ids -------------------------------------------------------
-- Purchase orders carry the item DEFINITION id (items KV "ID") as both target
-- and ability index; sell/move/disassemble carry an item entity instead. The
-- scripts resolve the id from XHelpers items KV (self_play/shop.lua:844:
-- `local cost, itemId = tonumber(kv.ItemCost), tonumber(kv.ID)`), so the loader
-- must expose ID in gamedata/items.json (fixed: 500 items got their ID).
local itemNameById, itemIdByName, itemMapAt
function M.itemNames()
  if itemMapAt and (os.clock() - itemMapAt) < 30 then return itemNameById, itemIdByName end
  itemNameById, itemIdByName = {}, {}
  local XH = rawget(_G, "XHelpers") or package.loaded["xhelpers"]
  if XH and XH.xkv and XH.xkv.GetKV then
    local ok, kv = pcall(function() return XH.xkv:GetKV("items").DOTAAbilities end)
    if ok and kv then
      for key, entry in pairs(kv) do
        if type(entry) == "table" then
          local id = tonumber(entry.ID)
          if id and key:sub(1, 5) == "item_" then
            local name = key:sub(6)
            itemNameById[id] = name
            itemIdByName[name] = id
          end
        end
      end
    end
  end
  itemMapAt = os.clock()
  return itemNameById, itemIdByName
end

-- resolve a display name for an item-ish order argument (id or entity)
function M.itemName(v)
  if v == nil or v == 0 then return nil end
  local byId = M.itemNames()
  if type(v) == "number" and v < 0x8000 then return byId[tonumber(v)] end
  local idx = M.entityIndex(v)
  if idx ~= 0 then
    -- entity path: read its designer name when api/entity modules are available
    local N = rawget(_G, "NPC")
    if N and N.GetItemByIndex then
      local h = M.localHero()
      if h then
        for i = 0, 8 do
          local ok, it = pcall(N.GetItemByIndex, h, i)
          if ok and it then
            local ok2, nm = pcall(function() return _G.Ability.GetName(it) end)
            if ok2 and nm then return (nm:gsub("^item_", "")) end
          end
        end
      end
    end
  end
  return nil
end

-- purchase bookkeeping: the P0-C acceptance is "no repeating failed buys", so
-- each purchase attempt is counted per item id; a repeat means the previous
-- order did not acquire the item.
M.purchases = {}      -- itemId -> { name, count, firstAt, lastAt, prevAt }

-- read the bot's own inventory: slot -> item designer name (works without api
-- namespaces too, falls back to a stub result when the hero has no inventory)
function M.inventory()
  local out = {}
  local hero = M.localHero()
  if not hero then return out end
  local N = rawget(_G, "NPC")
  if N and N.GetItemByIndex then
    for i = 0, 18 do
      local ok, it = pcall(N.GetItemByIndex, hero, i)
      if ok and it then
        local ok2, nm = pcall(function() return _G.Ability.GetName(it) end)
        if ok2 and nm then out[#out + 1] = { slot = i, name = nm, entity = it } end
      end
    end
    return out
  end
  -- direct read: C_DOTA_UnitInventory.m_hItems at NPC+0x11C0+0x20
  for i = 0, 18 do
    local ok, h = pcall(function()
      return tonumber(ffi.cast("uint32_t*", hero + 0x11C0 + 0x20 + i * 4)[0])
    end)
    if ok and h and h ~= 0 and h ~= 0xFFFFFFFF then
      local ok2, idn = pcall(entity.byHandle, h)
      if ok2 and idn then
        local nm = entity.designerName(idn)
        if nm then out[#out + 1] = { slot = i, name = nm } end
      end
    end
  end
  return out
end

function M.inventoryHas(name)
  if not name then return false end
  local want = name:find("^item_") and name or ("item_" .. name)
  for _, it in ipairs(M.inventory()) do
    if it.name == want then return true end
  end
  return false
end

function M.purchaseStats()
  local n, repeats = 0, 0
  local parts = {}
  for id, p in pairs(M.purchases) do
    n = n + 1
    if p.count > 1 then repeats = repeats + (p.count - 1) end
    parts[#parts + 1] = string.format("%s(id=%d)x%d", p.name or "?", id, p.count)
  end
  table.sort(parts)
  return { items = n, attempts = n, repeats = repeats, detail = table.concat(parts, ",") }
end

local function now() return os.clock() end

-- rate-limited [order] logging. Item orders and failures are always logged
-- (QA acceptance needs every purchase line); other orders are sampled.
local function logOrder(spec, ok, err, extra)
  local itemish = spec.type == (M.ORDER.DOTA_UNIT_ORDER_PURCHASE_ITEM or 16)
    or spec.type == (M.ORDER.DOTA_UNIT_ORDER_SELL_ITEM or 17)
    or spec.type == (M.ORDER.DOTA_UNIT_ORDER_MOVE_ITEM or 19)
    or spec.type == (M.ORDER.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM or 18)
    or spec.type == (M.ORDER.DOTA_UNIT_ORDER_TRAIN_ABILITY or 11)
  M.orderLogN = M.orderLogN + 1
  local must = itemish or (not ok) or (spec.mismatch ~= nil) or M.orderLogN <= 20
    or (M.orderLogN % 25) == 0
  if not must or not M.logOrders then return end
  local name = spec.itemName or M.itemName(spec.itemArg) or "-"
  local unitName = spec.unitName or (spec.issuer and M.unitName(spec.issuer)) or "?"
  local line = string.format("[order] PUO type=%d(%s) tgt=%s abil=%s issuer=%s unit=%s queue=%s id=%s item=%s -> %s",
    spec.type, M.orderName(spec.type), tostring(spec.target), tostring(spec.ability),
    tostring(spec.orderIssuer), unitName, tostring(spec.queue),
    tostring(spec.identifier or "-"), tostring(name), ok and "ok" or ("fail:" .. tostring(err)))
  if spec.mismatch then line = line .. " MISMATCH=" .. spec.mismatch end
  if extra then line = line .. " " .. extra end
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. line .. "\n"); f:close() end
end

-- crash guard: FFI derefs are not catchable by pcall. Validate pages first.
-- The cdef MUST match api.lua byte-for-byte: a different declaration of
-- VirtualQuery re-binds the symbol and breaks api.lua's own readable().
ffi.cdef[[
  typedef struct { void* BaseAddress; void* AllocationBase; unsigned long AllocProtect;
                   size_t RegionSize; unsigned long State; unsigned long Protect; unsigned long Type; } API_MBI;
  size_t VirtualQuery(const void* addr, API_MBI* mbi, size_t len);
]]
local rcache = { base = 0, ends = 0 }
local rlist, rN = {}, 0
local function readable(addr, n)
  if addr == nil or addr < 0x10000 or addr > 0x7FFFFFFFFFFF then return false end
  local need = addr + (n or 8)
  if addr >= rcache.base and need <= rcache.ends then return true end
  for i = 1, rN do
    local r = rlist[i]
    if addr >= r[1] and need <= r[2] then rcache.base, rcache.ends = r[1], r[2]; return true end
  end
  local mbi = ffi.new("API_MBI")
  if ffi.C.VirtualQuery(ffi.cast("void*", addr), mbi, ffi.sizeof(mbi)) == 0 then return false end
  if tonumber(mbi.State) ~= 0x1000 then return false end
  local prot = tonumber(mbi.Protect)
  if not (prot == 0x02 or prot == 0x04 or prot == 0x08 or prot == 0x10 or prot == 0x20 or prot == 0x40 or prot == 0x80) then return false end
  local b = tonumber(ffi.cast("uintptr_t", mbi.BaseAddress))
  local e = b + tonumber(mbi.RegionSize)
  if rN < 32 then rN = rN + 1; rlist[rN] = { b, e } else rlist[(rN % 32) + 1] = { b, e } end
  rcache.base, rcache.ends = b, e
  return true
end
local function ri32(p, o) if not p then return nil end local a = ffi.cast("uintptr_t", p) + (o or 0) if not readable(a, 4) then return nil end return tonumber(ffi.cast("int32_t*", a)[0]) end
local function ru8(p, o) if not p then return nil end local a = ffi.cast("uintptr_t", p) + (o or 0) if not readable(a, 1) then return nil end return tonumber(ffi.cast("uint8_t*", a)[0]) end
local function rf32(p, o) if not p then return nil end local a = ffi.cast("uintptr_t", p) + (o or 0) if not readable(a, 4) then return nil end return tonumber(ffi.cast("float*", a)[0]) end
local function rq(p, o) if not p then return nil end local a = ffi.cast("uintptr_t", p) + (o or 0) if not readable(a, 8) then return nil end return tonumber(ffi.cast("uintptr_t*", a)[0]) end

local logLine                -- forward declaration: defined near the bottom, used by init/retry/fatal paths
-- retry/fatal state: signature mismatch is fatal/sticky; entity/client/schema/schema-offsets are retryable (rate-limited, bounded)
local fatalErr
local retryCount, lastRetryLog = 0, -1e9
local OFFSET_SPECS = {
  {"oIsLocal",  "CBasePlayerController", "m_bIsLocalPlayerController"},
  {"oHeroPID",  "C_DOTA_BaseNPC_Hero",   "m_iPlayerID"},
  {"oCtrlPID",  "C_DOTAPlayerController","m_nPlayerID"},
  {"oSceneNode","C_BaseEntity",          "m_pGameSceneNode"},
  {"oAbsOrigin","CGameSceneNode",        "m_vecAbsOrigin"},
}
local function setFatal(msg)
  fatalErr = msg; initErr = msg; PUO = nil
  logLine("[order] init DISABLED (fatal): " .. tostring(msg))
end
local function retryable(msg)
  local now = os.time()
  local counted = false
  if now - lastRetryLog > 2 then
    lastRetryLog = now
    retryCount = retryCount + 1
    counted = true
    logLine(string.format("[order] init retry n=%d err=%s", retryCount, tostring(msg)))
  end
  -- lobby/pre-game is NOT a failure: entity.init legitimately fails until the match starts.
  local notInGame = tostring(msg):find("not in%-game") or tostring(msg):find("no gamerules identity seed")
  if (not notInGame) and retryCount > 600 then setFatal("init retry limit: " .. tostring(msg)); return nil, initErr end
  return nil, msg
end
function M.init()
  if fatalErr then return nil, fatalErr end
  if PUO then return true end
  local ok, err = entity.init()
  if not ok then return retryable("entity.init: " .. tostring(err or "failed")) end
  clientBase = ffi.cast("uintptr_t", C.GetModuleHandleA("client.dll"))
  if clientBase == 0 then return retryable("client.dll not loaded") end
  local sok, serr = schema.init()
  if not sok then return retryable("schema.init: " .. tostring(serr or "failed")) end
  local puoFn = ffi.cast("PrepareUnitOrdersFn", clientBase + M.prepareUnitOrdersRVA)
  -- signature guard: 4C 89 4C 24 20 44 89 44 (8-byte 9-arg home-store prologue)
  local p = ffi.cast("uint8_t*", clientBase + M.prepareUnitOrdersRVA)
  local sigOk = (p[0]==0x4C and p[1]==0x89 and p[2]==0x4C and p[3]==0x24
             and p[4]==0x20 and p[5]==0x44 and p[6]==0x89 and p[7]==0x44)
  logLine(string.format("[order] PUO rva=0x%X sig=%s", M.prepareUnitOrdersRVA, sigOk and "ok" or "MISMATCH"))
  if not sigOk then setFatal("PrepareUnitOrders signature mismatch at rva 0x" .. string.format("%X", M.prepareUnitOrdersRVA)); return nil, initErr end
  -- all schema offsets must be valid before PUO is exposed
  local vals, errs = {}, {}
  for _, spec in ipairs(OFFSET_SPECS) do
    local v, e = schema.offsetOf(spec[2], spec[3])
    if v == nil then errs[#errs + 1] = spec[2] .. "." .. spec[3] .. " (" .. tostring(e or "nil") .. ")" end
    vals[spec[1]] = v
  end
  if #errs > 0 then
    logLine("[order] schema offsets missing: " .. table.concat(errs, ", "))
    return retryable("schema offsets missing: " .. table.concat(errs, ", "))
  end
  oIsLocal, oHeroPID, oCtrlPID, oSceneNode, oAbsOrigin =
    vals.oIsLocal, vals.oHeroPID, vals.oCtrlPID, vals.oSceneNode, vals.oAbsOrigin
  PUO = puoFn
  retryCount = 0
  logLine(string.format("[order] init ok rva=0x%X oIsLocal=0x%X oHeroPID=0x%X oCtrlPID=0x%X oSceneNode=0x%X oAbsOrigin=0x%X",
    M.prepareUnitOrdersRVA, oIsLocal, oHeroPID, oCtrlPID, oSceneNode, oAbsOrigin))
  return true
end

local function ensureInit()
  if fatalErr then return nil, fatalErr end
  if PUO then return true end
  return M.init()
end

function M.lastInitError() return initErr end

-- controllers / hero -------------------------------------------------------
-- O2: both lookups walk the entity list, so they are cached for cacheTtl.
-- A cached pointer is validated with a cheap field read before reuse (hero
-- respawn keeps the instance; end-of-match/reconnect invalidates).
function M.localController()
  local ok, err = ensureInit(); if not ok then return nil, err end
  local t = os.clock()
  local c = ctrlCache
  if c.inst and (t - c.at) < M.cacheTtl then
    local ok, v = pcall(function() return ru8(c.inst, oIsLocal) end)
    if ok and v ~= nil then return c.inst, c.pid end
  end
  for idn in entity.iter() do
    local dn = entity.designerName(idn)
    if dn and dn:find("player_controller", 1, true) then
      local inst = entity.instance(idn)
      if ru8(inst, oIsLocal) == 1 then
        c.inst, c.pid, c.at = inst, ri32(inst, oCtrlPID or 0), t
        return inst, c.pid
      end
    end
  end
  c.inst, c.at = nil, -1e9
  return nil
end

function M.localHero()
  local okInit, errInit = ensureInit(); if not okInit then return nil, errInit end
  local t = os.clock()
  local c = heroCache
  if c.inst and c.identity and (t - c.at) < M.cacheTtl then
    -- validate: identity+0x10 must still be a sane handle and the instance alive
    local ok, h = pcall(function() return ri32(c.identity, 0x10) end)
    if ok and h ~= nil and h ~= 0 and h ~= 0xFFFFFFFF then
      return c.inst, c.identity
    end
  end
  local h = entity.getLocalHero()
  if h then
    c.inst, c.identity, c.at = h.instance, h.identity, t
    return h.instance, h.identity
  end
  c.inst, c.identity, c.at = nil, nil, -1e9
  return nil
end

-- designer name of an issuer instance (logging only; cached)
local unitNameCache = {}
function M.unitName(inst)
  if not inst then return "?" end
  local cached = unitNameCache[inst]
  if cached then return cached end
  local name
  local ok, h = pcall(entity.getLocalHero)
  if ok and h and h.instance == inst then name = h.name end
  if not name then
    local ok2 = pcall(function()
      for idn in entity.iter() do
        if entity.instance(idn) == inst then name = entity.designerName(idn); break end
      end
    end)
    if not ok2 then name = nil end
  end
  name = name or "?"
  unitNameCache[inst] = name
  return name
end

function M.heroPosition(heroInst)
  local ok, err = ensureInit(); if not ok then return nil, err end
  heroInst = heroInst or M.localHero()
  if not heroInst then return nil end
  local node = rq(heroInst, oSceneNode)
  if not node or node < 0x10000 then return nil end
  return rf32(node, oAbsOrigin), rf32(node, oAbsOrigin + 4), rf32(node, oAbsOrigin + 8)
end

-- identity/entity-index helpers -------------------------------------------
-- Entity identities are opaque pointers (identity+0x10 = CHandle). Accept:
--   nil, numbers (already an entity index), identity pointers, {identity=...}
function M.entityIndex(v)
  if v == nil then return 0 end
  if type(v) == "number" then
    if v < 0 then return 0 end
    if v < 0x8000 then return v end
    -- a raw CHandle was passed: mask it
    return v % 0x8000
  end
  if type(v) == "table" and v.identity ~= nil then v = v.identity end
  local ok, h = pcall(function() return ri32(v, 0x10) end)
  if not ok or not h then return 0 end
  if h < 0 then h = h + 4294967296 end
  return h % 0x8000
end

function M.entityInstance(v)
  if v == nil then return nil end
  if type(v) == "number" then return nil end
  if type(v) == "table" and v.identity ~= nil then v = v.identity end
  local ok, inst = pcall(entity.instance, v)
  if ok then return inst end
  return nil
end

function M.setAbilityEncoding(mode)
  if mode ~= "entity" and mode ~= "slot" then return nil, "mode must be entity|slot" end
  abilityEncoding = mode
  return true
end
function M.getAbilityEncoding() return abilityEncoding end

-- ability slot resolution (used only in "slot" A/B mode and by diag probes).
-- Client NPC ability array layout (verified by api.lua abilitySlots):
--   NPC + 0x11C0 + 0x20 is the handle array; count at +0x11C0 + 0x10.
local function abilitySlots(npcInst)
  if not npcInst then return nil end
  local base = npcInst + 0x11C0
  local count = ri32(base, 0x10)
  if not count or count < 0 or count > 64 then return nil end
  local ptr = rq(base, 0x20)
  if not ptr or ptr < 0x10000 then return nil end
  return ptr, count
end

function M.abilitySlotOf(ability, issuerInst)
  local want = M.entityIndex(ability)
  if want == 0 or not issuerInst then return nil end
  local ptr, count = abilitySlots(issuerInst)
  if not ptr then return nil end
  for i = 0, count - 1 do
    local h = tonumber(ffi.cast("uint32_t*", ptr + i * 4)[0])
    if h and h ~= 0 and h ~= 0xFFFFFFFF then
      local idx = h % 0x8000
      if idx == want then return i end
    end
  end
  return nil
end

local function resolveAbilityIndex(ability, issuerInst)
  if ability == nil or ability == 0 then return 0 end
  if type(ability) == "number" then
    if ability < 0x8000 then return ability end
    return ability % 0x8000
  end
  if abilityEncoding == "slot" then
    local slot = M.abilitySlotOf(ability, issuerInst)
    if slot ~= nil then return slot end
    -- fall back to the entity index when the slot cannot be located
  end
  return M.entityIndex(ability)
end

-- order-record verification -------------------------------------------------
-- Read the last CUnitOrders entry the engine wrote to the controller. Used by
-- diag_orders.lua to prove that type/target/ability/queue reach the engine.
function M.lastEngineOrder()
  local okInit, errInit = ensureInit(); if not okInit then return nil, errInit end
  local ctrl = M.localController()
  if not ctrl then return nil end
  local size = ri32(ctrl, O_CTRL_ORDERS_SIZE)
  local ptr = rq(ctrl, O_CTRL_ORDERS_PTR)
  if not size or size <= 0 or size > 8 or not ptr or ptr < 0x10000 then return nil end
  local ord = ptr + (size - 1) * ORDER_STRIDE
  local rec = {
    size = size,
    seq = ri32(ord, O_ORDER_SEQ),
    type = ri32(ord, O_ORDER_TYPE),
    target = ri32(ord, O_ORDER_TARGET),
    ability = ri32(ord, O_ORDER_ABILITY),
    issuer = ri32(ord, O_ORDER_ISSUER),
    flags = ri32(ord, O_ORDER_FLAGS),
    x = rf32(ord, O_ORDER_POS),
    y = rf32(ord, O_ORDER_POS + 4),
    z = rf32(ord, O_ORDER_POS + 8),
  }
  return rec
end

-- Humanizer.GetOrderQueue backing: read the controller's pending CUnitOrders vector.
-- Returns a list of {player, orderType, target, ability, position, seq, addTime}.
-- addTime is approximated from the order's float timestamp @0x10 (falls back to now).
function M.getQueue()
  local okInit, errInit = ensureInit(); if not okInit then return {} end
  local ctrl = M.localController()
  if not ctrl then return {} end
  local size = ri32(ctrl, O_CTRL_ORDERS_SIZE)
  local ptr = rq(ctrl, O_CTRL_ORDERS_PTR)
  if not size or size <= 0 or size > 16 or not ptr or ptr < 0x10000 then return {} end
  local nowSec = wallSec()
  local out = {}
  for i = 0, size - 1 do
    local ord = ptr + i * ORDER_STRIDE
    if readable(ord, ORDER_STRIDE) then
      local ts = rf32(ord, 0x10)
      out[#out + 1] = {
        player = ctrl,
        orderType = ri32(ord, O_ORDER_TYPE) or 0,
        target = ri32(ord, O_ORDER_TARGET) or 0,
        ability = ri32(ord, O_ORDER_ABILITY) or 0,
        seq = ri32(ord, O_ORDER_SEQ) or 0,
        position = { x = rf32(ord, O_ORDER_POS) or 0, y = rf32(ord, O_ORDER_POS + 4) or 0, z = rf32(ord, O_ORDER_POS + 8) or 0 },
        addTime = (ts and ts > 0) and ts or nowSec,
      }
    end
  end
  return out
end
-- opts (optional table): player=, identifier=, callback=, executeFast=, forceMinimap=,
--                        ability= (entity or number), issuerNpc=, rawTarget=, dedupe=
-- The extra Umbrella parameters are recorded for diagnostics; they do not change
-- the native call (our loader bypasses Umbrella's humanizer layer entirely).
local function wallSec()
  local ok, v = pcall(function() return ffi.C.GetTickCount64() end)
  if ok and v then return tonumber(v) / 1000.0 end
  return os.clock()
end
M.wallSec = wallSec

-- high-resolution wall clock for the Present-thread drain wait (reviewer
-- condition: quantify the residual Sleep(1)-granularity cost per order)
local qpcFreq
local function nowMs()
  if qpcFreq == nil then
    qpcFreq = false
    local ok, f = pcall(function()
      local v = ffi.new("int64_t[1]")
      if ffi.C.QueryPerformanceFrequency(v) == 0 then return nil end
      return tonumber(v[0])
    end)
    if ok and f and f > 0 then qpcFreq = f end
  end
  if qpcFreq then
    local ok, v = pcall(function()
      local c = ffi.new("int64_t[1]")
      if ffi.C.QueryPerformanceCounter(c) == 0 then return nil end
      return tonumber(c[0])
    end)
    if ok and v then return v * 1000.0 / qpcFreq end
  end
  return wallSec() * 1000.0
end
M.nowMs = nowMs

logLine = function(msg)
  local f = io.open("D:\\hake\\lotus\\host.log", "a")
  if f then f:write(os.date("%H:%M:%S ") .. msg .. "\n"); f:close() end
end
M.logLine = logLine

-- O1: issue on the Present thread when the host queue exists, else direct call.
-- The drain happens synchronously inside the DXGI Present hook; we wait for the
-- controller order sequence to move so M.lastSeq (manual-order detection) and
-- the engine-record verification stay exact.
-- Self Play runs `core.manual()` (a 4 s pause) for every order the loader sees as
-- "human": loader.lua polls the controller order sequence and subtracts the
-- sequences we recorded ourselves. Nothing recorded them, so every bot order
-- paused the bot for 4 s (live symptom: "[SelfPlay manual] pause 4s" forever).
-- Mark the sequences our own dispatch produced; loader.lua reads this table.
local function markOwnSeq(before, after)
  if not before or not after or after <= before then return end
  local t = _G.__botOwnSeq
  if not t then t = {}; _G.__botOwnSeq = t end
  for s = before + 1, after do t[s] = true end
end
local function issueNative(ctrl, orderType, target, pos, abilityIdx, issuerMode, issuer, queueFlag, show)
  if M.orderMode ~= "direct" and not M.queueStats.disabled then
    local lib = hostQueue()
    if lib then
      local seqBefore = ri32(ctrl, O_CTRL_NEXT_SEQ)
      local okq, nq = pcall(lib.QueueOrder, ffi.cast("void*", ctrl), orderType, target,
                            pos[0], pos[1], pos[2], abilityIdx, ffi.cast("void*", issuer),
                            queueFlag and 1 or 0, show and 1 or 0)
      if okq and type(nq) == "number" and nq >= 0 then
        local tQ = nowMs()
        for _ = 1, drainTimeoutMs do
          ffi.C.Sleep(1)
          local s = ri32(ctrl, O_CTRL_NEXT_SEQ)
          if s and s ~= seqBefore then
            local d = nowMs() - tQ
            M.queueStats.queued = M.queueStats.queued + 1
            M.queueStats.drainN = M.queueStats.drainN + 1
            M.queueStats.drainSumMs = M.queueStats.drainSumMs + d
            if d > M.queueStats.drainMaxMs then M.queueStats.drainMaxMs = d end
            local prevTimeouts = M.queueStats.consecutiveTimeouts or 0
            M.queueStats.consecutiveTimeouts = 0
            if prevTimeouts > 0 then
              logLine(string.format("[order] queue drain recovered after %d timeout(s)", prevTimeouts))
            end
            markOwnSeq(seqBefore, s)
            return true, nil, true, s
          end
        end
        M.queueStats.consecutiveTimeouts = (M.queueStats.consecutiveTimeouts or 0) + 1
        M.queueStats.timeouts = (M.queueStats.timeouts or 0) + 1
        if M.queueStats.consecutiveTimeouts == 1 then
          logLine("[order] WARN queue drain timeout (Present hook not draining?) — direct-call fallback")
        end
        if M.queueStats.consecutiveTimeouts >= 5 and not M.queueStats.disabled then
          M.queueStats.disabled = true
          logLine("[order] WARN Present-thread order queue disabled after 5 CONSECUTIVE drain timeouts (direct mode)")
        end
      end
    end
  end
  M.queueStats.direct = M.queueStats.direct + 1
  local okInit, errInit = ensureInit(); if not okInit then return nil, errInit, false end
  -- crash guard (AI-14): a dangling ctrl/issuer makes the game AV inside PUO.
  -- Validate readability before the native call (pcall cannot catch an FFI AV).
  if not readable(ctrl, 0x9C0) then return nil, "ctrl unreadable", false end
  if not issuer or not readable(issuer, 0x358) then return nil, "issuer unreadable", false end
  -- lifeState guard for combat/movement orders only (item/purchase/train are legal
  -- while dead). m_lifeState (C_BaseEntity) @0x354, 0 == alive.
  if orderType <= 10 then
    local lok, life = pcall(function() return tonumber(ffi.cast("uint8_t*", ffi.cast("uintptr_t", issuer) + 0x354)[0]) end)
    if lok and life and life ~= 0 then return nil, "issuer dead lifeState=" .. life, false end
  end
  local seqBefore = ri32(ctrl, O_CTRL_NEXT_SEQ)
  local ok, ret = pcall(PUO, ffi.cast("void*", ctrl), orderType, target, pos, abilityIdx,
                        issuerMode, ffi.cast("void*", issuer), queueFlag, show,
                        0, 0, 0, 0)  -- AI-14: explicit callback/executeFast/identifier/forceMinimap defaults
  -- The outgoing seq (m_nNextOutgoingOrderSequenceNumber@0x9B8) increments when the
  -- order is SENT (next frame), not synchronously inside PUO. Reading it right after
  -- PUO often returns the old value, so markOwnSeq marked nothing and pollOrders then
  -- saw our own order as a HUMAN order -> perpetual "Paused: manual control".
  -- Optimistically mark seqBefore+1 (one order == one outgoing seq).
  local seqAfter = ri32(ctrl, O_CTRL_NEXT_SEQ) or seqBefore
  if seqBefore then markOwnSeq(seqBefore, math.max(seqAfter, seqBefore + 1)) end
  return ok, ret, false
end

function M.prepare(orderType, targetIndex, position, abilityIndex, issuerInst, queue, showEffects, opts)
  local okInit, errInit = ensureInit()
  if not okInit then M.stats.failed = M.stats.failed + 1; return nil, errInit end
  opts = opts or {}
  local ctrl = opts.player or M.localController()
  if not ctrl then M.stats.failed = M.stats.failed + 1; return nil, "no local controller" end
  local issuer = issuerInst or M.entityInstance(opts.issuerNpc) or M.localHero()
  if not issuer then M.stats.failed = M.stats.failed + 1; return nil, "no issuer" end

  orderType = tonumber(orderType) or 0
  local target = tonumber(targetIndex) or 0
  local ability = abilityIndex
  if ability == nil then ability = opts.ability end
  local abilityIdx = resolveAbilityIndex(ability, issuer)
  local queueFlag = queue == true
  local show = showEffects == true

  local px, py, pz = 0, 0, 0
  if position then
    px = tonumber(position.x or position[1]) or 0
    py = tonumber(position.y or position[2]) or 0
    pz = tonumber(position.z or position[3]) or 0
  end

  -- duplicate guard: identical order within dedupeWindow is dropped (protects
  -- against the same decision being executed twice by two call sites in a tick)
  local t = now()
  local last = M._lastSpec
  if M.dedupeWindow and M.dedupeWindow > 0 and last and last.type == orderType
    and last.target == target and last.ability == abilityIdx and last.issuer == issuer
    and (t - last.at) < M.dedupeWindow
    and math.abs(last.x - px) < 8 and math.abs(last.y - py) < 8 then
    return true, "deduped"
  end

  local pos = ffi.new("float[3]", px, py, pz)
  local issuerMode = M.ISSUER.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY or 3
  if opts.orderIssuer then issuerMode = tonumber(opts.orderIssuer) or issuerMode end
  local ok, ret, viaQueue, queueSeq = issueNative(ctrl, orderType, target, pos, abilityIdx,
                                                  issuerMode, issuer, queueFlag, show)
  if not ok then
    -- stale cached pointers are the usual cause: retry once with a fresh lookup
    M.invalidateCache()
  end

  M.stats.sent = M.stats.sent + 1
  M.stats.lastAt = t
  M.stats.byType[orderType] = (M.stats.byType[orderType] or 0) + 1

  local itemArg = nil
  if orderType == (M.ORDER.DOTA_UNIT_ORDER_PURCHASE_ITEM or 16)
    or orderType == (M.ORDER.DOTA_UNIT_ORDER_SELL_ITEM or 17)
    or orderType == (M.ORDER.DOTA_UNIT_ORDER_MOVE_ITEM or 19)
    or orderType == (M.ORDER.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM or 18)
    or orderType == (M.ORDER.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK or 32)
    or orderType == (M.ORDER.DOTA_UNIT_ORDER_TRAIN_ABILITY or 11) then
    itemArg = abilityIdx ~= 0 and abilityIdx or target
  end

  local spec = {
    at = t, type = orderType, target = target, ability = abilityIdx,
    issuer = issuer, issuerMode = issuerMode, orderIssuer = issuerMode,
    x = px, y = py, z = pz, queue = queueFlag, show = show,
    identifier = opts.identifier, callback = opts.callback == true,
    executeFast = opts.executeFast == true, forceMinimap = opts.forceMinimap == true,
    itemArg = itemArg, itemName = itemArg and M.itemName(itemArg) or nil,
    seq = -1, engine = nil, ok = ok and ret and true or false,
  }
  if not ok then
    M.stats.failed = M.stats.failed + 1
    spec.ok = false
    M._lastSpec = spec
    logOrder(spec, false, ret)
    return nil, tostring(ret)
  end
  -- purchase bookkeeping (P0-C): a repeated attempt means the item was not
  -- acquired by the previous order. Always log purchase lines for QA proof.
  local extra = nil
  if orderType == (M.ORDER.DOTA_UNIT_ORDER_PURCHASE_ITEM or 16) then
    local id = spec.ability ~= 0 and spec.ability or spec.target
    local p = M.purchases[id]
    if not p then p = { name = spec.itemName, count = 0, firstAt = t }; M.purchases[id] = p end
    p.count = p.count + 1
    p.lastAt = t
    if spec.itemName then p.name = spec.itemName end
    extra = string.format("buy-attempt=%d", p.count)
    if p.count > 1 then
      extra = extra .. string.format(" REPEAT(prev %.1fs ago)", p.lastAt - p.prevAt)
    end
    p.prevAt = t
  end
  -- stall oracle handoff (nav.lua, task-9 item 2): report move goals so nav can
  -- detect "engine refused the path" (hero not moving) and re-route; clear it on
  -- every non-move order (attack/cast/stop/hold) so farming in place is not
  -- mistaken for a stall.
  do
    local navm = package.loaded["nav"]
    if navm then
      if orderType == (M.ORDER.DOTA_UNIT_ORDER_MOVE_TO_POSITION or 1) then
        if navm.noteMoveOrder and (px ~= 0 or py ~= 0) then
          local ix, iy = M.heroPosition(issuer)
          if ix then pcall(navm.noteMoveOrder, ix, iy, px, py) end
        end
      elseif navm.clearMoveOrder then
        pcall(navm.clearMoveOrder)
      end
    end
  end
  -- record the outgoing sequence so the loader's manual-order detector can tell
  -- bot orders apart from human clicks (queued orders take the seq reported by
  -- the Present-thread drain)
  local seq = queueSeq or ri32(ctrl, O_CTRL_NEXT_SEQ)
  M.lastSeq = seq or -1
  spec.seq = M.lastSeq
  spec.viaQueue = viaQueue == true
  M.lastRecord = M.lastEngineOrder()
  spec.engine = M.lastRecord
  if M.lastRecord and M.lastRecord.seq == M.lastSeq then
    -- the engine recorded an order; if its type/target/ability differ from what
    -- we sent, our encoding is wrong (this is how a mapping bug is caught)
    if M.lastRecord.type ~= nil and spec.type ~= 0 and M.lastRecord.type ~= spec.type then
      M.stats.verifyMismatch = M.stats.verifyMismatch + 1
      spec.mismatch = string.format("type %d != %d", M.lastRecord.type, spec.type)
    elseif M.lastRecord.target ~= nil and spec.target ~= 0 and M.lastRecord.target ~= spec.target then
      M.stats.verifyMismatch = M.stats.verifyMismatch + 1
      spec.mismatch = string.format("target %d != %d", M.lastRecord.target, spec.target)
    elseif M.lastRecord.ability ~= nil and spec.ability ~= 0 and M.lastRecord.ability ~= spec.ability then
      M.stats.verifyMismatch = M.stats.verifyMismatch + 1
      spec.mismatch = string.format("ability %d != %d", M.lastRecord.ability, spec.ability)
    end
  end
  if spec.mismatch then extra = (extra and extra .. " " or "") .. "MISMATCH=" .. spec.mismatch end
  if not M._queueLogged then
    M._queueLogged = true
    logLine(string.format("[order] queue mode=%s hostlib=%s queueDisabled=%s",
      M.orderMode, tostring(hostlib ~= nil), tostring(M.queueStats.disabled)))
  end
  logOrder(spec, true, nil, extra)
  -- periodic order/queue counters (QA proof for O1: queued>0 direct=0)
  local ws = wallSec()
  if ws - (M._statsLogAt or -1e9) >= 60 then
    M._statsLogAt = ws
    logLine("[order] stats " .. M.statsLine())
  end
  M._lastSpec = spec
  M.historyN = M.historyN + 1
  M.history[((M.historyN - 1) % M.historySize) + 1] = spec
  return true, spec
end

-- convenience wrappers used by api.lua / diag scripts ----------------------
function M.moveTo(x, y, z, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_MOVE_TO_POSITION, 0, { x, y, z }, 0, nil, false, false, opts)
end
function M.moveToTarget(target, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_MOVE_TO_TARGET, M.entityIndex(target), nil, 0, nil, false, false, opts)
end
function M.attackMove(x, y, z, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_ATTACK_MOVE, 0, { x, y, z }, 0, nil, false, false, opts)
end
function M.attackTarget(target, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_ATTACK_TARGET, M.entityIndex(target), nil, 0, nil, false, false, opts)
end
function M.castPosition(ability, x, y, z, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_CAST_POSITION, 0, { x, y, z }, ability, nil, false, false, opts)
end
function M.castTarget(ability, target, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_CAST_TARGET, M.entityIndex(target), nil, ability, nil, false, false, opts)
end
function M.castTargetTree(ability, tree, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_CAST_TARGET_TREE, M.entityIndex(tree), nil, ability, nil, false, false, opts)
end
function M.castNoTarget(ability, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_CAST_NO_TARGET, 0, nil, ability, nil, false, false, opts)
end
function M.castToggle(ability, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_CAST_TOGGLE, 0, nil, ability, nil, false, false, opts)
end
function M.castToggleAuto(ability, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_CAST_TOGGLE_AUTO, 0, nil, ability, nil, false, false, opts)
end
function M.trainAbility(ability, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_TRAIN_ABILITY, 0, nil, ability, nil, false, false, opts)
end
function M.holdPosition(opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_HOLD_POSITION, 0, nil, 0, nil, false, false, opts)
end
function M.stop(opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_STOP, 0, nil, 0, nil, false, false, opts)
end
function M.buyItem(item, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_PURCHASE_ITEM, 0, nil, item, nil, false, false, opts)
end
function M.sellItem(item, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_SELL_ITEM, 0, nil, item, nil, false, false, opts)
end
function M.dropItem(item, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_DROP_ITEM, 0, nil, item, nil, false, false, opts)
end
function M.giveItem(item, target, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_GIVE_ITEM, M.entityIndex(target), nil, item, nil, false, false, opts)
end
function M.pickupItem(item, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_PICKUP_ITEM, M.entityIndex(item), nil, 0, nil, false, false, opts)
end
function M.pickupRune(rune, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_PICKUP_RUNE, M.entityIndex(rune), nil, 0, nil, false, false, opts)
end
function M.moveItem(item, slot, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_MOVE_ITEM, tonumber(slot) or 0, nil, item, nil, false, false, opts)
end
function M.disassembleItem(item, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM, 0, nil, item, nil, false, false, opts)
end
function M.setItemCombineLock(item, lock, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK, tonumber(lock) or 0, nil, item, nil, false, false, opts)
end
function M.glyph(opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_GLYPH, 0, nil, 0, nil, false, false, opts)
end
function M.buyback(opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_BUYBACK, 0, nil, 0, nil, false, false, opts)
end
function M.taunt(opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_TAUNT, 0, nil, 0, nil, false, false, opts)
end
function M.vectorTargetPosition(ability, x, y, z, opts)
  return M.prepare(M.ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION, 0, { x, y, z }, ability, nil, false, false, opts)
end

-- stats snapshot for diagnostics
function M.statsLine()
  local parts = {}
  for t, n in pairs(M.stats.byType) do parts[#parts + 1] = M.orderName(t) .. "=" .. n end
  table.sort(parts)
  local qs = M.queueStats
  local avg = qs.drainN > 0 and (qs.drainSumMs / qs.drainN) or 0
  return string.format("sent=%d failed=%d mismatches=%d lastSeq=%s queued=%d direct=%d drainTo=%d drainAvgMs=%.2f drainMaxMs=%.2f%s [%s]",
    M.stats.sent, M.stats.failed, M.stats.verifyMismatch, tostring(M.lastSeq),
    qs.queued, qs.direct, qs.timeouts, avg, qs.drainMaxMs,
    qs.disabled and " QUEUE-DISABLED" or "", table.concat(parts, " "))
end

-- current order-queue mode (diag/QA)
function M.setOrderMode(mode)
  if mode ~= "auto" and mode ~= "queue" and mode ~= "direct" then
    return nil, "mode must be auto|queue|direct"
  end
  M.orderMode = mode
  if mode ~= "direct" then M.queueStats.disabled = false end
  return true
end

return M



