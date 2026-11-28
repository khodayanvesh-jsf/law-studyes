param(
  [string]$Version = "3.2.1",
  [switch]$PushOta
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$wwwDir = Join-Path $root "www"
$modDir = Join-Path $wwwDir "js\modules"
$jsDir = Join-Path $wwwDir "js"
New-Item -ItemType Directory -Path $modDir, $jsDir -Force | Out-Null

Write-Host "`n=== 1. Installing Unified Live-Switching Voice Engine (www/js/modules/ls-voice-controller.js) ===" -ForegroundColor Cyan
$voiceJs = @'
(function () {
  "use strict";
  if (window.__lsVoiceCtrlV321) return;
  window.__lsVoiceCtrlV321 = true;

  var K_ENG = "ls_voice_engine_v2", K_GEN = "ls_voice_gender_v2", K_VID = "ls_voice_id_v2", K_RATE = "ls_voice_rate_v2";
  var webVoices = [], capVoices = [], nativeWebSpeak = null, nativeCapSpeak = null;

  function getEngine() { try { return localStorage.getItem(K_ENG) || "studio"; } catch (e) { return "studio"; } }
  function getGender() { try { return localStorage.getItem(K_GEN) || localStorage.getItem("ls_prof_gender_v1") || "female"; } catch (e) { return "female"; } }
  function getVoiceId() { try { return localStorage.getItem(K_VID) || "auto"; } catch (e) { return "auto"; } }
  function getRate() { try { var r = parseFloat(localStorage.getItem(K_RATE) || "1"); return (isFinite(r) && r >= 0.5 && r <= 2.0) ? r : 1.0; } catch (e) { return 1.0; } }
  function getLang() { try { return (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "en"; } catch (e) { return "en"; } }
  function toBcp47(l) { l = String(l || getLang()).toLowerCase(); return l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN"); }
  function getPitch() { return getGender() === "male" ? (getEngine() === "device" ? 0.82 : 0.90) : (getEngine() === "device" ? 1.10 : 1.04); }

  function loadWebVoices() {
    try { if ("speechSynthesis" in window) { var v = window.speechSynthesis.getVoices() || []; if (v.length) webVoices = v; } } catch (e) {}
    return webVoices;
  }
  async function loadCapVoices() {
    try {
      var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
      if (tts && typeof tts.getSupportedVoices === "function") {
        var r = await tts.getSupportedVoices();
        if (r && Array.isArray(r.voices)) capVoices = r.voices;
      }
    } catch (e) {}
    return capVoices;
  }

  function scoreVoice(v, bcp47, eng, gen) {
    var vl = String((v && v.lang) || "").toLowerCase().replace("_", "-");
    var vn = String((v && (v.name || v.voiceURI)) || "");
    var pref = bcp47.toLowerCase().split("-")[0];
    if (vl.indexOf("ar") === 0) return -9999;
    if (vl !== bcp47.toLowerCase() && vl.indexOf(pref + "-") !== 0 && vl !== pref) return -5000;
    var sc = (vl === bcp47.toLowerCase()) ? 100 : 40;
    var isNeural = /neural|natural|network|wavenet|online|google|microsoft/i.test(vn) || (v && v.localService === false);
    if (eng === "device") { if (v && v.localService === true) sc += 55; if (!isNeural) sc += 25; }
    else if (isNeural) sc += 55;
    if (gen === "female" && /neerja|shruti|swara|heera|kalpana|veena|lekha|female|wavenet-a|wavenet-d|sfg|isf|inf/i.test(vn)) sc += 30;
    if (gen === "male" && /prabhat|mohan|madhur|ravi|hemant|male|wavenet-b|wavenet-c|ism|inm/i.test(vn)) sc += 30;
    return sc;
  }

  function resolveWebVoice(lang) {
    var bcp47 = toBcp47(lang), vs = loadWebVoices(), vid = getVoiceId();
    if (!vs.length) return null;
    if (vid && vid !== "auto") {
      for (var i = 0; i < vs.length; i++) if (vs[i].voiceURI === vid || vs[i].name === vid) return vs[i];
    }
    var best = null, bestSc = -999, eng = getEngine(), gen = getGender();
    for (var j = 0; j < vs.length; j++) { var s = scoreVoice(vs[j], bcp47, eng, gen); if (s > bestSc) { bestSc = s; best = vs[j]; } }
    return best;
  }

  function resolveCapVoiceIndex(lang) {
    var bcp47 = toBcp47(lang), vs = capVoices, vid = getVoiceId();
    if (!vs.length) return -1;
    if (vid && vid !== "auto") {
      if (/^\d+$/.test(vid) && vs[parseInt(vid, 10)]) return parseInt(vid, 10);
      for (var i = 0; i < vs.length; i++) if (vs[i].voiceURI === vid || vs[i].name === vid) return i;
    }
    var bestIdx = -1, bestSc = -999, eng = getEngine(), gen = getGender();
    for (var j = 0; j < vs.length; j++) { var s = scoreVoice(vs[j], bcp47, eng, gen); if (s > bestSc) { bestSc = s; bestIdx = j; } }
    return bestIdx;
  }

  function stopRawTts() {
    try { var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech; if (tts && tts.stop) tts.stop().catch(function () {}); } catch (e) {}
    try { if ("speechSynthesis" in window) window.speechSynthesis.cancel(); } catch (e) {}
  }

  function applySettings(patch, restartActive) {
    if (patch && typeof patch.engine === "string") try { localStorage.setItem(K_ENG, patch.engine); } catch (e) {}
    if (patch && typeof patch.gender === "string") try { localStorage.setItem(K_GEN, patch.gender); localStorage.setItem("ls_prof_gender_v1", patch.gender); } catch (e) {}
    if (patch && typeof patch.voiceId === "string") try { localStorage.setItem(K_VID, patch.voiceId); } catch (e) {}
    if (patch && patch.rate !== undefined) try { localStorage.setItem(K_RATE, String(patch.rate)); } catch (e) {}

    syncUi();
    var detail = { engine: getEngine(), gender: getGender(), voiceId: getVoiceId(), rate: getRate(), restartActive: restartActive !== false };
    try { window.dispatchEvent(new CustomEvent("ls:voice-settings-changed", { detail: detail })); } catch (e) {}

    if (restartActive !== false) {
      try {
        var engApi = window.LSAudioEngine;
        if (engApi && typeof engApi.getState === "function") {
          var st = engApi.getState();
          if (st && st.playing && !st.paused) {
            if (typeof engApi.setSpeed === "function") engApi.setSpeed(detail.rate);
            var idx = typeof st.index === "number" ? st.index : 0;
            if (typeof engApi.stop === "function") engApi.stop();
            setTimeout(function () {
              try {
                if (typeof engApi.jumpTo === "function") engApi.jumpTo(idx);
                else if (typeof engApi.play === "function") engApi.play();
              } catch (err) {}
            }, 130);
          }
        }
      } catch (e) {}
    }
  }

  function patchSpeechApis() {
    try {
      if ("speechSynthesis" in window && typeof window.speechSynthesis.speak === "function" && !window.speechSynthesis.__lsPatchedV321) {
        nativeWebSpeak = window.speechSynthesis.speak.bind(window.speechSynthesis);
        window.speechSynthesis.__lsPatchedV321 = true;
        window.speechSynthesis.speak = function (u) {
          try {
            if (u && !u.__lsVoiceApplied) {
              u.__lsVoiceApplied = true;
              var l = getLang();
              u.lang = toBcp47(l);
              var v = resolveWebVoice(l);
              if (v) u.voice = v;
              u.rate = getRate();
              u.pitch = getPitch();
            }
          } catch (e) {}
          return nativeWebSpeak(u);
        };
      }
    } catch (e) {}
    try {
      var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
      if (tts && typeof tts.speak === "function" && !tts.__lsPatchedV321) {
        nativeCapSpeak = tts.speak.bind(tts);
        tts.__lsPatchedV321 = true;
        tts.speak = function (opts) {
          var o = Object.assign({}, opts || {});
          try {
            var l = getLang();
            o.lang = toBcp47(l);
            o.rate = getRate();
            o.pitch = getPitch();
            var idx = resolveCapVoiceIndex(l);
            if (idx >= 0) o.voice = idx;
          } catch (e) {}
          return nativeCapSpeak(o);
        };
      }
    } catch (e) {}
  }

  async function testVoice() {
    var l = getLang(), eng = getEngine(), gen = getGender();
    var sample = l === "te"
      ? "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02! \u0c07\u0c26\u0c3f \u0c2e\u0c40\u0c30\u0c41 \u0c0e\u0c02\u0c2a\u0c3f\u0c15 \u0c1a\u0c47\u0c38\u0c3f\u0c28 \u0c32\u0c3e \u0c38\u0c4d\u0c1f\u0c21\u0c40\u0c38\u0c4d \u0c35\u0c3e\u0c2f\u0c3f\u0c38\u0c4d."
      : (l === "hi"
        ? "\u0928\u092e\u0938\u094d\u0924\u0947! \u092f\u0939 \u0906\u092a\u0915\u0940 \u091a\u0941\u0928\u0940 \u0939\u0941\u0908 \u0932\u0949 \u0938\u094d\u091f\u0921\u0940\u091c\u093c \u0906\u0935\u093e\u091c\u093c \u0939\u0948\u0964"
        : "Hello students! Testing your selected " + eng + " " + (gen === "male" ? "Sir" : "Ma'am") + " voice engine.");

    stopRawTts();
    if (window.LSIndianProfessor && window.LSIndianProfessor.stop) window.LSIndianProfessor.stop();
    if (typeof showToast === "function") showToast("Testing " + eng.toUpperCase() + " (" + (gen === "male" ? "Sir" : "Ma'am") + ", " + getRate() + "x)");

    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && typeof tts.speak === "function") {
      try { await tts.speak({ text: sample, lang: toBcp47(l), rate: getRate(), pitch: getPitch(), volume: 1.0 }); return; } catch (e) {}
    }
    if ("speechSynthesis" in window) {
      try { window.speechSynthesis.speak(new SpeechSynthesisUtterance(sample)); } catch (e) {}
    }
  }

  function fillVoiceSelect(sel) {
    if (!sel) return;
    var bcp = toBcp47(getLang()).toLowerCase(), pref = bcp.split("-")[0];
    var list = capVoices.length ? capVoices : loadWebVoices(), saved = getVoiceId();
    var html = '<option value="auto">Auto Best (' + toBcp47(getLang()) + ')</option>';
    for (var i = 0; i < list.length; i++) {
      var v = list[i], vl = String((v && v.lang) || "").toLowerCase().replace("_", "-");
      if (vl === bcp || vl.indexOf(pref + "-") === 0 || vl === pref) {
        var key = capVoices.length ? String(i) : String(v.voiceURI || v.name || i);
        var lbl = String(v.name || v.voiceURI || ("Voice " + i)) + " (" + (v.lang || "") + ")";
        html += '<option value="' + key.replace(/"/g, "&quot;") + '"' + (saved === key ? " selected" : "") + '>' + lbl.replace(/</g, "&lt;") + '</option>';
      }
    }
    sel.innerHTML = html;
  }

  function syncUi() {
    var e = document.getElementById("lsUnifiedEngineSel"), g = document.getElementById("lsUnifiedGenderSel"),
        v = document.getElementById("lsUnifiedVoiceSel"), r = document.getElementById("lsUnifiedRateSel");
    if (e) e.value = getEngine();
    if (g) g.value = getGender();
    if (r) r.value = String(getRate());
    if (v) fillVoiceSelect(v);
  }

  function injectPlayerControls() {
    try {
      var host = document.getElementById("lsAudioModalBody") || document.getElementById("lsAudioWindowBody")
        || document.getElementById("lsAudioWindow") || document.getElementById("lsAudioModal")
        || document.querySelector("[id*='AudioWindow'], [id*='AudioModal'], [id*='audioPlayer']");
      if (!host) return;

      host.querySelectorAll("select").forEach(function (s) {
        if ((s.id && s.id.indexOf("lsUnified") === 0) || s.__lsHookedV321) return;
        s.__lsHookedV321 = true;
        s.addEventListener("change", function () {
          var val = String(s.value || "").toLowerCase();
          if (/studio|mp3|human/.test(val)) applySettings({ engine: "studio", voiceId: "auto" }, true);
          else if (/device|offline|local/.test(val)) applySettings({ engine: "device", voiceId: "auto" }, true);
          else if (/neural|web|cloud|tts|native/.test(val)) applySettings({ engine: "neural", voiceId: "auto" }, true);
          else if (/male|sir/.test(val)) applySettings({ gender: "male", voiceId: "auto" }, true);
          else if (/female|maam|madam/.test(val)) applySettings({ gender: "female", voiceId: "auto" }, true);
          else if (/^\d+(\.\d+)?$/.test(val) && parseFloat(val) >= 0.5 && parseFloat(val) <= 2.5) applySettings({ rate: parseFloat(val) }, true);
          else if (s.value) applySettings({ voiceId: s.value }, true);
        });
      });

      if (document.getElementById("lsUnifiedVoicePanel")) { syncUi(); return; }

      var box = document.createElement("div");
      box.id = "lsUnifiedVoicePanel";
      box.style.cssText = "margin:10px 0;padding:10px;border-radius:12px;background:#FAF7F2;border:1px solid #E5D5C0;display:flex;flex-direction:column;gap:8px;";
      box.innerHTML =
        '<div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">' +
          '<strong style="font-size:12px;color:#7B1E2B;">Voice Engine &amp; Live Controls</strong>' +
          '<button type="button" id="lsUnifiedTestVoiceBtn" style="padding:4px 10px;border-radius:8px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11px;font-weight:800;cursor:pointer;">Test Voice</button>' +
        '</div>' +
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;">' +
          '<label style="font-size:10.5px;font-weight:700;color:#5F554E;">Engine' +
            '<select id="lsUnifiedEngineSel" style="width:100%;margin-top:2px;padding:6px;border-radius:8px;border:1px solid #D8C8B4;background:#FFF;font-size:11.5px;">' +
              '<option value="studio">Human Studio MP3 + Neural</option>' +
              '<option value="neural">Indian Neural TTS</option>' +
              '<option value="device">Offline Device TTS</option>' +
            '</select></label>' +
          '<label style="font-size:10.5px;font-weight:700;color:#5F554E;">Professor Voice' +
            '<select id="lsUnifiedGenderSel" style="width:100%;margin-top:2px;padding:6px;border-radius:8px;border:1px solid #D8C8B4;background:#FFF;font-size:11.5px;">' +
              '<option value="female">Ma\'am (Female Indian)</option>' +
              '<option value="male">Sir (Male Indian)</option>' +
            '</select></label>' +
          '<label style="font-size:10.5px;font-weight:700;color:#5F554E;">System Voice' +
            '<select id="lsUnifiedVoiceSel" style="width:100%;margin-top:2px;padding:6px;border-radius:8px;border:1px solid #D8C8B4;background:#FFF;font-size:11.5px;"></select></label>' +
          '<label style="font-size:10.5px;font-weight:700;color:#5F554E;">Speed' +
            '<select id="lsUnifiedRateSel" style="width:100%;margin-top:2px;padding:6px;border-radius:8px;border:1px solid #D8C8B4;background:#FFF;font-size:11.5px;">' +
              '<option value="0.85">0.85x (Slow)</option><option value="1">1.0x (Normal)</option><option value="1.15">1.15x (Fast)</option><option value="1.3">1.3x (Revision)</option>' +
            '</select></label>' +
        '</div>';

      (host.querySelector(".bg-white, .modal-card, .ls-audio-card") || host).appendChild(box);
      box.querySelector("#lsUnifiedEngineSel").addEventListener("change", function (ev) {
        applySettings({ engine: ev.target.value, voiceId: "auto" }, true);
        if (typeof showToast === "function") showToast("Engine: " + ev.target.options[ev.target.selectedIndex].text);
      });
      box.querySelector("#lsUnifiedGenderSel").addEventListener("change", function (ev) {
        applySettings({ gender: ev.target.value, voiceId: "auto" }, true);
        if (typeof showToast === "function") showToast("Voice: " + (ev.target.value === "male" ? "Sir" : "Ma'am"));
      });
      box.querySelector("#lsUnifiedVoiceSel").addEventListener("change", function (ev) {
        applySettings({ voiceId: ev.target.value }, true);
      });
      box.querySelector("#lsUnifiedRateSel").addEventListener("change", function (ev) {
        applySettings({ rate: parseFloat(ev.target.value) || 1.0 }, true);
      });
      box.querySelector("#lsUnifiedTestVoiceBtn").addEventListener("click", testVoice);
      syncUi();
    } catch (e) {}
  }

  window.LSVoiceController = {
    getEngine: getEngine, getGender: getGender, getVoiceId: getVoiceId, getRate: getRate, getPitch: getPitch,
    langToBcp47: toBcp47, applySettings: applySettings, testVoice: testVoice
  };

  function boot() { patchSpeechApis(); loadWebVoices(); loadCapVoices().then(syncUi); injectPlayerControls(); }
  if ("speechSynthesis" in window && "onvoiceschanged" in window.speechSynthesis) {
    window.speechSynthesis.onvoiceschanged = function () { loadWebVoices(); syncUi(); };
  }
  window.addEventListener("ls:lang-changed", syncUi);
  window.addEventListener("DOMContentLoaded", function () { boot(); setTimeout(boot, 600); setTimeout(boot, 1600); });
})();
'@

$voicePath = Join-Path $modDir "ls-voice-controller.js"
[System.IO.File]::WriteAllText($voicePath, $voiceJs, $u)
node --check $voicePath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-voice-controller.js!" }
Write-Host "[PASS] www/js/modules/ls-voice-controller.js installed & verified (0 errors)." -ForegroundColor Green

Write-Host "`n=== 2. Rebuilding AI Indian Professor Module (Live Voice Engine Sync) ===" -ForegroundColor Cyan
$profJs = @'
(function () {
  "use strict";
  if (window.__lsIndianProfessorV321) return;
  window.__lsIndianProfessorV321 = true;

  var AUDIO_CACHE = "ls-prof-audio-v1", CDN_BASE = "https://law-studyes.vercel.app";
  var manifest = null, htmlAudio = null, playing = false, paused = false, curIdx = 0, sentences = [], token = 0;

  function vc() { return window.LSVoiceController || null; }
  function getEng() { return vc() ? vc().getEngine() : "studio"; }
  function getGen() { return vc() ? vc().getGender() : "female"; }
  function getRate() { return vc() ? vc().getRate() : 1.0; }
  function getPitch() { return vc() ? vc().getPitch() : 1.0; }
  function bcp47(l) { return vc() ? vc().langToBcp47(l) : (l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN")); }
  function clean(s) { return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim(); }

  function topicTitle(tid) {
    try { var m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; if (m && m.topic && m.topic.title) return m.topic.title; } catch (e) {}
    return String(tid || "Topic").replace(/-/g, " ");
  }

  function buildLesson(tid, lang) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return null;
    var ld = rec[lang] || rec.en;
    if (!ld) return null;
    var t = topicTitle(tid), m1 = clean(ld.inOneMinute), pr = clean(ld.legalProvision), mn = clean(ld.meaning);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.slice(0, 5).map(function (x) { return clean(typeof x === "string" ? x : (x && (x.point || x.text || x.summary))); }).filter(Boolean) : [];
    var c0 = Array.isArray(ld.caseLaws) && ld.caseLaws[0];
    var topCase = !c0 ? "" : (typeof c0 === "string" ? clean(c0) : (clean(c0.name || c0.title) + (c0.principle || c0.summary ? " - " + clean(c0.principle || c0.summary) : "")));

    if (lang === "te") {
      return {
        heading: "\u0c07\u0c02\u0c21\u0c3f\u0c2f\u0c28\u0c4d \u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d (AI Teaching Mode)",
        sub: "\u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d \u0c35\u0c3f\u0c35\u0c30\u0c23 + \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d\u0c38\u0c4d",
        steps: [
          { tag: "\u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d", text: "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d! \u0c08\u0c30\u0c4b\u0c1c\u0c41 " + t + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d\u200c\u0c17\u0c3e \u0c28\u0c47\u0c30\u0c4d\u0c1a\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." },
          m1 ? { tag: "\u0c38\u0c3e\u0c30\u0c3e\u0c02\u0c36\u0c02", text: m1 } : null,
          pr ? { tag: "\u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d", text: pr } : null,
          mn ? { tag: "\u0c35\u0c3f\u0c35\u0c30\u0c23", text: mn } : null,
          pts.length ? { tag: "\u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41", text: pts.join(" | ") } : null,
          topCase ? { tag: "\u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e", text: topCase } : null
        ].filter(Boolean)
      };
    }
    if (lang === "hi") {
      return {
        heading: "\u0907\u0902\u0921\u093f\u092f\u0928 \u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e (AI Teaching Mode)",
        sub: "\u0906\u0938\u093e\u0928 \u0939\u093f\u0902\u0926\u0940 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0938\u092e\u091d + \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u094d\u0930\u093f\u0915\u094d\u0938",
        steps: [
          { tag: "\u0915\u094d\u0932\u093e\u0938", text: "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938! \u0906\u091c \u0939\u092e " + t + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0905\u0902\u0926\u093e\u091c \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" },
          m1 ? { tag: "\u0915\u0949\u0928\u094d\u0938\u0947\u092a\u094d\u091f", text: m1 } : null,
          pr ? { tag: "\u0938\u0947\u0915\u094d\u0936\u0928", text: pr } : null,
          mn ? { tag: "\u0905\u0930\u094d\u0925", text: mn } : null,
          pts.length ? { tag: "\u092a\u0949\u0907\u0902\u091f\u094d\u0938", text: pts.join(" | ") } : null,
          topCase ? { tag: "\u0915\u0947\u0938 \u0932\u0949", text: topCase } : null
        ].filter(Boolean)
      };
    }
    return {
      heading: "Indian Professor Classroom (AI Teaching Mode)",
      sub: "Relatable Indian LL.B. classroom explanation + exam answer strategy",
      steps: [
        { tag: "Class Start", text: "Hello students! Let us understand " + t + " in simple Indian classroom style." },
        m1 ? { tag: "1-Min Core", text: m1 } : null,
        pr ? { tag: "Section Hook", text: pr } : null,
        mn ? { tag: "Plain Meaning", text: mn } : null,
        pts.length ? { tag: "Scoring Points", text: pts.join(" | ") } : null,
        topCase ? { tag: "Landmark Case", text: topCase } : null
      ].filter(Boolean)
    };
  }

  function injectCss() {
    if (document.getElementById("lsProfCssV321")) return;
    var st = document.createElement("style");
    st.id = "lsProfCssV321";
    st.textContent =
      ".ls-prof-card{margin:14px 0 16px;border-radius:16px;background:linear-gradient(135deg,#FFFBF2 0%,#FDF4F5 100%);border:1.5px solid #E5C9A8;padding:12px 14px}" +
      ".ls-prof-title{font-size:13.5px;font-weight:800;color:#7B1E2B}.ls-prof-sub{font-size:11px;color:#6B5B4D;font-weight:600}" +
      ".ls-prof-controls{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:10px}" +
      ".ls-prof-btn,.ls-prof-sel{padding:6px 10px;border-radius:999px;border:1px solid #DFC5A4;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:800;cursor:pointer}" +
      ".ls-prof-btn.primary{background:#7B1E2B;color:#FFF;border-color:#7B1E2B}.ls-prof-btn.active{background:#8C6D46;color:#FFF;border-color:#8C6D46}" +
      ".ls-prof-status{font-size:11px;color:#7B1E2B;font-weight:700;margin-top:8px}.ls-prof-body{margin-top:10px;display:flex;flex-direction:column;gap:7px}" +
      ".ls-prof-step{background:#FFF;border:1px solid #EFE4D6;border-left:3.5px solid #7B1E2B;border-radius:10px;padding:8px 10px;font-size:12.5px;line-height:1.55}" +
      ".ls-prof-step.speaking{background:#FFF7E6;border-left-color:#B45309}.ls-prof-tag{display:inline-block;font-size:10px;font-weight:800;color:#7B1E2B;background:#FBF1F2;padding:2px 7px;border-radius:999px;margin-bottom:4px}";
    document.head.appendChild(st);
  }

  async function getManifest() {
    if (manifest !== null) return manifest;
    manifest = {};
    try { var r = await fetch("./audio/manifest.json", { cache: "no-store" }); if (r.ok) manifest = await r.json(); } catch (e) {}
    return manifest;
  }

  function setStatus(msg) { var el = document.getElementById("lsProfStatus"); if (el) el.textContent = msg || ""; }
  function highlight(idx) { document.querySelectorAll("#lsProfLessonBody .ls-prof-step").forEach(function (el, i) { el.classList.toggle("speaking", i === idx); }); }

  function syncBtns() {
    var p = document.getElementById("lsProfPlayBtn"), s = document.getElementById("lsProfStopBtn"),
        f = document.getElementById("lsProfVoiceFemBtn"), m = document.getElementById("lsProfVoiceMaleBtn"),
        e = document.getElementById("lsProfEngineSel");
    if (p) p.textContent = playing ? (paused ? "Resume Class" : "Pause Class") : "Listen to Professor";
    if (s) s.style.display = (playing || paused) ? "inline-block" : "none";
    if (f) f.classList.toggle("active", getGen() === "female");
    if (m) m.classList.toggle("active", getGen() === "male");
    if (e) e.value = getEng();
  }

  function stopAudio() {
    token++; playing = false; paused = false;
    if (htmlAudio) { try { htmlAudio.pause(); htmlAudio.currentTime = 0; } catch (e) {} htmlAudio = null; }
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && tts.stop) { try { tts.stop().catch(function () {}); } catch (e) {} }
    if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
    syncBtns(); highlight(-1);
  }

  async function tryMp3(tid, lang, tk) {
    if (getEng() !== "studio" || getGen() !== "female") return false;
    var mf = await getManifest();
    var rel = (mf && mf[lang] && mf[lang][tid]) ? mf[lang][tid] : null;
    if (!rel) return false;
    var urls = [rel, CDN_BASE + "/" + rel.replace(/^\.\//, "")];
    for (var i = 0; i < urls.length; i++) {
      try {
        var u = urls[i], playUrl = u;
        if ("caches" in window) {
          var c = await caches.open(AUDIO_CACHE), hit = await c.match(u);
          if (hit) playUrl = URL.createObjectURL(await hit.blob());
          else {
            var resp = await fetch(u);
            if (!resp.ok) continue;
            try { c.put(u, resp.clone()); } catch (e) {}
            playUrl = URL.createObjectURL(await resp.blob());
          }
        }
        if (tk !== token) return true;
        htmlAudio = new Audio(playUrl);
        htmlAudio.playbackRate = getRate();
        htmlAudio.onended = function () { playing = false; paused = false; setStatus("Class completed (Studio MP3)."); syncBtns(); };
        await htmlAudio.play();
        playing = true; paused = false;
        setStatus("Playing Studio Human MP3 (" + getRate() + "x)");
        syncBtns();
        return true;
      } catch (e) {}
    }
    return false;
  }

  async function speakOne(text, lang) {
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && typeof tts.speak === "function") {
      await tts.speak({ text: text, lang: bcp47(lang), rate: getRate(), pitch: getPitch(), volume: 1.0, category: "ambient" });
      return;
    }
    if ("speechSynthesis" in window) {
      await new Promise(function (resolve) {
        try { var u = new SpeechSynthesisUtterance(text); u.lang = bcp47(lang); u.onend = resolve; u.onerror = resolve; window.speechSynthesis.speak(u); }
        catch (e) { resolve(); }
      });
    }
  }

  async function loopSpeak(startAt) {
    var tk = ++token, lang = (typeof state !== "undefined" && state.lang) ? state.lang : "en";
    playing = true; paused = false; syncBtns();
    setStatus("Active: " + getEng().toUpperCase() + " | " + (getGen() === "male" ? "Sir" : "Ma'am") + " | " + bcp47(lang) + " | " + getRate() + "x");
    for (var i = startAt; i < sentences.length; i++) {
      if (tk !== token) return;
      curIdx = i; highlight(i);
      await speakOne(sentences[i], lang);
      if (tk !== token) return;
      await new Promise(function (r) { setTimeout(r, 200); });
    }
    if (tk === token) { playing = false; paused = false; highlight(-1); setStatus("Classroom explanation complete!"); syncBtns(); }
  }

  async function play(resumeIdx) {
    if (typeof state === "undefined" || !state.activeTopicId) return;
    if (typeof resumeIdx !== "number" && playing && !paused) {
      paused = true;
      if (htmlAudio) { try { htmlAudio.pause(); } catch (e) {} }
      else {
        token++;
        var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
        if (tts && tts.stop) { try { tts.stop().catch(function () {}); } catch (e) {} }
        if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
      }
      setStatus("Class paused."); syncBtns(); return;
    }
    if (typeof resumeIdx !== "number" && playing && paused) {
      paused = false;
      if (htmlAudio) { htmlAudio.playbackRate = getRate(); try { await htmlAudio.play(); } catch (e) {} syncBtns(); return; }
      loopSpeak(curIdx); return;
    }
    if (window.LSAudioEngine && window.LSAudioEngine.stop) window.LSAudioEngine.stop();
    stopAudio();
    var tk = ++token, tid = state.activeTopicId, lang = state.lang || "en";
    var body = document.getElementById("lsProfLessonBody");
    if (body) body.style.display = "flex";
    var lesson = buildLesson(tid, lang);
    if (!lesson || !lesson.steps.length) return;
    sentences = lesson.steps.map(function (s) { return s.text; });
    curIdx = (typeof resumeIdx === "number" && resumeIdx >= 0 && resumeIdx < sentences.length) ? resumeIdx : 0;
    if (curIdx === 0 && await tryMp3(tid, lang, tk)) return;
    loopSpeak(curIdx);
  }

  window.addEventListener("ls:voice-settings-changed", function () {
    syncBtns();
    if (!playing || paused) return;
    if (htmlAudio && getEng() === "studio" && getGen() === "female") {
      htmlAudio.playbackRate = getRate();
      setStatus("Updated Studio MP3 speed (" + getRate() + "x)");
      return;
    }
    var idx = curIdx;
    stopAudio();
    setTimeout(function () { play(idx); }, 130);
  });

  function renderCard() {
    try {
      injectCss();
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane");
      if (!pane) return;
      var old = document.getElementById("lsIndianProfessorCard"); if (old) old.remove();
      var lesson = buildLesson(state.activeTopicId, state.lang || "en");
      if (!lesson) return;

      var card = document.createElement("section");
      card.id = "lsIndianProfessorCard"; card.className = "ls-prof-card";
      card.innerHTML =
        '<div class="ls-prof-title">' + lesson.heading + '</div><div class="ls-prof-sub">' + lesson.sub + '</div>' +
        '<div class="ls-prof-controls">' +
          '<button type="button" id="lsProfPlayBtn" class="ls-prof-btn primary">Listen to Professor</button>' +
          '<button type="button" id="lsProfStopBtn" class="ls-prof-btn" style="display:none;">Stop</button>' +
          '<select id="lsProfEngineSel" class="ls-prof-sel">' +
            '<option value="studio">Engine: Studio MP3</option><option value="neural">Engine: Indian Neural</option><option value="device">Engine: Offline Device</option>' +
          '</select>' +
          '<button type="button" id="lsProfVoiceFemBtn" class="ls-prof-btn">Ma\'am</button>' +
          '<button type="button" id="lsProfVoiceMaleBtn" class="ls-prof-btn">Sir</button>' +
          '<button type="button" id="lsProfTestBtn" class="ls-prof-btn">Test Voice</button>' +
          '<button type="button" id="lsProfToggleBodyBtn" class="ls-prof-btn">Show Notes</button>' +
        '</div>' +
        '<div id="lsProfStatus" class="ls-prof-status"></div><div id="lsProfLessonBody" class="ls-prof-body" style="display:none;"></div>';

      var body = card.querySelector("#lsProfLessonBody");
      lesson.steps.forEach(function (st) {
        var r = document.createElement("div"); r.className = "ls-prof-step";
        r.innerHTML = '<span class="ls-prof-tag">' + st.tag.replace(/</g, "&lt;") + '</span><div>' + st.text.replace(/</g, "&lt;") + '</div>';
        body.appendChild(r);
      });

      card.querySelector("#lsProfPlayBtn").addEventListener("click", function () { play(); });
      card.querySelector("#lsProfStopBtn").addEventListener("click", stopAudio);
      card.querySelector("#lsProfEngineSel").addEventListener("change", function (ev) { if (vc()) vc().applySettings({ engine: ev.target.value, voiceId: "auto" }, true); });
      card.querySelector("#lsProfVoiceFemBtn").addEventListener("click", function () { if (vc()) vc().applySettings({ gender: "female", voiceId: "auto" }, true); });
      card.querySelector("#lsProfVoiceMaleBtn").addEventListener("click", function () { if (vc()) vc().applySettings({ gender: "male", voiceId: "auto" }, true); });
      card.querySelector("#lsProfTestBtn").addEventListener("click", function () { if (vc()) vc().testVoice(); });
      card.querySelector("#lsProfToggleBodyBtn").addEventListener("click", function (ev) {
        var open = body.style.display !== "none";
        body.style.display = open ? "none" : "flex";
        ev.currentTarget.textContent = open ? "Show Notes" : "Hide Notes";
      });

      var copyBar = document.getElementById("lsNoteCopyBar");
      if (copyBar && copyBar.parentNode === pane) copyBar.insertAdjacentElement("afterend", card);
      else pane.insertBefore(card, pane.firstChild);
      syncBtns();
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsProfHookV321) {
        window.__lsProfHookV321 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { stopAudio(); var r = orig.apply(this, arguments); renderCard(); return r; };
        renderCard();
      }
    } catch (e) {}
  }

  window.addEventListener("ls:lang-changed", stopAudio);
  window.LSIndianProfessor = { play: play, stop: stopAudio };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 400); setTimeout(hook, 1250); });
})();
'@

$profPath = Join-Path $modDir "ls-indian-professor.js"
[System.IO.File]::WriteAllText($profPath, $profJs, $u)
node --check $profPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-indian-professor.js!" }
Write-Host "[PASS] www/js/modules/ls-indian-professor.js rebuilt & verified (0 errors)." -ForegroundColor Green

Write-Host "`n=== 3. Rebuilding Downloads inside .md Window + Ask Save Location with Topic Name ===" -ForegroundColor Cyan
$pdfJs = @'
(function () {
  "use strict";
  if (window.__lsPdfExportV321) return;
  window.__lsPdfExportV321 = true;

  var LBL = {
    en: { med: "English Medium", m1: "In One Minute", pr: "Legal Provision", mn: "Meaning", pts: "Key Scoring Points", cs: "Leading Case Laws", dg: "Original Diagrams & Tables" },
    te: { med: "\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c2e\u0c40\u0c21\u0c3f\u0c2f\u0c02", m1: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b", pr: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28", mn: "\u0c05\u0c30\u0c4d\u0c25\u0c02", pts: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c05\u0c02\u0c36\u0c3e\u0c32\u0c41", cs: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41\u0c32\u0c41", dg: "\u0c05\u0c38\u0c32\u0c41 \u0c21\u0c2f\u0c3e\u0c17\u0c4d\u0c30\u0c2e\u0c4d\u200c\u0c32\u0c41" },
    hi: { med: "\u0939\u093f\u0928\u094d\u0926\u0940 \u092e\u093e\u0927\u094d\u092f\u092e", m1: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902", pr: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928", mn: "\u0905\u0930\u094d\u0925", pts: "\u092e\u0941\u0916\u094d\u092f \u092c\u093f\u0902\u0926\u0941", cs: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0928\u094d\u092f\u093e\u092f\u093f\u0915 \u0928\u093f\u0930\u094d\u0923\u092f", dg: "\u092e\u0942\u0932 \u0906\u0930\u0947\u0916 \u0914\u0930 \u0924\u093e\u0932\u093f\u0915\u093e\u090f\u0902" }
  };

  function esc(s) { return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
  function isDual() { try { return localStorage.getItem("ls_dual_mode_v1") === "1"; } catch (e) { return false; } }
  function safeTopicName(title, lang, suffix) {
    var base = String(title || "LawStudyes-Topic").replace(/[<>:"/\\|?*\x00-\x1F]+/g, "").replace(/\s+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "").slice(0, 75) || "LawStudyes-Topic";
    return base + "-" + String(lang || "en").toUpperCase() + (suffix ? "-" + suffix : "");
  }

  function showSaveStatus(msg) {
    var el = document.getElementById("lsDownloadSaveStatus");
    if (el) { el.textContent = msg; el.style.display = "block"; }
    if (typeof showToast === "function") showToast(msg);
  }

  async function saveWithFolderPrompt(content, fileName, mimeType, ext, desc) {
    if (typeof window.showSaveFilePicker === "function") {
      try {
        var opts = { suggestedName: fileName };
        if (ext && mimeType) {
          var acc = {}; acc[mimeType] = ["." + ext.replace(/^\./, "")];
          opts.types = [{ description: desc || "Study Notes", accept: acc }];
        }
        var handle = await window.showSaveFilePicker(opts);
        var w = await handle.createWritable();
        await w.write(content);
        await w.close();
        showSaveStatus("Saved \"" + handle.name + "\" to your selected folder!");
        return true;
      } catch (err) {
        if (err && err.name === "AbortError") { showSaveStatus("Save cancelled."); return false; }
      }
    }

    var capFs = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Filesystem;
    var capShare = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Share;
    if (capFs && typeof capFs.writeFile === "function") {
      var b64 = btoa(unescape(encodeURIComponent(content))), uri = null, loc = "Documents/LawStudyes/" + fileName;
      try {
        var w1 = await capFs.writeFile({ path: "LawStudyes/" + fileName, data: b64, directory: "DOCUMENTS", recursive: true });
        uri = w1 && w1.uri;
      } catch (e1) {
        try {
          var w2 = await capFs.writeFile({ path: fileName, data: b64, directory: "CACHE" });
          uri = w2 && w2.uri;
          loc = "Choose folder in Save/Share popup (" + fileName + ")";
        } catch (e2) {}
      }
      if (uri) {
        showSaveStatus("Saved: " + loc);
        if (capShare && typeof capShare.share === "function") {
          try { await capShare.share({ title: fileName, text: "Choose folder or app to save " + fileName, url: uri, dialogTitle: "Save " + fileName + " to..." }); } catch (e) {}
        }
        return true;
      }
    }

    try {
      var blob = new Blob([content], { type: (mimeType || "text/plain") + ";charset=utf-8" });
      var url = URL.createObjectURL(blob), a = document.createElement("a");
      a.href = url; a.download = fileName; document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { try { URL.revokeObjectURL(url); } catch (e) {} }, 2500);
      showSaveStatus("Saved \"" + fileName + "\" to your device's Downloads folder.");
      return true;
    } catch (e) { return false; }
  }

  function getVisualsHtml(tid, rec) {
    try {
      if (typeof state !== "undefined" && state.activeTopicId === tid) {
        var live = document.getElementById("lsAsIsDiagramsSection") || document.getElementById("lsSourceVisualsSection");
        if (live) {
          var cards = live.querySelectorAll(".ls-asis-card, .ls-src-vis-card"), out = [];
          cards.forEach(function (c) {
            var cap = c.querySelector(".ls-asis-head div, .ls-src-vis-head div");
            var stg = c.querySelector(".ls-asis-stage, .ls-src-vis-box");
            if (stg && stg.innerHTML.trim()) out.push('<div class="pdf-vis-card"><div class="pdf-vis-cap">' + esc(cap ? cap.textContent : "Diagram") + '</div><div class="pdf-vis-stage">' + stg.innerHTML + '</div></div>');
          });
          if (out.length) return out.join("");
        }
      }
    } catch (e) {}
    var vis = (rec && rec.en && Array.isArray(rec.en.visuals)) ? rec.en.visuals : [], arr = [];
    for (var i = 0; i < vis.length; i++) {
      var v = vis[i]; if (!v || !v.html) continue;
      arr.push('<div class="pdf-vis-card"><div class="pdf-vis-cap">' + esc(v.caption || ("Diagram " + (i + 1))) + '</div><div class="pdf-vis-stage">' + v.html + '</div></div>');
    }
    return arr.join("");
  }

  function buildTopicHtml(tid, title, subj, unitLbl, lang, dual) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return "";
    var ld = rec[lang] || rec.en; if (!ld) return "";
    var l = LBL[lang] || LBL.en, p = ['<article class="pdf-topic">'];
    p.push('<div class="pdf-meta">' + esc(subj) + (unitLbl ? " &middot; " + esc(unitLbl) : "") + ' &middot; ' + esc(l.med) + '</div>');
    p.push('<h1 class="pdf-title">' + esc(title) + '</h1>');
    if (ld.inOneMinute) p.push('<div class="pdf-box highlight"><h2>' + esc(l.m1) + '</h2><p>' + esc(ld.inOneMinute) + '</p></div>');
    if (ld.legalProvision) p.push('<div class="pdf-box"><h2>' + esc(l.pr) + '</h2><p>' + esc(ld.legalProvision) + '</p></div>');
    if (ld.meaning) p.push('<div class="pdf-box"><h2>' + esc(l.mn) + '</h2><p>' + esc(ld.meaning) + '</p></div>');
    if (Array.isArray(ld.keyPoints) && ld.keyPoints.length) {
      p.push('<div class="pdf-box"><h2>' + esc(l.pts) + '</h2><ul>' + ld.keyPoints.map(function (x) { return '<li>' + esc(typeof x === "string" ? x : (x.point || x.text || x.summary || JSON.stringify(x))) + '</li>'; }).join("") + '</ul></div>');
    }
    if (Array.isArray(ld.caseLaws) && ld.caseLaws.length) {
      p.push('<div class="pdf-box"><h2>' + esc(l.cs) + '</h2><ul>' + ld.caseLaws.map(function (c) {
        if (typeof c === "string") return '<li>' + esc(c) + '</li>';
        return c ? ('<li><strong>' + esc(c.name || c.title || "") + '</strong>' + (c.principle || c.summary ? ': ' + esc(c.principle || c.summary) : '') + '</li>') : '';
      }).join("") + '</ul></div>');
    }
    if (dual && lang !== "en" && rec.en) {
      p.push('<div class="pdf-box dual"><h2>English Exam Reference</h2>');
      if (rec.en.legalProvision) p.push('<p><strong>Provision:</strong> ' + esc(rec.en.legalProvision) + '</p>');
      if (rec.en.inOneMinute) p.push('<p><strong>Summary:</strong> ' + esc(rec.en.inOneMinute) + '</p>');
      p.push('</div>');
    }
    var vh = getVisualsHtml(tid, rec);
    if (vh) p.push('<div class="pdf-vis-wrap"><h2>' + esc(l.dg) + '</h2>' + vh + '</div>');
    p.push('</article>');
    return p.join("");
  }

  function buildTopicMd(tid, title, subj, unitLbl, lang, dual) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return "";
    var ld = rec[lang] || rec.en; if (!ld) return "";
    var out = ["# " + title, "*" + subj + (unitLbl ? " | " + unitLbl : "") + " | " + String(lang || "en").toUpperCase() + "*", ""];
    if (ld.inOneMinute) out.push("## In One Minute\n" + ld.inOneMinute + "\n");
    if (ld.legalProvision) out.push("## Legal Provision\n" + ld.legalProvision + "\n");
    if (ld.meaning) out.push("## Meaning\n" + ld.meaning + "\n");
    if (Array.isArray(ld.keyPoints) && ld.keyPoints.length) {
      out.push("## Key Points");
      ld.keyPoints.forEach(function (x) { out.push("- " + (typeof x === "string" ? x : (x.point || x.text || x.summary || JSON.stringify(x)))); });
      out.push("");
    }
    if (Array.isArray(ld.caseLaws) && ld.caseLaws.length) {
      out.push("## Leading Case Laws");
      ld.caseLaws.forEach(function (c) { out.push(typeof c === "string" ? ("- " + c) : ("- **" + (c.name || c.title || "") + "**: " + (c.principle || c.summary || ""))); });
      out.push("");
    }
    if (dual && lang !== "en" && rec.en) {
      out.push("---\n## English Exam Reference");
      if (rec.en.legalProvision) out.push("**Provision:** " + rec.en.legalProvision);
      if (rec.en.inOneMinute) out.push("**Summary:** " + rec.en.inOneMinute);
    }
    return out.join("\n");
  }

  function wrapA4(docTitle, bodyHtml) {
    var dt = new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
    return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width,initial-scale=1.0" /><title>' + esc(docTitle) + '</title>' +
      '<style>@page{size:A4;margin:14mm 13mm}*{box-sizing:border-box}body{font-family:"Noto Sans Telugu","Noto Sans Devanagari","Nirmala UI","Segoe UI",Roboto,Arial,sans-serif;color:#1A1715;background:#FFF;margin:0;padding:18px;line-height:1.58;font-size:12.5px}' +
      '.pdf-toolbar{position:sticky;top:0;display:flex;justify-content:space-between;align-items:center;padding:10px 14px;margin-bottom:14px;background:#7B1E2B;color:#FFF;border-radius:10px}.pdf-toolbar button{padding:7px 14px;border:0;border-radius:8px;background:#FFF;color:#7B1E2B;font-weight:800;cursor:pointer}' +
      '.pdf-header{display:flex;justify-content:space-between;border-bottom:2px solid #7B1E2B;padding-bottom:8px;margin-bottom:14px}.pdf-brand{font-family:Georgia,serif;font-size:20px;font-weight:800;color:#7B1E2B}' +
      '.pdf-topic{page-break-after:always}.pdf-topic:last-child{page-break-after:auto}.pdf-meta{font-size:11px;font-weight:700;color:#8C6D46;text-transform:uppercase}.pdf-title{font-family:Georgia,serif;font-size:19px;color:#7B1E2B;margin:4px 0 12px}' +
      '.pdf-box{border:1px solid #E4DBD0;border-radius:8px;padding:10px 12px;margin-bottom:10px;break-inside:avoid}.pdf-box.highlight{background:#FBF6EE;border-color:#DFC5A4}.pdf-box.dual{background:#FAF7F2;border:1.5px dashed #B89D7A}' +
      '.pdf-box h2,.pdf-vis-wrap>h2{font-size:13px;color:#7B1E2B;margin:0 0 6px;border-bottom:1px solid #EFE7DC;padding-bottom:3px}.pdf-vis-card{border:1px solid #DDD2C5;border-radius:8px;padding:10px;margin-bottom:10px;break-inside:avoid}' +
      '.pdf-vis-cap{font-size:11.5px;font-weight:800;color:#7B1E2B;margin-bottom:6px}.pdf-vis-stage svg,.pdf-vis-stage img{max-width:100%!important;height:auto!important;display:block;margin:0 auto}' +
      '.pdf-vis-stage table{width:100%;border-collapse:collapse;font-size:11.5px}.pdf-vis-stage th{background:#FBF1F2;color:#7B1E2B;border:1px solid #DFC9CC;padding:6px}.pdf-vis-stage td{border:1px solid #E4DBD0;padding:6px}' +
      '@media print{body{padding:0}.pdf-toolbar{display:none!important}}</style></head><body>' +
      '<div class="pdf-toolbar"><span><strong>Law Studyes</strong> &middot; ' + esc(docTitle) + '</span><button onclick="window.print()">Print / Save as PDF</button></div>' +
      '<div class="pdf-header"><div class="pdf-brand">&#9878; Law Studyes</div><div style="font-size:11px;color:#5F554E">' + esc(dt) + '</div></div>' + bodyHtml + '</body></html>';
  }

  function ctx() {
    if (typeof state === "undefined" || !state.activeTopicId) return null;
    var tid = state.activeTopicId, lang = state.lang || "en", m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null;
    return {
      tid: tid, lang: lang, meta: m,
      title: (m && m.topic && m.topic.title) || tid,
      subj: (m && m.subject && m.subject.title) || "3-Year LL.B.",
      unitLbl: (m && m.unit) ? ("Unit " + (m.unit.unitNo || "") + (m.unit.title ? ": " + m.unit.title : "")) : ""
    };
  }

  function printPdf(html, fname) {
    var isCap = !!(window.Capacitor && typeof window.Capacitor.isNativePlatform === "function" && window.Capacitor.isNativePlatform());
    if (isCap) { saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); return; }
    var prev = document.title;
    try {
      document.title = fname;
      var old = document.getElementById("lsPdfPrintFrame"); if (old) old.remove();
      var fr = document.createElement("iframe"); fr.id = "lsPdfPrintFrame";
      fr.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;";
      document.body.appendChild(fr);
      var d = fr.contentWindow.document; d.open(); d.write(html); d.close();
      setTimeout(function () {
        try {
          fr.contentWindow.focus(); fr.contentWindow.print();
          showSaveStatus("Select 'Save as PDF' & pick your folder -> pre-filled filename: \"" + fname + ".pdf\"");
        } catch (err) { saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); }
        finally { setTimeout(function () { document.title = prev; }, 1500); }
      }, 280);
    } catch (e) { document.title = prev; saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); }
  }

  function exportPdf() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, ""); printPdf(wrapA4(fn, buildTopicHtml(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual())), fn); }
  function exportHtml() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, "HardCopy"); saveWithFolderPrompt(wrapA4(fn, buildTopicHtml(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual())), fn + ".html", "text/html", "html", "Printable Study Sheet (.html)"); }
  function exportMd() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, ""); saveWithFolderPrompt(buildTopicMd(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual()), fn + ".md", "text/markdown", "md", "Markdown Study Notes (.md)"); }
  function exportUnit() {
    var c = ctx(); if (!c || !c.meta || !c.meta.unit || !Array.isArray(c.meta.unit.topics)) { exportPdf(); return; }
    var secs = c.meta.unit.topics.map(function (t) { return t && t.id ? buildTopicHtml(t.id, t.title || t.id, c.subj, c.unitLbl, c.lang, isDual()) : ""; }).filter(Boolean);
    if (!secs.length) return;
    var fn = safeTopicName(c.subj + "-Unit" + (c.meta.unit.unitNo || "1"), c.lang, "Booklet");
    printPdf(wrapA4(fn, secs.join("")), fn);
  }

  function findMdHost() {
    var els = document.querySelectorAll("button, a");
    for (var i = 0; i < els.length; i++) {
      var b = els[i];
      if (b.id && b.id.indexOf("lsUnifiedDl") === 0) continue;
      var txt = String(b.textContent || "").trim(), meta = String(b.id || "") + " " + String(b.getAttribute("onclick") || "");
      if (/\.(md)\b/i.test(txt) || /markdown/i.test(txt) || /exportmd|downloadmd/i.test(meta)) return { btn: b, box: b.parentElement };
    }
    return null;
  }

  function createUnifiedBar() {
    var b1 = "padding:6px 10px;border-radius:9px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11.5px;font-weight:800;cursor:pointer;";
    var b2 = "padding:6px 10px;border-radius:9px;border:1px solid #C7B299;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:700;cursor:pointer;";
    var w = document.createElement("div");
    w.id = "lsUnifiedDownloadsWrap";
    w.style.cssText = "display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:6px;";
    w.innerHTML =
      '<button type="button" id="lsUnifiedDlPdfBtn" style="' + b1 + '">Download PDF (Hard Copy)</button>' +
      '<button type="button" id="lsUnifiedDlUnitBtn" style="' + b2 + '">Unit PDF Booklet</button>' +
      '<button type="button" id="lsUnifiedDlHtmlBtn" style="' + b2 + '">Save Print File (.html)</button>' +
      '<button type="button" id="lsUnifiedDlMdBtn" style="' + b2 + '">Save .md (Choose Folder)</button>' +
      '<div id="lsDownloadSaveStatus" style="display:none;width:100%;margin-top:4px;padding:6px 8px;border-radius:8px;background:#EEF7EE;border:1px solid #B7DDB9;color:#1F5C24;font-size:11px;font-weight:700;"></div>';
    w.querySelector("#lsUnifiedDlPdfBtn").addEventListener("click", exportPdf);
    w.querySelector("#lsUnifiedDlUnitBtn").addEventListener("click", exportUnit);
    w.querySelector("#lsUnifiedDlHtmlBtn").addEventListener("click", exportHtml);
    w.querySelector("#lsUnifiedDlMdBtn").addEventListener("click", exportMd);
    return w;
  }

  function mountInMdWindow() {
    try {
      ["lsPdfTopicBtn", "lsPdfUnitBtn", "lsPdfXeroxBtn"].forEach(function (id) { var x = document.getElementById(id); if (x) x.remove(); });
      var found = findMdHost();
      if (found && found.box) {
        if (found.btn && !found.btn.__lsMdSaveAsBound) {
          found.btn.__lsMdSaveAsBound = true;
          found.btn.addEventListener("click", function (ev) {
            if (typeof state !== "undefined" && state.activeTopicId) { ev.preventDefault(); ev.stopImmediatePropagation(); exportMd(); }
          }, true);
        }
        if (!found.box.querySelector("#lsUnifiedDownloadsWrap")) {
          var prev = document.getElementById("lsUnifiedDownloadsWrap"); if (prev) prev.remove();
          found.box.appendChild(createUnifiedBar());
        }
        return;
      }
      var pane = document.getElementById("readingPane");
      if (!pane || typeof state === "undefined" || !state.activeTopicId || document.getElementById("lsUnifiedDownloadsWrap")) return;
      var bar = document.getElementById("lsNoteCopyBar");
      if (!bar) {
        bar = document.createElement("div"); bar.id = "lsNoteCopyBar";
        bar.style.cssText = "display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:12px;padding:8px 10px;border-radius:12px;background:#FAF7F2;border:1px solid #E8E0D5;";
        pane.insertBefore(bar, pane.firstChild);
      }
      bar.appendChild(createUnifiedBar());
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsPdfHookV321) {
        window.__lsPdfHookV321 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(mountInMdWindow, 40); return r; };
      }
      mountInMdWindow();
      if (!window.__lsDlObsV321 && typeof MutationObserver !== "undefined" && document.body) {
        window.__lsDlObsV321 = true;
        new MutationObserver(mountInMdWindow).observe(document.body, { childList: true, subtree: true });
      }
    } catch (e) {}
  }

  window.LSPdfExport = { exportTopic: exportPdf, exportUnit: exportUnit, exportHtml: exportHtml, exportMd: exportMd, safeTopicName: safeTopicName };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 350); setTimeout(hook, 1200); });
})();
'@

