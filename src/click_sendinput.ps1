param([int]$X = 960, [int]$Y = 540, [int]$DelayMs = 120)
# SendInput absolute-move click helper (fallback when mouse_event-at-position
# clicks are ignored by the game). Focuses the dota2 window first.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class SI {
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  public const uint MOVE = 0x0001, ABS = 0x8000, DOWN = 0x0002, UP = 0x0004;
  static INPUT M(int dx, int dy, uint flags) { INPUT i = new INPUT(); i.type = 0; i.mi.dx = dx; i.mi.dy = dy; i.mi.dwFlags = flags; return i; }
  public static void Click(int x, int y) {
    int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
    int ax = (int)Math.Round(x * 65535.0 / (sw - 1)), ay = (int)Math.Round(y * 65535.0 / (sh - 1));
    INPUT[] seq = new INPUT[] { M(ax, ay, MOVE | ABS) };
    SendInput(1, seq, Marshal.SizeOf(typeof(INPUT)));
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(180);
    INPUT[] seq2 = new INPUT[] { M(ax, ay, MOVE | ABS), M(0, 0, DOWN), M(0, 0, UP) };
    SendInput(3, seq2, Marshal.SizeOf(typeof(INPUT)));
  }
}
'@
$p = Get-Process dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { Write-Output "NO dota2"; exit 1 }
[void][SI]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
[void][SI]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
[void][SI]::SetForegroundWindow($p.MainWindowHandle)
Start-Sleep -Milliseconds 400
$fg = [SI]::GetForegroundWindow()
Write-Output ("fg={0} dota={1} fg_ok={2}" -f $fg, $p.MainWindowHandle, ($fg -eq $p.MainWindowHandle))
[SI]::Click($X, $Y)
Start-Sleep -Milliseconds $DelayMs
Write-Output ("sendinput clicked at {0},{1}" -f $X, $Y)