<#
.SYNOPSIS
  Law Studyes v2.6.7 - Generates Matching Burgundy-and-Gold Splash Screen for Android
  (All Portrait & Landscape Densities), Wires Capacitor SplashScreen Config,
  Builds Clean Signed Release APK v2.6.7 (versionCode 267), and Pushes OTA to GitHub & Vercel!
.USAGE
  Run in C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Upgrade-LawStudyes-v2.6.7-SplashScreen-APK.ps1
#>

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.7"
$verCode = 267

Write-Host "`n=== 1. Generating Burgundy-and-Gold 'Law Studyes' Splash Screens (Portrait & Landscape) ===" -ForegroundColor Cyan

function Save-LawStudyesSplashPng {
  param(
    [int]$Width,
    [int]$Height,
    [string]$OutPath
  )

  $dir = Split-Path $OutPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  # Deep Burgundy vertical gradient (#8A2231 -> #56111B)
  $bgRect = New-Object System.Drawing.RectangleF(0, 0, $Width, $Height)
  $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.PointF(0, 0)),
    (New-Object System.Drawing.PointF($Width, $Height)),
    [System.Drawing.Color]::FromArgb(255, 138, 34, 49),
    [System.Drawing.Color]::FromArgb(255, 86, 17, 27)
  )
  $g.FillRectangle($bgBrush, $bgRect)
  $bgBrush.Dispose()

  # Scale emblem cleanly to the shorter dimension
  $minSide = [float][Math]::Min($Width, $Height)
  $s = ($minSide * 0.56) / 1024.0
  $originX = ($Width - 1024.0 * $s) / 2.0
  $originY = ($Height - 1024.0 * $s) / 2.0

  $g.TranslateTransform($originX, $originY)

  $goldBright = [System.Drawing.Color]::FromArgb(255, 250, 214, 118)
  $goldMid    = [System.Drawing.Color]::FromArgb(255, 229, 169, 60)
  $ivory      = [System.Drawing.Color]::FromArgb(255, 250, 247, 242)

  # Subtle outer gold crest ring
  $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(145, 245, 198, 92), [float](10 * $s))
  $pad = 54 * $s
  $g.DrawEllipse($ringPen, $pad, $pad, (1024 * $s - 2 * $pad), (1024 * $s - 2 * $pad))
  $ringPen.Dispose()

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
  $g.FillEllipse($goldBrush, ($cx - 24 * $s), (168 * $s), (48 * $s), (48 * $s))
  $g.DrawLine($goldPen, $cx, (212 * $s), $cx, (560 * $s))

  $beamY = 278 * $s
  $leftX = 270 * $s
  $rightX = 754 * $s
  $g.DrawLine($goldPen, $leftX, $beamY, $rightX, $beamY)
  $g.FillEllipse($goldBrush, ($leftX - 18 * $s), ($beamY - 18 * $s), (36 * $s), (36 * $s))
  $g.FillEllipse($goldBrush, ($rightX - 18 * $s), ($beamY - 18 * $s), (36 * $s), (36 * $s))

  $panY = 448 * $s
  $panW = 176 * $s
  $g.DrawLine($thinGoldPen, $leftX, $beamY, ($leftX - 78 * $s), $panY)
  $g.DrawLine($thinGoldPen, $leftX, $beamY, ($leftX + 78 * $s), $panY)
  $g.FillPie($goldBrush, ($leftX - $panW / 2), ($panY - 68 * $s), $panW, (136 * $s), 0, 180)

  $g.DrawLine($thinGoldPen, $rightX, $beamY, ($rightX - 78 * $s), $panY)
  $g.DrawLine($thinGoldPen, $rightX, $beamY, ($rightX + 78 * $s), $panY)
  $g.FillPie($goldBrush, ($rightX - $panW / 2), ($panY - 68 * $s), $panW, (136 * $s), 0, 180)

  # --- OPEN LAW BOOK ---
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

  $spinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 123, 30, 43), [float](10 * $s))
  $g.DrawLine($spinePen, $cx, (570 * $s), $cx, (695 * $s))
  $g.DrawLine($thinGoldPen, (240 * $s), (682 * $s), $cx, (718 * $s))
  $g.DrawLine($thinGoldPen, (784 * $s), (682 * $s), $cx, (718 * $s))

  # --- TITLE & TAGLINE ---
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

  $titleFont = New-Object System.Drawing.Font("Georgia", [float](88 * $s), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $subFont   = New-Object System.Drawing.Font("Segoe UI", [float](36 * $s), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

  $titleRect = New-Object System.Drawing.RectangleF(0, (748 * $s), (1024 * $s), (98 * $s))
  $g.DrawString("LAW STUDYES", $titleFont, $ivoryBrush, $titleRect, $sf)

  $subRect = New-Object System.Drawing.RectangleF(0, (844 * $s), (1024 * $s), (58 * $s))
  $g.DrawString("3-YEAR LL.B.  |  OFFLINE NOTES & DIAGRAMS", $subFont, $goldBrush, $subRect, $sf)

  $titleFont.Dispose(); $subFont.Dispose(); $sf.Dispose()
  $bookPathL.Dispose(); $bookPathR.Dispose(); $spinePen.Dispose()
  $goldBrush.Dispose(); $goldPen.Dispose(); $thinGoldPen.Dispose(); $ivoryBrush.Dispose()
  $g.Dispose()

  $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

$resDir = Join-Path $root "android\app\src\main\res"
$splashTargets = @(
  @{ Folder = "drawable";               W = 1080; H = 1920 },
  @{ Folder = "drawable-port-mdpi";     W = 320;  H = 480  },
  @{ Folder = "drawable-port-hdpi";     W = 480;  H = 800  },
  @{ Folder = "drawable-port-xhdpi";    W = 720;  H = 1280 },
  @{ Folder = "drawable-port-xxhdpi";   W = 960;  H = 1600 },
  @{ Folder = "drawable-port-xxxhdpi";  W = 1280; H = 1920 },
  @{ Folder = "drawable-land-mdpi";     W = 480;  H = 320  },
  @{ Folder = "drawable-land-hdpi";     W = 800;  H = 480  },
  @{ Folder = "drawable-land-xhdpi";    W = 1280; H = 720  },
  @{ Folder = "drawable-land-xxhdpi";   W = 1600; H = 960  },
  @{ Folder = "drawable-land-xxxhdpi";  W = 1920; H = 1280 }
)

foreach ($t in $splashTargets) {
  $outP = Join-Path (Join-Path $resDir $t.Folder) "splash.png"
  Save-LawStudyesSplashPng -Width $t.W -Height $t.H -OutPath $outP
}
Write-Host "[OK] Generated all 11 Android portrait & landscape burgundy-and-gold splash screens!" -ForegroundColor Green

Write-Host "`n=== 2. Configuring SplashScreen in capacitor.config.json & Bumping Version to v$ver ===" -ForegroundColor Cyan
python -c "import json,pathlib; p=pathlib.Path('capacitor.config.json'); d=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}; pl=d.setdefault('plugins',{}); pl['SplashScreen']={'launchShowDuration':1600,'launchAutoHide':True,'backgroundColor':'#7B1E2B','androidSplashResourceName':'splash','androidScaleType':'CENTER_CROP','showSpinner':False,'splashFullScreen':True,'splashImmersive':True}; p.write_text(json.dumps(d,indent=2),encoding='utf-8'); print('[OK] SplashScreen config written to capacitor.config.json')"
if ($LASTEXITCODE -ne 0) { throw "Failed updating capacitor.config.json!" }

$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$ver`";"
[System.IO.File]::WriteAllText($idx, $h, $u)

Write-Host "`n=== 3. Building Signed Release APK v$ver (versionCode $verCode) with Matching Splash Screen ===" -ForegroundColor Cyan
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
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-Splash-NewIcon-OTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 4. Pushing Updated APK & Full OTA Bundle to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
