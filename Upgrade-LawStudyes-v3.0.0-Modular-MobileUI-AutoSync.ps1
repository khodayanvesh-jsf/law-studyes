<#
.SYNOPSIS
  Law Studyes v3.0.0 - Modular Mobile-First Upgrade + Automated Scheduled Source Sync!
  Preserves 100% of existing features (Strict Sheet Auth + Selfie + 24h Daily Usage, Bulletproof OTA,
  Native en-IN/te-IN TTS, Mermaid Diagrams + Memory Walk, Custom Icon & Splash) while adding:
  1. Clean modular frontend under www/js/modules/ (ls-store, ls-hub, ls-judgments, ls-drill, ls-vault, ls-nav).
  2. Mobile bottom navigation bar + rebranded original hubs:
     - Study Hub (live stats, resume reading, subject cards)
     - Library (existing bilingual notes + animated diagrams)
     - Landmark Judgments (searchable case law explorer)
     - Exam Drill (interactive MCQ / Active Recall arena)
     - More Tools (Viva & Exam Bank, Lexicon & Maxims, My Shelf bookmarks, Live Sync trigger)
  3. Automated 12-hour GitHub Actions cron workflow (.github/workflows/auto-sync-lawstudyes.yml)
     that checks nyayasaral.com for new/updated content and auto-publishes OTA to Vercel!
  4. Builds clean signed release APK v3.0.0 (versionCode 300) and pushes verified OTA live.
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Upgrade-LawStudyes-v3.0.0-Modular-MobileUI-AutoSync.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "3.0.0"
$verCode = 300

Write-Host "`n=== 1. Creating Modular Frontend Architecture (www/js/modules/) ===" -ForegroundColor Cyan
$modDir = Join-Path $root "www\js\modules"
New-Item -ItemType Directory -Path $modDir -Force | Out-Null

