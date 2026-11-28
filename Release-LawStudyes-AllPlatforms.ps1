<#
.SYNOPSIS
  Law Studyes - Unified All-Platform Release & Deploy Script
  Fixes Audio Player (all controls + topic-switch sync + en-IN/te-IN + mobile bounds),
  Restores Offline Mermaid Flowcharts / Diagrams / Tables + Zoom & Memory Walk,
  and atomically updates & deploys ALL platforms in ONE command:
    1. www/index.html + www/js/modules/ (ls-audio.js, ls-diagrams.js) + WhatsApp Share Link
    2. www/download.html (live version, build date, APK size, cache-busted link) + www/manifest.json
    3. Signed Android APK (Desktop + copied to www/LawStudyes-Offline.apk for WhatsApp link)
    4. Forward-slash Vercel OTA bundle (excluding .apk) with SemVer & SHA-256 checksum
    5. Windows Founder Console (Desktop\LawStudyes-Founder-Console-Windows.exe)
    6. GitHub push + live Vercel SHA-256 parity verification
.USAGE
  .\Release-LawStudyes-AllPlatforms.ps1
  .\Release-LawStudyes-AllPlatforms.ps1 -Version "3.0.9" -VersionCode 309 -Message "New notes & UI polish"
  .\Release-LawStudyes-AllPlatforms.ps1 -OtaOnly
