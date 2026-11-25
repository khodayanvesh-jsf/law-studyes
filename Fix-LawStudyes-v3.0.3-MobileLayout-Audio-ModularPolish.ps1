<#
.SYNOPSIS
  Law Studyes v3.0.3 - Fixes Mobile Layout Overlap (Bottom Nav vs Audio Bar),
  Hides Course Filter & Audio Bar on Modular Tabs (Study Hub, Judgments, Exam Drill, My Shelf),
  Fixes Header Title Truncation ("Law St" -> "Law Studyes"),
  Fixes Play/Pause Button ("No offline note text to read" error),
  and Pushes Verified Forward-Slash OTA v3.0.3 to GitHub & Vercel!
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Fix-LawStudyes-v3.0.3-MobileLayout-Audio-ModularPolish.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "3.0.3"

Write-Host "`n=== 1. Updating www/js/modules/ls-nav.js (Fixes Overlap, Header Truncation & Tab Isolation) ===" -ForegroundColor Cyan
$navPath = Join-Path $root "www\js\modules\ls-nav.js"
$navCode = @'
(function () {
  "use strict";
  if (window.__lsModularNavV303) return;
  window.__lsModularNavV303 = true;

  var activeTab = "library";

  function injectMobileShell() {
    var oldStyle = document.getElementById("lsModularNavStyle");
    if (oldStyle) oldStyle.remove();

    var style = document.createElement("style");
    style.id = "lsModularNavStyle";
    style.textContent =
      "body { padding-bottom: 64px !important; }" +
      "main { padding-bottom: 132px !important; }" +
      /* Lift any fixed bottom audio bar cleanly above the 60px bottom nav */
      ".fixed.bottom-0:not(#lsBottomNav):not(#lsMoreSheet), #audioPlayerBar, #floatingAudioBar, [id*='audioBar' i], [id*='playerBar' i] { bottom: 60px !important; z-index: 80 !important; }" +
      /* Prevent top header brand title from truncating to 'Law St' on narrow mobile screens */
      "header h1, header .brand-title, header [class*='font-bold'] { white-space: nowrap !important; }" +
      "@media (max-width: 480px) { header { gap: 4px !important; padding-left: 8px !important; padding-right: 8px !important; } header button, header a { padding-left: 6px !important; padding-right: 6px !important; font-size: 11px !important; } }" +
      /* Hide Library-only filter/audio chrome when viewing modular hubs */
      "body.ls-in-module main, body.ls-in-module #audioPlayerBar, body.ls-in-module #floatingAudioBar, body.ls-in-module .fixed.bottom-0:not(#lsBottomNav):not(#lsMoreSheet), body.ls-in-module [data-ls-library-only='1'] { display: none !important; }" +
      "#lsModularStage { display:none; padding: 12px 14px 82px; max-width: 900px; margin: 0 auto; }" +
      "#lsModularStage.active { display:block; }" +
      "#lsBottomNav { position:fixed; bottom:0; left:0; right:0; z-index:95; background:#FFFFFF; border-top:1px solid #E8E0D5; display:grid; grid-template-columns:repeat(5,1fr); height:60px; box-shadow:0 -4px 16px rgba(31,27,24,0.08); }" +
      ".ls-nav-btn { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:2px; font-size:10.5px; font-weight:700; color:#5F554E; border:none; background:transparent; cursor:pointer; }" +
      ".ls-nav-btn.active { color:#7B1E2B; }" +
      ".ls-nav-btn.active .ls-nav-dot { width:20px; height:3px; border-radius:99px; background:#7B1E2B; margin-bottom:2px; }" +
      "#lsMoreSheet { position:fixed; inset:0; z-index:140; background:rgba(0,0,0,0.45); display:none; align-items:flex-end; justify-content:center; }" +
      "#lsMoreSheet.show { display:flex; }" +
      "#lsMoreCard { background:#FFFFFF; width:100%; max-width:540px; border-radius:22px 22px 0 0; padding:18px 16px 26px; box-shadow:0 -8px 30px rgba(0,0,0,0.18); }";
    document.head.appendChild(style);

    // Tag Library-specific course filter & sub-unit audio bars so they auto-hide on non-Library tabs
    setTimeout(function () {
      document.querySelectorAll("div, section").forEach(function (el) {
        if (el.id === "lsModularStage" || el.id === "lsBottomNav" || el.id === "lsMoreSheet") return;
        var txt = (el.textContent || "");
        if (txt.indexOf("COURSE FILTER") !== -1 && txt.indexOf("Sub-Unit Audio") !== -1 && el.children.length <= 6 && el.offsetHeight < 260) {
          el.setAttribute("data-ls-library-only", "1");
        }
      });
    }, 300);

    if (document.getElementById("lsBottomNav")) return;

    var stage = document.createElement("div");
    stage.id = "lsModularStage";
    var mainHost = document.querySelector("main") || document.body;
    if (mainHost && mainHost.parentNode && mainHost !== document.body) {
      mainHost.parentNode.insertBefore(stage, mainHost);
    } else {
      document.body.appendChild(stage);
    }

    var nav = document.createElement("nav");
    nav.id = "lsBottomNav";
    nav.innerHTML =
      '<button type="button" class="ls-nav-btn" data-ls-nav="hub"><span class="ls-nav-dot"></span><span>Study Hub</span></button>' +
      '<button type="button" class="ls-nav-btn active" data-ls-nav="library"><span class="ls-nav-dot"></span><span>Library</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="judgments"><span class="ls-nav-dot"></span><span>Judgments</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="drill"><span class="ls-nav-dot"></span><span>Exam Drill</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="more"><span class="ls-nav-dot"></span><span>More</span></button>';
    document.body.appendChild(nav);

    var sheet = document.createElement("div");
    sheet.id = "lsMoreSheet";
    sheet.innerHTML =
      '<div id="lsMoreCard">' +
        '<div class="flex items-center justify-between mb-3">' +
          '<div class="text-sm font-bold text-[#7B1E2B]">Law Studyes Tools</div>' +
          '<button type="button" id="lsMoreClose" class="text-xs font-bold px-2.5 py-1 rounded-lg bg-[#FAF7F2] text-[#5F554E]">Close</button>' +
        '</div>' +
        '<div class="grid grid-cols-2 gap-2.5">' +
          '<button type="button" data-ls-nav="viva" class="p-3 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">Viva &amp; Exam Bank</div><div class="text-[10.5px] text-[#5F554E]">Short &amp; Long Q&amp;A</div></button>' +
          '<button type="button" data-ls-nav="lexicon" class="p-3 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">Lexicon &amp; Maxims</div><div class="text-[10.5px] text-[#5F554E]">Legal Terms &amp; Latin</div></button>' +
          '<button type="button" data-ls-nav="shelf" class="p-3 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">My Shelf</div><div class="text-[10.5px] text-[#5F554E]">Saved Bookmarks</div></button>' +
          '<button type="button" id="lsMoreForceOta" class="p-3 rounded-xl border border-[#7B1E2B] bg-[#FBF1F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">Check Live Sync</div><div class="text-[10.5px] text-[#5F554E]">Pull Latest OTA</div></button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(sheet);

    sheet.addEventListener("click", function (ev) {
      if (ev.target === sheet || ev.target.id === "lsMoreClose") sheet.classList.remove("show");
    });
    var otaBtn = sheet.querySelector("#lsMoreForceOta");
    if (otaBtn) otaBtn.addEventListener("click", async function () {
      sheet.classList.remove("show");
      var hasCap = !!(window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater);
      if (hasCap && typeof window.__lsForceOtaUpdate === "function") {
        window.__lsForceOtaUpdate();
      } else {
        try {
          var r = await fetch("https://law-studyes.vercel.app/ota-version.json?t=" + Date.now(), { cache: "no-store" });
          var m = await r.json();
          if (typeof showToast === "function") showToast("Live Vercel OTA: v" + (m.version || "ready"));
        } catch (e) {
          if (typeof showToast === "function") showToast("Offline mode - using local bundle.");
        }
      }
    });
  }

  function setActiveNavHighlight(tab) {
    document.querySelectorAll("#lsBottomNav .ls-nav-btn").forEach(function (b) {
      var t = b.getAttribute("data-ls-nav");
      var isMoreChild = (tab === "viva" || tab === "lexicon" || tab === "shelf");
      b.classList.toggle("active", t === tab || (t === "more" && isMoreChild));
    });
  }

  function openTab(tab) {
    var sheet = document.getElementById("lsMoreSheet");
    if (tab === "more") {
      if (sheet) sheet.classList.add("show");
      return;
    }
    if (sheet) sheet.classList.remove("show");
    activeTab = tab;
    setActiveNavHighlight(tab);

    var stage = document.getElementById("lsModularStage");
    if (!stage) return;

    if (tab === "library") {
      document.body.classList.remove("ls-in-module");
      stage.classList.remove("active");
      return;
    }

    document.body.classList.add("ls-in-module");
    stage.classList.add("active");
    window.scrollTo(0, 0);

    if (tab === "hub" && window.LSHub) window.LSHub.render(stage);
    else if (tab === "judgments" && window.LSJudgments) window.LSJudgments.render(stage);
    else if (tab === "drill" && window.LSDrill) window.LSDrill.render(stage);
    else if (tab === "viva" && window.LSVault) window.LSVault.renderViva(stage);
    else if (tab === "lexicon" && window.LSVault) window.LSVault.renderLexicon(stage);
    else if (tab === "shelf" && window.LSVault) window.LSVault.renderShelf(stage);
  }

  document.addEventListener("click", function (ev) {
    var navEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-nav]") : null;
    if (navEl) {
      openTab(navEl.getAttribute("data-ls-nav"));
      return;
    }
    var topicEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-open-topic]") : null;
    if (topicEl) {
      var tid = topicEl.getAttribute("data-ls-open-topic");
      openTab("library");
      if (typeof state !== "undefined" && tid) {
        state.activeTopicId = tid;
        if (typeof window.renderReadingPane === "function") window.renderReadingPane();
      }
      return;
    }
    var subjEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-open-subject]") : null;
    if (subjEl) {
      var sid = subjEl.getAttribute("data-ls-open-subject");
      openTab("library");
      if (typeof state !== "undefined" && sid) {
        state.activeSubjectId = sid;
        if (typeof window.renderSidebar === "function") window.renderSidebar();
        var subj = (state.subjects || []).find(function (s) { return s.id === sid; });
        if (subj && subj.units && subj.units[0] && subj.units[0].topics && subj.units[0].topics[0]) {
          state.activeTopicId = subj.units[0].topics[0].id;
          if (typeof window.renderReadingPane === "function") window.renderReadingPane();
        }
      }
      return;
    }
    var shelfEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-shelf-id]") : null;
    if (shelfEl && window.LSStore) {
      var saved = window.LSStore.toggleShelf({
        id: shelfEl.getAttribute("data-ls-shelf-id"),
        title: shelfEl.getAttribute("data-ls-shelf-title"),
        subtitle: shelfEl.getAttribute("data-ls-shelf-sub") || ""
      });
      if (activeTab === "shelf") openTab("shelf");
      else {
        shelfEl.textContent = saved ? "Saved" : "Save";
        shelfEl.className = "text-[11px] px-2 py-0.5 rounded-full border border-[#7B1E2B] " + (saved ? "bg-[#7B1E2B] text-white" : "text-[#7B1E2B]");
      }
    }
  });

  window.addEventListener("DOMContentLoaded", function () {
    injectMobileShell();
    setTimeout(function () {
      if (typeof window.renderReadingPane === "function" && !window.__lsProgressHooked) {
        window.__lsProgressHooked = true;
        var origR = window.renderReadingPane;
        window.renderReadingPane = function () {
          var res = origR.apply(this, arguments);
          try {
            if (typeof state !== "undefined" && state.activeTopicId && window.LSStore) {
              var rec = state.notes && state.notes[state.activeTopicId];
              window.LSStore.markTopicRead(state.activeTopicId, (rec && rec.subtitle) || state.activeTopicId);
            }
          } catch (e) {}
          return res;
        };
      }
    }, 500);
  });

  window.LSNav = { openTab: openTab };
})();

