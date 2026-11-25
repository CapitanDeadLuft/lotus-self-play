param([int]$TargetPid,[string]$OutDir,[long]$Lo,[long]$Hi)
Add-Type -Namespace Q -Name M -MemberDefinition @"
[StructLayout(LayoutKind.Sequential)] public struct MEMORY_BASIC_INFORMATION { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, IntPtr len);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
"@
$ph=[Q.M]::OpenProcess(0x0410,$false,[uint32]$TargetPid)
if($ph -eq [IntPtr]::Zero){ "OpenProcess failed"; exit 1 }
$addr=[IntPtr]$Lo; $mbi=New-Object Q.M+MEMORY_BASIC_INFORMATION; $sz=[System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
$report=@()
while($addr.ToInt64() -lt $Hi){
  $r=[Q.M]::VirtualQueryEx($ph,$addr,[ref]$mbi,[IntPtr]$sz)
  if($r -eq [IntPtr]::Zero){ break }
  $base=$mbi.BaseAddress.ToInt64(); $size=$mbi.RegionSize.ToInt64()
  $line = "base=0x{0:X} size=0x{1:X} state=0x{2:X} type=0x{3:X} prot=0x{4:X}" -f $base,$size,$mbi.State,$mbi.Type,$mbi.Protect
  $report += $line
  if($mbi.State -eq 0x1000 -and $size -le 0x4000000 -and $size -ge 0x1000){
    $buf=New-Object byte[] $size; $rd=[IntPtr]::Zero
    if([Q.M]::ReadProcessMemory($ph,[IntPtr]$base,$buf,[IntPtr]$size,[ref]$rd) -and $rd.ToInt64() -gt 0){
      $path=Join-Path $OutDir ("ureg_{0:X}.bin" -f $base)
      [System.IO.File]::WriteAllBytes($path,$buf[0..([Math]::Max(0,$rd.ToInt64()-1))])
    }
  }
  $next=$base+$size; if($next -le $base){ break }
  $addr=[IntPtr]$next
}
[Q.M]::CloseHandle($ph) | Out-Null
$report | Out-File (Join-Path $OutDir 'uregions.txt') -Encoding UTF8
"regions=$($report.Count)"