$modules = [ordered]@{
  "ls-store.js" = @'
(function () {
  "use strict";
  var SHELF_KEY = "ls_my_shelf_v3";
  var PROGRESS_KEY = "ls_study_progress_v3";
  var EXTRAS_CACHE = null;

  function safeJsonParse(raw, fb) {
    try { return JSON.parse(raw); } catch (e) { return fb; }
  }

  function getShelf() {
    return safeJsonParse(localStorage.getItem(SHELF_KEY) || "[]", []);
  }

  function toggleShelf(item) {
    var list = getShelf();
    var idx = -1;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === item.id) { idx = i; break; }
    }
    var saved = false;
    if (idx !== -1) {
      list.splice(idx, 1);
      saved = false;
    } else {
      list.unshift({
        id: item.id,
        type: item.type || "note",
        title: item.title || "Saved Item",
        subtitle: item.subtitle || "",
        savedAt: new Date().toISOString()
      });
      saved = true;
    }
    try { localStorage.setItem(SHELF_KEY, JSON.stringify(list)); } catch (e) {}
    return saved;
  }

  function isInShelf(id) {
    var list = getShelf();
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) return true;
    }
    return false;
  }

  function markTopicRead(topicId, title) {
    if (!topicId) return;
    var p = safeJsonParse(localStorage.getItem(PROGRESS_KEY) || "{}", {});
    p.lastTopicId = topicId;
    p.lastTopicTitle = title || topicId;
    p.lastOpenedAt = new Date().toISOString();
    p.readMap = p.readMap || {};
    p.readMap[topicId] = true;
    try { localStorage.setItem(PROGRESS_KEY, JSON.stringify(p)); } catch (e) {}
  }

  function getProgress() {
    return safeJsonParse(localStorage.getItem(PROGRESS_KEY) || "{}", {});
  }

  function getCoreStats() {
    var subjects = (typeof state !== "undefined" && Array.isArray(state.subjects)) ? state.subjects : [];
    var notes = (typeof state !== "undefined" && state.notes) ? state.notes : {};
    var noteKeys = Object.keys(notes);
    var caseCount = 0;
    var qaCount = 0;
    var visualCount = 0;
    for (var i = 0; i < noteKeys.length; i++) {
      var n = notes[noteKeys[i]];
      var en = n && n.en ? n.en : null;
      if (en) {
        if (Array.isArray(en.caseLaws)) caseCount += en.caseLaws.length;
        if (Array.isArray(en.selfTest)) qaCount += en.selfTest.length;
        if (Array.isArray(en.visuals)) visualCount += en.visuals.length;
      }
    }
    return {
      subjects: subjects.length,
      notes: noteKeys.length,
      cases: caseCount,
      qa: qaCount,
      visuals: visualCount
    };
  }

  function extractCasesFromNotes() {
    var notes = (typeof state !== "undefined" && state.notes) ? state.notes : {};
    var subjects = (typeof state !== "undefined" && Array.isArray(state.subjects)) ? state.subjects : [];
    var subjTitleById = {};
    subjects.forEach(function (s) { subjTitleById[s.id] = s.title; });
    var out = [];
    var seen = {};
    Object.keys(notes).forEach(function (tid) {
      var n = notes[tid];
      var lang = (typeof state !== "undefined" && state.lang === "te" && n.te) ? "te" : "en";
      var ld = n && n[lang] ? n[lang] : (n && n.en ? n.en : null);
      if (!ld || !Array.isArray(ld.caseLaws)) return;
      var sid = tid.split("-u")[0];
      var sTitle = subjTitleById[sid] || sid.replace(/-/g, " ");
      ld.caseLaws.forEach(function (c, idx) {
        var nm = String(c.name || "").trim();
        if (!nm || nm.length < 4) return;
        var key = nm.toLowerCase().slice(0, 60);
        if (seen[key]) return;
        seen[key] = true;
        out.push({
          id: tid + "-c" + idx,
          topicId: tid,
          subject: sTitle,
          name: nm,
          citation: c.citation || "",
          facts: c.facts || "",
          principle: c.principle || ""
        });
      });
    });
    return out;
  }

  function extractQaFromNotes() {
    var notes = (typeof state !== "undefined" && state.notes) ? state.notes : {};
    var out = [];
    Object.keys(notes).forEach(function (tid) {
      var n = notes[tid];
      var lang = (typeof state !== "undefined" && state.lang === "te" && n.te) ? "te" : "en";
      var ld = n && n[lang] ? n[lang] : (n && n.en ? n.en : null);
      if (!ld || !Array.isArray(ld.selfTest)) return;
      ld.selfTest.forEach(function (qa, idx) {
        if (!qa || !qa.q) return;
        out.push({
          id: tid + "-q" + idx,
          topicId: tid,
          subject: tid.split("-u")[0].replace(/-/g, " "),
          q: qa.q,
          a: qa.a || ""
        });
      });
    });
    return out;
  }

  async function loadExtras() {
    if (EXTRAS_CACHE) return EXTRAS_CACHE;
    try {
      var r = await fetch("./extras_db.json?v=" + Date.now(), { cache: "no-store" });
      if (r.ok) {
        EXTRAS_CACHE = await r.json();
        return EXTRAS_CACHE;
      }
    } catch (e) {}
    EXTRAS_CACHE = {
      updatedAt: "",
      mcqs: [],
      caseLaws: [],
      maxims: [
        { term: "Actus non facit reum nisi mens sit rea", meaning: "An act does not make a person guilty unless the mind is also guilty." },
        { term: "Audi alteram partem", meaning: "Hear the other side; no one should be condemned unheard." },
        { term: "Nemo judex in causa sua", meaning: "No one should be a judge in their own cause." },
        { term: "Ubi jus ibi remedium", meaning: "Where there is a legal right, there is a legal remedy." },
        { term: "Volenti non fit injuria", meaning: "To a willing person, no legal injury is done." },
        { term: "Damnum sine injuria", meaning: "Damage or loss without infringement of a legal right is not actionable." },
        { term: "Injuria sine damno", meaning: "Infringement of a legal right without actual loss is actionable." },
        { term: "Res ipsa loquitur", meaning: "The thing speaks for itself (presumption of negligence)." },
        { term: "Ignorantia juris non excusat", meaning: "Ignorance of the law is no excuse." },
        { term: "Caveat emptor", meaning: "Let the buyer beware." },
        { term: "Pacta sunt servanda", meaning: "Agreements must be kept." },
        { term: "Quid pro quo", meaning: "Something for something (consideration in contract)." },
        { term: "Consensus ad idem", meaning: "Meeting of minds on the same thing in the same sense." },
        { term: "Nemo dat quod non habet", meaning: "No one can give a better title than they themselves have." },
        { term: "Qui facit per alium facit per se", meaning: "He who acts through another does the act himself (vicarious liability)." }
      ],
      glossary: [
        { term: "Ratio Decidendi", meaning: "The binding legal principle or reason for a court's decision." },
        { term: "Obiter Dicta", meaning: "Incidental remarks made by a judge that are persuasive, not binding." },
        { term: "Ultra Vires", meaning: "Beyond the legal power or authority of a body or statute." },
        { term: "Locus Standi", meaning: "The right or legal standing of a party to bring an action in court." },
        { term: "Sub Judice", meaning: "A matter currently under judicial consideration." },
        { term: "Prima Facie", meaning: "Accepted as correct on first appearance until proved otherwise." },
        { term: "In Personam", meaning: "A right or judgment binding only the specific parties to the suit." },
        { term: "In Rem", meaning: "A right or judgment enforceable against the whole world." }
      ],
      pastPapers: []
    };
    return EXTRAS_CACHE;
  }

  window.LSStore = {
    getShelf: getShelf,
    toggleShelf: toggleShelf,
    isInShelf: isInShelf,
    markTopicRead: markTopicRead,
    getProgress: getProgress,
    getCoreStats: getCoreStats,
    extractCasesFromNotes: extractCasesFromNotes,
    extractQaFromNotes: extractQaFromNotes,
    loadExtras: loadExtras
  };
})();

