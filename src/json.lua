-- json.lua — minimal pure-Lua JSON decoder (for game data files).
local M = {}
local function decode_error(str, idx, msg) error(string.format("json decode error at %d: %s", idx, msg)) end
local function skip_ws(s, i)
  while i <= #s do
    local c = s:sub(i, i)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then i = i + 1 else break end
  end
  return i
end
local parse_value
local function parse_string(s, i)
  -- i points at opening quote
  local out = {}
  i = i + 1
  while i <= #s do
    local c = s:sub(i, i)
    if c == '"' then return table.concat(out), i + 1 end
    if c == "\\" then
      local e = s:sub(i + 1, i + 1)
      if e == "n" then out[#out + 1] = "\n"
      elseif e == "t" then out[#out + 1] = "\t"
      elseif e == "r" then out[#out + 1] = "\r"
      elseif e == "u" then
        local hex = s:sub(i + 2, i + 5)
        out[#out + 1] = string.char(tonumber(hex, 16) % 256)
        i = i + 4
      else out[#out + 1] = e end
      i = i + 2
    else
      out[#out + 1] = c; i = i + 1
    end
  end
  decode_error(s, i, "unterminated string")
end
local function parse_number(s, i)
  local j = i
  while j <= #s do
    local c = s:sub(j, j)
    if c:match("[%d%+%-%.eE]") then j = j + 1 else break end
  end
  local num = tonumber(s:sub(i, j - 1))
  if not num then decode_error(s, i, "invalid number") end
  return num, j
end
local function parse_array(s, i)
  local arr = {}
  i = skip_ws(s, i + 1)
  if s:sub(i, i) == "]" then return arr, i + 1 end
  while true do
    local v; v, i = parse_value(s, i)
    arr[#arr + 1] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "]" then return arr, i + 1 end
    if c ~= "," then decode_error(s, i, "expected , or ]") end
    i = skip_ws(s, i + 1)
  end
end
local function parse_object(s, i)
  local obj = {}
  i = skip_ws(s, i + 1)
  if s:sub(i, i) == "}" then return obj, i + 1 end
  while true do
    i = skip_ws(s, i)
    if s:sub(i, i) ~= '"' then decode_error(s, i, "expected key string") end
    local k; k, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ":" then decode_error(s, i, "expected :") end
    i = skip_ws(s, i + 1)
    local v; v, i = parse_value(s, i)
    obj[k] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "}" then return obj, i + 1 end
    if c ~= "," then decode_error(s, i, "expected , or }") end
    i = i + 1
  end
end
parse_value = function(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == '"' then return parse_string(s, i) end
  if c == "{" then return parse_object(s, i) end
  if c == "[" then return parse_array(s, i) end
  if s:sub(i, i + 3) == "true" then return true, i + 4 end
  if s:sub(i, i + 4) == "false" then return false, i + 5 end
  if s:sub(i, i + 3) == "null" then return nil, i + 4 end
  if c:match("[%d%-]") then return parse_number(s, i) end
  decode_error(s, i, "unexpected char " .. c)
end
function M.decode(s)
  local v, i = parse_value(s, 1)
  return v
end
function M.loadfile(path)
  local f = io.open(path, "rb"); if not f then return nil, "cannot open " .. path end
  local s = f:read("*a"); f:close()
  local ok, res = pcall(M.decode, s)
  if not ok then return nil, res end
  return res
end
return M