$pdfPath = Join-Path $modDir "ls-pdf-export.js"
[System.IO.File]::WriteAllText($pdfPath, $pdfJs, $u)
node --check $pdfPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-pdf-export.js!" }
Write-Host "[PASS] www/js/modules/ls-pdf-export.js rebuilt & verified (0 errors)." -ForegroundColor Green

Write-Host "`n=== 4. Re-Binding All Modules into www/js/ls-app-bundle.js (v$Version) ===" -ForegroundColor Cyan
$priority = @(
  "ls-store.js", "ls-trilingual.js", "ls-voice-controller.js",
  "ls-audio-engine.js", "ls-audio-mini.js", "ls-audio-window.js",
  "ls-diagrams.js", "ls-note-converter.js", "ls-indian-professor.js", "ls-pdf-export.js"
)
$allMods = Get-ChildItem $modDir -Filter "*.js" -File | Sort-Object Name
$ordered = New-Object System.Collections.Generic.List[System.IO.FileInfo]
foreach ($pName in $priority) {
  $m = $allMods | Where-Object { $_.Name -eq $pName } | Select-Object -First 1
  if ($m) { $ordered.Add($m) }
}
foreach ($mf in $allMods) {
  if ($priority -notcontains $mf.Name) { $ordered.Add($mf) }
}

