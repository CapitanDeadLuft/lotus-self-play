@echo off
pwsh -NoProfile -File "D:\hake\lotus\src\synth_click.ps1" -X %1 -Y %2 > "D:\hake\lotus\src\synth_result.txt" 2>&1
echo done >> "D:\hake\lotus\src\synth_result.txt"
