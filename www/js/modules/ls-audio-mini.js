(function () {
  "use strict";
  if (window.__lsAudioMiniV309) return;
  window.__lsAudioMiniV309 = true;

  function injectMiniCss() {
    var oldFix = document.getElementById("lsAudioLayoutFixV308");
    if (oldFix) oldFix.remove();
    if (document.getElementById("lsAudioMiniCssV309")) return;

    var st = document.createElement("style");
    st.id = "lsAudioMiniCssV309";
    st.textContent =
      "@keyframes lsMiniPulseAnim { 0%, 100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.35); opacity: 0.6; } }" +
      "main { padding-bottom: 146px !important; }" +
      "#audioPlayerBar, #lsAudioShowFab, #lsAudioHideInlineBtn, #lsAudioMiniToggle { display: none !important; }" +
      "body.ls-in-module #lsMiniPlayerBar:not(.ls-playing) { display: none !important; }" +
      "#lsMiniPlayerBar { position: fixed; left: 10px; right: 10px; bottom: 80px; max-width: 620px; margin: 0 auto; z-index: 84; background: #FFFFFF; border: 1.5px solid #E8D5D8; border-radius: 16px; padding: 7px 10px; display: flex; align-items: center; gap: 10px; box-shadow: 0 8px 22px rgba(123,30,43,0.14); box-sizing: border-box; transition: border-color 0.2s ease, background-color 0.2s ease; }" +
      "#lsMiniPlayerBar.ls-playing { border-color: #7B1E2B; background: #FFFDFB; }" +
      "#lsMiniOpenZone { flex: 1; min-width: 0; display: flex; align-items: center; gap: 9px; background: transparent; border: none; padding: 2px 0; text-align: left; cursor: pointer; }" +
      "#lsMiniIconWrap { width: 36px; height: 36px; border-radius: 50%; background: #FBF1F2; border: 1px solid #E8D5D8; color: #7B1E2B; display: flex; align-items: center; justify-content: center; flex-shrink: 0; position: relative; }" +
      "#lsMiniPulse { display: none; position: absolute; top: -1px; right: -1px; width: 9px; height: 9px; border-radius: 50%; background: #16A34A; border: 1.5px solid #FFFFFF; animation: lsMiniPulseAnim 1.3s ease-in-out infinite; }" +
      "#lsMiniPlayerBar.ls-playing #lsMiniPulse { display: block; }" +
      "#lsMiniTextCol { min-width: 0; flex: 1; }" +
      "#lsMiniSub { font-size: 10px; font-weight: 800; color: #7B1E2B; text-transform: uppercase; letter-spacing: 0.35px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
      "#lsMiniTitle { font-size: 12.5px; font-weight: 700; color: #1F1B18; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }" +
      "#lsMiniQuickPlayBtn { width: 40px; height: 40px; border-radius: 12px; border: none; background: #7B1E2B; color: #FFFFFF; display: flex; align-items: center; justify-content: center; flex-shrink: 0; cursor: pointer; box-shadow: 0 4px 10px rgba(123,30,43,0.25); transition: transform 0.14s ease; }" +
      "#lsMiniQuickPlayBtn:active { transform: scale(0.92); }" +
      "#lsMiniExpandBtn { padding: 8px 12px; border-radius: 11px; border: 1px solid #E8D5D8; background: #FAF7F2; color: #7B1E2B; font-size: 11.5px; font-weight: 800; flex-shrink: 0; cursor: pointer; white-space: nowrap; transition: transform 0.14s ease; }" +
      "#lsMiniExpandBtn:active { transform: scale(0.94); }";
    document.head.appendChild(st);
  }

  function updateMiniUi(snap) {
    if (!snap) return;
    var bar = document.getElementById("lsMiniPlayerBar");
    var subEl = document.getElementById("lsMiniSub");
    var titleEl = document.getElementById("lsMiniTitle");
    var svgEl = document.getElementById("lsMiniPlaySvg");
    if (!bar) return;

    bar.classList.toggle("ls-playing", !!snap.isPlaying);
    if (titleEl) titleEl.textContent = snap.activeTitle || snap.topicTitle || "Select a topic to listen";
    if (subEl) {
      if (snap.isPlaying) {
        subEl.textContent = "Playing" + (snap.counterText ? " \u00b7 " + snap.counterText : "");
      } else if (snap.isPaused) {
        subEl.textContent = "Paused \u00b7 Tap Player for controls";
      } else {
        subEl.textContent = "Audio Studio \u00b7 Tap to open";
      }
    }
    if (svgEl) {
      svgEl.innerHTML = snap.isPlaying
        ? '<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>'
        : '<polygon points="6 4 20 12 6 20 6 4"/>';
    }
  }

  function openFullWindow() {
    if (window.LSAudioWindow && typeof window.LSAudioWindow.open === "function") {
      window.LSAudioWindow.open();
    } else if (typeof showToast === "function") {
      showToast("Player window module loading...");
    }
  }

  function mountMiniBar() {
    injectMiniCss();

    ["lsAudioShowFab", "lsAudioHideInlineBtn", "lsAudioMiniToggle"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.remove();
    });

    if (document.getElementById("lsMiniPlayerBar")) return;

    var bar = document.createElement("div");
    bar.id = "lsMiniPlayerBar";
    bar.innerHTML =
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
    document.body.appendChild(bar);

    bar.querySelector("#lsMiniOpenZone").addEventListener("click", openFullWindow);
    bar.querySelector("#lsMiniExpandBtn").addEventListener("click", openFullWindow);
    bar.querySelector("#lsMiniQuickPlayBtn").addEventListener("click", function (ev) {
      ev.stopPropagation();
      if (window.LSAudioEngine && typeof window.LSAudioEngine.toggle === "function") {
        window.LSAudioEngine.toggle();
      } else {
        var btn = document.getElementById("audioPlayPauseBtn");
        if (btn) btn.click();
      }
    });

    if (window.LSAudioEngine && typeof window.LSAudioEngine.getSnapshot === "function") {
      updateMiniUi(window.LSAudioEngine.getSnapshot());
    }
  }

  window.addEventListener("ls:audio-state", function (ev) {
    updateMiniUi(ev && ev.detail);
  });

  window.LSAudioMini = { mount: mountMiniBar, update: updateMiniUi };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(mountMiniBar, 300);
    setTimeout(function () {
      mountMiniBar();
      if (window.LSAudioEngine && typeof window.LSAudioEngine.getSnapshot === "function") {
        updateMiniUi(window.LSAudioEngine.getSnapshot());
      }
    }, 1150);
  });
})();