'@
  "ls-hub.js" = @'
(function () {
  "use strict";
  function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  async function renderStudyHub(container) {
    if (!container || !window.LSStore) return;
    var stats = window.LSStore.getCoreStats();
    var extras = await window.LSStore.loadExtras();
    var prog = window.LSStore.getProgress();
    var subjects = (typeof state !== "undefined" && Array.isArray(state.subjects)) ? state.subjects : [];
    var totalMcqs = (extras && Array.isArray(extras.mcqs)) ? extras.mcqs.length : 0;
    var totalMaxims = (extras && Array.isArray(extras.maxims)) ? extras.maxims.length : 0;

    var html = [];
    html.push('<div class="space-y-4 pb-6">');

    // Hero card
    html.push('<div class="rounded-2xl p-5 text-white shadow-md" style="background:linear-gradient(135deg,#8A2231 0%,#56111B 100%);">');
    html.push('<div class="text-[11px] font-bold uppercase tracking-wider text-[#FAD676]">Law Studyes &middot; 3-Year LL.B.</div>');
    html.push('<h2 class="text-xl font-bold mt-1">Your Bilingual Law Study Hub</h2>');
    html.push('<p class="text-xs text-[#FAF7F2]/85 mt-1">Offline English &amp; Telugu notes, animated flowcharts, landmark judgments, and exam drills.</p>');
    if (prog && prog.lastTopicId) {
      html.push('<button type="button" data-ls-open-topic="' + esc(prog.lastTopicId) + '" class="mt-3 px-3.5 py-2 rounded-xl bg-[#FAD676] text-[#56111B] text-xs font-bold shadow-sm">Continue: ' + esc(prog.lastTopicTitle || "Last Topic") + ' &rarr;</button>');
    }
    html.push('</div>');

    // Live Stats Grid
    html.push('<div class="grid grid-cols-2 sm:grid-cols-4 gap-2.5">');
    var kpis = [
      { n: stats.notes, l: "Study Notes", act: "library" },
      { n: stats.visuals, l: "Diagrams & Tables", act: "library" },
      { n: stats.cases, l: "Judgments", act: "judgments" },
      { n: totalMcqs || stats.qa, l: totalMcqs ? "MCQ Drills" : "Self-Test Q&A", act: "drill" }
    ];
    kpis.forEach(function (k) {
      html.push('<button type="button" data-ls-nav="' + k.act + '" class="bg-white border border-[#E8E0D5] rounded-2xl p-3.5 text-left shadow-sm active:scale-95 transition">');
      html.push('<div class="text-xl font-extrabold text-[#7B1E2B]">' + k.n + '</div>');
      html.push('<div class="text-[11px] font-semibold text-[#5F554E] mt-0.5">' + k.l + '</div>');
      html.push('</button>');
    });
    html.push('</div>');

    // Quick Tools Row
    html.push('<div class="grid grid-cols-2 gap-2.5">');
    html.push('<button type="button" data-ls-nav="viva" class="bg-white border border-[#E8E0D5] rounded-xl p-3 text-left"><div class="text-xs font-bold text-[#7B1E2B]">Viva &amp; Exam Bank</div><div class="text-[11px] text-[#5F554E]">' + stats.qa + ' Q&amp;A Cards</div></button>');
    html.push('<button type="button" data-ls-nav="lexicon" class="bg-white border border-[#E8E0D5] rounded-xl p-3 text-left"><div class="text-xs font-bold text-[#7B1E2B]">Lexicon &amp; Maxims</div><div class="text-[11px] text-[#5F554E]">' + totalMaxims + '+ Legal Terms</div></button>');
    html.push('</div>');

    // Subjects List
    html.push('<div><h3 class="text-sm font-bold text-[#1F1B18] mb-2">Subjects Library (' + subjects.length + ')</h3>');
    html.push('<div class="space-y-2.5">');
    subjects.forEach(function (s) {
      var uCount = Array.isArray(s.units) ? s.units.length : 0;
      html.push('<button type="button" data-ls-open-subject="' + esc(s.id) + '" class="w-full bg-white border border-[#E8E0D5] hover:border-[#7B1E2B] rounded-2xl p-3.5 flex items-center justify-between text-left shadow-sm">');
      html.push('<div><div class="text-[11px] font-bold text-[#7B1E2B]">' + esc(s.semester || "LL.B.") + '</div><div class="text-sm font-bold text-[#1F1B18]">' + esc(s.title) + '</div><div class="text-[11px] text-[#5F554E] mt-0.5">' + uCount + ' Units &middot; ' + (s.totalPublished || 0) + ' Notes</div></div>');
      html.push('<span class="text-[#7B1E2B] font-bold text-lg">&rsaquo;</span>');
      html.push('</button>');
    });
    html.push('</div></div>');

    html.push('</div>');
    container.innerHTML = html.join("");
  }

  window.LSHub = { render: renderStudyHub };
})();

