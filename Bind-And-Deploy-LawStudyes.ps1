param(
  [string]$Version = "3.1.1",
  [int]$VersionCode = 311,
  [switch]$OtaOnly,
  [switch]$SkipWindowsExe
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$wwwDir = Join-Path $root "www"
$modDir = Join-Path $wwwDir "js\modules"
$jsDir = Join-Path $wwwDir "js"
New-Item -ItemType Directory -Path $jsDir -Force | Out-Null

Write-Host "`n=== 1. Zero-Error Pre-Flight Audit of www/nyayasaral_db.json ===" -ForegroundColor Cyan
$pyAudit = @'
import json
import sys
from pathlib import Path

db_path = Path(sys.argv[1])
if not db_path.exists():
    sys.exit("ERROR: www/nyayasaral_db.json not found.")

data = json.loads(db_path.read_text(encoding="utf-8"))
notes = data.get("notes")
if not isinstance(notes, dict) or len(notes) == 0:
    sys.exit("ERROR: Database 'notes' is empty or invalid.")

def has_content(obj):
    if not isinstance(obj, dict) or not obj:
        return False
    for f in ("inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest"):
        v = obj.get(f)
        if isinstance(v, str) and v.strip():
            return True
        if isinstance(v, list) and len(v) > 0:
            return True
    return False

total = len(notes)
en_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_content(r.get("en")))
te_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_content(r.get("te")))
hi_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_content(r.get("hi")))
vis_ok = sum(
    len(r.get("en", {}).get("visuals", []))
    for r in notes.values()
    if isinstance(r, dict) and isinstance(r.get("en"), dict) and isinstance(r.get("en", {}).get("visuals"), list)
)

sz_mb = db_path.stat().st_size / 1048576
print(f"[AUDIT PASS] DB valid JSON ({sz_mb:.2f} MB) | Total={total} | EN={en_ok} | TE={te_ok} | HI={hi_ok} | Diagrams/Tables={vis_ok}")
if en_ok == 0:
    sys.exit("ERROR: No English notes found in DB.")
'@

$pyAuditPath = Join-Path $env:TEMP "ls_part4_db_audit.py"
[System.IO.File]::WriteAllText($pyAuditPath, $pyAudit, $u)
python -u $pyAuditPath (Join-Path $wwwDir "nyayasaral_db.json")
if ($LASTEXITCODE -ne 0) { throw "Database pre-flight audit failed! Aborting deploy to protect active users." }

Write-Host "`n=== 2. Verifying & Binding All Modules into 1 Fast File (www/js/ls-app-bundle.js) ===" -ForegroundColor Cyan
$oldMono = Join-Path $modDir "ls-audio.js"
if (Test-Path $oldMono) {
  Remove-Item $oldMono -Force
  Write-Host "  [CLEAN] Removed obsolete ls-audio.js" -ForegroundColor Yellow
}

$reqMods = @("ls-trilingual.js", "ls-diagrams.js", "ls-audio-engine.js", "ls-audio-mini.js", "ls-audio-window.js")
foreach ($rm in $reqMods) {
  if (-not (Test-Path (Join-Path $modDir $rm))) {
    throw "Missing required module: www/js/modules/$rm"
  }
}

$priority = @("ls-store.js", "ls-trilingual.js", "ls-audio-engine.js", "ls-audio-mini.js", "ls-audio-window.js", "ls-diagrams.js")
$allMods = Get-ChildItem $modDir -Filter "*.js" -File | Sort-Object Name
$ordered = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($pName in $priority) {
  $match = $allMods | Where-Object { $_.Name -eq $pName } | Select-Object -First 1
  if ($match) { $ordered.Add($match) }
}
foreach ($mf in $allMods) {
  if ($priority -notcontains $mf.Name) { $ordered.Add($mf) }
}

$parts = New-Object System.Collections.Generic.List[string]
$parts.Add("/* Law Studyes v$Version - Unified Crash-Safe Module Bundle (Built $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) */")
foreach ($mf in $ordered) {
  $chk = node --check $mf.FullName 2>&1
  if ($LASTEXITCODE -ne 0) { throw "JS syntax error in $($mf.Name): $chk" }
  $src = [System.IO.File]::ReadAllText($mf.FullName, $u)
  $parts.Add("`r`n/* === MODULE: $($mf.Name) === */`r`ntry {`r`n$src`r`n} catch (__lsModErr) { console.error('[LS Module Error: $($mf.Name)]', __lsModErr); }")
  Write-Host "  [BOUND] $($mf.Name) ($([Math]::Round($mf.Length / 1KB, 1)) KB)" -ForegroundColor Green
}

