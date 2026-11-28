<#
.SYNOPSIS
  Law Studyes - Production OTA Pusher (Python Forward-Slash ZIP + SemVer + Live SHA-256 Parity)
  Compatible with manual runs, -Version overrides, and the Windows Founder Console.
.USAGE
  .\Push-LawStudyes-OTA.ps1
  .\Push-LawStudyes-OTA.ps1 -Version "3.0.7-test"
  .\Push-LawStudyes-OTA.ps1 -Message "Updated Constitutional Law notes"
#>
param(
  [string]$Version = "",
  [string]$Message = "",
  [int]$MaxWaitSeconds = 75,
  [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$wwwDir = Join-Path $root "www"

if (Test-Path (Join-Path $root "Sync-And-Translate-BeforeDeploy.ps1")) { & (Join-Path $root "Sync-And-Translate-BeforeDeploy.ps1") }
# === LS_SMOKE_PRE_START ===
$__lsRoot = if ($root) { $root } else { $PSScriptRoot }
$__lsSmokeFile = Join-Path $__lsRoot "SmokeTest-LawStudyes-v3.1.1.ps1"
$__lsSmokeVer = "3.1.1"
$__lsManPath = Join-Path $__lsRoot "www\manifest.json"
if (Test-Path $__lsManPath) {
  try {
    $__lsManObj = Get-Content $__lsManPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($__lsManObj.version) { $__lsSmokeVer = [string]$__lsManObj.version }
  } catch {}
}
if (Test-Path $__lsSmokeFile) {
  Write-Host "`n=== Pre-Push Gate: Running Local Smoke Test (v$__lsSmokeVer) ===" -ForegroundColor Cyan
  powershell -ExecutionPolicy Bypass -File $__lsSmokeFile -ExpectedVersion $__lsSmokeVer -SkipLiveOta
  if ($LASTEXITCODE -ne 0) {
    throw "Pre-push Smoke Test FAILED (exit code $LASTEXITCODE)! Aborting OTA push to protect active users."
  }
} else {
  Write-Host "[WARN] SmokeTest-LawStudyes-v3.1.1.ps1 not found; skipping pre-push smoke gate." -ForegroundColor Yellow
}
# === LS_SMOKE_PRE_END ===
# === LS_MP3_STAGE_START ===
$__lsMp3Root = if ($root) { $root } else { $PSScriptRoot }
$__lsAudioDir = Join-Path $__lsMp3Root "www\audio"
$__lsMp3Stage = Join-Path $__lsMp3Root ".ls_mp3_stage_tmp"
$__lsMovedLangs = New-Object System.Collections.Generic.List[string]
if (Test-Path $__lsMp3Stage) {
  New-Item -ItemType Directory -Path $__lsAudioDir -Force | Out-Null
  foreach ($__lg in @("en", "te", "hi")) {
    $__left = Join-Path $__lsMp3Stage $__lg
    $__dest = Join-Path $__lsAudioDir $__lg
    if ((Test-Path $__left) -and (-not (Test-Path $__dest))) { Move-Item $__left $__dest -Force }
  }
  Remove-Item $__lsMp3Stage -Recurse -Force -ErrorAction SilentlyContinue
}
foreach ($__lg in @("en", "te", "hi")) {
  $__src = Join-Path $__lsAudioDir $__lg
  if (Test-Path $__src) {
    New-Item -ItemType Directory -Path $__lsMp3Stage -Force | Out-Null
    Move-Item $__src (Join-Path $__lsMp3Stage $__lg) -Force
    $__lsMovedLangs.Add($__lg)
  }
}
if ($__lsMovedLangs.Count -gt 0) {
  Write-Host "  [LEAN OTA] Excluded www/audio/{$($__lsMovedLangs -join ',')} MP3s from ota-bundle.zip (hosted on Vercel CDN)." -ForegroundColor Cyan
}
try {
# === LS_MP3_STAGE_END ===
if (-not (Test-Path (Join-Path $wwwDir "index.html"))) {
  throw "www/index.html not found. Run this script from the project root."
}

Write-Host "`n=== 1. Validating Modular JS Syntax (www/js/modules/) ===" -ForegroundColor Cyan
$modDir = Join-Path $wwwDir "js\modules"
if (Test-Path $modDir) {
  $modFiles = Get-ChildItem $modDir -Filter "*.js" -File
  foreach ($mf in $modFiles) {
    $chkErr = node --check $mf.FullName 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw ("JS syntax error in " + $mf.Name + ": " + $chkErr)
    }
  }
  Write-Host ("[PASS] Verified " + $modFiles.Count + " module(s) with 0 JS errors.") -ForegroundColor Green
}

Write-Host "`n=== 2. Packing Forward-Slash OTA Bundle & Computing SHA-256 ===" -ForegroundColor Cyan
$pyBuild = @'
import hashlib
import json
import re
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

www = Path("www")
idx_path = www / "index.html"
custom_ver = sys.argv[1].strip() if len(sys.argv) > 1 else ""

base_ver = "3.0.7"
idx_text = idx_path.read_text(encoding="utf-8", errors="ignore")
m = re.search(r'var\s+CURRENT_APP_VER\s*=\s*"(\d+\.\d+\.\d+)"', idx_text)
if m:
    base_ver = m.group(1)

now_utc = datetime.now(timezone.utc)
ver = custom_ver if custom_ver else f"{base_ver}-{now_utc.strftime('%m%d%H%M')}"
iso = now_utc.strftime("%Y-%m-%dT%H:%M:%SZ")

exclude_names = {
    "ota-bundle.zip",
    "ota-version.json",
    "ota-manifest.json",
    "LawStudyes-Offline.apk",
    ".DS_Store",
    "Thumbs.db",
}

zp = www / "ota-bundle.zip"
file_count = 0
mod_count = 0
with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for p in sorted(www.rglob("*")):
        if not p.is_file():
            continue
        if p.name in exclude_names or p.suffix.lower() in {".apk", ".map"}:
            continue
        arcname = p.relative_to(www).as_posix()
        zf.write(p, arcname)
        file_count += 1
        if arcname.startswith("js/modules/") and arcname.endswith(".js"):
            mod_count += 1

with zipfile.ZipFile(zp, "r") as zchk:
    names = zchk.namelist()
    bad_slashes = sum(1 for n in names if "\\" in n)
    if "index.html" not in names:
        sys.exit("ERROR: index.html missing at ZIP root!")
    if bad_slashes > 0:
        sys.exit(f"ERROR: Found {bad_slashes} Windows backslash path(s) in ZIP!")

sha = hashlib.sha256(zp.read_bytes()).hexdigest().lower()
sz = zp.stat().st_size
url = "https://law-studyes.vercel.app/ota-bundle.zip"

ver_payload = {
    "version": ver,
    "url": url,
    "sha256": sha,
    "checksum": sha,
    "sizeBytes": sz,
    "updatedAt": iso,
}
manifest_payload = {
    "app": "Law Studyes",
    "version": ver,
    "bundle": "ota-bundle.zip",
    "url": url,
    "sha256": sha,
    "checksum": sha,
    "sizeBytes": sz,
    "updatedAt": iso,
}

(www / "ota-version.json").write_text(json.dumps(ver_payload, indent=2) + "\n", encoding="utf-8")
(www / "ota-manifest.json").write_text(json.dumps(manifest_payload, indent=2) + "\n", encoding="utf-8")

print(json.dumps({
    "version": ver,
    "sha256": sha,
    "sizeBytes": sz,
    "files": file_count,
    "modules": mod_count,
}))
'@

$pyBuildPath = Join-Path $env:TEMP "ls_ota_build_prod.py"
[System.IO.File]::WriteAllText($pyBuildPath, $pyBuild, $u)

$buildRaw = python $pyBuildPath $Version
if ($LASTEXITCODE -ne 0) { throw "Python forward-slash OTA bundler failed!" }
$built = $buildRaw | ConvertFrom-Json

$builtVer = $built.version
$builtSha = $built.sha256
$builtMB = [Math]::Round($built.sizeBytes / 1MB, 2)
Write-Host ("[BUILT] SemVer=" + $builtVer + " | Size=" + $builtMB + " MB | Files=" + $built.files + " | Modules=" + $built.modules + " | SHA=" + $builtSha.Substring(0,16)) -ForegroundColor Green

# === LS_MP3_RESTORE_START ===
} finally {
  if ($__lsMovedLangs -and $__lsMovedLangs.Count -gt 0) {
    New-Item -ItemType Directory -Path $__lsAudioDir -Force | Out-Null
    foreach ($__lg in $__lsMovedLangs) {
      $__bk = Join-Path $__lsMp3Stage $__lg
      if (Test-Path $__bk) { Move-Item $__bk (Join-Path $__lsAudioDir $__lg) -Force }
    }
    if (Test-Path $__lsMp3Stage) { Remove-Item $__lsMp3Stage -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "  [LEAN OTA] Restored www/audio/{$($__lsMovedLangs -join ',')} MP3s for Git/Vercel CDN." -ForegroundColor Green
  }
}
$__lsPrevEaAudio = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  git config core.safecrlf false 2>$null
  if (Test-Path $__lsAudioDir) { git add "www/audio" 2>$null }
} finally { $ErrorActionPreference = $__lsPrevEaAudio }
# === LS_MP3_RESTORE_END ===
Write-Host "`n=== 3. Committing & Pushing OTA Bundle to GitHub (Triggers Vercel CDN) ===" -ForegroundColor Cyan
git add -A www/
if (Test-Path (Join-Path $root ".github\workflows\auto-sync-lawstudyes.yml")) {
  git add .github/workflows/auto-sync-lawstudyes.yml
}

$status = git status --porcelain
if (-not $status) {
  Write-Host "[INFO] No changes to commit." -ForegroundColor Yellow
} else {
  $commitMsg = if ($Message.Trim()) {
    "OTA v$builtVer - $($Message.Trim())"
  } else {
    "OTA v$builtVer - Verified forward-slash bundle (SHA $($builtSha.Substring(0,12)))"
  }
  git commit -m $commitMsg
  if ($LASTEXITCODE -ne 0) { throw "git commit failed!" }
}

# === LS_GIT_AUTOMERGE_START ===
$__lsPrevEaGit = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  git config core.safecrlf false 2>$null
  Write-Host "  [GIT SYNC] Checking origin/main for newer remote commits..." -ForegroundColor Cyan
  git fetch origin main 2>&1 | Out-Null
  $__lsBehindRaw = ((git rev-list --count HEAD..origin/main 2>$null) | Out-String).Trim()
  $__lsBehind = 0
  if ($__lsBehindRaw -match '^\d+$') { $__lsBehind = [int]$__lsBehindRaw }
  if ($__lsBehind -gt 0) {
    Write-Host "  [GIT SYNC] Remote origin/main is ahead by $__lsBehind commit(s). Auto-merging with -s ours..." -ForegroundColor Yellow
    git merge -s ours origin/main --no-edit -m "Auto-sync remote main while preserving verified local OTA build" 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) { throw "Auto-merge with origin/main failed (exit code $LASTEXITCODE)!" }
    Write-Host "  [GIT SYNC] Auto-merge succeeded (0 conflicts). Pushing..." -ForegroundColor Green
  }
} finally { $ErrorActionPreference = $__lsPrevEaGit }
# === LS_GIT_AUTOMERGE_END ===
git push origin main
if ($LASTEXITCODE -ne 0) {
  Write-Host "[WARN] Remote main has newer commits (e.g. Auto-Sync Bot). Run 'git pull --rebase origin main' then retry." -ForegroundColor Yellow
  throw "git push origin main failed!"
}

