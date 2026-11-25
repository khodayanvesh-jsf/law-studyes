(function () {
  "use strict";
  if (window.__lsModularNavV305) return;
  window.__lsModularNavV305 = true;

  var activeTab = "library";
  var audioCollapsed = false;

  function setAudioCollapsed(collapsed) {
    audioCollapsed = !!collapsed;
    document.body.classList.toggle("ls-audio-collapsed", audioCollapsed);
  }

  function mountInsidePlayerHideBtn() {
    var bar = document.getElementById("audioPlayerBar");
    if (!bar || document.getElementById("lsAudioHideInlineBtn")) return;

    var badge = document.getElementById("audioModeBadge");
    var headerRow = badge ? badge.parentElement : null;

    var hideBtn = document.createElement("button");
    hideBtn.id = "lsAudioHideInlineBtn";
    hideBtn.type = "button";
    hideBtn.title = "Minimize Audio Player";
    hideBtn.setAttribute("aria-label", "Hide Audio Player");
    hideBtn.innerHTML = '<span>Hide</span><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>';
    hideBtn.addEventListener("click", function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      setAudioCollapsed(true);
    });

    if (headerRow) {
      headerRow.style.width = "100%";
      headerRow.appendChild(hideBtn);
    } else {
      hideBtn.style.position = "absolute";
      hideBtn.style.top = "8px";
      hideBtn.style.right = "10px";
      bar.appendChild(hideBtn);
    }
  }

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
      "main { padding-bottom: 168px !important; }" +
      "body.ls-audio-collapsed main { padding-bottom: 96px !important; }" +
      "header .font-editorial { white-space: nowrap !important; }" +
      "@media (max-width: 480px) { header .h-16 { gap: 4px !important; padding-left: 8px !important; padding-right: 8px !important; } header button, header a { padding-left: 6px !important; padding-right: 6px !important; font-size: 11px !important; } }" +
      "body.ls-in-module main, body.ls-in-module #cascadeFilterBar, body.ls-in-module #audioPlayerBar, body.ls-in-module #lsAudioShowFab { display: none !important; }" +
      "#audioPlayerBar { bottom: 80px !important; left: 10px !important; right: 10px !important; border-radius: 18px !important; border: 1.5px solid #E8D5D8 !important; box-shadow: 0 8px 24px rgba(123,30,43,0.14) !important; z-index: 82 !important; transition: transform 0.28s cubic-bezier(0.22,1,0.36,1), opacity 0.22s ease !important; }" +
      "body.ls-audio-collapsed #audioPlayerBar { transform: translateY(135%) !important; opacity: 0 !important; pointer-events: none !important; }" +
      /* Inline Hide button tucked neatly in top-right of player track row */
      "#lsAudioHideInlineBtn { margin-left: auto; display: inline-flex; align-items: center; gap: 3px; padding: 2px 9px; border-radius: 999px; border: 1px solid #E8D5D8; background: #FAF7F2; color: #7B1E2B; font-size: 10.5px; font-weight: 800; cursor: pointer; flex-shrink: 0; transition: background 0.15s ease, transform 0.15s ease; }" +
      "#lsAudioHideInlineBtn:active { transform: scale(0.92); background: #FBF1F2; }" +
      /* Floating Audio pill ONLY visible when player is collapsed */
      "#lsAudioShowFab { position: fixed; right: 14px; bottom: 82px; z-index: 86; background: #7B1E2B; color: #FAF7F2; border: 2px solid #FAD676; border-radius: 999px; padding: 8px 14px; font-size: 11.5px; font-weight: 800; box-shadow: 0 6px 20px rgba(123,30,43,0.3); cursor: pointer; display: inline-flex; align-items: center; gap: 6px; opacity: 0; transform: translateY(16px) scale(0.9); pointer-events: none; transition: transform 0.24s cubic-bezier(0.34,1.56,0.64,1), opacity 0.2s ease; }" +
      "body.ls-audio-collapsed #lsAudioShowFab { opacity: 1; transform: translateY(0) scale(1); pointer-events: auto; }" +
      "#lsAudioShowFab:active { transform: scale(0.92); }" +
      "#lsModularStage { display: none; padding: 12px 14px 96px; max-width: 900px; margin: 0 auto; }" +
      "#lsModularStage.active { display: block; animation: lsFadeSlideUp 0.26s cubic-bezier(0.22,1,0.36,1); }" +
      "#lsBottomNav { position: fixed; bottom: 10px; left: 10px; right: 10px; max-width: 620px; margin: 0 auto; z-index: 95; background: rgba(255,255,255,0.96); backdrop-filter: blur(12px); border: 1px solid #E8E0D5; border-radius: 22px; display: grid; grid-template-columns: repeat(5, 1fr); height: 62px; padding: 4px 6px; box-shadow: 0 10px 28px rgba(31,27,24,0.14); }" +
      ".ls-nav-btn { position: relative; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; font-size: 10px; font-weight: 700; color: #6E6259; border: none; background: transparent; border-radius: 16px; cursor: pointer; transition: color 0.2s ease, background 0.22s ease, transform 0.16s ease; }" +
      ".ls-nav-btn:active { transform: scale(0.9); }" +
      ".ls-nav-btn svg { width: 20px; height: 20px; stroke-width: 2; transition: transform 0.24s cubic-bezier(0.34,1.56,0.64,1); }" +
      ".ls-nav-btn.active { color: #7B1E2B; background: #FBF1F2; }" +
      ".ls-nav-btn.active svg { transform: translateY(-2px) scale(1.12); animation: lsPop 0.28s ease; }" +
      ".ls-nav-btn.active::after { content: ''; position: absolute; bottom: 3px; width: 18px; height: 3px; border-radius: 99px; background: #7B1E2B; }" +
      "#lsMoreSheet { position: fixed; inset: 0; z-index: 140; background: rgba(20,14,12,0.48); backdrop-filter: blur(3px); display: none; align-items: flex-end; justify-content: center; }" +
      "#lsMoreSheet.show { display: flex; }" +
      "#lsMoreCard { background: #FFFFFF; width: 100%; max-width: 540px; border-radius: 24px 24px 0 0; padding: 12px 16px 26px; box-shadow: 0 -10px 34px rgba(0,0,0,0.22); animation: lsSheetUp 0.28s cubic-bezier(0.22,1,0.36,1); }" +
      ".ls-sheet-handle { width: 42px; height: 4px; border-radius: 99px; background: #D6C7BC; margin: 0 auto 12px; }" +
      ".ls-tool-tile { padding: 12px; border-radius: 16px; border: 1px solid #E8E0D5; background: #FAF7F2; text-align: left; transition: transform 0.16s ease, border-color 0.2s ease; }" +
      ".ls-tool-tile:active { transform: scale(0.96); border-color: #7B1E2B; }" +
      "#lsOtaDiagModal { position: fixed; inset: 0; z-index: 10080; background: rgba(20,14,12,0.58); backdrop-filter: blur(3px); display: none; align-items: center; justify-content: center; padding: 14px; }" +
      "#lsOtaDiagModal.show { display: flex; }" +
      "#lsOtaDiagCard { background: #FFFFFF; width: 100%; max-width: 480px; max-height: 84vh; border-radius: 20px; padding: 16px; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 18px 40px rgba(0,0,0,0.28); animation: lsFadeSlideUp 0.22s ease; }" +
      "#lsOtaDiagPre { background: #1B1715; color: #F5EFE6; font-family: monospace; font-size: 11px; line-height: 1.45; padding: 12px; border-radius: 12px; overflow: auto; max-height: 48vh; white-space: pre-wrap; word-break: break-word; }";
    document.head.appendChild(style);

    var legacyToggle = document.getElementById("lsAudioMiniToggle");
    if (legacyToggle) legacyToggle.remove();

    mountInsidePlayerHideBtn();

    if (!document.getElementById("lsAudioShowFab")) {
      var showFab = document.createElement("button");
      showFab.id = "lsAudioShowFab";
      showFab.type = "button";
      showFab.innerHTML =
        '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.3"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3z"/><path d="M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>' +
        '<span>Audio</span>';
      showFab.addEventListener("click", function () { setAudioCollapsed(false); });
      document.body.appendChild(showFab);
    }

    if (!document.getElementById("lsOtaDiagModal")) {
      var dm = document.createElement("div");
      dm.id = "lsOtaDiagModal";
      dm.innerHTML =
        '<div id="lsOtaDiagCard">' +
          '<div class="flex items-center justify-between">' +
            '<div class="text-sm font-bold text-[#7B1E2B]">Live OTA Diagnostics</div>' +
            '<button type="button" id="lsOtaDiagClose" class="text-xs font-bold px-3 py-1 rounded-full bg-[#FAF7F2] text-[#5F554E]">Close</button>' +
          '</div>' +
          '<pre id="lsOtaDiagPre">Tap Run Live Check to inspect OTA status...</pre>' +
          '<div class="flex gap-2">' +
            '<button type="button" id="lsOtaDiagRun" class="flex-1 py-2 rounded-xl bg-[#7B1E2B] text-white text-xs font-bold">Run Live Check</button>' +
            '<button type="button" id="lsOtaDiagCopy" class="px-3.5 py-2 rounded-xl border border-[#7B1E2B] text-[#7B1E2B] text-xs font-bold">Copy</button>' +
          '</div>' +
        '</div>';
      document.body.appendChild(dm);
      dm.addEventListener("click", function (ev) {
        if (ev.target === dm || ev.target.id === "lsOtaDiagClose") dm.classList.remove("show");
      });
      dm.querySelector("#lsOtaDiagRun").addEventListener("click", runInAppOtaDiagnostics);
      dm.querySelector("#lsOtaDiagCopy").addEventListener("click", function () {
        var txt = (document.getElementById("lsOtaDiagPre") || {}).textContent || "";
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(txt).then(function () {
            if (typeof showToast === "function") showToast("OTA diagnostics copied!");
          }).catch(function () {});
        }
      });
    }

    if (document.getElementById("lsBottomNav")) return;

    var stage = document.createElement("div");
    stage.id = "lsModularStage";
    var mainHost = document.querySelector("main") || document.body;
    if (mainHost && mainHost.parentNode && mainHost !== document.body) {
      mainHost.parentNode.insertBefore(stage, mainHost);
    } else {
      document.body.appendChild(stage);
    }

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
          '<button type="button" id="lsMoreOtaDiag" class="ls-tool-tile col-span-2" style="background:#FFFBF0;border-color:#E8D5A8;"><div class="text-xs font-bold text-[#7B1E2B]">OTA Diagnostics (In-App)</div><div class="text-[10.5px] text-[#5F554E] mt-0.5">Check Vercel / GitHub status, active bundle &amp; exact download errors</div></button>' +
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
    var diagBtn = sheet.querySelector("#lsMoreOtaDiag");
    if (diagBtn) diagBtn.addEventListener("click", function () {
      sheet.classList.remove("show");
      openOtaDiagnostics();
    });
  }

  async function runInAppOtaDiagnostics() {
    var pre = document.getElementById("lsOtaDiagPre");
    if (!pre) return;
    var lines = [];
    function log(s) {
      lines.push(s);
      pre.textContent = lines.join("\n");
    }

    log("Time: " + new Date().toLocaleString());
    log("Online: " + navigator.onLine);
    log("Last OTA Status: " + (window.__lsOtaLastStatus || "N/A"));
    if (window.__lsOtaLastErrors && window.__lsOtaLastErrors.length) {
      log("Per-Mirror Download Errors:\n  - " + window.__lsOtaLastErrors.join("\n  - "));
    }

    var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
    if (!up) {
      log("Capgo Plugin: NOT PRESENT (Web/Preview mode)");
    } else {
      try {
        var cur = await up.current();
        log("Running Bundle: " + JSON.stringify(cur && (cur.bundle || cur)));
      } catch (e) { log("current() err: " + e.message); }
      try {
        var lst = await up.list();
        var bs = (lst && lst.bundles) ? lst.bundles : [];
        log("Stored Bundles (" + bs.length + "): " + bs.map(function (b) { return b.version + "[" + b.status + "]"; }).join(", "));
      } catch (e) { log("list() err: " + e.message); }
    }

    var checks = [
      { label: "Vercel JSON", url: "https://law-studyes.vercel.app/ota-version.json?t=" + Date.now(), method: "GET" },
      { label: "Vercel ZIP (HEAD)", url: "https://law-studyes.vercel.app/ota-bundle.zip?t=" + Date.now(), method: "HEAD" },
      { label: "GitHub Raw JSON", url: "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www/ota-version.json?t=" + Date.now(), method: "GET" }
    ];
    for (var i = 0; i < checks.length; i++) {
      var c = checks[i];
      var t0 = Date.now();
      try {
        var r = await fetch(c.url, { method: c.method, cache: "no-store" });
        var ms = Date.now() - t0;
        var extra = "";
        if (c.method === "GET" && r.ok) {
          var j = await r.json();
          extra = " ver=" + j.version + " size=" + j.sizeBytes;
        } else if (c.method === "HEAD") {
          extra = " len=" + (r.headers.get("content-length") || "?");
        }
        log("[OK] " + c.label + ": HTTP " + r.status + " (" + ms + "ms)" + extra);
      } catch (err) {
        log("[FAIL] " + c.label + ": " + ((err && err.message) || String(err)));
      }
    }
  }

  function openOtaDiagnostics() {
    var dm = document.getElementById("lsOtaDiagModal");
    if (dm) {
      dm.classList.add("show");
      runInAppOtaDiagnostics();
    }
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
  window.LSNav = { openTab: openTab, openOtaDiagnostics: openOtaDiagnostics };
})();