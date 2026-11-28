param(
  [switch]$RunOtaNow
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$otaPath = Join-Path $root "Push-LawStudyes-OTA.ps1"
if (-not (Test-Path $otaPath)) {
  throw "Push-LawStudyes-OTA.ps1 not found at: $otaPath"
}

$raw = [System.IO.File]::ReadAllText($otaPath, $u)

# Backup current Push-LawStudyes-OTA.ps1 once
$bakPath = Join-Path $root "Push-LawStudyes-OTA.ps1.pre-lean.bak"
if (-not (Test-Path $bakPath)) {
  [System.IO.File]::WriteAllText($bakPath, $raw, $u)
  Write-Host "[BACKUP] Saved original -> Push-LawStudyes-OTA.ps1.pre-lean.bak" -ForegroundColor DarkGray
}

# Keep temp staging folder & backup ignored by Git
$giPath = Join-Path $root ".gitignore"
$giTxt = if (Test-Path $giPath) { [System.IO.File]::ReadAllText($giPath, $u) } else { "" }
if ($giTxt -notmatch '\.ls_mp3_stage_tmp') {
  [System.IO.File]::WriteAllText($giPath, ($giTxt.TrimEnd() + "`r`n.ls_mp3_stage_tmp/`r`nPush-LawStudyes-OTA.ps1.pre-lean.bak`r`n"), $u)
}

# Remove any earlier patch blocks so re-running is 100% idempotent
$raw = [regex]::Replace($raw, '(?s)\r?\n?# === LS_MP3_STAGE_START ===.*?# === LS_MP3_STAGE_END ===\r?\n?', "`r`n")
$raw = [regex]::Replace($raw, '(?s)\r?\n?# === LS_MP3_RESTORE_START ===.*?# === LS_MP3_RESTORE_END ===\r?\n?', "`r`n")
$raw = [regex]::Replace($raw, '(?s)\r?\n?# === LS_GIT_AUTOMERGE_START ===.*?# === LS_GIT_AUTOMERGE_END ===\r?\n?', "`r`n")

$stageTryBlock = @'
# === LS_MP3_STAGE_START ===
$__lsMp3Root = if ($root) { $root } else { $PSScriptRoot }
$__lsAudioDir = Join-Path $__lsMp3Root "www\audio"
$__lsMp3Stage = Join-Path $__lsMp3Root ".ls_mp3_stage_tmp"
$__lsMovedLangs = New-Object System.Collections.Generic.List[string]
# Auto-recover any MP3 folders left staged by an interrupted run
if (Test-Path $__lsMp3Stage) {
  New-Item -ItemType Directory -Path $__lsAudioDir -Force | Out-Null
  foreach ($__lg in @("en", "te", "hi")) {
    $__left = Join-Path $__lsMp3Stage $__lg
    $__dest = Join-Path $__lsAudioDir $__lg
    if ((Test-Path $__left) -and (-not (Test-Path $__dest))) {
      Move-Item $__left $__dest -Force
    }
  }
  Remove-Item $__lsMp3Stage -Recurse -Force -ErrorAction SilentlyContinue
}
# Temporarily stage www/audio/{en,te,hi} outside www/ during ZIP packing (keeps manifest.json inside ZIP)
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
'@

$restoreFinallyBlock = @'
# === LS_MP3_RESTORE_START ===
} finally {
  if ($__lsMovedLangs -and $__lsMovedLangs.Count -gt 0) {
    New-Item -ItemType Directory -Path $__lsAudioDir -Force | Out-Null
    foreach ($__lg in $__lsMovedLangs) {
      $__bk = Join-Path $__lsMp3Stage $__lg
      if (Test-Path $__bk) {
        Move-Item $__bk (Join-Path $__lsAudioDir $__lg) -Force
      }
    }
    if (Test-Path $__lsMp3Stage) {
      Remove-Item $__lsMp3Stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [LEAN OTA] Restored www/audio/{$($__lsMovedLangs -join ',')} MP3s for Git/Vercel CDN." -ForegroundColor Green
  }
}
# Ensure MP3s + manifest.json are staged for Vercel CDN deployment
$__lsPrevEaAudio = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  git config core.safecrlf false 2>$null
  if (Test-Path $__lsAudioDir) { git add "www/audio" 2>$null }
} finally {
  $ErrorActionPreference = $__lsPrevEaAudio
}
# === LS_MP3_RESTORE_END ===
'@

