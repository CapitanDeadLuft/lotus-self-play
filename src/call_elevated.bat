@echo off
"D:\hake\lotus\luajit\src\src\luajit.exe" "D:\hake\lotus\src\call_export.lua" %1 "D:\hake\lotus\src\host16.dll" RunHost > "D:\hake\lotus\src\call_result.txt" 2>&1
echo done >> "D:\hake\lotus\src\call_result.txt"
