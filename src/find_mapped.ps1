param([int]$TargetPid,[string]$LogFile,[string]$OutDir)
Add-Type -Namespace V -Name M -MemberDefinition @"
[StructLayout(LayoutKind.Sequential)] public struct MEMORY_BASIC_INFORMATION { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, IntPtr len);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
"@
$lines=@()
$ph=[V.M]::OpenProcess(0x0410,$false,[uint32]$TargetPid)   # QUERY_INFORMATION|VM_READ
if($ph -eq [IntPtr]::Zero){ "OpenProcess failed" | Out-File $LogFile -Encoding UTF8; exit 1 }
$addr=[IntPtr]::Zero; $mbi=New-Object V.M+MEMORY_BASIC_INFORMATION; $sz=[System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
$cands=@()
while($true){
  $r=[V.M]::VirtualQueryEx($ph,$addr,[ref]$mbi,[IntPtr]$sz)
  if($r -eq [IntPtr]::Zero){ break }
  $base=$mbi.BaseAddress.ToInt64(); $size=$mbi.RegionSize.ToInt64()
  if($mbi.State -eq 0x1000 -and $mbi.Type -eq 0x20000 -and $size -ge 0x100000){
    $buf=New-Object byte[] 0x1000; $rd=[IntPtr]::Zero
    if([V.M]::ReadProcessMemory($ph,[IntPtr]$base,$buf,[IntPtr]0x1000,[ref]$rd) -and $rd.ToInt64() -ge 0x1000){
      if($buf[0] -eq 0x4D -and $buf[1] -eq 0x5A){
        $lfanew=[BitConverter]::ToInt32($buf,0x3C)
        if($lfanew -gt 0 -and $lfanew -lt 0x400 -and $buf[$lfanew] -eq 0x50 -and $buf[$lfanew+1] -eq 0x45){
          $cands += [pscustomobject]@{Base=$base; Size=$size; Proto=$mbi.AllocationProtect; SizeofImage=0}
          $lines += ("MZ-PE at 0x{0:X} region=0x{1:X} allocProtect=0x{2:X}" -f $base,$size,$mbi.AllocationProtect)
        }
      }
    }
  }
  $next=$base+$size
  if($next -le $base){ break }
  $addr=[IntPtr]$next
  if($base -gt 0x7FFFFFFF0000){ break }
}
[V.M]::CloseHandle($ph) | Out-Null
$lines += ("candidates=$($cands.Count)")
$lines | Out-File $LogFile -Encoding UTF8