$stagePlainBlock = $stageTryBlock.Replace("try {`r`n# === LS_MP3_STAGE_END ===", "# === LS_MP3_STAGE_END ===").Replace("try {`n# === LS_MP3_STAGE_END ===", "# === LS_MP3_STAGE_END ===")
$restorePlainBlock = $restoreFinallyBlock.Replace("# === LS_MP3_RESTORE_START ===`r`n} finally {", "# === LS_MP3_RESTORE_START ===").Replace("# === LS_MP3_RESTORE_START ===`n} finally {", "# === LS_MP3_RESTORE_START ===").Replace("`r`n}`r`n# Ensure MP3s", "`r`n# Ensure MP3s").Replace("`n}`n# Ensure MP3s", "`n# Ensure MP3s")

$autoMergeBlock = @'
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
    Write-Host "  [GIT SYNC] Remote origin/main is ahead by $__lsBehind commit(s) (e.g. Auto-Sync Bot). Auto-merging with -s ours..." -ForegroundColor Yellow
    git merge -s ours origin/main --no-edit -m "Auto-sync remote main while preserving verified local OTA build" 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
      throw "Auto-merge with origin/main failed (exit code $LASTEXITCODE)!"
    }
    Write-Host "  [GIT SYNC] Auto-merge succeeded (0 conflicts). Pushing to origin/main..." -ForegroundColor Green
  }
} finally {
  $ErrorActionPreference = $__lsPrevEaGit
}
# === LS_GIT_AUTOMERGE_END ===
'@

function Apply-PatchVariant {
  param([string]$SourceText, [string]$StageBlk, [string]$RestoreBlk, [string]$MergeBlk)

  $txt = $SourceText

  # Anchor 1: Right after pre-push smoke gate (or Sync-And-Translate / $wwwDir)
  $m1 = [regex]::Match($txt, '(?m)^# === LS_SMOKE_PRE_END ===[ \t]*')
  if (-not $m1.Success) { $m1 = [regex]::Match($txt, '(?m)^[^\r\n]*Sync-And-Translate-BeforeDeploy\.ps1[^\r\n]*') }
  if (-not $m1.Success) { $m1 = [regex]::Match($txt, '(?m)^\$wwwDir\s*=\s*Join-Path\s+\$root\s+"www"[ \t]*') }
  if (-not $m1.Success) { throw "Could not locate pre-pack anchor in Push-LawStudyes-OTA.ps1." }

  # Anchor 2: Right before Section 3 (Committing & Pushing) or first active `git add`
  $m2 = [regex]::Match($txt, '(?m)^[ \t]*Write-Host[^\r\n]*===\s*3\.\s*Committing[^\r\n]*')
  if (-not $m2.Success) { $m2 = [regex]::Match($txt, '(?m)^[ \t]*Write-Host[^\r\n]*Committing[^\r\n]*') }
  if (-not $m2.Success) { $m2 = [regex]::Match($txt, '(?m)^[ \t]*(?!#|Write-Host)[^\r\n]*\bgit\s+add\b[^\r\n]*') }
  if (-not $m2.Success) { throw "Could not locate Git Commit/Add anchor in Push-LawStudyes-OTA.ps1." }
  if ($m2.Index -le ($m1.Index + $m1.Length)) {
    throw "Unexpected script layout: Commit anchor appears before pre-pack anchor."
  }

  # Insert Anchor 2 first (higher offset), then Anchor 1
  $txt = $txt.Substring(0, $m2.Index) + $RestoreBlk + "`r`n" + $txt.Substring($m2.Index)
  $pos1 = $m1.Index + $m1.Length
  $txt = $txt.Substring(0, $pos1) + "`r`n" + $StageBlk + $txt.Substring($pos1)

  # Anchor 3: Right before the active `git push` command
  $m3 = [regex]::Match($txt, '(?m)^[ \t]*(?!#|Write-Host|throw\b)[^\r\n]*\bgit\s+push\b[^\r\n]*')
  if (-not $m3.Success) { throw "Could not locate active 'git push' line in Push-LawStudyes-OTA.ps1." }
  $txt = $txt.Substring(0, $m3.Index) + $MergeBlk + "`r`n" + $txt.Substring($m3.Index)

  return $txt
}

