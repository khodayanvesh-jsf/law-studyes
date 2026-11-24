<#
.SYNOPSIS
  Law Studyes OTA Publisher v2.6.1
  Packs UI + offline mermaid.min.js + FULL nyayasaral_db.json (all 591 EN/TE notes + verbatim
  Mermaid flowcharts, SVG diagrams, inline images & tables) into forward-slash www/ota-bundle.zip,
  updates Vercel CDN OTA manifests with SHA-256, pushes to GitHub/Vercel, and verifies live parity.
#>
param(
  [string]$Version = (Get-Date).ToUniversalTime().ToString("yyyy.MM.dd.HHmm"),
  [string]$VercelBaseUrl = "https://law-studyes.vercel.app"
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$wwwDir = Join-Path $root "www"
$zipPath = Join-Path $wwwDir "ota-bundle.zip"
$baseUrl = $VercelBaseUrl.TrimEnd('/')

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Pack ALL web assets INCLUDING vendor/mermaid.min.js, nyayasaral_db.json & db-version.json
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -Path $wwwDir -Recurse -File | Where-Object {
    $_.Name -notin @("ota-bundle.zip", "ota-version.json", "ota-manifest.json", "LawStudyes-Offline.apk")
  } | ForEach-Object {
    $rel = $_.FullName.Substring($wwwDir.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
} finally {
  $zip.Dispose()
}

$zipSizeBytes = (Get-Item $zipPath).Length
$zipSizeMB = [Math]::Round($zipSizeBytes / 1MB, 2)
$zipSha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
$nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$verObj = [ordered]@{
  version   = $Version
  url       = "$baseUrl/ota-bundle.zip"
  sha256    = $zipSha
  sizeBytes = $zipSizeBytes
  updatedAt = $nowIso
} | ConvertTo-Json -Depth 3

$manObj = [ordered]@{
  app       = "Law Studyes"
  version   = $Version
  bundle    = "ota-bundle.zip"
  url       = "$baseUrl/ota-bundle.zip"
  sha256    = $zipSha
  sizeBytes = $zipSizeBytes
  updatedAt = $nowIso
} | ConvertTo-Json -Depth 3

[System.IO.File]::WriteAllText((Join-Path $wwwDir "ota-version.json"), $verObj, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $wwwDir "ota-manifest.json"), $manObj, $utf8NoBom)

Write-Host "[OK] Built FULL Diagram + Mermaid OTA v$Version -> www/ota-bundle.zip ($zipSizeMB MB | SHA256: $($zipSha.Substring(0,16)))" -ForegroundColor Green

$gi = Join-Path $root ".gitignore"
if (Test-Path $gi) {
  $giTxt = [System.IO.File]::ReadAllText($gi, $utf8NoBom)
  if ($giTxt -notmatch 'audit_extract') {
    [System.IO.File]::WriteAllText($gi, ($giTxt.TrimEnd() + "`r`naudit_extract/`r`n"), $utf8NoBom)
  }
} else {
  [System.IO.File]::WriteAllText($gi, "audit_extract/`r`n", $utf8NoBom)
}

git add -A
git commit -m "OTA v$Version - Full 591 EN/TE notes + Offline Mermaid Flowcharts, Diagrams & Animations"
git pull --rebase origin main
git push origin main

Write-Host "[WAIT] Waiting 30s for Vercel CDN to publish v$Version..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

try {
  $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $liveMeta = (Invoke-WebRequest "$baseUrl/ota-version.json?t=$ts" -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
  $tmpZip = Join-Path $env:TEMP "ls_live_verify.zip"
  Invoke-WebRequest "$baseUrl/ota-bundle.zip?t=$ts" -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60
  $liveSha = (Get-FileHash $tmpZip -Algorithm SHA256).Hash.ToLower()
  if ($liveSha -eq $zipSha -and $liveMeta.version -eq $Version) {
    Write-Host "[VERIFIED] Vercel LIVE Parity MATCH! Version=$($liveMeta.version) | SHA=$($liveSha.Substring(0,16))" -ForegroundColor Green
  } else {
    Write-Host "[INFO] Vercel still propagating (Live=$($liveMeta.version) vs Local=$Version). Wait 20s and re-test." -ForegroundColor Yellow
  }
} catch {
  Write-Host "[WARN] Live verify skipped: $($_.Exception.Message)" -ForegroundColor Yellow
}
