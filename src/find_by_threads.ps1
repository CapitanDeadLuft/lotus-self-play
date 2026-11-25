param([int]$TargetPid,[string]$LogFile,[string]$ModsFile)
Add-Type -Namespace T -Name M -MemberDefinition @"
[StructLayout(LayoutKind.Sequential)] public struct THREADENTRY32 { public uint dwSize; public uint cntUsage; public uint th32ThreadID; public uint th32OwnerProcessID; public int tpBasePri; public int tpDeltaPri; public uint dwFlags; }
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool Thread32First(IntPtr snap, ref THREADENTRY32 te);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool Thread32Next(IntPtr snap, ref THREADENTRY32 te);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenThread(uint access, bool inherit, uint tid);
[DllImport("ntdll.dll")] public static extern int NtQueryInformationThread(IntPtr h, int cls, out IntPtr info, int len, out int ret);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[StructLayout(LayoutKind.Sequential)] public struct MEMORY_BASIC_INFORMATION { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MEMORY_BASIC_INFORMATION mbi, IntPtr len);
"@
$mods=@()
foreach($line in Get-Content $ModsFile){ $p=$line -split "`t"; if($p.Count -ge 3){ $mods += [pscustomobject]@{Name=$p[0]; Base=[Convert]::ToInt64($p[1],16); Size=[Convert]::ToInt64($p[2],16)} } }
function ModOf([long]$a){ foreach($m in $mods){ if($a -ge $m.Base -and $a -lt ($m.Base+$m.Size)){ return $m.Name } } return $null }
$ph=[T.M]::OpenProcess(0x0410,$false,[uint32]$TargetPid)
$snap=[T.M]::CreateToolhelp32Snapshot(0x4,[uint32]$TargetPid)
$te=New-Object T.M+THREADENTRY32; $te.dwSize=[System.Runtime.InteropServices.Marshal]::SizeOf($te)
$out=@()
if([T.M]::Thread32First($snap,[ref]$te)){
  do {
    if($te.th32OwnerProcessID -eq $TargetPid){
      $th=[T.M]::OpenThread(0x0040,$false,$te.th32ThreadID)  # THREAD_QUERY_INFORMATION
      if($th -ne [IntPtr]::Zero){
        $start=[IntPtr]::Zero; $rl=0
        [void][T.M]::NtQueryInformationThread($th,9,[ref]$start,[IntPtr]::Size,[ref]$rl)
        [T.M]::CloseHandle($th) | Out-Null
        $a=$start.ToInt64()
        if($a -ne 0){
          $m=ModOf $a
          $mbi=New-Object T.M+MEMORY_BASIC_INFORMATION
          $null=[T.M]::VirtualQueryEx($ph,[IntPtr]$a,[ref]$mbi,[IntPtr][System.Runtime.InteropServices.Marshal]::SizeOf($mbi))
          $out += ("tid={0} start=0x{1:X} module={2} regionBase=0x{3:X} regionSize=0x{4:X} type=0x{5:X} prot=0x{6:X}" -f $te.th32ThreadID,$a,($(if($m){$m}else{'?PRIVATE?'})),$mbi.BaseAddress.ToInt64(),$mbi.RegionSize.ToInt64(),$mbi.Type,$mbi.Protect)
        }
      }
    }
  } while([T.M]::Thread32Next($snap,[ref]$te))
}
[T.M]::CloseHandle($snap) | Out-Null
[T.M]::CloseHandle($ph) | Out-Null
$out | Out-File $LogFile -Encoding UTF8
"threads=$($out.Count)"
