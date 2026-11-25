-- assets/JSON.lua — Umbrella-compatible JSON lib (rxi-style :new/:decode/:encode).
package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local json = require("json")
local JSON = {}
JSON.__index = JSON

function JSON:new(options)
  return setmetatable({ options = options or {} }, JSON)
end
function JSON:decode(str)
  if type(str) ~= "string" then return nil end
  local ok, res = pcall(json.decode, str)
  if ok then return res end
  return nil
end
local function encode_value(v, out)
  local t = type(v)
  if t == "nil" then out[#out + 1] = "null"
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "number" then out[#out + 1] = tostring(v)
  elseif t == "string" then
    out[#out + 1] = '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
  elseif t == "table" then
    -- array?
    local n = #v
    if n > 0 or next(v) == nil then
      out[#out + 1] = "["
      for i = 1, n do encode_value(v[i], out); if i < n then out[#out + 1] = "," end end
      out[#out + 1] = "]"
    else
      out[#out + 1] = "{"
      local first = true
      for k, val in pairs(v) do
        if not first then out[#out + 1] = "," end; first = false
        encode_value(tostring(k), out); out[#out + 1] = ":"; encode_value(val, out)
      end
      out[#out + 1] = "}"
    end
  else out[#out + 1] = "null" end
end
function JSON:encode(value)
  local out = {}
  encode_value(value, out)
  return table.concat(out)
end
return JSON