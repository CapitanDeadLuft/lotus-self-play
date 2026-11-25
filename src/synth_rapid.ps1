param([int]$X1 = 650, [int]$Y = 262, [int]$N = 4, [int]$GapMs = 150)
Add-Type -Namespace W32 -Name N -MemberDefinition @'
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
'@
$proc = Get-Process -Name dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { "NO dota2"; exit 1 }
[W32.N]::keybd_event(0x12,0,0,[IntPtr]::Zero); [W32.N]::keybd_event(0x12,0,2,[IntPtr]::Zero)
[void][W32.N]::SetForegroundWindow($proc.MainWindowHandle)
Start-Sleep -Milliseconds 300
$xs = @($X1, 517, 650, 850)
for ($i = 0; $i -lt $N; $i++) {
  $x = $xs[$i % $xs.Count]
  [void][W32.N]::SetCursorPos($x, $Y)
  Start-Sleep -Milliseconds 40
  [W32.N]::mouse_event(0x0002,0,0,0,[IntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [W32.N]::mouse_event(0x0004,0,0,0,[IntPtr]::Zero)
  Start-Sleep -Milliseconds $GapMs
}
"rapid clicks done N=$N"