$bundlePath = Join-Path $jsDir "ls-app-bundle.js"
[System.IO.File]::WriteAllText($bundlePath, ($parts -join "`r`n"), $u)
$bChk = node --check $bundlePath 2>&1
if ($LASTEXITCODE -ne 0) { throw "Bound bundle syntax error: $bChk" }
Write-Host "[PASS] Bound $($ordered.Count) modules -> www/js/ls-app-bundle.js ($([Math]::Round((Get-Item $bundlePath).Length / 1KB, 1)) KB, 0 errors)" -ForegroundColor Green

Write-Host "`n=== 3. Wiring www/index.html to Single Bundle & Verifying 0 Inline JS Errors ===" -ForegroundColor Cyan
$idxPath = Join-Path $wwwDir "index.html"
$h = [System.IO.File]::ReadAllText($idxPath, $u)

$h = [regex]::Replace($h, '<script defer src="\./js/modules/ls-[^"]+\.js[^"]*"></script>\r?\n?', '')
$h = [regex]::Replace($h, '<script defer src="\./js/ls-app-bundle\.js[^"]*"></script>\r?\n?', '')

$bundleTag = "<script defer src=`"./js/ls-app-bundle.js?v=$Version`"></script>"
if ($h.Contains("<!-- LS_MODULAR_V3_END -->")) {
  $h = $h.Replace("<!-- LS_MODULAR_V3_END -->", ($bundleTag + "`r`n<!-- LS_MODULAR_V3_END -->"))
} else {
  $h = $h.Replace("</body>", ($bundleTag + "`r`n</body>"))
}

$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$Version"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$Version`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$Version`";"
$h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', "var CURRENT_APP_VER = `"$Version`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$Version`";"
$h = $h -replace '\?v=3\.\d+\.\d+"', "?v=$Version`""
$h = $h -replace 'var SHARE_LINK = "[^"]+";', "var SHARE_LINK = `"https://law-studyes.vercel.app/download.html?v=$Version`";"
$h = $h -replace 'var msg = "Download Law Studyes[^"]*";', "var msg = `"Download Law Studyes v$Version (Free 3-Year LL.B. EN/TE/HI Notes, Source Diagrams & Audio App): `" + SHARE_LINK;"
$h = $h -replace 'href="https://github\.com/khodayanvesh-jsf/law-studyes/releases/latest/download/LawStudyes-Offline\.apk"', "href=`"https://law-studyes.vercel.app/LawStudyes-Offline.apk?v=$Version`""

[System.IO.File]::WriteAllText($idxPath, $h, $u)

$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++
  $tmp = Join-Path $env:TEMP "ls_p4_chk_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) {
    $fails++
    Write-Host "  [FAIL] Inline Script #${i}: $err" -ForegroundColor Red
  }
}
if ($fails -gt 0) { throw "$fails inline JS syntax error(s) found in www/index.html! Aborting deploy." }
Write-Host "[PASS] www/index.html wired to single bundle & verified ($i inline scripts, 0 errors)" -ForegroundColor Green

$manPath = Join-Path $wwwDir "manifest.json"
if (Test-Path $manPath) {
  python -c "import json,pathlib; p=pathlib.Path(r'$manPath'); d=json.loads(p.read_text(encoding='utf-8')); d['version']='$Version'; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')"
}