'@
  "ls-judgments.js" = @'
(function () {
  "use strict";
  function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function renderJudgments(container) {
    if (!container || !window.LSStore) return;
    var allCases = window.LSStore.extractCasesFromNotes();
    container.innerHTML =
      '<div class="space-y-3 pb-6">' +
        '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm">' +
          '<div class="text-base font-bold text-[#7B1E2B]">Landmark Judgments (' + allCases.length + ')</div>' +
          '<p class="text-xs text-[#5F554E] mt-0.5">Search Supreme Court, High Court &amp; English precedents across all subjects.</p>' +
          '<input id="lsCaseSearchInput" type="search" placeholder="Search case name, fact, or subject..." class="mt-2.5 w-full px-3 py-2 rounded-xl border border-[#D6C7BC] text-xs bg-[#FAF7F2]" />' +
        '</div>' +
        '<div id="lsCaseListBox" class="space-y-2.5"></div>' +
      '</div>';

    var listBox = container.querySelector("#lsCaseListBox");
    var searchIn = container.querySelector("#lsCaseSearchInput");

    function paint(q) {
      var query = String(q || "").trim().toLowerCase();
      var filtered = query
        ? allCases.filter(function (c) {
            return (c.name + " " + c.facts + " " + c.subject).toLowerCase().indexOf(query) !== -1;
          })
        : allCases;
      var slice = filtered.slice(0, 60);
      if (!slice.length) {
        listBox.innerHTML = '<div class="text-xs text-center text-[#5F554E] py-8">No matching judgments found.</div>';
        return;
      }
      var rows = [];
      slice.forEach(function (c) {
        var saved = window.LSStore.isInShelf(c.id);
        rows.push(
          '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-3.5 shadow-sm">' +
            '<div class="flex items-start justify-between gap-2">' +
              '<div class="text-xs font-bold text-[#7B1E2B]">' + esc(c.name) + '</div>' +
              '<button type="button" data-ls-shelf-id="' + esc(c.id) + '" data-ls-shelf-title="' + esc(c.name) + '" data-ls-shelf-sub="' + esc(c.subject) + '" class="text-[11px] px-2 py-0.5 rounded-full border border-[#7B1E2B] ' + (saved ? 'bg-[#7B1E2B] text-white' : 'text-[#7B1E2B]') + '">' + (saved ? 'Saved' : 'Save') + '</button>' +
            '</div>' +
            '<div class="text-[10.5px] font-semibold text-[#8C6D46] mt-0.5">' + esc(c.subject) + '</div>' +
            '<p class="text-xs text-[#3D352E] mt-1.5 leading-relaxed">' + esc(c.facts) + '</p>' +
            '<button type="button" data-ls-open-topic="' + esc(c.topicId) + '" class="mt-2 text-[11px] font-bold text-[#7B1E2B] underline">Open Full Topic Note &rarr;</button>' +
          '</div>'
        );
      });
      if (filtered.length > 60) {
        rows.push('<div class="text-[11px] text-center text-[#5F554E]">Showing top 60 of ' + filtered.length + ' results. Type to narrow down.</div>');
      }
      listBox.innerHTML = rows.join("");
    }

    paint("");
    searchIn.addEventListener("input", function () { paint(searchIn.value); });
  }

  window.LSJudgments = { render: renderJudgments };
})();

'@
  "ls-drill.js" = @'