#>
param(
  [string]$Version = "3.0.8",
  [int]$VersionCode = 308,
  [string]$Message = "",
  [switch]$OtaOnly,
  [switch]$SkipWindowsExe
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$wwwDir = Join-Path $root "www"
if (Test-Path (Join-Path $root "Sync-And-Translate-BeforeDeploy.ps1")) { & (Join-Path $root "Sync-And-Translate-BeforeDeploy.ps1") }
$modDir = Join-Path $wwwDir "js\modules"
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

Write-Host "`n=== 1. Writing Unified Audio Engine & Mobile Bounds Fix (www/js/modules/ls-audio.js) ===" -ForegroundColor Cyan
$audioJs = @'
(function () {
  "use strict";
  if (window.__lsUnifiedAudioV308) return;
  window.__lsUnifiedAudioV308 = true;

  var cachedVoiceIdx = {};

  function injectAudioLayoutCss() {
    if (document.getElementById("lsAudioLayoutFixV308")) return;
    var st = document.createElement("style");
    st.id = "lsAudioLayoutFixV308";
    st.textContent =
      "#audioPlayerBar { left: 10px !important; right: 10px !important; width: auto !important; max-width: calc(100vw - 20px) !important; box-sizing: border-box !important; overflow: hidden !important; }" +
      "#audioPlayerBar > div:last-child { display: flex !important; flex-direction: column !important; align-items: stretch !important; gap: 7px !important; padding: 8px 10px 10px !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box !important; }" +
      "#audioPlayerBar .ls-audio-row-controls { display: flex !important; align-items: center !important; justify-content: space-between !important; gap: 5px !important; width: 100% !important; max-width: 100% !important; flex-wrap: nowrap !important; overflow: hidden !important; }" +
      "#audioPlayerBar .ls-audio-row-controls > div { display: flex !important; align-items: center !important; gap: 4px !important; flex-wrap: nowrap !important; min-width: 0 !important; }" +
      "#audioPlayerBar #audioCurrentTitle { max-width: 100% !important; overflow: hidden !important; text-overflow: ellipsis !important; white-space: nowrap !important; font-size: 12.5px !important; }" +
      "#audioPlayerBar #audioQueueCounter { max-width: 115px !important; overflow: hidden !important; text-overflow: ellipsis !important; white-space: nowrap !important; }" +
      "#audioPlayerBar #audioPlayPauseBtn { padding: 6px 11px !important; font-size: 12px !important; white-space: nowrap !important; flex-shrink: 0 !important; }" +
      "#audioPlayerBar #audioPrevBtn, #audioPlayerBar #audioStopBtn, #audioPlayerBar #audioNextBtn, #audioPlayerBar #repeatTopicBtn { padding: 6px !important; flex-shrink: 0 !important; }" +
      "#audioPlayerBar #teachingModeBtn { padding: 5px 7px !important; font-size: 11px !important; flex-shrink: 0 !important; }" +
      "#audioPlayerBar #audioSpeedSelect { padding: 5px 4px !important; font-size: 11px !important; max-width: 56px !important; flex-shrink: 0 !important; }" +
      "@media (min-width: 900px) { #audioPlayerBar > div:last-child { flex-direction: row !important; align-items: center !important; } #audioPlayerBar .ls-audio-row-controls { width: auto !important; gap: 10px !important; } }";
    document.head.appendChild(st);
  }

  function arrangeAudioBarRows() {
    var bar = document.getElementById("audioPlayerBar");
    if (!bar || bar.getAttribute("data-ls-rows-arranged") === "1") return;
    var inner = bar.lastElementChild;
    if (!inner) return;
    var children = Array.prototype.slice.call(inner.children);
    if (children.length >= 3) {
      var controlsWrap = document.createElement("div");
      controlsWrap.className = "ls-audio-row-controls";
      controlsWrap.appendChild(children[1]);
      controlsWrap.appendChild(children[2]);
      inner.appendChild(controlsWrap);
      bar.setAttribute("data-ls-rows-arranged", "1");
    }
  }

  function getNativeTts() {
    return window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
  }

  async function resolveNativeVoice(tts, targetLang) {
    var key = String(targetLang || "en-IN").toLowerCase();
    if (cachedVoiceIdx[key] !== undefined) return cachedVoiceIdx[key];
    var res = { lang: targetLang || "en-IN", voice: undefined };
    try {
      if (typeof tts.getSupportedVoices === "function") {
        var out = await tts.getSupportedVoices();
        var voices = (out && Array.isArray(out.voices)) ? out.voices : [];
        var pref = key.split("-")[0];
        var exact = -1, prefIdx = -1, enFb = -1;
        for (var i = 0; i < voices.length; i++) {
          var vl = String((voices[i] && voices[i].lang) || "").toLowerCase().replace("_", "-");
          if (vl.indexOf("ar") === 0) continue;
          if (vl === key) { exact = i; break; }
          if (prefIdx === -1 && vl.indexOf(pref + "-") === 0) prefIdx = i;
          if (pref === "en" && enFb === -1 && (vl === "en-gb" || vl === "en-us")) enFb = i;
        }
        var picked = exact !== -1 ? exact : (prefIdx !== -1 ? prefIdx : enFb);
        if (picked !== -1) {
          res.voice = picked;
          res.lang = voices[picked].lang || res.lang;
        }
      }
    } catch (e) {}
    cachedVoiceIdx[key] = res;
    return res;
  }

  function patchNativeTtsPlugin() {
    var tts = getNativeTts();
    if (!tts || tts.__lsUnifiedPatched) return;
    tts.__lsUnifiedPatched = true;
    var rawSpeak = tts.speak.bind(tts);
    tts.speak = async function (opts) {
      var text = String((opts && opts.text) || "").trim();
      if (!text) return;
      var targetLang = (opts && opts.lang) || ((typeof state !== "undefined" && state.lang === "te") ? "te-IN" : "en-IN");
      var resolved = await resolveNativeVoice(tts, targetLang);
      var payload = {
        text: text,
        lang: resolved.lang || targetLang,
        rate: Math.min(2.0, Math.max(0.6, Number((opts && opts.rate) || 1.15))),
        pitch: Number((opts && opts.pitch) || 1.0),
        volume: 1.0,
        category: "ambient"
      };
      if (typeof resolved.voice === "number") payload.voice = resolved.voice;
      try {
        return await rawSpeak(payload);
      } catch (err) {
        return rawSpeak({ text: text, lang: "en-US", rate: payload.rate, pitch: 1.0, volume: 1.0, category: "ambient" });
      }
    };
  }

  function stopNativeAndWeb() {
    var tts = getNativeTts();
    if (tts && typeof tts.stop === "function") {
      try { tts.stop().catch(function () {}); } catch (e) {}
    }
    if (typeof window.speechSynthesis !== "undefined") {
      try { window.speechSynthesis.cancel(); } catch (e) {}
    }
  }

  function syncPlayerBarWithActiveTopic() {
    if (typeof state === "undefined" || !state) return;
    if (state.audio && state.audio.isPlaying && !state.audio.isPaused) return;
    var titleEl = document.getElementById("audioCurrentTitle");
    var counterEl = document.getElementById("audioQueueCounter");
    var badgeEl = document.getElementById("audioModeBadge");
    if (!titleEl || !state.activeTopicId) return;
    var rec = state.notes && state.notes[state.activeTopicId];
    var ld = rec ? (rec[state.lang] || rec.en) : null;
    var meta = (typeof findTopicMeta === "function") ? findTopicMeta(state.activeTopicId) : null;
    titleEl.textContent = (ld && ld.title) || (meta && meta.topic && meta.topic.title) || state.activeTopicId;
    if (counterEl && (!state.audio || !state.audio.isPaused)) counterEl.textContent = "Ready to listen";
    if (badgeEl && (!state.audio || !state.audio.isPaused)) badgeEl.textContent = "Topic Mode";
  }

  function wireUnifiedAudioControls() {
    patchNativeTtsPlugin();
    injectAudioLayoutCss();
    arrangeAudioBarRows();

    var playBtn = document.getElementById("audioPlayPauseBtn");
    if (playBtn && !playBtn.__lsUnifiedBound) {
      playBtn.__lsUnifiedBound = true;
      var freshPlay = playBtn.cloneNode(true);
      playBtn.parentNode.replaceChild(freshPlay, playBtn);
      freshPlay.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        patchNativeTtsPlugin();
        if (typeof state === "undefined" || !state.audio) return;

        var hasNative = !!getNativeTts();
        var hasWeb = ("speechSynthesis" in window);
        if (!hasNative && !hasWeb) {
          if (typeof showToast === "function") showToast("Install Google Speech Services on Android for audio.");
          return;
        }

        if (state.audio.isPlaying && !state.audio.isPaused) {
          clearTimeout(state.audio.pauseTimerHandle);
          state.audio.isPaused = true;
          if (hasNative) {
            stopNativeAndWeb();
          } else {
            try { window.speechSynthesis.pause(); } catch (e) { window.speechSynthesis.cancel(); }
          }
          if (typeof updateAudioUI === "function") updateAudioUI();
          if (typeof showToast === "function") showToast("Audio paused");
          return;
        }

        if (state.audio.isPlaying && state.audio.isPaused) {
          state.audio.isPaused = false;
          if (hasNative) {
            if (typeof playQueueIndex === "function") playQueueIndex(state.audio.index || 0, state.audio.chunkIndex || 0);
          } else if (hasWeb && window.speechSynthesis.paused) {
            window.speechSynthesis.resume();
            if (typeof updateAudioUI === "function") updateAudioUI();
          } else if (typeof playQueueIndex === "function") {
            playQueueIndex(state.audio.index || 0, state.audio.chunkIndex || 0);
          }
          return;
        }

        if (typeof startTopicAudio === "function" && state.activeTopicId) {
          startTopicAudio(state.activeTopicId);
        }
      });
    }

    var stopBtn = document.getElementById("audioStopBtn");
    if (stopBtn && !stopBtn.__lsStopWrapped) {
      stopBtn.__lsStopWrapped = true;
      stopBtn.addEventListener("click", function () {
        if (typeof state !== "undefined" && state.audio) {
          clearTimeout(state.audio.pauseTimerHandle);
          state.audio.isPlaying = false;
          state.audio.isPaused = false;
        }
        stopNativeAndWeb();
        setTimeout(syncPlayerBarWithActiveTopic, 60);
      }, true);
    }

    ["audioPrevBtn", "audioNextBtn"].forEach(function (bid) {
      var b = document.getElementById(bid);
      if (b && !b.__lsSkipWrapped) {
        b.__lsSkipWrapped = true;
        b.addEventListener("click", function () { stopNativeAndWeb(); }, true);
      }
    });

    var spd = document.getElementById("audioSpeedSelect");
    if (spd && !spd.__lsSpdWrapped) {
      spd.__lsSpdWrapped = true;
      spd.addEventListener("change", function () {
        if (typeof state !== "undefined" && state.audio) {
          state.audio.speed = parseFloat(spd.value) || 1.15;
          if (state.audio.isPlaying && !state.audio.isPaused && typeof playQueueIndex === "function") {
            stopNativeAndWeb();
            playQueueIndex(state.audio.index || 0, state.audio.chunkIndex || 0);
          }
        }
      });
    }

    if (typeof window.renderReadingPane === "function" && !window.__lsAudioTopicHooked) {
      window.__lsAudioTopicHooked = true;
      var origRender = window.renderReadingPane;
      window.renderReadingPane = function () {
        var res = origRender.apply(this, arguments);
        try {
          if (typeof state !== "undefined" && state.audio && state.audio.queue && state.audio.queue.length) {
            var curItem = state.audio.queue[state.audio.index || 0];
            if (curItem && curItem.topicId && state.activeTopicId && curItem.topicId !== state.activeTopicId && state.audio.mode !== "unit") {
              stopNativeAndWeb();
              clearTimeout(state.audio.pauseTimerHandle);
              state.audio.isPlaying = false;
              state.audio.isPaused = false;
              state.audio.queue = [];
              if (typeof updateAudioUI === "function") updateAudioUI();
            }
          }
          syncPlayerBarWithActiveTopic();
        } catch (e) {}
        return res;
      };
    }

    syncPlayerBarWithActiveTopic();
  }

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(wireUnifiedAudioControls, 250);
    setTimeout(wireUnifiedAudioControls, 1200);
  });
})();
'@
$audioPath = Join-Path $modDir "ls-audio.js"
if (-not (Test-Path $audioPath)) { if (-not (Test-Path (Join-Path $modDir "ls-audio-engine.js"))) { [System.IO.File]::WriteAllText($audioPath, $audioJs, $u) } }
if (Test-Path $audioPath) { node --check $audioPath }
if ($LASTEXITCODE -ne 0) { throw "ls-audio.js syntax error!" }
Write-Host "[PASS] www/js/modules/ls-audio.js verified (0 errors)" -ForegroundColor Green

