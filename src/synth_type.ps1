param([string]$Text = "", [switch]$NoFocus)
# Elevated synthetic text helper: SendInput KEYEVENTF_UNICODE, layout-independent.
Add-Type -Namespace Win32T -Name Native -MemberDefinition @'
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] p, int sz);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
  [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION {
    [FieldOffset(0)] public KEYBDINPUT ki;
    [FieldOffset(0)] public MOUSEINPUT mi; }
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT {
    public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT {
    public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
'@
$proc = Get-Process -Name dota2 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Write-Output "NO dota2 PROCESS"; exit 1 }
$dota = $proc.MainWindowHandle
if (-not $NoFocus) {
  [Win32T.Native]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
  [Win32T.Native]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
  $fg = [Win32T.Native]::GetForegroundWindow()
  $ftid = [Win32T.Native]::GetWindowThreadProcessId($fg, [ref]$null)
  $mtid = [Win32T.Native]::GetCurrentThreadId()
  [void][Win32T.Native]::AttachThreadInput($mtid, $ftid, $true)
  [void][Win32T.Native]::SetForegroundWindow($dota)
  [void][Win32T.Native]::AttachThreadInput($mtid, $ftid, $false)
  Start-Sleep -Milliseconds 400
}
$fg2 = [Win32T.Native]::GetForegroundWindow()
$fpid = 0; [void][Win32T.Native]::GetWindowThreadProcessId($fg2, [ref]$fpid)
Write-Output ("dota pid={0} fg pid={1} foreground_ok={2}" -f $proc.Id, $fpid, ($fpid -eq $proc.Id))
# INPUT struct on x64: type(4)+pad(4)+union(32) = 40 bytes; KEYBDINPUT = 24 bytes.
$sz = [System.Runtime.InteropServices.Marshal]::SizeOf([type][Win32T.Native+INPUT])
foreach ($ch in $Text.ToCharArray()) {
  $down = New-Object Win32T.Native+INPUT
  $down.type = 1  # INPUT_KEYBOARD
  $down.u.ki.wScan = [ushort][char]$ch
  $down.u.ki.dwFlags = 0x0004  # KEYEVENTF_UNICODE
  $up = New-Object Win32T.Native+INPUT
  $up.type = 1
  $up.u.ki.wScan = [ushort][char]$ch
  $up.u.ki.dwFlags = 0x0004 -bor 0x0002  # UNICODE | KEYUP
  [void][Win32T.Native]::SendInput(1, @($down), $sz)
  Start-Sleep -Milliseconds 30
  [void][Win32T.Native]::SendInput(1, @($up), $sz)
  Start-Sleep -Milliseconds 30
}
Write-Output ("typed {0} chars" -f $Text.Length)