if ($SkipVerify) {
  Write-Host "[DONE] Pushed v$builtVer (Skipped live CDN verification)." -ForegroundColor Yellow
  exit 0
}

Write-Host "`n=== 4. Polling Vercel CDN for Live SHA-256 Parity (max ${MaxWaitSeconds}s) ===" -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds($MaxWaitSeconds)
$matched = $false
$liveMeta = $null

Start-Sleep -Seconds 10
while ((Get-Date) -lt $deadline) {
  $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  try {
    $liveMeta = (Invoke-WebRequest "https://law-studyes.vercel.app/ota-version.json?t=$ts" -UseBasicParsing -TimeoutSec 15).Content | ConvertFrom-Json
    $liveSha = if ($liveMeta.sha256) { $liveMeta.sha256.ToLower() } else { "" }
    if ($liveMeta.version -eq $builtVer -and $liveSha -eq $builtSha) {
      $matched = $true
      break
    }
    Write-Host ("  [WAIT] Vercel still serving " + $liveMeta.version + " ... waiting 5s") -ForegroundColor DarkGray
  } catch {
    Write-Host "  [WAIT] Retrying Vercel metadata fetch..." -ForegroundColor DarkGray
  }
  Start-Sleep -Seconds 5
}

if (-not $matched) {
  $gotVer = if ($liveMeta) { $liveMeta.version } else { "Unreachable" }
  throw "Timed out waiting for Vercel CDN parity. Expected $builtVer ($($builtSha.Substring(0,16))), got $gotVer."
}

