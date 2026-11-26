param([int]$BatchSize = 0, [int]$Workers = 8)
$ErrorActionPreference = "Stop"
$env:PYTHONIOENCODING = "utf-8"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
# === LS_DUAL_SOURCE_SYNC_START ===
Write-Host "
=== Dual-Source Sync: Comparing Website + Study Material & Strict Grammar Polish ===" -ForegroundColor Cyan
$__dualPy = Join-Path $root "scripts\merge_dual_source_notes.py"
if (Test-Path $__dualPy) {
  python -u $__dualPy (Join-Path $root "www\nyayasaral_db.json") "" (Join-Path $root "data\study_material_index.json") (Join-Path $root "reports\dual_source_report.json")
  if ($LASTEXITCODE -ne 0) { throw "Dual-source merge/grammar sync failed!" }
}
# === LS_DUAL_SOURCE_SYNC_END ===
$pyScript = Join-Path $root "scripts\convert_en_to_te_hi.py"
$dbPath = Join-Path $root "www\nyayasaral_db.json"
$ckpt = Join-Path $root ".ls_legal_tr_cache.json"
if ((Test-Path $pyScript) -and (Test-Path $dbPath)) {
  Write-Host "`n=== Pre-Deploy Auto-Convert: Verifying EN -> TE & HI Legal Copies ===" -ForegroundColor Cyan
  python -u $pyScript $dbPath $BatchSize $Workers $ckpt
  if ($LASTEXITCODE -ne 0) { Write-Host "[WARN] Converter exited with $LASTEXITCODE (existing DB preserved)." -ForegroundColor Yellow }
}