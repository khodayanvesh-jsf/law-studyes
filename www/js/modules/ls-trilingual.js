(function () {
  "use strict";
  if (window.__lsTrilingualV310) return;
  window.__lsTrilingualV310 = true;

  var LANG_KEY = "ls_medium_v1";
  var DUAL_KEY = "ls_dual_mode_v1";
  var CACHE_PREFIX = "ls_tr_v1_";
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
      badge: "\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c2e\u0c40\u0c21\u0c3f\u0c2f\u0c02 (Telugu)",
      inOneMinute: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b (In One Minute)",
      legalProvision: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28 (Legal Provision)",
      meaning: "\u0c05\u0c30\u0c4d\u0c25\u0c02 & \u0c28\u0c3f\u0c30\u0c4d\u0c35\u0c1a\u0c28\u0c02 (Meaning)",
      keyPoints: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c05\u0c02\u0c36\u0c3e\u0c32\u0c41 (Key Points)",
      caseLaws: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41\u0c32\u0c41 (Case Laws)",
      selfTest: "\u0c38\u0c4d\u0c35\u0c2f\u0c02 \u0c2a\u0c30\u0c40\u0c15\u0c4d\u0c37 (Self-Test)"
    },
    hi: {
      badge: "\u0939\u093f\u0928\u094d\u0926\u0940 \u092e\u093e\u0927\u094d\u092f\u092e (Hindi)",
      inOneMinute: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902 (In One Minute)",
      legalProvision: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928 (Legal Provision)",
      meaning: "\u0905\u0930\u094d\u0925 \u0914\u0930 \u092a\u0930\u093f\u092d\u093e\u0937\u093e (Meaning)",
      keyPoints: "\u092e\u0941\u0916\u094d\u092f \u092c\u093f\u0902\u0926\u0941 (Key Points)",
      caseLaws: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0928\u094d\u092f\u093e\u092f\u093f\u0915 \u0928\u093f\u0930\u094d\u0923\u092f (Case Laws)",
      selfTest: "\u0938\u094d\u0935-\u092a\u0930\u0940\u0915\u094d\u0937\u0923 (Self-Test)"
    }
  };

  function getSavedLang() {
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
    if (typeof window.renderReadingPane === "function") window.renderReadingPane();
  }

  function injectTrilingualCss() {
    if (document.getElementById("lsTrilingualCss")) return;
    var st = document.createElement("style");
    st.id = "lsTrilingualCss";
    st.textContent =
      ".ls-tr-banner { display:flex; align-items:center; justify-content:space-between; gap:8px; padding:8px 12px; margin-bottom:12px; border-radius:12px; background:#FFFBF0; border:1px solid #E8D5A8; color:#5E1520; font-size:12px; font-weight:700; }" +
      ".ls-dual-card { margin-top:14px; padding:12px 14px; border-radius:14px; background:#FAF7F2; border:1.5px dashed #C7B299; }" +
      ".ls-dual-title { font-size:11.5px; font-weight:800; text-transform:uppercase; letter-spacing:0.4px; color:#7B1E2B; margin-bottom:6px; }" +
      ".ls-dual-body { font-size:12.5px; color:#2C2520; line-height:1.55; }";
    document.head.appendChild(st);
  }

  function readCache(lang, topicId) {
    try {
      var raw = localStorage.getItem(CACHE_PREFIX + lang + "_" + topicId);
      return raw ? JSON.parse(raw) : null;
    } catch (e) { return null; }
  }

  function writeCache(lang, topicId, obj) {
    try {
      localStorage.setItem(CACHE_PREFIX + lang + "_" + topicId, JSON.stringify(obj));
    } catch (e) {}
  }

  async function translateText(text, targetLang) {
    var clean = String(text || "").trim();
    if (!clean) return "";
    var parts = [];
    var remaining = clean;
    while (remaining.length > 900) {
      var cut = remaining.lastIndexOf(". ", 900);
      if (cut < 300) cut = remaining.lastIndexOf(" ", 900);
      if (cut < 200) cut = 900;
      parts.push(remaining.slice(0, cut + 1).trim());
      remaining = remaining.slice(cut + 1).trim();
    }
    if (remaining) parts.push(remaining);

    var outParts = [];
    for (var i = 0; i < parts.length; i++) {
      var url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=" +
        encodeURIComponent(targetLang) + "&dt=t&q=" + encodeURIComponent(parts[i]);
      var r = await fetch(url);
      if (!r.ok) throw new Error("HTTP " + r.status);
      var data = await r.json();
      var seg = "";
      if (Array.isArray(data) && Array.isArray(data[0])) {
        for (var j = 0; j < data[0].length; j++) {
          if (data[0][j] && data[0][j][0]) seg += data[0][j][0];
        }
      }
      outParts.push(seg || parts[i]);
    }
    return outParts.join(" ");
  }

  async function translateField(val, targetLang) {
    if (!val) return val;
    if (typeof val === "string") return await translateText(val, targetLang);
    if (Array.isArray(val)) {
      var arr = [];
      for (var i = 0; i < val.length; i++) {
        if (typeof val[i] === "string") {
          arr.push(await translateText(val[i], targetLang));
        } else if (val[i] && typeof val[i] === "object") {
          var clone = Object.assign({}, val[i]);
          if (clone.summary) clone.summary = await translateText(clone.summary, targetLang);
          if (clone.principle) clone.principle = await translateText(clone.principle, targetLang);
          if (clone.q) clone.q = await translateText(clone.q, targetLang);
          if (clone.a) clone.a = await translateText(clone.a, targetLang);
          arr.push(clone);
        } else {
          arr.push(val[i]);
        }
      }
      return arr;
    }
    return val;
  }

  async function ensureTopicTranslated(topicId, targetLang) {
    if (!topicId || (targetLang !== "hi" && targetLang !== "te")) return;
    if (typeof state === "undefined" || !state.notes || !state.notes[topicId]) return;
    var rec = state.notes[topicId];
    if (rec[targetLang] && rec[targetLang].inOneMinute) return;

    var cached = readCache(targetLang, topicId);
    if (cached && cached.inOneMinute) {
      rec[targetLang] = cached;
      if (typeof window.renderReadingPane === "function") window.renderReadingPane();
      return;
    }

    var key = targetLang + ":" + topicId;
    if (inFlight[key]) return;
    if (!navigator.onLine) return;
    if (!rec.en) return;

    inFlight[key] = true;
    showTranslatingBanner(targetLang, true);
    try {
      var en = rec.en;
      var tr = {
        inOneMinute: await translateField(en.inOneMinute, targetLang),
        legalProvision: await translateField(en.legalProvision, targetLang),
        meaning: await translateField(en.meaning, targetLang),
        keyPoints: await translateField(en.keyPoints, targetLang),
        caseLaws: await translateField(en.caseLaws, targetLang),
        selfTest: await translateField(en.selfTest, targetLang),
        visuals: en.visuals || []
      };
      rec[targetLang] = tr;
      writeCache(targetLang, topicId, tr);
      if (state.activeTopicId === topicId && state.lang === targetLang && typeof window.renderReadingPane === "function") {
        window.renderReadingPane();
      }
    } catch (e) {
      showTranslatingBanner(targetLang, false, "Offline / translation paused - showing English note.");
    } finally {
      delete inFlight[key];
    }
  }

  function showTranslatingBanner(lang, loading, errText) {
    var pane = document.getElementById("readingPane");
    if (!pane) return;
    var old = document.getElementById("lsTrStatusBanner");
    if (old) old.remove();
    var div = document.createElement("div");
    div.id = "lsTrStatusBanner";
    div.className = "ls-tr-banner";
    var lname = lang === "hi" ? "Hindi" : "Telugu";
    div.textContent = loading
      ? ("Preparing " + lname + " medium note & saving offline...")
      : (errText || "");
    if (div.textContent) pane.insertBefore(div, pane.firstChild);
  }

  function localizePaneAndDualView() {
    if (typeof state === "undefined" || !state.activeTopicId) return;
    var lang = state.lang || "en";
    var pane = document.getElementById("readingPane");
    if (!pane) return;

    if (lang === "te" || lang === "hi") {
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

      var rec = state.notes && state.notes[state.activeTopicId];
      if (rec && (!rec[lang] || !rec[lang].inOneMinute)) {
        ensureTopicTranslated(state.activeTopicId, lang);
      }

      var oldDual = document.getElementById("lsDualRefBox");
      if (oldDual) oldDual.remove();
      if (isDualMode() && rec && rec.en && rec[lang]) {
        var box = document.createElement("div");
        box.id = "lsDualRefBox";
        box.className = "ls-dual-card";
        var enProv = rec.en.legalProvision ? ("<p style='margin-bottom:6px;'><strong>Provision:</strong> " + String(rec.en.legalProvision).replace(/</g, "&lt;") + "</p>") : "";
        var enSum = rec.en.inOneMinute ? ("<p><strong>Summary:</strong> " + String(rec.en.inOneMinute).replace(/</g, "&lt;") + "</p>") : "";
        box.innerHTML =
          '<div class="ls-dual-title">Dual-Medium English Exam Reference</div>' +
          '<div class="ls-dual-body">' + enProv + enSum + '</div>';
        pane.appendChild(box);
      }
    }
  }

  function applyMedium(newLang) {
    if (typeof state === "undefined") return;
    var lang = (newLang === "te" || newLang === "hi") ? newLang : "en";
    if (window.LSAudioEngine && typeof window.LSAudioEngine.stop === "function") {
      window.LSAudioEngine.stop();
    } else if (typeof stopAudio === "function") {
      stopAudio();
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

    if (typeof loadVoices === "function") { try { loadVoices(); } catch (e) {} }
    if (typeof window.renderReadingPane === "function") window.renderReadingPane();

    window.dispatchEvent(new CustomEvent("ls:lang-changed", { detail: { lang: lang } }));
    if (typeof showToast === "function") showToast("Switched to " + LABELS[lang].badge);
  }

  function mountSwitcher() {
    injectTrilingualCss();
    var enBtn = document.getElementById("langEnBtn");
    var teBtn = document.getElementById("langTeBtn");
    if (!enBtn || !teBtn) return;

    var host = enBtn.parentElement;
    if (!host || host.__lsTriMounted) return;
    host.__lsTriMounted = true;

    var newEn = enBtn.cloneNode(true);
    var newTe = teBtn.cloneNode(true);
    enBtn.parentNode.replaceChild(newEn, enBtn);
    teBtn.parentNode.replaceChild(newTe, teBtn);

    var hiBtn = document.createElement("button");
    hiBtn.id = "langHiBtn";
    hiBtn.type = "button";
    hiBtn.textContent = "HI";
    hiBtn.title = "Hindi Medium";
    host.appendChild(hiBtn);

    var dualBtn = document.createElement("button");
    dualBtn.id = "langDualBtn";
    dualBtn.type = "button";
    dualBtn.textContent = "Dual";
    dualBtn.title = "Show English Legal Reference alongside Telugu/Hindi";
    dualBtn.style.display = "none";
    host.appendChild(dualBtn);

    newEn.addEventListener("click", function () { applyMedium("en"); });
    newTe.addEventListener("click", function () { applyMedium("te"); });
    hiBtn.addEventListener("click", function () { applyMedium("hi"); });
    dualBtn.addEventListener("click", function () { setDualMode(!isDualMode()); });

    if (typeof window.renderReadingPane === "function" && !window.__lsTriRenderHook) {
      window.__lsTriRenderHook = true;
      var origR = window.renderReadingPane;
      window.renderReadingPane = function () {
        var r = origR.apply(this, arguments);
        try { localizePaneAndDualView(); } catch (e) {}
        return r;
      };
    }

    var saved = getSavedLang();
    setDualMode(isDualMode());
    if (saved !== "en") {
      applyMedium(saved);
    } else {
      newEn.className = "px-2 py-1 rounded-full transition-colors bg-[#7B1E2B] text-white font-bold";
    }
  }

  window.LSTrilingual = {
    setLang: applyMedium,
    getLang: function () { return (typeof state !== "undefined" && state.lang) ? state.lang : getSavedLang(); },
    setDual: setDualMode
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(mountSwitcher, 200);
    setTimeout(mountSwitcher, 1000);
  });
})();