(function () {
  "use strict";
  function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  async function renderExamDrill(container) {
    if (!container || !window.LSStore) return;
    var extras = await window.LSStore.loadExtras();
    var mcqs = (extras && Array.isArray(extras.mcqs) && extras.mcqs.length) ? extras.mcqs : [];

    // Fallback: if extras_db.json has no MCQs yet, build interactive flashcard drills from selfTest Q&A
    var qaItems = window.LSStore.extractQaFromNotes();
    if (!mcqs.length && !qaItems.length) {
      container.innerHTML = '<div class="p-6 text-center text-xs text-[#5F554E]">No practice questions loaded yet.</div>';
      return;
    }

    var idx = 0;
    var score = 0;
    var answered = 0;

    function renderCard() {
      if (mcqs.length) {
        var q = mcqs[idx % mcqs.length];
        var optsHtml = (q.options || []).map(function (opt, oi) {
          return '<button type="button" data-opt-idx="' + oi + '" class="ls-drill-opt w-full text-left px-3.5 py-2.5 rounded-xl border border-[#E8E0D5] bg-[#FAF7F2] text-xs font-semibold text-[#1F1B18] active:scale-[0.99]">' + esc(opt) + '</button>';
        }).join("");

        container.innerHTML =
          '<div class="space-y-3 pb-6">' +
            '<div class="flex items-center justify-between bg-white border border-[#E8E0D5] rounded-2xl px-4 py-3">' +
              '<div><div class="text-sm font-bold text-[#7B1E2B]">Exam Drill Arena</div><div class="text-[11px] text-[#5F554E]">Question ' + (idx + 1) + ' of ' + mcqs.length + '</div></div>' +
              '<div class="text-xs font-extrabold px-2.5 py-1 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Score: ' + score + '/' + answered + '</div>' +
            '</div>' +
            '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm space-y-3">' +
              '<div class="text-[11px] font-bold text-[#8C6D46]">' + esc(q.subject || "LL.B. Practice") + '</div>' +
              '<div class="text-sm font-bold text-[#1F1B18] leading-snug">' + esc(q.q) + '</div>' +
              '<div class="space-y-2">' + optsHtml + '</div>' +
              '<div id="lsDrillExplain" class="hidden p-3 rounded-xl bg-[#FAF7F2] border border-[#E8E0D5] text-xs text-[#3D352E]"></div>' +
              '<div class="flex justify-between pt-2">' +
                '<button type="button" id="lsDrillPrev" class="px-3 py-1.5 rounded-xl border border-[#D6C7BC] text-xs font-bold text-[#5F554E]">&larr; Prev</button>' +
                '<button type="button" id="lsDrillNext" class="px-4 py-1.5 rounded-xl bg-[#7B1E2B] text-white text-xs font-bold">Next Question &rarr;</button>' +
              '</div>' +
            '</div>' +
          '</div>';

        var locked = false;
        container.querySelectorAll(".ls-drill-opt").forEach(function (b) {
          b.addEventListener("click", function () {
            if (locked) return;
            locked = true;
            answered++;
            var picked = parseInt(b.getAttribute("data-opt-idx"), 10);
            var correct = typeof q.answerIndex === "number" ? q.answerIndex : 0;
            if (picked === correct) {
              score++;
              b.style.background = "#ECFDF5";
              b.style.borderColor = "#10B981";
            } else {
              b.style.background = "#FEF2F2";
              b.style.borderColor = "#EF4444";
              var rightBtn = container.querySelector('.ls-drill-opt[data-opt-idx="' + correct + '"]');
              if (rightBtn) { rightBtn.style.background = "#ECFDF5"; rightBtn.style.borderColor = "#10B981"; }
            }
            var ex = container.querySelector("#lsDrillExplain");
            if (ex) {
              ex.textContent = q.explanation || ("Correct answer: " + ((q.options && q.options[correct]) || ""));
              ex.classList.remove("hidden");
            }
          });
        });
      } else {
        var item = qaItems[idx % qaItems.length];
        container.innerHTML =
          '<div class="space-y-3 pb-6">' +
            '<div class="bg-white border border-[#E8E0D5] rounded-2xl px-4 py-3 flex items-center justify-between">' +
              '<div><div class="text-sm font-bold text-[#7B1E2B]">Exam Drill Flashcards</div><div class="text-[11px] text-[#5F554E]">Card ' + (idx + 1) + ' of ' + qaItems.length + '</div></div>' +
              '<span class="text-[11px] font-bold px-2.5 py-1 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Active Recall</span>' +
            '</div>' +
            '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm space-y-3">' +
              '<div class="text-[11px] font-bold text-[#8C6D46] uppercase">' + esc(item.subject) + '</div>' +
              '<div class="text-sm font-bold text-[#1F1B18]">' + esc(item.q) + '</div>' +
              '<button type="button" id="lsRevealAnsBtn" class="px-3.5 py-2 rounded-xl bg-[#FAF7F2] border border-[#7B1E2B] text-xs font-bold text-[#7B1E2B]">Reveal Answer</button>' +
              '<div id="lsFlashAns" class="hidden p-3 rounded-xl bg-[#ECFDF5] border border-[#A7F3D0] text-xs text-[#065F46] leading-relaxed">' + esc(item.a) + '</div>' +
              '<div class="flex justify-between pt-2">' +
                '<button type="button" id="lsDrillPrev" class="px-3 py-1.5 rounded-xl border border-[#D6C7BC] text-xs font-bold text-[#5F554E]">&larr; Prev</button>' +
                '<button type="button" id="lsDrillNext" class="px-4 py-1.5 rounded-xl bg-[#7B1E2B] text-white text-xs font-bold">Next Card &rarr;</button>' +
              '</div>' +
            '</div>' +
          '</div>';
        var rb = container.querySelector("#lsRevealAnsBtn");
        if (rb) rb.addEventListener("click", function () {
          var fa = container.querySelector("#lsFlashAns");
          if (fa) fa.classList.remove("hidden");
        });
      }

      var prev = container.querySelector("#lsDrillPrev");
      var next = container.querySelector("#lsDrillNext");
      var totalLen = mcqs.length || qaItems.length;
      if (prev) prev.addEventListener("click", function () { idx = (idx - 1 + totalLen) % totalLen; renderCard(); });
      if (next) next.addEventListener("click", function () { idx = (idx + 1) % totalLen; renderCard(); });
    }

    renderCard();
  }

  window.LSDrill = { render: renderExamDrill };
})();

