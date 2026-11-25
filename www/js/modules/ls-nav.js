(function () {
  "use strict";
  if (window.__lsModularNavV3) return;
  window.__lsModularNavV3 = true;

  var activeTab = "library";

  function injectMobileShell() {
    if (document.getElementById("lsBottomNav")) return;

    var style = document.createElement("style");
    style.textContent =
      "body { padding-bottom: 66px !important; }" +
      "#lsModularStage { display:none; padding: 12px 14px 78px; max-width: 900px; margin: 0 auto; }" +
      "#lsModularStage.active { display:block; }" +
      "#lsBottomNav { position:fixed; bottom:0; left:0; right:0; z-index:90; background:#FFFFFF; border-top:1px solid #E8E0D5; display:grid; grid-template-columns:repeat(5,1fr); height:60px; box-shadow:0 -4px 16px rgba(31,27,24,0.06); }" +
      ".ls-nav-btn { display:flex; flex-direction:column; align-items:center; justify-content:center; gap:2px; font-size:10.5px; font-weight:700; color:#5F554E; border:none; background:transparent; cursor:pointer; }" +
      ".ls-nav-btn.active { color:#7B1E2B; }" +
      ".ls-nav-btn.active .ls-nav-dot { width:20px; height:3px; border-radius:99px; background:#7B1E2B; margin-bottom:2px; }" +
      "#lsMoreSheet { position:fixed; inset:0; z-index:130; background:rgba(0,0,0,0.45); display:none; align-items:flex-end; justify-content:center; }" +
      "#lsMoreSheet.show { display:flex; }" +
      "#lsMoreCard { background:#FFFFFF; width:100%; max-width:540px; border-radius:22px 22px 0 0; padding:18px 16px 26px; box-shadow:0 -8px 30px rgba(0,0,0,0.18); }";
    document.head.appendChild(style);

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
      '<button type="button" class="ls-nav-btn" data-ls-nav="hub"><span class="ls-nav-dot"></span><span>Study Hub</span></button>' +
      '<button type="button" class="ls-nav-btn active" data-ls-nav="library"><span class="ls-nav-dot"></span><span>Library</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="judgments"><span class="ls-nav-dot"></span><span>Judgments</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="drill"><span class="ls-nav-dot"></span><span>Exam Drill</span></button>' +
      '<button type="button" class="ls-nav-btn" data-ls-nav="more"><span class="ls-nav-dot"></span><span>More</span></button>';
    document.body.appendChild(nav);

    var sheet = document.createElement("div");
    sheet.id = "lsMoreSheet";
    sheet.innerHTML =
      '<div id="lsMoreCard">' +
        '<div class="flex items-center justify-between mb-3">' +
          '<div class="text-sm font-bold text-[#7B1E2B]">Law Studyes Tools</div>' +
          '<button type="button" id="lsMoreClose" class="text-xs font-bold px-2.5 py-1 rounded-lg bg-[#FAF7F2] text-[#5F554E]">Close</button>' +
        '</div>' +
        '<div class="grid grid-cols-2 gap-2.5">' +
          '<button type="button" data-ls-nav="viva" class="p-3 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">Viva &amp; Exam Bank</div><div class="text-[10.5px] text-[#5F554E]">Short &amp; Long Q&amp;A</div></button>' +
          '<button type="button" data-ls-nav="lexicon" class="p-3 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">Lexicon &amp; Maxims</div><div class="text-[10.5px] text-[#5F554E]">Legal Terms &amp; Latin</div></button>' +
          '<button type="button" data-ls-nav="shelf" class="p-3 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">My Shelf</div><div class="text-[10.5px] text-[#5F554E]">Saved Bookmarks</div></button>' +
          '<button type="button" id="lsMoreForceOta" class="p-3 rounded-xl border border-[#7B1E2B] bg-[#FBF1F2] text-left"><div class="text-xs font-bold text-[#7B1E2B]">Check Live Sync</div><div class="text-[10.5px] text-[#5F554E]">Pull Latest OTA</div></button>' +
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
    var mainHost = document.querySelector("main");
    if (!stage) return;

    if (tab === "library") {
      stage.classList.remove("active");
      if (mainHost) mainHost.style.display = "";
      return;
    }

    if (mainHost) mainHost.style.display = "none";
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
    if (navEl) {
      openTab(navEl.getAttribute("data-ls-nav"));
      return;
    }
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

  window.addEventListener("DOMContentLoaded", function () {
    injectMobileShell();
    setTimeout(function () {
      if (typeof window.renderReadingPane === "function" && !window.__lsProgressHooked) {
        window.__lsProgressHooked = true;
        var origR = window.renderReadingPane;
        window.renderReadingPane = function () {
          var res = origR.apply(this, arguments);
          try {
            if (typeof state !== "undefined" && state.activeTopicId && window.LSStore) {
              var rec = state.notes && state.notes[state.activeTopicId];
              window.LSStore.markTopicRead(state.activeTopicId, (rec && rec.subtitle) || state.activeTopicId);
            }
          } catch (e) {}
          return res;
        };
      }
    }, 500);
  });

  window.LSNav = { openTab: openTab };
})();