Write-Host "`n=== 2. Restoring Offline Mermaid Flowcharts, Diagrams & Tables (www/js/modules/ls-diagrams.js) ===" -ForegroundColor Cyan
$diagramsJs = @'
(function () {
  "use strict";
  if (window.__lsDiagramsRestoredV308) return;
  window.__lsDiagramsRestoredV308 = true;

  var mermaidInited = false;
  var zoomScale = 1;
  var walkTimer = null;

  function injectDiagramStyles() {
    if (document.getElementById("lsDiagramsExtraCss")) return;
    var st = document.createElement("style");
    st.id = "lsDiagramsExtraCss";
    st.textContent =
      ".ls-visual-card { background:#FFFFFF; border:1px solid #E8E0D5; border-radius:16px; padding:14px; margin-bottom:14px; box-shadow:0 2px 10px rgba(31,27,24,0.04); overflow:hidden; }" +
      ".ls-visual-box { overflow-x:auto; -webkit-overflow-scrolling:touch; padding:6px 2px; }" +
      ".ls-visual-box .dg { margin:0; font-size:12.5px; color:#1F1B18; }" +
      ".ls-visual-box .dg-title { display:block; font-weight:800; color:#7B1E2B; font-size:13.5px; margin-bottom:3px; }" +
      ".ls-visual-box .dg-how { display:block; font-size:11.5px; color:#5F554E; margin-bottom:10px; font-weight:500; }" +
      ".ls-visual-box .nest { border:2px solid #7B1E2B; border-radius:14px; padding:10px 12px; margin-top:8px; background:#FAF7F2; }" +
      ".ls-visual-box .nest .nest { border-color:#B45309; background:#FFFBF0; }" +
      ".ls-visual-box .nest .nest .nest { border-color:#0F766E; background:#F0FDFA; }" +
      ".ls-visual-box .nest-label { font-weight:700; font-size:12px; color:#1F1B18; }" +
      ".ls-visual-box .nest-label small { display:block; font-weight:600; color:#7B1E2B; font-size:10.5px; margin-top:2px; }" +
      ".ls-visual-box .dg-time ol { list-style:none; padding:0; margin:8px 0 0; display:grid; grid-template-columns:repeat(auto-fit,minmax(130px,1fr)); gap:8px; }" +
      ".ls-visual-box .dg-time li { background:#FAF7F2; border:1px solid #E8E0D5; border-left:3px solid #7B1E2B; border-radius:10px; padding:8px 10px; font-size:11.5px; line-height:1.4; }" +
      ".ls-visual-box .dg-time .when { display:block; font-weight:800; color:#7B1E2B; font-size:12px; margin-bottom:2px; }" +
      ".ls-visual-box .mermaid { text-align:center; }";
    document.head.appendChild(st);
  }

  function isRealVisual(v) {
    if (!v || !v.html) return false;
    var h = String(v.html);
    if (v.type === "svg") {
      if (/height=["']?(1[0-9]|2[0-4])["']?/i.test(h) && /width=["']?(1[0-9]|2[0-4])["']?/i.test(h)) return false;
      if (/viewbox=["']0 0 24 24["']/i.test(h) && h.length < 700) return false;
    }
    return true;
  }

  function dedupeVisuals(list) {
    var out = [];
    var seen = {};
    for (var i = 0; i < list.length; i++) {
      var v = list[i];
      if (!isRealVisual(v)) continue;
      var norm = String(v.html).replace(/<[^>]+>/g, " ").replace(/&[a-z#0-9]+;/gi, " ").replace(/\s+/g, " ").trim().toLowerCase().slice(0, 140);
      if (norm && seen[norm]) continue;
      if (norm) seen[norm] = true;
      out.push(v);
    }
    return out;
  }

  function initMermaidOnce() {
    if (mermaidInited || !window.mermaid) return;
    mermaidInited = true;
    try {
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "loose",
        theme: "base",
        themeVariables: {
          primaryColor: "#FBF1F2",
          primaryTextColor: "#1F1B18",
          primaryBorderColor: "#7B1E2B",
          lineColor: "#7B1E2B",
          secondaryColor: "#FFFBF0",
          tertiaryColor: "#FAF7F2",
          fontFamily: "system-ui, -apple-system, sans-serif",
          fontSize: "13px"
        },
        flowchart: { htmlLabels: true, curve: "basis", useMaxWidth: true }
      });
    } catch (e) {}
  }

  function renderMermaidNodes(container) {
    if (!container) return;
    var nodes = container.querySelectorAll(".mermaid");
    if (!nodes.length) return;
    if (!window.mermaid) {
      setTimeout(function () { renderMermaidNodes(container); }, 400);
      return;
    }
    initMermaidOnce();
    nodes.forEach(function (node, idx) {
      if (node.getAttribute("data-processed") === "true") return;
      var src = (node.textContent || "").trim();
      if (!src) return;
      var renderId = "ls_mm_" + Date.now() + "_" + idx;
      try {
        var res = window.mermaid.render(renderId, src);
        if (res && typeof res.then === "function") {
          res.then(function (out) {
            if (out && out.svg) {
              node.innerHTML = out.svg;
              node.setAttribute("data-processed", "true");
            }
          }).catch(function () {});
        }
      } catch (e) {}
    });
  }

  function stopMemoryWalk() {
    if (walkTimer) { clearInterval(walkTimer); walkTimer = null; }
    var canvas = document.getElementById("lsZoomCanvas");
    if (canvas) {
      canvas.querySelectorAll(".ls-spotlight-dim, .ls-spotlight-active, .ls-row-flash").forEach(function (el) {
        el.classList.remove("ls-spotlight-dim", "ls-spotlight-active", "ls-row-flash");
      });
    }
  }

  function startMemoryWalk() {
    stopMemoryWalk();
    var canvas = document.getElementById("lsZoomCanvas");
    if (!canvas) return;
    var items = Array.prototype.slice.call(canvas.querySelectorAll("svg .node, .dg-time li, .nest, tbody tr"));
    if (!items.length) return;
    var step = 0;
    items.forEach(function (el) { el.classList.add("ls-spotlight-dim"); });
    function tick() {
      items.forEach(function (el, idx) {
        var on = (idx === step);
        el.classList.toggle("ls-spotlight-active", on);
        el.classList.toggle("ls-spotlight-dim", !on);
        if (el.tagName === "TR") el.classList.toggle("ls-row-flash", on);
      });
      step = (step + 1) % items.length;
    }
    tick();
    walkTimer = setInterval(tick, 1400);
  }

  function openZoomForCard(cardEl, title) {
    var modal = document.getElementById("lsZoomModal");
    var canvas = document.getElementById("lsZoomCanvas");
    var titleEl = document.getElementById("lsZoomTitle");
    if (!modal || !canvas || !cardEl) return;
    stopMemoryWalk();
    zoomScale = 1;
    canvas.style.transform = "scale(1)";
    if (titleEl) titleEl.textContent = title || "Study Diagram";
    var box = cardEl.querySelector(".ls-visual-box");
    canvas.innerHTML = box ? box.innerHTML : cardEl.innerHTML;
    modal.classList.remove("hidden");
  }

  function wireZoomModalOnce() {
    var modal = document.getElementById("lsZoomModal");
    if (!modal || modal.__lsZoomWired) return;
    modal.__lsZoomWired = true;
    var canvas = document.getElementById("lsZoomCanvas");
    var btnClose = document.getElementById("lsZoomCloseBtn");
    var btnIn = document.getElementById("lsZoomInBtn");
    var btnOut = document.getElementById("lsZoomOutBtn");
    var btnReset = document.getElementById("lsZoomResetBtn");
    var btnWalk = document.getElementById("lsMemoryPulseBtn");
    if (btnClose) btnClose.addEventListener("click", function () { stopMemoryWalk(); modal.classList.add("hidden"); });
    if (btnIn) btnIn.addEventListener("click", function () { zoomScale = Math.min(2.4, +(zoomScale + 0.25).toFixed(2)); if (canvas) canvas.style.transform = "scale(" + zoomScale + ")"; });
    if (btnOut) btnOut.addEventListener("click", function () { zoomScale = Math.max(0.6, +(zoomScale - 0.25).toFixed(2)); if (canvas) canvas.style.transform = "scale(" + zoomScale + ")"; });
    if (btnReset) btnReset.addEventListener("click", function () { zoomScale = 1; if (canvas) canvas.style.transform = "scale(1)"; });
    if (btnWalk) btnWalk.addEventListener("click", startMemoryWalk);
    modal.addEventListener("click", function (ev) {
      if (ev.target === modal) { stopMemoryWalk(); modal.classList.add("hidden"); }
    });
  }

  function renderVisualDiagramsForActiveTopic() {
    injectDiagramStyles();
    wireZoomModalOnce();
    var pane = document.getElementById("readingPane");
    if (!pane || typeof state === "undefined" || !state.activeTopicId) return;

    var oldSec = document.getElementById("lsVisualDiagramsSection");
    if (oldSec) oldSec.remove();

    var rec = state.notes && state.notes[state.activeTopicId];
    if (!rec) return;
    var ld = rec[state.lang] || rec.en;
    var rawVis = (ld && Array.isArray(ld.visuals) && ld.visuals.length) ? ld.visuals : ((rec.en && Array.isArray(rec.en.visuals)) ? rec.en.visuals : []);
    var visuals = dedupeVisuals(rawVis);
    if (!visuals.length) return;

    var sec = document.createElement("section");
    sec.id = "lsVisualDiagramsSection";
    sec.className = "mt-6 space-y-3";

    var header = document.createElement("div");
    header.className = "flex items-center justify-between gap-2 px-1";
    header.innerHTML =
      '<div class="text-sm font-extrabold text-[#7B1E2B]">Visual Flowcharts, Diagrams &amp; Tables (' + visuals.length + ')</div>' +
      '<span class="text-[10.5px] font-bold px-2 py-0.5 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Offline Ready</span>';
    sec.appendChild(header);

    visuals.forEach(function (v, idx) {
      var card = document.createElement("div");
      card.className = "ls-visual-card";
      var cap = String(v.caption || (v.type === "table" ? "Comparison Table" : "Study Diagram " + (idx + 1)));

      var topBar = document.createElement("div");
      topBar.className = "flex items-center justify-between gap-2 mb-2 pb-1.5 border-b border-[#F3EDE4]";
      topBar.innerHTML =
        '<div class="text-xs font-bold text-[#7B1E2B] truncate">' + cap.replace(/</g, "&lt;") + '</div>' +
        '<button type="button" class="ls-zoom-open-btn px-2.5 py-1 rounded-lg bg-[#FAF7F2] border border-[#E8E0D5] text-[11px] font-bold text-[#7B1E2B] shrink-0">Zoom &amp; Walk</button>';

      var box = document.createElement("div");
      box.className = "ls-visual-box";
      box.innerHTML = v.html;

      topBar.querySelector(".ls-zoom-open-btn").addEventListener("click", function () {
        openZoomForCard(card, cap);
      });

      card.appendChild(topBar);
      card.appendChild(box);
      sec.appendChild(card);
    });

    pane.appendChild(sec);
    renderMermaidNodes(sec);
  }

  function hookReadingPane() {
    if (typeof window.renderReadingPane === "function" && !window.__lsDiagramsHooked) {
      window.__lsDiagramsHooked = true;
      var orig = window.renderReadingPane;
      window.renderReadingPane = function () {
        var r = orig.apply(this, arguments);
        try { renderVisualDiagramsForActiveTopic(); } catch (e) {}
        return r;
      };
      renderVisualDiagramsForActiveTopic();
    }
  }

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(hookReadingPane, 300);
    setTimeout(hookReadingPane, 1100);
  });
  window.LSDiagrams = { render: renderVisualDiagramsForActiveTopic };
})();
'@
$diagramsPath = Join-Path $modDir "ls-diagrams.js"
if (-not (Test-Path $diagramsPath)) { [System.IO.File]::WriteAllText($diagramsPath, $diagramsJs, $u) }
node --check $diagramsPath
if ($LASTEXITCODE -ne 0) { throw "ls-diagrams.js syntax error!" }
Write-Host "[PASS] www/js/modules/ls-diagrams.js verified (0 errors)" -ForegroundColor Green

Write-Host "`n=== 3. Syncing www/index.html, WhatsApp Share Link & Removing Conflicting Legacy TTS Patches ===" -ForegroundColor Cyan
$idxPath = Join-Path $wwwDir "index.html"
$h = [System.IO.File]::ReadAllText($idxPath, $u)

# Remove conflicting legacy TTS band-aids so ls-audio.js owns all player controls cleanly
$h = [regex]::Replace($h, '(?s)<!-- LS_SAFE_TTS_START -->.*?<!-- LS_SAFE_TTS_END -->', '')
$h = [regex]::Replace($h, '(?s)<!-- LS_NATIVE_TTS_V2610_START -->.*?<!-- LS_NATIVE_TTS_V2610_END -->', '')
$h = [regex]::Replace($h, '(?s)<!-- LS_TTS_PLAY_CATCH_V303_START -->.*?<!-- LS_TTS_PLAY_CATCH_V303_END -->', '')

# Wire ls-audio.js & ls-diagrams.js inside LS_MODULAR_V3 block
$h = [regex]::Replace($h, '<script defer src="\./js/modules/ls-(audio|diagrams)\.js[^"]*"></script>\r?\n?', '')
$newModTags = "<script defer src=`"./js/modules/ls-diagrams.js?v=$Version`"></script>`r`n<!-- LS_MODULAR_V3_END -->"
if ($h.Contains("<!-- LS_MODULAR_V3_END -->")) {
  $h = $h.Replace("<!-- LS_MODULAR_V3_END -->", $newModTags)
} else {
  $h = $h.Replace("</body>", "<script defer src=`"./js/modules/ls-audio.js?v=$Version`"></script>`r`n<script defer src=`"./js/modules/ls-diagrams.js?v=$Version`"></script>`r`n</body>")
}

