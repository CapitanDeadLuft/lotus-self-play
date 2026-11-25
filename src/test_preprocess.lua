package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local preprocess = require("preprocess")
local base = "C:\\Users\\USER\\AppData\\Roaming\\xYjGsPeqoWTEzbif\\scripts\\self_play\\"
for _, f in ipairs({ "field.lua", "prediction.lua", "awareness.lua", "catalog.lua" }) do
  io.write("transforming " .. f .. " ... "); io.flush()
  local fh = io.open(base .. f, "rb"); local src = fh:read("*a"); fh:close()
  local t0 = os.clock()
  local out = preprocess.transform(src)
  io.write(string.format("OK %d->%d bytes, %.3fs\n", #src, #out, os.clock() - t0)); io.flush()
end
print("ALL DONE")