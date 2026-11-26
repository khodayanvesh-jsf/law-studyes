/* Law Studyes v3.2.5 - Unified Crash-Safe Module Bundle (Built 2026-11-26 21:01:34) */

/* === MODULE: ls-store.js === */
try {
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

} catch (__lsModErr) { console.error('[LS Module Error: ls-store.js]', __lsModErr); }

/* === MODULE: ls-trilingual.js === */
try {
(function () {
  "use strict";
  if (window.__lsTrilingualV311) return;
  window.__lsTrilingualV311 = true;

  var LANG_KEY = "ls_medium_v1";
  var DUAL_KEY = "ls_dual_mode_v1";
  var CACHE_PREFIX = "ls_tr_v2_";
  var inFlight = {};

  var LABELS = {
    en: {
      badge: "English Medium",
      inOneMinute: "In One Minute",
      legalProvision: "Legal Provision",
      meaning: "Meaning & Definition",
      keyPoints: "Key Points",
      caseLaws: "Leading Case Laws",
      selfTest: "Quick Self-Test"
    },
    te: {
      badge: "\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c2e\u0c40\u0c21\u0c3f\u0c2f\u0c02",
      inOneMinute: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b",
      legalProvision: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28",
      meaning: "\u0c05\u0c30\u0c4d\u0c25\u0c02 & \u0c28\u0c3f\u0c30\u0c4d\u0c35\u0c1a\u0c28\u0c02",
      keyPoints: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c05\u0c02\u0c36\u0c3e\u0c32\u0c41",
      caseLaws: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41\u0c32\u0c41",
      selfTest: "\u0c38\u0c4d\u0c35\u0c2f\u0c02 \u0c2a\u0c30\u0c40\u0c15\u0c4d\u0c37"
    },
    hi: {
      badge: "\u0939\u093f\u0928\u094d\u0926\u0940 \u092e\u093e\u0927\u094d\u092f\u092e",
      inOneMinute: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902",
      legalProvision: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928",
      meaning: "\u0905\u0930\u094d\u0925 \u0914\u0930 \u092a\u0930\u093f\u092d\u093e\u0937\u093e",
      keyPoints: "\u092e\u0941\u0916\u094d\u092f \u092c\u093f\u0902\u0926\u0941",
      caseLaws: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0928\u094d\u092f\u093e\u092f\u093f\u0915 \u0928\u093f\u0930\u094d\u0923\u092f",
      selfTest: "\u0938\u094d\u0935-\u092a\u0930\u0940\u0915\u094d\u0937\u0923"
    }
  };

  function hasLangData(obj) {
    if (!obj || typeof obj !== "object") return false;
    var fields = ["inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest"];
    for (var i = 0; i < fields.length; i++) {
      var v = obj[fields[i]];
      if (typeof v === "string" && v.trim().length > 0) return true;
      if (Array.isArray(v) && v.length > 0) return true;
    }
    return false;
  }

  function safeGetLang() {
    try {
      var v = localStorage.getItem(LANG_KEY);
      if (v === "te" || v === "hi" || v === "en") return v;
    } catch (e) {}
    return "en";
  }

  function isDualMode() {
    try { return localStorage.getItem(DUAL_KEY) === "1"; } catch (e) { return false; }
  }

  function setDualMode(on) {
    try { localStorage.setItem(DUAL_KEY, on ? "1" : "0"); } catch (e) {}
    var b = document.getElementById("langDualBtn");
    if (b) {
      b.className = on
        ? "px-2 py-1 rounded-full transition-colors bg-[#8C6D46] text-white font-bold"
        : "px-2 py-1 rounded-full transition-colors text-[#5F554E] hover:text-[#7B1E2B]";
    }
    if (typeof window.renderReadingPane === "function") {
      try { window.renderReadingPane(); } catch (e) {}
    }
  }

  function injectCss() {
    if (document.getElementById("lsTriCssV311")) return;
    var st = document.createElement("style");
    st.id = "lsTriCssV311";
    st.textContent =
      ".ls-dual-card { margin-top:14px; padding:12px 14px; border-radius:14px; background:#FAF7F2; border:1.5px dashed #C7B299; }" +
      ".ls-dual-title { font-size:11.5px; font-weight:800; text-transform:uppercase; letter-spacing:0.4px; color:#7B1E2B; margin-bottom:6px; }" +
      ".ls-dual-body { font-size:12.5px; color:#2C2520; line-height:1.55; }" +
      ".ls-lang-pill-badge { display:inline-flex; align-items:center; gap:5px; padding:3px 10px; border-radius:999px; background:#FBF1F2; border:1px solid #E8D5D8; color:#7B1E2B; font-size:11px; font-weight:800; margin-bottom:10px; }";
    document.head.appendChild(st);
  }

  function readLocalCache(lang, topicId) {
    try {
      var raw = localStorage.getItem(CACHE_PREFIX + lang + "_" + topicId);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  function writeLocalCache(lang, topicId, obj) {
    try { localStorage.setItem(CACHE_PREFIX + lang + "_" + topicId, JSON.stringify(obj)); } catch (e) {}
  }

  async function translateStr(text, tl) {
    var clean = String(text || "").trim();
    if (!clean) return "";
    var url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=" +
      encodeURIComponent(tl) + "&dt=t&q=" + encodeURIComponent(clean.slice(0, 1200));
    var r = await fetch(url);
    if (!r.ok) throw new Error("HTTP " + r.status);
    var d = await r.json();
    if (Array.isArray(d) && Array.isArray(d[0])) {
      var out = "";
      for (var i = 0; i < d[0].length; i++) {
        if (d[0][i] && d[0][i][0]) out += d[0][i][0];
      }
      if (out.trim()) return out.trim();
    }
    return clean;
  }

  async function translateAny(val, tl) {
    if (!val || (typeof val !== "object" && typeof val !== "string")) return val;
    if (typeof val === "string") return await translateStr(val, tl);
    if (Array.isArray(val)) {
      var arr = [];
      for (var i = 0; i < val.length; i++) arr.push(await translateAny(val[i], tl));
      return arr;
    }
    var copy = {};
    var keys = Object.keys(val);
    for (var j = 0; j < keys.length; j++) {
      var k = keys[j];
      if (k === "id" || k === "type" || k === "html" || k === "svg" || k === "mermaid" || k === "code" || k === "visuals") {
        copy[k] = val[k];
      } else {
        copy[k] = await translateAny(val[k], tl);
      }
    }
    return copy;
  }

  async function ensureNoteInLang(topicId, lang) {
    if (!topicId || (lang !== "te" && lang !== "hi")) return;
    if (typeof state === "undefined" || !state.notes || !state.notes[topicId]) return;
    var rec = state.notes[topicId];
    if (hasLangData(rec[lang])) return;

    var cached = readLocalCache(lang, topicId);
    if (hasLangData(cached)) {
      rec[lang] = cached;
      if (state.activeTopicId === topicId && state.lang === lang && typeof window.renderReadingPane === "function") {
        try { window.renderReadingPane(); } catch (e) {}
      }
      return;
    }

    var lock = lang + ":" + topicId;
    if (inFlight[lock] || !navigator.onLine || !hasLangData(rec.en)) return;
    inFlight[lock] = true;
    try {
      var built = await translateAny(rec.en, lang);
      if (hasLangData(built)) {
        built.visuals = rec.en.visuals || [];
        rec[lang] = built;
        writeLocalCache(lang, topicId, built);
        if (state.activeTopicId === topicId && state.lang === lang && typeof window.renderReadingPane === "function") {
          try { window.renderReadingPane(); } catch (e) {}
        }
      }
    } catch (e) {}
    finally { delete inFlight[lock]; }
  }

  function removeLegacyUnavailableBanners(pane) {
    if (!pane) return;
    try {
      var nodes = pane.querySelectorAll("div, p, span");
      for (var i = 0; i < nodes.length; i++) {
        var el = nodes[i];
        if (el.children.length > 2) continue;
        var txt = (el.textContent || "").trim();
        if (txt.length > 240) continue;
        if (
          /not available (for|in).*(telugu|hindi)/i.test(txt) ||
          /telugu.*not available/i.test(txt) ||
          /hindi.*not available/i.test(txt) ||
          /showing english fallback/i.test(txt)
        ) {
          el.style.display = "none";
        }
      }
    } catch (e) {}
  }

  function localizePane() {
    try {
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane");
      if (!pane) return;

      var lang = state.lang || "en";
      var rec = state.notes && state.notes[state.activeTopicId];

      if (lang === "te" || lang === "hi") {
        if (rec && hasLangData(rec[lang])) {
          removeLegacyUnavailableBanners(pane);
        } else if (rec) {
          ensureNoteInLang(state.activeTopicId, lang);
        }

        var map = LABELS[lang];
        var enMap = LABELS.en;
        pane.querySelectorAll("h2, h3, button[data-toggle-section]").forEach(function (el) {
          var t = el.textContent || "";
          ["inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest"].forEach(function (k) {
            if (t.indexOf(enMap[k]) !== -1 && t.indexOf(map[k]) === -1) {
              el.textContent = t.replace(enMap[k], map[k]);
            }
          });
        });

        var oldDual = document.getElementById("lsDualRefBox");
        if (oldDual) oldDual.remove();
        if (isDualMode() && rec && hasLangData(rec.en) && hasLangData(rec[lang])) {
          var box = document.createElement("div");
          box.id = "lsDualRefBox";
          box.className = "ls-dual-card";
          var enProv = rec.en.legalProvision ? ("<p style='margin-bottom:6px;'><strong>Provision:</strong> " + String(rec.en.legalProvision).replace(/</g, "&lt;") + "</p>") : "";
          var enSum = rec.en.inOneMinute ? ("<p><strong>Summary:</strong> " + String(rec.en.inOneMinute).replace(/</g, "&lt;") + "</p>") : "";
          box.innerHTML = '<div class="ls-dual-title">Dual-Medium English Exam Reference</div><div class="ls-dual-body">' + enProv + enSum + '</div>';
          pane.appendChild(box);
        }
      }
    } catch (e) {}
  }

  function applyMedium(newLang) {
    try {
      if (typeof state === "undefined") return;
      var lang = (newLang === "te" || newLang === "hi") ? newLang : "en";
      if (window.LSAudioEngine && typeof window.LSAudioEngine.stop === "function") {
        window.LSAudioEngine.stop();
      } else if (typeof stopAudio === "function") {
        try { stopAudio(); } catch (e) {}
      }

      state.lang = lang;
      try { localStorage.setItem(LANG_KEY, lang); } catch (e) {}

      var activeCls = "px-2 py-1 rounded-full transition-colors bg-[#7B1E2B] text-white font-bold";
      var idleCls = "px-2 py-1 rounded-full transition-colors text-[#5F554E] hover:text-[#7B1E2B]";
      var bEn = document.getElementById("langEnBtn");
      var bTe = document.getElementById("langTeBtn");
      var bHi = document.getElementById("langHiBtn");
      var bDual = document.getElementById("langDualBtn");
      if (bEn) bEn.className = lang === "en" ? activeCls : idleCls;
      if (bTe) bTe.className = lang === "te" ? activeCls : idleCls;
      if (bHi) bHi.className = lang === "hi" ? activeCls : idleCls;
      if (bDual) bDual.style.display = (lang === "en") ? "none" : "inline-block";

      if (lang !== "en" && state.activeTopicId) {
        ensureNoteInLang(state.activeTopicId, lang);
      }
      if (typeof loadVoices === "function") { try { loadVoices(); } catch (e) {} }
      if (typeof window.renderReadingPane === "function") window.renderReadingPane();

      window.dispatchEvent(new CustomEvent("ls:lang-changed", { detail: { lang: lang } }));
      if (typeof showToast === "function") showToast("Switched to " + LABELS[lang].badge);
    } catch (e) {}
  }

  function mountSwitcher() {
    try {
      injectCss();
      var enBtn = document.getElementById("langEnBtn");
      var teBtn = document.getElementById("langTeBtn");
      if (!enBtn || !teBtn) return;

      var host = enBtn.parentElement;
      if (!host || host.__lsTriV311Mounted) return;
      host.__lsTriV311Mounted = true;

      var newEn = enBtn.cloneNode(true);
      var newTe = teBtn.cloneNode(true);
      enBtn.parentNode.replaceChild(newEn, enBtn);
      teBtn.parentNode.replaceChild(newTe, teBtn);

      var oldHi = document.getElementById("langHiBtn");
      if (oldHi) oldHi.remove();
      var hiBtn = document.createElement("button");
      hiBtn.id = "langHiBtn";
      hiBtn.type = "button";
      hiBtn.textContent = "HI";
      hiBtn.title = "Hindi Medium";
      host.appendChild(hiBtn);

      var oldDual = document.getElementById("langDualBtn");
      if (oldDual) oldDual.remove();
      var dualBtn = document.createElement("button");
      dualBtn.id = "langDualBtn";
      dualBtn.type = "button";
      dualBtn.textContent = "Dual";
      dualBtn.title = "Show English Exam Reference alongside Telugu/Hindi";
      dualBtn.style.display = "none";
      host.appendChild(dualBtn);

      newEn.addEventListener("click", function () { applyMedium("en"); });
      newTe.addEventListener("click", function () { applyMedium("te"); });
      hiBtn.addEventListener("click", function () { applyMedium("hi"); });
      dualBtn.addEventListener("click", function () { setDualMode(!isDualMode()); });

      if (typeof window.renderReadingPane === "function" && !window.__lsTriV311Hook) {
        window.__lsTriV311Hook = true;
        var origR = window.renderReadingPane;
        window.renderReadingPane = function () {
          var r = origR.apply(this, arguments);
          localizePane();
          return r;
        };
      }

      var saved = safeGetLang();
      setDualMode(isDualMode());
      if (saved !== "en") {
        applyMedium(saved);
      } else {
        newEn.className = "px-2 py-1 rounded-full transition-colors bg-[#7B1E2B] text-white font-bold";
        localizePane();
      }
    } catch (e) {}
  }

  window.LSTrilingual = {
    setLang: applyMedium,
    getLang: function () { return (typeof state !== "undefined" && state.lang) ? state.lang : safeGetLang(); },
    setDual: setDualMode
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(mountSwitcher, 200);
    setTimeout(mountSwitcher, 1000);
  });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-trilingual.js]', __lsModErr); }

/* === MODULE: ls-audio-engine.js === */
try {
(function () {
  "use strict";
  if (window.__lsCleanAudioV325) return;
  window.__lsCleanAudioV325 = true;

  var K_SPD = "ls_aud_spd_325", K_TCH = "ls_aud_tch_325", K_REP = "ls_aud_rep_325", K_VC = "ls_aud_vc_325_";
  var AUDIO_CACHE = "ls-prof-audio-v1", CDN = "https://law-studyes.vercel.app";

  var manifest = null, htmlAudio = null, webVoices = [];
  var token = 0, playing = false, paused = false, studioMp3 = false;
  var scope = "topic", teachMode = true, repeat = false, speed = 0.98, sleepId = null;
  var queue = [], curIdx = 0, curTopicId = "", curTitle = "", curCaption = "", curStepIdx = -1, curVoiceLbl = "Auto Best Indian Voice";

  function nativeSvc() {
    try { return (window.LSNativeTtsService && typeof window.LSNativeTtsService.playQueue === "function") ? window.LSNativeTtsService : null; }
    catch (e) { return null; }
  }

  function loadPrefs() {
    try {
      var sp = parseFloat(localStorage.getItem(K_SPD) || "0.98");
      if (isFinite(sp) && sp >= 0.6 && sp <= 1.8) speed = sp;
      teachMode = localStorage.getItem(K_TCH) !== "0";
      repeat = localStorage.getItem(K_REP) === "1";
    } catch (e) {}
  }

  function langNow() {
    try { var l = (typeof state !== "undefined" && state && state.lang) ? String(state.lang).toLowerCase() : "en"; return (l === "te" || l === "hi") ? l : "en"; }
    catch (e) { return "en"; }
  }
  function bcp47(l) { l = String(l || langNow()).toLowerCase(); return l === "te" ? "te-IN" : (l === "hi" ? "hi-IN" : "en-IN"); }
  function getSavedVc(l) { try { return localStorage.getItem(K_VC + l) || "auto"; } catch (e) { return "auto"; } }
  function setSavedVc(l, k) { try { localStorage.setItem(K_VC + l, String(k || "auto")); } catch (e) {} }

  function cleanSpeech(raw, lang) {
    var s = String(raw || "");
    if (!s) return "";
    s = s.replace(/<[^>]+>/g, " ").replace(/https?:\/\/\S+/gi, " ").replace(/[\*\#\_`~>\[\]]+/g, " ");
    s = s.replace(/\s*\|\s*/g, ". ").replace(/[\u2022\u25aa\u25ba\u25b8\u2756\u25cf\u25cb\u25c6\u25c7\u2713\u2714\u2192\u21d2\u2014\u2013]+/g, ", ");
    if (lang === "en") {
      s = s.replace(/\bsallent\b/gi, "salient")
           .replace(/\bSecs?\.\s*/gi, "Section ").replace(/\bArts?\.\s*/gi, "Article ")
           .replace(/\bu\/s\b/gi, "under Section").replace(/\bw\.e\.f\./gi, "with effect from")
           .replace(/\bi\.e\./gi, "that is").replace(/\be\.g\./gi, "for example")
           .replace(/\betc\./gi, "and so on").replace(/\bvs?\.\s+/gi, " versus ")
           .replace(/\bIPC\b/g, "I P C").replace(/\bCrPC\b/g, "C R P C").replace(/\bCPC\b/g, "C P C")
           .replace(/\bBNS\b/g, "B N S").replace(/\bBNSS\b/g, "B N S S").replace(/\bBSA\b/g, "B S A")
           .replace(/\bAIR\b/g, "A I R").replace(/\bSCC\b/g, "S C C").replace(/\bPIL\b/g, "P I L").replace(/\bFIR\b/g, "F I R");
    }
    return s.replace(/\s*([,\.;:\?!\u0964])\s*/g, "$1 ").replace(/\.{2,}/g, ".").replace(/\s+/g, " ").trim();
  }

  function splitFluent(text, maxLen) {
    var lim = maxLen || 185, s = String(text || "").trim();
    if (!s) return [];
    if (s.length <= lim) return [s];
    var parts = s.match(/[^\.\?!\u0964]+[\.\?!\u0964]*/g) || [s], out = [];
    for (var i = 0; i < parts.length; i++) {
      var p = parts[i].trim();
      if (!p) continue;
      if (p.length <= lim) { out.push(p); continue; }
      var cls = p.match(/[^,;:]+[,;:]*/g) || [p], buf = "";
      for (var j = 0; j < cls.length; j++) {
        var c = cls[j].trim();
        if (!c) continue;
        if ((buf + " " + c).trim().length <= lim) { buf = (buf ? buf + " " : "") + c; }
        else {
          if (buf) out.push(buf);
          if (c.length <= lim) { buf = c; }
          else {
            var ws = c.split(/\s+/), wb = "";
            for (var k = 0; k < ws.length; k++) {
              if ((wb + " " + ws[k]).trim().length <= lim) wb = (wb ? wb + " " : "") + ws[k];
              else { if (wb) out.push(wb); wb = ws[k]; }
            }
            buf = wb;
          }
        }
      }
      if (buf) out.push(buf);
    }
    return out.filter(function (x) { return x && x.length > 1; });
  }

  function metaSafe(tid) { try { return typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; } catch (e) { return null; } }

  function buildTopicQueue(tid, lang, asProf) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return [];
    var ld = rec[lang] || rec.en; if (!ld) return [];
    var m = metaSafe(tid), title = (m && m.topic && m.topic.title) ? m.topic.title : String(tid).replace(/-/g, " ");
    var ct = cleanSpeech(title, lang), m1 = cleanSpeech(ld.inOneMinute, lang), pr = cleanSpeech(ld.legalProvision, lang), mn = cleanSpeech(ld.meaning, lang);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.map(function (x) { return cleanSpeech(typeof x === "string" ? x : (x && (x.point || x.text || x.summary)), lang); }).filter(Boolean) : [];
    var cs = Array.isArray(ld.caseLaws) ? ld.caseLaws.slice(0, 3).map(function (c) {
      if (typeof c === "string") return cleanSpeech(c, lang);
      if (!c) return "";
      var n = cleanSpeech(c.name || c.title, lang), p = cleanSpeech(c.principle || c.summary, lang);
      return (n && p) ? (n + ". " + p) : (n || p);
    }).filter(Boolean) : [];

    var blks = [];
    if (lang === "te") {
      if (asProf) {
        blks.push({ step: 0, text: "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d. \u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 " + ct + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c41\u0c32\u0c2d\u0c02\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." });
        if (m1) blks.push({ step: 1, text: "\u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b \u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c35\u0c3f\u0c37\u0c2f\u0c02 \u0c24\u0c46\u0c32\u0c41\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02. " + m1 });
        if (pr) blks.push({ step: 2, text: "\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d\u200c\u0c32\u0c4b \u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c30\u0c3e\u0c2f\u0c3e\u0c32\u0c4d\u0c38\u0c3f\u0c28 \u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28 \u0c07\u0c26\u0c3f. " + pr });
        if (mn) blks.push({ step: 3, text: "\u0c07\u0c2a\u0c4d\u0c2a\u0c41\u0c21\u0c41 \u0c26\u0c40\u0c28\u0c3f \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c02\u0c17\u0c3e \u0c1a\u0c42\u0c26\u0c4d\u0c26\u0c3e\u0c02. " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41 \u0c12\u0c15\u0c4d\u0c15\u0c4a\u0c15\u0c4d\u0c15\u0c1f\u0c3f\u0c17\u0c3e \u0c17\u0c2e\u0c28\u0c3f\u0c02\u0c1a\u0c02\u0c21\u0c3f." });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "\u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d " + (i + 1) + ". " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41 \u0c32\u0c3e \u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41\u0c2a\u0c46\u0c1f\u0c4d\u0c1f\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f. " + cs.join(". ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    } else if (lang === "hi") {
      if (asProf) {
        blks.push({ step: 0, text: "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938\u0964 \u0906\u091c \u0939\u092e " + ct + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0914\u0930 \u0938\u094d\u092a\u0937\u094d\u091f \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" });
        if (m1) blks.push({ step: 1, text: "\u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902 \u0907\u0938\u0915\u093e \u092e\u0941\u0916\u094d\u092f \u0938\u093e\u0930 \u0938\u092e\u091d\u093f\u090f\u0964 " + m1 });
        if (pr) blks.push({ step: 2, text: "\u090f\u0917\u094d\u091c\u093e\u092e \u092e\u0947\u0902 \u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u092f\u0939 \u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928 \u0932\u093f\u0916\u093f\u090f\u0964 " + pr });
        if (mn) blks.push({ step: 3, text: "\u0905\u092c \u0907\u0938\u0915\u093e \u0938\u0930\u0932 \u0905\u0930\u094d\u0925 \u0938\u092e\u091d\u0924\u0947 \u0939\u0948\u0902\u0964 " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "\u0905\u092c \u090f\u0915 \u090f\u0915 \u0915\u0930\u0915\u0947 \u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938 \u0927\u094d\u092f\u093e\u0928 \u0938\u0947 \u0938\u0941\u0928\u093f\u090f\u0964" });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "\u092a\u0949\u0907\u0902\u091f " + (i + 1) + "\u0964 " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "\u0907\u0938 \u0935\u093f\u0937\u092f \u0915\u093e \u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949 \u092f\u093e\u0926 \u0930\u0916\u093f\u090f\u0964 " + cs.join("\u0964 ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    } else {
      if (asProf) {
        blks.push({ step: 0, text: "Hello students. Today let us clearly understand " + ct + "." });
        if (m1) blks.push({ step: 1, text: "First, here is the core idea in plain words. " + m1 });
        if (pr) blks.push({ step: 2, text: "For your exam answer, start with this exact legal provision. " + pr });
        if (mn) blks.push({ step: 3, text: "Let us look at what this means. " + mn });
        if (pts.length) {
          blks.push({ step: 4, text: "Now listen carefully to the key scoring points." });
          pts.forEach(function (p, i) { blks.push({ step: 4, text: "Point " + (i + 1) + ". " + p }); });
        }
        if (cs.length) blks.push({ step: 5, text: "Be sure to quote this landmark case law in your answer. " + cs.join(". ") });
      } else {
        blks.push({ step: 0, text: ct }); if (m1) blks.push({ step: 1, text: m1 }); if (pr) blks.push({ step: 2, text: pr });
        if (mn) blks.push({ step: 3, text: mn }); pts.forEach(function (p) { blks.push({ step: 4, text: p }); }); cs.forEach(function (c) { blks.push({ step: 5, text: c }); });
      }
    }

    var out = [];
    for (var b = 0; b < blks.length; b++) {
      var chs = splitFluent(blks[b].text, 185);
      for (var s = 0; s < chs.length; s++) out.push({ topicId: tid, topicTitle: title, lang: lang, stepIdx: blks[b].step, text: chs[s] });
    }
    return out;
  }

  async function loadManifest() {
    if (manifest !== null) return manifest;
    manifest = {};
    try { var r = await fetch("./audio/manifest.json", { cache: "no-store" }); if (r.ok) manifest = await r.json(); } catch (e) {}
    return manifest;
  }

  function curatedVoices(lang) {
    var bcp = bcp47(lang), svc = nativeSvc(), raw = [];
    if (svc && typeof svc.getVoicesForLang === "function") {
      try { raw = JSON.parse(svc.getVoicesForLang(bcp) || "[]"); } catch (e) { raw = []; }
    } else if ("speechSynthesis" in window) {
      raw = webVoices;
    }
    var tgt = bcp.toLowerCase(), pref = tgt.split("-")[0], all = [];
    for (var i = 0; i < raw.length; i++) {
      var v = raw[i], vl = String((v && v.lang) || "").toLowerCase().replace("_", "-");
      if (vl.indexOf("ar") === 0) continue;
      if (vl !== tgt && vl.indexOf(pref + "-") !== 0 && vl !== pref) continue;
      var rn = String((v && (v.name || v.voiceURI)) || ("Voice " + i));
      var sc = (vl === tgt ? 200 : 80) + (/network|neural|natural|wavenet|online/i.test(rn) ? 80 : 0) + (/google|neerja|prabhat|shruti|mohan|swara|madhur/i.test(rn) ? 50 : 0);
      var isNet = /network|neural|natural|wavenet|online/i.test(rn) || (v.localService === false);
      var isMale = /prabhat|mohan|madhur|ravi|hemant|male|\-e\-|\-d\-|en\-in\-x\-ene|te\-in\-x\-tem|hi\-in\-x\-hid/i.test(rn);
      var isFem = /neerja|shruti|swara|heera|kalpana|veena|lekha|female|en\-in\-x\-ena|en\-in\-x\-enc|te\-in\-x\-tef|hi\-in\-x\-hia/i.test(rn);
      all.push({ key: rn, voice: v, score: sc, isNet: isNet, isMale: isMale, isFem: isFem });
    }
    all.sort(function (a, b) { return b.score - a.score; });

    var picked = [], used = {};
    function add(it, lbl) { if (!it || used[it.key]) return; used[it.key] = true; picked.push({ key: it.key, voice: it.voice, name: lbl }); }
    add(all.filter(function (x) { return x.isFem; })[0] || all[0], "Indian Female (Clear)");
    add(all.filter(function (x) { return x.isMale && !used[x.key]; })[0], "Indian Male (Clear)");
    add(all.filter(function (x) { return x.isNet && !used[x.key]; })[0], "Indian HD Online Voice");
    add(all.filter(function (x) { return !x.isNet && !used[x.key]; })[0], "Indian Offline Voice");
    for (var k = 0; k < all.length && picked.length < 3; k++) add(all[k], "Indian Voice " + (picked.length + 1));
    return picked;
  }

  function removeDeadDropdowns() {
    var host = document.getElementById("lsPwVoiceHost");
    if (host) host.querySelectorAll("select").forEach(function (s) { if (s.id !== "audioVoiceSelect") s.remove(); });
    var modal = document.getElementById("lsPlayerWindowModal");
    if (modal) modal.querySelectorAll("select").forEach(function (s) { if (s.id !== "audioVoiceSelect" && s.id !== "audioSpeedSelect" && s.id !== "sleepTimerSelect") s.remove(); });
  }

  function updateHint() {
    var h = document.getElementById("lsPwVoiceActiveHint");
    if (h) h.textContent = curVoiceLbl + " (" + speed.toFixed(2).replace(/\.00$/, "") + "x)";
  }

  function populateVoices() {
    removeDeadDropdowns();
    var sel = document.getElementById("audioVoiceSelect");
    if (!sel) return;
    var lang = langNow(), bcp = bcp47(lang), tid = (typeof state !== "undefined" && state.activeTopicId) ? state.activeTopicId : curTopicId;
    var list = curatedVoices(lang), saved = getSavedVc(lang), opts = [];
    if (manifest && manifest[lang] && manifest[lang][tid]) opts.push({ v: "studio-mp3", l: "HD Studio Human Voice (MP3)" });
    opts.push({ v: "auto", l: "Auto Best Indian Voice (" + bcp + ")" });
    for (var i = 0; i < list.length; i++) opts.push({ v: list[i].key, l: list[i].name });
    sel.innerHTML = "";
    var hit = false;
    opts.forEach(function (o) {
      var op = document.createElement("option"); op.value = o.v; op.textContent = o.l;
      if (o.v === saved) { op.selected = true; hit = true; }
      sel.appendChild(op);
    });
    if (!hit && sel.options.length) sel.selectedIndex = 0;
    var found = list.filter(function (x) { return x.key === saved; })[0];
    curVoiceLbl = saved === "studio-mp3" ? "HD Studio Human Voice (MP3)" : (found ? found.name : "Auto Best Indian Voice");
    updateHint();
  }

  function stopHardware() {
    if (htmlAudio) { try { htmlAudio.pause(); htmlAudio.currentTime = 0; } catch (e) {} htmlAudio = null; }
    var svc = nativeSvc();
    if (svc) { try { svc.stop(); } catch (e) {} }
    if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
  }

  function stop() {
    token++; playing = false; paused = false; studioMp3 = false;
    if (sleepId) { clearTimeout(sleepId); sleepId = null; }
    stopHardware(); emitState();
  }

  async function tryMp3(tid, lang, tk) {
    await loadManifest();
    var rel = (manifest && manifest[lang] && manifest[lang][tid]) ? manifest[lang][tid] : null;
    if (!rel) return false;
    var urls = [rel, CDN + "/" + rel.replace(/^\.\//, "")];
    for (var i = 0; i < urls.length; i++) {
      try {
        var u = urls[i], playUrl = u;
        if ("caches" in window) {
          var c = await caches.open(AUDIO_CACHE), hit = await c.match(u);
          if (hit) playUrl = URL.createObjectURL(await hit.blob());
          else {
            var resp = await fetch(u); if (!resp.ok) continue;
            try { c.put(u, resp.clone()); } catch (e) {}
            playUrl = URL.createObjectURL(await resp.blob());
          }
        }
        if (tk !== token) return true;
        htmlAudio = new Audio(playUrl);
        htmlAudio.playbackRate = speed;
        htmlAudio.ontimeupdate = function () {
          if (tk !== token || !htmlAudio || !htmlAudio.duration) return;
          var b = document.getElementById("audioProgressBar");
          if (b) b.style.width = Math.min(100, Math.round((htmlAudio.currentTime / htmlAudio.duration) * 100)) + "%";
        };
        htmlAudio.onended = function () {
          if (tk !== token) return;
          if (repeat) { htmlAudio.currentTime = 0; htmlAudio.play().catch(function () {}); return; }
          playing = false; paused = false; studioMp3 = false; emitState();
        };
        await htmlAudio.play();
        playing = true; paused = false; studioMp3 = true;
        curVoiceLbl = "HD Studio Human Voice (MP3)"; updateHint(); emitState();
        return true;
      } catch (e) {}
    }
    return false;
  }

  async function runWebQueue(idx) {
    var tk = ++token; stopHardware();
    if (!queue.length) { playing = false; paused = false; emitState(); return; }
    curIdx = Math.max(0, Math.min(idx, queue.length - 1));
    var lang = queue[curIdx].lang, saved = getSavedVc(lang);
    var list = curatedVoices(lang);
    var chosen = list.filter(function (x) { return x.key === saved; })[0] || list[0] || null;
    curVoiceLbl = chosen ? chosen.name : ("System " + bcp47(lang));
    updateHint();
    playing = true; paused = false; studioMp3 = false;

    for (var i = curIdx; i < queue.length; i++) {
      if (tk !== token) return;
      curIdx = i; curTopicId = queue[i].topicId; curTitle = queue[i].topicTitle; curCaption = queue[i].text; curStepIdx = queue[i].stepIdx;
      emitState();
      await new Promise(function (resolve) {
        var finFlag = false; function fin() { if (!finFlag) { finFlag = true; resolve(); } }
        try {
          var u = new SpeechSynthesisUtterance(queue[i].text);
          u.lang = bcp47(queue[i].lang); u.rate = speed; u.pitch = 1.0;
          if (chosen && chosen.voice) u.voice = chosen.voice;
          u.onend = fin; u.onerror = fin;
          window.speechSynthesis.speak(u);
          setTimeout(fin, Math.max(9000, Math.round((queue[i].text.length * 145) / Math.max(0.6, speed))));
        } catch (e) { fin(); }
      });
      if (tk !== token) return;
      await new Promise(function (r) { setTimeout(r, 200); });
    }
    if (tk === token) {
      if (repeat && scope === "topic") { runWebQueue(0); return; }
      playing = false; paused = false; emitState();
    }
  }

  async function startQueue(startIdx) {
    if (!queue.length) return;
    var tk = ++token;
    stopHardware();
    curIdx = Math.max(0, Math.min(startIdx || 0, queue.length - 1));
    var first = queue[curIdx], lang = first.lang, saved = getSavedVc(lang);

    if (scope === "topic" && curIdx === 0 && saved === "studio-mp3") {
      if (await tryMp3(first.topicId, lang, tk)) return;
    }

    var svc = nativeSvc();
    if (svc) {
      playing = true; paused = false; studioMp3 = false;
      curTopicId = first.topicId; curTitle = first.topicTitle; curCaption = first.text; curStepIdx = first.stepIdx;
      var vName = (saved && saved !== "auto" && saved !== "studio-mp3") ? saved : "";
      svc.playQueue(JSON.stringify(queue), bcp47(lang), speed, vName, curIdx, repeat);
      emitState();
      return;
    }

    runWebQueue(curIdx);
  }

  window.__lsOnNativeAudioState = function (jsonStr) {
    try {
      var s = JSON.parse(jsonStr || "{}");
      playing = !!s.playing;
      paused = !!s.paused;
      if (typeof s.index === "number") curIdx = s.index;
      if (s.title) curTitle = s.title;
      if (s.caption !== undefined) curCaption = s.caption;
      if (s.topicId) curTopicId = s.topicId;
      if (typeof s.stepIdx === "number") curStepIdx = s.stepIdx;
      emitState();
    } catch (e) {}
  };

  function playTopic(tid, forceProf) {
    var id = tid || (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
    if (!id) { if (typeof showToast === "function") showToast("Open any topic first to listen."); return; }
    if (typeof forceProf === "boolean") { teachMode = forceProf; try { localStorage.setItem(K_TCH, teachMode ? "1" : "0"); } catch (e) {} }
    populateVoices();
    var items = buildTopicQueue(id, langNow(), teachMode);
    if (!items.length) return;
    scope = "topic"; queue = items; curIdx = 0; curTopicId = id; curTitle = items[0].topicTitle;
    startQueue(0);
  }

  function playUnit(tid) {
    var id = tid || (typeof state !== "undefined" && state.activeTopicId) || curTopicId;
    if (!id) return;
    var m = metaSafe(id);
    if (!m || !m.unit || !Array.isArray(m.unit.topics) || !m.unit.topics.length) { playTopic(id); return; }
    populateVoices();
    var all = [], lang = langNow();
    m.unit.topics.forEach(function (t) { if (t && t.id) all = all.concat(buildTopicQueue(t.id, lang, teachMode)); });
    if (!all.length) return;
    scope = "unit"; queue = all; curIdx = 0; curTopicId = all[0].topicId; curTitle = all[0].topicTitle;
    startQueue(0);
  }

  function pause() {
    if (!playing || paused) return;
    paused = true;
    var svc = nativeSvc();
    if (studioMp3 && htmlAudio) { try { htmlAudio.pause(); } catch (e) {} }
    else if (svc) { svc.pause(); }
    else { token++; stopHardware(); }
    emitState();
  }

  function resume() {
    if (!playing || !paused) return;
    paused = false;
    var svc = nativeSvc();
    if (studioMp3 && htmlAudio) { htmlAudio.playbackRate = speed; htmlAudio.play().catch(function () {}); emitState(); }
    else if (svc) { svc.resume(); emitState(); }
    else runWebQueue(curIdx);
  }

  function togglePlay() { if (playing && !paused) pause(); else if (playing && paused) resume(); else playTopic(); }
  function prev() {
    if (studioMp3 && htmlAudio) { htmlAudio.currentTime = Math.max(0, htmlAudio.currentTime - 10); return; }
    var svc = nativeSvc(); if (svc && playing) { svc.prev(); return; }
    if (queue.length) startQueue(Math.max(0, curIdx - 1));
  }
  function next() {
    if (studioMp3 && htmlAudio && htmlAudio.duration) { htmlAudio.currentTime = Math.min(htmlAudio.duration - 0.5, htmlAudio.currentTime + 10); return; }
    var svc = nativeSvc(); if (svc && playing) { svc.next(); return; }
    if (queue.length) startQueue(Math.min(queue.length - 1, curIdx + 1));
  }

  function setSpeed(val) {
    var r = parseFloat(val); if (!isFinite(r) || r < 0.6 || r > 1.8) return;
    speed = r; try { localStorage.setItem(K_SPD, String(speed)); } catch (e) {}
    updateHint();
    var svc = nativeSvc();
    if (playing && !paused) {
      if (studioMp3 && htmlAudio) htmlAudio.playbackRate = speed;
      else if (svc) svc.setSpeed(speed);
      else runWebQueue(curIdx);
    }
    emitState();
  }

  function toggleTeach() {
    teachMode = !teachMode; try { localStorage.setItem(K_TCH, teachMode ? "1" : "0"); } catch (e) {}
    if (typeof showToast === "function") showToast(teachMode ? "Indian Professor Style ON" : "Direct Notes Reading ON");
    if (playing && !paused) { if (scope === "unit") playUnit(curTopicId); else playTopic(curTopicId); } else emitState();
  }

  function toggleRepeat() {
    repeat = !repeat; try { localStorage.setItem(K_REP, repeat ? "1" : "0"); } catch (e) {}
    if (typeof showToast === "function") showToast(repeat ? "Loop Topic ON" : "Loop Topic OFF");
    emitState();
  }

  function setSleep(mins) {
    if (sleepId) { clearTimeout(sleepId); sleepId = null; }
    var m = parseInt(mins, 10) || 0;
    if (m > 0) {
      sleepId = setTimeout(function () { stop(); if (typeof showToast === "function") showToast("Sleep timer ended audio."); }, m * 60000);
      if (typeof showToast === "function") showToast("Sleep timer: " + m + " min");
    }
  }

  function testVoice() {
    var lang = langNow();
    var txt = lang === "te"
      ? "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d. \u0c07\u0c26\u0c3f \u0c32\u0c3e \u0c38\u0c4d\u0c1f\u0c21\u0c40\u0c38\u0c4d \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c35\u0c3e\u0c2f\u0c3f\u0c38\u0c4d."
      : (lang === "hi"
        ? "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938\u0964 \u092f\u0939 \u0932\u0949 \u0938\u094d\u091f\u0921\u0940\u091c\u093c \u0915\u0940 \u0939\u093f\u0902\u0926\u0940 \u0906\u0935\u093e\u091c\u093c \u0939\u0948\u0964"
        : "Hello students. Testing your selected Law Studyes voice.");
    if (typeof showToast === "function") showToast("Testing: " + curVoiceLbl);
    queue = [{ topicId: curTopicId || "test", topicTitle: "Voice Test", lang: lang, stepIdx: 0, text: txt }];
    scope = "topic";
    startQueue(0);
  }

  function getState() {
    var tot = queue.length || 0, pct = tot ? Math.round(((curIdx + 1) / tot) * 100) : 0;
    return {
      playing: playing, isPlaying: playing && !paused, paused: paused, topicId: curTopicId,
      title: curTitle || "Select a Topic to Listen", topicTitle: curTitle || "Select a Topic to Listen",
      caption: studioMp3 ? "Playing HD Studio Human Voice (MP3)" : curCaption,
      currentText: studioMp3 ? "Playing HD Studio Human Voice (MP3)" : curCaption,
      stepIdx: curStepIdx, index: curIdx, currentIndex: curIdx, total: tot, progress: pct, percent: pct,
      scope: scope, teachingMode: teachMode, repeat: repeat, speed: speed, lang: langNow(), voiceName: curVoiceLbl, studioMp3: studioMp3
    };
  }

  function emitState() {
    var st = getState(), el;
    if ((el = document.getElementById("audioCurrentTitle"))) el.textContent = st.title;
    if ((el = document.getElementById("audioModeBadge"))) el.textContent = st.studioMp3 ? "HD Studio MP3" : (st.teachingMode ? "Indian Professor" : "Direct Notes");
    if ((el = document.getElementById("audioQueueCounter"))) el.textContent = st.total ? ((st.index + 1) + " / " + st.total) : "Ready";
    if ((el = document.getElementById("liveCaptionStrip"))) { el.textContent = st.caption || "Tap Play to start Audio"; el.classList.remove("hidden"); }
    if ((el = document.getElementById("audioProgressBar")) && !st.studioMp3) el.style.width = st.percent + "%";
    if ((el = document.getElementById("audioPlayPauseBtn"))) { el.textContent = (st.playing && !st.paused) ? "Pause" : (st.paused ? "Resume" : "Play"); }
    if ((el = document.getElementById("teachingModeBtn"))) { el.textContent = st.teachingMode ? "Professor Mode: ON" : "Direct Notes: ON"; el.classList.toggle("active", st.teachingMode); }
    if ((el = document.getElementById("repeatTopicBtn"))) { el.textContent = st.repeat ? "Loop: ON" : "Loop: OFF"; el.classList.toggle("active", st.repeat); }
    if ((el = document.getElementById("lsMiniTitle"))) el.textContent = st.title;
    if ((el = document.getElementById("lsMiniSub"))) el.textContent = (st.playing && !st.paused) ? (st.voiceName + " - " + st.percent + "%") : (st.paused ? "Paused" : "Tap to open Audio Player");
    if ((el = document.getElementById("lsMiniPulse"))) el.style.display = (st.playing && !st.paused) ? "block" : "none";
    try { window.dispatchEvent(new CustomEvent("ls:audio-state", { detail: st })); } catch (e) {}
  }

  function cleanClone(id) {
    var el = document.getElementById(id);
    if (!el || el.__lsClean325) return el;
    var c = el.cloneNode(true); c.__lsClean325 = true;
    if (el.parentNode) el.parentNode.replaceChild(c, el);
    return c;
  }

  function bindControls() {
    removeDeadDropdowns();
    var b;
    if ((b = cleanClone("audioPlayPauseBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", togglePlay); }
    if ((b = cleanClone("audioPrevBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", prev); }
    if ((b = cleanClone("audioNextBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", next); }
    if ((b = cleanClone("audioStopBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", stop); }
    if ((b = cleanClone("teachingModeBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", toggleTeach); }
    if ((b = cleanClone("repeatTopicBtn")) && !b.__w) { b.__w = true; b.addEventListener("click", toggleRepeat); }
    if ((b = cleanClone("sleepTimerSelect")) && !b.__w) { b.__w = true; b.addEventListener("change", function () { setSleep(b.value); }); }
    if ((b = cleanClone("audioSpeedSelect")) && !b.__w) {
      b.__w = true;
      b.innerHTML = '<option value="0.8">0.8x (Slow)</option><option value="0.98">1.0x (Natural)</option><option value="1.15">1.15x (Brisk)</option><option value="1.3">1.3x (Revision)</option>';
      b.value = String(speed); if (b.selectedIndex === -1) b.value = "0.98";
      b.addEventListener("change", function () { setSpeed(b.value); });
    }
    var vcSel = cleanClone("audioVoiceSelect");
    if (vcSel && !vcSel.__w) {
      vcSel.__w = true;
      vcSel.addEventListener("change", function () {
        var l = langNow(); setSavedVc(l, vcSel.value);
        populateVoices();
        if (typeof showToast === "function") showToast("Voice: " + curVoiceLbl);
        var svc = nativeSvc();
        if (playing && !paused) {
          if (vcSel.value === "studio-mp3") startQueue(0);
          else if (svc) svc.setVoice(vcSel.value === "auto" ? "" : vcSel.value);
          else runWebQueue(curIdx);
        }
        emitState();
      });
    }
    var vcHost = document.getElementById("lsPwVoiceHost");
    if (vcHost) {
      var oldR = document.getElementById("lsPwVoiceActionRow");
      if (oldR && !oldR.__v325) oldR.remove();
      if (!document.getElementById("lsPwVoiceActionRow")) {
        var row = document.createElement("div"); row.id = "lsPwVoiceActionRow"; row.__v325 = true;
        row.style.cssText = "display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:6px;";
        row.innerHTML = '<span id="lsPwVoiceActiveHint" style="font-size:11px;font-weight:700;color:#7B1E2B;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"></span>' +
          '<button type="button" id="lsPwTestVoiceBtn" style="padding:5px 11px;border-radius:8px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11px;font-weight:800;cursor:pointer;flex-shrink:0;">Test Voice</button>';
        vcHost.appendChild(row);
        row.querySelector("#lsPwTestVoiceBtn").addEventListener("click", testVoice);
      }
    }
    populateVoices(); emitState();
  }

  window.LSAudioEngine = {
    playTopic: playTopic, playUnit: playUnit, play: togglePlay, pause: pause, resume: resume, togglePlay: togglePlay,
    stop: stop, stopHardware: stopHardware, prev: prev, next: next, jumpTo: startQueue, setSpeed: setSpeed,
    toggleTeachingMode: toggleTeach, toggleRepeat: toggleRepeat, setSleepTimer: setSleep,
    testVoice: testVoice, refreshVoices: populateVoices, emitState: emitState, getState: getState
  };

  function boot() {
    loadPrefs();
    try { if ("speechSynthesis" in window) webVoices = window.speechSynthesis.getVoices() || []; } catch (e) {}
    loadManifest().then(bindControls);
  }
  if ("speechSynthesis" in window && "onvoiceschanged" in window.speechSynthesis) {
    window.speechSynthesis.onvoiceschanged = function () { webVoices = window.speechSynthesis.getVoices() || []; populateVoices(); };
  }
  window.addEventListener("ls:lang-changed", function () { stop(); populateVoices(); });
  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(boot, 250); setTimeout(bindControls, 900); setTimeout(bindControls, 1800);
    if (typeof window.renderReadingPane === "function" && !window.__lsAudHook325) {
      window.__lsAudHook325 = true;
      var orig = window.renderReadingPane;
      window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(populateVoices, 60); return r; };
    }
    if (typeof MutationObserver !== "undefined" && document.body) {
      new MutationObserver(removeDeadDropdowns).observe(document.body, { childList: true, subtree: true });
    }
  });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-audio-engine.js]', __lsModErr); }

/* === MODULE: ls-audio-mini.js === */
try {
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
} catch (__lsModErr) { console.error('[LS Module Error: ls-audio-mini.js]', __lsModErr); }

/* === MODULE: ls-audio-window.js === */
try {
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
} catch (__lsModErr) { console.error('[LS Module Error: ls-audio-window.js]', __lsModErr); }

/* === MODULE: ls-diagrams.js === */
try {
(function () {
  "use strict";
  if (window.__lsDiagramsAsIsV320) return;
  window.__lsDiagramsAsIsV320 = true;

  var mermaidReady = false;
  var zoomScale = 1;
  var walkTimer = null;

  function injectNonDestructiveCss() {
    if (document.getElementById("lsDiagAsIsCssV320")) return;
    var st = document.createElement("style");
    st.id = "lsDiagAsIsCssV320";
    st.textContent =
      ".ls-asis-wrap { margin-top:20px; display:flex; flex-direction:column; gap:14px; }" +
      ".ls-asis-card { background:#FFFFFF; border:1px solid #E8E0D5; border-radius:14px; padding:12px; overflow:hidden; }" +
      ".ls-asis-head { display:flex; align-items:center; justify-content:space-between; gap:8px; margin-bottom:8px; padding-bottom:6px; border-bottom:1px solid #F3EDE4; }" +
      ".ls-asis-stage { overflow-x:auto; -webkit-overflow-scrolling:touch; max-width:100%; }" +
      ".ls-asis-stage svg { max-width:100%; height:auto; }" +
      ".ls-asis-stage img { max-width:100%; height:auto; }" +
      ".ls-asis-stage table { width:100%; border-collapse:collapse; }" +
      ".ls-asis-stage th, .ls-asis-stage td { border:1px solid #E8E0D5; padding:7px 9px; text-align:left; vertical-align:top; }";
    document.head.appendChild(st);
  }

  function isRealVisual(v) {
    if (!v || !v.html) return false;
    var h = String(v.html).trim();
    if (!h) return false;
    if (v.type === "svg") {
      if (/height=["']?(1[0-9]|2[0-4])["']?/i.test(h) && /width=["']?(1[0-9]|2[0-4])["']?/i.test(h)) return false;
      if (/viewbox=["']0 0 24 24["']/i.test(h) && h.length < 700) return false;
    }
    return true;
  }

  function initMermaidAsIs() {
    if (mermaidReady || !window.mermaid) return;
    mermaidReady = true;
    try {
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "loose",
        flowchart: { htmlLabels: true, useMaxWidth: true }
      });
    } catch (e) {}
  }

  function renderMermaidAsIs(container) {
    if (!container) return;
    var nodes = container.querySelectorAll(".mermaid");
    if (!nodes.length) return;
    if (!window.mermaid) {
      setTimeout(function () { renderMermaidAsIs(container); }, 350);
      return;
    }
    initMermaidAsIs();
    nodes.forEach(function (node, idx) {
      if (node.getAttribute("data-processed") === "true") return;
      var code = (node.textContent || "").trim();
      if (!code) return;
      var rid = "ls_asis_mm_" + Date.now() + "_" + idx;
      try {
        var res = window.mermaid.render(rid, code);
        if (res && typeof res.then === "function") {
          res.then(function (out) {
            if (out && out.svg) {
              node.innerHTML = out.svg;
              node.setAttribute("data-processed", "true");
            }
          }).catch(function () {});
        }
      } catch (e) {}
    });
  }

  function stopWalk() {
    if (walkTimer) { clearInterval(walkTimer); walkTimer = null; }
    var c = document.getElementById("lsZoomCanvas");
    if (c) {
      c.querySelectorAll(".ls-spotlight-dim, .ls-spotlight-active, .ls-row-flash").forEach(function (n) {
        n.classList.remove("ls-spotlight-dim", "ls-spotlight-active", "ls-row-flash");
      });
    }
  }

  function startWalk() {
    stopWalk();
    var c = document.getElementById("lsZoomCanvas");
    if (!c) return;
    var items = Array.prototype.slice.call(c.querySelectorAll("svg .node, li, .nest, tbody tr"));
    if (!items.length) return;
    var step = 0;
    items.forEach(function (n) { n.classList.add("ls-spotlight-dim"); });
    function tick() {
      items.forEach(function (n, idx) {
        var on = (idx === step);
        n.classList.toggle("ls-spotlight-active", on);
        n.classList.toggle("ls-spotlight-dim", !on);
        if (n.tagName === "TR") n.classList.toggle("ls-row-flash", on);
      });
      step = (step + 1) % items.length;
    }
    tick();
    walkTimer = setInterval(tick, 1400);
  }

  function openZoom(cardEl, title) {
    try {
      var m = document.getElementById("lsZoomModal");
      var c = document.getElementById("lsZoomCanvas");
      var t = document.getElementById("lsZoomTitle");
      if (!m || !c || !cardEl) return;
      stopWalk();
      zoomScale = 1;
      c.style.transform = "scale(1)";
      if (t) t.textContent = title || "Source Diagram";
      var stage = cardEl.querySelector(".ls-asis-stage");
      c.innerHTML = stage ? stage.innerHTML : cardEl.innerHTML;
      m.classList.remove("hidden");
      renderMermaidAsIs(c);
    } catch (e) {}
  }

  function wireZoom() {
    var m = document.getElementById("lsZoomModal");
    if (!m || m.__lsAsIsZoomBound) return;
    m.__lsAsIsZoomBound = true;
    var c = document.getElementById("lsZoomCanvas");
    var bCl = document.getElementById("lsZoomCloseBtn");
    var bIn = document.getElementById("lsZoomInBtn");
    var bOut = document.getElementById("lsZoomOutBtn");
    var bRs = document.getElementById("lsZoomResetBtn");
    var bWk = document.getElementById("lsMemoryPulseBtn");
    if (bCl) bCl.addEventListener("click", function () { stopWalk(); m.classList.add("hidden"); });
    if (bIn) bIn.addEventListener("click", function () { zoomScale = Math.min(2.5, +(zoomScale + 0.25).toFixed(2)); if (c) c.style.transform = "scale(" + zoomScale + ")"; });
    if (bOut) bOut.addEventListener("click", function () { zoomScale = Math.max(0.5, +(zoomScale - 0.25).toFixed(2)); if (c) c.style.transform = "scale(" + zoomScale + ")"; });
    if (bRs) bRs.addEventListener("click", function () { zoomScale = 1; if (c) c.style.transform = "scale(1)"; });
    if (bWk) bWk.addEventListener("click", startWalk);
    m.addEventListener("click", function (ev) { if (ev.target === m) { stopWalk(); m.classList.add("hidden"); } });
  }

  function renderAsIsDiagrams() {
    try {
      injectNonDestructiveCss();
      wireZoom();
      var pane = document.getElementById("readingPane");
      if (!pane || typeof state === "undefined" || !state.activeTopicId) return;

      ["lsVisualDiagramsSection", "lsSourceVisualsSection", "lsAsIsDiagramsSection"].forEach(function (id) {
        var old = document.getElementById(id);
        if (old) old.remove();
      });

      var rec = state.notes && state.notes[state.activeTopicId];
      if (!rec) return;

      var srcList = (rec.en && Array.isArray(rec.en.visuals) && rec.en.visuals.length)
        ? rec.en.visuals
        : ((rec[state.lang] && Array.isArray(rec[state.lang].visuals)) ? rec[state.lang].visuals : []);

      var visuals = [];
      for (var i = 0; i < srcList.length; i++) {
        if (isRealVisual(srcList[i])) visuals.push(srcList[i]);
      }
      if (!visuals.length) return;

      var sec = document.createElement("section");
      sec.id = "lsAsIsDiagramsSection";
      sec.className = "ls-asis-wrap";

      var head = document.createElement("div");
      head.className = "flex items-center justify-between gap-2 px-1";
      head.innerHTML =
        '<div class="text-sm font-extrabold text-[#7B1E2B]">Original Diagrams &amp; Tables (' + visuals.length + ')</div>' +
        '<span class="text-[10.5px] font-bold px-2 py-0.5 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Exact Source Copy</span>';
      sec.appendChild(head);

      visuals.forEach(function (v, idx) {
        var card = document.createElement("div");
        card.className = "ls-asis-card";
        var cap = String(v.caption || (v.type === "table" ? "Reference Table" : "Diagram " + (idx + 1)));

        var bar = document.createElement("div");
        bar.className = "ls-asis-head";
        bar.innerHTML =
          '<div class="text-xs font-bold text-[#7B1E2B] truncate">' + cap.replace(/</g, "&lt;") + '</div>' +
          '<button type="button" class="ls-asis-zoom px-2.5 py-1 rounded-lg bg-[#FAF7F2] border border-[#E8E0D5] text-[11px] font-bold text-[#7B1E2B] shrink-0">Zoom &amp; Walk</button>';

        var stage = document.createElement("div");
        stage.className = "ls-asis-stage";
        stage.innerHTML = v.html;

        bar.querySelector(".ls-asis-zoom").addEventListener("click", function () { openZoom(card, cap); });
        card.appendChild(bar);
        card.appendChild(stage);
        sec.appendChild(card);
      });

      pane.appendChild(sec);
      renderMermaidAsIs(sec);
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsAsIsHookV320) {
        window.__lsAsIsHookV320 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () {
          var r = orig.apply(this, arguments);
          renderAsIsDiagrams();
          return r;
        };
        renderAsIsDiagrams();
      }
    } catch (e) {}
  }

  window.LSDiagrams = { render: renderAsIsDiagrams };
  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(hook, 300);
    setTimeout(hook, 1100);
  });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-diagrams.js]', __lsModErr); }

/* === MODULE: ls-note-converter.js === */
try {
(function () {
  "use strict";
  if (window.__lsNoteConverterV312) return;
  window.__lsNoteConverterV312 = true;

  var CACHE_PREFIX = "ls_legal_copy_v1_";
  var busyKeys = {};

  function hasScript(obj, lang) {
    if (!obj || typeof obj !== "object") return false;
    var s = String(obj.inOneMinute || "") + " " + String(obj.meaning || "") + " " + String(obj.legalProvision || "");
    if (s.trim().length < 6) return false;
    if (lang === "te") return /[\u0C00-\u0C7F]{3,}/.test(s);
    if (lang === "hi") return /[\u0900-\u097F]{3,}/.test(s);
    return true;
  }

  function protectTokens(text) {
    var tokens = [];
    var re = /(<[^>]+>|\b(?:Section|Sec\.|Article|Art\.|Order|Rule|Schedule|Clause)\s+\d+[A-Za-z0-9()\-/]*|\b(?:IPC|CrPC|CPC|BNS|BNSS|BSA|ICA|TPA|AIR|SCC|SCR)\b)/g;
    var masked = String(text || "").replace(re, function (m) {
      tokens.push(m);
      return "__LTOK" + (tokens.length - 1) + "__";
    });
    return { masked: masked, tokens: tokens };
  }

  function restoreTokens(text, tokens) {
    var out = String(text || "");
    for (var i = 0; i < tokens.length; i++) {
      out = out.replace(new RegExp("__\\s*LTOK\\s*" + i + "\\s*__", "gi"), tokens[i]);
    }
    return out;
  }

  async function trLegalStr(text, tl) {
    var s = String(text || "").trim();
    if (!s) return "";
    var p = protectTokens(s.slice(0, 1100));
    var url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=" +
      encodeURIComponent(tl) + "&dt=t&q=" + encodeURIComponent(p.masked);
    var r = await fetch(url);
    if (!r.ok) throw new Error("HTTP " + r.status);
    var d = await r.json();
    var joined = "";
    if (Array.isArray(d) && Array.isArray(d[0])) {
      for (var i = 0; i < d[0].length; i++) {
        if (d[0][i] && d[0][i][0]) joined += d[0][i][0];
      }
    }
    return restoreTokens(joined.trim() || p.masked, p.tokens);
  }

  async function convertNode(val, tl) {
    if (!val || (typeof val !== "string" && typeof val !== "object")) return val;
    if (typeof val === "string") return await trLegalStr(val, tl);
    if (Array.isArray(val)) {
      var arr = [];
      for (var i = 0; i < val.length; i++) arr.push(await convertNode(val[i], tl));
      return arr;
    }
    var skip = { id: 1, type: 1, html: 1, svg: 1, mermaid: 1, code: 1, citation: 1, year: 1, visuals: 1 };
    var out = {};
    Object.keys(val).forEach(function (k) { out[k] = val[k]; });
    var keys = Object.keys(val);
    for (var j = 0; j < keys.length; j++) {
      var k = keys[j];
      if (!skip[k]) out[k] = await convertNode(val[k], tl);
    }
    return out;
  }

  async function ensureVerifiedCopy(topicId, lang, force) {
    if (!topicId || (lang !== "te" && lang !== "hi")) return;
    if (typeof state === "undefined" || !state.notes || !state.notes[topicId]) return;
    var rec = state.notes[topicId];
    if (!rec.en) return;
    if (!force && hasScript(rec[lang], lang)) return;

    if (!force) {
      try {
        var raw = localStorage.getItem(CACHE_PREFIX + lang + "_" + topicId);
        if (raw) {
          var parsed = JSON.parse(raw);
          if (hasScript(parsed, lang)) {
            rec[lang] = parsed;
            if (state.activeTopicId === topicId && state.lang === lang && typeof window.renderReadingPane === "function") window.renderReadingPane();
            return;
          }
        }
      } catch (e) {}
    }

    var lock = lang + ":" + topicId;
    if (busyKeys[lock] || !navigator.onLine) return;
    busyKeys[lock] = true;
    try {
      var conv = await convertNode(rec.en, lang);
      conv.visuals = rec.en.visuals || [];
      if (hasScript(conv, lang)) {
        rec[lang] = conv;
        try { localStorage.setItem(CACHE_PREFIX + lang + "_" + topicId, JSON.stringify(conv)); } catch (e) {}
        if (state.activeTopicId === topicId && state.lang === lang && typeof window.renderReadingPane === "function") window.renderReadingPane();
      }
    } catch (e) {}
    finally { delete busyKeys[lock]; }
  }

  function formatStudyCopy(topicId, lang, withEnglish) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[topicId] : null;
    if (!rec) return "";
    var ld = rec[lang] || rec.en;
    if (!ld) return "";
    var meta = (typeof findTopicMeta === "function") ? findTopicMeta(topicId) : null;
    var title = (meta && meta.topic && meta.topic.title) || topicId;
    var lines = ["LAW STUDYES - " + title + " (" + String(lang || "en").toUpperCase() + ")"];
    if (ld.inOneMinute) lines.push("\n[In One Minute]\n" + ld.inOneMinute);
    if (ld.legalProvision) lines.push("\n[Legal Provision]\n" + ld.legalProvision);
    if (ld.meaning) lines.push("\n[Meaning]\n" + ld.meaning);
    if (Array.isArray(ld.keyPoints) && ld.keyPoints.length) {
      lines.push("\n[Key Points]\n- " + ld.keyPoints.map(function (p) { return typeof p === "string" ? p : JSON.stringify(p); }).join("\n- "));
    }
    if (Array.isArray(ld.caseLaws) && ld.caseLaws.length) {
      lines.push("\n[Leading Case Laws]");
      ld.caseLaws.forEach(function (c) {
        if (typeof c === "string") lines.push("- " + c);
        else if (c) lines.push("- " + (c.name || c.title || "") + (c.summary ? ": " + c.summary : (c.principle ? ": " + c.principle : "")));
      });
    }
    if (withEnglish && lang !== "en" && rec.en) {
      lines.push("\n--- ENGLISH EXAM REFERENCE ---");
      if (rec.en.legalProvision) lines.push("Provision: " + rec.en.legalProvision);
      if (rec.en.inOneMinute) lines.push("Summary: " + rec.en.inOneMinute);
    }
    return lines.join("\n");
  }

  function copyText(txt, label) {
    if (!txt) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(txt).then(function () {
        if (typeof showToast === "function") showToast(label + " copied!");
      }).catch(function () { fallbackCopy(txt, label); });
    } else {
      fallbackCopy(txt, label);
    }
  }

  function fallbackCopy(txt, label) {
    try {
      var ta = document.createElement("textarea");
      ta.value = txt; ta.style.cssText = "position:fixed;left:-9999px;top:0;";
      document.body.appendChild(ta); ta.select(); document.execCommand("copy"); ta.remove();
      if (typeof showToast === "function") showToast(label + " copied!");
    } catch (e) {}
  }

  function renderCopyToolbar() {
    try {
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane");
      if (!pane) return;
      var lang = state.lang || "en";
      var rec = state.notes && state.notes[state.activeTopicId];
      if (!rec) return;

      if ((lang === "te" || lang === "hi") && !hasScript(rec[lang], lang)) {
        ensureVerifiedCopy(state.activeTopicId, lang, false);
      }

      var old = document.getElementById("lsNoteCopyBar");
      if (old) old.remove();

      var bar = document.createElement("div");
      bar.id = "lsNoteCopyBar";
      bar.style.cssText = "display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:12px;padding:8px 10px;border-radius:12px;background:#FAF7F2;border:1px solid #E8E0D5;";
      var langName = lang === "te" ? "Telugu" : (lang === "hi" ? "Hindi" : "English");
      var btnCss = "padding:6px 10px;border-radius:9px;border:1px solid #E8D5D8;background:#FFFFFF;color:#7B1E2B;font-size:11.5px;font-weight:700;cursor:pointer;";

      var bCopy = document.createElement("button");
      bCopy.type = "button"; bCopy.style.cssText = btnCss;
      bCopy.textContent = "Copy " + langName + " Note";
      bCopy.addEventListener("click", function () { copyText(formatStudyCopy(state.activeTopicId, lang, false), langName + " note"); });
      bar.appendChild(bCopy);

      if (lang !== "en") {
        var bDual = document.createElement("button");
        bDual.type = "button"; bDual.style.cssText = btnCss + "background:#FBF1F2;";
        bDual.textContent = "Copy " + langName + " + EN";
        bDual.addEventListener("click", function () { copyText(formatStudyCopy(state.activeTopicId, lang, true), langName + " + English copy"); });
        bar.appendChild(bDual);

        if (!hasScript(rec[lang], lang)) {
          var bFix = document.createElement("button");
          bFix.type = "button"; bFix.style.cssText = btnCss + "background:#7B1E2B;color:#FFFFFF;border-color:#7B1E2B;";
          bFix.textContent = "Prepare " + langName + " Now";
          bFix.addEventListener("click", function () {
            if (typeof showToast === "function") showToast("Preparing " + langName + " legal copy...");
            ensureVerifiedCopy(state.activeTopicId, lang, true);
          });
          bar.appendChild(bFix);
        }
      }
      pane.insertBefore(bar, pane.firstChild);
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsNoteConvHookV312) {
        window.__lsNoteConvHookV312 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); renderCopyToolbar(); return r; };
        renderCopyToolbar();
      }
    } catch (e) {}
  }

  window.LSNoteConverter = { ensureCopy: ensureVerifiedCopy, formatCopy: formatStudyCopy, hasScript: hasScript };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 350); setTimeout(hook, 1200); });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-note-converter.js]', __lsModErr); }

/* === MODULE: ls-indian-professor.js === */
try {
(function () {
  "use strict";
  if (window.__lsIndianProfessorV323) return;
  window.__lsIndianProfessorV323 = true;

  function clean(s) { return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s*\|\s*/g, ". ").replace(/\s+/g, " ").trim(); }
  function topicTitle(tid) {
    try { var m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null; if (m && m.topic && m.topic.title) return m.topic.title; } catch (e) {}
    return String(tid || "Topic").replace(/-/g, " ");
  }

  function buildLesson(tid, lang) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return null;
    var ld = rec[lang] || rec.en; if (!ld) return null;
    var t = topicTitle(tid), m1 = clean(ld.inOneMinute), pr = clean(ld.legalProvision), mn = clean(ld.meaning);
    var pts = Array.isArray(ld.keyPoints) ? ld.keyPoints.slice(0, 5).map(function (x, i) { var tx = clean(typeof x === "string" ? x : (x && (x.point || x.text || x.summary))); return tx ? ((i + 1) + ". " + tx) : ""; }).filter(Boolean) : [];
    var c0 = Array.isArray(ld.caseLaws) && ld.caseLaws[0];
    var topCase = !c0 ? "" : (typeof c0 === "string" ? clean(c0) : (clean(c0.name || c0.title) + (c0.principle || c0.summary ? " - " + clean(c0.principle || c0.summary) : "")));

    if (lang === "te") {
      return {
        heading: "\u0c07\u0c02\u0c21\u0c3f\u0c2f\u0c28\u0c4d \u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d",
        sub: "\u0c38\u0c41\u0c32\u0c2d\u0c2e\u0c48\u0c28 \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c35\u0c3f\u0c35\u0c30\u0c23 & \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d\u0c38\u0c4d",
        steps: [
          { step: 0, tag: "\u0c2a\u0c30\u0c3f\u0c1a\u0c2f\u0c02", text: "\u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 " + t + " \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c38\u0c41\u0c32\u0c2d\u0c02\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." },
          m1 ? { step: 1, tag: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b", text: m1 } : null,
          pr ? { step: 2, tag: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28", text: pr } : null,
          mn ? { step: 3, tag: "\u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c2e\u0c48\u0c28 \u0c05\u0c30\u0c4d\u0c25\u0c02", text: mn } : null,
          pts.length ? { step: 4, tag: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41", text: pts.join(" ") } : null,
          topCase ? { step: 5, tag: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41 \u0c32\u0c3e", text: topCase } : null
        ].filter(Boolean)
      };
    }
    if (lang === "hi") {
      return {
        heading: "\u0907\u0902\u0921\u093f\u092f\u0928 \u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e",
        sub: "\u0906\u0938\u093e\u0928 \u0939\u093f\u0902\u0926\u0940 \u0935\u094d\u092f\u093e\u0916\u094d\u092f\u093e & \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u093f\u092a\u094d\u0938",
        steps: [
          { step: 0, tag: "\u092a\u0930\u093f\u091a\u092f", text: "\u0906\u091c \u0939\u092e " + t + " \u0915\u094b \u0906\u0938\u093e\u0928 \u0914\u0930 \u0938\u094d\u092a\u0937\u094d\u091f \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964" },
          m1 ? { step: 1, tag: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902", text: m1 } : null,
          pr ? { step: 2, tag: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928", text: pr } : null,
          mn ? { step: 3, tag: "\u0938\u0930\u0932 \u0905\u0930\u094d\u0925", text: mn } : null,
          pts.length ? { step: 4, tag: "\u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938", text: pts.join(" ") } : null,
          topCase ? { step: 5, tag: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949", text: topCase } : null
        ].filter(Boolean)
      };
    }
    return {
      heading: "Indian Professor Classroom",
      sub: "Clear Indian LL.B. classroom explanation & exam structure",
      steps: [
        { step: 0, tag: "Overview", text: "Today let us clearly understand " + t + "." },
        m1 ? { step: 1, tag: "1-Minute Core", text: m1 } : null,
        pr ? { step: 2, tag: "Legal Provision", text: pr } : null,
        mn ? { step: 3, tag: "Plain Meaning", text: mn } : null,
        pts.length ? { step: 4, tag: "Key Scoring Points", text: pts.join(" ") } : null,
        topCase ? { step: 5, tag: "Landmark Case", text: topCase } : null
      ].filter(Boolean)
    };
  }

  function injectCss() {
    if (document.getElementById("lsProfCssV323")) return;
    var st = document.createElement("style"); st.id = "lsProfCssV323";
    st.textContent =
      ".ls-prof-card{margin:14px 0 16px;border-radius:16px;background:linear-gradient(135deg,#FFFBF2 0%,#FDF4F5 100%);border:1.5px solid #E5C9A8;padding:12px 14px}" +
      ".ls-prof-title{font-size:13.5px;font-weight:800;color:#7B1E2B}.ls-prof-sub{font-size:11px;color:#6B5B4D;font-weight:600}" +
      ".ls-prof-controls{display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:10px}" +
      ".ls-prof-btn{padding:6px 11px;border-radius:999px;border:1px solid #DFC5A4;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:800;cursor:pointer}" +
      ".ls-prof-btn.primary{background:#7B1E2B;color:#FFF;border-color:#7B1E2B}.ls-prof-status{font-size:11px;color:#7B1E2B;font-weight:700;margin-top:8px}" +
      ".ls-prof-body{margin-top:10px;display:flex;flex-direction:column;gap:7px}" +
      ".ls-prof-step{background:#FFF;border:1px solid #EFE4D6;border-left:3.5px solid #7B1E2B;border-radius:10px;padding:8px 10px;font-size:12.5px;line-height:1.55}" +
      ".ls-prof-step.speaking{background:#FFF7E6;border-left-color:#B45309}.ls-prof-tag{display:inline-block;font-size:10px;font-weight:800;color:#7B1E2B;background:#FBF1F2;padding:2px 7px;border-radius:999px;margin-bottom:4px}";
    document.head.appendChild(st);
  }

  function sync(st) {
    if (!st) return;
    var p = document.getElementById("lsProfPlayBtn"), s = document.getElementById("lsProfStopBtn"), el = document.getElementById("lsProfStatus");
    if (p) p.textContent = (st.playing && !st.paused) ? "Pause Class" : (st.paused ? "Resume Class" : "Listen to Professor");
    if (s) s.style.display = (st.playing || st.paused) ? "inline-block" : "none";
    if (el) el.textContent = (st.playing && !st.paused) ? ("Playing: " + st.voiceName + " (" + st.percent + "%)") : (st.paused ? "Paused" : "");
    document.querySelectorAll("#lsProfLessonBody .ls-prof-step").forEach(function (n) {
      n.classList.toggle("speaking", st.playing && !st.paused && !st.studioMp3 && parseInt(n.getAttribute("data-step") || "-9", 10) === st.stepIdx);
    });
  }

  function renderCard() {
    try {
      injectCss();
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane"); if (!pane) return;
      var old = document.getElementById("lsIndianProfessorCard"); if (old) old.remove();
      var lesson = buildLesson(state.activeTopicId, state.lang || "en"); if (!lesson) return;

      var card = document.createElement("section"); card.id = "lsIndianProfessorCard"; card.className = "ls-prof-card";
      card.innerHTML =
        '<div class="ls-prof-title">' + lesson.heading + '</div><div class="ls-prof-sub">' + lesson.sub + '</div>' +
        '<div class="ls-prof-controls">' +
          '<button type="button" id="lsProfPlayBtn" class="ls-prof-btn primary">Listen to Professor</button>' +
          '<button type="button" id="lsProfStopBtn" class="ls-prof-btn" style="display:none;">Stop</button>' +
          '<button type="button" id="lsProfOpenPlayerBtn" class="ls-prof-btn">Voice &amp; Speed Settings</button>' +
          '<button type="button" id="lsProfToggleBodyBtn" class="ls-prof-btn">Show Classroom Notes</button>' +
        '</div><div id="lsProfStatus" class="ls-prof-status"></div><div id="lsProfLessonBody" class="ls-prof-body" style="display:none;"></div>';

      var body = card.querySelector("#lsProfLessonBody");
      lesson.steps.forEach(function (st) {
        var r = document.createElement("div"); r.className = "ls-prof-step"; r.setAttribute("data-step", String(st.step));
        r.innerHTML = '<span class="ls-prof-tag">' + st.tag.replace(/</g, "&lt;") + '</span><div>' + st.text.replace(/</g, "&lt;") + '</div>';
        body.appendChild(r);
      });

      card.querySelector("#lsProfPlayBtn").addEventListener("click", function () {
        var eng = window.LSAudioEngine; if (!eng) return;
        var st = eng.getState();
        if (st.playing && st.topicId === state.activeTopicId) eng.togglePlay();
        else { body.style.display = "flex"; card.querySelector("#lsProfToggleBodyBtn").textContent = "Hide Classroom Notes"; eng.playTopic(state.activeTopicId, true); }
      });
      card.querySelector("#lsProfStopBtn").addEventListener("click", function () { if (window.LSAudioEngine) window.LSAudioEngine.stop(); });
      card.querySelector("#lsProfOpenPlayerBtn").addEventListener("click", function () {
        if (window.LSAudioWindow && typeof window.LSAudioWindow.open === "function") window.LSAudioWindow.open();
        else { var m = document.getElementById("lsPlayerWindowModal"); if (m) m.classList.add("show"); }
      });
      card.querySelector("#lsProfToggleBodyBtn").addEventListener("click", function (ev) {
        var open = body.style.display !== "none"; body.style.display = open ? "none" : "flex";
        ev.currentTarget.textContent = open ? "Show Classroom Notes" : "Hide Classroom Notes";
      });

      var copyBar = document.getElementById("lsNoteCopyBar");
      if (copyBar && copyBar.parentNode === pane) copyBar.insertAdjacentElement("afterend", card);
      else pane.insertBefore(card, pane.firstChild);
      if (window.LSAudioEngine) sync(window.LSAudioEngine.getState());
    } catch (e) {}
  }

  window.addEventListener("ls:audio-state", function (ev) { sync(ev.detail); });
  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsProfHookV323) {
        window.__lsProfHookV323 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); renderCard(); return r; };
        renderCard();
      }
    } catch (e) {}
  }

  window.LSIndianProfessor = {
    play: function () { if (window.LSAudioEngine) window.LSAudioEngine.playTopic(state.activeTopicId, true); },
    stop: function () { if (window.LSAudioEngine) window.LSAudioEngine.stop(); }
  };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 350); setTimeout(hook, 1200); });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-indian-professor.js]', __lsModErr); }

/* === MODULE: ls-pdf-export.js === */
try {
(function () {
  "use strict";
  if (window.__lsPdfExportV322) return;
  window.__lsPdfExportV322 = true;

  var LBL = {
    en: { med: "English Medium", m1: "In One Minute", pr: "Legal Provision", mn: "Meaning", pts: "Key Scoring Points", cs: "Leading Case Laws", dg: "Original Diagrams & Tables" },
    te: { med: "\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c2e\u0c40\u0c21\u0c3f\u0c2f\u0c02", m1: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b", pr: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28", mn: "\u0c05\u0c30\u0c4d\u0c25\u0c02", pts: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c05\u0c02\u0c36\u0c3e\u0c32\u0c41", cs: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41\u0c32\u0c41", dg: "\u0c05\u0c38\u0c32\u0c41 \u0c21\u0c2f\u0c3e\u0c17\u0c4d\u0c30\u0c2e\u0c4d\u200c\u0c32\u0c41" },
    hi: { med: "\u0939\u093f\u0928\u094d\u0926\u0940 \u092e\u093e\u0927\u094d\u092f\u092e", m1: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902", pr: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928", mn: "\u0905\u0930\u094d\u0925", pts: "\u092e\u0941\u0916\u094d\u092f \u092c\u093f\u0902\u0926\u0941", cs: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0928\u094d\u092f\u093e\u092f\u093f\u0915 \u0928\u093f\u0930\u094d\u0923\u092f", dg: "\u092e\u0942\u0932 \u0906\u0930\u0947\u0916 \u0914\u0930 \u0924\u093e\u0932\u093f\u0915\u093e\u090f\u0902" }
  };

  function esc(s) { return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }
  function isDual() { try { return localStorage.getItem("ls_dual_mode_v1") === "1"; } catch (e) { return false; } }
  function safeTopicName(title, lang, suffix) {
    var base = String(title || "LawStudyes-Topic").replace(/[<>:"/\\|?*\x00-\x1F]+/g, "").replace(/\s+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "").slice(0, 75) || "LawStudyes-Topic";
    return base + "-" + String(lang || "en").toUpperCase() + (suffix ? "-" + suffix : "");
  }

  function showSaveStatus(msg) {
    ["lsModalSaveStatus", "lsTopicSaveStatus"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) { el.textContent = msg; el.style.display = "block"; }
    });
    if (typeof showToast === "function") showToast(msg);
  }

  async function saveWithFolderPrompt(content, fileName, mimeType, ext, desc) {
    if (typeof window.showSaveFilePicker === "function") {
      try {
        var opts = { suggestedName: fileName };
        if (ext && mimeType) {
          var acc = {}; acc[mimeType] = ["." + ext.replace(/^\./, "")];
          opts.types = [{ description: desc || "Law Studyes File", accept: acc }];
        }
        var handle = await window.showSaveFilePicker(opts);
        var w = await handle.createWritable();
        await w.write(content);
        await w.close();
        showSaveStatus("Saved \"" + handle.name + "\" to your chosen folder!");
        return true;
      } catch (err) {
        if (err && err.name === "AbortError") { showSaveStatus("Save cancelled."); return false; }
      }
    }

    var capFs = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Filesystem;
    var capShare = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Share;
    if (capFs && typeof capFs.writeFile === "function") {
      var b64 = btoa(unescape(encodeURIComponent(content))), uri = null, loc = "Documents/LawStudyes/" + fileName;
      try {
        var w1 = await capFs.writeFile({ path: "LawStudyes/" + fileName, data: b64, directory: "DOCUMENTS", recursive: true });
        uri = w1 && w1.uri;
      } catch (e1) {
        try {
          var w2 = await capFs.writeFile({ path: fileName, data: b64, directory: "CACHE" });
          uri = w2 && w2.uri;
          loc = "Choose folder in Save/Share popup (" + fileName + ")";
        } catch (e2) {}
      }
      if (uri) {
        showSaveStatus("Saved: " + loc);
        if (capShare && typeof capShare.share === "function") {
          try { await capShare.share({ title: fileName, text: "Choose folder or app to save " + fileName, url: uri, dialogTitle: "Save " + fileName + " to..." }); } catch (e) {}
        }
        return true;
      }
    }

    try {
      var blob = new Blob([content], { type: (mimeType || "text/plain") + ";charset=utf-8" });
      var url = URL.createObjectURL(blob), a = document.createElement("a");
      a.href = url; a.download = fileName; document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { try { URL.revokeObjectURL(url); } catch (e) {} }, 2500);
      showSaveStatus("Saved \"" + fileName + "\" to your device's Downloads folder.");
      return true;
    } catch (e) { return false; }
  }

  function getVisualsHtml(tid, rec) {
    try {
      if (typeof state !== "undefined" && state.activeTopicId === tid) {
        var live = document.getElementById("lsAsIsDiagramsSection") || document.getElementById("lsSourceVisualsSection");
        if (live) {
          var cards = live.querySelectorAll(".ls-asis-card, .ls-src-vis-card"), out = [];
          cards.forEach(function (c) {
            var cap = c.querySelector(".ls-asis-head div, .ls-src-vis-head div");
            var stg = c.querySelector(".ls-asis-stage, .ls-src-vis-box");
            if (stg && stg.innerHTML.trim()) out.push('<div class="pdf-vis-card"><div class="pdf-vis-cap">' + esc(cap ? cap.textContent : "Diagram") + '</div><div class="pdf-vis-stage">' + stg.innerHTML + '</div></div>');
          });
          if (out.length) return out.join("");
        }
      }
    } catch (e) {}
    var vis = (rec && rec.en && Array.isArray(rec.en.visuals)) ? rec.en.visuals : [], arr = [];
    for (var i = 0; i < vis.length; i++) {
      var v = vis[i]; if (!v || !v.html) continue;
      arr.push('<div class="pdf-vis-card"><div class="pdf-vis-cap">' + esc(v.caption || ("Diagram " + (i + 1))) + '</div><div class="pdf-vis-stage">' + v.html + '</div></div>');
    }
    return arr.join("");
  }

  function buildTopicHtml(tid, title, subj, unitLbl, lang, dual) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return "";
    var ld = rec[lang] || rec.en; if (!ld) return "";
    var l = LBL[lang] || LBL.en, p = ['<article class="pdf-topic">'];
    p.push('<div class="pdf-meta">' + esc(subj) + (unitLbl ? " &middot; " + esc(unitLbl) : "") + ' &middot; ' + esc(l.med) + '</div>');
    p.push('<h1 class="pdf-title">' + esc(title) + '</h1>');
    if (ld.inOneMinute) p.push('<div class="pdf-box highlight"><h2>' + esc(l.m1) + '</h2><p>' + esc(ld.inOneMinute) + '</p></div>');
    if (ld.legalProvision) p.push('<div class="pdf-box"><h2>' + esc(l.pr) + '</h2><p>' + esc(ld.legalProvision) + '</p></div>');
    if (ld.meaning) p.push('<div class="pdf-box"><h2>' + esc(l.mn) + '</h2><p>' + esc(ld.meaning) + '</p></div>');
    if (Array.isArray(ld.keyPoints) && ld.keyPoints.length) {
      p.push('<div class="pdf-box"><h2>' + esc(l.pts) + '</h2><ul>' + ld.keyPoints.map(function (x) { return '<li>' + esc(typeof x === "string" ? x : (x.point || x.text || x.summary || JSON.stringify(x))) + '</li>'; }).join("") + '</ul></div>');
    }
    if (Array.isArray(ld.caseLaws) && ld.caseLaws.length) {
      p.push('<div class="pdf-box"><h2>' + esc(l.cs) + '</h2><ul>' + ld.caseLaws.map(function (c) {
        if (typeof c === "string") return '<li>' + esc(c) + '</li>';
        return c ? ('<li><strong>' + esc(c.name || c.title || "") + '</strong>' + (c.principle || c.summary ? ': ' + esc(c.principle || c.summary) : '') + '</li>') : '';
      }).join("") + '</ul></div>');
    }
    if (dual && lang !== "en" && rec.en) {
      p.push('<div class="pdf-box dual"><h2>English Exam Reference</h2>');
      if (rec.en.legalProvision) p.push('<p><strong>Provision:</strong> ' + esc(rec.en.legalProvision) + '</p>');
      if (rec.en.inOneMinute) p.push('<p><strong>Summary:</strong> ' + esc(rec.en.inOneMinute) + '</p>');
      p.push('</div>');
    }
    var vh = getVisualsHtml(tid, rec);
    if (vh) p.push('<div class="pdf-vis-wrap"><h2>' + esc(l.dg) + '</h2>' + vh + '</div>');
    p.push('</article>');
    return p.join("");
  }

  function buildTopicMd(tid, title, subj, unitLbl, lang, dual) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[tid] : null;
    if (!rec) return "";
    var ld = rec[lang] || rec.en; if (!ld) return "";
    var out = ["# " + title, "*" + subj + (unitLbl ? " | " + unitLbl : "") + " | " + String(lang || "en").toUpperCase() + "*", ""];
    if (ld.inOneMinute) out.push("## In One Minute\n" + ld.inOneMinute + "\n");
    if (ld.legalProvision) out.push("## Legal Provision\n" + ld.legalProvision + "\n");
    if (ld.meaning) out.push("## Meaning\n" + ld.meaning + "\n");
    if (Array.isArray(ld.keyPoints) && ld.keyPoints.length) {
      out.push("## Key Points");
      ld.keyPoints.forEach(function (x) { out.push("- " + (typeof x === "string" ? x : (x.point || x.text || x.summary || JSON.stringify(x)))); });
      out.push("");
    }
    if (Array.isArray(ld.caseLaws) && ld.caseLaws.length) {
      out.push("## Leading Case Laws");
      ld.caseLaws.forEach(function (c) { out.push(typeof c === "string" ? ("- " + c) : ("- **" + (c.name || c.title || "") + "**: " + (c.principle || c.summary || ""))); });
      out.push("");
    }
    if (dual && lang !== "en" && rec.en) {
      out.push("---\n## English Exam Reference");
      if (rec.en.legalProvision) out.push("**Provision:** " + rec.en.legalProvision);
      if (rec.en.inOneMinute) out.push("**Summary:** " + rec.en.inOneMinute);
    }
    return out.join("\n");
  }

  function wrapA4(docTitle, bodyHtml) {
    var dt = new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
    return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width,initial-scale=1.0" /><title>' + esc(docTitle) + '</title>' +
      '<style>@page{size:A4;margin:14mm 13mm}*{box-sizing:border-box}body{font-family:"Noto Sans Telugu","Noto Sans Devanagari","Nirmala UI","Segoe UI",Roboto,Arial,sans-serif;color:#1A1715;background:#FFF;margin:0;padding:18px;line-height:1.58;font-size:12.5px}' +
      '.pdf-toolbar{position:sticky;top:0;display:flex;justify-content:space-between;align-items:center;padding:10px 14px;margin-bottom:14px;background:#7B1E2B;color:#FFF;border-radius:10px}.pdf-toolbar button{padding:7px 14px;border:0;border-radius:8px;background:#FFF;color:#7B1E2B;font-weight:800;cursor:pointer}' +
      '.pdf-header{display:flex;justify-content:space-between;border-bottom:2px solid #7B1E2B;padding-bottom:8px;margin-bottom:14px}.pdf-brand{font-family:Georgia,serif;font-size:20px;font-weight:800;color:#7B1E2B}' +
      '.pdf-topic{page-break-after:always}.pdf-topic:last-child{page-break-after:auto}.pdf-meta{font-size:11px;font-weight:700;color:#8C6D46;text-transform:uppercase}.pdf-title{font-family:Georgia,serif;font-size:19px;color:#7B1E2B;margin:4px 0 12px}' +
      '.pdf-box{border:1px solid #E4DBD0;border-radius:8px;padding:10px 12px;margin-bottom:10px;break-inside:avoid}.pdf-box.highlight{background:#FBF6EE;border-color:#DFC5A4}.pdf-box.dual{background:#FAF7F2;border:1.5px dashed #B89D7A}' +
      '.pdf-box h2,.pdf-vis-wrap>h2{font-size:13px;color:#7B1E2B;margin:0 0 6px;border-bottom:1px solid #EFE7DC;padding-bottom:3px}.pdf-vis-card{border:1px solid #DDD2C5;border-radius:8px;padding:10px;margin-bottom:10px;break-inside:avoid}' +
      '.pdf-vis-cap{font-size:11.5px;font-weight:800;color:#7B1E2B;margin-bottom:6px}.pdf-vis-stage svg,.pdf-vis-stage img{max-width:100%!important;height:auto!important;display:block;margin:0 auto}' +
      '.pdf-vis-stage table{width:100%;border-collapse:collapse;font-size:11.5px}.pdf-vis-stage th{background:#FBF1F2;color:#7B1E2B;border:1px solid #DFC9CC;padding:6px}.pdf-vis-stage td{border:1px solid #E4DBD0;padding:6px}' +
      '@media print{body{padding:0}.pdf-toolbar{display:none!important}}</style></head><body>' +
      '<div class="pdf-toolbar"><span><strong>Law Studyes</strong> &middot; ' + esc(docTitle) + '</span><button onclick="window.print()">Print / Save as PDF</button></div>' +
      '<div class="pdf-header"><div class="pdf-brand">&#9878; Law Studyes</div><div style="font-size:11px;color:#5F554E">' + esc(dt) + '</div></div>' + bodyHtml + '</body></html>';
  }

  function ctx() {
    if (typeof state === "undefined" || !state.activeTopicId) return null;
    var tid = state.activeTopicId, lang = state.lang || "en", m = typeof findTopicMeta === "function" ? findTopicMeta(tid) : null;
    return {
      tid: tid, lang: lang, meta: m,
      title: (m && m.topic && m.topic.title) || tid,
      subj: (m && m.subject && m.subject.title) || "3-Year LL.B.",
      unitLbl: (m && m.unit) ? ("Unit " + (m.unit.unitNo || "") + (m.unit.title ? ": " + m.unit.title : "")) : ""
    };
  }

  function printPdf(html, fname) {
    var isCap = !!(window.Capacitor && typeof window.Capacitor.isNativePlatform === "function" && window.Capacitor.isNativePlatform());
    if (isCap) { saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); return; }
    var prev = document.title;
    try {
      document.title = fname;
      var old = document.getElementById("lsPdfPrintFrame"); if (old) old.remove();
      var fr = document.createElement("iframe"); fr.id = "lsPdfPrintFrame";
      fr.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;";
      document.body.appendChild(fr);
      var d = fr.contentWindow.document; d.open(); d.write(html); d.close();
      setTimeout(function () {
        try {
          fr.contentWindow.focus(); fr.contentWindow.print();
          showSaveStatus("Select 'Save as PDF' & pick your folder -> filename: \"" + fname + ".pdf\"");
        } catch (err) { saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); }
        finally { setTimeout(function () { document.title = prev; }, 1500); }
      }, 280);
    } catch (e) { document.title = prev; saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); }
  }

  function exportPdf() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, ""); printPdf(wrapA4(fn, buildTopicHtml(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual())), fn); }
  function exportHtml() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, "HardCopy"); saveWithFolderPrompt(wrapA4(fn, buildTopicHtml(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual())), fn + ".html", "text/html", "html", "Printable Study Sheet (.html)"); }
  function exportMd() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, ""); saveWithFolderPrompt(buildTopicMd(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual()), fn + ".md", "text/markdown", "md", "Markdown Study Notes (.md)"); }
  function exportSubjectMd() {
    try {
      var subj = typeof getActiveSubject === "function" ? getActiveSubject() : null;
      if (!subj || !Array.isArray(subj.units)) { exportMd(); return; }
      var lang = (typeof state !== "undefined" && state.lang) ? state.lang : "en";
      var md = "# " + subj.title + "\n\n";
      subj.units.forEach(function (u) {
        md += "---\n# Unit " + (u.unitNo || "") + ": " + (u.title || "") + "\n\n";
        (u.topics || []).forEach(function (t) { md += buildTopicMd(t.id, t.title || t.id, subj.title, "Unit " + (u.unitNo || ""), lang, isDual()) + "\n"; });
      });
      var fn = safeTopicName(subj.title, lang, "FullSubject");
      saveWithFolderPrompt(md, fn + ".md", "text/markdown", "md", "Subject Markdown Notes (.md)");
    } catch (e) { exportMd(); }
  }
  function exportUnit() {
    var c = ctx(); if (!c || !c.meta || !c.meta.unit || !Array.isArray(c.meta.unit.topics)) { exportPdf(); return; }
    var secs = c.meta.unit.topics.map(function (t) { return t && t.id ? buildTopicHtml(t.id, t.title || t.id, c.subj, c.unitLbl, c.lang, isDual()) : ""; }).filter(Boolean);
    if (!secs.length) return;
    var fn = safeTopicName(c.subj + "-Unit" + (c.meta.unit.unitNo || "1"), c.lang, "Booklet");
    printPdf(wrapA4(fn, secs.join("")), fn);
  }

  function wireTopicHeaderExports() {
    ["lsPdfTopicBtn", "lsPdfUnitBtn", "lsPdfXeroxBtn", "lsUnifiedDownloadsWrap"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.remove();
    });

    var mdBtn = document.getElementById("exportTopicMdBtn");
    if (mdBtn && mdBtn.parentElement) {
      if (!mdBtn.__lsSaveAsBoundV322) {
        mdBtn.__lsSaveAsBoundV322 = true;
        mdBtn.title = "Save topic as .md (choose folder with Topic Name)";
        mdBtn.addEventListener("click", function (ev) {
          ev.preventDefault();
          ev.stopImmediatePropagation();
          exportMd();
        }, true);
      }

      var row = mdBtn.parentElement;
      if (!row.querySelector("#lsHeaderPdfBtn")) {
        var bPdf = document.createElement("button");
        bPdf.type = "button";
        bPdf.id = "lsHeaderPdfBtn";
        bPdf.className = "px-3 py-2 rounded-lg bg-[#7B1E2B] hover:bg-[#5E1520] text-white text-xs font-semibold flex items-center gap-1.5";
        bPdf.textContent = "PDF";
        bPdf.title = "Download Topic as Hard-Copy PDF (pre-filled with Topic Name)";
        bPdf.addEventListener("click", exportPdf);
        mdBtn.insertAdjacentElement("afterend", bPdf);

        var bHtml = document.createElement("button");
        bHtml.type = "button";
        bHtml.id = "lsHeaderPrintHtmlBtn";
        bHtml.className = "px-3 py-2 rounded-lg border border-[#E8E0D5] bg-white hover:bg-[#FAF7F2] text-xs font-semibold text-[#1F1B18] flex items-center gap-1.5";
        bHtml.textContent = "Save File";
        bHtml.title = "Choose folder & save A4 printable study file with Topic Name";
        bHtml.addEventListener("click", exportHtml);
        bPdf.insertAdjacentElement("afterend", bHtml);
      }

      if (!document.getElementById("lsTopicSaveStatus")) {
        var st = document.createElement("div");
        st.id = "lsTopicSaveStatus";
        st.style.cssText = "display:none;width:100%;margin-top:6px;padding:6px 10px;border-radius:8px;background:#EEF7EE;border:1px solid #B7DDB9;color:#1F5C24;font-size:11.5px;font-weight:700;";
        row.parentElement.appendChild(st);
      }
    }
  }

  function wireDbExportModal() {
    var subjMdBtn = document.getElementById("exportSubjectMdBtn");
    if (!subjMdBtn || !subjMdBtn.parentElement) return;

    if (!subjMdBtn.__lsSaveAsBoundV322) {
      subjMdBtn.__lsSaveAsBoundV322 = true;
      subjMdBtn.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopImmediatePropagation();
        exportSubjectMd();
      }, true);
    }

    var grid = subjMdBtn.parentElement;
    if (!grid.querySelector("#lsModalTopicPdfBtn")) {
      var cls = "px-3.5 py-2.5 rounded-lg border border-[#E8E0D5] bg-white hover:bg-[#FAF7F2] text-xs font-semibold text-[#1F1B18] flex items-center justify-center gap-2";
      var primaryCls = "px-3.5 py-2.5 rounded-lg bg-[#7B1E2B] hover:bg-[#5E1520] text-xs font-semibold text-white flex items-center justify-center gap-2";

      var b1 = document.createElement("button");
      b1.type = "button"; b1.id = "lsModalTopicPdfBtn"; b1.className = primaryCls;
      b1.textContent = "Download Topic PDF (Hard Copy)";
      b1.addEventListener("click", exportPdf);
      grid.appendChild(b1);

      var b2 = document.createElement("button");
      b2.type = "button"; b2.id = "lsModalUnitPdfBtn"; b2.className = cls;
      b2.textContent = "Download Unit PDF Booklet";
      b2.addEventListener("click", exportUnit);
      grid.appendChild(b2);

      var b3 = document.createElement("button");
      b3.type = "button"; b3.id = "lsModalTopicHtmlBtn"; b3.className = cls;
      b3.textContent = "Save Topic Print File (.html)";
      b3.addEventListener("click", exportHtml);
      grid.appendChild(b3);

      var b4 = document.createElement("button");
      b4.type = "button"; b4.id = "lsModalTopicMdBtn"; b4.className = cls;
      b4.textContent = "Save Current Topic (.md)";
      b4.addEventListener("click", exportMd);
      grid.appendChild(b4);
    }

    if (!document.getElementById("lsModalSaveStatus") && grid.parentElement) {
      var st = document.createElement("div");
      st.id = "lsModalSaveStatus";
      st.style.cssText = "display:none;margin-top:8px;padding:7px 10px;border-radius:8px;background:#EEF7EE;border:1px solid #B7DDB9;color:#1F5C24;font-size:11.5px;font-weight:700;";
      grid.insertAdjacentElement("afterend", st);
    }
  }

  function mountAll() {
    try {
      wireTopicHeaderExports();
      wireDbExportModal();
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsPdfHookV322) {
        window.__lsPdfHookV322 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(mountAll, 25); return r; };
      }
      mountAll();
    } catch (e) {}
  }

  window.LSPdfExport = { exportTopic: exportPdf, exportUnit: exportUnit, exportHtml: exportHtml, exportMd: exportMd, safeTopicName: safeTopicName };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 300); setTimeout(hook, 1100); });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-pdf-export.js]', __lsModErr); }

