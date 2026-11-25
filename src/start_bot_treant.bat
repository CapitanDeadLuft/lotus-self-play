@echo off
rem Автозапуск бот-матча за Treant (elevated). Использование:
rem   Start-Process D:\hake\lotus\src\start_bot_treant.bat -Verb RunAs -Wait
rem Параметры можно передать через start_bot_treant.ps1 напрямую.
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\hake\lotus\src\start_bot_treant.ps1" > "D:\hake\lotus\src\start_bot_result.txt" 2>&1
echo done >> "D:\hake\lotus\src\start_bot_result.txt"