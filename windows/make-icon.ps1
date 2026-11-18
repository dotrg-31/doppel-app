# Builds build\Doppel.ico from the logo (..\assets\doppel-icon-1024.png).
# The source is a macOS-style tile with a transparent margin; it is cropped to the tile
# so the icon fills the Windows taskbar slot like other apps, then resized to each size.
param(
    [string]$Png = (Join-Path $PSScriptRoot '..\assets\doppel-icon-1024.png'),
    [string]$OutFile = (Join-Path $PSScriptRoot 'build\Doppel.ico'),
    [int]$Crop = 92   # pixels trimmed from each edge of the 1024px source
)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Resolve-Path $Png))
$side = $src.Width - 2 * $Crop
$sizes = 256, 128, 64, 48, 40, 32, 24, 20, 16
$pngs = foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'
    $g.PixelOffsetMode = 'HighQuality'; $g.CompositingQuality = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $s, $s), $Crop, $Crop, $side, $side, ([System.Drawing.GraphicsUnit]::Pixel))
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    , $ms.ToArray()
}
$src.Dispose()
New-Item -ItemType Directory -Force (Split-Path $OutFile) | Out-Null
$fs = [System.IO.File]::Create($OutFile); $bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Close()
Write-Host "icon -> $OutFile"
