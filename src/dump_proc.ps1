param([int]$pid,[string]$out)
Add-Type -Namespace D -Name M -MemberDefinition @"
[DllImport("dbghelp.dll", SetLastError=true)] public static extern bool MiniDumpWriteDump(IntPtr hProcess, uint pid, IntPtr hFile, uint dumpType, IntPtr exc, IntPtr user, IntPtr cab);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
"@
$ph=[D]::M::OpenProcess(0x1F0FFF,$false,[uint32]$pid)
if($ph -eq [IntPtr]::Zero){ "OpenProcess failed: $([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)"; exit 1 }
$fs=[System.IO.File]::Create($out)
$ok=[D]::M::MiniDumpWriteDump($ph,[uint32]$pid,$fs.SafeFileHandle.DangerousGetHandle(),0x00000002,$null,$null,$null)
$fs.Close(); [D]::M::CloseHandle($ph) | Out-Null
if($ok){ "dump ok: $out size=$([math]::Round((Get-Item $out).Length/1MB,1)) MB" } else { "dump failed: $([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)" }