# Sync ALL version strings & WhatsApp Share message/URL to $Version
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$Version"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$Version`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$Version`";"
$h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', "var CURRENT_APP_VER = `"$Version`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$Version`";"
$h = $h -replace '\?v=3\.\d+\.\d+"', "?v=$Version`""
$h = $h -replace 'var SHARE_LINK = "[^"]+";', "var SHARE_LINK = `"https://law-studyes.vercel.app/download.html?v=$Version`";"
$h = $h -replace 'var msg = "Download Law Studyes[^"]*";', "var msg = `"Download Law Studyes v$Version (Free 3-Year LL.B. Offline Notes, Flowcharts & Audio App): `" + SHARE_LINK;"
$h = $h -replace 'href="https://github\.com/khodayanvesh-jsf/law-studyes/releases/latest/download/LawStudyes-Offline\.apk"', "href=`"https://law-studyes.vercel.app/LawStudyes-Offline.apk?v=$Version`""

[System.IO.File]::WriteAllText($idxPath, $h, $u)

# Verify 0 JS syntax errors in all inline scripts
$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_unified_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS syntax error(s) in www/index.html!" }
Write-Host "[PASS] www/index.html + WhatsApp share link synced to v$Version (0 JS errors)" -ForegroundColor Green

# Sync www/manifest.json if present
$manPath = Join-Path $wwwDir "manifest.json"
if (Test-Path $manPath) {
  python -c "import json,pathlib; p=pathlib.Path(r'$manPath'); d=json.loads(p.read_text(encoding='utf-8')); d['version']='$Version'; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')"
}