function Test-PsAst {
  param([string]$TextToTest, [string]$TmpFile)
  [System.IO.File]::WriteAllText($TmpFile, $TextToTest, $u)
  $tok = $null; $errs = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($TmpFile, [ref]$tok, [ref]$errs)
  return $errs
}

$tmpPath = "$otaPath.tmp"
$patched = Apply-PatchVariant -SourceText $raw -StageBlk $stageTryBlock -RestoreBlk $restoreFinallyBlock -MergeBlk $autoMergeBlock
$astErrs = Test-PsAst -TextToTest $patched -TmpFile $tmpPath
$usedTryFinally = $true

if ($astErrs -and $astErrs.Count -gt 0) {
  $usedTryFinally = $false
  $patched = Apply-PatchVariant -SourceText $raw -StageBlk $stagePlainBlock -RestoreBlk $restorePlainBlock -MergeBlk $autoMergeBlock
  $astErrs = Test-PsAst -TextToTest $patched -TmpFile $tmpPath
}

if ($astErrs -and $astErrs.Count -gt 0) {
  Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
  $errSummary = ($astErrs | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }) -join "; "
  throw "Aborted! AST syntax validation failed -> $errSummary"
}

Move-Item $tmpPath $otaPath -Force
Write-Host "[PASS] Push-LawStudyes-OTA.ps1 patched & AST-verified (0 errors, try/finally=$usedTryFinally)." -ForegroundColor Green
Write-Host "  -> Lean OTA ZIP:   Excludes www/audio/{en,te,hi}/*.mp3 from ota-bundle.zip (keeps manifest.json + Vercel CDN MP3s)" -ForegroundColor Cyan
Write-Host "  -> Git Auto-Merge: Fetches origin/main & auto-merges newer Auto-Sync Bot commits with -s ours before git push" -ForegroundColor Cyan

if ($RunOtaNow) {
  Write-Host "`n=== Pushing Lean OTA Now to Verify mp3InZip=0 & Live Vercel Parity ===" -ForegroundColor Cyan
  & $otaPath -Message "Lean OTA ZIP (MP3s on Vercel CDN, excluded from ZIP) & Auto-Merge enabled"
}param(
  [switch]$RunOtaNow
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$otaPath = Join-Path $root "Push-LawStudyes-OTA.ps1"
if (-not (Test-Path $otaPath)) {
  throw "Push-LawStudyes-OTA.ps1 not found at: $otaPath"
}

$raw = [System.IO.File]::ReadAllText($otaPath, $u)

# Backup current Push-LawStudyes-OTA.ps1 once
$bakPath = Join-Path $root "Push-LawStudyes-OTA.ps1.pre-lean.bak"
if (-not (Test-Path $bakPath)) {
  [System.IO.File]::WriteAllText($bakPath, $raw, $u)
  Write-Host "[BACKUP] Saved original -> Push-LawStudyes-OTA.ps1.pre-lean.bak" -ForegroundColor DarkGray
}

# Keep temp staging folder & backup ignored by Git
$giPath = Join-Path $root ".gitignore"
$giTxt = if (Test-Path $giPath) { [System.IO.File]::ReadAllText($giPath, $u) } else { "" }
if ($giTxt -notmatch '\.ls_mp3_stage_tmp') {
  [System.IO.File]::WriteAllText($giPath, ($giTxt.TrimEnd() + "`r`n.ls_mp3_stage_tmp/`r`nPush-LawStudyes-OTA.ps1.pre-lean.bak`r`n"), $u)
}

# Remove any earlier patch blocks so re-running is 100% idempotent
$raw = [regex]::Replace($raw, '(?s)\r?\n?# === LS_MP3_STAGE_START ===.*?# === LS_MP3_STAGE_END ===\r?\n?', "`r`n")
$raw = [regex]::Replace($raw, '(?s)\r?\n?# === LS_MP3_RESTORE_START ===.*?# === LS_MP3_RESTORE_END ===\r?\n?', "`r`n")
$raw = [regex]::Replace($raw, '(?s)\r?\n?# === LS_GIT_AUTOMERGE_START ===.*?# === LS_GIT_AUTOMERGE_END ===\r?\n?', "`r`n")

$stageTryBlock = @'
# === LS_MP3_STAGE_START ===
$__lsMp3Root = if ($root) { $root } else { $PSScriptRoot }
$__lsAudioDir = Join-Path $__lsMp3Root "www\audio"
$__lsMp3Stage = Join-Path $__lsMp3Root ".ls_mp3_stage_tmp"
$__lsMovedLangs = New-Object System.Collections.Generic.List[string]
# Auto-recover any MP3 folders left staged by an interrupted run
if (Test-Path $__lsMp3Stage) {
  New-Item -ItemType Directory -Path $__lsAudioDir -Force | Out-Null
  foreach ($__lg in @("en", "te", "hi")) {
    $__left = Join-Path $__lsMp3Stage $__lg
    $__dest = Join-Path $__lsAudioDir $__lg
    if ((Test-Path $__left) -and (-not (Test-Path $__dest))) {
      Move-Item $__left $__dest -Force
    }
  }
  Remove-Item $__lsMp3Stage -Recurse -Force -ErrorAction SilentlyContinue
}
# Temporarily stage www/audio/{en,te,hi} outside www/ during ZIP packing (keeps manifest.json inside ZIP)
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
'@

$restoreFinallyBlock = @'
# === LS_MP3_RESTORE_START ===
} finally {
  if ($__lsMovedLangs -and $__lsMovedLangs.Count -gt 0) {
    New-Item -ItemType Directory -Path $__lsAudioDir -Force | Out-Null
    foreach ($__lg in $__lsMovedLangs) {
      $__bk = Join-Path $__lsMp3Stage $__lg
      if (Test-Path $__bk) {
        Move-Item $__bk (Join-Path $__lsAudioDir $__lg) -Force
      }
    }
    if (Test-Path $__lsMp3Stage) {
      Remove-Item $__lsMp3Stage -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [LEAN OTA] Restored www/audio/{$($__lsMovedLangs -join ',')} MP3s for Git/Vercel CDN." -ForegroundColor Green
  }
}
# Ensure MP3s + manifest.json are staged for Vercel CDN deployment
$__lsPrevEaAudio = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  git config core.safecrlf false 2>$null
  if (Test-Path $__lsAudioDir) { git add "www/audio" 2>$null }
} finally {
  $ErrorActionPreference = $__lsPrevEaAudio
}
# === LS_MP3_RESTORE_END ===
'@

