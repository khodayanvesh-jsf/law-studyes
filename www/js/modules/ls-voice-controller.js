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