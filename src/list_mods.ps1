param([int]$TargetPid,[string]$LogFile)
Add-Type -Namespace T -Name K -MemberDefinition @"
[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct MODULEENTRY32W {
 public uint dwSize; public uint th32ModuleID; public uint th32ProcessID; public uint GlblcntUsage; public uint ProccntUsage;
 public IntPtr modBaseAddr; public uint modBaseSize; public IntPtr hModule;
 [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string szModule;
 [MarshalAs(UnmanagedType.ByValTStr, SizeConst=260)] public string szExePath; }
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool Module32FirstW(IntPtr snap, ref MODULEENTRY32W me);
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool Module32NextW(IntPtr snap, ref MODULEENTRY32W me);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
"@
$snap=[T.K]::CreateToolhelp32Snapshot(0x8,[uint32]$TargetPid)
if($snap -eq [IntPtr](-1)){ "snapshot failed" | Out-File $LogFile -Encoding UTF8; exit 1 }
$me=New-Object T.K+MODULEENTRY32W; $me.dwSize=[System.Runtime.InteropServices.Marshal]::SizeOf($me)
$lines=@()
if([T.K]::Module32FirstW($snap,[ref]$me)){
  do {
    $lines += ("{0}`t{1:X}`t{2:X}`t{3}" -f $me.szModule, $me.modBaseAddr.ToInt64(), $me.modBaseSize, $me.szExePath)
  } while([T.K]::Module32NextW($snap,[ref]$me))
}
[T.K]::CloseHandle($snap) | Out-Null
$lines | Out-File $LogFile -Encoding UTF8
"modules=$($lines.Count)"