$parts = New-Object System.Collections.Generic.List[string]
$parts.Add("/* Law Studyes v$Version - Unified Crash-Safe Module Bundle (Built $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) */")
foreach ($mf in $ordered) {
  $chk = node --check $mf.FullName 2>&1
  if ($LASTEXITCODE -ne 0) { throw "JS syntax error in $($mf.Name): $chk" }
  $src = [System.IO.File]::ReadAllText($mf.FullName, $u)
  $parts.Add("`r`n/* === MODULE: $($mf.Name) === */`r`ntry {`r`n$src`r`n} catch (__lsModErr) { console.error('[LS Module Error: $($mf.Name)]', __lsModErr); }")
  Write-Host "  [BOUND] $($mf.Name) ($([Math]::Round($mf.Length / 1KB, 1)) KB)" -ForegroundColor Green
}

$bundlePath = Join-Path $jsDir "ls-app-bundle.js"
[System.IO.File]::WriteAllText($bundlePath, ($parts -join "`r`n"), $u)
$bChk = node --check $bundlePath 2>&1
if ($LASTEXITCODE -ne 0) { throw "Unified bundle syntax error: $bChk" }
Write-Host "[PASS] Bound $($ordered.Count) modules -> www/js/ls-app-bundle.js ($([Math]::Round((Get-Item $bundlePath).Length / 1KB, 1)) KB, 0 errors)" -ForegroundColor Green

