(function () {
  "use strict";
  if (window.__lsSeparatePlayerWindowV309) return;
  window.__lsSeparatePlayerWindowV309 = true;

  var cachedVoiceIdx = {};
  var playerOpen = false;

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

  function injectSeparatePlayerCss() {
    var old = document.getElementById("lsAudioLayoutFixV308");
    if (old) old.remove();
    if (document.getElementById("lsSeparatePlayerCssV309")) return;

    var st = document.createElement("style");
    st.id = "lsSeparatePlayerCssV309";
    st.textContent =
      "@keyframes lsPlayerPopIn { from { opacity: 0; transform: translateY(22px) scale(0.97); } to { opacity: 1; transform: translateY(0) scale(1); } }" +
      "@keyframes lsPulseDot { 0%, 100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.35); opacity: 0.6; } }" +
      "main { padding-bottom: 142px !important; }" +
      "#audioPlayerBar, #lsAudioShowFab, #lsAudioHideInlineBtn, #lsAudioMiniToggle { display: none !important; }" +
      "body.ls-in-module #lsMiniPlayerBar:not(.ls-playing) { display: none !important; }" +
      "#lsMiniPlayerBar { position: fixed; left: 10px; right: 10px; bottom: 80px; max-width: 620px; margin: 0 auto; z-index: 84; background: #FFFFFF; border: 1.5px solid #E8D5D8; border-radius: 16px; padding: 7px 10px; display: flex; align-items: center; gap: 10px; box-shadow: 0 8px 22px rgba(123,30,43,0.14); box-sizing: border-box; }" +
      "#lsMiniPlayerBar.ls-playing { border-color: #7B1E2B; background: #FFFDFB; }" +
      "#lsMiniOpenZone { flex: 1; min-width: 0; display: flex; align-items: center; gap: 9px; background: transparent; border: none; padding: 2px 0; text-align: left; cursor: pointer; }" +
      "#lsMiniIconWrap { width: 34px; height: 34px; border-radius: 50%; background: #FBF1F2; border: 1px solid #E8D5D8; color: #7B1E2B; display: flex; align-items: center; justify-content: center; flex-shrink: 0; position: relative; }" +
      "#lsMiniPulse { display: none; position: absolute; top: -1px; right: -1px; width: 9px; height: 9px; border-radius: 50%; background: #16A34A; border: 1.5px solid #fff; animation: lsPulseDot 1.3s ease-in-out infinite; }" +
      "#lsMiniPlayerBar.ls-playing #lsMiniPulse { display: block; }" +
      "#lsMiniTextCol { min-width: 0; flex: 1; }" +
      "#lsMiniSub { font-size: 10px; font-weight: 800; color: #7B1E2B; text-transform: uppercase; letter-spacing: 0.4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
      "#lsMiniTitle { font-size: 12.5px; font-weight: 700; color: #1F1B18; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
      "#lsMiniQuickPlayBtn { width: 38px; height: 38px; border-radius: 12px; border: none; background: #7B1E2B; color: #FFFFFF; display: flex; align-items: center; justify-content: center; flex-shrink: 0; cursor: pointer; box-shadow: 0 4px 10px rgba(123,30,43,0.25); }" +
      "#lsMiniQuickPlayBtn:active { transform: scale(0.92); }" +
      "#lsMiniExpandBtn { padding: 7px 11px; border-radius: 11px; border: 1px solid #E8D5D8; background: #FAF7F2; color: #7B1E2B; font-size: 11px; font-weight: 800; flex-shrink: 0; cursor: pointer; white-space: nowrap; }" +
      "#lsMiniExpandBtn:active { transform: scale(0.94); }" +
      "#lsPlayerWindowModal { position: fixed; inset: 0; z-index: 10060; background: rgba(20,14,12,0.62); backdrop-filter: blur(5px); display: none; align-items: center; justify-content: center; padding: 14px; box-sizing: border-box; }" +
      "#lsPlayerWindowModal.show { display: flex; }" +
      "#lsPlayerWindowCard { width: 100%; max-width: 480px; max-height: 92vh; overflow-y: auto; background: #FAF7F2; border: 1.5px solid #E8D5D8; border-radius: 26px; box-shadow: 0 22px 54px rgba(20,10,12,0.36); animation: lsPlayerPopIn 0.26s cubic-bezier(0.22,1,0.36,1); display: flex; flex-direction: column; box-sizing: border-box; }" +
      ".ls-pw-header { background: linear-gradient(135deg, #7B1E2B 0%, #56111B 100%); color: #FAF7F2; padding: 14px 16px; display: flex; align-items: center; justify-content: space-between; gap: 10px; border-radius: 24px 24px 0 0; }" +
      ".ls-pw-close { width: 34px; height: 34px; border-radius: 50%; border: 1px solid rgba(255,255,255,0.28); background: rgba(255,255,255,0.14); color: #FFFFFF; font-size: 18px; font-weight: 700; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; }" +
      ".ls-pw-body { padding: 16px; display: flex; flex-direction: column; gap: 14px; }" +
      ".ls-pw-now { background: #FFFFFF; border: 1px solid #E8E0D5; border-radius: 18px; padding: 14px; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 3px 10px rgba(31,27,24,0.04); }" +
      ".ls-pw-now-top { display: flex; align-items: center; gap: 12px; }" +
      ".ls-pw-now #audioCurrentTitle { font-size: 14.5px !important; font-weight: 800 !important; color: #1F1B18 !important; white-space: normal !important; line-height: 1.35 !important; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }" +
      ".ls-pw-now #liveCaptionStrip { border-radius: 12px !important; border: 1px solid #EFE0E2 !important; padding: 8px 10px !important; }" +
      ".ls-pw-now #liveCaptionText { white-space: normal !important; line-height: 1.4 !important; font-size: 12px !important; }" +
      ".ls-pw-prog-wrap { height: 7px; width: 100%; background: #F0EAE2; border-radius: 999px; overflow: hidden; }" +
      ".ls-pw-prog-wrap #audioProgressBar { height: 100% !important; border-radius: 999px; }" +
      ".ls-pw-transport { background: #FFFFFF; border: 1px solid #E8E0D5; border-radius: 18px; padding: 14px 12px; display: flex; align-items: center; justify-content: space-evenly; gap: 10px; }" +
      ".ls-pw-transport #audioPrevBtn, .ls-pw-transport #audioStopBtn, .ls-pw-transport #audioNextBtn { width: 48px !important; height: 48px !important; padding: 0 !important; border-radius: 14px !important; border: 1.5px solid #E8E0D5 !important; background: #FAF7F2 !important; color: #1F1B18 !important; display: flex !important; align-items: center !important; justify-content: center !important; cursor: pointer; }" +
      ".ls-pw-transport #audioPlayPauseBtn { min-width: 118px !important; height: 52px !important; padding: 0 20px !important; border-radius: 16px !important; background: #7B1E2B !important; color: #FFFFFF !important; font-size: 15px !important; font-weight: 800 !important; display: flex !important; align-items: center !important; justify-content: center !important; gap: 8px !important; box-shadow: 0 8px 18px rgba(123,30,43,0.28) !important; cursor: pointer; }" +
      ".ls-pw-transport button:active { transform: scale(0.93); }" +
      ".ls-pw-scope { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }" +
      ".ls-pw-scope-btn { padding: 11px 10px; border-radius: 14px; border: 1.5px solid #E8D5D8; background: #FFFFFF; color: #7B1E2B; font-size: 12px; font-weight: 800; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px; }" +
      ".ls-pw-scope-btn.primary { background: #FBF1F2; border-color: #7B1E2B; }" +
      ".ls-pw-scope-btn:active { transform: scale(0.96); }" +
      ".ls-pw-settings { background: #FFFFFF; border: 1px solid #E8E0D5; border-radius: 18px; padding: 14px; display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }" +
      ".ls-pw-field { display: flex; flex-direction: column; gap: 5px; }" +
      ".ls-pw-field.full { grid-column: 1 / -1; }" +
      ".ls-pw-label { font-size: 10.5px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.4px; color: #5F554E; }" +
      ".ls-pw-settings #teachingModeBtn, .ls-pw-settings #repeatTopicBtn { width: 100% !important; min-height: 42px !important; padding: 8px 10px !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important; font-size: 12px !important; font-weight: 700 !important; box-sizing: border-box !important; }" +
      ".ls-pw-settings #teachingModeBtn span { display: inline !important; }" +
      ".ls-pw-settings #audioSpeedSelect, .ls-pw-settings #sleepTimerSelect, .ls-pw-settings #audioVoiceSelect { display: block !important; width: 100% !important; max-width: 100% !important; min-height: 42px !important; padding: 8px 10px !important; border-radius: 12px !important; border: 1.5px solid #E8E0D5 !important; background: #FAF7F2 !important; color: #1F1B18 !important; font-size: 12.5px !important; font-weight: 700 !important; box-sizing: border-box !important; }";
    document.head.appendChild(st);
  }

  function openPlayerWindow() {
    var modal = document.getElementById("lsPlayerWindowModal");
    if (!modal) return;
    playerOpen = true;
    modal.classList.add("show");
    syncMiniAndWindow();
  }

  function closePlayerWindow() {
    var modal = document.getElementById("lsPlayerWindowModal");
    if (!modal) return;
    playerOpen = false;
    modal.classList.remove("show");
  }

  function buildSeparatePlayerWindow() {
    if (document.getElementById("lsPlayerWindowModal")) return;

    ["lsAudioShowFab", "lsAudioHideInlineBtn", "lsAudioMiniToggle"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.remove();
    });

    var mini = document.createElement("div");
    mini.id = "lsMiniPlayerBar";
    mini.innerHTML =
      '<button type="button" id="lsMiniOpenZone" aria-label="Open Audio Player Window">' +
        '<div id="lsMiniIconWrap">' +
          '<svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3z"/><path d="M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>' +
          '<span id="lsMiniPulse"></span>' +
        '</div>' +
        '<div id="lsMiniTextCol">' +
          '<div id="lsMiniSub">Audio Studio &middot; Tap to open</div>' +
          '<div id="lsMiniTitle">Select a topic to listen</div>' +
        '</div>' +
      '</button>' +
      '<button type="button" id="lsMiniQuickPlayBtn" title="Play / Pause" aria-label="Play or Pause">' +
        '<svg id="lsMiniPlaySvg" viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><polygon points="6 4 20 12 6 20 6 4"/></svg>' +
      '</button>' +
      '<button type="button" id="lsMiniExpandBtn" title="Open Full Audio Player Window">Player</button>';
    document.body.appendChild(mini);

    var modal = document.createElement("div");
    modal.id = "lsPlayerWindowModal";
    modal.innerHTML =
      '<div id="lsPlayerWindowCard">' +
        '<div class="ls-pw-header">' +
          '<div>' +
            '<div style="font-size:15px;font-weight:800;letter-spacing:-0.2px;">Law Studyes Audio Player</div>' +
            '<div style="font-size:11px;opacity:0.86;">Indian Voice (EN / TE) &middot; Offline Reading Studio</div>' +
          '</div>' +
          '<button type="button" class="ls-pw-close" id="lsPlayerCloseBtn" title="Minimize to Reading View">&times;</button>' +
        '</div>' +
        '<div class="ls-pw-body">' +
          '<div class="ls-pw-now">' +
            '<div class="ls-pw-now-top" id="lsPwNowTop"></div>' +
            '<div class="ls-pw-prog-wrap" id="lsPwProgWrap"></div>' +
            '<div id="lsPwCaptionHost"></div>' +
          '</div>' +
          '<div class="ls-pw-transport" id="lsPwTransport"></div>' +
          '<div class="ls-pw-scope">' +
            '<button type="button" class="ls-pw-scope-btn primary" id="lsPwPlayTopicBtn">Listen Current Topic</button>' +
            '<button type="button" class="ls-pw-scope-btn" id="lsPwPlayUnitBtn">Listen Whole Unit</button>' +
          '</div>' +
          '<div class="ls-pw-settings">' +
            '<div class="ls-pw-field"><span class="ls-pw-label">Style</span><div id="lsPwTeachHost"></div></div>' +
            '<div class="ls-pw-field"><span class="ls-pw-label">Loop Topic</span><div id="lsPwRepeatHost"></div></div>' +
            '<div class="ls-pw-field"><span class="ls-pw-label">Speed</span><div id="lsPwSpeedHost"></div></div>' +
            '<div class="ls-pw-field"><span class="ls-pw-label">Sleep Timer</span><div id="lsPwSleepHost"></div></div>' +
            '<div class="ls-pw-field full"><span class="ls-pw-label">Voice Engine</span><div id="lsPwVoiceHost"></div></div>' +
          '</div>' +
        '</div>' +
      '</div>';
    document.body.appendChild(modal);

    var nowTop = modal.querySelector("#lsPwNowTop");
    var iconEl = document.getElementById("audioStatusIcon");
    var modeBadge = document.getElementById("audioModeBadge");
    var queueCounter = document.getElementById("audioQueueCounter");
    var titleEl = document.getElementById("audioCurrentTitle");
    if (iconEl) nowTop.appendChild(iconEl);
    var metaCol = document.createElement("div");
    metaCol.style.cssText = "min-width:0;flex:1;display:flex;flex-direction:column;gap:4px;";
    var badgeRow = document.createElement("div");
    badgeRow.style.cssText = "display:flex;align-items:center;gap:8px;flex-wrap:wrap;";
    if (modeBadge) badgeRow.appendChild(modeBadge);
    if (queueCounter) badgeRow.appendChild(queueCounter);
    metaCol.appendChild(badgeRow);
    if (titleEl) metaCol.appendChild(titleEl);
    nowTop.appendChild(metaCol);

    var progBar = document.getElementById("audioProgressBar");
    if (progBar) modal.querySelector("#lsPwProgWrap").appendChild(progBar);

    var capStrip = document.getElementById("liveCaptionStrip");
    if (capStrip) modal.querySelector("#lsPwCaptionHost").appendChild(capStrip);

    var transport = modal.querySelector("#lsPwTransport");
    ["audioPrevBtn", "audioPlayPauseBtn", "audioStopBtn", "audioNextBtn"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) transport.appendChild(el);
    });

    var teachBtn = document.getElementById("teachingModeBtn");
    if (teachBtn) modal.querySelector("#lsPwTeachHost").appendChild(teachBtn);

    var repBtn = document.getElementById("repeatTopicBtn");
    if (repBtn) {
      if (!repBtn.querySelector(".ls-rep-txt")) {
        var sp = document.createElement("span");
        sp.className = "ls-rep-txt";
        sp.textContent = "Repeat";
        repBtn.appendChild(sp);
      }
      modal.querySelector("#lsPwRepeatHost").appendChild(repBtn);
    }

    var spdSel = document.getElementById("audioSpeedSelect");
    if (spdSel) modal.querySelector("#lsPwSpeedHost").appendChild(spdSel);

    var slpSel = document.getElementById("sleepTimerSelect");
    if (slpSel) modal.querySelector("#lsPwSleepHost").appendChild(slpSel);

    var vcSel = document.getElementById("audioVoiceSelect");
    if (vcSel) modal.querySelector("#lsPwVoiceHost").appendChild(vcSel);

    mini.querySelector("#lsMiniOpenZone").addEventListener("click", openPlayerWindow);
    mini.querySelector("#lsMiniExpandBtn").addEventListener("click", openPlayerWindow);
    mini.querySelector("#lsMiniQuickPlayBtn").addEventListener("click", function (ev) {
      ev.stopPropagation();
      var mainPlay = document.getElementById("audioPlayPauseBtn");
      if (mainPlay) mainPlay.click();
    });

    modal.querySelector("#lsPlayerCloseBtn").addEventListener("click", closePlayerWindow);
    modal.addEventListener("click", function (ev) {
      if (ev.target === modal) closePlayerWindow();
    });

    modal.querySelector("#lsPwPlayTopicBtn").addEventListener("click", function () {
      if (typeof startTopicAudio === "function" && typeof state !== "undefined" && state.activeTopicId) {
        stopNativeAndWeb();
        startTopicAudio(state.activeTopicId);
      }
    });
    modal.querySelector("#lsPwPlayUnitBtn").addEventListener("click", function () {
      if (typeof startUnitAudio === "function" && typeof state !== "undefined" && state.activeSubjectId) {
        stopNativeAndWeb();
        startUnitAudio(state.activeSubjectId, state.expandedUnitNo);
      }
    });

    ["filterListenSubUnitBtn", "filterListenWholeUnitBtn"].forEach(function (fid) {
      var fb = document.getElementById(fid);
      if (fb && !fb.__lsOpenWinBound) {
        fb.__lsOpenWinBound = true;
        fb.addEventListener("click", function () {
          stopNativeAndWeb();
          setTimeout(openPlayerWindow, 80);
        }, true);
      }
    });
  }

  function syncMiniAndWindow() {
    if (typeof state === "undefined" || !state) return;
    var mini = document.getElementById("lsMiniPlayerBar");
    var miniTitle = document.getElementById("lsMiniTitle");
    var miniSub = document.getElementById("lsMiniSub");
    var miniSvg = document.getElementById("lsMiniPlaySvg");
    var titleEl = document.getElementById("audioCurrentTitle");
    var counterEl = document.getElementById("audioQueueCounter");
    var badgeEl = document.getElementById("audioModeBadge");

    var isPlaying = !!(state.audio && state.audio.isPlaying && !state.audio.isPaused);
    var isPaused = !!(state.audio && state.audio.isPlaying && state.audio.isPaused);

    var topicLabel = "Select a topic to listen";
    if (state.activeTopicId) {
      var rec = state.notes && state.notes[state.activeTopicId];
      var ld = rec ? (rec[state.lang] || rec.en) : null;
      var meta = (typeof findTopicMeta === "function") ? findTopicMeta(state.activeTopicId) : null;
      topicLabel = (ld && ld.title) || (meta && meta.topic && meta.topic.title) || state.activeTopicId;
    }

    if (titleEl && !isPlaying && !isPaused) {
      titleEl.textContent = topicLabel;
      if (counterEl) counterEl.textContent = "Ready to listen";
      if (badgeEl) badgeEl.textContent = "Topic Mode";
    }

    if (mini) mini.classList.toggle("ls-playing", isPlaying);
    if (miniTitle) miniTitle.textContent = (titleEl && titleEl.textContent) ? titleEl.textContent : topicLabel;
    if (miniSub) {
      if (isPlaying) {
        miniSub.textContent = "Playing" + (counterEl && counterEl.textContent ? " \u00b7 " + counterEl.textContent : "");
      } else if (isPaused) {
        miniSub.textContent = "Paused \u00b7 Tap Player for controls";
      } else {
        miniSub.textContent = "Audio Studio \u00b7 Tap to open";
      }
    }
    if (miniSvg) {
      miniSvg.innerHTML = isPlaying
        ? '<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>'
        : '<polygon points="6 4 20 12 6 20 6 4"/>';
    }
  }

  function wireUnifiedAudioControls() {
    patchNativeTtsPlugin();
    injectSeparatePlayerCss();
    buildSeparatePlayerWindow();

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
          syncMiniAndWindow();
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
          syncMiniAndWindow();
          return;
        }

        if (typeof startTopicAudio === "function" && state.activeTopicId) {
          startTopicAudio(state.activeTopicId);
          setTimeout(syncMiniAndWindow, 80);
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
        setTimeout(syncMiniAndWindow, 60);
      }, true);
    }

    ["audioPrevBtn", "audioNextBtn"].forEach(function (bid) {
      var b = document.getElementById(bid);
      if (b && !b.__lsSkipWrapped) {
        b.__lsSkipWrapped = true;
        b.addEventListener("click", function () {
          stopNativeAndWeb();
          setTimeout(syncMiniAndWindow, 80);
        }, true);
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

    if (typeof window.updateAudioUI === "function" && !window.__lsUpdateAudioHooked) {
      window.__lsUpdateAudioHooked = true;
      var origUpd = window.updateAudioUI;
      window.updateAudioUI = function () {
        var r = origUpd.apply(this, arguments);
        try { syncMiniAndWindow(); } catch (e) {}
        return r;
      };
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
          syncMiniAndWindow();
        } catch (e) {}
        return res;
      };
    }

    syncMiniAndWindow();
  }

  window.LSAudioWindow = {
    open: openPlayerWindow,
    close: closePlayerWindow,
    isOpen: function () { return playerOpen; }
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(wireUnifiedAudioControls, 250);
    setTimeout(wireUnifiedAudioControls, 1200);
  });
})();