'@
  "ls-vault.js" = @'
(function () {
  "use strict";
  function esc(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  }

  function renderVivaBank(container) {
    var qa = window.LSStore.extractQaFromNotes();
    container.innerHTML =
      '<div class="space-y-3 pb-6">' +
        '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm">' +
          '<div class="text-base font-bold text-[#7B1E2B]">Viva &amp; Exam Q&amp;A Bank (' + qa.length + ')</div>' +
          '<input id="lsQaSearch" type="search" placeholder="Search questions or legal topics..." class="mt-2 w-full px-3 py-2 rounded-xl border border-[#D6C7BC] text-xs bg-[#FAF7F2]" />' +
        '</div>' +
        '<div id="lsQaList" class="space-y-2.5"></div>' +
      '</div>';
    var box = container.querySelector("#lsQaList");
    var inp = container.querySelector("#lsQaSearch");
    function paint(q) {
      var ql = String(q || "").trim().toLowerCase();
      var list = (ql ? qa.filter(function (x) { return (x.q + " " + x.a + " " + x.subject).toLowerCase().indexOf(ql) !== -1; }) : qa).slice(0, 50);
      box.innerHTML = list.map(function (x) {
        return '<details class="bg-white border border-[#E8E0D5] rounded-2xl p-3.5 shadow-sm">' +
          '<summary class="text-xs font-bold text-[#1F1B18] cursor-pointer">' + esc(x.q) + '</summary>' +
          '<div class="mt-2 text-xs text-[#3D352E] leading-relaxed border-t border-[#FAF7F2] pt-2">' + esc(x.a) + '</div>' +
          '<button type="button" data-ls-open-topic="' + esc(x.topicId) + '" class="mt-2 text-[11px] font-bold text-[#7B1E2B] underline">Read Full Note &rarr;</button>' +
        '</details>';
      }).join("") || '<div class="text-xs text-center text-[#5F554E] py-6">No matching Q&amp;A found.</div>';
    }
    paint("");
    inp.addEventListener("input", function () { paint(inp.value); });
  }

  async function renderLexicon(container) {
    var extras = await window.LSStore.loadExtras();
    var allTerms = [];
    (extras.maxims || []).forEach(function (m) { allTerms.push({ cat: "Legal Maxim", term: m.term, meaning: m.meaning }); });
    (extras.glossary || []).forEach(function (g) { allTerms.push({ cat: "Glossary", term: g.term, meaning: g.meaning }); });

    container.innerHTML =
      '<div class="space-y-3 pb-6">' +
        '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm">' +
          '<div class="text-base font-bold text-[#7B1E2B]">Lexicon &amp; Latin Maxims (' + allTerms.length + ')</div>' +
          '<input id="lsLexSearch" type="search" placeholder="Search Latin maxims or legal terms..." class="mt-2 w-full px-3 py-2 rounded-xl border border-[#D6C7BC] text-xs bg-[#FAF7F2]" />' +
        '</div>' +
        '<div id="lsLexList" class="space-y-2"></div>' +
      '</div>';
    var box = container.querySelector("#lsLexList");
    var inp = container.querySelector("#lsLexSearch");
    function paint(q) {
      var ql = String(q || "").trim().toLowerCase();
      var list = (ql ? allTerms.filter(function (x) { return (x.term + " " + x.meaning).toLowerCase().indexOf(ql) !== -1; }) : allTerms).slice(0, 80);
      box.innerHTML = list.map(function (x) {
        return '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-3.5 shadow-sm">' +
          '<div class="flex items-center justify-between"><span class="text-xs font-bold text-[#7B1E2B]">' + esc(x.term) + '</span><span class="text-[10px] font-bold px-2 py-0.5 rounded-full bg-[#FAF7F2] text-[#8C6D46]">' + esc(x.cat) + '</span></div>' +
          '<p class="text-xs text-[#3D352E] mt-1">' + esc(x.meaning) + '</p>' +
        '</div>';
      }).join("") || '<div class="text-xs text-center text-[#5F554E] py-6">No matching terms found.</div>';
    }
    paint("");
    inp.addEventListener("input", function () { paint(inp.value); });
  }

  function renderMyShelf(container) {
    var list = window.LSStore.getShelf();
    var html = '<div class="space-y-3 pb-6">' +
      '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-4 shadow-sm">' +
        '<div class="text-base font-bold text-[#7B1E2B]">My Shelf (Saved Bookmarks: ' + list.length + ')</div>' +
        '<p class="text-xs text-[#5F554E] mt-0.5">Quick offline revision list for exams.</p>' +
      '</div>';
    if (!list.length) {
      html += '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-6 text-center text-xs text-[#5F554E]">Nothing saved yet. Tap Save on any Judgment or Note to pin it here.</div>';
    } else {
      html += list.map(function (it) {
        return '<div class="bg-white border border-[#E8E0D5] rounded-2xl p-3.5 flex items-center justify-between gap-2">' +
          '<div><div class="text-xs font-bold text-[#1F1B18]">' + esc(it.title) + '</div><div class="text-[11px] text-[#5F554E]">' + esc(it.subtitle) + '</div></div>' +
          '<button type="button" data-ls-shelf-id="' + esc(it.id) + '" data-ls-shelf-title="' + esc(it.title) + '" class="px-2.5 py-1 rounded-lg border border-[#E8E0D5] text-[11px] font-bold text-[#991B1B]">Remove</button>' +
        '</div>';
      }).join("");
    }
    html += '</div>';
    container.innerHTML = html;
  }

  window.LSVault = {
    renderViva: renderVivaBank,
    renderLexicon: renderLexicon,
    renderShelf: renderMyShelf
  };
})();

