<#
.SYNOPSIS
  Law Studyes v2.6.2 - Fixes OTA Rollback After Restart & Broken Force Update!
  1. Calls CapacitorUpdater.notifyAppReady() immediately in <head> (prevents Android 10s rollback).
  2. Sets capacitor.config.json plugins.CapacitorUpdater (autoUpdate: false, appReadyTimeout: 30000).
  3. Defers mermaid.min.js so 3.18 MB JS never blocks app boot or notifyAppReady().
  4. Replaces stale localStorage OTA checks with real native up.current() + clean up.set({ id }) without double reload().
  5. Fixes Force Update to purge failed/duplicate bundles and force-install fresh from Vercel CDN.
  6. Builds clean bloat-free Desktop APK v2.6.2 (versionCode 262) and pushes verified Full-Diagram OTA.
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Fix-LawStudyes-v2.6.2-PersistentOTA-ForceUpdate.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.2"
$verCode = 262
$vercelBase = "https://law-studyes.vercel.app"

Write-Host "`n=== 1. Verifying Offline Diagram Database & Mermaid Engine ===" -ForegroundColor Cyan
$dbPath = Join-Path $root "www\nyayasaral_db.json"
$mmdPath = Join-Path $root "www\vendor\mermaid.min.js"
if (-not (Test-Path $dbPath) -or (Get-Item $dbPath).Length -lt 1000000) {
  Write-Host "[INFO] Database missing or small - running scrape_nyayasaral.py..." -ForegroundColor Yellow
  python scrape_nyayasaral.py
  if ($LASTEXITCODE -ne 0) { throw "Scraper failed!" }
} else {
  Write-Host ("[OK] Using existing full diagram DB: " + [Math]::Round((Get-Item $dbPath).Length/1MB, 2) + " MB") -ForegroundColor Green
}
if (-not (Test-Path $mmdPath)) {
  throw "Missing www/vendor/mermaid.min.js! Run v2.6.1 script first or download mermaid.min.js."
}

Write-Host "`n=== 2. Configuring capacitor.config.json for Persistent Manual OTA ===" -ForegroundColor Cyan
python -c "import json,pathlib; p=pathlib.Path('capacitor.config.json'); d=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {}; d.pop('bundledWebRuntime',None); pl=d.setdefault('plugins',{}); pl['CapacitorUpdater']={'autoUpdate':False,'appReadyTimeout':30000,'responseTimeout':30000,'resetWhenUpdate':True,'autoDeleteFailed':True,'autoDeletePrevious':True}; p.write_text(json.dumps(d,indent=2),encoding='utf-8'); print('[OK] capacitor.config.json updated:', json.dumps(pl['CapacitorUpdater']))"
if ($LASTEXITCODE -ne 0) { throw "Failed updating capacitor.config.json!" }

Write-Host "`n=== 3. Patching www/index.html (Early notifyAppReady, Deferred Mermaid, Persistent OTA + Force Update Fix) ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

# 3a. Defer mermaid.min.js so 3.18 MB never blocks startup or notifyAppReady()
$h = $h.Replace('<script src="./vendor/mermaid.min.js"></script>', '<script defer src="./vendor/mermaid.min.js"></script>')

# 3b. Fix double-reload bug in any legacy OTA block (up.set() already reloads; calling up.reload() triggers rollback!)
$h = $h -replace 'await\s+up\.set\(bdl\);\s*if\s*\(up\.reload\)\s*await\s+up\.reload\(\);', 'await up.set({ id: bdl.id });'
$h = $h -replace 'if\s*\(up\.reload\)\s*await\s+up\.reload\(\);', '/* reload handled by up.set */'

# 3c. Ensure all OTA endpoints point to Vercel CDN
$h = $h.Replace("https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www", $vercelBase)

# 3d. Bump version labels cleanly to 2.6.2
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"

# 3e. Inject immediate notifyAppReady() at top of <head>
$h = [regex]::Replace($h, '(?s)<!-- LS_OTA_EARLY_READY_START -->.*?<!-- LS_OTA_EARLY_READY_END -->', '')
$earlyReady = @'
<!-- LS_OTA_EARLY_READY_START -->
<script>
(function () {
  // CRITICAL: Confirm bundle boot to @capgo/capacitor-updater immediately so Android never rolls back on restart
  function lsSignalAppReady() {
    try {
      var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
      if (up && typeof up.notifyAppReady === "function") {
        up.notifyAppReady().catch(function () {});
      }
    } catch (e) {}
  }
  lsSignalAppReady();
  setTimeout(lsSignalAppReady, 150);
  document.addEventListener("DOMContentLoaded", lsSignalAppReady);
  window.addEventListener("load", lsSignalAppReady);
})();
</script>
<!-- LS_OTA_EARLY_READY_END -->
'@
if ($h -match '<head[^>]*>') {
  $h = [regex]::Replace($h, '(<head[^>]*>)', ('$1' + "`r`n" + $earlyReady), 1)
}

