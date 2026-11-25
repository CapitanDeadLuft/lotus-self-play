@echo off
"D:\hake\lotus\luajit\src\src\luajit.exe" "D:\hake\lotus\src\inject.lua" %1 "D:\hake\lotus\src\host16.dll" > "D:\hake\lotus\src\inject_result.txt" 2>&1
echo done >> "D:\hake\lotus\src\inject_result.txt"