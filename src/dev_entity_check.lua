-- dev_entity_check.lua — offline unit test for the entity.lua per-tick caching
-- (task-17). Simulates the process memory + schema so no game/host16.dll is
-- needed and nothing touches host.log. Run:
--   luajit D:\hake\lotus\src\dev_entity_check.lua
package.path = "D:/hake/lotus/src/?.lua;" .. package.path
_G.ENTITY_NO_PROFILE = true  -- no [entity] lines in the live log during tests

-- fake process memory: addr -> value (int32 / pointer / u8 reads all use this)
local mem, names = {}, {}
local nameSeq = 0
local function nameAddr(s)
  nameSeq = nameSeq + 1
  local a = 0x40000000 + nameSeq * 0x100
  names[a] = s
  return a
end
local function idnAt(addr, inst, name, handle)
  mem[addr + 0x00] = inst
  mem[addr + 0x20] = nameAddr(name)
  mem[addr + 0x10] = handle or 0
  return addr
end

-- fake ffi
local fakeffi = { C = {}, cdef = function() end }
fakeffi.C.GetModuleHandleA = function() return 0x10000000 end
fakeffi.string = function(p, n)
  local addr = type(p) == "table" and p.addr or tonumber(p)
  return names[addr] or "\0"
end
function fakeffi.cast(ct, v)
  if ct == "uintptr_t" then return tonumber(v) end
  if ct == "void*" then return { addr = tonumber(v) } end
  return setmetatable({ addr = tonumber(v) }, {
    __index = function(_, k) if k == 0 then return mem[tonumber(v)] or 0 end end,
  })
end
package.preload["ffi"] = function() return fakeffi end
package.loaded["ffi"] = nil

-- fake schema (offsets chosen for the simulation)
local offCount = 0
local offsets = {
  ["C_BaseEntity.m_iHealth"] = 0x34C, ["C_BaseEntity.m_iMaxHealth"] = 0x348,
  ["C_BaseEntity.m_iTeamNum"] = 0x3E7, ["C_BaseEntity.m_lifeState"] = 0x354,
  ["CBasePlayerController.m_bIsLocalPlayerController"] = 0x100,
  ["C_DOTAPlayerController.m_nPlayerID"] = 0x200,
  ["C_DOTAPlayerController.m_hAssignedHero"] = 0x204,
  ["C_DOTA_BaseNPC_Hero.m_iPlayerID"] = 0x300,
}
package.preload["schema"] = function()
  return {
    init = function() return true end,
    offsetOf = function(cls, f)
      offCount = offCount + 1
      return offsets[cls .. "." .. f]
    end,
  }
end
package.loaded["schema"] = nil

local entity = require("entity")

-- ------------------------------------------------------------------ world
local base = 0x10000000
local gr, proxy = 0x20000000, 0x20001000
mem[base + 0x6219008] = gr
mem[gr + 0x08] = proxy
local ID = { 0x30000000, 0x30001000, 0x30002000, 0x30003000, 0x30004000, 0x30005000 }
local ctrlInst, heroInst = 0x50000000, 0x50001000
-- identity/instance/name/handle for: creep, player_controller, hero(treant), seed, tree, tower
local creep = idnAt(ID[1], 0x50010000, "npc_dota_creep_lane", 10)
local ctrl  = idnAt(ID[2], ctrlInst, "player_controller", 20)
local hero  = idnAt(ID[3], heroInst, "npc_dota_hero_treant", 55)
local seed  = idnAt(ID[4], 0x50040000, "npc_dota_gamerules", 90)
local tree  = idnAt(ID[5], 0x50050000, "ent_dota_tree", 60)
local tower = idnAt(ID[6], 0x50060000, "npc_dota_tower", 61)
-- doubly linked list: creep <-> ctrl <-> hero <-> seed <-> tree <-> tower
mem[creep + 0x50] = 0;            mem[creep + 0x58] = ctrl
mem[ctrl + 0x50] = creep;         mem[ctrl + 0x58] = hero
mem[hero + 0x50] = ctrl;          mem[hero + 0x58] = seed
mem[seed + 0x50] = hero;          mem[seed + 0x58] = tree
mem[tree + 0x50] = seed;          mem[tree + 0x58] = tower
mem[tower + 0x50] = tree;         mem[tower + 0x58] = 0
mem[proxy + 0x10] = seed
-- controller: local player, playerID 0, assigned hero handle 55
mem[ctrlInst + 0x100] = 1
mem[ctrlInst + 0x200] = 0
mem[ctrlInst + 0x204] = 55
-- hero instance fields
mem[heroInst + 0x34C] = 670
mem[heroInst + 0x348] = 700
mem[heroInst + 0x3E7] = 2
mem[heroInst + 0x354] = 0
mem[heroInst + 0x300] = 0

