<#
.SYNOPSIS
  Law Studyes v2.6.8 - Fixes Selfie Camera & Gallery Upload (Native @capacitor/camera),
  Fixes Auto-OTA on App Restart & Resume, and Fixes Version Display on Registration Screen!
  1. Installs @capacitor/camera matching your @capacitor/core major version.
  2. Adds READ_MEDIA_IMAGES, READ_EXTERNAL_STORAGE & CAMERA permissions to AndroidManifest.xml.
  3. Upgrades www/index.html:
     - Native Camera.getPhoto() for Take Selfie (front camera) & Upload Gallery (Android Photos)
     - Auto-OTA check on cold start, app restart, and background resume (works on Registration screen too!)
     - Live top OTA banner + accurate v2.6.8 version pill on Registration/Login card
  4. Builds clean signed release APK v2.6.8 (versionCode 268) and pushes verified OTA to GitHub & Vercel.
.USAGE
  Run in C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Fix-LawStudyes-v2.6.8-Camera-AutoOTA-APK.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.8"
$verCode = 268

Write-Host "`n=== 1. Installing Native @capacitor/camera Plugin (Fixes Selfie & Gallery on Android) ===" -ForegroundColor Cyan
$capMajor = python -c "import json,re,pathlib; p=pathlib.Path('package.json'); d=json.loads(p.read_text(encoding='utf-8')); v=(d.get('dependencies',{}).get('@capacitor/core') or d.get('devDependencies',{}).get('@capacitor/core') or '6'); m=re.search(r'(\d+)',v); print(m.group(1) if m else '6')"
$capMajor = $capMajor.Trim()
Write-Host "[INFO] Detected Capacitor major v$capMajor -> installing @capacitor/camera@$capMajor..." -ForegroundColor Yellow
npm install "@capacitor/camera@$capMajor" --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "npm install @capacitor/camera@$capMajor failed!" }
Write-Host "[OK] @capacitor/camera@$capMajor installed!" -ForegroundColor Green

Write-Host "`n=== 2. Ensuring Camera & Gallery Permissions in AndroidManifest.xml ===" -ForegroundColor Cyan
$manifestPath = Join-Path $root "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifestPath) {
  $mTxt = [System.IO.File]::ReadAllText($manifestPath, $u)
  $needed = @(
    '<uses-permission android:name="android.permission.CAMERA" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />'
  )
  $toAdd = ""
  foreach ($perm in $needed) {
    $key = ([regex]::Match($perm, 'android\.permission\.[A-Z_]+')).Value
    if ($mTxt -notmatch [regex]::Escape($key)) {
      $toAdd += "    $perm`r`n"
    }
  }
  if ($toAdd) {
    $mTxt = $mTxt -replace '(<uses-permission\s+android:name="android\.permission\.INTERNET"\s*/>)', ("`$1`r`n" + $toAdd)
    [System.IO.File]::WriteAllText($manifestPath, $mTxt, $u)
    Write-Host "[OK] Added missing Camera/Gallery permissions to AndroidManifest.xml" -ForegroundColor Green
  } else {
    Write-Host "[OK] Camera & Gallery permissions already present in AndroidManifest.xml" -ForegroundColor Green
  }
}

Write-Host "`n=== 3. Patching www/index.html (Native Camera + Auto-OTA on Restart/Resume + Version v$ver) ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

