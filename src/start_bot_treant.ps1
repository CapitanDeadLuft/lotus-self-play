# start_bot_treant.ps1 — автозапуск одиночного бот-матча за Treant Protector.
# Кликает: ИГРАТЬ -> ИГРА С БОТАМИ -> иконка Treant -> ВЫБРАТЬ.
# Dota elevated (HIGH integrity) -> использовать synth_click.ps1 (mouse_event),
# запускать скрипт ОТ АДМИНИСТРАТОРА (см. start_bot_treant.bat).
#
# Координаты сняты со скриншотов 21.11.2026 для окна Dota 1920x1080 @ (0,0),
# клиент RU, сборка 6986 (7.42), сортировка сетки "Атрибуты". Если разрешение/
# раскладка изменятся — координаты нужно переснять (см. docs/UI_AUTOSTART.md).
#
# Использование:  Start-Process start_bot_treant.bat -Verb RunAs
#   либо вручную: powershell -File start_bot_treant.ps1  (из elevated консоли)

param(
  [int]$MenuDelay = 2,      # пауза после ИГРАТЬ (открытие экрана режимов), с
  [int]$LoadDelay = 24,     # пауза после ИГРА С БОТАМИ (загрузка экрана пика), с
  [int]$PickDelay = 1,      # пауза после клика по иконке героя, с
  [switch]$Solo,            # дополнительно кликнуть радиокнопку ОДИНОЧНАЯ
  [switch]$DryRun           # только печатать шаги, не кликать
)

$ErrorActionPreference = 'Stop'
$click = 'D:\hake\lotus\src\synth_click.ps1'

# --- координаты (Dota 1920x1080 @ 0,0) ---
$P_PLAY      = @(1685, 1025)   # кнопка ИГРАТЬ в главном меню
$P_BOTSTART  = @(1700, 1035)   # зелёная ИГРА С БОТАМИ (низ панели режимов)
$P_SOLO      = @(1710, 485)    # радиокнопка ОДИНОЧНАЯ (секция ИГРА ПРОТИВ БОТОВ)
$P_TREANT    = @(202, 660)     # иконка Treant Protector (колонка СИЛА, T-ряд)
$P_SELECT    = @(1485, 828)    # кнопка ВЫБРАТЬ (под панелью предпросмотра)

function Step($name, $pt) {
  Write-Output ("{0}: click {1},{2}" -f $name, $pt[0], $pt[1])
  if (-not $DryRun) {
    & $click -X $pt[0] -Y $pt[1] | Out-Null
    Start-Sleep -Milliseconds 400
  }
}

if (-not (Get-Process -Name dota2 -ErrorAction SilentlyContinue)) {
  Write-Output "NO dota2 PROCESS — запустите Dota и выйдите в главное меню."; exit 1
}

Step "ИГРАТЬ" $P_PLAY
Start-Sleep -Seconds $MenuDelay
if ($Solo) { Step "ОДИНОЧНАЯ" $P_SOLO; Start-Sleep -Milliseconds 500 }
Step "ИГРА С БОТАМИ" $P_BOTSTART
Write-Output ("ждём экран пика {0}s..." -f $LoadDelay)
Start-Sleep -Seconds $LoadDelay
Step "Treant Protector" $P_TREANT
Start-Sleep -Seconds $PickDelay
Step "ВЫБРАТЬ" $P_SELECT
Write-Output "готово: матч с ботами за Treant должен начаться."