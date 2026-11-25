package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void R11_SetMenuOpen(int); ]]
local lib = ffi.load("D:\\hake\\lotus\\src\\host16.dll")
lib.R11_SetMenuOpen(0)
local f = io.open("D:\\hake\\lotus\\host.log", "a")
f:write(os.date("%H:%M:%S ") .. "close_menu probe set=0\n"); f:close()
