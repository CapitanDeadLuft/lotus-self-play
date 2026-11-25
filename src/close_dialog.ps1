param([int]$Hwnd = 1640232, [string]$Keys = "18,115")
# Focus a specific window by hwnd and send keys (VK codes, decimal).
# Used for the elevated ms-gamingoverlay OpenWith dialog (ALT+F4 = 18,115).
Add-Type -Namespace Win32D -Name Native -MemberDefinition @'
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern uint MapVirtualKeyA(uint vk, uint map);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
'@
$h = [IntPtr]$Hwnd
[Win32D.Native]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
[Win32D.Native]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
$fg = [Win32D.Native]::GetForegroundWindow()
$ftid = [Win32D.Native]::GetWindowThreadProcessId($fg, [ref]$null)
$mtid = [Win32D.Native]::GetCurrentThreadId()
[void][Win32D.Native]::AttachThreadInput($mtid, $ftid, $true)
[void][Win32D.Native]::SetForegroundWindow($h)
[void][Win32D.Native]::AttachThreadInput($mtid, $ftid, $false)
Start-Sleep -Milliseconds 500
$fg2 = [Win32D.Native]::GetForegroundWindow()
Write-Output ("target={0} foreground={1} focused_ok={2}" -f $Hwnd, $fg2, ($fg2 -eq $h))
$ks = $Keys -split ','
# press all modifiers first, then the final key, then release in reverse
for ($i = 0; $i -lt $ks.Count; $i++) {
  $vk = [int]$ks[$i]
  $scan = [Win32D.Native]::MapVirtualKeyA([uint]$vk, 0)
  [Win32D.Native]::keybd_event([byte]$vk, [byte]$scan, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 60
}
Start-Sleep -Milliseconds 80
for ($i = $ks.Count - 1; $i -ge 0; $i--) {
  $vk = [int]$ks[$i]
  $scan = [Win32D.Native]::MapVirtualKeyA([uint]$vk, 0)
  [Win32D.Native]::keybd_event([byte]$vk, [byte]$scan, 2, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 60
}
Write-Output "keys sent: $Keys"
