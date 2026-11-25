param([int]$X = 1697, [int]$Y = 1002)
# SendInput-based elevated click (QA fallback; mouse_event is ignored by some windows).
Add-Type -Namespace SIn -Name Native -MemberDefinition @'
  [StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
'@
$proc = Get-Process -Name dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "NO dota2"; exit 1 }
$dota = $proc.MainWindowHandle
[void][SIn.Native]::SetForegroundWindow($dota)
Start-Sleep -Milliseconds 300
[void][SIn.Native]::SetCursorPos($X, $Y)
Start-Sleep -Milliseconds 300
$SW = 1920; $SH = 1080
$ax = [int]($X * 65535 / $SW); $ay = [int]($Y * 65535 / $SH)
$inputs = New-Object 'SIn.Native+INPUT[]' 2
$inputs[0].type = 0; $inputs[0].mi.dx = $ax; $inputs[0].mi.dy = $ay; $inputs[0].mi.dwFlags = 0x0001 -bor 0x8000; $inputs[0].mi.mouseData = 0
$inputs[1].type = 0; $inputs[1].mi.dx = $ax; $inputs[1].mi.dy = $ay; $inputs[1].mi.dwFlags = 0x0002 -bor 0x8000; $inputs[1].mi.mouseData = 0
$sz = [System.Runtime.InteropServices.Marshal]::SizeOf([type]('SIn.Native+INPUT'))
$r = [SIn.Native]::SendInput(2, $inputs, $sz)
Write-Output ("SendInput n={0} size={1} err={2} clicked {3},{4}" -f $r, $sz, [System.Runtime.InteropServices.Marshal]::GetLastWin32Error(), $X, $Y)
