param(
  [int]$BatchSize = 0,
  [int]$Workers = 8
)
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyScript = Join-Path $root "scripts\generate_te_hi_db.py"
$dbPath = Join-Path $root "www\nyayasaral_db.json"
$ckpt = Join-Path $root ".ls_te_hi_cache.json"

if ((Test-Path $pyScript) -and (Test-Path $dbPath)) {
  Write-Host "`n=== Auto-Sync Pre-Deploy: Checking Telugu & Hindi Notes ===" -ForegroundColor Cyan
  python -u $pyScript $dbPath $BatchSize $Workers $ckpt
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Pre-deploy translation returned exit code $LASTEXITCODE (existing valid DB preserved)." -ForegroundColor Yellow
  }
}