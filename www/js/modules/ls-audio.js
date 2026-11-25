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