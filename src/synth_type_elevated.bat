@echo off
pwsh -NoProfile -File "D:\hake\lotus\src\synth_type.ps1" -Text %1 > "D:\hake\lotus\src\synth_type_result.txt" 2>&1
echo done >> "D:\hake\lotus\src\synth_type_result.txt"
