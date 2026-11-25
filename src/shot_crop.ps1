param(
  [string]$Out = 'D:\hake\lotus\archive\20261123_fsl3\screen.png',
  [int]$X = 0, [int]$Y = 0, [int]$W = 0, [int]$H = 0,
  [double]$Scale = 1.0
)
# Screen capture helper (works from a Medium-IL pwsh for a High-IL Dota window).
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
if ($W -le 0) { $W = $b.Width }
if ($H -le 0) { $H = $b.Height }
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($X, $Y, 0, 0, (New-Object System.Drawing.Size($W, $H)))
$g.Dispose()
if ($Scale -ne 1.0) {
  $w2 = [int][Math]::Round($W * $Scale); $h2 = [int][Math]::Round($H * $Scale)
  $bmp2 = New-Object System.Drawing.Bitmap $w2, $h2
  $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g2.DrawImage($bmp, 0, 0, $w2, $h2)
  $g2.Dispose()
  $bmp.Dispose()
  $bmp = $bmp2
}
$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("captured screen region X={0} Y={1} W={2} H={3} scale={4} -> {5}" -f $X, $Y, $W, $H, $Scale, $Out)