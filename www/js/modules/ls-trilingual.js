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