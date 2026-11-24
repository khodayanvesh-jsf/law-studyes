<#
.SYNOPSIS
  Builds a forward-slash ota-bundle.zip from www/, updates ota-version.json & ota-manifest.json,
  and pushes to GitHub/Vercel so installed Law Studyes APKs auto-update via OTA.
#>
param(
  [string]$Version = (Get-Date -Format "yyyy.MM.dd.HHmm"),
  [string]$VercelBaseUrl = "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www"
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$wwwDir = Join-Path $root "www"
$zipPath = Join-Path $wwwDir "ota-bundle.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -Path $wwwDir -Recurse -File | Where-Object {
    $_.Name -notin @("ota-bundle.zip", "ota-version.json", "ota-manifest.json", "nyayasaral_db.json", "db-version.json")
  } | ForEach-Object {
    $rel = $_.FullName.Substring($wwwDir.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
} finally {
  $zip.Dispose()
}

$nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$verObj = @{ version = $Version; url = "$VercelBaseUrl/ota-bundle.zip"; updatedAt = $nowIso } | ConvertTo-Json -Depth 3
$manObj = @{ app = "Law Studyes"; version = $Version; bundle = "ota-bundle.zip"; updatedAt = $nowIso } | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText((Join-Path $wwwDir "ota-version.json"), $verObj, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $wwwDir "ota-manifest.json", "nyayasaral_db.json", "db-version.json"), $manObj, $utf8NoBom)

Write-Host "[OK] Built OTA v$Version -> www/ota-bundle.zip (forward-slash paths for Android)" -ForegroundColor Green

git add -A
git commit -m "OTA release v$Version"
git pull --rebase origin main
git push origin main
Write-Host "[DONE] OTA v$Version pushed to GitHub & Vercel!" -ForegroundColor Green