-- probe_identity.lua — ONE-SHOT: re-derive CEntityIdentity layout (next-node
-- pointer + designer-name offset) after a game update. Read-only, exits by
-- itself so the host watchdog stays free for the next run.txt.
require("loader")
local ent = require("entity")

local f = io.open("D:\\hake\\lotus\\host.log", "a")
local function L(fmt, ...)
  local ok, s = pcall(string.format, fmt, ...)
  if f then f:write(os.date("%H:%M:%S ") .. "[idprobe] " .. tostring(s or fmt) .. "\n"); f:flush() end
end

local function inRange(p)
  if not p then return false end
  local n = tonumber(p)
  return n and n > 0x10000 and n < 0x7FFFFFFFFFFF
end

local hero = _G.Heroes and _G.Heroes.GetLocal()
L("start hero=%s", hero and tostring(_G.NPC.GetUnitName(hero)) or "nil")

-- 1) where is the identity-list seed?
local seed = ent.debugSeed()
L("seed client=0x%X gr=0x%X proxy=0x%X seed=0x%X",
  tonumber(seed.client) or 0, tonumber(seed.gr) or 0, tonumber(seed.proxy) or 0, tonumber(seed.seed) or 0)

local function scanNode(node)
  -- designer name: first pointer in [node, node+0x120) that reads as "npc_*"
  for off = 0, 0x120, 8 do
    local p = ent.debugReadQ(node, off)
    if inRange(p) then
      local s = ent.debugCStr(p)
      if s and s:find("^npc_") then return off, s end
    end
  end
  return nil
end

-- 2) try candidate next-node offsets and measure the chain
local candidates = { 0x58, 0x50, 0x60, 0x48, 0x40, 0x68, 0x70, 0x78, 0x38, 0x30, 0x28 }
local best, bestOff = 0, nil
for _, off in ipairs(candidates) do
  local cur, n, named, sample = seed.seed, 0, 0, {}
  local firstSamples = {}
  while inRange(cur) and n < 20000 do
    n = n + 1
    local noff, nm = scanNode(cur)
    if nm then
      named = named + 1
      if #firstSamples < 3 then firstSamples[#firstSamples + 1] = string.format("+0x%X=%s", noff, nm) end
    end
    local nxt = ent.debugReadQ(cur, off)
    if not inRange(nxt) or tonumber(nxt) == 0 then break end
    cur = nxt
  end
  L("nextOff=0x%X chain=%d named=%d %s", off, n, named, table.concat(firstSamples, " "))
  if n > best and named > 0 then best, bestOff = n, off end
end

-- 3) report the designer-name offsets seen on the best chain
if bestOff then
  L("BEST nextOff=0x%X chain=%d", bestOff, best)
  local cur, n, seen = seed.seed, 0, {}
  while inRange(cur) and n < 20000 do
    n = n + 1
    local noff = scanNode(cur)
    if noff then seen[noff] = (seen[noff] or 0) + 1 end
    local nxt = ent.debugReadQ(cur, bestOff)
    if not inRange(nxt) or tonumber(nxt) == 0 then break end
    cur = nxt
  end
  for off, cnt in pairs(seen) do L("  designer-name offset 0x%X seen %d times", off, cnt) end
else
  L("no candidate produced a named chain")
end

-- 4) also probe the local hero identity directly (it IS an identity handle)
if hero then
  local noff, nm = scanNode(hero)
  L("hero identity designer: off=%s name=%s", noff and string.format("0x%X", noff) or "nil", tostring(nm))
  for off = 0, 0x200, 8 do
    local p = ent.debugReadQ(hero, off)
    if inRange(p) then
      local s = ent.debugCStr(p)
      if s then L("  hero+0x%X -> %s", off, s) end
    end
  end
end

L("done")