# Download live ZIP from Vercel and verify actual binary SHA-256 + forward-slash structure
$ts2 = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$tmpZip = Join-Path $env:TEMP "ls_ota_live_verify.zip"
Invoke-WebRequest "https://law-studyes.vercel.app/ota-bundle.zip?t=$ts2" -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60

$pyVerify = @'
import hashlib
import re
import sys
import zipfile
from pathlib import Path

zp = Path(sys.argv[1])
expected_sha = sys.argv[2].strip().lower()

actual_sha = hashlib.sha256(zp.read_bytes()).hexdigest().lower()
with zipfile.ZipFile(zp, "r") as z:
    names = z.namelist()
    has_idx = "index.html" in names
    bad = sum(1 for n in names if "\\" in n)
    mods = sum(1 for n in names if n.startswith("js/modules/") and n.endswith(".js"))
    idx_txt = z.read("index.html").decode("utf-8", "ignore") if has_idx else ""
    m = re.search(r'CURRENT_APP_VER\s*=\s*"([^"]+)"', idx_txt)
    app_ver = m.group(1) if m else "UNKNOWN"

sha_ok = (actual_sha == expected_sha)
print(f"[LIVE ZIP] shaMatch={sha_ok} | rootIndex={has_idx} | badSlashes={bad} | modules={mods} | appVer={app_ver} | sha={actual_sha[:16]}")
if not (sha_ok and has_idx and bad == 0):
    sys.exit(1)
'@

$pyVerifyPath = Join-Path $env:TEMP "ls_ota_verify_prod.py"
[System.IO.File]::WriteAllText($pyVerifyPath, $pyVerify, $u)
python $pyVerifyPath $tmpZip $builtSha
if ($LASTEXITCODE -ne 0) {
  throw "Live Vercel ZIP binary verification failed!"
}

Write-Host ("[VERIFIED] Vercel LIVE Parity MATCH! Version=" + $builtVer + " | SHA=" + $builtSha.Substring(0,16)) -ForegroundColor Green

# === LS_SMOKE_POST_START ===
if (Test-Path $__lsSmokeFile) {
  Write-Host "`n=== Post-Push Gate: Running Full Live Vercel OTA Smoke Test (v$__lsSmokeVer) ===" -ForegroundColor Cyan
  powershell -ExecutionPolicy Bypass -File $__lsSmokeFile -ExpectedVersion $__lsSmokeVer
  if ($LASTEXITCODE -ne 0) {
    throw "Post-push Live Smoke Test FAILED (exit code $LASTEXITCODE)! Check Vercel CDN parity immediately."
  }
}
# === LS_SMOKE_POST_END ===
