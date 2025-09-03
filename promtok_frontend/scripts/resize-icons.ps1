Param(
  [string]$Source = "$PSScriptRoot/../public/icon_original.PNG",
  [string]$OutDir = "$PSScriptRoot/../public",
  [switch]$SkipDark
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Source)) { throw "Source not found: $Source" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Add-Type -AssemblyName System.Drawing

function Invoke-WithRetry {
  param(
    [scriptblock]$Action,
    [int]$Retries = 5,
    [int]$DelayMs = 300
  )
  for ($i = 0; $i -lt $Retries; $i++) {
    try {
      & $Action
      return
    } catch {
      if ($i -eq ($Retries-1)) { throw }
      [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers();
      Start-Sleep -Milliseconds $DelayMs
    }
  }
}

function Resize-Png {
  param(
    [int]$Width,
    [int]$Height,
    [string]$OutPath
  )
  # Ensure output directory exists and remove existing file to avoid GDI+ generic errors
  $outDir = Split-Path -Parent $OutPath
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
  if (Test-Path $OutPath) {
    Invoke-WithRetry { Remove-Item -Force $OutPath }
  }

  $bmpIn = [System.Drawing.Bitmap]::FromFile($Source)
  try {
    $bmpOut = New-Object System.Drawing.Bitmap $Width, $Height
    try {
      $g = [System.Drawing.Graphics]::FromImage($bmpOut)
      try {
        $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.DrawImage($bmpIn, 0, 0, $Width, $Height)
      } finally { $g.Dispose() }
      # Save to a MemoryStream first to avoid GDI+ Save issues, then write bytes
      $ms = New-Object System.IO.MemoryStream
      try {
        $bmpOut.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $bytes = $ms.ToArray()
        Invoke-WithRetry { [System.IO.File]::WriteAllBytes($OutPath, $bytes) }
      } finally { $ms.Dispose() }
    } finally { $bmpOut.Dispose() }
  } finally { $bmpIn.Dispose() }
}

# Targets and sizes
$targets = @(
  @{ File = 'apple-touch-icon.png'; W=180; H=180 },
  @{ File = 'favicon-16x16.png';  W=16;  H=16  },
  @{ File = 'favicon-32x32.png';  W=32;  H=32  },
  @{ File = 'favicon-48x48.png';  W=48;  H=48  },
  @{ File = 'icon-72x72.png';     W=72;  H=72  },
  @{ File = 'icon-96x96.png';     W=96;  H=96  },
  @{ File = 'icon-128x128.png';   W=128; H=128 },
  @{ File = 'icon-144x144.png';   W=144; H=144 },
  @{ File = 'icon-192x192.png';   W=192; H=192 },
  @{ File = 'icon-256x256.png';   W=256; H=256 },
  @{ File = 'icon-512x512.png';   W=512; H=512 }
)

foreach ($t in $targets) {
  $out = Join-Path $OutDir $t.File
  Resize-Png -Width $t.W -Height $t.H -OutPath $out
}

if (-not $SkipDark) {
  # Replace icon_dark.png preserving its current dimensions if available
  $iconDark = Join-Path $OutDir 'icon_dark.png'
  $tempDark = Join-Path $OutDir ("icon_dark.tmp.{0}.png" -f ([Guid]::NewGuid().ToString()))
  $renamed = $false

  # Try to rename first to avoid locks while we write a fresh file
  if (Test-Path $iconDark) {
    try {
      Invoke-WithRetry { Rename-Item -Path $iconDark -NewName (Split-Path -Leaf $tempDark) -Force }
      $renamed = $true
    } catch {
      # Could not rename (likely locked). We'll try to read its dimensions directly and overwrite.
      $renamed = $false
    }
  }

  try {
    $w = 773; $h = 773
    if ($renamed -and (Test-Path $tempDark)) {
      $meta = [System.Drawing.Bitmap]::FromFile($tempDark)
      try { $w = $meta.Width; $h = $meta.Height } finally { $meta.Dispose() }
    } elseif (Test-Path $iconDark) {
      try {
        $meta2 = [System.Drawing.Bitmap]::FromFile($iconDark)
        try { $w = $meta2.Width; $h = $meta2.Height } finally { $meta2.Dispose() }
      } catch { }
    }

    Resize-Png -Width $w -Height $h -OutPath $iconDark

    # Cleanup temp if we managed to rename
    if ($renamed -and (Test-Path $tempDark)) {
      try { Remove-Item -Force $tempDark } catch { }
    }
  } catch {
    Write-Warning "Could not update icon_dark.png (file may be in use). Close any previewers or apps using it and re-run, or pass -SkipDark to skip."
  }
}

# Recreate favicon.ico (single 48x48 icon)
$fav48 = Join-Path $OutDir 'favicon-48x48.png'
if (-not (Test-Path $fav48)) { Resize-Png -Width 48 -Height 48 -OutPath $fav48 }
$bmpIco = [System.Drawing.Bitmap]::FromFile($fav48)
try {
  $hicon = $bmpIco.GetHicon()
  $icon = [System.Drawing.Icon]::FromHandle($hicon)
  try {
    $icoPath = Join-Path $OutDir 'favicon.ico'
    if (Test-Path $icoPath) { Remove-Item -Force $icoPath }
    $fs = [System.IO.File]::Open($icoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try { $icon.Save($fs) } finally { $fs.Dispose() }
  } finally { $icon.Dispose() }
} finally { $bmpIco.Dispose() }

Write-Host 'Icons refreshed from icon_original.PNG'
