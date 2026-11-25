(function () {
  "use strict";
  if (window.__lsAudioWindowV309) return;
  window.__lsAudioWindowV309 = true;

  var isOpen = false;

  function injectWindowCss() {
    if (document.getElementById("lsAudioWindowCssV309")) return;
    var st = document.createElement("style");
    st.id = "lsAudioWindowCssV309";
    st.textContent =
      "@keyframes lsPwPopIn { from { opacity: 0; transform: translateY(24px) scale(0.96); } to { opacity: 1; transform: translateY(0) scale(1); } }" +
      "#lsPlayerWindowModal { position: fixed; inset: 0; z-index: 10060; background: rgba(20,14,12,0.64); backdrop-filter: blur(5px); display: none; align-items: center; justify-content: center; padding: 14px; box-sizing: border-box; }" +
      "#lsPlayerWindowModal.show { display: flex; }" +
      "#lsPlayerWindowCard { width: 100%; max-width: 480px; max-height: 92vh; overflow-y: auto; background: #FAF7F2; border: 1.5px solid #E8D5D8; border-radius: 26px; box-shadow: 0 22px 54px rgba(20,10,12,0.36); animation: lsPwPopIn 0.25s cubic-bezier(0.22,1,0.36,1); display: flex; flex-direction: column; box-sizing: border-box; }" +
      ".ls-pw-header { background: linear-gradient(135deg, #7B1E2B 0%, #56111B 100%); color: #FAF7F2; padding: 14px 16px; display: flex; align-items: center; justify-content: space-between; gap: 10px; border-radius: 24px 24px 0 0; }" +
      ".ls-pw-close { width: 36px; height: 36px; border-radius: 50%; border: 1px solid rgba(255,255,255,0.28); background: rgba(255,255,255,0.14); color: #FFFFFF; font-size: 20px; font-weight: 700; display: flex; align-items: center; justify-content: center; cursor: pointer; flex-shrink: 0; }" +
      ".ls-pw-close:active { transform: scale(0.92); }" +
      ".ls-pw-body { padding: 16px; display: flex; flex-direction: column; gap: 14px; }" +
      ".ls-pw-now { background: #FFFFFF; border: 1px solid #E8E0D5; border-radius: 18px; padding: 14px; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 3px 10px rgba(31,27,24,0.04); }" +
      ".ls-pw-now-top { display: flex; align-items: center; gap: 12px; }" +
      ".ls-pw-now #audioStatusIcon { width: 44px !important; height: 44px !important; flex-shrink: 0 !important; }" +
      ".ls-pw-now #audioCurrentTitle { font-size: 14.5px !important; font-weight: 800 !important; color: #1F1B18 !important; white-space: normal !important; line-height: 1.35 !important; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }" +
      ".ls-pw-now #liveCaptionStrip { border-radius: 12px !important; border: 1px solid #EFE0E2 !important; padding: 8px 10px !important; }" +
      ".ls-pw-now #liveCaptionText { white-space: normal !important; line-height: 1.4 !important; font-size: 12px !important; }" +
      ".ls-pw-prog-wrap { height: 7px; width: 100%; background: #F0EAE2; border-radius: 999px; overflow: hidden; }" +
      ".ls-pw-prog-wrap #audioProgressBar { height: 100% !important; border-radius: 999px; }" +
      ".ls-pw-transport { background: #FFFFFF; border: 1px solid #E8E0D5; border-radius: 18px; padding: 14px 12px; display: flex; align-items: center; justify-content: space-evenly; gap: 10px; }" +
      ".ls-pw-transport #audioPrevBtn, .ls-pw-transport #audioStopBtn, .ls-pw-transport #audioNextBtn { width: 48px !important; height: 48px !important; padding: 0 !important; border-radius: 14px !important; border: 1.5px solid #E8E0D5 !important; background: #FAF7F2 !important; color: #1F1B18 !important; display: flex !important; align-items: center !important; justify-content: center !important; cursor: pointer; flex-shrink: 0; }" +
      ".ls-pw-transport #audioPlayPauseBtn { min-width: 118px !important; height: 52px !important; padding: 0 20px !important; border-radius: 16px !important; background: #7B1E2B !important; color: #FFFFFF !important; font-size: 15px !important; font-weight: 800 !important; display: flex !important; align-items: center !important; justify-content: center !important; gap: 8px !important; box-shadow: 0 8px 18px rgba(123,30,43,0.28) !important; cursor: pointer; flex-shrink: 0; }" +
      ".ls-pw-transport button:active { transform: scale(0.93); }" +
      ".ls-pw-scope { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }" +
      ".ls-pw-scope-btn { min-height: 44px; padding: 10px; border-radius: 14px; border: 1.5px solid #E8D5D8; background: #FFFFFF; color: #7B1E2B; font-size: 12px; font-weight: 800; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 6px; }" +
      ".ls-pw-scope-btn.primary { background: #FBF1F2; border-color: #7B1E2B; }" +
      ".ls-pw-scope-btn:active { transform: scale(0.96); }" +
      ".ls-pw-settings { background: #FFFFFF; border: 1px solid #E8E0D5; border-radius: 18px; padding: 14px; display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }" +
      ".ls-pw-field { display: flex; flex-direction: column; gap: 5px; min-width: 0; }" +
      ".ls-pw-field.full { grid-column: 1 / -1; }" +
      ".ls-pw-label { font-size: 10.5px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.4px; color: #5F554E; }" +
      ".ls-pw-settings #teachingModeBtn, .ls-pw-settings #repeatTopicBtn { width: 100% !important; min-height: 44px !important; padding: 8px 10px !important; border-radius: 12px !important; display: flex !important; align-items: center !important; justify-content: center !important; gap: 6px !important; font-size: 12px !important; font-weight: 700 !important; box-sizing: border-box !important; }" +
      ".ls-pw-settings #teachingModeBtn span { display: inline !important; }" +
      ".ls-pw-settings #audioSpeedSelect, .ls-pw-settings #sleepTimerSelect, .ls-pw-settings #audioVoiceSelect { display: block !important; width: 100% !important; max-width: 100% !important; min-height: 44px !important; padding: 8px 10px !important; border-radius: 12px !important; border: 1.5px solid #E8E0D5 !important; background: #FAF7F2 !important; color: #1F1B18 !important; font-size: 12.5px !important; font-weight: 700 !important; box-sizing: border-box !important; }";
    document.head.appendChild(st);
  }

  function openWindow() {
    var modal = document.getElementById("lsPlayerWindowModal");
    if (!modal) {
      mountWindow();
      modal = document.getElementById("lsPlayerWindowModal");
    }
    if (!modal) return;
    isOpen = true;
    modal.classList.add("show");
    if (window.LSAudioEngine && typeof window.LSAudioEngine.emitState === "function") {
      window.LSAudioEngine.emitState();
    }
  }

  function closeWindow() {
    var modal = document.getElementById("lsPlayerWindowModal");
    if (!modal) return;
    isOpen = false;
    modal.classList.remove("show");
  }

  function mountWindow() {
    injectWindowCss();
    if (document.getElementById("lsPlayerWindowModal")) return;

    var modal = document.createElement("div");
    modal.id = "lsPlayerWindowModal";
    modal.innerHTML =
      '<div id="lsPlayerWindowCard">' +
        '<div class="ls-pw-header">' +
          '<div>' +
            '<div style="font-size:15px;font-weight:800;letter-spacing:-0.2px;">Law Studyes Audio Player</div>' +
            '<div style="font-size:11px;opacity:0.86;">Indian Voice (EN / TE / HI) &middot; Spacious Controls</div>' +
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

    // Reparent real DOM controls so all native/core listeners keep working
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

    modal.querySelector("#lsPlayerCloseBtn").addEventListener("click", closeWindow);
    modal.addEventListener("click", function (ev) {
      if (ev.target === modal) closeWindow();
    });

    modal.querySelector("#lsPwPlayTopicBtn").addEventListener("click", function () {
      if (window.LSAudioEngine && typeof window.LSAudioEngine.playTopic === "function") {
        window.LSAudioEngine.playTopic();
      } else if (typeof startTopicAudio === "function" && typeof state !== "undefined" && state.activeTopicId) {
        startTopicAudio(state.activeTopicId);
      }
    });

    modal.querySelector("#lsPwPlayUnitBtn").addEventListener("click", function () {
      if (window.LSAudioEngine && typeof window.LSAudioEngine.playUnit === "function") {
        window.LSAudioEngine.playUnit();
      } else if (typeof startUnitAudio === "function" && typeof state !== "undefined" && state.activeSubjectId) {
        startUnitAudio(state.activeSubjectId, state.expandedUnitNo);
      }
    });

    ["filterListenSubUnitBtn", "filterListenWholeUnitBtn"].forEach(function (fid) {
      var fb = document.getElementById(fid);
      if (fb && !fb.__lsOpenWinBound) {
        fb.__lsOpenWinBound = true;
        fb.addEventListener("click", function () {
          if (window.LSAudioEngine && typeof window.LSAudioEngine.stopHardware === "function") {
            window.LSAudioEngine.stopHardware();
          }
          setTimeout(openWindow, 80);
        }, true);
      }
    });

    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape" && isOpen) closeWindow();
    });
  }

  window.LSAudioWindow = {
    open: openWindow,
    close: closeWindow,
    isOpen: function () { return isOpen; },
    mount: mountWindow
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(mountWindow, 350);
    setTimeout(mountWindow, 1200);
  });
})();