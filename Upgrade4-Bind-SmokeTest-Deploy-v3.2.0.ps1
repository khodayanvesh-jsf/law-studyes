param(
  [string]$Version = "3.2.0",
  [int]$VersionCode = 320,
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
$scriptsDir = Join-Path $root "scripts"
New-Item -ItemType Directory -Path $jsDir, $scriptsDir -Force | Out-Null

function Invoke-GitSafe {
  param([string[]]$GitArgs)
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & git @GitArgs 2>&1 | ForEach-Object {
      $line = "$_"
      if ($line -notmatch "LF will be replaced by CRLF") { Write-Host "  $line" -ForegroundColor DarkGray }
    }
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevPref
  }
  return $code
}

Write-Host "`n=== 1. Installing v$Version SmokeTest Helpers & Upgrading SmokeTest-LawStudyes-v3.1.1.ps1 ===" -ForegroundColor Cyan

$pyAuditDb = @'
import json, sys
from pathlib import Path

p = Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8"))
notes = data.get("notes")
if not isinstance(notes, dict) or not notes:
    sys.exit("Invalid or empty notes object")

def ok(obj):
    if not isinstance(obj, dict) or not obj:
        return False
    for f in ("inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest"):
        v = obj.get(f)
        if (isinstance(v, str) and v.strip()) or (isinstance(v, list) and len(v) > 0):
            return True
    return False

total = len(notes)
en = te = hi = vis = vis_mismatch = 0
for r in notes.values():
    if not isinstance(r, dict):
        continue
    en_o, te_o, hi_o = r.get("en"), r.get("te"), r.get("hi")
    if ok(en_o): en += 1
    if ok(te_o): te += 1
    if ok(hi_o): hi += 1
    if isinstance(en_o, dict) and isinstance(en_o.get("visuals"), list):
        ev = en_o["visuals"]
        vis += len(ev)
        if isinstance(te_o, dict) and te_o.get("visuals") != ev:
            vis_mismatch += 1
        if isinstance(hi_o, dict) and hi_o.get("visuals") != ev:
            vis_mismatch += 1

mb = p.stat().st_size / 1048576
print(json.dumps({
    "total": total, "en": en, "te": te, "hi": hi,
    "vis": vis, "visMismatch": vis_mismatch, "mb": round(mb, 2)
}))
'@

$pyAuditPath = Join-Path $scriptsDir "smoke_audit_db.py"
[System.IO.File]::WriteAllText($pyAuditPath, $pyAuditDb, $u)
python -m py_compile $pyAuditPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in scripts/smoke_audit_db.py!" }

$pyVerifyOta = @'
import hashlib, io, json, sys, time, urllib.request, zipfile

base = sys.argv[1].rstrip("/")
expected_ver = sys.argv[2]

