-- diag_events.lua — runtime evidence for the loader event synthesizer (task-2).
-- Run this INSTEAD of bot_loop.lua in a single-player bot game (QA owns runtime):
--   host16.dll!RunHost / call_elevated.bat <pid> with this script path.
-- It loads Self Play through loader.lua, wraps every Umbrella callback the 16.11
-- script exposes, and logs which callbacks actually fire and with what payload.
--
-- Evidence files:
--   D:\hake\lotus\host.log     — "EVDIAG" lines (greppable together with loader)
--   D:\hake\lotus\evdiag.log   — same lines, isolated
--   D:\hake\lotus\evdiag_names.txt — unique entity designer names (proves whether
--                                    projectile/particle entities are in the list)
-- Stop: write D:\hake\lotus\stop.txt (QA only).
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void Sleep(unsigned long ms); ]]
local loader = require("loader")
local entity = require("entity")

local HOST_LOG = "D:\\hake\\lotus\\host.log"
local EV_LOG = "D:\\hake\\lotus\\evdiag.log"
local NAMES_OUT = "D:\\hake\\lotus\\evdiag_names.txt"
local hostlog = io.open(HOST_LOG, "a")
local evlog = io.open(EV_LOG, "a")
local function log(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end
  local line = os.date("%H:%M:%S ") .. table.concat(t, "\t")
  if hostlog then hostlog:write("EVDIAG " .. line .. "\n"); hostlog:flush() end
  if evlog then evlog:write(line .. "\n"); evlog:flush() end
end

local function entDesc(e)
  if e == nil then return "nil" end
  local ty = type(e)
  if ty == "table" or ty == "userdata" or ty == "cdata" then
    local ok, nm = pcall(function() return entity.designerName(e) end)
    local ok2, idx = pcall(function() return _G.Entity and _G.Entity.GetIndex(e) end)
    return string.format("%s#%s", tostring(ok and nm or "?"), tostring(ok2 and idx or "?"))
  end
  return tostring(e)
end
local function vecDesc(v)
  if type(v) ~= "table" then return tostring(v) end
  return string.format("(%.0f,%.0f,%.0f)", tonumber(v.x) or 0, tonumber(v.y) or 0, tonumber(v.z) or 0)
end

-- payload description per callback -----------------------------------------
local describer = {
  OnEntityHurt = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("source=%s target=%s damage=%s ability=%s",
      entDesc(d.source), entDesc(d.target), tostring(d.damage), entDesc(d.ability))
  end,
  OnNpcDying = function(d) return entDesc(d) end,
  OnEntityDestroy = function(d) return entDesc(d) end,
  OnUnitAnimation = function(d)
    if type(d) ~= "table" then return tostring(d) end
    local keys = {}
    for k in pairs(d) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local v = d[k]
      if k == "unit" then v = entDesc(v)
      elseif type(v) == "number" then v = string.format("%.3f", v)
      else v = tostring(v) end
      parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return "keys(" .. #keys .. "): " .. table.concat(parts, " ")
  end,
  OnUnitAnimationEnd = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("unit=%s snap=%s", entDesc(d.unit), tostring(d.snap))
  end,
  OnProjectile = function(d)
    if type(d) ~= "table" then return tostring(d) end
    -- L3: dump the FULL payload key set so the contract can be checked statically
    local keys = {}
    for k in pairs(d) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
      local v = d[k]
      if k == "source" or k == "target" or k == "ability" then v = entDesc(v)
      elseif type(v) == "table" then v = vecDesc(v)
      else v = tostring(v) end
      parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return "keys(" .. #keys .. "): " .. table.concat(parts, " ")
  end,
  OnLinearProjectileCreate = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("handle=%s source=%s origin=%s velocity=%s distance=%s",
      tostring(d.handle), entDesc(d.source), vecDesc(d.origin), vecDesc(d.velocity), tostring(d.distance))
  end,
  OnLinearProjectileDestroy = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("handle=%s", tostring(d.handle))
  end,
  OnParticleCreate = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("index=%s fullName=%s entity=%s entity_for_modifiers=%s",
      tostring(d.index), tostring(d.fullName), entDesc(d.entity), entDesc(d.entityForModifiers))
  end,
  OnParticleUpdate = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("index=%s cp=%s pos=%s", tostring(d.index), tostring(d.controlPoint), vecDesc(d.position))
  end,
  OnParticleUpdateFallback = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("index=%s cp=%s pos=%s", tostring(d.index), tostring(d.controlPoint), vecDesc(d.position))
  end,
  OnParticleUpdateEntity = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("index=%s cp=%s entity=%s", tostring(d.index), tostring(d.controlPoint), entDesc(d.entity))
  end,
  OnParticleDestroy = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("index=%s", tostring(d.index))
  end,
  OnPrepareUnitOrders = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return string.format("player=%s order=%s issuer=%s npc=%s identifier=%s queue=%s",
      entDesc(d.player), tostring(d.order), tostring(d.orderIssuer), entDesc(d.npc),
      tostring(d.identifier), tostring(d.queue))
  end,
  OnGameEnd = function() return "(no payload)" end,
  OnGameStart = function() return "(no payload)" end,
  OnChatEvent = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return "type=" .. tostring(d.type) .. " value=" .. tostring(d.value)
  end,
  OnGCMessage = function(d)
    if type(d) ~= "table" then return tostring(d) end
    return "msg_type=" .. tostring(d.msg_type) .. " size=" .. tostring(d.size)
  end,
}

local CALLBACKS = {
  "OnEntityHurt", "OnNpcDying", "OnEntityDestroy", "OnUnitAnimation", "OnUnitAnimationEnd",
  "OnProjectile", "OnLinearProjectileCreate", "OnLinearProjectileDestroy",
  "OnParticleCreate", "OnParticleUpdate", "OnParticleUpdateFallback", "OnParticleUpdateEntity",
  "OnParticleDestroy", "OnPrepareUnitOrders", "OnGameEnd", "OnChatEvent", "OnGCMessage",
}

local counts, samples = {}, {}
local MAX_SAMPLES = 6
local function wrapCallback(script, name)
  local orig = script[name]
  if type(orig) ~= "function" then return false end
  counts[name] = 0
  script[name] = function(...)
    counts[name] = counts[name] + 1
    if (samples[name] or 0) < MAX_SAMPLES then
      samples[name] = (samples[name] or 0) + 1
      local d = ...
      local ok, txt = pcall(function()
        local f = describer[name]
        return f and f(d) or ("type=" .. type(d))
      end)
      log("CB " .. name, "#" .. counts[name], ok and txt or ("describe error: " .. tostring(txt)))
    end
    return orig(...)
  end
  return true
end

log("=== EVDIAG start (task-2 loader event synthesizer) ===")
log("build:", tostring(os.date("%Y-%m-%d %H:%M:%S")))
local script, err = loader.load()
if not script then log("LOAD FAIL", err); return end
local wrapped = 0
for _, name in ipairs(CALLBACKS) do
  if wrapCallback(script, name) then wrapped = wrapped + 1 end
end
log("wrapped callbacks:", wrapped)
-- central firing evidence (fires even if the script itself has no handler)
loader.setDiagHook(function(name, arg)
  counts["FIRE " .. name] = (counts["FIRE " .. name] or 0) + 1
end)
loader.setVerbose(false)

local namesDumped = false
local shimProbed = false
local function dumpNamesOnce()
  if namesDumped then return end
  local ok, list = pcall(loader.dumpEntityNames)
  if not ok or type(list) ~= "table" or #list == 0 then return end
  namesDumped = true
  local f = io.open(NAMES_OUT, "w")
  if f then
    f:write("entity names at " .. tostring(os.date("%H:%M:%S")) .. " count=" .. #list .. "\n")
    for _, line in ipairs(list) do f:write(line, "\n") end
    f:close()
  end
  local proj, part = 0, 0
  for _, line in ipairs(list) do
    local nm = line:sub(1, line:find(" idx=") - 1):lower()
    if nm:find("projectile") then proj = proj + 1 end
    if nm:find("particle") then part = part + 1 end
  end
  log(string.format("NAMES dumped=%d projectile_named=%d particle_named=%d -> %s",
    #list, proj, part, NAMES_OUT))
  -- dump a sample of unusual (non npc_dota / non modifier / non player) names
  local odd = {}
  for _, line in ipairs(list) do
    local nm = line:sub(1, line:find(" idx=") - 1)
    if not nm:find("npc_dota") and not nm:find("^modifier_") and not nm:find("player") then
      odd[#odd + 1] = nm
      if #odd >= 60 then break end
    end
  end
  log("NAMES odd sample: " .. table.concat(odd, ", "))
end

local loop = 0
local lastReport = os.clock()
local orderDumps = 0
local inMatchSeen = false
local heroName = nil
while true do
  local stop = io.open("D:\\hake\\lotus\\stop.txt", "r")
  if stop then stop:close(); log("stop.txt -> EVDIAG done"); break end
  loop = loop + 1
  local t0 = os.clock()
  local okTick, tickErr = pcall(loader.tick)
  local tickMs = (os.clock() - t0) * 1000
  if not okTick then log("tick error:", tickErr) end
  -- hero / game time snapshot
  local okh, h = pcall(function() return _G.Heroes and _G.Heroes.GetLocal() end)
  if okh and h then
    inMatchSeen = true
    local okn, nm = pcall(function() return _G.NPC.GetUnitName(h) end)
    heroName = okn and nm or nil
  end
  local okgt, gt = pcall(function() return _G.GameRules.GetGameTime() end)
  gt = (okgt and tonumber(gt)) or -1
  if h and not namesDumped then dumpNamesOnce() end
  if h and not shimProbed then
    shimProbed = true
    local okp, list = pcall(loader.probeShims)
    if okp and type(list) == "table" then
      for _, line in ipairs(list) do log("SHIM", line) end
    else
      log("SHIM probe error:", list)
    end
  end
  -- human order evidence: raw order queue dump on first few human orders
  if counts["OnPrepareUnitOrders"] and counts["OnPrepareUnitOrders"] > orderDumps and orderDumps < 4 then
    orderDumps = orderDumps + 1
    local okq, q = pcall(loader.dumpOrderQueue)
    if okq and type(q) == "table" then
      for _, line in ipairs(q) do log("ORDERQUEUE", line) end
    end
  end
  if os.clock() - lastReport > 10 then
    lastReport = os.clock()
    local st = loader.stats()
    local syn = loader.SYN or {}
    local parts = {}
    for name, n in pairs(counts) do parts[#parts + 1] = name .. "=" .. tostring(n) end
    table.sort(parts)
    log(string.format("STAT loop=%d tick=%.0fms gt=%.1f hero=%s polls=%d avg=%.2fms max=%.1fms err=%d dropped=%d human=%d drawSkip=%d",
      loop, tickMs, gt, tostring(heroName or "nil"), st.polls, (st.cost / math.max(1, st.polls)) * 1000,
      st.maxCost * 1000, st.errors, st.hurtsDropped, syn.humanOrders or 0, st.drawSkips))
    log("STAT counts:", table.concat(parts, " "))
    log("STAT inner fires:", (function()
      local p = {}
      for name, n in pairs(st.fires) do p[#p + 1] = name .. "=" .. n end
      table.sort(p); return table.concat(p, " ")
    end)())
  end
  for _ = 1, 3 do
    pcall(loader.drawOnly)
    pcall(require("overlay").pump)
    ffi.C.Sleep(15)
  end
end
log("=== EVDIAG done loops=" .. loop .. " inMatch=" .. tostring(inMatchSeen) .. " ===")