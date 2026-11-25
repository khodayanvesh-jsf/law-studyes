(function () {
  "use strict";
  if (window.__lsAudioEngineV310) return;
  window.__lsAudioEngineV310 = true;
  var cachedVoice = {};

  function getNativeTts() {
    return window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
  }

  function getActiveBcp47() {
    var l = (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "en";
    if (l === "te") return "te-IN";
    if (l === "hi") return "hi-IN";
    return "en-IN";
  }

  async function resolveVoice(tts, targetLang) {
    var key = String(targetLang || getActiveBcp47()).toLowerCase();
    if (cachedVoice[key] !== undefined) return cachedVoice[key];
    var res = { lang: targetLang || getActiveBcp47(), voice: undefined };
    try {
      if (typeof tts.getSupportedVoices === "function") {
        var out = await tts.getSupportedVoices();
        var list = (out && Array.isArray(out.voices)) ? out.voices : [];
        var pref = key.split("-")[0], exact = -1, prefIdx = -1, enFb = -1;
        for (var i = 0; i < list.length; i++) {
          var vl = String((list[i] && list[i].lang) || "").toLowerCase().replace("_", "-");
          if (vl.indexOf("ar") === 0) continue;
          if (vl === key) { exact = i; break; }
          if (prefIdx === -1 && vl.indexOf(pref + "-") === 0) prefIdx = i;
          if (pref === "en" && enFb === -1 && (vl === "en-gb" || vl === "en-us")) enFb = i;
        }
        var pick = exact !== -1 ? exact : (prefIdx !== -1 ? prefIdx : enFb);
        if (pick !== -1) { res.voice = pick; res.lang = list[pick].lang || res.lang; }
      }
    } catch (e) {}
    cachedVoice[key] = res;
    return res;
  }

  function patchNativeTts() {
    var tts = getNativeTts();
    if (!tts || tts.__lsTriPatched) return;
    tts.__lsTriPatched = true;
    var rawSpeak = tts.speak.bind(tts);
    tts.speak = async function (opts) {
      var text = String((opts && opts.text) || "").trim();
      if (!text) return;
      var lang = getActiveBcp47();
      var r = await resolveVoice(tts, lang);
      var p = {
        text: text,
        lang: r.lang || lang,
        rate: Math.min(2.0, Math.max(0.6, Number((opts && opts.rate) || 1.15))),
        pitch: Number((opts && opts.pitch) || 1.0),
        volume: 1.0,
        category: "ambient"
      };
      if (typeof r.voice === "number") p.voice = r.voice;
      try { return await rawSpeak(p); }
      catch (err) {
        return rawSpeak({ text: text, lang: lang === "en-IN" ? "en-US" : lang, rate: p.rate, pitch: 1.0, volume: 1.0, category: "ambient" });
      }
    };
  }

  function patchWebSpeechLang() {
    if (typeof window.SpeechSynthesisUtterance === "undefined" || window.__lsWebTriPatched) return;
    window.__lsWebTriPatched = true;
    var origSpeak = window.speechSynthesis && window.speechSynthesis.speak ? window.speechSynthesis.speak.bind(window.speechSynthesis) : null;
    if (!origSpeak) return;
    window.speechSynthesis.speak = function (utter) {
      try {
        if (utter) {
          var target = getActiveBcp47();
          utter.lang = target;
          var vs = window.speechSynthesis.getVoices ? window.speechSynthesis.getVoices() : [];
          if (vs && vs.length) {
            var pref = target.split("-")[0];
            var match = vs.find(function (v) { return (v.lang || "").toLowerCase().replace("_", "-") === target.toLowerCase(); }) ||
                        vs.find(function (v) { return (v.lang || "").toLowerCase().indexOf(pref + "-") === 0; });
            if (match) utter.voice = match;
          }
        }
      } catch (e) {}
      return origSpeak(utter);
    };
  }

  function stopHardware() {
    var tts = getNativeTts();
    if (tts && typeof tts.stop === "function") { try { tts.stop().catch(function () {}); } catch (e) {} }
    if (typeof window.speechSynthesis !== "undefined") { try { window.speechSynthesis.cancel(); } catch (e) {} }
  }

  function getSnapshot() {
    var ok = (typeof state !== "undefined" && state);
    var aud = (ok && state.audio) ? state.audio : {};
    var title = "Select a topic to listen";
    if (ok && state.activeTopicId) {
      var rec = state.notes && state.notes[state.activeTopicId];
      var ld = rec ? (rec[state.lang] || rec.en) : null;
      var meta = (typeof findTopicMeta === "function") ? findTopicMeta(state.activeTopicId) : null;
      title = (ld && ld.title) || (meta && meta.topic && meta.topic.title) || state.activeTopicId;
    }
    var tEl = document.getElementById("audioCurrentTitle");
    var cEl = document.getElementById("audioQueueCounter");
    return {
      isPlaying: !!(aud.isPlaying && !aud.isPaused),
      isPaused: !!(aud.isPlaying && aud.isPaused),
      topicTitle: title,
      activeTitle: (tEl && tEl.textContent) ? tEl.textContent : title,
      counterText: (cEl && cEl.textContent) ? cEl.textContent : "Ready to listen",
      mode: aud.mode || "topic",
      lang: getActiveBcp47()
    };
  }

  function emitState() {
    var s = getSnapshot();
    var tEl = document.getElementById("audioCurrentTitle");
    var cEl = document.getElementById("audioQueueCounter");
    var bEl = document.getElementById("audioModeBadge");
    if (tEl && !s.isPlaying && !s.isPaused) {
      tEl.textContent = s.topicTitle;
      if (cEl) cEl.textContent = "Ready (" + s.lang + ")";
      if (bEl) bEl.textContent = "Topic Mode";
    }
    window.dispatchEvent(new CustomEvent("ls:audio-state", { detail: s }));
  }

  function togglePlayPause() {
    patchNativeTts();
    patchWebSpeechLang();
    if (typeof state === "undefined" || !state.audio) return;
    var hasNative = !!getNativeTts(), hasWeb = ("speechSynthesis" in window);
    if (!hasNative && !hasWeb) { if (typeof showToast === "function") showToast("Install Google Speech Services for audio."); return; }

    if (state.audio.isPlaying && !state.audio.isPaused) {
      clearTimeout(state.audio.pauseTimerHandle);
      state.audio.isPaused = true;
      if (hasNative) stopHardware();
      else { try { window.speechSynthesis.pause(); } catch (e) { window.speechSynthesis.cancel(); } }
      if (typeof updateAudioUI === "function") updateAudioUI();
      emitState();
      return;
    }
    if (state.audio.isPlaying && state.audio.isPaused) {
      state.audio.isPaused = false;
      if (hasNative) { if (typeof playQueueIndex === "function") playQueueIndex(state.audio.index || 0, state.audio.chunkIndex || 0); }
      else if (hasWeb && window.speechSynthesis.paused) { window.speechSynthesis.resume(); if (typeof updateAudioUI === "function") updateAudioUI(); }
      else if (typeof playQueueIndex === "function") { playQueueIndex(state.audio.index || 0, state.audio.chunkIndex || 0); }
      emitState();
      return;
    }
    if (typeof startTopicAudio === "function" && state.activeTopicId) {
      startTopicAudio(state.activeTopicId);
      setTimeout(emitState, 80);
    }
  }

  function stopAll() {
    if (typeof state !== "undefined" && state.audio) {
      clearTimeout(state.audio.pauseTimerHandle);
      state.audio.isPlaying = false;
      state.audio.isPaused = false;
    }
    stopHardware();
    if (typeof updateAudioUI === "function") updateAudioUI();
    setTimeout(emitState, 60);
  }

  function bindEngine() {
    patchNativeTts();
    patchWebSpeechLang();
    var pBtn = document.getElementById("audioPlayPauseBtn");
    if (pBtn && !pBtn.__lsEng) {
      pBtn.__lsEng = true;
      var fresh = pBtn.cloneNode(true);
      pBtn.parentNode.replaceChild(fresh, pBtn);
      fresh.addEventListener("click", function (ev) { ev.preventDefault(); ev.stopPropagation(); togglePlayPause(); });
    }
    var sBtn = document.getElementById("audioStopBtn");
    if (sBtn && !sBtn.__lsStop) { sBtn.__lsStop = true; sBtn.addEventListener("click", function () { stopAll(); }, true); }
    ["audioPrevBtn", "audioNextBtn"].forEach(function (id) {
      var b = document.getElementById(id);
      if (b && !b.__lsSkip) { b.__lsSkip = true; b.addEventListener("click", function () { stopHardware(); setTimeout(emitState, 80); }, true); }
    });
    var spd = document.getElementById("audioSpeedSelect");
    if (spd && !spd.__lsSpd) {
      spd.__lsSpd = true;
      spd.addEventListener("change", function () {
        if (typeof state !== "undefined" && state.audio) {
          state.audio.speed = parseFloat(spd.value) || 1.15;
          if (state.audio.isPlaying && !state.audio.isPaused && typeof playQueueIndex === "function") {
            stopHardware(); playQueueIndex(state.audio.index || 0, state.audio.chunkIndex || 0);
          }
        }
      });
    }
    if (typeof window.updateAudioUI === "function" && !window.__lsEngUpd) {
      window.__lsEngUpd = true;
      var oU = window.updateAudioUI;
      window.updateAudioUI = function () { var r = oU.apply(this, arguments); try { emitState(); } catch (e) {} return r; };
    }
    if (typeof window.renderReadingPane === "function" && !window.__lsEngRen) {
      window.__lsEngRen = true;
      var oR = window.renderReadingPane;
      window.renderReadingPane = function () {
        var r = oR.apply(this, arguments);
        try {
          if (typeof state !== "undefined" && state.audio && state.audio.queue && state.audio.queue.length) {
            var cur = state.audio.queue[state.audio.index || 0];
            if (cur && cur.topicId && state.activeTopicId && cur.topicId !== state.activeTopicId && state.audio.mode !== "unit") {
              stopHardware(); clearTimeout(state.audio.pauseTimerHandle);
              state.audio.isPlaying = false; state.audio.isPaused = false; state.audio.queue = [];
              if (typeof updateAudioUI === "function") updateAudioUI();
            }
          }
          emitState();
        } catch (e) {}
        return r;
      };
    }
    emitState();
  }

  window.addEventListener("ls:lang-changed", function () {
    cachedVoice = {};
    stopAll();
  });

  window.LSAudioEngine = {
    toggle: togglePlayPause,
    stop: stopAll,
    stopHardware: stopHardware,
    playTopic: function () { if (typeof startTopicAudio === "function" && state && state.activeTopicId) { stopHardware(); startTopicAudio(state.activeTopicId); setTimeout(emitState, 80); } },
    playUnit: function () { if (typeof startUnitAudio === "function" && state && state.activeSubjectId) { stopHardware(); startUnitAudio(state.activeSubjectId, state.expandedUnitNo); setTimeout(emitState, 80); } },
    getSnapshot: getSnapshot,
    emitState: emitState
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(bindEngine, 250);
    setTimeout(bindEngine, 1100);
  });
})();