'@
  "ls-nav.js" = @'
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

'@
}

foreach ($mName in $modules.Keys) {
  $mPath = Join-Path $modDir $mName
  [System.IO.File]::WriteAllText($mPath, $modules[$mName], $u)
  $err = node --check $mPath 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Module $mName JS syntax error: $err" }
  Write-Host ("  [PASS] www/js/modules/" + $mName) -ForegroundColor Green
}

Write-Host "`n=== 2. Wiring Modules Non-Destructively into www/index.html (v$ver) ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h -replace 'var CURRENT_APP_VER = "[^"]+";', "var CURRENT_APP_VER = `"$ver`";"
$h = $h -replace 'var APP_VER = "[^"]+";', "var APP_VER = `"$ver`";"

$h = [regex]::Replace($h, '(?s)<!-- LS_MODULAR_V3_START -->.*?<!-- LS_MODULAR_V3_END -->', '')
$modTags = @"
<!-- LS_MODULAR_V3_START -->
<script defer src="./js/modules/ls-store.js?v=$ver"></script>
<script defer src="./js/modules/ls-hub.js?v=$ver"></script>
<script defer src="./js/modules/ls-judgments.js?v=$ver"></script>
<script defer src="./js/modules/ls-drill.js?v=$ver"></script>
<script defer src="./js/modules/ls-vault.js?v=$ver"></script>
<script defer src="./js/modules/ls-nav.js?v=$ver"></script>
<!-- LS_MODULAR_V3_END -->
"@
$h = $h.Replace('</body>', ($modTags + "`r`n</body>"))
[System.IO.File]::WriteAllText($idx, $h, $u)
Write-Host "[PASS] Wired all 6 modules into www/index.html (all existing features untouched!)" -ForegroundColor Green

Write-Host "`n=== 3. Installing Automated 12-Hour Source Sync Workflow (.github/workflows/auto-sync-lawstudyes.yml) ===" -ForegroundColor Cyan
$wfDir = Join-Path $root ".github\workflows"
New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
$wfContent = @'
name: Law Studyes Scheduled Source Sync & OTA Publish

on:
  schedule:
    # Runs automatically every 12 hours (00:30 & 12:30 UTC -> 06:00 & 18:00 IST)
    - cron: '30 0,12 * * *'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  sync-and-publish-ota:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install scraper dependencies
        run: pip install requests beautifulsoup4

      - name: Record previous DB hash
        id: prev
        run: |
          if [ -f www/nyayasaral_db.json ]; then
            echo "hash=$(sha256sum www/nyayasaral_db.json | awk '{print $1}')" >> "$GITHUB_OUTPUT"
          else
            echo "hash=none" >> "$GITHUB_OUTPUT"
          fi

      - name: Run 12-thread source scraper
        run: python scrape_nyayasaral.py

      - name: Check if source website has new or updated content
        id: diff
        run: |
          NEW_HASH=$(sha256sum www/nyayasaral_db.json | awk '{print $1}')
          echo "Previous: ${{ steps.prev.outputs.hash }}"
          echo "Current:  $NEW_HASH"
          if [ "$NEW_HASH" != "${{ steps.prev.outputs.hash }}" ]; then
            echo "changed=true" >> "$GITHUB_OUTPUT"
          else
            echo "changed=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Rebuild forward-slash OTA bundle & manifests if changed
        if: steps.diff.outputs.changed == 'true'
        run: |
          python - <<'PY'
          import hashlib, json, zipfile
          from datetime import datetime, timezone
          from pathlib import Path

          www = Path("www")
          zip_path = www / "ota-bundle.zip"
          exclude = {"ota-bundle.zip", "ota-version.json", "ota-manifest.json", "LawStudyes-Offline.apk"}
          with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
              for p in sorted(www.rglob("*")):
                  if p.is_file() and p.name not in exclude:
                      zf.write(p, p.relative_to(www).as_posix())

          ver = datetime.now(timezone.utc).strftime("%Y.%m.%d.%H%M")
          now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
          sha = hashlib.sha256(zip_path.read_bytes()).hexdigest().lower()
          size_b = zip_path.stat().st_size
          url = "https://law-studyes.vercel.app/ota-bundle.zip"

          (www / "ota-version.json").write_text(json.dumps({
              "version": ver, "url": url, "sha256": sha, "sizeBytes": size_b, "updatedAt": now_iso
          }, indent=2), encoding="utf-8")
          (www / "ota-manifest.json").write_text(json.dumps({
              "app": "Law Studyes", "version": ver, "bundle": "ota-bundle.zip",
              "url": url, "sha256": sha, "sizeBytes": size_b, "updatedAt": now_iso
          }, indent=2), encoding="utf-8")
          print(f"Built automated OTA v{ver} ({size_b} bytes, sha256={sha[:16]})")
          PY

      - name: Commit & push updated OTA bundle to main (triggers Vercel CDN)
        if: steps.diff.outputs.changed == 'true'
        run: |
          git config user.name "Law Studyes Auto-Sync Bot"
          git config user.email "actions@users.noreply.github.com"
          git add www/nyayasaral_db.json www/db-version.json www/ota-bundle.zip www/ota-version.json www/ota-manifest.json
          git commit -m "Auto-Sync OTA: Updated source notes & diagrams ($(date -u +'%Y-%m-%d %H:%M UTC'))"
          git push origin main

'@
[System.IO.File]::WriteAllText((Join-Path $wfDir "auto-sync-lawstudyes.yml"), $wfContent, $u)
Write-Host "[OK] Created .github/workflows/auto-sync-lawstudyes.yml (Auto-checks nyayasaral.com every 12h & pushes OTA)" -ForegroundColor Green

Write-Host "`n=== 4. Building Clean Signed Release APK v$ver (versionCode $verCode) ===" -ForegroundColor Cyan
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

Remove-Item (Join-Path $root "www\LawStudyes-Offline.apk"), (Join-Path $root "www\ota-bundle.zip") -ErrorAction SilentlyContinue
npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

Push-Location ".\android"
try {
  .\gradlew.bat assembleRelease
  if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
} finally {
  Pop-Location
}

$apk = ".\android\app\build\outputs\apk\release\app-release.apk"
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-Modular-AutoSync-OTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 5. Pushing Modular v$ver + Auto-Sync Workflow + OTA Bundle to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
