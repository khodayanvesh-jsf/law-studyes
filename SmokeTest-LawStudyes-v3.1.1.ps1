param(
  [string]$ExpectedVersion = "3.2.0",
  [string]$BaseUrl = "https://law-studyes.vercel.app",
  [switch]$SkipLiveOta
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$wwwDir = Join-Path $root "www"
$failCount = 0
$warnCount = 0

function Add-Check {
  param([string]$Area, [string]$Status, [string]$Detail)
  $color = switch ($Status) {
    "PASS" { "Green" }
    "WARN" { "Yellow" }
    default { "Red" }
  }
  Write-Host ("[{0}] {1}: {2}" -f $Status, $Area, $Detail) -ForegroundColor $color
  if ($Status -eq "FAIL") { $script:failCount++ }
  elseif ($Status -eq "WARN") { $script:warnCount++ }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Law Studyes v$ExpectedVersion - Automated Smoke Test" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# --- 1. Database Counts & Verbatim Source Diagram Parity ---
$dbPath = Join-Path $wwwDir "nyayasaral_db.json"
$auditPy = Join-Path $root "scripts\smoke_audit_db.py"
if (-not (Test-Path $dbPath)) {
  Add-Check "Database" "FAIL" "Missing www/nyayasaral_db.json"
} elseif (-not (Test-Path $auditPy)) {
  Add-Check "Database" "FAIL" "Missing scripts/smoke_audit_db.py"
} else {
  try {
    $rawJson = python -u $auditPy $dbPath 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$rawJson" }
    $stats = $rawJson | ConvertFrom-Json
    $summary = "Valid JSON ($($stats.mb) MB) | Total=$($stats.total) | EN=$($stats.en) | TE=$($stats.te) | HI=$($stats.hi) | Diagrams=$($stats.vis) | Mismatches=$($stats.visMismatch)"
    if ($stats.en -eq 0) {
      Add-Check "Database" "FAIL" $summary
    } elseif ($stats.visMismatch -gt 0) {
      Add-Check "Verbatim Diagrams" "FAIL" "$summary (Run Upgrade1 to lock TE/HI visuals verbatim to EN)"
    } elseif ($stats.te -lt $stats.en -or $stats.hi -lt $stats.en) {
      Add-Check "Database" "WARN" "$summary (Some topics missing TE or HI)"
    } else {
      Add-Check "Database & Verbatim Diagrams" "PASS" $summary
    }
  } catch {
    Add-Check "Database" "FAIL" "Parse error: $_"
  }
}

# --- 2. Unified Bundle (www/js/ls-app-bundle.js) ---
$bundlePath = Join-Path $wwwDir "js\ls-app-bundle.js"
if (-not (Test-Path $bundlePath)) {
  Add-Check "Bundle" "FAIL" "Missing www/js/ls-app-bundle.js"
} else {
  $chkOut = node --check $bundlePath 2>&1
  if ($LASTEXITCODE -ne 0) {
    Add-Check "Bundle Syntax" "FAIL" "node --check failed: $chkOut"
  } else {
    $bTxt = [System.IO.File]::ReadAllText($bundlePath, $u)
    $kb = [Math]::Round((Get-Item $bundlePath).Length / 1KB, 1)
    $reqMarkers = @(
      "ls-trilingual.js",
      "ls-diagrams.js",
      "ls-audio-engine.js",
      "ls-audio-mini.js",
      "ls-audio-window.js",
      "ls-note-converter.js",
      "ls-indian-professor.js",
      "ls-pdf-export.js"
    )
    $missing = @($reqMarkers | Where-Object { $bTxt -notmatch [regex]::Escape($_) })
    if ($missing.Count -gt 0) {
      Add-Check "Bundle Modules" "FAIL" "0 syntax errors ($kb KB), missing: $($missing -join ', ')"
    } else {
      Add-Check "Bundle" "PASS" "0 syntax errors ($kb KB) | All 8 core + v3.2.0 modules bound"
    }
  }
}

# --- 3. www/index.html Tags, Version Stamp & Inline Script Syntax ---
$idxPath = Join-Path $wwwDir "index.html"
if (-not (Test-Path $idxPath)) {
  Add-Check "index.html" "FAIL" "Missing www/index.html"
} else {
  $h = [System.IO.File]::ReadAllText($idxPath, $u)
  $hasBundleTag = ($h -match [regex]::Escape("./js/ls-app-bundle.js?v=$ExpectedVersion"))
  $strayModTags = [regex]::Matches($h, '<script[^>]+src="\./js/modules/ls-[^"]+\.js[^"]*"').Count
  $hasVerStamp = ($h -match ('var (BUILT_IN|APP_VER|CURRENT_APP_VER) = "' + [regex]::Escape($ExpectedVersion) + '"'))

  if (-not $hasBundleTag) {
    Add-Check "index.html Bundle Tag" "FAIL" "Missing ./js/ls-app-bundle.js?v=$ExpectedVersion tag"
  } elseif ($strayModTags -gt 0) {
    Add-Check "index.html Bundle Tag" "WARN" "Bundle tag found, but $strayModTags duplicate module tag(s) remain"
  } elseif (-not $hasVerStamp) {
    Add-Check "index.html Bundle Tag" "WARN" "Bundle tag OK, but version stamp != $ExpectedVersion"
  } else {
    Add-Check "index.html Tags" "PASS" "Single bundle tag v$ExpectedVersion wired, 0 duplicate module tags"
  }

  $i = 0; $badInline = 0
  [regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
    $i++
    $tmpJs = Join-Path $env:TEMP "ls_smoke320_inline_$i.js"
    [System.IO.File]::WriteAllText($tmpJs, $_.Groups[1].Value, $u)
    $err = node --check $tmpJs 2>&1
    if ($LASTEXITCODE -ne 0) {
      $badInline++
      Write-Host "    -> Inline script #${i} error: $err" -ForegroundColor Red
    }
  }
  if ($badInline -gt 0) {
    Add-Check "index.html Inline JS" "FAIL" "$badInline of $i inline script(s) failed node --check"
  } else {
    Add-Check "index.html Inline JS" "PASS" "All $i inline script(s) passed node --check (0 errors)"
  }
}

# --- 4. Studio Neural Audio Manifest Check ---
$audMan = Join-Path $wwwDir "audio\manifest.json"
if (Test-Path $audMan) {
  try {
    $am = Get-Content $audMan -Raw -Encoding UTF8 | ConvertFrom-Json
    $enC = if ($am.en) { ($am.en.PSObject.Properties | Measure-Object).Count } else { 0 }
    $teC = if ($am.te) { ($am.te.PSObject.Properties | Measure-Object).Count } else { 0 }
    $hiC = if ($am.hi) { ($am.hi.PSObject.Properties | Measure-Object).Count } else { 0 }
    Add-Check "Professor Audio Manifest" "PASS" "Valid JSON | Studio MP3s indexed: EN=$enC, TE=$teC, HI=$hiC"
  } catch {
    Add-Check "Professor Audio Manifest" "FAIL" "Invalid www/audio/manifest.json: $_"
  }
} else {
  Add-Check "Professor Audio Manifest" "WARN" "No www/audio/manifest.json (App uses neural device voices cleanly)"
}

# --- 5. Live Vercel OTA Parity & Download Page ---
$otaPy = Join-Path $root "scripts\smoke_verify_ota.py"
if (-not $SkipLiveOta) {
  try {
    $otaRaw = python -u $otaPy $BaseUrl $ExpectedVersion 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$otaRaw" }
    $ota = $otaRaw | ConvertFrom-Json
    $info = $ota.info
    $msg = "Version=$($info.liveVersion) | Size=$($info.zipMB) MB | Files=$($info.zipFiles) | mp3InZip=$($info.mp3InZip) | shaMatch=$($info.shaMatch) ($($info.actualSha)) | badSlashes=$($info.badSlashes)"
    if ($ota.ok) {
      Add-Check "Live Vercel OTA" "PASS" $msg
    } else {
      Add-Check "Live Vercel OTA" "FAIL" ($msg + " | Errors: " + ($ota.errors -join "; "))
    }
    if ($info.downloadHtmlVerMatch -eq $true) {
      Add-Check "WhatsApp Download Page" "PASS" "$BaseUrl/download.html shows v$ExpectedVersion"
    } else {
      Add-Check "WhatsApp Download Page" "WARN" "$BaseUrl/download.html does not yet show v$ExpectedVersion"
    }
  } catch {
    Add-Check "Live Vercel OTA" "FAIL" "Failed to verify live Vercel endpoint: $_"
  }
} else {
  Add-Check "Live Vercel OTA" "WARN" "Skipped via -SkipLiveOta"
}

# --- 6. Local Release Artifacts ---
$desk = [Environment]::GetFolderPath("Desktop")
$apkFile = Join-Path $desk "LawStudyes-v$ExpectedVersion.apk"
$exeFile = Join-Path $desk "LawStudyes-Founder-Console-Windows.exe"
if (Test-Path $apkFile) {
  Add-Check "Desktop APK" "PASS" ("Found LawStudyes-v$ExpectedVersion.apk (" + [Math]::Round((Get-Item $apkFile).Length / 1MB, 2) + " MB)")
} else {
  Add-Check "Desktop APK" "WARN" "LawStudyes-v$ExpectedVersion.apk not on Desktop (normal for -OtaOnly)"
}
if (Test-Path $exeFile) {
  Add-Check "Windows Console EXE" "PASS" ("Found LawStudyes-Founder-Console-Windows.exe (" + [Math]::Round((Get-Item $exeFile).Length / 1MB, 2) + " MB)")
} else {
  Add-Check "Windows Console EXE" "WARN" "LawStudyes-Founder-Console-Windows.exe not found on Desktop"
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($failCount -eq 0) {
  Write-Host "  SMOKE TEST PASSED (0 Failures, $warnCount Warning(s))" -ForegroundColor Green
  Write-Host "============================================================`n" -ForegroundColor Cyan
  exit 0
} else {
  Write-Host "  SMOKE TEST FAILED ($failCount Failure(s), $warnCount Warning(s))" -ForegroundColor Red
  Write-Host "============================================================`n" -ForegroundColor Cyan
  exit 1
}