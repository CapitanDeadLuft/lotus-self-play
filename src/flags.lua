-- flags.lua — offline kill-switches for live bisection (2026-11-19 crash).
-- Reads D:\hake\lotus\features.txt (re-read when the file changes):
--   stub=Player.GetTeamPlayer     -> that API function returns nil instead of reading
--   stub=Entity.IsDormant         -> same for any ns.fn
--   off=visibility_mask           -> feature switch read by api/loader via flags.get()
-- Lines with '#' are comments. Missing file = everything enabled.
-- Purpose: find the deterministic lua51!lj_cconv_ct_ct crash 2 s after Self Play
-- starts WITHOUT editing/reloading code between runs (restart is via RunHost).
local M = {}
local PATH = "D:\\hake\\lotus\\features.txt"
local cache, cacheAt, cacheMtime = nil, 0, -1

-- GetFileAttributesExA-free mtime probe: opening the file is cheap (once/sec)
local function fileMtime()
  local f = io.open(PATH, "r")
  if not f then return -1 end
  local ok, size = pcall(function() return f:seek("end") end)
  f:close()
  return tonumber(size) or 0
end

function M.load()
  local now = os.clock()
  if cache and now - cacheAt < 1.0 then return cache end
  cacheAt = now
  local mt = fileMtime()
  if mt < 0 then
    cache = { stubs = {}, off = {} }
    return cache
  end
  if mt == cacheMtime and cache then return cache end
  cacheMtime = mt
  local c = { stubs = {}, off = {} }
  local f = io.open(PATH, "r")
  if f then
    for line in f:lines() do
      line = line:gsub("%s+$", "")
      if line ~= "" and line:sub(1, 1) ~= "#" then
        local k, v = line:match("^([%w_]+)%s*=%s*(.+)$")
        if k == "stub" and v then c.stubs[v] = true
        elseif k == "off" and v then c.off[v] = true end
      end
    end
    f:close()
  end
  cache = c
  return c
end

function M.get(name, default)
  local c = M.load()
  if c.off[name] then return false end
  return default ~= false
end

function M.stubbed(ns, fn)
  local c = M.load()
  return c.stubs[tostring(ns) .. "." .. tostring(fn)] == true
end

-- wrap the listed API members so they return nil/empty instead of reading memory
function M.applyStubs(log)
  local c = M.load()
  local n = 0
  for key in pairs(c.stubs) do
    local ns, fn = key:match("^([%w_]+)%.([%w_]+)$")
    if ns and fn then
      local target = _G[ns]
      if type(target) == "table" then
        target[fn] = function() return nil end
        n = n + 1
      end
    end
  end
  if n > 0 and log then log(string.format("[flags] stubbed %d API function(s) from features.txt", n)) end
  return n
end

return M