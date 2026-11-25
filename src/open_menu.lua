package.path = "D:\\hake\\lotus\\src\\?.lua;" .. package.path
local ffi = require("ffi")
ffi.cdef[[ void R11_SetMenuOpen(int); int R11_IsMenuOpen(void); ]]
local lib = ffi.load("D:\\hake\\lotus\\src\\host16.dll")
lib.R11_SetMenuOpen(1)
local f = io.open("D:\\hake\\lotus\\host.log", "a")
f:write(os.date("%H:%M:%S ") .. "open_menu probe set=1 is=" .. lib.R11_IsMenuOpen() .. "\n"); f:close()
