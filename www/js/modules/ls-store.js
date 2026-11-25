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
