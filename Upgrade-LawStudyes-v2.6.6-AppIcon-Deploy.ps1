<#
.SYNOPSIS
  Law Studyes v2.6.6 - Generates Custom "Law Studyes" App Icon (Scales of Justice + Open Law Book
  in Burgundy & Gold), Applies to All Android Mipmap Densities + Adaptive Icons + Web/PWA Icons,
  Builds Clean Signed Release APK v2.6.6 (versionCode 266), and Deploys to GitHub & Vercel via OTA!
.USAGE
  Run in C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Upgrade-LawStudyes-v2.6.6-AppIcon-Deploy.ps1
#>

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.6"
$verCode = 266

Write-Host "`n=== 1. Rendering Custom 'Law Studyes' App Icon (1024x1024 Master + Adaptive Foreground) ===" -ForegroundColor Cyan

function New-LawStudyesIconBitmap {
  param(
    [int]$Size = 1024,
    [bool]$TransparentBg = $false,
    [bool]$RoundClip = $false
  )

  $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $s = [float]$Size / 1024.0

  if ($RoundClip) {
    $clipPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $clipPath.AddEllipse(0, 0, $Size, $Size)
    $g.SetClip($clipPath)
  }

  if (-not $TransparentBg) {
    # Deep Burgundy radial-style linear gradient (#8C2332 -> #5A121C)
    $bgRect = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      (New-Object System.Drawing.PointF(0, 0)),
      (New-Object System.Drawing.PointF($Size, $Size)),
      [System.Drawing.Color]::FromArgb(255, 138, 34, 49),
      [System.Drawing.Color]::FromArgb(255, 86, 17, 27)
    )
    $g.FillRectangle($bgBrush, $bgRect)
    $bgBrush.Dispose()

    # Subtle gold inner crest ring
    $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(145, 245, 198, 92), [float](10 * $s))
    $pad = 54 * $s
    $g.DrawEllipse($ringPen, $pad, $pad, ($Size - 2 * $pad), ($Size - 2 * $pad))
    $ringPen.Dispose()
  } else {
    $g.Clear([System.Drawing.Color]::Transparent)
  }

  # Scale inner emblem slightly smaller for adaptive foreground safe zone (66% safe area)
  if ($TransparentBg) {
    $g.TranslateTransform($Size * 0.5, $Size * 0.5)
    $g.ScaleTransform(0.68, 0.68)
    $g.TranslateTransform(-$Size * 0.5, -$Size * 0.5)
  }

  $goldBright = [System.Drawing.Color]::FromArgb(255, 250, 214, 118)
  $goldMid    = [System.Drawing.Color]::FromArgb(255, 229, 169, 60)
  $ivory      = [System.Drawing.Color]::FromArgb(255, 250, 247, 242)

  $goldBrush = New-Object System.Drawing.SolidBrush($goldBright)
  $goldPen   = New-Object System.Drawing.Pen($goldBright, [float](22 * $s))
  $goldPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $goldPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

  $thinGoldPen = New-Object System.Drawing.Pen($goldMid, [float](11 * $s))
  $thinGoldPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $thinGoldPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round

  $ivoryBrush = New-Object System.Drawing.SolidBrush($ivory)

  # --- SCALES OF JUSTICE ---
  $cx = 512 * $s
  # Top finial circle
  $g.FillEllipse($goldBrush, ($cx - 24 * $s), (168 * $s), (48 * $s), (48 * $s))
  # Center pillar
  $g.DrawLine($goldPen, $cx, (212 * $s), $cx, (560 * $s))
  # Crossbar beam
  $beamY = 278 * $s
  $leftX = 270 * $s
  $rightX = 754 * $s
  $g.DrawLine($goldPen, $leftX, $beamY, $rightX, $beamY)
  # End knobs on beam
  $g.FillEllipse($goldBrush, ($leftX - 18 * $s), ($beamY - 18 * $s), (36 * $s), (36 * $s))
  $g.FillEllipse($goldBrush, ($rightX - 18 * $s), ($beamY - 18 * $s), (36 * $s), (36 * $s))

  # Left scale chains + pan
  $panY = 448 * $s
  $panW = 176 * $s
  $g.DrawLine($thinGoldPen, $leftX, $beamY, ($leftX - 78 * $s), $panY)
  $g.DrawLine($thinGoldPen, $leftX, $beamY, ($leftX + 78 * $s), $panY)
  $g.FillPie($goldBrush, ($leftX - $panW / 2), ($panY - 68 * $s), $panW, (136 * $s), 0, 180)

  # Right scale chains + pan
  $g.DrawLine($thinGoldPen, $rightX, $beamY, ($rightX - 78 * $s), $panY)
  $g.DrawLine($thinGoldPen, $rightX, $beamY, ($rightX + 78 * $s), $panY)
  $g.FillPie($goldBrush, ($rightX - $panW / 2), ($panY - 68 * $s), $panW, (136 * $s), 0, 180)

  # --- OPEN LAW BOOK (at base of pillar) ---
  $bookPathL = New-Object System.Drawing.Drawing2D.GraphicsPath
  $bookPathL.AddPolygon(@(
    (New-Object System.Drawing.PointF($cx, (575 * $s))),
    (New-Object System.Drawing.PointF((272 * $s), (538 * $s))),
    (New-Object System.Drawing.PointF((242 * $s), (656 * $s))),
    (New-Object System.Drawing.PointF($cx, (692 * $s)))
  ))
  $g.FillPath($ivoryBrush, $bookPathL)

  $bookPathR = New-Object System.Drawing.Drawing2D.GraphicsPath
  $bookPathR.AddPolygon(@(
    (New-Object System.Drawing.PointF($cx, (575 * $s))),
    (New-Object System.Drawing.PointF((752 * $s), (538 * $s))),
    (New-Object System.Drawing.PointF((782 * $s), (656 * $s))),
    (New-Object System.Drawing.PointF($cx, (692 * $s)))
  ))
  $g.FillPath($ivoryBrush, $bookPathR)

  # Book center spine + gold base underline
  $spinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 123, 30, 43), [float](10 * $s))
  $g.DrawLine($spinePen, $cx, (570 * $s), $cx, (695 * $s))
  $g.DrawLine($thinGoldPen, (240 * $s), (682 * $s), $cx, (718 * $s))
  $g.DrawLine($thinGoldPen, (784 * $s), (682 * $s), $cx, (718 * $s))

  # --- TITLE: "LAW STUDYES" ---
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  $titleFont = New-Object System.Drawing.Font("Georgia", [float](82 * $s), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $subFont   = New-Object System.Drawing.Font("Segoe UI", [float](36 * $s), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

  $titleRect = New-Object System.Drawing.RectangleF(0, (746 * $s), $Size, (96 * $s))
  $g.DrawString("LAW STUDYES", $titleFont, $ivoryBrush, $titleRect, $sf)

  $subRect = New-Object System.Drawing.RectangleF(0, (838 * $s), $Size, (56 * $s))
  $g.DrawString("3-YEAR LL.B.", $subFont, $goldBrush, $subRect, $sf)

  # Cleanup GDI objects
  $titleFont.Dispose(); $subFont.Dispose(); $sf.Dispose()
  $bookPathL.Dispose(); $bookPathR.Dispose(); $spinePen.Dispose()
  $goldBrush.Dispose(); $goldPen.Dispose(); $thinGoldPen.Dispose(); $ivoryBrush.Dispose()
  $g.Dispose()
  return $bmp
}

function Save-ResizedPng {
  param([System.Drawing.Bitmap]$Source, [int]$TargetSize, [string]$OutPath)
  $dir = Split-Path $OutPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $dst = New-Object System.Drawing.Bitmap($TargetSize, $TargetSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($dst)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($Source, 0, 0, $TargetSize, $TargetSize)
  $g.Dispose()
  $dst.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $dst.Dispose()
}

$masterFull  = New-LawStudyesIconBitmap -Size 1024 -TransparentBg $false -RoundClip $false
$masterRound = New-LawStudyesIconBitmap -Size 1024 -TransparentBg $false -RoundClip $true
$masterFg    = New-LawStudyesIconBitmap -Size 1024 -TransparentBg $true  -RoundClip $false

# 1a. Save Web / PWA Icons in www/
Save-ResizedPng -Source $masterFull -TargetSize 512 -OutPath (Join-Path $root "www\icon-512.png")
Save-ResizedPng -Source $masterFull -TargetSize 192 -OutPath (Join-Path $root "www\icon-192.png")
Save-ResizedPng -Source $masterRound -TargetSize 64 -OutPath (Join-Path $root "www\favicon.png")
Write-Host "[OK] Saved www/icon-512.png, www/icon-192.png, www/favicon.png" -ForegroundColor Green

# 1b. Save All Android Launcher Mipmap Densities
$resDir = Join-Path $root "android\app\src\main\res"
$densities = @(
  @{ Name = "mipmap-mdpi";    Icon = 48;  Fg = 108 },
  @{ Name = "mipmap-hdpi";    Icon = 72;  Fg = 162 },
  @{ Name = "mipmap-xhdpi";   Icon = 96;  Fg = 216 },
  @{ Name = "mipmap-xxhdpi";  Icon = 144; Fg = 324 },
  @{ Name = "mipmap-xxxhdpi"; Icon = 192; Fg = 432 }
)

foreach ($d in $densities) {
  $mDir = Join-Path $resDir $d.Name
  Save-ResizedPng -Source $masterFull  -TargetSize $d.Icon -OutPath (Join-Path $mDir "ic_launcher.png")
  Save-ResizedPng -Source $masterRound -TargetSize $d.Icon -OutPath (Join-Path $mDir "ic_launcher_round.png")
  Save-ResizedPng -Source $masterFg    -TargetSize $d.Fg   -OutPath (Join-Path $mDir "ic_launcher_foreground.png")
}

$masterFull.Dispose(); $masterRound.Dispose(); $masterFg.Dispose()

# 1c. Set Adaptive Icon Background Color to Brand Burgundy (#7B1E2B)
$bgXmlPath = Join-Path $resDir "values\ic_launcher_background.xml"
$bgXml = @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#7B1E2B</color>
</resources>
"@
[System.IO.File]::WriteAllText($bgXmlPath, $bgXml, $u)
Write-Host "[OK] Updated all 5 Android mipmap densities + adaptive background (#7B1E2B)" -ForegroundColor Green

Write-Host "`n=== 2. Updating www/manifest.json & www/index.html Icons + Version v$ver ===" -ForegroundColor Cyan

# Update manifest.json cleanly via Python
python -c "import json,pathlib; p=pathlib.Path('www/manifest.json'); d=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}; d['name']='Law Studyes'; d['short_name']='Law Studyes'; d['theme_color']='#7B1E2B'; d['background_color']='#FAF7F2'; d['icons']=[{'src':'./icon-192.png','sizes':'192x192','type':'image/png','purpose':'any maskable'},{'src':'./icon-512.png','sizes':'512x512','type':'image/png','purpose':'any maskable'}]; p.write_text(json.dumps(d,indent=2),encoding='utf-8'); print('[OK] www/manifest.json updated')"

$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

# Ensure favicon and apple-touch-icon point to the new Law Studyes icon
$h = [regex]::Replace($h, '(?s)<!-- LS_ICON_LINKS_START -->.*?<!-- LS_ICON_LINKS_END -->', '')
$iconLinks = @"
<!-- LS_ICON_LINKS_START -->
<link rel="icon" type="image/png" href="./favicon.png?v=$ver" />
<link rel="apple-touch-icon" href="./icon-192.png?v=$ver" />
<!-- LS_ICON_LINKS_END -->
"@
if ($h -match '</head>') {
  $h = $h.Replace('</head>', ($iconLinks + "`r`n</head>"))
}

# Bump version labels to 2.6.6
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$ver`";"
[System.IO.File]::WriteAllText($idx, $h, $u)

# Verify 0 JS errors
$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_266_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS error(s) found in www/index.html!" }
Write-Host "[PASS] All $i inline JS blocks verified (0 errors)!" -ForegroundColor Green

Write-Host "`n=== 3. Building Signed Release APK v$ver (versionCode $verCode) with New Law Studyes Icon ===" -ForegroundColor Cyan
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

# Remove previous APK & OTA zip BEFORE cap sync so zero recursive bloat enters the APK
Remove-Item (Join-Path $root "www\LawStudyes-Offline.apk"), (Join-Path $root "www\ota-bundle.zip") -ErrorAction SilentlyContinue

npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

Push-Location ".\android"
try {
  .\gradlew.bat assembleRelease
  if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
} finally {
  Pop-Location
}

$apk = ".\android\app\build\outputs\apk\release\app-release.apk"
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-NewIcon-OTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 4. Deploying Updated Icons, APK & Full OTA Bundle to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
