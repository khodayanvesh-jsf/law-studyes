<#
.SYNOPSIS
  Law Studyes - Clean v3.0.2 Forward-Slash OTA Builder, Pusher & Live Vercel Verifier
  Stamps v3.0.2 in www/index.html, packs www/ into www/ota-bundle.zip with strict forward slashes
  (index.html at ZIP root), updates ota-version.json & ota-manifest.json, pushes to GitHub/Vercel,
  and verifies the live Vercel ZIP contents.
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Push-LawStudyes-v3.0.2-OTA.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$idx = Join-Path $root "www\index.html"

Write-Host "`n=== 1. Stamping v3.0.2 in www/index.html ===" -ForegroundColor Cyan
$h = [System.IO.File]::ReadAllText($idx, $u)
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', '3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v3.0.2'
$h = $h -replace 'var BUILT_IN = "[^"]+";', 'var BUILT_IN = "3.0.2";'
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', 'var BUILT_IN_VER = "3.0.2";'
$h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', 'var CURRENT_APP_VER = "3.0.2";'
$h = $h -replace 'var APP_VER = "[^"]+";', 'var APP_VER = "3.0.2";'
[System.IO.File]::WriteAllText($idx, $h, $u)
Write-Host "[OK] www/index.html stamped with v3.0.2" -ForegroundColor Green

Write-Host "`n=== 2. Building Forward-Slash www/ota-bundle.zip via Python ===" -ForegroundColor Cyan
$pyBuild = @'
import hashlib, json, zipfile
from datetime import datetime, timezone
from pathlib import Path

www = Path("www")
zp = www / "ota-bundle.zip"
exclude = {"ota-bundle.zip", "ota-version.json", "ota-manifest.json", "LawStudyes-Offline.apk"}

with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for p in sorted(www.rglob("*")):
        if p.is_file() and p.name not in exclude:
            zf.write(p, p.relative_to(www).as_posix())

ver = "3.0.2." + datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
sha = hashlib.sha256(zp.read_bytes()).hexdigest().lower()
sz = zp.stat().st_size
url = "https://law-studyes.vercel.app/ota-bundle.zip"

(www / "ota-version.json").write_text(json.dumps({
    "version": ver, "url": url, "sha256": sha, "sizeBytes": sz, "updatedAt": iso
}, indent=2), encoding="utf-8")

(www / "ota-manifest.json").write_text(json.dumps({
    "app": "Law Studyes", "version": ver, "bundle": "ota-bundle.zip",
    "url": url, "sha256": sha, "sizeBytes": sz, "updatedAt": iso
}, indent=2), encoding="utf-8")

print(f"[BUILT] v{ver} | {round(sz / 1048576, 2)} MB | SHA={sha[:16]}")
'@
$pyBuildPath = Join-Path $env:TEMP "ls_build_ota_302.py"
[System.IO.File]::WriteAllText($pyBuildPath, $pyBuild, $u)
python $pyBuildPath
if ($LASTEXITCODE -ne 0) { throw "Python OTA zip builder failed!" }

Write-Host "`n=== 3. Pushing v3.0.2 OTA Bundle to GitHub & Vercel ===" -ForegroundColor Cyan
git add www/index.html www/ota-bundle.zip www/ota-version.json www/ota-manifest.json
$st = git status --porcelain
if ($st) {
  git commit -m "OTA v3.0.2 - Verified forward-slash bundle for auto-update"
  git push origin main
} else {
  Write-Host "[INFO] No git diff to commit." -ForegroundColor Yellow
}

Write-Host "`n=== 4. Waiting 30s for Vercel CDN & Verifying Live ZIP ===" -ForegroundColor Yellow
Start-Sleep -Seconds 30

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$liveMeta = (Invoke-WebRequest "https://law-studyes.vercel.app/ota-version.json?t=$ts" -UseBasicParsing -TimeoutSec 25).Content | ConvertFrom-Json
$tmpZip = Join-Path $env:TEMP "ls_v302_live.zip"
Invoke-WebRequest "https://law-studyes.vercel.app/ota-bundle.zip?t=$ts" -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60

$pyVerify = @'
import re, sys, zipfile
zp = sys.argv[1]
live_ver = sys.argv[2]
with zipfile.ZipFile(zp, "r") as z:
    names = z.namelist()
    bad = sum(1 for n in names if "\\" in n)
    mods = sum(1 for n in names if n.startswith("js/modules/") and n.endswith(".js"))
    has_idx = "index.html" in names
    idx = z.read("index.html").decode("utf-8", "ignore") if has_idx else ""
    m = re.search(r'CURRENT_APP_VER\s*=\s*"([^"]+)"', idx)
    ver_str = m.group(1) if m else "MISSING"
print(f"[LIVE VERIFY] version={live_ver} | rootIndex={has_idx} | badSlashes={bad} | modules={mods}/6 | indexVer={ver_str}")
if not has_idx or bad > 0 or mods < 6 or ver_str != "3.0.2":
    sys.exit(1)
'@
$pyVerifyPath = Join-Path $env:TEMP "ls_verify_ota_302.py"
[System.IO.File]::WriteAllText($pyVerifyPath, $pyVerify, $u)
python $pyVerifyPath $tmpZip $liveMeta.version
if ($LASTEXITCODE -ne 0) {
  Write-Host "[WARN] Live verification found a mismatch - check output above." -ForegroundColor Red
} else {
  Write-Host "[SUCCESS] Live Vercel OTA v3.0.2 is 100% verified! Open Law Studyes on your phone to auto-update." -ForegroundColor Green
}