$idxPath = Join-Path $wwwDir "index.html"
if (Test-Path $idxPath) {
  $h = [System.IO.File]::ReadAllText($idxPath, $u)
  $h = $h -replace 'ls-app-bundle\.js(\?v=[^"]*)?', "ls-app-bundle.js?v=$Version"
  $h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$Version`";"
  $h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$Version`";"
  $h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', "var CURRENT_APP_VER = `"$Version`";"
  $h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$Version`";"
  [System.IO.File]::WriteAllText($idxPath, $h, $u)
}
$manPath = Join-Path $wwwDir "manifest.json"
if (Test-Path $manPath) {
  python -c "import json,pathlib; p=pathlib.Path(r'$manPath'); d=json.loads(p.read_text(encoding='utf-8')); d['version']='$Version'; p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')"
}

Write-Host "`n=== 5. Local Smoke Test (Existing Push-LawStudyes-OTA.ps1 Untouched) ===" -ForegroundColor Cyan
$smokeTarget = Join-Path $root "SmokeTest-LawStudyes-v3.1.1.ps1"
if (Test-Path $smokeTarget) {
  powershell -ExecutionPolicy Bypass -File $smokeTarget -ExpectedVersion $Version -SkipLiveOta
  if ($LASTEXITCODE -ne 0) { throw "Local Smoke Test FAILED!" }
}

if ($PushOta) {
  Write-Host "`n=== 6. Pushing Live OTA via Existing Push-LawStudyes-OTA.ps1 ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "v$Version - Rebuilt Live Voice Engine + Save-As Topic Downloads in .md Window"
} else {
  Write-Host "`n[DONE] Rebuild verified locally! Push live using your existing OTA script:" -ForegroundColor Green
  Write-Host "  powershell -ExecutionPolicy Bypass -File .\Push-LawStudyes-OTA.ps1 -Message `"v$Version - Live Voice Engine + Save-As Downloads`"" -ForegroundColor Cyan
}