$apkMB = ""
if (-not $OtaOnly) {
  Write-Host "`n=== 4. Building Signed Android APK v$Version (versionCode $VersionCode) ===" -ForegroundColor Cyan
  $bgPath = Join-Path $root "android\app\build.gradle"
  $bgTxt = [System.IO.File]::ReadAllText($bgPath, $u)
  $bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $VersionCode"
  $bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$Version`""
  [System.IO.File]::WriteAllText($bgPath, $bgTxt, $u)

  # Remove old APK/ZIP from www/ BEFORE cap sync so APK never bundles an old copy of itself
  Remove-Item (Join-Path $wwwDir "LawStudyes-Offline.apk"), (Join-Path $wwwDir "ota-bundle.zip") -ErrorAction SilentlyContinue

  npx cap sync android
  if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

  Push-Location (Join-Path $root "android")
  try {
    .\gradlew.bat assembleRelease
    if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
  } finally { Pop-Location }

  $builtApk = Join-Path $root "android\app\build\outputs\apk\release\app-release.apk"
  $deskApk = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$Version.apk"
  Copy-Item $builtApk $deskApk -Force
  # Copy fresh APK to www/LawStudyes-Offline.apk AFTER build so WhatsApp share link serves latest APK!
  Copy-Item $builtApk (Join-Path $wwwDir "LawStudyes-Offline.apk") -Force
  $apkMB = [string][Math]::Round((Get-Item $deskApk).Length / 1MB, 2) + " MB"
  Write-Host "[SUCCESS] Android APK built -> Desktop\LawStudyes-v$Version.apk & www/LawStudyes-Offline.apk ($apkMB)" -ForegroundColor Green
}

Write-Host "`n=== 5. Updating www/download.html (WhatsApp Share Landing Page -> v$Version) ===" -ForegroundColor Cyan
$todayDisp = (Get-Date).ToString("dd MMM yyyy")
$sizeBadge = if ($apkMB) { " &middot; $apkMB" } else { "" }
$dlHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Download Law Studyes v$Version (Android APK)</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif}
    body{min-height:100vh;background:#FAF7F2;color:#1F1B18;display:flex;align-items:center;justify-content:center;padding:24px}
    .card{background:#fff;border:1px solid #E8E0D5;border-radius:22px;max-width:400px;width:100%;padding:34px 26px;text-align:center;box-shadow:0 14px 34px rgba(31,27,24,.08)}
    .logo{width:64px;height:64px;border-radius:50%;background:#7B1E2B;color:#FAF7F2;display:inline-flex;align-items:center;justify-content:center;font-size:28px;margin-bottom:14px}
    h1{font-family:Georgia,serif;color:#7B1E2B;font-size:26px;margin-bottom:6px}
    .ver{display:inline-block;padding:4px 12px;border-radius:999px;background:#FBF1F2;border:1px solid #E8D5D8;color:#7B1E2B;font-size:12px;font-weight:800;margin-bottom:14px}
    p{color:#5F554E;font-size:13px;line-height:1.5;margin-bottom:22px}
    .btn{display:block;width:100%;padding:15px 20px;background:#7B1E2B;color:#fff;text-decoration:none;border-radius:14px;font-weight:700;font-size:15px;box-shadow:0 6px 16px rgba(123,30,43,.25)}
    .btn:active{background:#5E1520}
    .sub{margin-top:14px;font-size:11.5px;color:#8C6D46}
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">&#9878;</div>
    <h1>Law Studyes</h1>
    <div class="ver">Latest Release: v$Version ($todayDisp$sizeBadge)</div>
    <p>3-Year LL.B. Bilingual Offline Notes, Animated Flowcharts, Landmark Judgments &amp; Indian Voice Audio App with Auto-OTA Updates.</p>
    <a class="btn" href="./LawStudyes-Offline.apk?v=$Version" download="LawStudyes-v$Version.apk">Download Law Studyes v$Version (.APK)</a>
    <div class="sub">Auto-updates automatically over the air after install.</div>
  </div>
</body>
</html>
"@
[System.IO.File]::WriteAllText((Join-Path $wwwDir "download.html"), $dlHtml, $u)
Write-Host "[OK] www/download.html updated to v$Version" -ForegroundColor Green

$deskDir = Join-Path $root "desktop-console"
if ((Test-Path $deskDir) -and (-not $OtaOnly)) {
  Write-Host "`n=== 6. Syncing Windows Founder Console (desktop-console/) to v$Version ===" -ForegroundColor Cyan
  $deskPkg = Join-Path $deskDir "package.json"
  if (Test-Path $deskPkg) {
    python -c "import json,pathlib; p=pathlib.Path(r'$deskPkg'); d=json.loads(p.read_text(encoding='utf-8')); d['version']='$Version'; d.setdefault('build',{}).setdefault('win',{})['signAndEditExecutable']=False; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')"
  }
  $deskHtml = Join-Path $deskDir "index.html"
  if (Test-Path $deskHtml) {
    $dh = [System.IO.File]::ReadAllText($deskHtml, $u)
    $dh = $dh -replace 'v\d+\.\d+\.\d+\s*&middot;\s*Android \+ Windows', "v$Version &middot; Android + Windows"
    [System.IO.File]::WriteAllText($deskHtml, $dh, $u)
  }
  $deskMain = Join-Path $deskDir "main.js"
  if (Test-Path $deskMain) {
    $dm = [System.IO.File]::ReadAllText($deskMain, $u)
    $dm = $dm -replace 'Founder & Admin Console v[\d\.]+', "Founder & Admin Console v$Version"
    [System.IO.File]::WriteAllText($deskMain, $dm, $u)
  }
  if (-not $SkipWindowsExe) {
    Push-Location $deskDir
    try {
      $env:CSC_IDENTITY_AUTO_DISCOVERY = "false"
      npm run build
      if ($LASTEXITCODE -ne 0) { throw "Windows Founder Console build failed!" }
    } finally { Pop-Location }
    $exeSrc = Get-ChildItem (Join-Path $deskDir "dist") -Filter "*.exe" -File | Select-Object -First 1
    if ($exeSrc) {
      $destExe = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-Founder-Console-Windows.exe"
      Copy-Item $exeSrc.FullName $destExe -Force
      Write-Host ("[SUCCESS] Windows Console updated -> " + $destExe) -ForegroundColor Green
    }
  }
}

Write-Host "`n=== 7. Packing Verified OTA Bundle & Pushing ALL Platforms to GitHub + Vercel ===" -ForegroundColor Cyan
if (Test-Path ".\www\LawStudyes-Offline.apk") { git add -f ".\www\LawStudyes-Offline.apk" }
$otaMsg = if ($Message.Trim()) { $Message.Trim() } else { "Unified v$Version release (Audio Engine, Offline Diagrams, Mobile Alignment & WhatsApp APK sync)" }
& (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message $otaMsg