# Bump all version constants cleanly to 2.6.8
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$ver`";"

# Replace LS_PERSISTENT_OTA block with upgraded Auto-OTA + Native Camera handler
$h = [regex]::Replace($h, '(?s)<!-- LS_PERSISTENT_OTA_START -->.*?<!-- LS_PERSISTENT_OTA_END -->', '')
$otaCamBlock = @'
<!-- LS_PERSISTENT_OTA_START -->
<style>
  #lsOtaTopBanner {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 10050;
    background: #7B1E2B;
    color: #FAF7F2;
    font-size: 12px;
    font-weight: 700;
    padding: 8px 14px;
    display: none;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    box-shadow: 0 3px 12px rgba(0,0,0,0.22);
  }
  #lsOtaTopBanner.show { display: flex; }
  .ls-reg-ver-pill {
    margin-top: 8px;
    padding: 5px 10px;
    border-radius: 9999px;
    background: #FAF7F2;
    border: 1px solid #E8E0D5;
    color: #5F554E;
    font-size: 11px;
    font-weight: 700;
    text-align: center;
  }
</style>
<div id="lsOtaTopBanner">
  <span id="lsOtaBannerText">Checking for updates...</span>
  <button id="lsOtaBannerClose" type="button" style="background:rgba(255,255,255,0.2);border:none;color:#fff;border-radius:6px;padding:2px 8px;font-weight:700;cursor:pointer;">&times;</button>
</div>
<script>
(function () {
  var VERCEL_BASE = "https://law-studyes.vercel.app";
  var RAW_FALLBACK = "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www";
  var VK = "law_studyes_ota_version";
  var CURRENT_APP_VER = "2.6.8";
  var otaBusy = false;
  var lastCheckMs = 0;

  function getUpdater() {
    return window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
  }

  function showBanner(msg, autoHideMs) {
    var b = document.getElementById("lsOtaTopBanner");
    var t = document.getElementById("lsOtaBannerText");
    if (!b || !t) return;
    t.textContent = msg;
    b.classList.add("show");
    if (window.__lsBannerTimer) clearTimeout(window.__lsBannerTimer);
    if (autoHideMs && autoHideMs > 0) {
      window.__lsBannerTimer = setTimeout(function () { b.classList.remove("show"); }, autoHideMs);
    }
  }

  function hideBanner() {
    var b = document.getElementById("lsOtaTopBanner");
    if (b) b.classList.remove("show");
  }

  function setStatus(msg, realVer) {
    window.__lsOtaLastStatus = msg;
    var st = document.getElementById("lsAccountOtaStatus");
    if (st) st.textContent = msg;
    var el = document.getElementById("lsAccountVerText");
    var verLabel = "App v" + CURRENT_APP_VER + " \u00b7 OTA: " + (realVer || "Built-in");
    if (el && realVer !== undefined) el.textContent = verLabel;

    // Also keep a live version pill synced inside the Registration/Login overlay
    var ov = document.getElementById("lawStudyesAuthOverlay");
    if (ov) {
      var pill = ov.querySelector("#lsRegVerPill");
      if (!pill) {
        var card = ov.querySelector("form") ? ov.querySelector("form").parentElement : ov.firstElementChild;
        if (card) {
          pill = document.createElement("div");
          pill.id = "lsRegVerPill";
          pill.className = "ls-reg-ver-pill";
          card.appendChild(pill);
        }
      }
      if (pill) pill.textContent = verLabel + " (" + msg + ")";
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
      setStatus("Web mode", "Web");
      return;
    }
    try { await up.notifyAppReady(); } catch (e) {}
    var running = await getNativeRunningVersion(up);
    try {
      if (running.isBuiltin) localStorage.removeItem(VK);
      else localStorage.setItem(VK, running.version);
    } catch (e) {}

    if (otaBusy) return;
    if (!forceManual && (Date.now() - lastCheckMs) < 12000) {
      setStatus(running.isBuiltin ? "Built-in" : ("Active v" + running.version), running.version);
      return;
    }
    if (!navigator.onLine) {
      setStatus("Offline (" + running.version + ")", running.version);
      return;
    }

    otaBusy = true;
    lastCheckMs = Date.now();
    try {
      setStatus(forceManual ? "Force checking Vercel..." : "Checking OTA...", running.version);
      if (forceManual) showBanner("Checking Law Studyes OTA update...", 0);

      var fetched = await fetchMeta();
      var meta = fetched.meta;
      var base = fetched.base;
      if (!meta || !meta.version) throw new Error("Invalid ota-version.json");

      var targetVer = String(meta.version);
      if (!forceManual && !running.isBuiltin && running.version === targetVer) {
        setStatus("Up to date (v" + running.version + ")", running.version);
        hideBanner();
        return;
      }

      // Clean any old failed/duplicate bundles for this version
      if (typeof up.list === "function" && typeof up.delete === "function") {
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

      var downloadVer = (forceManual && !running.isBuiltin && running.version === targetVer)
        ? (targetVer + "-f" + String(Date.now()).slice(-4))
        : targetVer;

      var zipUrl = (meta.url && meta.url.indexOf("http") === 0) ? meta.url : (base + "/ota-bundle.zip");
      if (zipUrl.indexOf("raw.githubusercontent.com") !== -1) zipUrl = VERCEL_BASE + "/ota-bundle.zip";
      var sep = zipUrl.indexOf("?") === -1 ? "?" : "&";
      var bustedUrl = zipUrl + sep + "v=" + encodeURIComponent(downloadVer) + "&t=" + Date.now();

      setStatus("Downloading v" + targetVer + "...", running.version);
      showBanner("Downloading Law Studyes update v" + targetVer + "...", 0);

      var bdl = null;
      try {
        bdl = await up.download({ url: bustedUrl, version: downloadVer });
      } catch (dlErr) {
        var fbUrl = RAW_FALLBACK + "/ota-bundle.zip?v=" + encodeURIComponent(downloadVer) + "&t=" + Date.now();
        bdl = await up.download({ url: fbUrl, version: downloadVer });
      }

      if (!bdl || !bdl.id) throw new Error("Empty bundle returned");

      setStatus("Applying v" + targetVer + "...", targetVer);
      showBanner("Installing update v" + targetVer + " & restarting...", 0);
      try { localStorage.setItem(VK, downloadVer); } catch (e) {}

      // Persist & reload cleanly into the new bundle
      await up.set({ id: bdl.id });
    } catch (err) {
      var msg = (err && err.message) ? err.message : String(err);
      setStatus("OTA Error: " + msg, running.version);
      if (forceManual) showBanner("OTA Error: " + msg, 5000);
      else hideBanner();
    } finally {
      otaBusy = false;
    }
  }

  window.__lsCheckOtaVerbose = function (manual) { return runPersistentOta(!!manual); };
  window.__lsForceOtaUpdate = function () { return runPersistentOta(true); };

  // Native Android Camera + Gallery handler using @capacitor/camera (with web file-input fallback)
  window.__lsPickStudentPhoto = async function (mode) {
    var cam = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Camera;
    if (cam && typeof cam.getPhoto === "function") {
      try {
        var res = await cam.getPhoto({
          quality: 75,
          width: 360,
          height: 360,
          allowEditing: false,
          resultType: "dataUrl",
          source: mode === "camera" ? "CAMERA" : "PHOTOS",
          direction: "FRONT",
          correctOrientation: true
        });
        if (res && res.dataUrl) {
          window.__lsRegPhotoBase64 = res.dataUrl;
          var prev = document.getElementById("lsPhotoPreview");
          var hint = document.getElementById("lsPhotoHint");
          if (prev) prev.innerHTML = '<img src="' + res.dataUrl + '" alt="Student Photo" />';
          if (hint) {
            var kb = Math.round((res.dataUrl.length * 3) / 4 / 1024);
            hint.textContent = "Photo ready (" + kb + " KB) - will save to Sheet";
          }
          return true;
        }
      } catch (err) {
        var em = (err && err.message) ? err.message : String(err);
        if (/cancel/i.test(em)) return false;
        var h2 = document.getElementById("lsPhotoHint");
        if (h2) h2.textContent = "Camera error: " + em;
        return false;
      }
    }
    return false;
  };

  // Capture-phase click handler for Selfie/Gallery buttons (uses native Capacitor Camera on Android)
  document.addEventListener("click", function (ev) {
    var btn = ev.target && ev.target.closest ? ev.target.closest("button") : null;
    if (!btn) return;
    var id = (btn.id || "");
    if (id === "lsOtaBannerClose") { hideBanner(); return; }
    if (id === "lsSelfieBtn" || id === "lsGalleryBtn") {
      var cam = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Camera;
      if (cam && typeof cam.getPhoto === "function") {
        ev.preventDefault();
        ev.stopImmediatePropagation();
        window.__lsPickStudentPhoto(id === "lsSelfieBtn" ? "camera" : "gallery");
      }
      return;
    }
    var lowId = id.toLowerCase();
    var txt = (btn.textContent || "").toLowerCase();
    if (
      lowId.indexOf("force") !== -1 ||
      lowId.indexOf("ota") !== -1 ||
      txt.indexOf("force update") !== -1 ||
      txt.indexOf("check ota") !== -1 ||
      txt.indexOf("check for update") !== -1
    ) {
      if (lowId === "lszoomclosebtn" || lowId === "lsmemorypulsebtn" || lowId === "lsotabannerclose") return;
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
        setStatus(r.isBuiltin ? "Built-in ready" : ("Active v" + r.version), r.version);
      });
      // Auto-check on cold launch (works even on Registration/Login screen!)
      setTimeout(function () { runPersistentOta(false); }, 1500);

      // Auto-check whenever app is resumed from background
      document.addEventListener("visibilitychange", function () {
        if (document.visibilityState === "visible") {
          setTimeout(function () { runPersistentOta(false); }, 800);
        }
      });
      var capApp = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.App;
      if (capApp && typeof capApp.addListener === "function") {
        try {
          capApp.addListener("appStateChange", function (state) {
            if (state && state.isActive) {
              setTimeout(function () { runPersistentOta(false); }, 800);
            }
          });
        } catch (ae) {}
      }
    }
  });
})();
</script>
<!-- LS_PERSISTENT_OTA_END -->
'@
$h = $h.Replace('</body>', ($otaCamBlock + "`r`n</body>"))
[System.IO.File]::WriteAllText($idx, $h, $u)

# Verify 0 JS syntax errors across every inline <script> tag
$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_268_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS error(s) found in www/index.html!" }
Write-Host "[PASS] All $i inline JS blocks verified (0 errors)!" -ForegroundColor Green

Write-Host "`n=== 4. Building Clean Signed Release APK v$ver (versionCode $verCode) ===" -ForegroundColor Cyan
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

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
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-Camera-AutoOTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 5. Pushing Verified OTA Bundle + APK to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
