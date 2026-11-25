param([string]$Probe = "", [int]$WaitStopSec = 45, [int]$WaitStartSec = 25)
# Restart the bot Lua state without restarting Dota:
# stop.txt -> wait for "=== BOT LOOP done ===" -> delete stop.txt -> RunHost.
$ErrorActionPreference = 'Stop'
$hostLog = 'D:\hake\lotus\host.log'
$dota = Get-Process dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $dota) { Write-Output 'NO dota2'; exit 1 }
$len0 = (Get-Item $hostLog).Length
Set-Content -Path 'D:\hake\lotus\stop.txt' -Value 'stop'
$deadline = (Get-Date).AddSeconds($WaitStopSec)
$stopped = $false
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 500
  $tail = Get-Content $hostLog -Tail 5
  if ($tail -match 'BOT LOOP done|stop.txt detected') { $stopped = $true; break }
}
if (-not $stopped) { Write-Output 'WARN: stop not observed within wait; continuing anyway' }
Start-Sleep -Milliseconds 800
Remove-Item 'D:\hake\lotus\stop.txt' -Force -ErrorAction SilentlyContinue
if ($Probe -ne '') {
  Copy-Item $Probe 'C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play\last_hit.lua' -Force
  $md5 = (Get-FileHash 'C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play\last_hit.lua' -Algorithm MD5).Hash
  Write-Output "probe installed md5=$md5"
}
$len1 = (Get-Item $hostLog).Length
# elevated RunHost
$p = Start-Process -Verb RunAs -FilePath cmd.exe -ArgumentList "/c `"D:\hake\lotus\src\call_elevated.bat $($dota.Id)`"" -Wait -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$fs = [System.IO.File]::Open($hostLog, 'Open', 'Read', 'ReadWrite')
$fs.Seek($len1, 'Begin') | Out-Null
$sr = New-Object System.IO.StreamReader($fs)
$txt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$n = ([regex]::Matches($txt, '=== BOT LOOP ===')).Count
$errs = ($txt -split "`n" | Select-String -Pattern 'LOAD FAIL|error|FAILED' | Where-Object { $_.Line -notmatch 'errors=0' } | Select-Object -First 3)
Write-Output "RunHost exit=$($p.ExitCode) botloop_markers=$n"
if ($errs) { Write-Output '--- suspicious lines ---'; $errs | ForEach-Object { $_.Line } }
if ($n -ne 1) { Write-Output 'WARN: expected exactly 1 BOT LOOP marker' }
# wait for the loop to actually tick
$deadline = (Get-Date).AddSeconds($WaitStartSec)
$ticks = 0
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 1
  $tail = Get-Content $hostLog -Tail 40
  $ticks = ([regex]::Matches(($tail -join "`n"), ' loop \d+ ')).Count
  if ($ticks -gt 0) { break }
}
Write-Output "ticks_seen=$ticks"
Get-Content 'D:\hake\lotus\src\call_result.txt' -ErrorAction SilentlyContinue