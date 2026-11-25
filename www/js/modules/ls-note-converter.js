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