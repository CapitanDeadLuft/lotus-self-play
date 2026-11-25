-- preprocess.lua — adapt Lua 5.4 source to LuaJIT 5.1: integer division // and bitwise ops.
-- Protects strings/comments, then rewrites operators to bit-library / floor-division calls.
local M = {}
local bit = require("bit")

-- expose helpers used by rewritten code as globals
_G.__idiv = function(a, b) return math.floor(a / b) end
_G.__band = bit.band
_G.__bor = bit.bor
_G.__bxor = bit.bxor
_G.__bnot = bit.bnot
_G.__shl = bit.lshift
_G.__shr = bit.rshift

-- protect strings and comments by replacing with placeholders
local function protect(src)
  local store = {}
  local out = {}
  local i, n = 1, #src
  local function stash(s) store[#store + 1] = s; return "\1STR" .. #store .. "\1" end
  while i <= n do
    local c = src:sub(i, i)
    local c2 = src:sub(i, i + 1)
    if c2 == "--" then
      -- comment
      if src:sub(i + 2, i + 3) == "[[" then
        local close = src:find("]]", i + 4, true)
        close = close and (close + 1) or n
        out[#out + 1] = stash(src:sub(i, close)); i = close + 1
      else
        local nl = src:find("\n", i, true)
        nl = nl and (nl - 1) or n
        out[#out + 1] = stash(src:sub(i, nl)); i = nl + 1
      end
    elseif c == '"' or c == "'" then
      local q = c; local j = i + 1
      while j <= n do
        local ch = src:sub(j, j)
        if ch == "\\" then j = j + 2
        elseif ch == q then break
        else j = j + 1 end
      end
      out[#out + 1] = stash(src:sub(i, j)); i = j + 1
    elseif c2 == "[[" then
      local close = src:find("]]", i + 2, true)
      close = close and (close + 1) or n
      out[#out + 1] = stash(src:sub(i, close)); i = close + 1
    else
      out[#out + 1] = c; i = i + 1
    end
  end
  return table.concat(out), store
end
local function restore(src, store)
  return (src:gsub("\1STR(%d+)\1", function(idx) return store[tonumber(idx)] end))
end

function M.transform(src)
  local code, store = protect(src)
  -- integer division: a // b  ->  __idiv(a, b)  (// binds like * /)
  code = code:gsub("(%b())%s*//%s*([%w_]+)", "__idiv(%1,%2)")
  code = code:gsub("([%w_]+)%s*//%s*(%b())", "__idiv(%1,%2)")
  code = code:gsub("([%w_]+)%s*//%s*([%w_]+)", "__idiv(%1,%2)")
  -- bitwise and/or/xor (binary): a & b -> __band(a,b)
  code = code:gsub("([%w_%.]+)%s*&%s*([%w_%.]+)", "__band(%1,%2)")
  code = code:gsub("([%w_%.]+)%s*|%s*([%w_%.]+)", "__bor(%1,%2)")
  code = code:gsub("([%w_%.]+)%s*~%s*([%w_%.]+)", "__bxor(%1,%2)")
  code = code:gsub("([%w_%.]+)%s*<<%s*([%w_%.]+)", "__shl(%1,%2)")
  code = code:gsub("([%w_%.]+)%s*>>%s*([%w_%.]+)", "__shr(%1,%2)")
  -- unary bitwise not: ~a -> __bnot(a)
  code = code:gsub("~%s*([%w_]+)", "__bnot(%1)")
  return restore(code, store)
end

return M