$apkMB = ""
if (-not $OtaOnly) {
  Write-Host "`n=== 4. Building Signed Android APK v$Version (versionCode $VersionCode) ===" -ForegroundColor Cyan
  $bgPath = Join-Path $root "android\app\build.gradle"
  $bgTxt = [System.IO.File]::ReadAllText($bgPath, $u)
  $bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $VersionCode"
  $bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$Version`""
  [System.IO.File]::WriteAllText($bgPath, $bgTxt, $u)

  Remove-Item (Join-Path $wwwDir "LawStudyes-Offline.apk"), (Join-Path $wwwDir "ota-bundle.zip") -ErrorAction SilentlyContinue
  npx cap sync android
  if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

  Push-Location (Join-Path $root "android")
  try {
    .\gradlew.bat assembleRelease
    if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
  } finally { Pop-Location }

  $builtApk = Join-Path $root "android\app\build\outputs\apk\release\app-release.apk"
  $deskApk = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$Version.apk"
  Copy-Item $builtApk $deskApk -Force
  Copy-Item $builtApk (Join-Path $wwwDir "LawStudyes-Offline.apk") -Force
  $apkMB = [string][Math]::Round((Get-Item $deskApk).Length / 1MB, 2) + " MB"
  Write-Host "[SUCCESS] Android APK -> Desktop\LawStudyes-v$Version.apk & www/LawStudyes-Offline.apk ($apkMB)" -ForegroundColor Green

  Write-Host "`n=== 5. Syncing www/download.html (WhatsApp Share Landing Page -> v$Version) ===" -ForegroundColor Cyan
  $todayDisp = (Get-Date).ToString("dd MMM yyyy")
  $dlHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Download Law Studyes v$Version (Android APK)</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}
    body{min-height:100vh;background:#FAF7F2;color:#1F1B18;display:flex;align-items:center;justify-content:center;padding:24px}
    .card{background:#fff;border:1px solid #E8E0D5;border-radius:22px;max-width:400px;width:100%;padding:34px 26px;text-align:center;box-shadow:0 14px 34px rgba(31,27,24,.08)}
    .logo{width:64px;height:64px;border-radius:50%;background:#7B1E2B;color:#FAF7F2;display:inline-flex;align-items:center;justify-content:center;font-size:28px;margin-bottom:14px}
    h1{font-family:Georgia,serif;color:#7B1E2B;font-size:26px;margin-bottom:6px}
    .ver{display:inline-block;padding:4px 12px;border-radius:999px;background:#FBF1F2;border:1px solid #E8D5D8;color:#7B1E2B;font-size:12px;font-weight:800;margin-bottom:14px}
    p{color:#5F554E;font-size:13px;line-height:1.5;margin-bottom:22px}
    .btn{display:block;width:100%;padding:15px 20px;background:#7B1E2B;color:#fff;text-decoration:none;border-radius:14px;font-weight:700;font-size:15px;box-shadow:0 6px 16px rgba(123,30,43,.25)}
    .btn:active{background:#5E1520}
    .sub{margin-top:14px;font-size:11.5px;color:#8C6D46}
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">&#9878;</div>
    <h1>Law Studyes</h1>
    <div class="ver">Latest Release: v$Version ($todayDisp &middot; $apkMB)</div>
    <p>3-Year LL.B. Full English, Telugu &amp; Hindi Notes, Source Flowcharts &amp; Diagrams, and Indian Voice Audio App with Auto-OTA.</p>
    <a class="btn" href="./LawStudyes-Offline.apk?v=$Version" download="LawStudyes-v$Version.apk">Download Law Studyes v$Version (.APK)</a>
    <div class="sub">Auto-updates automatically over the air after install.</div>
  </div>
</body>
</html>
"@
  [System.IO.File]::WriteAllText((Join-Path $wwwDir "download.html"), $dlHtml, $u)
  Write-Host "[OK] www/download.html updated to v$Version" -ForegroundColor Green

  $deskDir = Join-Path $root "desktop-console"
  if ((Test-Path $deskDir) -and (-not $SkipWindowsExe)) {
    Write-Host "`n=== 6. Building Windows Founder Console v$Version (.exe) ===" -ForegroundColor Cyan
    $deskPkg = Join-Path $deskDir "package.json"
    if (Test-Path $deskPkg) {
      python -c "import json,pathlib; p=pathlib.Path(r'$deskPkg'); d=json.loads(p.read_text(encoding='utf-8')); d['version']='$Version'; d.setdefault('build',{}).setdefault('win',{})['signAndEditExecutable']=False; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')"
    }
    $deskHtml = Join-Path $deskDir "index.html"
    if (Test-Path $deskHtml) {
      $dh = [System.IO.File]::ReadAllText($deskHtml, $u)
      $dh = $dh -replace 'v\d+\.\d+\.\d+\s*&middot;\s*Android \+ Windows', "v$Version &middot; Android + Windows"
      [System.IO.File]::WriteAllText($deskHtml, $dh, $u)
    }
    $deskMain = Join-Path $deskDir "main.js"
    if (Test-Path $deskMain) {
      $dm = [System.IO.File]::ReadAllText($deskMain, $u)
      $dm = $dm -replace 'Founder & Admin Console v[\d\.]+', "Founder & Admin Console v$Version"
      [System.IO.File]::WriteAllText($deskMain, $dm, $u)
    }
    Push-Location $deskDir
    try {
      $env:CSC_IDENTITY_AUTO_DISCOVERY = "false"
      npm run build
      if ($LASTEXITCODE -ne 0) { throw "Windows Founder Console build failed!" }
    } finally { Pop-Location }
    $exeSrc = Get-ChildItem (Join-Path $deskDir "dist") -Filter "*.exe" -File | Select-Object -First 1
    if ($exeSrc) {
      $destExe = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-Founder-Console-Windows.exe"
      Copy-Item $exeSrc.FullName $destExe -Force
      Write-Host "[SUCCESS] Windows Console -> $destExe" -ForegroundColor Green
    }
  }
}

Write-Host "`n=== 7. Staging Automation Scripts & Pushing Verified Live OTA v$Version ===" -ForegroundColor Cyan
foreach ($extra in @("scripts/generate_te_hi_db.py", "Sync-And-Translate-BeforeDeploy.ps1", ".gitignore")) {
  $ep = Join-Path $root $extra
  if (Test-Path $ep) { git add $extra }
}
if ((Test-Path (Join-Path $wwwDir "LawStudyes-Offline.apk")) -and (-not $OtaOnly)) {
  git add -f "www/LawStudyes-Offline.apk"
}

& (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "v$Version - Full EN/TE/HI Notes DB, Auto-Translate Pre-Deploy, Faithful Source Diagrams & Zero-Crash Single Bundle"