'@
[System.IO.File]::WriteAllText($navPath, $navCode, $u)
$err = node --check $navPath 2>&1
if ($LASTEXITCODE -ne 0) { throw "ls-nav.js syntax error: $err" }
Write-Host "[PASS] www/js/modules/ls-nav.js verified (0 errors)!" -ForegroundColor Green

Write-Host "`n=== 2. Patching www/index.html (Play/Pause Catch + Version v$ver) ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', "var CURRENT_APP_VER = `"$ver`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$ver`";"
$h = $h -replace '\?v=3\.0\.0"', "?v=$ver`""

$h = [regex]::Replace($h, '(?s)<!-- LS_TTS_PLAY_CATCH_V303_START -->.*?<!-- LS_TTS_PLAY_CATCH_V303_END -->', '')
$ttsCatch = @'
<!-- LS_TTS_PLAY_CATCH_V303_START -->
<script>
(function () {
  if (window.__lsTtsCatchV303) return;
  window.__lsTtsCatchV303 = true;

  function extractActiveNoteTextFallback() {
    // 1. Try visible #readingPane first
    var pane = document.getElementById("readingPane");
    if (pane && pane.offsetParent !== null) {
      var cl = pane.cloneNode(true);
      cl.querySelectorAll("script,style,svg,button,#lsVisualDiagramsSection,.ls-visual-card,.mermaid").forEach(function (e) { e.remove(); });
      var t = (cl.innerText || cl.textContent || "").replace(/\s+/g, " ").trim();
      if (t.length > 20) return t;
    }
    // 2. Fall back directly to state.notes[state.activeTopicId] so Play works even before DOM sync
    if (typeof state !== "undefined" && state && state.notes) {
      var tid = state.activeTopicId || Object.keys(state.notes)[0];
      var rec = tid ? state.notes[tid] : null;
      var lang = (state.lang === "te" && rec && rec.te) ? "te" : "en";
      var ld = rec && rec[lang] ? rec[lang] : (rec && rec.en ? rec.en : null);
      if (ld) {
        var parts = [];
        if (ld.title) parts.push(ld.title);
        if (ld.overview) parts.push(ld.overview);
        if (Array.isArray(ld.sections)) {
          ld.sections.forEach(function (s) {
            if (s.heading) parts.push(s.heading);
            if (s.content) parts.push(String(s.content).replace(/<[^>]+>/g, " "));
          });
        }
        return parts.join(". ").replace(/\s+/g, " ").trim();
      }
    }
    return "";
  }

  document.addEventListener("click", function (ev) {
    var btn = ev.target && ev.target.closest ? ev.target.closest("button") : null;
    if (!btn) return;
    var txt = (btn.textContent || "").replace(/\s+/g, " ").trim();
    if (/^(Play|Pause|Resume)$/i.test(txt) || btn.id === "btnPlayPause" || btn.id === "audioPlayBtn") {
      ev.preventDefault();
      ev.stopImmediatePropagation();
      if (typeof window.toggleAudio === "function") {
        if (/^Play$/i.test(txt) && typeof window.playAudio === "function") {
          var noteTxt = extractActiveNoteTextFallback();
          if (noteTxt) {
            window.playAudio(noteTxt);
            return;
          }
        }
        window.toggleAudio();
      }
    }
  }, true);
})();
</script>
<!-- LS_TTS_PLAY_CATCH_V303_END -->
'@
$h = $h.Replace('</body>', ($ttsCatch + "`r`n</body>"))
[System.IO.File]::WriteAllText($idx, $h, $u)
Write-Host "[PASS] www/index.html updated to v$ver!" -ForegroundColor Green