local fails, checks = 0, 0
local function check(name, cond, detail)
  checks = checks + 1
  if not cond then fails = fails + 1; print("FAIL " .. name .. (detail and (" :: " .. tostring(detail)) or "")) end
end
local function collect()
  local out = {}
  for idn in entity.iter() do out[#out + 1] = idn end
  return out
end

-- ------------------------------------------------------------ cache tests
check("init", entity.init() == true)
entity.beginTick()
local l1 = collect()
check("list order", #l1 == 6 and l1[1] == creep and l1[6] == tower, #l1)
check("one list build per tick", entity.stats.iterBuilds == 1, entity.stats.iterBuilds)
local l2 = collect()
check("second iter is cached", entity.stats.iterBuilds == 1, entity.stats.iterBuilds)
check("cached order identical", #l2 == 6 and l2[3] == hero)
check("no handle build yet", entity.stats.handleBuilds == 0, entity.stats.handleBuilds)
check("byHandle resolves hero", entity.byHandle(55) == hero)
check("exactly one handle-map build", entity.stats.handleBuilds == 1, entity.stats.handleBuilds)
check("tickBuilds<=2", entity.stats.tickBuilds <= 2, entity.stats.tickBuilds)
check("byHandle cached", entity.byHandle(55) == hero and entity.stats.handleBuilds == 1)
check("byHandle missing -> nil", entity.byHandle(9999) == nil and entity.byHandle(0) == nil and entity.byHandle(0xFFFFFFFF) == nil)
-- new tick -> exactly one new list build
entity.beginTick()
collect()
check("next tick rebuilds once", entity.stats.iterBuilds == 2, entity.stats.iterBuilds)
-- field() offset cache: second read must not ask schema again
entity.health(hero)
local before = offCount
entity.health(hero)
check("field offset cached", offCount == before, offCount - before)
-- local hero: cached per tick but health must stay live
mem[heroInst + 0x34C] = 670
local h1 = entity.getLocalHero()
check("local hero", h1 and h1.identity == hero and h1.name == "npc_dota_hero_treant", h1 and h1.name)
check("local hero playerID", h1 and h1.playerID == 0, h1 and h1.playerID)
check("local hero health live", h1 and h1.health == 670, h1 and h1.health)
local buildsBefore = entity.stats.iterBuilds
mem[heroInst + 0x34C] = 800
local h2 = entity.getLocalHero()
check("local hero cached same tick", entity.stats.iterBuilds == buildsBefore, entity.stats.iterBuilds)
check("cached record re-reads health", h2 and h2.health == 800, h2 and h2.health)
-- invalidate + match change: new hero identity appended, controller retargeted
local hero2 = idnAt(0x30006000, 0x50006000, "npc_dota_hero_axe", 66)
mem[hero2 + 0x50] = tower; mem[tower + 0x58] = hero2; mem[hero2 + 0x58] = 0
mem[ctrlInst + 0x204] = 66
mem[0x50006000 + 0x34C] = 550
entity.invalidate()
entity.beginTick()
local h3 = entity.getLocalHero()
check("hero change detected", h3 and h3.identity == hero2 and h3.name == "npc_dota_hero_axe", h3 and h3.name)
check("new hero health", h3 and h3.health == 550, h3 and h3.health)
check("byHandle rebuilt for new list", entity.byHandle(66) == hero2)
-- legacy (debug) switch: live walk works and does not touch snapshot counters
_G.ENTITY_NO_CACHE = true
local buildsNow = entity.stats.iterBuilds
local l3 = collect()
check("legacy iter works", #l3 >= 6, #l3)
check("legacy path does not build snapshot", entity.stats.iterBuilds == buildsNow, entity.stats.iterBuilds)
check("legacy byHandle works", entity.byHandle(55) == hero)
_G.ENTITY_NO_CACHE = false
entity.invalidate(); entity.beginTick(); collect()

print(string.format("dev_entity_check: %d checks, %d failed", checks, fails))
os.exit(fails == 0 and 0 or 1)