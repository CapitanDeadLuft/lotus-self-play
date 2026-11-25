param([int]$TargetPid,[string]$OutDir)
Add-Type -Namespace R -Name M -MemberDefinition @"
[DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
"@
$ph=[R.M]::OpenProcess(0x0410,$false,[uint32]$TargetPid)
if($ph -eq [IntPtr]::Zero){ "OpenProcess failed"; exit 1 }
$targets=@(
  @{name='bindtable'; base=[long]0x2AE89397000; size=0x18000},
  @{name='bigimage';   base=[long]0x4DA20000000; size=0xAB60000},
  @{name='misc1';      base=[long]0x2AE88F34000; size=0x10000},
  @{name='misc2';      base=[long]0x2AEB77E6000; size=0x10000}
)
foreach($t in $targets){
  $buf=New-Object byte[] $t.size; $rd=[IntPtr]::Zero
  $ok=[R.M]::ReadProcessMemory($ph,[IntPtr]$t.base,$buf,[IntPtr]$t.size,[ref]$rd)
  $got=$rd.ToInt64()
  $path=Join-Path $OutDir ("umbrella_{0}_{1:X}.bin" -f $t.name,$t.base)
  if($ok -or $got -gt 0){
    [System.IO.File]::WriteAllBytes($path,$buf[0..([Math]::Max(0,$got-1))])
    "OK $($t.name) base=0x$($t.base.ToString('X')) got=$got -> $path"
  } else { "FAIL $($t.name) base=0x$($t.base.ToString('X'))" }
}
[R.M]::CloseHandle($ph) | Out-Null
