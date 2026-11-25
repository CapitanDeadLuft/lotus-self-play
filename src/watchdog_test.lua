local logf = io.open("D:\\hake\\lotus\\host.log", "a")
logf:write(os.date("%H:%M:%S ") .. "WATCHDOG-TEST: file-based iteration works, pid=" .. tostring(require("ffi").C.GetCurrentProcessId and "ok") .. "\n")
logf:close()