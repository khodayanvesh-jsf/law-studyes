(function () {
  "use strict";
  if (window.__lsModularNavV304) return;
  window.__lsModularNavV304 = true;

  var activeTab = "library";
  var audioCollapsed = false;

  function injectMobileShell() {
    var oldStyle = document.getElementById("lsModularNavStyle");
    if (oldStyle) oldStyle.remove();

    var style = document.createElement("style");
    style.id = "lsModularNavStyle";
    style.textContent =
      "@keyframes lsFadeSlideUp { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: translateY(0); } }" +
      "@keyframes lsSheetUp { from { transform: translateY(100%); } to { transform: translateY(0); } }" +
      "@keyframes lsPop { 0% { transform: scale(0.88); } 60% { transform: scale(1.12); } 100% { transform: scale(1); } }" +
      "body { padding-bottom: 86px !important; }" +
      "main { padding-bottom: 164px !important; }" +
      "header .font-editorial { white-space: nowrap !important; }" +
      "@media (max-width: 480px) { header .h-16 { gap: 4px !important; padding-left: 8px !important; padding-right: 8px !important; } header button, header a { padding-left: 6px !important; padding-right: 6px !important; font-size: 11px !important; } }" +
      /* Hide Library-only filter & audio bars cleanly when on modular hubs */
      "body.ls-in-module main, body.ls-in-module #cascadeFilterBar, body.ls-in-module #audioPlayerBar, body.ls-in-module #lsAudioMiniToggle { display: none !important; }" +
      /* Float Audio Player Bar cleanly ABOVE the floating Bottom Dock */
      "#audioPlayerBar { bottom: 80px !important; left: 10px !important; right: 10px !important; border-radius: 18px !important; border: 1.5px solid #E8D5D8 !important; box-shadow: 0 8px 24px rgba(123,30,43,0.14) !important; z-index: 82 !important; transition: transform 0.28s cubic-bezier(0.22,1,0.36,1), opacity 0.24s ease !important; }" +
      "body.ls-audio-collapsed #audioPlayerBar { transform: translateY(130%) !important; opacity: 0 !important; pointer-events: none !important; }" +
      "#lsAudioMiniToggle { position: fixed; right: 14px; bottom: 82px; z-index: 86; background: #7B1E2B; color: #FAF7F2; border: 2px solid #FAD676; border-radius: 999px; padding: 7px 12px; font-size: 11px; font-weight: 800; box-shadow: 0 6px 18px rgba(123,30,43,0.28); cursor: pointer; display: flex; align-items: center; gap: 5px; transition: transform 0.2s ease, opacity 0.2s ease; }" +
      "#lsAudioMiniToggle:active { transform: scale(0.92); }" +
      "#lsModularStage { display: none; padding: 12px 14px 96px; max-width: 900px; margin: 0 auto; }" +
      "#lsModularStage.active { display: block; animation: lsFadeSlideUp 0.26s cubic-bezier(0.22,1,0.36,1); }" +
      /* Floating Glass Animated Bottom Navigation Dock */
      "#lsBottomNav { position: fixed; bottom: 10px; left: 10px; right: 10px; max-width: 620px; margin: 0 auto; z-index: 95; background: rgba(255,255,255,0.96); backdrop-filter: blur(12px); border: 1px solid #E8E0D5; border-radius: 22px; display: grid; grid-template-columns: repeat(5, 1fr); height: 62px; padding: 4px 6px; box-shadow: 0 10px 28px rgba(31,27,24,0.14); }" +
      ".ls-nav-btn { position: relative; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; font-size: 10px; font-weight: 700; color: #6E6259; border: none; background: transparent; border-radius: 16px; cursor: pointer; transition: color 0.2s ease, background 0.22s ease, transform 0.16s ease; }" +
      ".ls-nav-btn:active { transform: scale(0.9); }" +
      ".ls-nav-btn svg { width: 20px; height: 20px; stroke-width: 2; transition: transform 0.24s cubic-bezier(0.34,1.56,0.64,1); }" +
      ".ls-nav-btn.active { color: #7B1E2B; background: #FBF1F2; }" +
      ".ls-nav-btn.active svg { transform: translateY(-2px) scale(1.12); animation: lsPop 0.28s ease; }" +
      ".ls-nav-btn.active::after { content: ''; position: absolute; bottom: 3px; width: 18px; height: 3px; border-radius: 99px; background: #7B1E2B; }" +
      /* Animated Tools Bottom Sheet */
      "#lsMoreSheet { position: fixed; inset: 0; z-index: 140; background: rgba(20,14,12,0.48); backdrop-filter: blur(3px); display: none; align-items: flex-end; justify-content: center; }" +
      "#lsMoreSheet.show { display: flex; }" +
      "#lsMoreCard { background: #FFFFFF; width: 100%; max-width: 540px; border-radius: 24px 24px 0 0; padding: 12px 16px 26px; box-shadow: 0 -10px 34px rgba(0,0,0,0.22); animation: lsSheetUp 0.28s cubic-bezier(0.22,1,0.36,1); }" +
      ".ls-sheet-handle { width: 42px; height: 4px; border-radius: 99px; background: #D6C7BC; margin: 0 auto 12px; }" +
      ".ls-tool-tile { padding: 13px; border-radius: 16px; border: 1px solid #E8E0D5; background: #FAF7F2; text-align: left; transition: transform 0.16s ease, border-color 0.2s ease; }" +
      ".ls-tool-tile:active { transform: scale(0.96); border-color: #7B1E2B; }";
    document.head.appendChild(style);

    if (document.getElementById("lsBottomNav")) return;

    var stage = document.createElement("div");
    stage.id = "lsModularStage";
    var mainHost = document.querySelector("main") || document.body;
    if (mainHost && mainHost.parentNode && mainHost !== document.body) {
      mainHost.parentNode.insertBefore(stage, mainHost);
    } else {
      document.body.appendChild(stage);
    }

    // Audio Bar Collapse/Expand pill so students can read full-screen or pop up Audio anytime
    var audioToggle = document.createElement("button");
    audioToggle.id = "lsAudioMiniToggle";
    audioToggle.type = "button";
    audioToggle.textContent = "Hide Audio";
    audioToggle.addEventListener("click", function () {
      audioCollapsed = !audioCollapsed;
      document.body.classList.toggle("ls-audio-collapsed", audioCollapsed);
      audioToggle.textContent = audioCollapsed ? "Show Audio" : "Hide Audio";
    });
    document.body.appendChild(audioToggle);

    var nav = document.createElement("nav");
    nav.id = "lsBottomNav";
    nav.innerHTML =
      '<button type="button" class="ls-nav-btn" data-ls-nav="hub">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M3 10.5L12 3l9 7.5"/><path d="M5 10v10h14V10"/></svg>' +
        '<span>Hub</span></button>' +
      '<button type="button" class="ls-nav-btn active" data-ls-nav="library">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>' +
        '<span>Library</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="judgments">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M12 3v18"/><path d="M5 8h14"/><path d="M3 14l2-6 2 6a2 2 0 0 1-4 0z"/><path d="M17 14l2-6 2 6a2 2 0 0 1-4 0z"/></svg>' +
        '<span>Cases</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="drill">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="9"/><path d="M9 12l2 2 4-4"/></svg>' +
        '<span>Drill</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="more">' +
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>' +
        '<span>Tools</span></button>';
    document.body.appendChild(nav);

    var sheet = document.createElement("div");
    sheet.id = "lsMoreSheet";
    sheet.innerHTML =
      '<div id="lsMoreCard">' +
        '<div class="ls-sheet-handle"></div>' +
        '<div class="flex items-center justify-between mb-3">' +
          '<div class="text-sm font-bold text-[#7B1E2B]">Law Studyes Tools</div>' +
          '<button type="button" id="lsMoreClose" class="text-xs font-bold px-3 py-1 rounded-full bg-[#FAF7F2] text-[#5F554E]">Close</button>' +
        '</div>' +
        '<div class="grid grid-cols-2 gap-2.5">' +
          '<button type="button" data-ls-nav="viva" class="ls-tool-tile"><div class="text-xs font-bold text-[#7B1E2B]">Viva &amp; Exam Bank</div><div class="text-[10.5px] text-[#5F554E] mt-0.5">Short &amp; Long Q&amp;A</div></button>' +
          '<button type="button" data-ls-nav="lexicon" class="ls-tool-tile"><div class="text-xs font-bold text-[#7B1E2B]">Lexicon &amp; Maxims</div><div class="text-[10.5px] text-[#5F554E] mt-0.5">Legal Terms &amp; Latin</div></button>' +
          '<button type="button" data-ls-nav="shelf" class="ls-tool-tile"><div class="text-xs font-bold text-[#7B1E2B]">My Shelf</div><div class="text-[10.5px] text-[#5F554E] mt-0.5">Saved Bookmarks</div></button>' +
          '<button type="button" id="lsMoreForceOta" class="ls-tool-tile" style="border-color:#7B1E2B;background:#FBF1F2;"><div class="text-xs font-bold text-[#7B1E2B]">Check Live Sync</div><div class="text-[10.5px] text-[#5F554E] mt-0.5">Pull Latest OTA</div></button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(sheet);

    sheet.addEventListener("click", function (ev) {
      if (ev.target === sheet || ev.target.id === "lsMoreClose") sheet.classList.remove("show");
    });
    var otaBtn = sheet.querySelector("#lsMoreForceOta");
    if (otaBtn) otaBtn.addEventListener("click", function () {
      sheet.classList.remove("show");
      if (typeof window.__lsForceOtaUpdate === "function") window.__lsForceOtaUpdate();
    });
  }

  function setActiveNavHighlight(tab) {
    document.querySelectorAll("#lsBottomNav .ls-nav-btn").forEach(function (b) {
      var t = b.getAttribute("data-ls-nav");
      var isMoreChild = (tab === "viva" || tab === "lexicon" || tab === "shelf");
      b.classList.toggle("active", t === tab || (t === "more" && isMoreChild));
    });
  }

  function openTab(tab) {
    var sheet = document.getElementById("lsMoreSheet");
    if (tab === "more") {
      if (sheet) sheet.classList.add("show");
      return;
    }
    if (sheet) sheet.classList.remove("show");
    activeTab = tab;
    setActiveNavHighlight(tab);

    var stage = document.getElementById("lsModularStage");
    if (!stage) return;

    if (tab === "library") {
      document.body.classList.remove("ls-in-module");
      stage.classList.remove("active");
      return;
    }

    document.body.classList.add("ls-in-module");
    stage.classList.remove("active");
    void stage.offsetWidth;
    stage.classList.add("active");
    window.scrollTo(0, 0);

    if (tab === "hub" && window.LSHub) window.LSHub.render(stage);
    else if (tab === "judgments" && window.LSJudgments) window.LSJudgments.render(stage);
    else if (tab === "drill" && window.LSDrill) window.LSDrill.render(stage);
    else if (tab === "viva" && window.LSVault) window.LSVault.renderViva(stage);
    else if (tab === "lexicon" && window.LSVault) window.LSVault.renderLexicon(stage);
    else if (tab === "shelf" && window.LSVault) window.LSVault.renderShelf(stage);
  }

  document.addEventListener("click", function (ev) {
    var navEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-nav]") : null;
    if (navEl) { openTab(navEl.getAttribute("data-ls-nav")); return; }
    var topicEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-open-topic]") : null;
    if (topicEl) {
      var tid = topicEl.getAttribute("data-ls-open-topic");
      openTab("library");
      if (typeof state !== "undefined" && tid) {
        state.activeTopicId = tid;
        if (typeof window.renderReadingPane === "function") window.renderReadingPane();
      }
      return;
    }
    var subjEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-open-subject]") : null;
    if (subjEl) {
      var sid = subjEl.getAttribute("data-ls-open-subject");
      openTab("library");
      if (typeof state !== "undefined" && sid) {
        state.activeSubjectId = sid;
        if (typeof window.renderSidebar === "function") window.renderSidebar();
        var subj = (state.subjects || []).find(function (s) { return s.id === sid; });
        if (subj && subj.units && subj.units[0] && subj.units[0].topics && subj.units[0].topics[0]) {
          state.activeTopicId = subj.units[0].topics[0].id;
          if (typeof window.renderReadingPane === "function") window.renderReadingPane();
        }
      }
      return;
    }
    var shelfEl = ev.target && ev.target.closest ? ev.target.closest("[data-ls-shelf-id]") : null;
    if (shelfEl && window.LSStore) {
      var saved = window.LSStore.toggleShelf({
        id: shelfEl.getAttribute("data-ls-shelf-id"),
        title: shelfEl.getAttribute("data-ls-shelf-title"),
        subtitle: shelfEl.getAttribute("data-ls-shelf-sub") || ""
      });
      if (activeTab === "shelf") openTab("shelf");
      else {
        shelfEl.textContent = saved ? "Saved" : "Save";
        shelfEl.className = "text-[11px] px-2 py-0.5 rounded-full border border-[#7B1E2B] " + (saved ? "bg-[#7B1E2B] text-white" : "text-[#7B1E2B]");
      }
    }
  });

  window.addEventListener("DOMContentLoaded", injectMobileShell);
  window.LSNav = { openTab: openTab };
})();