# 3f. Inject unified persistent OTA & Force Update controller right before </body>
$h = [regex]::Replace($h, '(?s)<!-- LS_PERSISTENT_OTA_START -->.*?<!-- LS_PERSISTENT_OTA_END -->', '')
$otaBlock = @'
<!-- LS_PERSISTENT_OTA_START -->
<script>
(function () {
  var VERCEL_BASE = "https://law-studyes.vercel.app";
  var RAW_FALLBACK = "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www";
  var VK = "law_studyes_ota_version";
  var otaBusy = false;

  function getUpdater() {
    return window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
  }

  function setStatus(msg, realVer) {
    window.__lsOtaLastStatus = msg;
    var st = document.getElementById("lsAccountOtaStatus");
    if (st) st.textContent = msg;
    var el = document.getElementById("lsAccountVerText");
    var bi = (typeof BUILT_IN_VER !== "undefined" ? BUILT_IN_VER : (typeof BUILT_IN !== "undefined" ? BUILT_IN : "2.6.2"));
    if (el && realVer !== undefined) {
      el.textContent = "App v" + bi + " \u00b7 OTA: " + realVer;
    }
    var sideIds = ["lsSidebarOtaStatus", "otaStatusText", "otaStatusBadge", "lsOtaStatus"];
    for (var i = 0; i < sideIds.length; i++) {
      var se = document.getElementById(sideIds[i]);
      if (se) se.textContent = msg;
    }
  }

  async function getNativeRunningVersion(up) {
    try {
      if (up && typeof up.current === "function") {
        var curObj = await up.current();
        var b = curObj && (curObj.bundle || curObj);
        if (b && b.id && b.id !== "builtin" && b.version && b.version !== "builtin") {
          return { id: String(b.id), version: String(b.version), isBuiltin: false };
        }
      }
    } catch (e) {}
    return { id: "builtin", version: "Built-in", isBuiltin: true };
  }

  async function fetchMeta() {
    var ts = Date.now();
    try {
      var r = await fetch(VERCEL_BASE + "/ota-version.json?t=" + ts, { cache: "no-store" });
      if (r.ok) return { meta: await r.json(), base: VERCEL_BASE };
    } catch (e) {}
    var r2 = await fetch(RAW_FALLBACK + "/ota-version.json?t=" + ts, { cache: "no-store" });
    if (!r2.ok) throw new Error("Server HTTP " + r2.status);
    return { meta: await r2.json(), base: RAW_FALLBACK };
  }

  async function runPersistentOta(forceManual) {
    var up = getUpdater();
    if (!up) {
      setStatus("Web mode (OTA runs inside Android APK)", "Web");
      return;
    }
    try { await up.notifyAppReady(); } catch (e) {}
    var running = await getNativeRunningVersion(up);
    // Sync localStorage to REAL native bundle (fixes stale version after rollback or APK reinstall)
    try {
      if (running.isBuiltin) localStorage.removeItem(VK);
      else localStorage.setItem(VK, running.version);
    } catch (e) {}
    setStatus(running.isBuiltin ? "Running Built-in" : ("Active OTA v" + running.version), running.version);

    if (otaBusy) return;
    if (!navigator.onLine) {
      setStatus("Offline (" + running.version + ")", running.version);
      return;
    }

    otaBusy = true;
    try {
      setStatus(forceManual ? "Force checking Vercel..." : "Checking OTA...", running.version);
      var fetched = await fetchMeta();
      var meta = fetched.meta;
      var base = fetched.base;
      if (!meta || !meta.version) throw new Error("Invalid ota-version.json");

      // Only skip if NOT force-updating AND the REAL native bundle already matches server version
      if (!forceManual && !running.isBuiltin && running.version === String(meta.version)) {
        setStatus("Up to date (v" + running.version + ")", running.version);
        return;
      }

      // On Force Update, delete any existing failed/duplicate bundle of the same version first
      var targetVer = String(meta.version);
      if (forceManual && typeof up.list === "function" && typeof up.delete === "function") {
        try {
          var listed = await up.list();
          var bundles = (listed && listed.bundles) ? listed.bundles : [];
          for (var i = 0; i < bundles.length; i++) {
            var bn = bundles[i];
            if (bn && bn.id && bn.id !== "builtin" && bn.id !== running.id && (bn.version === targetVer || bn.status === "error")) {
              try { await up.delete({ id: bn.id }); } catch (de) {}
            }
          }
        } catch (le) {}
      }

      // Unique version suffix on force reinstall if same version is currently running
      var downloadVer = (forceManual && !running.isBuiltin && running.version === targetVer)
        ? (targetVer + "-f" + String(Date.now()).slice(-4))
        : targetVer;

      var zipUrl = (meta.url && meta.url.indexOf("http") === 0)
        ? meta.url
        : (base + "/ota-bundle.zip");
      if (zipUrl.indexOf("raw.githubusercontent.com") !== -1) {
        zipUrl = VERCEL_BASE + "/ota-bundle.zip";
      }
      var sep = zipUrl.indexOf("?") === -1 ? "?" : "&";
      var bustedUrl = zipUrl + sep + "v=" + encodeURIComponent(downloadVer) + "&t=" + Date.now();

      setStatus("Downloading v" + targetVer + "...", running.version);
      var bdl = null;
      try {
        bdl = await up.download({ url: bustedUrl, version: downloadVer });
      } catch (dlErr) {
        var fbUrl = RAW_FALLBACK + "/ota-bundle.zip?v=" + encodeURIComponent(downloadVer) + "&t=" + Date.now();
        bdl = await up.download({ url: fbUrl, version: downloadVer });
      }

      if (!bdl || !bdl.id) {
        throw new Error("Empty bundle returned");
      }

      setStatus("Installing v" + targetVer + "...", targetVer);
      if (typeof showToast === "function") showToast("Applying OTA v" + targetVer + "...");

      // IMPORTANT: Do NOT call up.reload() after up.set()!
      // up.set({ id }) persists the active bundle and reloads the WebView cleanly.
      await up.set({ id: bdl.id });
    } catch (err) {
      var msg = (err && err.message) ? err.message : String(err);
      setStatus("OTA Error: " + msg, running.version);
      if (forceManual && typeof showToast === "function") showToast("OTA Error: " + msg);
    } finally {
      otaBusy = false;
    }
  }

  // Override both global OTA hooks so duplicate scripts cannot race or use stale localStorage
  window.__lsCheckOtaVerbose = function (manual) { return runPersistentOta(!!manual); };
  window.__lsForceOtaUpdate = function () { return runPersistentOta(true); };

  // Intercept any Force Update / Check OTA button clicks in the UI cleanly
  document.addEventListener("click", function (ev) {
    var btn = ev.target && ev.target.closest ? ev.target.closest("button") : null;
    if (!btn) return;
    var id = (btn.id || "").toLowerCase();
    var txt = (btn.textContent || "").toLowerCase();
    if (
      id.indexOf("force") !== -1 ||
      id.indexOf("ota") !== -1 ||
      txt.indexOf("force update") !== -1 ||
      txt.indexOf("check ota") !== -1 ||
      txt.indexOf("check for update") !== -1
    ) {
      if (id === "lszoomclosebtn" || id === "lsmemorypulsebtn") return;
      ev.preventDefault();
      ev.stopImmediatePropagation();
      runPersistentOta(true);
    }
  }, true);

  window.addEventListener("DOMContentLoaded", function () {
    var up = getUpdater();
    if (up) {
      try { up.notifyAppReady(); } catch (e) {}
      getNativeRunningVersion(up).then(function (r) {
        setStatus(r.isBuiltin ? "Built-in ready" : ("OTA v" + r.version + " active"), r.version);
      });
      // Single clean background check 2.5s after launch
      setTimeout(function () { runPersistentOta(false); }, 2500);
    }
  });
})();
</script>
<!-- LS_PERSISTENT_OTA_END -->
</body>
'@
$h = $h.Replace('</body>', $otaBlock)

[System.IO.File]::WriteAllText($idx, $h, $u)

# Verify 0 JS syntax errors across every inline <script> tag
$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_262_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS error(s) found in www/index.html!" }
Write-Host "[PASS] All $i inline JS blocks verified (0 errors)! Early notifyAppReady + Persistent OTA + Force Update wired." -ForegroundColor Green

Write-Host "`n=== 4. Building Clean Bloat-Free Signed Release APK v$ver (versionCode $verCode) ===" -ForegroundColor Cyan
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

# Remove previous APK & OTA zip BEFORE cap sync so zero recursive bloat enters the APK
Remove-Item (Join-Path $root "www\LawStudyes-Offline.apk"), (Join-Path $root "www\ota-bundle.zip") -ErrorAction SilentlyContinue

npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

Push-Location ".\android"
try {
  .\gradlew.bat assembleRelease
  if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
} finally {
  Pop-Location
}

$apk = ".\android\app\build\outputs\apk\release\app-release.apk"
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-FixedOTA-Diagrams.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 5. Pushing Verified Full-Diagram OTA Bundle + Clean APK to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
