param([string]$Keys = "27", [int]$HoldMs = 60, [switch]$NoFocus)
# Elevated synthetic key helper for QA. Keys = comma separated VK codes (decimal or 0x..).
Add-Type -Namespace Win32K -Name Native -MemberDefinition @'
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern uint MapVirtualKeyA(uint vk, uint map);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
'@
$proc = Get-Process -Name dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "NO dota2 PROCESS"; exit 1 }
$dota = $proc.MainWindowHandle
if ($dota -eq [IntPtr]::Zero) { Write-Output "NO DOTA WINDOW"; exit 1 }
if (-not $NoFocus) {
  [Win32K.Native]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
  [Win32K.Native]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
  $fg = [Win32K.Native]::GetForegroundWindow()
  $ftid = [Win32K.Native]::GetWindowThreadProcessId($fg, [ref]$null)
  $mtid = [Win32K.Native]::GetCurrentThreadId()
  [void][Win32K.Native]::AttachThreadInput($mtid, $ftid, $true)
  [void][Win32K.Native]::SetForegroundWindow($dota)
  [void][Win32K.Native]::AttachThreadInput($mtid, $ftid, $false)
  Start-Sleep -Milliseconds 400
}
$fg2 = [Win32K.Native]::GetForegroundWindow()
$fpid = 0; [void][Win32K.Native]::GetWindowThreadProcessId($fg2, [ref]$fpid)
Write-Output ("dota pid={0} fg pid={1} foreground_ok={2}" -f $proc.Id, $fpid, ($fpid -eq $proc.Id))
foreach ($k in ($Keys -split ',')) {
  $vk = [int]$k
  # SDL/Source2 reads hardware scan codes; scan=0 events are dropped by the game.
  $scan = [Win32K.Native]::MapVirtualKeyA([uint]$vk, 0)  # MAPVK_VK_TO_VSC
  [Win32K.Native]::keybd_event([byte]$vk, [byte]$scan, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds $HoldMs
  [Win32K.Native]::keybd_event([byte]$vk, [byte]$scan, 2, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 120
  Write-Output ("key vk={0} scan={1} pressed+released" -f $vk, $scan)
}