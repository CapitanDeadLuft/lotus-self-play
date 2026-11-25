@echo off
pwsh -NoProfile -File "D:\hake\lotus\src\synth_key.ps1" -Keys %1 -HoldMs %2 > "D:\hake\lotus\src\synth_key_result.txt" 2>&1
echo done >> "D:\hake\lotus\src\synth_key_result.txt"