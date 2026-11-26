(function () {
  "use strict";
  if (window.__lsPdfExportV320) return;
  window.__lsPdfExportV320 = true;

  var LABELS = {
    en: {
      medium: "English Medium",
      oneMin: "In One Minute",
      prov: "Legal Provision",
      meaning: "Meaning & Definition",
      points: "Key Scoring Points",
      cases: "Leading Case Laws",
      selfTest: "Exam Self-Test",
      diagrams: "Original Diagrams & Reference Tables"
    },
    te: {
      medium: "\u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c2e\u0c40\u0c21\u0c3f\u0c2f\u0c02 (Telugu Medium)",
      oneMin: "\u0c12\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b",
      prov: "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28",
      meaning: "\u0c05\u0c30\u0c4d\u0c25\u0c02 & \u0c28\u0c3f\u0c30\u0c4d\u0c35\u0c1a\u0c28\u0c02",
      points: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c05\u0c02\u0c36\u0c3e\u0c32\u0c41",
      cases: "\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c41\u0c32\u0c41",
      selfTest: "\u0c38\u0c4d\u0c35\u0c2f\u0c02 \u0c2a\u0c30\u0c40\u0c15\u0c4d\u0c37",
      diagrams: "\u0c05\u0c38\u0c32\u0c41 \u0c21\u0c2f\u0c3e\u0c17\u0c4d\u0c30\u0c2e\u0c4d\u200c\u0c32\u0c41 & \u0c1f\u0c47\u0c2c\u0c41\u0c33\u0c4d\u0c32\u0c41 (Source Copy)"
    },
    hi: {
      medium: "\u0939\u093f\u0928\u094d\u0926\u0940 \u092e\u093e\u0927\u094d\u092f\u092e (Hindi Medium)",
      oneMin: "\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902",
      prov: "\u0935\u093f\u0927\u093f\u0915 \u092a\u094d\u0930\u093e\u0935\u0927\u093e\u0928",
      meaning: "\u0905\u0930\u094d\u0925 \u0914\u0930 \u092a\u0930\u093f\u092d\u093e\u0937\u093e",
      points: "\u092e\u0941\u0916\u094d\u092f \u092c\u093f\u0902\u0926\u0941",
      cases: "\u092a\u094d\u0930\u092e\u0941\u0916 \u0928\u094d\u092f\u093e\u092f\u093f\u0915 \u0928\u093f\u0930\u094d\u0923\u092f",
      selfTest: "\u0938\u094d\u0935-\u092a\u0930\u0940\u0915\u094d\u0937\u0923",
      diagrams: "\u092e\u0942\u0932 \u0906\u0930\u0947\u0916 \u0914\u0930 \u0924\u093e\u0932\u093f\u0915\u093e\u090f\u0902 (Source Copy)"
    }
  };

  function esc(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function safeFilename(name) {
    return String(name || "LawStudyes-Notes")
      .replace(/[^a-zA-Z0-9\-_]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 72) || "LawStudyes-Notes";
  }

  function isDualActive() {
    try { return localStorage.getItem("ls_dual_mode_v1") === "1"; } catch (e) { return false; }
  }

  function getRenderedVisualsHtml(topicId, rec) {
    try {
      if (typeof state !== "undefined" && state.activeTopicId === topicId) {
        var liveSec = document.getElementById("lsAsIsDiagramsSection") || document.getElementById("lsSourceVisualsSection");
        if (liveSec) {
          var cards = liveSec.querySelectorAll(".ls-asis-card, .ls-src-vis-card");
          if (cards && cards.length) {
            var chunks = [];
            cards.forEach(function (c) {
              var capEl = c.querySelector(".ls-asis-head div, .ls-src-vis-head div");
              var stage = c.querySelector(".ls-asis-stage, .ls-src-vis-box");
              if (stage && stage.innerHTML.trim()) {
                var cap = capEl ? capEl.textContent : "Source Diagram";
                chunks.push('<div class="pdf-vis-card"><div class="pdf-vis-cap">' + esc(cap) + '</div><div class="pdf-vis-stage">' + stage.innerHTML + '</div></div>');
              }
            });
            if (chunks.length) return chunks.join("");
          }
        }
      }
    } catch (e) {}

    var vis = (rec && rec.en && Array.isArray(rec.en.visuals)) ? rec.en.visuals : [];
    var out = [];
    for (var i = 0; i < vis.length; i++) {
      var v = vis[i];
      if (!v || !v.html) continue;
      var h = String(v.html).trim();
      if (v.type === "svg" && /viewbox=["']0 0 24 24["']/i.test(h) && h.length < 700) continue;
      var cap = String(v.caption || (v.type === "table" ? "Reference Table" : "Source Diagram " + (i + 1)));
      out.push('<div class="pdf-vis-card"><div class="pdf-vis-cap">' + esc(cap) + '</div><div class="pdf-vis-stage">' + h + '</div></div>');
    }
    return out.join("");
  }

  function buildTopicSectionHtml(topicId, title, subjectName, unitLabel, lang, includeDual) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[topicId] : null;
    if (!rec) return "";
    var ld = rec[lang] || rec.en;
    if (!ld) return "";
    var lbl = LABELS[lang] || LABELS.en;

    var parts = [];
    parts.push('<article class="pdf-topic">');
    parts.push('<div class="pdf-meta">' + esc(subjectName || "3-Year LL.B.") + (unitLabel ? " &middot; " + esc(unitLabel) : "") + ' &middot; ' + esc(lbl.medium) + '</div>');
    parts.push('<h1 class="pdf-title">' + esc(title || topicId) + '</h1>');

    if (ld.inOneMinute) {
      parts.push('<div class="pdf-box highlight"><h2>' + esc(lbl.oneMin) + '</h2><p>' + esc(ld.inOneMinute) + '</p></div>');
    }
    if (ld.legalProvision) {
      parts.push('<div class="pdf-box"><h2>' + esc(lbl.prov) + '</h2><p>' + esc(ld.legalProvision) + '</p></div>');
    }
    if (ld.meaning) {
      parts.push('<div class="pdf-box"><h2>' + esc(lbl.meaning) + '</h2><p>' + esc(ld.meaning) + '</p></div>');
    }
    if (Array.isArray(ld.keyPoints) && ld.keyPoints.length) {
      var lis = ld.keyPoints.map(function (pt) {
        var t = typeof pt === "string" ? pt : (pt && (pt.point || pt.text || pt.summary) ? (pt.point || pt.text || pt.summary) : JSON.stringify(pt));
        return '<li>' + esc(t) + '</li>';
      }).join("");
      parts.push('<div class="pdf-box"><h2>' + esc(lbl.points) + '</h2><ul>' + lis + '</ul></div>');
    }
    if (Array.isArray(ld.caseLaws) && ld.caseLaws.length) {
      var casesHtml = ld.caseLaws.map(function (c) {
        if (typeof c === "string") return '<li>' + esc(c) + '</li>';
        if (!c || typeof c !== "object") return "";
        var nm = c.name || c.title || "";
        var yr = c.citation || c.year || "";
        var pr = c.principle || c.summary || "";
        return '<li><strong>' + esc(nm) + (yr ? " (" + esc(yr) + ")" : "") + '</strong>' + (pr ? ": " + esc(pr) : "") + '</li>';
      }).join("");
      parts.push('<div class="pdf-box"><h2>' + esc(lbl.cases) + '</h2><ul>' + casesHtml + '</ul></div>');
    }
    if (Array.isArray(ld.selfTest) && ld.selfTest.length) {
      var qs = ld.selfTest.map(function (q, idx) {
        if (typeof q === "string") return '<li>' + esc(q) + '</li>';
        if (!q || typeof q !== "object") return "";
        var qt = q.q || q.question || "";
        var ans = q.a || q.answer || "";
        return '<li><strong>Q' + (idx + 1) + ':</strong> ' + esc(qt) + (ans ? '<div class="pdf-ans"><em>Ans:</em> ' + esc(ans) + '</div>' : '') + '</li>';
      }).join("");
      parts.push('<div class="pdf-box"><h2>' + esc(lbl.selfTest) + '</h2><ol>' + qs + '</ol></div>');
    }

    if (includeDual && lang !== "en" && rec.en) {
      parts.push('<div class="pdf-box dual"><h2>Dual-Medium English Exam Reference</h2>');
      if (rec.en.legalProvision) parts.push('<p><strong>Provision:</strong> ' + esc(rec.en.legalProvision) + '</p>');
      if (rec.en.inOneMinute) parts.push('<p><strong>Summary:</strong> ' + esc(rec.en.inOneMinute) + '</p>');
      parts.push('</div>');
    }

    var visHtml = getRenderedVisualsHtml(topicId, rec);
    if (visHtml) {
      parts.push('<div class="pdf-vis-wrap"><h2>' + esc(lbl.diagrams) + '</h2>' + visHtml + '</div>');
    }
    parts.push('</article>');
    return parts.join("");
  }

  function wrapA4Document(docTitle, bodyHtml) {
    var dateStr = new Date().toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
    return '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8" />' +
      '<meta name="viewport" content="width=device-width,initial-scale=1.0" />' +
      '<title>' + esc(docTitle) + ' - Law Studyes Hard Copy</title>' +
      '<style>' +
      '@page { size: A4; margin: 14mm 13mm; }' +
      '* { box-sizing: border-box; }' +
      'body { font-family: "Noto Sans Telugu","Noto Sans Devanagari","Nirmala UI","Segoe UI",Roboto,Arial,sans-serif; color:#1A1715; background:#FFFFFF; margin:0; padding:18px; line-height:1.58; font-size:12.5px; }' +
      '.pdf-toolbar { position:sticky; top:0; z-index:99; display:flex; align-items:center; justify-content:space-between; gap:10px; padding:10px 14px; margin-bottom:16px; background:#7B1E2B; color:#FFF; border-radius:10px; }' +
      '.pdf-toolbar button { padding:7px 14px; border:0; border-radius:8px; background:#FFF; color:#7B1E2B; font-weight:800; font-size:12.5px; cursor:pointer; }' +
      '.pdf-header { display:flex; justify-content:space-between; align-items:flex-end; border-bottom:2px solid #7B1E2B; padding-bottom:8px; margin-bottom:16px; }' +
      '.pdf-brand { font-family:Georgia,serif; font-size:20px; font-weight:800; color:#7B1E2B; }' +
      '.pdf-date { font-size:11px; color:#5F554E; text-align:right; }' +
      '.pdf-topic { page-break-after: always; margin-bottom:18px; }' +
      '.pdf-topic:last-child { page-break-after: auto; }' +
      '.pdf-meta { font-size:11px; font-weight:700; color:#8C6D46; text-transform:uppercase; letter-spacing:0.35px; margin-bottom:4px; }' +
      '.pdf-title { font-family:Georgia,serif; font-size:19px; color:#7B1E2B; margin:0 0 12px; }' +
      '.pdf-box { border:1px solid #E4DBD0; border-radius:8px; padding:10px 12px; margin-bottom:10px; break-inside:avoid; }' +
      '.pdf-box.highlight { background:#FBF6EE; border-color:#DFC5A4; }' +
      '.pdf-box.dual { background:#FAF7F2; border:1.5px dashed #B89D7A; }' +
      '.pdf-box h2, .pdf-vis-wrap > h2 { font-size:13px; color:#7B1E2B; margin:0 0 6px; padding-bottom:3px; border-bottom:1px solid #EFE7DC; }' +
      '.pdf-box p { margin:4px 0; }' +
      '.pdf-box ul, .pdf-box ol { margin:4px 0 2px; padding-left:18px; }' +
      '.pdf-box li { margin-bottom:4px; }' +
      '.pdf-ans { margin-top:2px; color:#4A423C; font-size:11.5px; }' +
      '.pdf-vis-wrap { margin-top:12px; }' +
      '.pdf-vis-card { border:1px solid #DDD2C5; border-radius:8px; padding:10px; margin-bottom:10px; break-inside:avoid; }' +
      '.pdf-vis-cap { font-size:11.5px; font-weight:800; color:#7B1E2B; margin-bottom:6px; }' +
      '.pdf-vis-stage svg, .pdf-vis-stage img { max-width:100% !important; height:auto !important; display:block; margin:0 auto; }' +
      '.pdf-vis-stage table { width:100%; border-collapse:collapse; font-size:11.5px; }' +
      '.pdf-vis-stage th { background:#FBF1F2; color:#7B1E2B; border:1px solid #DFC9CC; padding:6px 8px; text-align:left; }' +
      '.pdf-vis-stage td { border:1px solid #E4DBD0; padding:6px 8px; vertical-align:top; }' +
      '.pdf-footer { margin-top:18px; padding-top:8px; border-top:1px solid #E4DBD0; font-size:10.5px; color:#6B5E54; text-align:center; }' +
      '@media print { body { padding:0; } .pdf-toolbar { display:none !important; } }' +
      '</style></head><body>' +
      '<div class="pdf-toolbar"><span><strong>Law Studyes</strong> &middot; A4 Hard-Copy Study Sheet</span><button onclick="window.print()">Print / Save as PDF</button></div>' +
      '<div class="pdf-header"><div class="pdf-brand">&#9878; Law Studyes</div><div class="pdf-date">3-Year LL.B. Hard-Copy Notes<br/>Generated: ' + esc(dateStr) + '</div></div>' +
      bodyHtml +
      '<div class="pdf-footer">Law Studyes &middot; Free 3-Year LL.B. Trilingual Notes (EN / TE / HI) &middot; https://law-studyes.vercel.app</div>' +
      '</body></html>';
  }

  function printA4Document(htmlText, fileBaseName) {
    try {
      var isNativeCap = !!(window.Capacitor && typeof window.Capacitor.isNativePlatform === "function" && window.Capacitor.isNativePlatform());
      if (isNativeCap) {
        exportPrintableFile(htmlText, fileBaseName, true);
        return;
      }

      var oldFrame = document.getElementById("lsPdfPrintFrame");
      if (oldFrame) oldFrame.remove();

      var iframe = document.createElement("iframe");
      iframe.id = "lsPdfPrintFrame";
      iframe.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden;";
      document.body.appendChild(iframe);

      var idoc = iframe.contentWindow.document;
      idoc.open();
      idoc.write(htmlText);
      idoc.close();

      setTimeout(function () {
        try {
          iframe.contentWindow.focus();
          iframe.contentWindow.print();
          if (typeof showToast === "function") showToast("Select 'Save as PDF' or your printer in the dialog.");
        } catch (err) {
          exportPrintableFile(htmlText, fileBaseName, false);
        }
      }, 320);
    } catch (e) {
      exportPrintableFile(htmlText, fileBaseName, false);
    }
  }

  async function exportPrintableFile(htmlText, fileBaseName, tryShare) {
    var fname = safeFilename(fileBaseName) + "-A4-Print.html";
    try {
      var capFs = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Filesystem;
      var capShare = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Share;
      if (tryShare && capFs && typeof capFs.writeFile === "function") {
        var b64 = btoa(unescape(encodeURIComponent(htmlText)));
        var written = await capFs.writeFile({ path: fname, data: b64, directory: "CACHE" });
        if (capShare && typeof capShare.share === "function" && written && written.uri) {
          await capShare.share({
            title: fileBaseName + " (A4 Hard Copy)",
            text: "Open in Chrome and tap Print -> Save as PDF for hard-copy study.",
            url: written.uri
          });
          return;
        }
      }
    } catch (e) {}

    try {
      var blob = new Blob([htmlText], { type: "text/html;charset=utf-8" });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url;
      a.download = fname;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(function () { try { URL.revokeObjectURL(url); } catch (e) {} }, 2500);
      if (typeof showToast === "function") showToast("Downloaded " + fname + " (Open in Chrome -> Print -> Save as PDF)");
    } catch (e) {
      try { window.print(); } catch (err) {}
    }
  }

  function exportCurrentTopic(asFileOnly) {
    if (typeof state === "undefined" || !state.activeTopicId) return;
    var tid = state.activeTopicId;
    var lang = state.lang || "en";
    var meta = (typeof findTopicMeta === "function") ? findTopicMeta(tid) : null;
    var title = (meta && meta.topic && meta.topic.title) || tid;
    var subj = (meta && meta.subject && meta.subject.title) || "3-Year LL.B.";
    var unitLbl = (meta && meta.unit) ? ("Unit " + (meta.unit.unitNo || "") + (meta.unit.title ? ": " + meta.unit.title : "")) : "";

    var body = buildTopicSectionHtml(tid, title, subj, unitLbl, lang, isDualActive());
    var html = wrapA4Document(title + " (" + lang.toUpperCase() + ")", body);
    var fname = "LawStudyes-" + title + "-" + lang.toUpperCase();
    if (asFileOnly) exportPrintableFile(html, fname, true);
    else printA4Document(html, fname);
  }

  function exportCurrentUnitBooklet() {
    if (typeof state === "undefined" || !state.activeTopicId) return;
    var lang = state.lang || "en";
    var meta = (typeof findTopicMeta === "function") ? findTopicMeta(state.activeTopicId) : null;
    if (!meta || !meta.unit || !Array.isArray(meta.unit.topics) || !meta.unit.topics.length) {
      exportCurrentTopic(false);
      return;
    }
    var subj = (meta.subject && meta.subject.title) || "3-Year LL.B.";
    var unitLbl = "Unit " + (meta.unit.unitNo || "") + (meta.unit.title ? ": " + meta.unit.title : "");
    var sections = [];
    meta.unit.topics.forEach(function (t) {
      if (t && t.id) {
        sections.push(buildTopicSectionHtml(t.id, t.title || t.id, subj, unitLbl, lang, isDualActive()));
      }
    });
    if (!sections.length) return;
    var html = wrapA4Document(subj + " - " + unitLbl + " (" + lang.toUpperCase() + ")", sections.join(""));
    printA4Document(html, "LawStudyes-" + subj + "-Unit" + (meta.unit.unitNo || "1") + "-" + lang.toUpperCase());
  }

  function renderPdfButtons() {
    try {
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane");
      if (!pane) return;

      var bar = document.getElementById("lsNoteCopyBar");
      if (!bar) {
        bar = document.createElement("div");
        bar.id = "lsNoteCopyBar";
        bar.style.cssText = "display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:12px;padding:8px 10px;border-radius:12px;background:#FAF7F2;border:1px solid #E8E0D5;";
        pane.insertBefore(bar, pane.firstChild);
      }

      ["lsPdfTopicBtn", "lsPdfUnitBtn", "lsPdfXeroxBtn"].forEach(function (id) {
        var old = document.getElementById(id);
        if (old) old.remove();
      });

      var btnCss = "padding:6px 10px;border-radius:9px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFFFFF;font-size:11.5px;font-weight:800;cursor:pointer;";
      var altCss = "padding:6px 10px;border-radius:9px;border:1px solid #C7B299;background:#FFFFFF;color:#7B1E2B;font-size:11.5px;font-weight:700;cursor:pointer;";

      var bPdf = document.createElement("button");
      bPdf.id = "lsPdfTopicBtn";
      bPdf.type = "button";
      bPdf.style.cssText = btnCss;
      bPdf.textContent = "Download PDF (Hard Copy)";
      bPdf.addEventListener("click", function () { exportCurrentTopic(false); });
      bar.appendChild(bPdf);

      var bUnit = document.createElement("button");
      bUnit.id = "lsPdfUnitBtn";
      bUnit.type = "button";
      bUnit.style.cssText = altCss;
      bUnit.textContent = "Unit PDF Booklet";
      bUnit.addEventListener("click", exportCurrentUnitBooklet);
      bar.appendChild(bUnit);

      var bXerox = document.createElement("button");
      bXerox.id = "lsPdfXeroxBtn";
      bXerox.type = "button";
      bXerox.style.cssText = altCss;
      bXerox.textContent = "Save Print File";
      bXerox.title = "Save self-contained A4 print file for Xerox shop or WhatsApp";
      bXerox.addEventListener("click", function () { exportCurrentTopic(true); });
      bar.appendChild(bXerox);
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsPdfHookV320) {
        window.__lsPdfHookV320 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () {
          var r = orig.apply(this, arguments);
          setTimeout(renderPdfButtons, 20);
          return r;
        };
        setTimeout(renderPdfButtons, 40);
      }
    } catch (e) {}
  }

  window.LSPdfExport = {
    exportTopic: exportCurrentTopic,
    exportUnit: exportCurrentUnitBooklet
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(hook, 450);
    setTimeout(hook, 1300);
  });
})();