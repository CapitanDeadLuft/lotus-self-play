param([int]$X = 926, [int]$Y = 340, [switch]$NoFocus)
# Synthetic click helper: focus Dota (SDL_app), move cursor, click.
Add-Type -Namespace Win32 -Name Native -MemberDefinition @'
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr FindWindowA(string cls, string title);
  [DllImport("user32.dll")] public static extern IntPtr FindWindowExA(IntPtr p, IntPtr c, string cls, string title);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
'@
# Steam's steamwebhelper also creates SDL_app windows and FindWindowExA class
# search misses Dota's W-registered class: enumerate and match by process id.
$proc = Get-Process -Name dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "NO dota2 PROCESS"; exit 1 }
$dpid = [uint32]$proc.Id
$script:cand = [IntPtr]::Zero
$cb = [Win32.Native+EnumWindowsProc]{ param($hwnd, $l)
  $p = 0; [void][Win32.Native]::GetWindowThreadProcessId($hwnd, [ref]$p)
  if ($p -eq $dpid -and $hwnd -eq $proc.MainWindowHandle) { $script:cand = $hwnd }
  return $true }
[void][Win32.Native]::EnumWindows($cb, [IntPtr]::Zero)
$dota = $script:cand
if ($dota -eq [IntPtr]::Zero) { $dota = $proc.MainWindowHandle }
if ($dota -eq [IntPtr]::Zero) { Write-Output "NO DOTA WINDOW"; exit 1 }
whoami /groups | Select-String 'S-1-16-\d+' | ForEach-Object { "integrity: " + ($_ -replace '.*S-1-16-(\d+).*','$1') }
$first = [Win32.Native]::FindWindowA("SDL_app", $null)
$fp = 0; [void][Win32.Native]::GetWindowThreadProcessId($first, [ref]$fp)
$rr = New-Object Win32.Native+RECT; [void][Win32.Native]::GetWindowRect($first, [ref]$rr)
Write-Output ("FindWindowA-first hwnd={0} pid={1} rect=({2},{3},{4},{5}) | dota hwnd={6}" -f $first, $fp, $rr.L, $rr.T, $rr.R, $rr.B, $dota)
if (-not $NoFocus) {
  # Alt-key tap releases the foreground lock, then attach to the foreground thread.
  [Win32.Native]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
  [Win32.Native]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
  $fg = [Win32.Native]::GetForegroundWindow()
  $ftid = [Win32.Native]::GetWindowThreadProcessId($fg, [ref]$null)
  $mtid = [Win32.Native]::GetCurrentThreadId()
  [void][Win32.Native]::AttachThreadInput($mtid, $ftid, $true)
  [void][Win32.Native]::SetForegroundWindow($dota)
  [void][Win32.Native]::AttachThreadInput($mtid, $ftid, $false)
  Start-Sleep -Milliseconds 400
}
$fg2 = [Win32.Native]::GetForegroundWindow()
$fpid = 0; [void][Win32.Native]::GetWindowThreadProcessId($fg2, [ref]$fpid)
Write-Output ("dota pid={0} fg pid={1} foreground_ok={2}" -f $dpid, $fpid, ($fpid -eq $dpid))
[void][Win32.Native]::SetCursorPos($X, $Y)
Start-Sleep -Milliseconds 250
[Win32.Native]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero) # LEFTDOWN
Start-Sleep -Milliseconds 80
[Win32.Native]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero) # LEFTUP
Write-Output ("clicked at {0},{1}" -f $X, $Y)