$stagePlainBlock = $stageTryBlock.Replace("try {`r`n# === LS_MP3_STAGE_END ===", "# === LS_MP3_STAGE_END ===").Replace("try {`n# === LS_MP3_STAGE_END ===", "# === LS_MP3_STAGE_END ===")
$restorePlainBlock = $restoreFinallyBlock.Replace("# === LS_MP3_RESTORE_START ===`r`n} finally {", "# === LS_MP3_RESTORE_START ===").Replace("# === LS_MP3_RESTORE_START ===`n} finally {", "# === LS_MP3_RESTORE_START ===").Replace("`r`n}`r`n# Ensure MP3s", "`r`n# Ensure MP3s").Replace("`n}`n# Ensure MP3s", "`n# Ensure MP3s")

$autoMergeBlock = @'
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
    Write-Host "  [GIT SYNC] Remote origin/main is ahead by $__lsBehind commit(s) (e.g. Auto-Sync Bot). Auto-merging with -s ours..." -ForegroundColor Yellow
    git merge -s ours origin/main --no-edit -m "Auto-sync remote main while preserving verified local OTA build" 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
      throw "Auto-merge with origin/main failed (exit code $LASTEXITCODE)!"
    }
    Write-Host "  [GIT SYNC] Auto-merge succeeded (0 conflicts). Pushing to origin/main..." -ForegroundColor Green
  }
} finally {
  $ErrorActionPreference = $__lsPrevEaGit
}
# === LS_GIT_AUTOMERGE_END ===
'@

