package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
io.stdout:setvbuf("no")
local loader = require("loader")
print("standalone: loading Self Play ...")
local script, err = loader.load()
if script then print("LOAD OK") else print("LOAD FAILED: " .. tostring(err)) end