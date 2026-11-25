param([int]$TargetPid,[string]$OutFile,[string]$LogFile)
function Log([string]$m){ Add-Content -Path $LogFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'),$m) -Encoding UTF8 }
"=== start ===" | Out-File $LogFile -Encoding UTF8
Add-Type -Namespace D -Name M -MemberDefinition @"
[DllImport("dbghelp.dll", SetLastError=true)] public static extern bool MiniDumpWriteDump(IntPtr hProcess, uint pid, IntPtr hFile, uint dumpType, IntPtr exc, IntPtr user, IntPtr cab);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool OpenProcessToken(IntPtr proc, uint access, out IntPtr token);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool LookupPrivilegeValue(string host, string name, out long luid);
[DllImport("advapi32.dll", SetLastError=true)] public static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES newState, uint bufLen, IntPtr prev, IntPtr retLen);
[StructLayout(LayoutKind.Sequential)] public struct TOKEN_PRIVILEGES { public uint Count; public long Luid; public uint Attr; }
"@
$tp=New-Object D.M+TOKEN_PRIVILEGES
$tp.Count=1; $tp.Attr=2
$tok=[IntPtr]::Zero
if([D.M]::OpenProcessToken((Get-Process -Id $PID).Handle,0x28,[ref]$tok)){ [void][D.M]::LookupPrivilegeValue($null,"SeDebugPrivilege",[ref]$tp.Luid); [void][D.M]::AdjustTokenPrivileges($tok,$false,[ref]$tp,0,[IntPtr]::Zero,[IntPtr]::Zero); Log "SeDebugPrivilege enabled (err=$([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message))" } else { Log "OpenProcessToken failed" }
$ph=[D.M]::OpenProcess(0x1F0FFF,$false,[uint32]$TargetPid)
if($ph -eq [IntPtr]::Zero){ Log ("OpenProcess FAILED: " + [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message); exit 2 }
Log ("OpenProcess ok handle=0x{0:X}" -f $ph.ToInt64())
$fs=[System.IO.File]::Create($OutFile)
$ok=[D.M]::MiniDumpWriteDump($ph,[uint32]$TargetPid,$fs.SafeFileHandle.DangerousGetHandle(),0x00000002,$null,$null,$null)
$err=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
$fs.Close(); [void][D.M]::CloseHandle($ph)
if($ok){ Log ("MiniDumpWriteDump OK size=" + [math]::Round((Get-Item $OutFile).Length/1MB,1) + " MB") } else { Log ("MiniDumpWriteDump FAILED: " + [ComponentModel.Win32Exception]::new($err).Message) }
