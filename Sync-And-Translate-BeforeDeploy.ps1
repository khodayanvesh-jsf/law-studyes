param([int]$BatchSize = 0, [int]$Workers = 8)
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyScript = Join-Path $root "scripts\convert_en_to_te_hi.py"
$dbPath = Join-Path $root "www\nyayasaral_db.json"
$ckpt = Join-Path $root ".ls_legal_tr_cache.json"
if ((Test-Path $pyScript) -and (Test-Path $dbPath)) {
  Write-Host "`n=== Pre-Deploy Auto-Convert: Verifying EN -> TE & HI Legal Copies ===" -ForegroundColor Cyan
  python -u $pyScript $dbPath $BatchSize $Workers $ckpt
  if ($LASTEXITCODE -ne 0) { Write-Host "[WARN] Converter exited with $LASTEXITCODE (existing DB preserved)." -ForegroundColor Yellow }
}