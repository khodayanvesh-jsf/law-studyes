(function () {
  "use strict";
  if (window.__lsCleanAudioV324) return;
  window.__lsCleanAudioV324 = true;

  var K_SPD = "ls_aud_spd_324", K_TCH = "ls_aud_tch_324", K_REP = "ls_aud_rep_324", K_VC = "ls_aud_vc_324_";
  var AUDIO_CACHE = "ls-prof-audio-v1", CDN = "https://law-studyes.vercel.app";

  var manifest = null, htmlAudio = null, keepAliveAudio = null, wakeLock = null;
  var webVoices = [], capVoices = [], isNative = false;
  var token = 0, playing = false, paused = false, studioMp3 = false;
  var scope = "topic", teachMode = true, repeat = false, speed = 0.98, sleepId = null;
  var queue = [], curIdx = 0, curTopicId = "", curTitle = "", curVoiceLbl = "Auto Best Indian Voice";

  var SILENT_WAV = "data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA";

  function loadPrefs() {
    try {
      var sp = parseFloat(localStorage.getItem(K_SPD) || "0.98");
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

  function startBackgroundKeepAlive(title) {
    try {
      if (window.LSNativeKeepAlive && typeof window.LSNativeKeepAlive.setPlaying === "function") {
        window.LSNativeKeepAlive.setPlaying(true, String(title || "Law Studyes Audio"));
      }
    } catch (e) {}
    try {
      if (navigator.wakeLock && typeof navigator.wakeLock.request === "function" && !wakeLock) {
        navigator.wakeLock.request("screen").then(function (wl) {
          wakeLock = wl;
          wl.addEventListener("release", function () { wakeLock = null; });
        }).catch(function () {});
      }
    } catch (e) {}
    try {
      if (!keepAliveAudio) {
        keepAliveAudio = new Audio(SILENT_WAV);
        keepAliveAudio.loop = true;
        keepAliveAudio.volume = 0.01;
      }
      if (keepAliveAudio.paused) keepAliveAudio.play().catch(function () {});
    } catch (e) {}
    try {
      if ("mediaSession" in navigator) {
        if (typeof MediaMetadata !== "undefined") {
          navigator.mediaSession.metadata = new MediaMetadata({
            title: String(title || "Law Studyes Audio"),
            artist: "Law Studyes - Indian Professor",
            album: "3-Year LL.B. Notes"
          });
        }
        navigator.mediaSession.playbackState = "playing";
        navigator.mediaSession.setActionHandler("play", function () { resume(); });
        navigator.mediaSession.setActionHandler("pause", function () { pause(); });
        navigator.mediaSession.setActionHandler("previoustrack", function () { prev(); });
        navigator.mediaSession.setActionHandler("nexttrack", function () { next(); });
        navigator.mediaSession.setActionHandler("stop", function () { stop(); });
      }
    } catch (e) {}
  }

  function stopBackgroundKeepAlive() {
    try {
      if (window.LSNativeKeepAlive && typeof window.LSNativeKeepAlive.setPlaying === "function") {
        window.LSNativeKeepAlive.setPlaying(false, "");
      }
    } catch (e) {}
    try { if (wakeLock) { wakeLock.release().catch(function () {}); wakeLock = null; } } catch (e) {}
    try { if (keepAliveAudio) { keepAliveAudio.pause(); keepAliveAudio.currentTime = 0; } } catch (e) {}
    try { if ("mediaSession" in navigator) navigator.mediaSession.playbackState = paused ? "paused" : "none"; } catch (e) {}
  }

  document.addEventListener("visibilitychange", function () {
    if (!document.hidden && playing && !paused) startBackgroundKeepAlive(curTitle);
  });

  function cleanSpeech(raw, lang) {
    var s = String(raw || "");
    if (!s) return "";
    s = s.replace(/<[^>]+>/g, " ").replace(/https?:\/\/\S+/gi, " ").replace(/[\*\#\_`~>\[\]]+/g, " ");
    s = s.replace(/\s*\|\s*/g, ". ").replace(/[\u2022\u25aa\u25ba\u25b8\u2756\u25cf\u25cb\u25c6\u25c7\u2713\u2714\u2192\u21d2\u2014\u2013]+/g, ", ");
    if (lang === "en") {
      s = s.replace(/\bsallent\b/gi, "salient")
           .replace(/\bSecs?\.\s*/gi, "Section ").replace(/\bArts?\.\s*/gi, "Article ")
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
    if (/natural|neural|wavenet|network|online/i.test(vn)) sc += 90;
    if (/neerja|prabhat|shruti|mohan|swara|madhur|google/i.test(vn)) sc += 60;
    if (v && v.localService === false) sc += 25;
    if (/espeak|compact/i.test(vn)) sc -= 60;
    return sc;
  }

  function curatedVoices(lang) {
    var bcp = bcp47(lang), src = (isNative && capVoices.length) ? capVoices : webVoices, all = [];
    for (var i = 0; i < src.length; i++) {
      var sc = rankVoice(src[i], bcp);
      if (sc > 0) {
        var rawName = String(src[i].name || src[i].voiceURI || ("Voice " + (i + 1)));
        var key = (isNative && capVoices.length) ? ("cap:" + i) : ("web:" + (src[i].voiceURI || src[i].name || i));
        var isNet = /network|neural|natural|wavenet|online/i.test(rawName) || (src[i].localService === false);
        var isMale = /prabhat|mohan|madhur|ravi|hemant|male|\-e\-|\-d\-|ind\-x\-end|en\-in\-x\-ene|te\-in\-x\-tem|hi\-in\-x\-hid/i.test(rawName);
        var isFem = /neerja|shruti|swara|heera|kalpana|veena|lekha|female|en\-in\-x\-ena|en\-in\-x\-enc|te\-in\-x\-tef|hi\-in\-x\-hia/i.test(rawName);
        all.push({ key: key, index: i, voice: src[i], rawName: rawName, lang: src[i].lang || bcp, score: sc, isNet: isNet, isMale: isMale, isFem: isFem });
      }
    }
    all.sort(function (a, b) { return b.score - a.score; });
    if (!all.length) return [];

    var picked = [], usedKeys = {};
    function addPick(item, cleanLabel) {
      if (!item || usedKeys[item.key]) return;
      usedKeys[item.key] = true;
      picked.push({ key: item.key, index: item.index, voice: item.voice, name: cleanLabel, lang: item.lang });
    }

    var bestFem = all.filter(function (x) { return x.isFem; })[0] || all[0];
    var bestMale = all.filter(function (x) { return x.isMale && !usedKeys[x.key]; })[0];
    var bestNet = all.filter(function (x) { return x.isNet && !usedKeys[x.key]; })[0];
    var bestLocal = all.filter(function (x) { return !x.isNet && !usedKeys[x.key]; })[0];

    addPick(bestFem, "Indian Female (Clear)");
    addPick(bestMale, "Indian Male (Clear)");
    addPick(bestNet, "Indian HD Online Voice");
    addPick(bestLocal, "Indian Offline Voice");

    for (var k = 0; k < all.length && picked.length < 3; k++) {
      addPick(all[k], "Indian Voice " + (picked.length + 1));
    }
    return picked;
  }

  function resolveVoice(lang) {
    var list = curatedVoices(lang), saved = getSavedVc(lang);
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

  function removeDeadVoiceDropdowns() {
    var host = document.getElementById("lsPwVoiceHost");
    if (host) {
      host.querySelectorAll("select").forEach(function (s) {
        if (s.id !== "audioVoiceSelect") s.remove();
      });
    }
    var modal = document.getElementById("lsPlayerWindowModal");
    if (modal) {
      modal.querySelectorAll("select").forEach(function (s) {
        if (s.id !== "audioVoiceSelect" && s.id !== "audioSpeedSelect" && s.id !== "sleepTimerSelect") {
          s.remove();
        }
      });
    }
  }

  function populateVoices() {
    removeDeadVoiceDropdowns();
    var sel = document.getElementById("audioVoiceSelect");
    if (!sel) return;
    var lang = langNow(), bcp = bcp47(lang), tid = (typeof state !== "undefined" && state.activeTopicId) ? state.activeTopicId : curTopicId;
    var list = curatedVoices(lang), saved = getSavedVc(lang), opts = [];
    if (manifest && manifest[lang] && manifest[lang][tid]) {
      opts.push({ v: "studio-mp3", l: "HD Studio Human Voice (MP3)" });
    }
    opts.push({ v: "auto", l: "Auto Best Indian Voice (" + bcp + ")" });
    for (var i = 0; i < list.length; i++) opts.push({ v: list[i].key, l: list[i].name });

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
    stopHardware();
    stopBackgroundKeepAlive();
    emitState();
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
          playing = false; paused = false; studioMp3 = false;
          stopBackgroundKeepAlive();
          emitState();
        };
        await htmlAudio.play();
        playing = true; paused = false; studioMp3 = true;
        curVoiceLbl = "HD Studio Human Voice (MP3)";
        startBackgroundKeepAlive(curTitle);
        updateHint(); emitState();
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
          setTimeout(fin, Math.max(9000, Math.round((text.length * 145) / Math.max(0.6, speed))));
        } catch (e) { fin(); }
      });
    }
    return Promise.resolve();
  }

  async function runFrom(idx) {
    var tk = ++token; stopHardware();
    if (!queue.length) { playing = false; paused = false; stopBackgroundKeepAlive(); emitState(); return; }
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
    startBackgroundKeepAlive(first.topicTitle);

    for (var i = curIdx; i < queue.length; i++) {
      if (tk !== token) return;
      curIdx = i; curTopicId = queue[i].topicId; curTitle = queue[i].topicTitle;
      emitState();
      await speakChunk(queue[i].text, queue[i].lang, chosen);
      if (tk !== token) return;
      if (!document.hidden) {
        await new Promise(function (r) { setTimeout(r, 200); });
      }
    }
    if (tk === token) {
      if (repeat && scope === "topic") { runFrom(0); return; }
      playing = false; paused = false;
      stopBackgroundKeepAlive();
      emitState();
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
    stopBackgroundKeepAlive();
    emitState();
  }
  function resume() {
    if (!playing || !paused) return;
    paused = false;
    startBackgroundKeepAlive(curTitle);
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
    if (!el || el.__lsClean324) return el;
    var c = el.cloneNode(true); c.__lsClean324 = true;
    if (el.parentNode) el.parentNode.replaceChild(c, el);
    return c;
  }

  function bindControls() {
    removeDeadVoiceDropdowns();
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
      b.innerHTML = '<option value="0.8">0.8x (Slow)</option><option value="0.98">1.0x (Natural)</option><option value="1.15">1.15x (Brisk)</option><option value="1.3">1.3x (Revision)</option>';
      b.value = String(speed); if (b.selectedIndex === -1) b.value = "0.98";
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
      if (oldR && !oldR.__v324) oldR.remove();
      if (!document.getElementById("lsPwVoiceActionRow")) {
        var row = document.createElement("div"); row.id = "lsPwVoiceActionRow"; row.__v324 = true;
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
    if (typeof window.renderReadingPane === "function" && !window.__lsAudHook324) {
      window.__lsAudHook324 = true;
      var orig = window.renderReadingPane;
      window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(populateVoices, 60); return r; };
    }
    if (typeof MutationObserver !== "undefined" && document.body) {
      new MutationObserver(removeDeadVoiceDropdowns).observe(document.body, { childList: true, subtree: true });
    }
  });
})();