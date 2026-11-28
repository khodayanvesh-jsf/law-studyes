param(
  [string]$Version = "3.2.3",
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
$bakDir = Join-Path $root ".ls_backups"
New-Item -ItemType Directory -Path $modDir, $jsDir, $bakDir -Force | Out-Null

$giPath = Join-Path $root ".gitignore"
$giTxt = if (Test-Path $giPath) { [System.IO.File]::ReadAllText($giPath, $u) } else { "" }
if ($giTxt -notmatch '\.ls_backups') {
  [System.IO.File]::WriteAllText($giPath, ($giTxt.TrimEnd() + "`r`n.ls_backups/`r`n"), $u)
}

Write-Host "`n=== 1. Removing Conflicting Monkey-Patch Module (ls-voice-controller.js) ===" -ForegroundColor Cyan
$oldVc = Join-Path $modDir "ls-voice-controller.js"
if (Test-Path $oldVc) {
  Move-Item $oldVc (Join-Path $bakDir "ls-voice-controller.removed.js") -Force
  Write-Host "[REMOVED] Conflicting ls-voice-controller.js moved to .ls_backups/ (restores pure native TTS)." -ForegroundColor Green
}
$oldEng = Join-Path $modDir "ls-audio-engine.js"
if (Test-Path $oldEng) { Copy-Item $oldEng (Join-Path $bakDir "ls-audio-engine.pre323.js") -Force }

Write-Host "`n=== 2. Installing Redeveloped Clean Audio Engine (www/js/modules/ls-audio-engine.js) ===" -ForegroundColor Cyan
$engineJs = @'
(function () {
  "use strict";
  if (window.__lsCleanAudioV323) return;
  window.__lsCleanAudioV323 = true;

  var K_SPD = "ls_aud_spd_323", K_TCH = "ls_aud_tch_323", K_REP = "ls_aud_rep_323", K_VC = "ls_aud_vc_323_";
  var AUDIO_CACHE = "ls-prof-audio-v1", CDN = "https://law-studyes.vercel.app";

  var manifest = null, htmlAudio = null, webVoices = [], capVoices = [], isNative = false;
  var token = 0, playing = false, paused = false, studioMp3 = false;
  var scope = "topic", teachMode = true, repeat = false, speed = 0.96, sleepId = null;
  var queue = [], curIdx = 0, curTopicId = "", curTitle = "", curVoiceLbl = "Auto Best Indian Voice";

  function loadPrefs() {
    try {
      var sp = parseFloat(localStorage.getItem(K_SPD) || "0.96");
      if (isFinite(sp) && sp >= 0.6 && sp <= 1.8) speed = sp;
      teachMode = localStorage.getItem(K_TCH) !== "0";
      repeat = localStorage.getItem(K_REP) === "1";
    } catch (e) {}
  }

  function langNow() {
    try { var l = (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "en"; return (l === "te" || l === "hi") ? l : "en"; }
    catch (e) { return "en"; }
  }
  function bcp47(l) { l = String(l || langNow()).toLowerCase(); return l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN"); }
  function getSavedVc(l) { try { return localStorage.getItem(K_VC + l) || "auto"; } catch (e) { return "auto"; } }
  function setSavedVc(l, k) { try { localStorage.setItem(K_VC + l, String(k || "auto")); } catch (e) {} }

  function cleanSpeech(raw, lang) {
    var s = String(raw || "");
    if (!s) return "";
    s = s.replace(/<[^>]+>/g, " ").replace(/https?:\/\/\S+/gi, " ").replace(/[\*\#\_`~>\[\]]+/g, " ");
    s = s.replace(/\s*\|\s*/g, ". ").replace(/[\u2022\u25aa\u25ba\u25b8\u2756\u25cf\u25cb\u25c6\u25c7\u2713\u2714\u2192\u21d2\u2014\u2013]+/g, ", ");
    if (lang === "en") {
      s = s.replace(/\bSecs?\.\s*/gi, "Section ").replace(/\bArts?\.\s*/gi, "Article ")
           .replace(/\bu\/s\b/gi, "under Section").replace(/\bw\.e\.f\./gi, "with effect from")
           .replace(/\bi\.e\./gi, "that is").replace(/\be\.g\./gi, "for example")
           .replace(/\betc\./gi, "and so on").replace(/\bvs?\.\s+/gi, " versus ")
           .replace(/\bIPC\b/g, "I P C").replace(/\bCrPC\b/g, "C R P C").replace(/\bCPC\b/g, "C P C")
           .replace(/\bBNS\b/g, "B N S").replace(/\bBNSS\b/g, "B N S S").replace(/\bBSA\b/g, "B S A")
           .replace(/\bAIR\b/g, "A I R").replace(/\bSCC\b/g, "S C C").replace(/\bPIL\b/g, "P I L").replace(/\bFIR\b/g, "F I R");
    }
    return s.replace(/\s*([,\.;:\?!\u0964])\s*/g, "$1 ").replace(/\.{2,}/g, ".").replace(/\s+/g, " ").trim();
  }

  function splitFluent(text, maxLen) {
    var lim = maxLen || 185, s = String(text || "").trim();
    if (!s) return [];
    if (s.length <= lim) return [s];
    var parts = s.match(/[^\.\?!\u0964]+[\.\?!\u0964]*/g) || [s], out = [];
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i].trim();
      if (!p) continue;
      if (p.length <= lim) { out.push(p); continue; }
      var cls = p.match(/[^,;:]+[,;:]*/g) || [p], buf = "";
      for (var j = 0; j < cls.length; j++) {
        var c = cls[j].trim();
        if (!c) continue;
        if ((buf + " " + c).trim().length <= lim) { buf = (buf ? buf + " " : "") + c; }
        else {
          if (buf) out.push(buf);
          if (c.length <= lim) { buf = c; }
          else {
            var ws = c.split(/\s+/), wb = "";
            for (var k = 0; k < ws.length; k++) {
              if ((wb + " " + ws[k]).trim().length <= lim) wb = (wb ? wb + " " : "") + ws[k];
              else { if (wb) out.push(wb); wb = ws[k]; }
            }
            buf = wb;
          }
        }
      }
      if (buf) out.push(buf);
    }
    return out.filter(function (x) { return x && x.length > 1; });
  }

  function metaSafe(tid) { try { return typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; } catch (e) { return null; } }

  function buildTopicQueue(tid, lang, asProf) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return [];
    var ld = rec[lang] || rec.en; if (!ld) return [];
    var m = metaSafe(tid), title = (m && m.topic && m.topic.title) ? m.topic.title : String(tid).replace(/-/g, " ");
    var ct = cleanSpeech(title, lang), m1 = cleanSpeech(ld.inOneMinute, lang), pr = cleanSpeech(ld.legalProvision, lang), mn = cleanSpeech(ld.meaning, lang);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.map(function (x) { return cleanSpeech(typeof x === "string" ? x : (x && (x.point || x.text || x.summary)), lang); }).filter(Boolean) : [];
    var cs = Array.isArray(ld.caseLaws) ? ld.caseLaws.slice(0, 3).map(function (c) {
      if (typeof c === "string") return cleanSpeech(c, lang);
      if (!c) return "";
      var n = cleanSpeech(c.name || c.title, lang), p = cleanSpeech(c.principle || c.summary, lang);
      return (n && p) ? (n + ". " + p) : (n || p);
    }).filter(Boolean) : [];

    var blks = [];
    if (lang === "te") {
      if (asProf) {
        blks.push({ step: 0, text: "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d. \u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 " + ct + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c41\u0c32\u0c2d\u0c02\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." });
        if (m1) blks.push({ step: 1, text: "\u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b \u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c35\u0c3f\u0c37\u0c2f\u0c02 \u0c24\u0c46\u0c32\u0c41\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02. " + m1 });
        if (pr) blks.push({ step: 2, text: "\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d\u200c\u0c32\u0c4b \u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c30\u0c3e\u0c2f\u0c3e\u0c32\u0c4d\u0c38\u0c3f\u0c28 \u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28 \u0c07\u0c26\u0c3f. " + pr });
        if (mn) blks.push({ step: 3, text: "\u0c07\u0c2a\u0c4d\u0c2a\u0c41\u0c21\u0c41 \u0c26\u0c40\u0c28\u0c3f \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c02\u0c17\u0c3e \u0c1a\u0c42\u0c26\u0c4d\u0c26\u0c3e\u0c02. " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41 \u0c12\u0c15\u0c4d\u0c15\u0c4a\u0c15\u0c4d\u0c15\u0c1f\u0c3f\u0c17\u0c3e \u0c17\u0c2e\u0c28\u0c3f\u0c02\u0c1a\u0c02\u0c21\u0c3f." });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "\u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d " + (i + 1) + ". " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41 \u0c32\u0c3e \u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41\u0c2a\u0c46\u0c1f\u0c4d\u0c1f\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f. " + cs.join(". ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    } else if (lang === "hi") {
      if (asProf) {
        blks.push({ step: 0, text: "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938\u0964 \u0906\u091c \u0939\u092e " + ct + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0914\u0930 \u0938\u094d\u092a\u0937\u094d\u091f \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" });
        if (m1) blks.push({ step: 1, text: "\u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902 \u0907\u0938\u0915\u093e \u092e\u0941\u0916\u094d\u092f \u0938\u093e\u0930 \u0938\u092e\u091d\u093f\u090f\u0964 " + m1 });
        if (pr) blks.push({ step: 2, text: "\u090f\u0917\u094d\u091c\u093e\u092e \u092e\u0947\u0902 \u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u092f\u0939 \u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928 \u0932\u093f\u0916\u093f\u090f\u0964 " + pr });
        if (mn) blks.push({ step: 3, text: "\u0905\u092c \u0907\u0938\u0915\u093e \u0938\u0930\u0932 \u0905\u0930\u094d\u0925 \u0938\u092e\u091d\u0924\u0947 \u0939\u0948\u0902\u0964 " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "\u0905\u092c \u090f\u0915 \u090f\u0915 \u0915\u0930\u0915\u0947 \u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938 \u0927\u094d\u092f\u093e\u0928 \u0938\u0947 \u0938\u0941\u0928\u093f\u090f\u0964" });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "\u092a\u0949\u0907\u0902\u091f " + (i + 1) + "\u0964 " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "\u0907\u0938 \u0935\u093f\u0937\u092f \u0915\u093e \u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949 \u092f\u093e\u0926 \u0930\u0916\u093f\u090f\u0964 " + cs.join("\u0964 ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    } else {
      if (asProf) {
        blks.push({ step: 0, text: "Hello students. Today let us clearly understand " + ct + "." });
        if (m1) blks.push({ step: 1, text: "First, here is the core idea in plain words. " + m1 });
        if (pr) blks.push({ step: 2, text: "For your exam answer, start with this exact legal provision. " + pr });
        if (mn) blks.push({ step: 3, text: "Let us look at what this means. " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "Now listen carefully to the key scoring points." });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "Point " + (i + 1) + ". " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "Be sure to quote this landmark case law in your answer. " + cs.join(". ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    }

    var out = [];
    for (var b = 0; b < blks.length; b++) {
      var chs = splitFluent(blks[b].text, 185);
      for (var s = 0; s < chs.length; s++) out.push({ topicId: tid, topicTitle: title, lang: lang, stepIdx: blks[b].step, text: chs[s] });
    }
    return out;
  }

  async function loadManifest() {
    if (manifest !== null) return manifest;
    manifest = {};
    try { var r = await fetch("./audio/manifest.json", { cache: "no-store" }); if (r.ok) manifest = await r.json(); } catch (e) {}
    return manifest;
  }

  function rankVoice(v, bcp) {
    var vl = String((v && v.lang) || "").toLowerCase().replace("_", "-"), vn = String((v && (v.name || v.voiceURI)) || "");
    var tgt = bcp.toLowerCase(), pref = tgt.split("-")[0];
    if (vl.indexOf("ar") === 0) return -9999;
    if (vl !== tgt && vl.indexOf(pref + "-") !== 0 && vl !== pref) return -5000;
    var sc = (vl === tgt) ? 200 : 80;
    if (/natural|neural|wavenet|online/i.test(vn)) sc += 90;
    if (/neerja|prabhat|shruti|mohan|swara|madhur|google/i.test(vn)) sc += 60;
    if (v && v.localService === false) sc += 25;
    if (/espeak|compact/i.test(vn)) sc -= 60;
    return sc;
  }

  function sortedVoices(lang) {
    var bcp = bcp47(lang), src = (isNative && capVoices.length) ? capVoices : webVoices, arr = [];
    for (var i = 0; i < src.length; i++) {
      var sc = rankVoice(src[i], bcp);
      if (sc > 0) {
        var key = (isNative && capVoices.length) ? ("cap:" + i) : ("web:" + (src[i].voiceURI || src[i].name || i));
        arr.push({ key: key, index: i, voice: src[i], name: String(src[i].name || src[i].voiceURI || ("Voice " + (i + 1))), lang: src[i].lang || bcp, score: sc });
      }
    }
    arr.sort(function (a, b) { return b.score - a.score; });
    return arr;
  }

  function resolveVoice(lang) {
    var list = sortedVoices(lang), saved = getSavedVc(lang);
    if (saved === "studio-mp3") return { key: "studio-mp3", isStudio: true, name: "HD Studio Human Voice (MP3)", fallback: list[0] || null };
    if (saved && saved !== "auto") {
      for (var i = 0; i < list.length; i++) if (list[i].key === saved) return list[i];
    }
    return list[0] || null;
  }

  function updateHint() {
    var h = document.getElementById("lsPwVoiceActiveHint");
    if (h) h.textContent = curVoiceLbl + " (" + speed.toFixed(2).replace(/\.00$/, "") + "x)";
  }

  function populateVoices() {
    var sel = document.getElementById("audioVoiceSelect");
    if (!sel) return;
    var lang = langNow(), bcp = bcp47(lang), tid = (typeof state !== "undefined" && state.activeTopicId) ? state.activeTopicId : curTopicId;
    var list = sortedVoices(lang), saved = getSavedVc(lang), opts = [];
    if (manifest && manifest[lang] && manifest[lang][tid]) opts.push({ v: "studio-mp3", l: "HD Studio Human Voice (MP3)" });
    opts.push({ v: "auto", l: "Auto Best Indian Voice (" + bcp + ")" });
    for (var i = 0; i < list.length; i++) opts.push({ v: list[i].key, l: list[i].name + " (" + list[i].lang + ")" });

    sel.innerHTML = "";
    var hit = false;
    opts.forEach(function (o) {
      var op = document.createElement("option"); op.value = o.v; op.textContent = o.l;
      if (o.v === saved) { op.selected = true; hit = true; }
      sel.appendChild(op);
    });
    if (!hit && sel.options.length) sel.selectedIndex = 0;
    var rv = resolveVoice(lang);
    curVoiceLbl = rv ? rv.name : ("System " + bcp);
    updateHint();
  }

  async function refreshVoices() {
    isNative = !!(window.Capacitor && typeof window.Capacitor.isNativePlatform === "function" && window.Capacitor.isNativePlatform());
    try { if ("speechSynthesis" in window) { var wv = window.speechSynthesis.getVoices() || []; if (wv.length) webVoices = wv; } } catch (e) {}
    try {
      var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
      if (tts && typeof tts.getSupportedVoices === "function") {
        var r = await tts.getSupportedVoices();
        if (r && Array.isArray(r.voices)) capVoices = r.voices;
      }
    } catch (e) {}
    populateVoices();
  }

  function stopHardware() {
    if (htmlAudio) { try { htmlAudio.pause(); htmlAudio.currentTime = 0; } catch (e) {} htmlAudio = null; }
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && tts.stop) { try { tts.stop().catch(function () {}); } catch (e) {} }
    if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
  }

  function stop() {
    token++; playing = false; paused = false; studioMp3 = false;
    if (sleepId) { clearTimeout(sleepId); sleepId = null; }
    stopHardware(); emitState();
  }

  async function tryMp3(tid, lang, tk) {
    await loadManifest();
    var rel = (manifest && manifest[lang] && manifest[lang][tid]) ? manifest[lang][tid] : null;
    if (!rel) return false;
    var urls = [rel, CDN + "/" + rel.replace(/^\.\//, "")];
    for (var i = 0; i < urls.length; i++) {
      try {
        var u = urls[i], playUrl = u;
        if ("caches" in window) {
          var c = await caches.open(AUDIO_CACHE), hit = await c.match(u);
          if (hit) playUrl = URL.createObjectURL(await hit.blob());
          else {
            var resp = await fetch(u); if (!resp.ok) continue;
            try { c.put(u, resp.clone()); } catch (e) {}
            playUrl = URL.createObjectURL(await resp.blob());
          }
        }
        if (tk !== token) return true;
        htmlAudio = new Audio(playUrl);
        htmlAudio.playbackRate = speed;
        htmlAudio.ontimeupdate = function () {
          if (tk !== token || !htmlAudio || !htmlAudio.duration) return;
          var b = document.getElementById("audioProgressBar");
          if (b) b.style.width = Math.min(100, Math.round((htmlAudio.currentTime / htmlAudio.duration) * 100)) + "%";
        };
        htmlAudio.onended = function () {
          if (tk !== token) return;
          if (repeat) { htmlAudio.currentTime = 0; htmlAudio.play().catch(function () {}); return; }
          playing = false; paused = false; studioMp3 = false; emitState();
        };
        await htmlAudio.play();
        playing = true; paused = false; studioMp3 = true;
        curVoiceLbl = "HD Studio Human Voice (MP3)"; updateHint(); emitState();
        return true;
      } catch (e) {}
    }
    return false;
  }

  function speakChunk(text, lang, vc) {
    var bcp = bcp47(lang);
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (isNative && tts && typeof tts.speak === "function") {
      var opts = { text: text, lang: bcp, rate: speed, pitch: 1.0, volume: 1.0, category: "ambient" };
      if (vc && typeof vc.index === "number") opts.voice = vc.index;
      return tts.speak(opts).catch(function () {});
    }
    if ("speechSynthesis" in window) {
      return new Promise(function (resolve) {
        var doneFlag = false;
        function fin() { if (!doneFlag) { doneFlag = true; resolve(); } }
        try {
          var u = new SpeechSynthesisUtterance(text);
          u.lang = bcp; u.rate = speed; u.pitch = 1.0;
          if (vc && vc.voice) { u.voice = vc.voice; if (vc.voice.lang) u.lang = vc.voice.lang; }
          u.onend = fin; u.onerror = fin;
          window.speechSynthesis.speak(u);
          setTimeout(fin, Math.max(8000, Math.round((text.length * 140) / Math.max(0.6, speed))));
        } catch (e) { fin(); }
      });
    }
    return Promise.resolve();
  }

  async function runFrom(idx) {
    var tk = ++token; stopHardware();
    if (!queue.length) { playing = false; paused = false; emitState(); return; }
    curIdx = Math.max(0, Math.min(idx, queue.length - 1));
    var first = queue[curIdx], lang = first.lang, saved = getSavedVc(lang);
    if (scope === "topic" && curIdx === 0 && (saved === "studio-mp3" || saved === "auto")) {
      if (await tryMp3(first.topicId, lang, tk)) return;
    }
    var chosen = resolveVoice(lang);
    if (chosen && chosen.isStudio) chosen = chosen.fallback;
    curVoiceLbl = chosen ? chosen.name : ("System " + bcp47(lang));
    updateHint();
    playing = true; paused = false; studioMp3 = false;

    for (var i = curIdx; i < queue.length; i++) {
      if (tk !== token) return;
      curIdx = i; curTopicId = queue[i].topicId; curTitle = queue[i].topicTitle;
      emitState();
      await speakChunk(queue[i].text, queue[i].lang, chosen);
      if (tk !== token) return;
      await new Promise(function (r) { setTimeout(r, 240); });
    }
    if (tk === token) {
      if (repeat && scope === "topic") { runFrom(0); return; }
      playing = false; paused = false; emitState();
    }
  }

  function playTopic(tid, forceProf) {
    var id = tid || (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
    if (!id) { if (typeof showToast === "function") showToast("Open any topic first to listen."); return; }
    if (typeof forceProf === "boolean") { teachMode = forceProf; try { localStorage.setItem(K_TCH, teachMode ? "1" : "0"); } catch (e) {} }
    populateVoices();
    var items = buildTopicQueue(id, langNow(), teachMode);
    if (!items.length) return;
    scope = "topic"; queue = items; curIdx = 0; curTopicId = id; curTitle = items[0].topicTitle;
    runFrom(0);
  }

  function playUnit(tid) {
    var id = tid || (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
    if (!id) return;
    var m = metaSafe(id);
    if (!m || !m.unit || !Array.isArray(m.unit.topics) || !m.unit.topics.length) { playTopic(id); return; }
    populateVoices();
    var all = [], lang = langNow();
    m.unit.topics.forEach(function (t) { if (t && t.id) all = all.concat(buildTopicQueue(t.id, lang, teachMode)); });
    if (!all.length) return;
    scope = "unit"; queue = all; curIdx = 0; curTopicId = all[0].topicId; curTitle = all[0].topicTitle;
    runFrom(0);
  }

  function pause() {
    if (!playing || paused) return;
    paused = true;
    if (studioMp3 && htmlAudio) { try { htmlAudio.pause(); } catch (e) {} }
    else { token++; stopHardware(); }
    emitState();
  }
  function resume() {
    if (!playing || !paused) return;
    paused = false;
    if (studioMp3 && htmlAudio) { htmlAudio.playbackRate = speed; htmlAudio.play().catch(function () {}); emitState(); }
    else runFrom(curIdx);
  }
  function togglePlay() { if (playing && !paused) pause(); else if (playing && paused) resume(); else playTopic(); }
  function prev() { if (!queue.length) return; if (studioMp3 && htmlAudio) { htmlAudio.currentTime = Math.max(0, htmlAudio.currentTime - 10); return; } runFrom(Math.max(0, curIdx - 1)); }
  function next() { if (!queue.length) return; if (studioMp3 && htmlAudio && htmlAudio.duration) { htmlAudio.currentTime = Math.min(htmlAudio.duration - 0.5, htmlAudio.currentTime + 10); return; } runFrom(Math.min(queue.length - 1, curIdx + 1)); }

  function setSpeed(val) {
    var r = parseFloat(val); if (!isFinite(r) || r < 0.6 || r > 1.8) return;
    speed = r; try { localStorage.setItem(K_SPD, String(speed)); } catch (e) {}
    updateHint();
    if (playing && !paused) { if (studioMp3 && htmlAudio) htmlAudio.playbackRate = speed; else runFrom(curIdx); }
    emitState();
  }

  function toggleTeach() {
    teachMode = !teachMode; try { localStorage.setItem(K_TCH, teachMode ? "1" : "0"); } catch (e) {}
    if (typeof showToast === "function") showToast(teachMode ? "Indian Professor Style ON" : "Direct Notes Reading ON");
    if (playing && !paused) { if (scope === "unit") playUnit(curTopicId); else playTopic(curTopicId); } else emitState();
  }

  function toggleRepeat() {
    repeat = !repeat; try { localStorage.setItem(K_REP, repeat ? "1" : "0"); } catch (e) {}
    if (typeof showToast === "function") showToast(repeat ? "Loop Topic ON" : "Loop Topic OFF");
    emitState();
  }

  function setSleep(mins) {
    if (sleepId) { clearTimeout(sleepId); sleepId = null; }
    var m = parseInt(mins, 10) || 0;
    if (m > 0) {
      sleepId = setTimeout(function () { stop(); if (typeof showToast === "function") showToast("Sleep timer ended audio."); }, m * 60000);
      if (typeof showToast === "function") showToast("Sleep timer: " + m + " min");
    }
  }

  async function testVoice() {
    var lang = langNow(), chosen = resolveVoice(lang);
    stop();
    var txt = lang === "te"
      ? "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d. \u0c07\u0c26\u0c3f \u0c32\u0c3e \u0c38\u0c4d\u0c1f\u0c21\u0c40\u0c38\u0c4d \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c35\u0c3e\u0c2f\u0c3f\u0c38\u0c4d."
      : (lang === "hi"
        ? "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938\u0964 \u092f\u0939 \u0932\u0949 \u0938\u094d\u091f\u0921\u0940\u091c\u093c \u0915\u0940 \u0939\u093f\u0902\u0926\u0940 \u0906\u0935\u093e\u091c\u093c \u0939\u0948\u0964"
        : "Hello students. This is your selected Law Studyes Indian voice.");
    if (chosen && chosen.isStudio) {
      var tid = (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
      if (tid && await tryMp3(tid, lang, ++token)) return;
      chosen = chosen.fallback;
    }
    if (typeof showToast === "function") showToast("Testing: " + (chosen ? chosen.name : ("System " + bcp47(lang))));
    await speakChunk(txt, lang, chosen);
  }

  function getState() {
    var it = queue[curIdx] || null, tot = queue.length || 0, pct = tot ? Math.round(((curIdx + 1) / tot) * 100) : 0;
    return {
      playing: playing, isPlaying: playing && !paused, paused: paused, topicId: curTopicId,
      title: curTitle || "Select a Topic to Listen", topicTitle: curTitle || "Select a Topic to Listen",
      caption: studioMp3 ? "Playing HD Studio Human Voice (MP3)" : (it ? it.text : ""),
      currentText: studioMp3 ? "Playing HD Studio Human Voice (MP3)" : (it ? it.text : ""),
      stepIdx: it ? it.stepIdx : -1, index: curIdx, currentIndex: curIdx, total: tot, progress: pct, percent: pct,
      scope: scope, teachingMode: teachMode, repeat: repeat, speed: speed, lang: langNow(), voiceName: curVoiceLbl, studioMp3: studioMp3
    };
  }

  function emitState() {
    var st = getState(), el;
    if ((el = document.getElementById("audioCurrentTitle"))) el.textContent = st.title;
    if ((el = document.getElementById("audioModeBadge"))) el.textContent = st.studioMp3 ? "HD Studio MP3" : (st.teachingMode ? "Indian Professor" : "Direct Notes");
    if ((el = document.getElementById("audioQueueCounter"))) el.textContent = st.total ? ((st.index + 1) + " / " + st.total) : "Ready";
    if ((el = document.getElementById("liveCaptionStrip"))) { el.textContent = st.caption || "Tap Play to start Audio"; el.classList.remove("hidden"); }
    if ((el = document.getElementById("audioProgressBar")) && !st.studioMp3) el.style.width = st.percent + "%";
    if ((el = document.getElementById("audioPlayPauseBtn"))) { el.textContent = (st.playing && !st.paused) ? "Pause" : (st.paused ? "Resume" : "Play"); }
    if ((el = document.getElementById("teachingModeBtn"))) { el.textContent = st.teachingMode ? "Professor Mode: ON" : "Direct Notes: ON"; el.classList.toggle("active", st.teachingMode); }
    if ((el = document.getElementById("repeatTopicBtn"))) { el.textContent = st.repeat ? "Loop: ON" : "Loop: OFF"; el.classList.toggle("active", st.repeat); }
    if ((el = document.getElementById("lsMiniTitle"))) el.textContent = st.title;
    if ((el = document.getElementById("lsMiniSub"))) el.textContent = (st.playing && !st.paused) ? (st.voiceName + " - " + st.percent + "%") : (st.paused ? "Paused" : "Tap to open Audio Player");
    if ((el = document.getElementById("lsMiniPulse"))) el.style.display = (st.playing && !st.paused) ? "block" : "none";
    try { window.dispatchEvent(new CustomEvent("ls:audio-state", { detail: st })); } catch (e) {}
  }

  function cleanClone(id) {
    var el = document.getElementById(id);
    if (!el || el.__lsClean323) return el;
    var c = el.cloneNode(true); c.__lsClean323 = true;
    if (el.parentNode) el.parentNode.replaceChild(c, el);
    return c;
  }

  function bindControls() {
    var b;
    if ((b = cleanClone("audioPlayPauseBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", togglePlay); }
    if ((b = cleanClone("audioPrevBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", prev); }
    if ((b = cleanClone("audioNextBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", next); }
    if ((b = cleanClone("audioStopBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", stop); }
    if ((b = cleanClone("teachingModeBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", toggleTeach); }
    if ((b = cleanClone("repeatTopicBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", toggleRepeat); }
    if ((b = cleanClone("sleepTimerSelect")) && !b.__w) { b.__w = true; b.addEventListener("change", function () { setSleep(b.value); }); }
    if ((b = cleanClone("audioSpeedSelect")) && !b.__w) {
      b.__w = true;
      b.innerHTML = '<option value="0.8">0.8x (Slow)</option><option value="0.96">1.0x (Natural)</option><option value="1.15">1.15x (Brisk)</option><option value="1.3">1.3x (Revision)</option>';
      b.value = String(speed); if (b.selectedIndex === -1) b.value = "0.96";
      b.addEventListener("change", function () { setSpeed(b.value); });
    }
    var vcSel = cleanClone("audioVoiceSelect");
    if (vcSel && !vcSel.__w) {
      vcSel.__w = true;
      vcSel.addEventListener("change", function () {
        var l = langNow(); setSavedVc(l, vcSel.value);
        var rv = resolveVoice(l); curVoiceLbl = rv ? rv.name : ("System " + bcp47(l));
        updateHint();
        if (typeof showToast === "function") showToast("Voice: " + curVoiceLbl);
        if (playing && !paused) runFrom(vcSel.value === "studio-mp3" ? 0 : curIdx);
        emitState();
      });
    }
    var vcHost = document.getElementById("lsPwVoiceHost");
    if (vcHost) {
      var oldR = document.getElementById("lsPwVoiceActionRow");
      if (oldR && !oldR.__v323) oldR.remove();
      if (!document.getElementById("lsPwVoiceActionRow")) {
        var row = document.createElement("div"); row.id = "lsPwVoiceActionRow"; row.__v323 = true;
        row.style.cssText = "display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:6px;";
        row.innerHTML = '<span id="lsPwVoiceActiveHint" style="font-size:11px;font-weight:700;color:#7B1E2B;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"></span>' +
          '<button type="button" id="lsPwTestVoiceBtn" style="padding:5px 11px;border-radius:8px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11px;font-weight:800;cursor:pointer;flex-shrink:0;">Test Voice</button>';
        vcHost.appendChild(row);
        row.querySelector("#lsPwTestVoiceBtn").addEventListener("click", testVoice);
      }
    }
    populateVoices(); emitState();
  }

  window.LSAudioEngine = {
    playTopic: playTopic, playUnit: playUnit, play: togglePlay, pause: pause, resume: resume, togglePlay: togglePlay,
    stop: stop, stopHardware: stopHardware, prev: prev, next: next, jumpTo: runFrom, setSpeed: setSpeed,
    toggleTeachingMode: toggleTeach, toggleRepeat: toggleRepeat, setSleepTimer: setSleep,
    testVoice: testVoice, refreshVoices: refreshVoices, emitState: emitState, getState: getState
  };

  function boot() { loadPrefs(); loadManifest().then(function () { refreshVoices().then(bindControls); }); }
  if ("speechSynthesis" in window && "onvoiceschanged" in window.speechSynthesis) window.speechSynthesis.onvoiceschanged = refreshVoices;
  window.addEventListener("ls:lang-changed", function () { stop(); populateVoices(); });
  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(boot, 250); setTimeout(bindControls, 900); setTimeout(bindControls, 1800);
    if (typeof window.renderReadingPane === "function" && !window.__lsAudHook323) {
      window.__lsAudHook323 = true;
      var orig = window.renderReadingPane;
      window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(populateVoices, 60); return r; };
    }
  });
})();
'@

$enginePath = Join-Path $modDir "ls-audio-engine.js"
[System.IO.File]::WriteAllText($enginePath, $engineJs, $u)
node --check $enginePath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-audio-engine.js!" }
Write-Host "[PASS] www/js/modules/ls-audio-engine.js redeveloped cleanly (0 errors)." -ForegroundColor Green

Write-Host "`n=== 3. Unifying AI Indian Professor Card to Single Audio Engine (www/js/modules/ls-indian-professor.js) ===" -ForegroundColor Cyan
$profJs = @'
(function () {
  "use strict";
  if (window.__lsIndianProfessorV323) return;
  window.__lsIndianProfessorV323 = true;

  function clean(s) { return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s*\|\s*/g, ". ").replace(/\s+/g, " ").trim(); }
  function topicTitle(tid) {
    try { var m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; if (m && m.topic && m.topic.title) return m.topic.title; } catch (e) {}
    return String(tid || "Topic").replace(/-/g, " ");
  }

  function buildLesson(tid, lang) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return null;
    var ld = rec[lang] || rec.en; if (!ld) return null;
    var t = topicTitle(tid), m1 = clean(ld.inOneMinute), pr = clean(ld.legalProvision), mn = clean(ld.meaning);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.slice(0, 5).map(function (x, i) { var tx = clean(typeof x === "string" ? x : (x && (x.point || x.text || x.summary))); return tx ? ((i + 1) + ". " + tx) : ""; }).filter(Boolean) : [];
    var c0 = Array.isArray(ld.caseLaws) && ld.caseLaws[0];
    var topCase = !c0 ? "" : (typeof c0 === "string" ? clean(c0) : (clean(c0.name || c0.title) + (c0.principle || c0.summary ? " - " + clean(c0.principle || c0.summary) : "")));

    if (lang === "te") {
      return {
        heading: "\u0c07\u0c02\u0c21\u0c3f\u0c2f\u0c28\u0c4d \u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d",
        sub: "\u0c38\u0c41\u0c32\u0c2d\u0c2e\u0c48\u0c28 \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c35\u0c3f\u0c35\u0c30\u0c23 & \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d\u0c38\u0c4d",
        steps: [
          { step: 0, tag: "\u0c2a\u0c30\u0c3f\u0c1a\u0c2f\u0c02", text: "\u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 " + t + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c41\u0c32\u0c2d\u0c02\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." },
          m1 ? { step: 1, tag: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b", text: m1 } : null,
          pr ? { step: 2, tag: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28", text: pr } : null,
          mn ? { step: 3, tag: "\u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c2e\u0c48\u0c28 \u0c05\u0c30\u0c4d\u0c25\u0c02", text: mn } : null,
          pts.length ? { step: 4, tag: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41", text: pts.join(" ") } : null,
          topCase ? { step: 5, tag: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41 \u0c32\u0c3e", text: topCase } : null
        ].filter(Boolean)
      };
    }
    if (lang === "hi") {
      return {
        heading: "\u0907\u0902\u0921\u093f\u092f\u0928 \u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e",
        sub: "\u0906\u0938\u093e\u0928 \u0939\u093f\u0902\u0926\u0940 \u0935\u094d\u092f\u093e\u0916\u094d\u092f\u093e & \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u093f\u092a\u094d\u0938",
        steps: [
          { step: 0, tag: "\u092a\u0930\u093f\u091a\u092f", text: "\u0906\u091c \u0939\u092e " + t + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0914\u0930 \u0938\u094d\u092a\u0937\u094d\u091f \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" },
          m1 ? { step: 1, tag: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902", text: m1 } : null,
          pr ? { step: 2, tag: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928", text: pr } : null,
          mn ? { step: 3, tag: "\u0938\u0930\u0932 \u0905\u0930\u094d\u0925", text: mn } : null,
          pts.length ? { step: 4, tag: "\u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938", text: pts.join(" ") } : null,
          topCase ? { step: 5, tag: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949", text: topCase } : null
        ].filter(Boolean)
      };
    }
    return {
      heading: "Indian Professor Classroom",
      sub: "Clear Indian LL.B. classroom explanation & exam structure",
      steps: [
        { step: 0, tag: "Overview", text: "Today let us clearly understand " + t + "." },
        m1 ? { step: 1, tag: "1-Minute Core", text: m1 } : null,
        pr ? { step: 2, tag: "Legal Provision", text: pr } : null,
        mn ? { step: 3, tag: "Plain Meaning", text: mn } : null,
        pts.length ? { step: 4, tag: "Key Scoring Points", text: pts.join(" ") } : null,
        topCase ? { step: 5, tag: "Landmark Case", text: topCase } : null
      ].filter(Boolean)
    };
  }

  function injectCss() {
    if (document.getElementById("lsProfCssV323")) return;
    var st = document.createElement("style"); st.id = "lsProfCssV323";
    st.textContent =
      ".ls-prof-card{margin:14px 0 16px;border-radius:16px;background:linear-gradient(135deg,#FFFBF2 0%,#FDF4F5 100%);border:1.5px solid #E5C9A8;padding:12px 14px}" +
      ".ls-prof-title{font-size:13.5px;font-weight:800;color:#7B1E2B}.ls-prof-sub{font-size:11px;color:#6B5B4D;font-weight:600}" +
      ".ls-prof-controls{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:10px}" +
      ".ls-prof-btn{padding:6px 11px;border-radius:999px;border:1px solid #DFC5A4;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:800;cursor:pointer}" +
      ".ls-prof-btn.primary{background:#7B1E2B;color:#FFF;border-color:#7B1E2B}.ls-prof-status{font-size:11px;color:#7B1E2B;font-weight:700;margin-top:8px}" +
      ".ls-prof-body{margin-top:10px;display:flex;flex-direction:column;gap:7px}" +
      ".ls-prof-step{background:#FFF;border:1px solid #EFE4D6;border-left:3.5px solid #7B1E2B;border-radius:10px;padding:8px 10px;font-size:12.5px;line-height:1.55}" +
      ".ls-prof-step.speaking{background:#FFF7E6;border-left-color:#B45309}.ls-prof-tag{display:inline-block;font-size:10px;font-weight:800;color:#7B1E2B;background:#FBF1F2;padding:2px 7px;border-radius:999px;margin-bottom:4px}";
    document.head.appendChild(st);
  }

  function sync(st) {
    if (!st) return;
    var p = document.getElementById("lsProfPlayBtn"), s = document.getElementById("lsProfStopBtn"), el = document.getElementById("lsProfStatus");
    if (p) p.textContent = (st.playing && !st.paused) ? "Pause Class" : (st.paused ? "Resume Class" : "Listen to Professor");
    if (s) s.style.display = (st.playing || st.paused) ? "inline-block" : "none";
    if (el) el.textContent = (st.playing && !st.paused) ? ("Playing: " + st.voiceName + " (" + st.percent + "%)") : (st.paused ? "Paused" : "");
    document.querySelectorAll("#lsProfLessonBody .ls-prof-step").forEach(function (n) {
      n.classList.toggle("speaking", st.playing && !st.paused && !st.studioMp3 && parseInt(n.getAttribute("data-step") || "-9", 10) === st.stepIdx);
    });
  }

  function renderCard() {
    try {
      injectCss();
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane"); if (!pane) return;
      var old = document.getElementById("lsIndianProfessorCard"); if (old) old.remove();
      var lesson = buildLesson(state.activeTopicId, state.lang || "en"); if (!lesson) return;

      var card = document.createElement("section"); card.id = "lsIndianProfessorCard"; card.className = "ls-prof-card";
      card.innerHTML =
        '<div class="ls-prof-title">' + lesson.heading + '</div><div class="ls-prof-sub">' + lesson.sub + '</div>' +
        '<div class="ls-prof-controls">' +
          '<button type="button" id="lsProfPlayBtn" class="ls-prof-btn primary">Listen to Professor</button>' +
          '<button type="button" id="lsProfStopBtn" class="ls-prof-btn" style="display:none;">Stop</button>' +
          '<button type="button" id="lsProfOpenPlayerBtn" class="ls-prof-btn">Voice &amp; Speed Settings</button>' +
          '<button type="button" id="lsProfToggleBodyBtn" class="ls-prof-btn">Show Classroom Notes</button>' +
        '</div><div id="lsProfStatus" class="ls-prof-status"></div><div id="lsProfLessonBody" class="ls-prof-body" style="display:none;"></div>';

      var body = card.querySelector("#lsProfLessonBody");
      lesson.steps.forEach(function (st) {
        var r = document.createElement("div"); r.className = "ls-prof-step"; r.setAttribute("data-step", String(st.step));
        r.innerHTML = '<span class="ls-prof-tag">' + st.tag.replace(/</g, "&lt;") + '</span><div>' + st.text.replace(/</g, "&lt;") + '</div>';
        body.appendChild(r);
      });

      card.querySelector("#lsProfPlayBtn").addEventListener("click", function () {
        var eng = window.LSAudioEngine; if (!eng) return;
        var st = eng.getState();
        if (st.playing && st.topicId === state.activeTopicId) eng.togglePlay();
        else { body.style.display = "flex"; card.querySelector("#lsProfToggleBodyBtn").textContent = "Hide Classroom Notes"; eng.playTopic(state.activeTopicId, true); }
      });
      card.querySelector("#lsProfStopBtn").addEventListener("click", function () { if (window.LSAudioEngine) window.LSAudioEngine.stop(); });
      card.querySelector("#lsProfOpenPlayerBtn").addEventListener("click", function () {
        if (window.LSAudioWindow && typeof window.LSAudioWindow.open === "function") window.LSAudioWindow.open();
        else { var m = document.getElementById("lsPlayerWindowModal"); if (m) m.classList.add("show"); }
      });
      card.querySelector("#lsProfToggleBodyBtn").addEventListener("click", function (ev) {
        var open = body.style.display !== "none"; body.style.display = open ? "none" : "flex";
        ev.currentTarget.textContent = open ? "Show Classroom Notes" : "Hide Classroom Notes";
      });

      var copyBar = document.getElementById("lsNoteCopyBar");
      if (copyBar && copyBar.parentNode === pane) copyBar.insertAdjacentElement("afterend", card);
      else pane.insertBefore(card, pane.firstChild);
      if (window.LSAudioEngine) sync(window.LSAudioEngine.getState());
    } catch (e) {}
  }

  window.addEventListener("ls:audio-state", function (ev) { sync(ev.detail); });
  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsProfHookV323) {
        window.__lsProfHookV323 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); renderCard(); return r; };
        renderCard();
      }
    } catch (e) {}
  }

  window.LSIndianProfessor = {
    play: function () { if (window.LSAudioEngine) window.LSAudioEngine.playTopic(state.activeTopicId, true); },
    stop: function () { if (window.LSAudioEngine) window.LSAudioEngine.stop(); }
  };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 350); setTimeout(hook, 1200); });
})();
'@

$profPath = Join-Path $modDir "ls-indian-professor.js"
[System.IO.File]::WriteAllText($profPath, $profJs, $u)
node --check $profPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-indian-professor.js!" }
Write-Host "[PASS] www/js/modules/ls-indian-professor.js unified with single audio engine (0 errors)." -ForegroundColor Green

Write-Host "`n=== 4. Re-Binding All Clean Modules into www/js/ls-app-bundle.js (v$Version) ===" -ForegroundColor Cyan
$priority = @(
  "ls-store.js", "ls-trilingual.js",
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
Write-Host "[PASS] Bound $($ordered.Count) clean modules -> www/js/ls-app-bundle.js ($([Math]::Round((Get-Item $bundlePath).Length / 1KB, 1)) KB, 0 errors)" -ForegroundColor Green

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

Write-Host "`n=== 5. Local Smoke Test (v$Version) ===" -ForegroundColor Cyan
$smokeTarget = Join-Path $root "SmokeTest-LawStudyes-v3.1.1.ps1"
if (Test-Path $smokeTarget) {
  powershell -ExecutionPolicy Bypass -File $smokeTarget -ExpectedVersion $Version -SkipLiveOta
  if ($LASTEXITCODE -ne 0) { throw "Local Smoke Test FAILED!" }
}

if ($PushOta) {
  Write-Host "`n=== 6. Pushing Verified Clean Audio v$Version Live ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "v$Version - Redeveloped Clean Indian Audio Engine (Natural Pitch 1.0, Real Voice Picker, Fluent Flow)"
}