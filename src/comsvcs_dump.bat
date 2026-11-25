@echo off
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump 13808 D:\hake\lotus\dumps\umbrella_live.dmp full
echo EXIT=%ERRORLEVEL% > D:\hake\lotus\dumps\comsvcs_result.txt
dir D:\hake\lotus\dumps\umbrella_live.dmp >> D:\hake\lotus\dumps\comsvcs_result.txt 2>&1
