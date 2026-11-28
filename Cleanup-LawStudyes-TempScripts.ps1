param(
  [switch]$DryRun,
  [switch]$RemoveBackups
)

$ErrorActionPreference = "Stop"
$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host ("  Law Studyes Workspace Cleanup" + $(if ($DryRun) { " [DRY RUN]" } else { "" })) -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

# --- 1. Promote Part4-Bind-And-Deploy.ps1 to a permanent name before removing Part* scripts ---
$oldBinder = Join-Path $root "Part4-Bind-And-Deploy.ps1"
$permBinder = Join-Path $root "Bind-And-Deploy-LawStudyes.ps1"
if ((Test-Path $oldBinder) -and (-not (Test-Path $permBinder))) {
  if ($DryRun) {
    Write-Host "[PREVIEW] Would promote Part4-Bind-And-Deploy.ps1 -> Bind-And-Deploy-LawStudyes.ps1" -ForegroundColor Yellow
  } else {
    Copy-Item $oldBinder $permBinder -Force
    Write-Host "[PROMOTED] Part4-Bind-And-Deploy.ps1 -> Bind-And-Deploy-LawStudyes.ps1" -ForegroundColor Green
  }
}

# --- 2. Strict Whitelist of Permanent Scripts (NEVER Deleted) ---
$keepRootScripts = @(
  "Bind-And-Deploy-LawStudyes.ps1",
  "Push-LawStudyes-OTA.ps1",
  "Release-LawStudyes-AllPlatforms.ps1",
  "Sync-And-Translate-BeforeDeploy.ps1",
  "SmokeTest-LawStudyes-v3.1.1.ps1",
  "Cleanup-LawStudyes-TempScripts.ps1"
)

Write-Host "=== Permanent Scripts Verified ===" -ForegroundColor Cyan
foreach ($kp in $keepRootScripts) {
  $fp = Join-Path $root $kp
  if (Test-Path $fp) {
    Write-Host "  [KEEP] $kp" -ForegroundColor Green
  }
}
$permConverter = Join-Path $root "scripts\convert_en_to_te_hi.py"
if (Test-Path $permConverter) {
  Write-Host "  [KEEP] scripts\convert_en_to_te_hi.py" -ForegroundColor Green
} else {
  Write-Host "  [WARN] scripts\convert_en_to_te_hi.py not found!" -ForegroundColor Yellow
}

# --- 3. Identify & Remove Temporary Setup Scripts ---
Write-Host "`n=== Cleaning Temporary Setup Scripts ===" -ForegroundColor Cyan
$tempPattern = '^(Part\d*[-_]|Mod(\d*|-Final)[-_]|Hook-SmokeTest|Build-Trilingual|Patch|Fix|Upgrade).*\.ps1$'
$targets = New-Object System.Collections.Generic.List[System.IO.FileInfo]

Get-ChildItem $root -File -Filter "*.ps1" | ForEach-Object {
  if (($keepRootScripts -notcontains $_.Name) -and ($_.Name -match $tempPattern)) {
    $targets.Add($_)
  }
}

# Remove superseded v1 converter only if the permanent legal-token converter exists
$oldConverter = Join-Path $root "scripts\generate_te_hi_db.py"
if ((Test-Path $permConverter) -and (Test-Path $oldConverter)) {
  $targets.Add((Get-Item $oldConverter))
}

# Remove stray .tmp / .log files (and .bak files only if -RemoveBackups is passed)
Get-ChildItem $root -File | Where-Object {
  ($_.Name -match '\.(tmp|log)$') -or ($RemoveBackups -and $_.Name -match '\.bak$')
} | ForEach-Object { $targets.Add($_) }

if ($RemoveBackups) {
  $dbBak = Join-Path $root "www\nyayasaral_db.json.bak"
  if (Test-Path $dbBak) { $targets.Add((Get-Item $dbBak)) }
}

$removed = 0
if ($targets.Count -eq 0) {
  Write-Host "  [OK] Workspace is already clean (0 temporary scripts found)." -ForegroundColor Green
} else {
  foreach ($item in $targets) {
    $rel = $item.FullName.Substring($root.Length).TrimStart('\')
    if ($DryRun) {
      Write-Host "  [PREVIEW DEL] $rel" -ForegroundColor Yellow
    } else {
      Remove-Item $item.FullName -Force
      Write-Host "  [DELETED] $rel" -ForegroundColor DarkGray
      $removed++
    }
  }
}

# Clean temporary ls_* helper files generated in %TEMP%
$tempHelpers = @(Get-ChildItem $env:TEMP -File -Filter "ls_*.py" -ErrorAction SilentlyContinue) +
               @(Get-ChildItem $env:TEMP -File -Filter "ls_*.js" -ErrorAction SilentlyContinue)
if ($tempHelpers.Count -gt 0) {
  if ($DryRun) {
    Write-Host "  [PREVIEW DEL] $($tempHelpers.Count) temp helper file(s) in %TEMP%" -ForegroundColor Yellow
  } else {
    $tempHelpers | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "  [DELETED] $($tempHelpers.Count) temp helper file(s) in %TEMP%" -ForegroundColor DarkGray
  }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($DryRun) {
  Write-Host "  DRY RUN COMPLETE ($($targets.Count) project file(s) matched). Run without -DryRun to delete." -ForegroundColor Yellow
} else {
  Write-Host "  CLEANUP COMPLETE ($removed project file(s) removed)." -ForegroundColor Green
}
Write-Host "============================================================`n" -ForegroundColor Cyan