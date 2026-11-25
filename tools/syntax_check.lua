package.path = "D:/hake/lotus/src/?.lua;" .. package.path
local pp = require("preprocess")
local path = arg[1]
local f = assert(io.open(path, "rb"))
local src = f:read("*a"); f:close()
local out = pp.transform(src)
local chunk, err = loadstring(out)
print(chunk and ("SYNTAX OK " .. tostring(#out)) or ("SYNTAX FAIL " .. tostring(err)))
