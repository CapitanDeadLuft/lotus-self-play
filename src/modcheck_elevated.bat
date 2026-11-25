@echo off
set PID=%1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -Id %PID% -Module -ErrorAction SilentlyContinue | Where-Object { $_.ModuleName -match 'gameoverlay|host16|nvwgf2|GameBar' } | ForEach-Object { $_.ModuleName + ' ver=' + $_.FileVersionInfo.FileVersion }" > D:\hake\lotus\modcheck.txt 2>&1
echo done >> D:\hake\lotus\modcheck.txt
