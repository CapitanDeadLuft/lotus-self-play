param([int]$TargetPid,[string]$LogFile)
Add-Type -Namespace S -Name M -MemberDefinition @"
[StructLayout(LayoutKind.Sequential)] public struct MEMORY_BASIC_INFORMATION { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, IntPtr len);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
"@
$needles=@('GetAbsOrigin','GetPhysicalArmorValue','IsPositionInRange','Heroes.InRadius','PrepareUnitOrders','GetSpellAmplification')
$pat=@{}
foreach($n in $needles){ $pat[$n]=[System.Text.Encoding]::ASCII.GetBytes($n) }
$log=@()
$ph=[S.M]::OpenProcess(0x0410,$false,[uint32]$TargetPid)
if($ph -eq [IntPtr]::Zero){ "OpenProcess failed" | Out-File $LogFile -Encoding UTF8; exit 1 }
$addr=[IntPtr]::Zero; $mbi=New-Object S.M+MEMORY_BASIC_INFORMATION; $sz=[System.Runtime.InteropServices.Marshal]::SizeOf($mbi)
$hits=0; $scanned=0
while($hits -lt 20){
  $r=[S.M]::VirtualQueryEx($ph,$addr,[ref]$mbi,[IntPtr]$sz)
  if($r -eq [IntPtr]::Zero){ break }
  $base=$mbi.BaseAddress.ToInt64(); $size=$mbi.RegionSize.ToInt64()
  $readable = ($mbi.Protect -band 0xFF) -in @(0x02,0x04,0x06,0x20,0x40,0x80,0x08,0x10)
  if($mbi.State -eq 0x1000 -and $readable -and $size -ge 0x10000){
    $chunk=4MB; $off=[long]0
    while($off -lt $size){
      $toRead=[int][Math]::Min($chunk, $size-$off)
      $buf=New-Object byte[] $toRead; $rd=[IntPtr]::Zero
      if([S.M]::ReadProcessMemory($ph,[IntPtr]($base+$off),$buf,[IntPtr]$toRead,[ref]$rd) -and $rd.ToInt64() -gt 0){
        $scanned += $rd.ToInt64()
        $s=[System.Text.Encoding]::Latin1.GetString($buf,0,$rd.ToInt64())
        foreach($n in $needles){
          $i=$s.IndexOf($n)
          if($i -ge 0){ $hits++; $log += ("HIT {0} at 0x{1:X} (regionBase=0x{2:X} regionSize=0x{3:X} type=0x{4:X} prot=0x{5:X})" -f $n,($base+$off+$i),$base,$size,$mbi.Type,$mbi.Protect); if($hits -ge 20){ break } }
        }
      }
      $off += $toRead
    }
  }
  $next=$base+$size
  if($next -le $base){ break }
  $addr=[IntPtr]$next
  if($base -gt 0x7FFFFFFF0000){ break }
}
[S.M]::CloseHandle($ph) | Out-Null
$log += ("scanned=$([math]::Round($scanned/1GB,2))GB hits=$hits")
$log | Out-File $LogFile -Encoding UTF8
"hits=$hits scanned=$([math]::Round($scanned/1GB,2))GB"