function Apply-PatchVariant {
  param([string]$SourceText, [string]$StageBlk, [string]$RestoreBlk, [string]$MergeBlk)

  $txt = $SourceText

  # Anchor 1: Right after pre-push smoke gate (or Sync-And-Translate / $wwwDir)
  $m1 = [regex]::Match($txt, '(?m)^# === LS_SMOKE_PRE_END ===[ \t]*')
  if (-not $m1.Success) { $m1 = [regex]::Match($txt, '(?m)^[^\r\n]*Sync-And-Translate-BeforeDeploy\.ps1[^\r\n]*') }
  if (-not $m1.Success) { $m1 = [regex]::Match($txt, '(?m)^\$wwwDir\s*=\s*Join-Path\s+\$root\s+"www"[ \t]*') }
  if (-not $m1.Success) { throw "Could not locate pre-pack anchor in Push-LawStudyes-OTA.ps1." }

  # Anchor 2: Right before Section 3 (Committing & Pushing) or first active `git add`
  $m2 = [regex]::Match($txt, '(?m)^[ \t]*Write-Host[^\r\n]*===\s*3\.\s*Committing[^\r\n]*')
  if (-not $m2.Success) { $m2 = [regex]::Match($txt, '(?m)^[ \t]*Write-Host[^\r\n]*Committing[^\r\n]*') }
  if (-not $m2.Success) { $m2 = [regex]::Match($txt, '(?m)^[ \t]*(?!#|Write-Host)[^\r\n]*\bgit\s+add\b[^\r\n]*') }
  if (-not $m2.Success) { throw "Could not locate Git Commit/Add anchor in Push-LawStudyes-OTA.ps1." }
  if ($m2.Index -le ($m1.Index + $m1.Length)) {
    throw "Unexpected script layout: Commit anchor appears before pre-pack anchor."
  }

  # Insert Anchor 2 first (higher offset), then Anchor 1
  $txt = $txt.Substring(0, $m2.Index) + $RestoreBlk + "`r`n" + $txt.Substring($m2.Index)
  $pos1 = $m1.Index + $m1.Length
  $txt = $txt.Substring(0, $pos1) + "`r`n" + $StageBlk + $txt.Substring($pos1)

  # Anchor 3: Right before the active `git push` command
  $m3 = [regex]::Match($txt, '(?m)^[ \t]*(?!#|Write-Host|throw\b)[^\r\n]*\bgit\s+push\b[^\r\n]*')
  if (-not $m3.Success) { throw "Could not locate active 'git push' line in Push-LawStudyes-OTA.ps1." }
  $txt = $txt.Substring(0, $m3.Index) + $MergeBlk + "`r`n" + $txt.Substring($m3.Index)

  return $txt
}

function Test-PsAst {
  param([string]$TextToTest, [string]$TmpFile)
  [System.IO.File]::WriteAllText($TmpFile, $TextToTest, $u)
  $tok = $null; $errs = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($TmpFile, [ref]$tok, [ref]$errs)
  return $errs
}

$tmpPath = "$otaPath.tmp"
$patched = Apply-PatchVariant -SourceText $raw -StageBlk $stageTryBlock -RestoreBlk $restoreFinallyBlock -MergeBlk $autoMergeBlock
$astErrs = Test-PsAst -TextToTest $patched -TmpFile $tmpPath
$usedTryFinally = $true

if ($astErrs -and $astErrs.Count -gt 0) {
  $usedTryFinally = $false
  $patched = Apply-PatchVariant -SourceText $raw -StageBlk $stagePlainBlock -RestoreBlk $restorePlainBlock -MergeBlk $autoMergeBlock
  $astErrs = Test-PsAst -TextToTest $patched -TmpFile $tmpPath
}

if ($astErrs -and $astErrs.Count -gt 0) {
  Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
  $errSummary = ($astErrs | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }) -join "; "
  throw "Aborted! AST syntax validation failed -> $errSummary"
}

Move-Item $tmpPath $otaPath -Force
Write-Host "[PASS] Push-LawStudyes-OTA.ps1 patched & AST-verified (0 errors, try/finally=$usedTryFinally)." -ForegroundColor Green
Write-Host "  -> Lean OTA ZIP:   Excludes www/audio/{en,te,hi}/*.mp3 from ota-bundle.zip (keeps manifest.json + Vercel CDN MP3s)" -ForegroundColor Cyan
Write-Host "  -> Git Auto-Merge: Fetches origin/main & auto-merges newer Auto-Sync Bot commits with -s ours before git push" -ForegroundColor Cyan

if ($RunOtaNow) {
  Write-Host "`n=== Pushing Lean OTA Now to Verify mp3InZip=0 & Live Vercel Parity ===" -ForegroundColor Cyan
  & $otaPath -Message "Lean OTA ZIP (MP3s on Vercel CDN, excluded from ZIP) & Auto-Merge enabled"
}