def fetch(path):
    sep = "&" if "?" in path else "?"
    url = f"{base}/{path.lstrip('/')}{sep}t={int(time.time())}"
    req = urllib.request.Request(url, headers={"User-Agent": "LawStudyes-SmokeTest/3.2", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.status, r.read()

out = {"ok": True, "errors": [], "info": {}}
try:
    meta = {}
    for mf in ("ota-manifest.json", "ota-version.json"):
        try:
            _, raw = fetch(mf)
            parsed = json.loads(raw.decode("utf-8"))
            if isinstance(parsed, dict):
                for k, v in parsed.items():
                    if k not in meta or not meta[k]:
                        meta[k] = v
        except Exception:
            pass

    ver = str(meta.get("version", ""))
    exp_sha = str(meta.get("sha256") or meta.get("checksum") or "").lower().strip()
    zip_url = str(meta.get("url") or f"{base}/ota-bundle.zip")
    out["info"]["liveVersion"] = ver or "unknown"
    if not ver.startswith(expected_ver):
        out["ok"] = False
        out["errors"].append(f"Live version '{ver}' != '{expected_ver}'")

    sep = "&" if "?" in zip_url else "?"
    req_z = urllib.request.Request(f"{zip_url}{sep}t={int(time.time())}", headers={"User-Agent": "LawStudyes-SmokeTest/3.2"})
    with urllib.request.urlopen(req_z, timeout=45) as rz:
        zbytes = rz.read()

    actual_sha = hashlib.sha256(zbytes).hexdigest().lower()
    out["info"]["zipMB"] = round(len(zbytes) / 1048576, 2)
    out["info"]["actualSha"] = actual_sha[:16]
    out["info"]["shaMatch"] = (actual_sha == exp_sha) if exp_sha else True
    if exp_sha and actual_sha != exp_sha:
        out["ok"] = False
        out["errors"].append(f"SHA mismatch: manifest={exp_sha[:16]} vs zip={actual_sha[:16]}")

    with zipfile.ZipFile(io.BytesIO(zbytes), "r") as zf:
        names = zf.namelist()
        bad_slashes = sum(1 for n in names if "\\" in n)
        mp3_count = sum(1 for n in names if n.lower().endswith(".mp3"))
        has_idx = ("index.html" in names)
        has_bun = ("js/ls-app-bundle.js" in names)
        has_db = ("nyayasaral_db.json" in names)
        out["info"].update({
            "zipFiles": len(names), "badSlashes": bad_slashes, "mp3InZip": mp3_count,
            "hasIdx": has_idx, "hasBundle": has_bun, "hasDb": has_db
        })
        if bad_slashes > 0:
            out["ok"] = False
            out["errors"].append(f"{bad_slashes} backslash path(s) in live ZIP")
        if not has_idx or not has_bun or not has_db:
            out["ok"] = False
            out["errors"].append(f"Missing core file in ZIP (index={has_idx}, bundle={has_bun}, db={has_db})")
except Exception as e:
    out["ok"] = False
    out["errors"].append(f"OTA verify error: {e}")

try:
    _, raw_d = fetch("download.html")
    out["info"]["downloadHtmlVerMatch"] = (f"v{expected_ver}" in raw_d.decode("utf-8", errors="ignore"))
except Exception:
    out["info"]["downloadHtmlVerMatch"] = False

print(json.dumps(out))
'@

$pyOtaPath = Join-Path $scriptsDir "smoke_verify_ota.py"
[System.IO.File]::WriteAllText($pyOtaPath, $pyVerifyOta, $u)
python -m py_compile $pyOtaPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in scripts/smoke_verify_ota.py!" }

$smokePs1 = @'
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
'@

$smokeTarget = Join-Path $root "SmokeTest-LawStudyes-v3.1.1.ps1"
[System.IO.File]::WriteAllText($smokeTarget, $smokePs1, $u)
$tok = $null; $errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($smokeTarget, [ref]$tok, [ref]$errs)
if ($errs -and $errs.Count -gt 0) { throw "Syntax error in upgraded SmokeTest: $($errs[0].Message)" }
Write-Host "[PASS] SmokeTest-LawStudyes-v3.1.1.ps1 upgraded for v$Version & AST-verified (Push-LawStudyes-OTA.ps1 hooks preserved)." -ForegroundColor Green

Write-Host "`n=== 2. Running Pre-Flight Verbatim Diagram & Trilingual Sync Check ===" -ForegroundColor Cyan
$syncHook = Join-Path $root "Sync-And-Translate-BeforeDeploy.ps1"
if (Test-Path $syncHook) {
  & $syncHook
}

Write-Host "`n=== 3. Verifying & Binding All Modules into 1 Crash-Safe File (www/js/ls-app-bundle.js) ===" -ForegroundColor Cyan
$reqMods = @(
  "ls-trilingual.js",
  "ls-diagrams.js",
  "ls-audio-engine.js",
  "ls-audio-mini.js",
  "ls-audio-window.js",
  "ls-note-converter.js",
  "ls-indian-professor.js",
  "ls-pdf-export.js"
)
foreach ($rm in $reqMods) {
  if (-not (Test-Path (Join-Path $modDir $rm))) {
    throw "Missing required v$Version module: www/js/modules/$rm"
  }
}

$priority = @(
  "ls-store.js",
  "ls-trilingual.js",
  "ls-audio-engine.js",
  "ls-audio-mini.js",
  "ls-audio-window.js",
  "ls-diagrams.js",
  "ls-note-converter.js",
  "ls-indian-professor.js",
  "ls-pdf-export.js"
)
$allMods = Get-ChildItem $modDir -Filter "*.js" -File | Sort-Object Name
$ordered = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($pName in $priority) {
  $m = $allMods | Where-Object { $_.Name -eq $pName } | Select-Object -First 1
  if ($m) { $ordered.Add($m) }
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
if ($LASTEXITCODE -ne 0) { throw "Unified bundle syntax error: $bChk" }
Write-Host "[PASS] Bound $($ordered.Count) modules -> www/js/ls-app-bundle.js ($([Math]::Round((Get-Item $bundlePath).Length / 1KB, 1)) KB, 0 errors)" -ForegroundColor Green

Write-Host "`n=== 4. Wiring www/index.html & www/manifest.json to v$Version ===" -ForegroundColor Cyan
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
$h = $h -replace 'var msg = "Download Law Studyes[^"]*";', "var msg = `"Download Law Studyes v$Version (Free 3-Year LL.B. EN/TE/HI Notes, Indian Professor Voice, Verbatim Diagrams & Hard-Copy PDF): `" + SHARE_LINK;"
$h = $h -replace 'href="https://github\.com/khodayanvesh-jsf/law-studyes/releases/latest/download/LawStudyes-Offline\.apk"', "href=`"https://law-studyes.vercel.app/LawStudyes-Offline.apk?v=$Version`""

[System.IO.File]::WriteAllText($idxPath, $h, $u)

$manPath = Join-Path $wwwDir "manifest.json"
if (Test-Path $manPath) {
  python -c "import json,pathlib; p=pathlib.Path(r'$manPath'); d=json.loads(p.read_text(encoding='utf-8')); d['version']='$Version'; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')"
}

Write-Host "`n=== 5. Running Local Pre-Build Smoke Test (v$Version) ===" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File $smokeTarget -ExpectedVersion $Version -SkipLiveOta
if ($LASTEXITCODE -ne 0) { throw "Local Smoke Test FAILED! Aborting build/deploy to protect active users." }

if (-not $OtaOnly) {
  Write-Host "`n=== 6. Building Lean Signed Android APK v$Version (versionCode $VersionCode) ===" -ForegroundColor Cyan
  $bgPath = Join-Path $root "android\app\build.gradle"
  $bgTxt = [System.IO.File]::ReadAllText($bgPath, $u)
  $bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $VersionCode"
  $bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$Version`""
  [System.IO.File]::WriteAllText($bgPath, $bgTxt, $u)

  Remove-Item (Join-Path $wwwDir "LawStudyes-Offline.apk"), (Join-Path $wwwDir "ota-bundle.zip") -ErrorAction SilentlyContinue

  $audioRoot = Join-Path $wwwDir "audio"
  $audioStage = Join-Path $env:TEMP ("ls_audio_stage_" + [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  $movedDirs = New-Object System.Collections.Generic.List[string]
  try {
    foreach ($langSub in @("en", "te", "hi")) {
      $srcSub = Join-Path $audioRoot $langSub
      if (Test-Path $srcSub) {
        New-Item -ItemType Directory -Path $audioStage -Force | Out-Null
        Move-Item $srcSub (Join-Path $audioStage $langSub) -Force
        $movedDirs.Add($langSub)
      }
    }
    npx cap sync android
    if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }
  } finally {
    foreach ($langSub in $movedDirs) {
      $bk = Join-Path $audioStage $langSub
      if (Test-Path $bk) { Move-Item $bk (Join-Path $audioRoot $langSub) -Force }
    }
    if (Test-Path $audioStage) { Remove-Item $audioStage -Recurse -Force -ErrorAction SilentlyContinue }
  }

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
  Write-Host "[SUCCESS] Lean Android APK -> Desktop\LawStudyes-v$Version.apk & www/LawStudyes-Offline.apk ($apkMB)" -ForegroundColor Green

  Write-Host "`n=== 7. Updating www/download.html (WhatsApp Share Page -> v$Version) ===" -ForegroundColor Cyan
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
    .card{background:#fff;border:1px solid #E8E0D5;border-radius:22px;max-width:410px;width:100%;padding:34px 26px;text-align:center;box-shadow:0 14px 34px rgba(31,27,24,.08)}
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
    <p>3-Year LL.B. English, Telugu &amp; Hindi Notes, Exact Source Diagrams, Indian Professor Human Voice &amp; 1-Tap Hard-Copy PDF Download.</p>
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
    Write-Host "`n=== 8. Building Windows Founder Console v$Version (.exe) ===" -ForegroundColor Cyan
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

Write-Host "`n=== 9. Staging v$Version Scripts, Audio & Release Files Safely ===" -ForegroundColor Cyan
Invoke-GitSafe @("config", "core.safecrlf", "false") | Out-Null
$toStage = @(
  "SmokeTest-LawStudyes-v3.1.1.ps1",
  "scripts/smoke_audit_db.py",
  "scripts/smoke_verify_ota.py",
  "scripts/convert_en_to_te_hi.py",
  "scripts/generate_professor_audio.py",
  "Sync-And-Translate-BeforeDeploy.ps1",
  "www/audio"
)
foreach ($item in $toStage) {
  if (Test-Path (Join-Path $root $item)) {
    Invoke-GitSafe @("add", $item) | Out-Null
  }
}
if ((Test-Path (Join-Path $wwwDir "LawStudyes-Offline.apk")) -and (-not $OtaOnly)) {
  Invoke-GitSafe @("add", "-f", "www/LawStudyes-Offline.apk") | Out-Null
}

Write-Host "`n=== 10. Pushing Verified Live OTA v$Version (Auto Pre-Push & Post-Push Smoke Tests Active) ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "v$Version - Better Telugu, Verbatim Source Diagrams, AI Indian Professor Voice & Hard-Copy PDF Download"