param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('install', 'restore', 'verify')]
  [string]$Action,
  [switch]$DryRun,
  [string]$Expect = ''
)
# ledger_probe_install.ps1 - install / restore / verify the two read-only probes
# for the ledger/noFlag measurement (2026-11-24):
#
#   live scripts\self_play\last_hit.lua  <- patches\last_hit.lua.ledger_probe
#   src\bot_loop_run.lua                 <- archive\20261123_fsl\bot_loop_run.lua.fsl_probe
#
# Pinned hashes:
#   live clean last_hit.lua (CE33)        CE33D41E8A477DE521C4CEB774B9AB79
#   clean runner (bot_loop_run.lua.clean) 60BE38ACE4DA9DEBDDD0B640D623F569
#   fsl probe                            0994160F5254694B124CB07FEDF7846A
#
# Actions:
#   install  refuse if Dota is running; assert live==CE33 and src==60BE38AC;
#            back the live file up to archive\20261124_ledger\last_hit.lua.before_install
#            (never overwritten once present); copy the probe build over live;
#            copy the fsl probe over the src runner; rotate an existing
#            probe_ledger.log into the archive; write install_state.json
#            (phase=installed, hashes.probe_build, ...).
#   restore  refuse if the backup is missing/mismatched; copy the backup back
#            over live and the clean runner over src; rotate a non-empty
#            probe_ledger.log to probe_ledger_final_<ts>.log; verify
#            CE33 / 60BE38AC and the absence of [ledg2]/[fsl] in live files;
#            write install_state.json (phase=clean).
#   verify   print hashes / probe presence / state phase; with -Expect
#            clean|installed exit non-zero on mismatch. Writes nothing.
#
# -DryRun: every validation and the full planned operation list, but ZERO
#          writes: no directory creation, no backups, no copies, no rotation,
#          no state json. Safe to run at any time.
#
# Run-book: docs\LEDGER_LIMITER_PLAN_2026-11-24.md §4.3, §5.
# Exit codes: 0 = OK, 1 = failure/refused/mismatch.

$ErrorActionPreference = 'Stop'

$root        = 'D:\hake\lotus'
$LiveLastHit = 'C:\Users\USER\AppData\Roaming\xYjGsPeqoWTEzbif\scripts\self_play\last_hit.lua'
$LiveHash    = 'CE33D41E8A477DE521C4CEB774B9AB79'
$BaseBackup  = "$root\backup_scripts_20261116_023749\last_hit.lua.bak_20261120_213938"
$ProbeBuild  = "$root\patches\last_hit.lua.ledger_probe"
# Pinned MD5 of the deterministic probe build (generated from the CE33 base);
# install refuses to copy a different build (see tools\make_ledger_probe.py).
$PinnedProbeHash = '4372E014B57A18520F89F061CB286AD9'
$CleanRunner = "$root\archive\20261123_fsl\bot_loop_run.lua.clean"
$CleanHash   = '60BE38ACE4DA9DEBDDD0B640D623F569'
$FslProbe    = "$root\archive\20261123_fsl\bot_loop_run.lua.fsl_probe"
$FslHash     = '0994160F5254694B124CB07FEDF7846A'
$SrcRunner   = "$root\src\bot_loop_run.lua"
$Archive     = "$root\archive\20261124_ledger"
$Before      = "$Archive\last_hit.lua.before_install"
$StateJson   = "$Archive\install_state.json"
$ProbeLog    = "$root\probe_ledger.log"
$Generator   = "$root\tools\make_ledger_probe.py"
$SelfPath    = $PSCommandPath
$LedgMarker  = '\[ledg2\]|ledg2Load'
$FslMarker   = '\[fsl\]'

function Write-Head([string]$text) { Write-Output "== $text ==" }
function Write-Step([string]$text) { Write-Output "   $text" }
function Write-Info([string]$text) { Write-Output "  $text" }

function Get-Md5([string]$path) {
  if (Test-Path -LiteralPath $path) { return (Get-FileHash -LiteralPath $path -Algorithm MD5).Hash }
  return 'MISSING'
}

