(function () {
  "use strict";
  if (window.__lsVoiceCtrlV322) return;
  window.__lsVoiceCtrlV322 = true;

  var K_ENG = "ls_voice_engine_v2", K_GEN = "ls_voice_gender_v2", K_VID = "ls_voice_id_v2", K_RATE = "ls_voice_rate_v2";
  var webVoices = [], capVoices = [], nativeWebSpeak = null, nativeCapSpeak = null;
  var syncingSelect = false;

  var PRESETS = [
    { val: "__ls_mode:studio:female", label: "Human Studio MP3 + Neural (Ma'am)" },
    { val: "__ls_mode:neural:female", label: "Indian Neural Voice (Ma'am)" },
    { val: "__ls_mode:neural:male",   label: "Indian Neural Voice (Sir)" },
    { val: "__ls_mode:device:female", label: "Offline Device Voice (Ma'am)" },
    { val: "__ls_mode:device:male",   label: "Offline Device Voice (Sir)" }
  ];

  function getEngine() { try { return localStorage.getItem(K_ENG) || "studio"; } catch (e) { return "studio"; } }
  function getGender() { try { return localStorage.getItem(K_GEN) || localStorage.getItem("ls_prof_gender_v1") || "female"; } catch (e) { return "female"; } }
  function getVoiceId() { try { return localStorage.getItem(K_VID) || "auto"; } catch (e) { return "auto"; } }
  function getRate() {
    try {
      var sel = document.getElementById("audioSpeedSelect");
      var raw = localStorage.getItem(K_RATE) || (sel && sel.value) || "1";
      var r = parseFloat(raw);
      return (isFinite(r) && r >= 0.5 && r <= 2.0) ? r : 1.0;
    } catch (e) { return 1.0; }
  }
  function getLang() { try { return (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "en"; } catch (e) { return "en"; } }
  function toBcp47(l) { l = String(l || getLang()).toLowerCase(); return l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN"); }
  function getPitch() { return getGender() === "male" ? (getEngine() === "device" ? 0.80 : 0.88) : (getEngine() === "device" ? 1.12 : 1.04); }

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
      if (/^\d+$/.test(vid) && vs[parseInt(vid, 10)]) return vs[parseInt(vid, 10)];
      for (var i = 0; i < vs.length; i++) {
        if (vs[i].voiceURI === vid || vs[i].name === vid) return vs[i];
      }
    }
    var best = null, bestSc = -999, eng = getEngine(), gen = getGender();
    for (var j = 0; j < vs.length; j++) {
      var s = scoreVoice(vs[j], bcp47, eng, gen);
      if (s > bestSc) { bestSc = s; best = vs[j]; }
    }
    return best;
  }

  function resolveCapVoiceIndex(lang) {
    var bcp47 = toBcp47(lang), vs = capVoices, vid = getVoiceId();
    if (!vs.length) return -1;
    if (vid && vid !== "auto") {
      if (/^\d+$/.test(vid) && vs[parseInt(vid, 10)]) return parseInt(vid, 10);
      for (var i = 0; i < vs.length; i++) {
        if (vs[i].voiceURI === vid || vs[i].name === vid) return i;
      }
    }
    var bestIdx = -1, bestSc = -999, eng = getEngine(), gen = getGender();
    for (var j = 0; j < vs.length; j++) {
      var s = scoreVoice(vs[j], bcp47, eng, gen);
      if (s > bestSc) { bestSc = s; bestIdx = j; }
    }
    return bestIdx;
  }

  function stopRawTts() {
    try { var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech; if (tts && tts.stop) tts.stop().catch(function () {}); } catch (e) {}
    try { if ("speechSynthesis" in window) window.speechSynthesis.cancel(); } catch (e) {}
  }

  function describeActive() {
    var eng = getEngine(), gen = getGender(), vid = getVoiceId(), rate = getRate(), bcp = toBcp47(getLang());
    if (vid && vid !== "auto") {
      var v = resolveWebVoice(getLang());
      var vname = v ? v.name : ("Voice #" + vid);
      return "Active: " + vname + " | " + rate + "x";
    }
    var eLbl = eng === "studio" ? "Studio MP3" : (eng === "device" ? "Offline Device" : "Indian Neural");
    return "Active: " + eLbl + " (" + (gen === "male" ? "Sir" : "Ma'am") + ") | " + bcp + " | " + rate + "x";
  }

  function ensurePlayerSelectPresets() {
    var sel = document.getElementById("audioVoiceSelect");
    if (!sel) return;
    syncingSelect = true;
    try {
      var grp = sel.querySelector('optgroup[data-ls-presets="1"]');
      if (!grp) {
        grp = document.createElement("optgroup");
        grp.setAttribute("data-ls-presets", "1");
        grp.label = "Law Studyes Voice Engines";
        PRESETS.forEach(function (p) {
          var opt = document.createElement("option");
          opt.value = p.val;
          opt.textContent = p.label;
          grp.appendChild(opt);
        });
        sel.insertBefore(grp, sel.firstChild);
      }

      var vid = getVoiceId();
      var targetVal = (vid && vid !== "auto") ? vid : ("__ls_mode:" + getEngine() + ":" + getGender());
      var found = false;
      for (var i = 0; i < sel.options.length; i++) {
        if (sel.options[i].value === targetVal) { sel.selectedIndex = i; found = true; break; }
      }
      if (!found && sel.options.length) {
        var fallback = "__ls_mode:" + getEngine() + ":" + getGender();
        for (var j = 0; j < sel.options.length; j++) {
          if (sel.options[j].value === fallback) { sel.selectedIndex = j; break; }
        }
      }
    } catch (e) {}
    finally { syncingSelect = false; }
  }

  function syncPlayerUi() {
    var oldDup = document.getElementById("lsUnifiedVoicePanel");
    if (oldDup) oldDup.remove();

    ensurePlayerSelectPresets();

    var spd = document.getElementById("audioSpeedSelect");
    if (spd) {
      var rStr = String(getRate());
      for (var i = 0; i < spd.options.length; i++) {
        if (parseFloat(spd.options[i].value) === parseFloat(rStr)) { spd.selectedIndex = i; break; }
      }
    }

    var hint = document.getElementById("lsPwVoiceActiveHint");
    if (hint) hint.textContent = describeActive();
  }

  function restartAudioEngineIfPlaying() {
    try {
      var eng = window.LSAudioEngine;
      if (!eng) return;
      var st = (typeof eng.getState === "function") ? eng.getState() : null;
      var isPlaying = !!(st && (st.playing || st.isPlaying) && !st.paused);
      if (!isPlaying && typeof window.speechSynthesis !== "undefined" && window.speechSynthesis.speaking) {
        var ppBtn = document.getElementById("audioPlayPauseBtn");
        if (ppBtn && /pause/i.test(String(ppBtn.textContent || ppBtn.getAttribute("aria-label") || ""))) {
          isPlaying = true;
        }
      }
      if (!isPlaying) return;

      if (typeof eng.setSpeed === "function") { try { eng.setSpeed(getRate()); } catch (e) {} }
      var curIdx = (st && typeof st.index === "number") ? st.index : ((st && typeof st.currentIndex === "number") ? st.currentIndex : -1);

      if (typeof eng.stopHardware === "function") eng.stopHardware();
      else if (typeof eng.stop === "function") eng.stop();
      else stopRawTts();

      setTimeout(function () {
        try {
          if (curIdx >= 0 && typeof eng.jumpTo === "function") eng.jumpTo(curIdx);
          else if (typeof eng.playTopic === "function") eng.playTopic();
          else if (typeof eng.play === "function") eng.play();
        } catch (err) {}
      }, 150);
    } catch (e) {}
  }

  function applySettings(patch, restartActive) {
    if (patch && typeof patch.engine === "string") try { localStorage.setItem(K_ENG, patch.engine); } catch (e) {}
    if (patch && typeof patch.gender === "string") try { localStorage.setItem(K_GEN, patch.gender); localStorage.setItem("ls_prof_gender_v1", patch.gender); } catch (e) {}
    if (patch && typeof patch.voiceId === "string") try { localStorage.setItem(K_VID, patch.voiceId); } catch (e) {}
    if (patch && patch.rate !== undefined) try { localStorage.setItem(K_RATE, String(patch.rate)); } catch (e) {}

    syncPlayerUi();

    var detail = { engine: getEngine(), gender: getGender(), voiceId: getVoiceId(), rate: getRate(), restartActive: restartActive !== false };
    try { window.dispatchEvent(new CustomEvent("ls:voice-settings-changed", { detail: detail })); } catch (e) {}

    if (restartActive !== false) {
      restartAudioEngineIfPlaying();
    }
  }

  function patchSpeechApis() {
    try {
      if ("speechSynthesis" in window && typeof window.speechSynthesis.speak === "function" && !window.speechSynthesis.__lsPatchedV322) {
        nativeWebSpeak = window.speechSynthesis.speak.bind(window.speechSynthesis);
        window.speechSynthesis.__lsPatchedV322 = true;
        window.speechSynthesis.speak = function (u) {
          try {
            if (u) {
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
      if (tts && typeof tts.speak === "function" && !tts.__lsPatchedV322) {
        nativeCapSpeak = tts.speak.bind(tts);
        tts.__lsPatchedV322 = true;
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
        : "Hello students! Testing " + eng + " " + (gen === "male" ? "Sir" : "Ma'am") + " voice engine.");

    stopRawTts();
    if (window.LSIndianProfessor && window.LSIndianProfessor.stop) window.LSIndianProfessor.stop();
    if (typeof showToast === "function") showToast(describeActive());

    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && typeof tts.speak === "function") {
      try { await tts.speak({ text: sample, lang: toBcp47(l), rate: getRate(), pitch: getPitch(), volume: 1.0 }); return; } catch (e) {}
    }
    if ("speechSynthesis" in window) {
      try { window.speechSynthesis.speak(new SpeechSynthesisUtterance(sample)); } catch (e) {}
    }
  }

  function wireRealPlayerControls() {
    try {
      var vcSel = document.getElementById("audioVoiceSelect");
      var vcHost = document.getElementById("lsPwVoiceHost");
      var spdSel = document.getElementById("audioSpeedSelect");

      if (vcSel && !vcSel.__lsBoundV322) {
        vcSel.__lsBoundV322 = true;
        vcSel.addEventListener("change", function () {
          if (syncingSelect) return;
          var val = String(vcSel.value || "");
          var txt = (vcSel.options[vcSel.selectedIndex] && vcSel.options[vcSel.selectedIndex].text) || "";
          if (val.indexOf("__ls_mode:") === 0) {
            var p = val.split(":");
            applySettings({ engine: p[1] || "studio", gender: p[2] || "female", voiceId: "auto" }, true);
          } else if (/studio|mp3/i.test(val + " " + txt)) {
            applySettings({ engine: "studio", voiceId: "auto" }, true);
          } else if (/offline|local|device/i.test(val + " " + txt)) {
            applySettings({ engine: "device", voiceId: val || "auto" }, true);
          } else {
            applySettings({ engine: "neural", voiceId: val || "auto" }, true);
          }
          if (typeof showToast === "function") showToast(describeActive());
        }, true);

        if (typeof MutationObserver !== "undefined") {
          new MutationObserver(function () {
            if (!syncingSelect) ensurePlayerSelectPresets();
          }).observe(vcSel, { childList: true });
        }
      }

      if (spdSel && !spdSel.__lsBoundV322) {
        spdSel.__lsBoundV322 = true;
        spdSel.addEventListener("change", function () {
          var r = parseFloat(spdSel.value);
          if (isFinite(r) && r >= 0.5 && r <= 2.0) {
            applySettings({ rate: r }, true);
            if (typeof showToast === "function") showToast("Speed: " + r + "x");
          }
        }, true);
      }

      if (vcHost && !document.getElementById("lsPwVoiceActionRow")) {
        var row = document.createElement("div");
        row.id = "lsPwVoiceActionRow";
        row.style.cssText = "display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:6px;";
        row.innerHTML =
          '<span id="lsPwVoiceActiveHint" style="font-size:11px;font-weight:700;color:#7B1E2B;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"></span>' +
          '<button type="button" id="lsPwTestVoiceBtn" style="padding:5px 11px;border-radius:8px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11px;font-weight:800;cursor:pointer;flex-shrink:0;">Test Voice</button>';
        vcHost.appendChild(row);
        row.querySelector("#lsPwTestVoiceBtn").addEventListener("click", testVoice);
      }

      syncPlayerUi();
    } catch (e) {}
  }

  window.LSVoiceController = {
    getEngine: getEngine, getGender: getGender, getVoiceId: getVoiceId, getRate: getRate, getPitch: getPitch,
    langToBcp47: toBcp47, applySettings: applySettings, testVoice: testVoice, describeActive: describeActive
  };

  function boot() {
    patchSpeechApis();
    loadWebVoices();
    loadCapVoices().then(syncPlayerUi);
    wireRealPlayerControls();
  }

  if ("speechSynthesis" in window && "onvoiceschanged" in window.speechSynthesis) {
    window.speechSynthesis.onvoiceschanged = function () { loadWebVoices(); syncPlayerUi(); };
  }
  window.addEventListener("ls:lang-changed", syncPlayerUi);
  window.addEventListener("DOMContentLoaded", function () {
    boot();
    setTimeout(boot, 500);
    setTimeout(boot, 1500);
    if (typeof MutationObserver !== "undefined" && document.body) {
      new MutationObserver(function () {
        if (document.getElementById("lsPwVoiceHost") && !document.getElementById("lsPwVoiceActionRow")) {
          wireRealPlayerControls();
        }
      }).observe(document.body, { childList: true, subtree: true });
    }
  });
})();