/* === MODULE: ls-drill.js === */
try {
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

} catch (__lsModErr) { console.error('[LS Module Error: ls-drill.js]', __lsModErr); }

/* === MODULE: ls-hub.js === */
try {
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

} catch (__lsModErr) { console.error('[LS Module Error: ls-hub.js]', __lsModErr); }

/* === MODULE: ls-judgments.js === */
try {
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

} catch (__lsModErr) { console.error('[LS Module Error: ls-judgments.js]', __lsModErr); }

/* === MODULE: ls-nav.js === */
try {
(function () {
  "use strict";
  if (window.__lsModularNavV307) return;
  window.__lsModularNavV307 = true;

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
      "#lsAudioHideInlineBtn { margin-left: auto; display: inline-flex; align-items: center; gap: 3px; padding: 2px 9px; border-radius: 999px; border: 1px solid #E8D5D8; background: #FAF7F2; color: #7B1E2B; font-size: 10.5px; font-weight: 800; cursor: pointer; flex-shrink: 0; transition: background 0.15s ease, transform 0.15s ease; }" +
      "#lsAudioHideInlineBtn:active { transform: scale(0.92); background: #FBF1F2; }" +
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
      ".ls-tool-tile:active { transform: scale(0.96); border-color: #7B1E2B; }";
    document.head.appendChild(style);

    var oldToggle = document.getElementById("lsAudioMiniToggle");
    if (oldToggle) oldToggle.remove();

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
} catch (__lsModErr) { console.error('[LS Module Error: ls-nav.js]', __lsModErr); }

/* === MODULE: ls-ota-diag.js === */
try {
(function () {
  "use strict";
  if (window.__lsOtaDiagV307) return;
  window.__lsOtaDiagV307 = true;

  window.__lsOtaDiagLog = window.__lsOtaDiagLog || [];
  function pushDiag(msg) {
    var ts = new Date().toLocaleTimeString();
    window.__lsOtaDiagLog.push("[" + ts + "] " + msg);
    if (window.__lsOtaDiagLog.length > 80) window.__lsOtaDiagLog.shift();
  }
  window.__lsPushOtaDiag = pushDiag;

  function ensureDiagModal() {
    if (!document.getElementById("lsOtaDiagStyle")) {
      var st = document.createElement("style");
      st.id = "lsOtaDiagStyle";
      st.textContent =
        "#lsOtaBannerDiag { display:none; background:#FAD676; color:#56111B; border:none; border-radius:6px; padding:3px 9px; font-size:11px; font-weight:800; cursor:pointer; flex-shrink:0; }" +
        "#lsOtaBannerDiag.show { display:inline-block; }" +
        "#lsOtaDiagModal { position:fixed; inset:0; z-index:10090; background:rgba(20,14,12,0.62); backdrop-filter:blur(3px); display:none; align-items:center; justify-content:center; padding:14px; }" +
        "#lsOtaDiagModal.show { display:flex; }" +
        "#lsOtaDiagCard { background:#FFFFFF; width:100%; max-width:500px; max-height:86vh; border-radius:20px; padding:16px; display:flex; flex-direction:column; gap:10px; box-shadow:0 20px 44px rgba(0,0,0,0.3); }" +
        "#lsOtaDiagPre { background:#181412; color:#F5EFE6; font-family:monospace; font-size:11px; line-height:1.45; padding:12px; border-radius:12px; overflow:auto; max-height:52vh; white-space:pre-wrap; word-break:break-word; margin:0; }";
      document.head.appendChild(st);
    }

    var closeBtn = document.getElementById("lsOtaBannerClose");
    if (closeBtn && !document.getElementById("lsOtaBannerDiag")) {
      var dBtn = document.createElement("button");
      dBtn.id = "lsOtaBannerDiag";
      dBtn.type = "button";
      dBtn.textContent = "Details";
      dBtn.addEventListener("click", function () { openDiagModal(true); });
      closeBtn.parentNode.insertBefore(dBtn, closeBtn);
    }

    var toolsGrid = document.querySelector("#lsMoreCard .grid");
    if (toolsGrid && !document.getElementById("lsMoreOtaDiag")) {
      var tile = document.createElement("button");
      tile.id = "lsMoreOtaDiag";
      tile.type = "button";
      tile.className = "ls-tool-tile col-span-2";
      tile.style.cssText = "padding:12px;border-radius:16px;border:1px solid #E8D5A8;background:#FFFBF0;text-align:left;";
      tile.innerHTML = '<div style="font-size:12px;font-weight:700;color:#7B1E2B;">OTA Diagnostics (In-App)</div><div style="font-size:10.5px;color:#5F554E;margin-top:2px;">Inspect Vercel, GitHub &amp; SHA-256 checksum download status</div>';
      tile.addEventListener("click", function () {
        var sheet = document.getElementById("lsMoreSheet");
        if (sheet) sheet.classList.remove("show");
        openDiagModal(true);
      });
      toolsGrid.appendChild(tile);
    }

    if (document.getElementById("lsOtaDiagModal")) return;

    var dm = document.createElement("div");
    dm.id = "lsOtaDiagModal";
    dm.innerHTML =
      '<div id="lsOtaDiagCard">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">' +
          '<div><div style="font-size:14px;font-weight:800;color:#7B1E2B;">OTA Live Diagnostics</div><div style="font-size:11px;color:#5F554E;">Vercel, GitHub &amp; Native SHA-256 Probe</div></div>' +
          '<button type="button" id="lsOtaDiagClose" style="font-size:11.5px;font-weight:700;padding:5px 11px;border-radius:999px;border:1px solid #E8E0D5;background:#FAF7F2;color:#5F554E;cursor:pointer;">Close</button>' +
        '</div>' +
        '<pre id="lsOtaDiagPre">Tap Check Mirrors or Test Native Download...</pre>' +
        '<div style="display:flex;flex-wrap:wrap;gap:8px;">' +
          '<button type="button" id="lsOtaDiagRun" style="flex:1;padding:9px 10px;border-radius:11px;border:none;background:#7B1E2B;color:#fff;font-size:12px;font-weight:700;cursor:pointer;">Check Mirrors</button>' +
          '<button type="button" id="lsOtaDiagNative" style="flex:1;padding:9px 10px;border-radius:11px;border:1px solid #7B1E2B;background:#FBF1F2;color:#7B1E2B;font-size:12px;font-weight:700;cursor:pointer;">Test Native Download</button>' +
          '<button type="button" id="lsOtaDiagCopy" style="padding:9px 12px;border-radius:11px;border:1px solid #D6C7BC;background:#FAF7F2;color:#1F1B18;font-size:12px;font-weight:700;cursor:pointer;">Copy</button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(dm);
    dm.addEventListener("click", function (ev) {
      if (ev.target === dm || ev.target.id === "lsOtaDiagClose") dm.classList.remove("show");
    });
    dm.querySelector("#lsOtaDiagRun").addEventListener("click", runMirrorCheck);
    dm.querySelector("#lsOtaDiagNative").addEventListener("click", runNativeDownloadProbe);
    dm.querySelector("#lsOtaDiagCopy").addEventListener("click", copyReport);
  }

  function copyReport() {
    var txt = (document.getElementById("lsOtaDiagPre") || {}).textContent || "";
    if (!txt) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(txt).then(function () {
        if (typeof showToast === "function") showToast("OTA Diagnostics copied!");
      }).catch(function () {});
    }
  }

  async function runMirrorCheck() {
    ensureDiagModal();
    var pre = document.getElementById("lsOtaDiagPre");
    var lines = [];
    function out(s) { lines.push(s); if (pre) { pre.textContent = lines.join("\n"); pre.scrollTop = pre.scrollHeight; } }

    out("=== LAW STUDYES OTA DIAGNOSTICS (v3.0.7) ===");
    out("Time: " + new Date().toLocaleString() + " | Online: " + navigator.onLine);
    out("Last Status: " + (window.__lsOtaLastStatus || "None"));

    var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
    if (!up) {
      out("Capgo Plugin: Web/Preview mode");
    } else {
      try {
        var cur = await up.current();
        var b = cur && (cur.bundle || cur);
        out("Active Bundle: id=" + (b && b.id) + " | ver=" + (b && b.version) + " | status=" + (b && b.status));
      } catch (e) { out("current() ERR: " + (e.message || e)); }
      try {
        var lst = await up.list();
        var arr = (lst && lst.bundles) ? lst.bundles : [];
        out("Stored Bundles (" + arr.length + "): " + (arr.length ? arr.map(function (x) { return x.version + "[" + x.status + "]"; }).join(", ") : "none"));
      } catch (e) {}
    }

    if (window.__lsOtaLastErrors && window.__lsOtaLastErrors.length) {
      out("\n--- Last Mirror Errors ---");
      window.__lsOtaLastErrors.forEach(function (l) { out("  * " + l); });
    }

    out("\n--- Live Mirror Probes ---");
    var ts = Date.now();
    var probes = [
      { name: "Vercel JSON", url: "https://law-studyes.vercel.app/ota-version.json?t=" + ts },
      { name: "GitHub Raw JSON", url: "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www/ota-version.json?t=" + ts }
    ];
    for (var i = 0; i < probes.length; i++) {
      var p = probes[i];
      var t0 = Date.now();
      try {
        var r = await fetch(p.url, { cache: "no-store" });
        var j = await r.json();
        out("[OK] " + p.name + " (" + (Date.now() - t0) + "ms) -> ver=" + j.version + " | sha=" + String(j.sha256 || "").slice(0, 12));
      } catch (err) {
        out("[FAIL] " + p.name + " -> " + ((err && err.message) || String(err)));
      }
    }
  }

  async function runNativeDownloadProbe() {
    ensureDiagModal();
    var pre = document.getElementById("lsOtaDiagPre");
    function add(s) { if (pre) { pre.textContent += "\n" + s; pre.scrollTop = pre.scrollHeight; } }
    var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
    if (!up) { add("\n[SKIP] Native test only runs on Android."); return; }

    add("\n=== NATIVE SHA-256 DOWNLOAD PROBE ===");
    try {
      var r = await fetch("https://law-studyes.vercel.app/ota-version.json?t=" + Date.now(), { cache: "no-store" });
      var meta = await r.json();
      var sha = String(meta.sha256 || "").trim().toLowerCase();
      var testVer = "0.0.0-probe" + String(Date.now()).slice(-4);
      var t0 = Date.now();
      add("Downloading with checksum=" + sha.slice(0, 12) + "...");
      var bdl = await up.download({ url: meta.url + "?probe=" + Date.now(), version: testVer, checksum: sha });
      add("[NATIVE OK] Downloaded & SHA-256 verified in " + (Date.now() - t0) + "ms | id=" + (bdl && bdl.id));
      if (bdl && bdl.id && typeof up.delete === "function") {
        await up.delete({ id: bdl.id });
        add("(Cleaned up probe bundle)");
      }
    } catch (err) {
      add("[NATIVE FAIL] " + ((err && err.message) || String(err)));
    }
  }

  function openDiagModal(autoRun) {
    ensureDiagModal();
    var dm = document.getElementById("lsOtaDiagModal");
    if (dm) dm.classList.add("show");
    if (autoRun !== false) runMirrorCheck();
  }

  window.LSOtaDiag = { open: openDiagModal, runMirrorCheck: runMirrorCheck, runNativeProbe: runNativeDownloadProbe, push: pushDiag };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(ensureDiagModal, 350); });
})();
} catch (__lsModErr) { console.error('[LS Module Error: ls-ota-diag.js]', __lsModErr); }

/* === MODULE: ls-vault.js === */
try {
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

} catch (__lsModErr) { console.error('[LS Module Error: ls-vault.js]', __lsModErr); }