function Get-Stamp { return (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') }
function Get-FileStamp { return (Get-Date).ToString('yyyyMMdd_HHmmss') }

function Assert-Exists([string]$path, [string]$label) {
  if (-not (Test-Path -LiteralPath $path)) { throw "$label missing: $path" }
}

function Assert-Hash([string]$path, [string]$expected, [string]$label) {
  $actual = Get-Md5 $path
  if ($actual -ne $expected) { throw "$label hash mismatch: $actual (expected $expected) [$path]" }
  return $actual
}

function Get-UniquePath([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $path }
  $dir  = Split-Path -Parent $path
  $base = [IO.Path]::GetFileNameWithoutExtension($path)
  $ext  = [IO.Path]::GetExtension($path)
  for ($i = 1; $i -le 999; $i++) {
    $candidate = Join-Path $dir ("{0}_{1}{2}" -f $base, $i, $ext)
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
  }
  throw "cannot find a unique archive path for $path"
}

function Get-MarkerCount([string]$path, [string]$pattern) {
  if (-not (Test-Path -LiteralPath $path)) { return -1 }
  return (Select-String -LiteralPath $path -Pattern $pattern -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Get-ProbeLogInfo {
  if (-not (Test-Path -LiteralPath $ProbeLog)) {
    return [ordered]@{ exists = $false; size = 0; lines = 0 }
  }
  $item = Get-Item -LiteralPath $ProbeLog
  return [ordered]@{ exists = $true; size = [int64]$item.Length; lines = @(Get-Content -LiteralPath $ProbeLog -ErrorAction SilentlyContinue).Count }
}

function Get-State {
  if (-not (Test-Path -LiteralPath $StateJson)) { return $null }
  try { return Get-Content -LiteralPath $StateJson -Raw | ConvertFrom-Json } catch { return $null }
}

function Write-StateJson([System.Collections.IDictionary]$state) {
  New-Item -ItemType Directory -Force -Path $Archive | Out-Null
  $json = $state | ConvertTo-Json -Depth 8
  [IO.File]::WriteAllText($StateJson, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
  return (Get-Md5 $StateJson)
}

function Get-CommonHashes {
  return [ordered]@{
    live_last_hit  = (Get-Md5 $LiveLastHit)
    src_runner     = (Get-Md5 $SrcRunner)
    base_backup    = (Get-Md5 $BaseBackup)
    probe_build    = (Get-Md5 $ProbeBuild)
    clean_runner   = (Get-Md5 $CleanRunner)
    fsl_probe      = (Get-Md5 $FslProbe)
    generator      = (Get-Md5 $Generator)
    installer      = (Get-Md5 $SelfPath)
  }
}

function Get-ProbeLogRotationPath([string]$kind) {
  return Get-UniquePath ("$Archive\{0}_{1}.log" -f $kind, (Get-FileStamp))
}

# --- validations shared by install/restore/verify ---------------------------
function Assert-ProbeBuild {
  Assert-Exists $ProbeBuild 'probe build'
  $probeHash = Get-Md5 $ProbeBuild
  if ($probeHash -eq 'MISSING' -or $probeHash -eq $LiveHash) {
    throw "probe build is invalid (hash $probeHash == clean base or missing): $ProbeBuild"
  }
  if ($probeHash -ne $PinnedProbeHash) {
    throw "probe build hash mismatch: $probeHash (expected pinned $PinnedProbeHash) [$ProbeBuild]; regenerate with tools\make_ledger_probe.py"
  }
  $ledg = Get-MarkerCount $ProbeBuild 'ledg2Load'
  if ($ledg -lt 1) { throw "probe build does not contain the ledg2Load marker: $ProbeBuild" }
  return $probeHash
}

function Assert-Inputs {
  Assert-Exists $BaseBackup 'clean base backup'
  Assert-Exists $CleanRunner 'clean runner'
  Assert-Exists $FslProbe 'fsl probe'
  Assert-Hash $BaseBackup $LiveHash 'clean base backup' | Out-Null
  Assert-Hash $CleanRunner $CleanHash 'clean runner' | Out-Null
  Assert-Hash $FslProbe $FslHash 'fsl probe' | Out-Null
}

# --- install ----------------------------------------------------------------
function Invoke-Install {
  Write-Head ("INSTALL ledger probe{0}" -f $(if ($DryRun) { ' (DryRun)' } else { '' }))
  if (Get-Process dota2 -ErrorAction SilentlyContinue) {
    throw 'dota2 is running: close it before installing the probes'
  }
  Write-Info 'dota2 is not running: OK'

  $probeHash = Assert-ProbeBuild
  Assert-Inputs
  Assert-Hash $LiveLastHit $LiveHash 'live last_hit.lua' | Out-Null
  Assert-Hash $SrcRunner $CleanHash 'src bot_loop_run.lua' | Out-Null
  Write-Info "live last_hit.lua = ${LiveHash}: OK"
  Write-Info "src bot_loop_run.lua = ${CleanHash}: OK"
  Write-Info "probe build = ${probeHash}: OK"

  if (Test-Path -LiteralPath $Before) {
    Assert-Hash $Before $LiveHash 'existing backup last_hit.lua.before_install' | Out-Null
    $backupPlanned = $false
    Write-Info "existing backup kept (never overwritten): $Before"
  } else {
    $backupPlanned = $true
    Write-Info "backup: $LiveLastHit -> $Before"
  }

  $logInfo = Get-ProbeLogInfo
  $rotationPlanned = $null
  if ($logInfo.exists) {
    $rotationPlanned = Get-ProbeLogRotationPath 'probe_ledger_prev'
    Write-Info "rotate existing probe log ($($logInfo.size) bytes) -> $rotationPlanned"
  } else {
    Write-Info 'no existing probe_ledger.log to rotate'
  }

  Write-Head 'planned operations'
  Write-Step ("{0} archive directory: {1}" -f $(if (Test-Path -LiteralPath $Archive) { 'keep' } else { 'create' }), $Archive)
  if ($backupPlanned) { Write-Step "backup live last_hit.lua -> $Before" } else { Write-Step "keep existing backup $Before" }
  Write-Step "copy $ProbeBuild -> $LiveLastHit"
  Write-Step "copy $FslProbe -> $SrcRunner"
  if ($rotationPlanned) { Write-Step "rotate $ProbeLog -> $rotationPlanned" }
  Write-Step "write $StateJson (phase=installed)"

  if ($DryRun) {
    Write-Head 'DRYRUN OK: validations passed, zero writes performed'
    exit 0
  }

  New-Item -ItemType Directory -Force -Path $Archive | Out-Null
  if ($backupPlanned) {
    Copy-Item -LiteralPath $LiveLastHit -Destination $Before -Force
    Assert-Hash $Before $LiveHash 'backed-up live last_hit.lua' | Out-Null
    Write-Info "backup written: $Before"
  }

  Copy-Item -LiteralPath $ProbeBuild -Destination $LiveLastHit -Force
  $liveAfter = Assert-Hash $LiveLastHit $probeHash 'installed live last_hit.lua'
  Write-Info "installed live last_hit.lua = $liveAfter"

  Copy-Item -LiteralPath $FslProbe -Destination $SrcRunner -Force
  $srcAfter = Assert-Hash $SrcRunner $FslHash 'installed src bot_loop_run.lua'
  Write-Info "installed src bot_loop_run.lua = $srcAfter"

  $rotated = $null
  if ($rotationPlanned) {
    Move-Item -LiteralPath $ProbeLog -Destination $rotationPlanned -Force
    $rotated = $rotationPlanned
    Write-Info "probe log rotated: $rotated"
  }

  $state = [ordered]@{
    phase       = 'installed'
    action      = 'install'
    at          = (Get-Stamp)
    root        = $root
    archive     = $Archive
    paths       = [ordered]@{
      live_last_hit          = $LiveLastHit
      probe_build            = $ProbeBuild
      src_runner             = $SrcRunner
      fsl_probe              = $FslProbe
      clean_runner           = $CleanRunner
      base_backup            = $BaseBackup
      probe_log              = $ProbeLog
      backup_before_install  = $Before
      state_json             = $StateJson
    }
    hashes      = [ordered]@{
      live_last_hit_before   = $LiveHash
      live_last_hit_after    = $liveAfter
      probe_build            = $probeHash
      src_runner_before      = $CleanHash
      src_runner_after       = $srcAfter
      fsl_probe              = $FslHash
      clean_runner           = $CleanHash
      base_backup            = (Get-Md5 $BaseBackup)
      generator              = (Get-Md5 $Generator)
      installer              = (Get-Md5 $SelfPath)
    }
    rotation    = [ordered]@{
      prev_probe_log    = $rotated
      probe_log_existed = [bool]$logInfo.exists
      probe_log_size    = [int64]$logInfo.size
    }
    preconditions = [ordered]@{
      dota2_running  = $false
      stop_txt_exists = (Test-Path -LiteralPath "$root\stop.txt")
    }
  }
  Write-StateJson $state | Out-Null
  Write-Info "state written: $StateJson (phase=installed)"
  Write-Head 'INSTALL OK'
  Write-Info "live last_hit.lua  = $(Get-Md5 $LiveLastHit)"
  Write-Info "src bot_loop_run.lua = $(Get-Md5 $SrcRunner)"
  Write-Info "backup = $Before"
  exit 0
}

# --- restore ----------------------------------------------------------------
function Invoke-Restore {
  Write-Head ("RESTORE ledger probe{0}" -f $(if ($DryRun) { ' (DryRun)' } else { '' }))
  if (Get-Process dota2 -ErrorAction SilentlyContinue) {
    Write-Info 'WARNING: dota2 is running; the client may rewrite scripts\ after restore - close it'
  }
  if (-not (Test-Path -LiteralPath $Before)) {
    throw "refusing restore: backup missing ($Before) - cannot prove the clean state"
  }
  Assert-Hash $Before $LiveHash 'backup last_hit.lua.before_install' | Out-Null
  Assert-Inputs
  Write-Info "backup = $Before ($LiveHash): OK"
  Write-Info "clean runner = ${CleanHash}: OK"

  $logInfo = Get-ProbeLogInfo
  $rotateFinal = $logInfo.exists -and ($logInfo.size -gt 0)
  $finalPath = $null
  if ($rotateFinal) {
    $finalPath = Get-ProbeLogRotationPath 'probe_ledger_final'
    Write-Info "rotate probe log ($($logInfo.size) bytes) -> $finalPath"
  } else {
    Write-Info 'probe_ledger.log missing or empty: no final rotation'
  }

  Write-Head 'planned operations'
  Write-Step "copy $Before -> $LiveLastHit"
  Write-Step "copy $CleanRunner -> $SrcRunner"
  if ($rotateFinal) { Write-Step "rotate $ProbeLog -> $finalPath" }
  Write-Step 'verify CE33 / 60BE38AC and no probe markers in live files'
  Write-Step "write $StateJson (phase=clean)"

  if ($DryRun) {
    Write-Head 'DRYRUN OK: validations passed, zero writes performed'
    exit 0
  }

  New-Item -ItemType Directory -Force -Path $Archive | Out-Null
  Copy-Item -LiteralPath $Before -Destination $LiveLastHit -Force
  $liveAfter = Assert-Hash $LiveLastHit $LiveHash 'restored live last_hit.lua'
  Write-Info "restored live last_hit.lua = $liveAfter"

  Copy-Item -LiteralPath $CleanRunner -Destination $SrcRunner -Force
  $srcAfter = Assert-Hash $SrcRunner $CleanHash 'restored src bot_loop_run.lua'
  Write-Info "restored src bot_loop_run.lua = $srcAfter"

  $rotated = $null
  if ($rotateFinal) {
    Move-Item -LiteralPath $ProbeLog -Destination $finalPath -Force
    $rotated = $finalPath
    Write-Info "probe log rotated: $rotated"
  }

  $ledgLeft = Get-MarkerCount $LiveLastHit $LedgMarker
  $fslLeft  = Get-MarkerCount $SrcRunner $FslMarker
  if ($ledgLeft -ne 0) { throw "restored live last_hit.lua still contains [ledg2] markers ($ledgLeft)" }
  if ($fslLeft -ne 0)  { throw "restored src bot_loop_run.lua still contains [fsl] markers ($fslLeft)" }
  Write-Info 'live files contain no probe markers: OK'

  $state = [ordered]@{
    phase    = 'clean'
    action   = 'restore'
    at       = (Get-Stamp)
    root     = $root
    archive  = $Archive
    paths    = [ordered]@{
      live_last_hit         = $LiveLastHit
      src_runner            = $SrcRunner
      backup_before_install = $Before
      clean_runner          = $CleanRunner
      fsl_probe             = $FslProbe
      probe_log             = $ProbeLog
      state_json            = $StateJson
    }
    hashes   = [ordered]@{
      live_last_hit_after = $liveAfter
      src_runner_after    = $srcAfter
      live_last_hit_clean = $LiveHash
      src_runner_clean    = $CleanHash
      base_backup         = (Get-Md5 $BaseBackup)
      clean_runner        = (Get-Md5 $CleanRunner)
      fsl_probe           = (Get-Md5 $FslProbe)
      probe_build         = (Get-Md5 $ProbeBuild)
      generator           = (Get-Md5 $Generator)
      installer           = (Get-Md5 $SelfPath)
    }
    rotation = [ordered]@{
      final_probe_log   = $rotated
      probe_log_existed = [bool]$logInfo.exists
      probe_log_size    = [int64]$logInfo.size
    }
    probes = [ordered]@{
      live_ledg2_markers = $ledgLeft
      src_fsl_markers    = $fslLeft
    }
  }
  Write-StateJson $state | Out-Null
  Write-Info "state written: $StateJson (phase=clean)"
  Write-Head 'RESTORE OK'
  Write-Info "live last_hit.lua  = $(Get-Md5 $LiveLastHit)"
  Write-Info "src bot_loop_run.lua = $(Get-Md5 $SrcRunner)"
  if ($rotated) { Write-Info "final probe log = $rotated" }
  exit 0
}

# --- verify -----------------------------------------------------------------
function Invoke-Verify {
  Write-Head 'VERIFY ledger probe'
  $common = Get-CommonHashes
  Write-Info "live last_hit.lua    : $($common.live_last_hit)  $LiveLastHit"
  Write-Info "src bot_loop_run.lua : $($common.src_runner)  $SrcRunner"
  Write-Info "base backup          : $($common.base_backup)  $BaseBackup"
  Write-Info "probe build          : $($common.probe_build)  $ProbeBuild"
  Write-Info "clean runner         : $($common.clean_runner)  $CleanRunner"
  Write-Info "fsl probe            : $($common.fsl_probe)  $FslProbe"

  $ledgCount = Get-MarkerCount $LiveLastHit $LedgMarker
  $fslCount  = Get-MarkerCount $SrcRunner $FslMarker
  Write-Info "live [ledg2] markers : $ledgCount"
  Write-Info "src [fsl] markers    : $fslCount"

  $logInfo = Get-ProbeLogInfo
  Write-Info ("probe_ledger.log     : exists={0} size={1} lines={2}" -f $logInfo.exists, $logInfo.size, $logInfo.lines)

  $state = Get-State
  if ($null -eq $state) {
    Write-Info 'install_state.json   : absent'
  } else {
    Write-Info "install_state.json   : phase=$($state.phase) at=$($state.at)"
    if ($null -ne $state.hashes) {
      Write-Info "  state hashes       : probe_build=$($state.hashes.probe_build) live_before=$($state.hashes.live_last_hit_before) live_after=$($state.hashes.live_last_hit_after)"
    }
  }

  if ($Expect -eq '') {
    Write-Head 'VERIFY OK (no expectation requested)'
    exit 0
  }
  if ($Expect -notin @('clean', 'installed')) {
    throw "-Expect must be 'clean' or 'installed' (got '$Expect')"
  }

  $problems = @()
  if ($Expect -eq 'clean') {
    if ($common.live_last_hit -ne $LiveHash) { $problems += "live last_hit.lua = $($common.live_last_hit) (expected clean $LiveHash)" }
    if ($common.src_runner -ne $CleanHash) { $problems += "src bot_loop_run.lua = $($common.src_runner) (expected clean $CleanHash)" }
    if ($ledgCount -ne 0) { $problems += "live last_hit.lua still has [ledg2] markers ($ledgCount)" }
    if ($fslCount -ne 0) { $problems += "src bot_loop_run.lua still has [fsl] markers ($fslCount)" }
    if ($null -ne $state -and $state.phase -ne 'clean') { $problems += "install_state.json phase=$($state.phase) (expected clean)" }
  } else {
    $expectedProbe = $common.probe_build
    if ($null -ne $state -and $null -ne $state.hashes -and $state.hashes.probe_build) {
      $expectedProbe = $state.hashes.probe_build
    }
    if ($common.live_last_hit -ne $expectedProbe) { $problems += "live last_hit.lua = $($common.live_last_hit) (expected probe $expectedProbe)" }
    if ($common.src_runner -ne $FslHash) { $problems += "src bot_loop_run.lua = $($common.src_runner) (expected fsl probe $FslHash)" }
    if ($ledgCount -lt 1) { $problems += 'live last_hit.lua has no [ledg2] markers (probe not installed)' }
    if ($fslCount -lt 1) { $problems += 'src bot_loop_run.lua has no [fsl] markers (probe not installed)' }
    if ($null -eq $state) {
      $problems += 'install_state.json missing (expected phase=installed)'
    } elseif ($state.phase -ne 'installed') {
      $problems += "install_state.json phase=$($state.phase) (expected installed)"
    }
  }

  if ($problems.Count -gt 0) {
    Write-Head "VERIFY MISMATCH (expect=$Expect)"
    foreach ($problem in $problems) { Write-Info "FAIL: $problem" }
    exit 1
  }
  Write-Head "VERIFY OK (expect=$Expect)"
  exit 0
}

try {
  switch ($Action) {
    'install' { Invoke-Install }
    'restore' { Invoke-Restore }
    'verify'  { Invoke-Verify }
    default   { throw "unknown action '$Action'" }
  }
} catch {
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
}