Write-Host "`n=== 3. Packing Forward-Slash OTA Bundle v$ver & Pushing to GitHub + Vercel ===" -ForegroundColor Cyan
$pyBuild = @'
import hashlib, json, zipfile
from datetime import datetime, timezone
from pathlib import Path

www = Path("www")
zp = www / "ota-bundle.zip"
exclude = {"ota-bundle.zip", "ota-version.json", "ota-manifest.json", "LawStudyes-Offline.apk"}

with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for p in sorted(www.rglob("*")):
        if p.is_file() and p.name not in exclude:
            zf.write(p, p.relative_to(www).as_posix())

ver = "3.0.3." + datetime.now(timezone.utc).strftime("%Y%m%d%H%M")
iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
sha = hashlib.sha256(zp.read_bytes()).hexdigest().lower()
sz = zp.stat().st_size
url = "https://law-studyes.vercel.app/ota-bundle.zip"

(www / "ota-version.json").write_text(json.dumps({
    "version": ver, "url": url, "sha256": sha, "sizeBytes": sz, "updatedAt": iso
}, indent=2), encoding="utf-8")

(www / "ota-manifest.json").write_text(json.dumps({
    "app": "Law Studyes", "version": ver, "bundle": "ota-bundle.zip",
    "url": url, "sha256": sha, "sizeBytes": sz, "updatedAt": iso
}, indent=2), encoding="utf-8")

print(f"[BUILT] v{ver} | {round(sz / 1048576, 2)} MB | SHA={sha[:16]}")
'@
$pyBuildPath = Join-Path $env:TEMP "ls_build_ota_303.py"
[System.IO.File]::WriteAllText($pyBuildPath, $pyBuild, $u)
python $pyBuildPath
if ($LASTEXITCODE -ne 0) { throw "Python OTA builder failed!" }

git add www/index.html www/js/modules/ls-nav.js www/ota-bundle.zip www/ota-version.json www/ota-manifest.json
git commit -m "OTA v3.0.3 - Fix mobile layout overlap, header truncation, tab isolation & Play/Pause TTS"
git push origin main

Write-Host "`n[WAIT] Waiting 30s for Vercel CDN to publish v3.0.3..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$liveMeta = (Invoke-WebRequest "https://law-studyes.vercel.app/ota-version.json?t=$ts" -UseBasicParsing -TimeoutSec 25).Content | ConvertFrom-Json
Write-Host ("[SUCCESS] Live Vercel OTA ready: " + $liveMeta.version + " | SHA=" + $liveMeta.sha256.Substring(0,16)) -ForegroundColor Green
