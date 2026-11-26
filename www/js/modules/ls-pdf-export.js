(function () {
  "use strict";
  if (window.__lsPdfExportV321) return;
  window.__lsPdfExportV321 = true;

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
    var el = document.getElementById("lsDownloadSaveStatus");
    if (el) { el.textContent = msg; el.style.display = "block"; }
    if (typeof showToast === "function") showToast(msg);
  }

  async function saveWithFolderPrompt(content, fileName, mimeType, ext, desc) {
    if (typeof window.showSaveFilePicker === "function") {
      try {
        var opts = { suggestedName: fileName };
        if (ext && mimeType) {
          var acc = {}; acc[mimeType] = ["." + ext.replace(/^\./, "")];
          opts.types = [{ description: desc || "Study Notes", accept: acc }];
        }
        var handle = await window.showSaveFilePicker(opts);
        var w = await handle.createWritable();
        await w.write(content);
        await w.close();
        showSaveStatus("Saved \"" + handle.name + "\" to your selected folder!");
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
          showSaveStatus("Select 'Save as PDF' & pick your folder -> pre-filled filename: \"" + fname + ".pdf\"");
        } catch (err) { saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); }
        finally { setTimeout(function () { document.title = prev; }, 1500); }
      }, 280);
    } catch (e) { document.title = prev; saveWithFolderPrompt(html, fname + ".html", "text/html", "html", "Printable Hard-Copy Study Sheet"); }
  }

  function exportPdf() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, ""); printPdf(wrapA4(fn, buildTopicHtml(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual())), fn); }
  function exportHtml() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, "HardCopy"); saveWithFolderPrompt(wrapA4(fn, buildTopicHtml(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual())), fn + ".html", "text/html", "html", "Printable Study Sheet (.html)"); }
  function exportMd() { var c = ctx(); if (!c) return; var fn = safeTopicName(c.title, c.lang, ""); saveWithFolderPrompt(buildTopicMd(c.tid, c.title, c.subj, c.unitLbl, c.lang, isDual()), fn + ".md", "text/markdown", "md", "Markdown Study Notes (.md)"); }
  function exportUnit() {
    var c = ctx(); if (!c || !c.meta || !c.meta.unit || !Array.isArray(c.meta.unit.topics)) { exportPdf(); return; }
    var secs = c.meta.unit.topics.map(function (t) { return t && t.id ? buildTopicHtml(t.id, t.title || t.id, c.subj, c.unitLbl, c.lang, isDual()) : ""; }).filter(Boolean);
    if (!secs.length) return;
    var fn = safeTopicName(c.subj + "-Unit" + (c.meta.unit.unitNo || "1"), c.lang, "Booklet");
    printPdf(wrapA4(fn, secs.join("")), fn);
  }

  function findMdHost() {
    var els = document.querySelectorAll("button, a");
    for (var i = 0; i < els.length; i++) {
      var b = els[i];
      if (b.id && b.id.indexOf("lsUnifiedDl") === 0) continue;
      var txt = String(b.textContent || "").trim(), meta = String(b.id || "") + " " + String(b.getAttribute("onclick") || "");
      if (/\.(md)\b/i.test(txt) || /markdown/i.test(txt) || /exportmd|downloadmd/i.test(meta)) return { btn: b, box: b.parentElement };
    }
    return null;
  }

  function createUnifiedBar() {
    var b1 = "padding:6px 10px;border-radius:9px;border:1px solid #7B1E2B;background:#7B1E2B;color:#FFF;font-size:11.5px;font-weight:800;cursor:pointer;";
    var b2 = "padding:6px 10px;border-radius:9px;border:1px solid #C7B299;background:#FFF;color:#7B1E2B;font-size:11.5px;font-weight:700;cursor:pointer;";
    var w = document.createElement("div");
    w.id = "lsUnifiedDownloadsWrap";
    w.style.cssText = "display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-top:6px;";
    w.innerHTML =
      '<button type="button" id="lsUnifiedDlPdfBtn" style="' + b1 + '">Download PDF (Hard Copy)</button>' +
      '<button type="button" id="lsUnifiedDlUnitBtn" style="' + b2 + '">Unit PDF Booklet</button>' +
      '<button type="button" id="lsUnifiedDlHtmlBtn" style="' + b2 + '">Save Print File (.html)</button>' +
      '<button type="button" id="lsUnifiedDlMdBtn" style="' + b2 + '">Save .md (Choose Folder)</button>' +
      '<div id="lsDownloadSaveStatus" style="display:none;width:100%;margin-top:4px;padding:6px 8px;border-radius:8px;background:#EEF7EE;border:1px solid #B7DDB9;color:#1F5C24;font-size:11px;font-weight:700;"></div>';
    w.querySelector("#lsUnifiedDlPdfBtn").addEventListener("click", exportPdf);
    w.querySelector("#lsUnifiedDlUnitBtn").addEventListener("click", exportUnit);
    w.querySelector("#lsUnifiedDlHtmlBtn").addEventListener("click", exportHtml);
    w.querySelector("#lsUnifiedDlMdBtn").addEventListener("click", exportMd);
    return w;
  }

  function mountInMdWindow() {
    try {
      ["lsPdfTopicBtn", "lsPdfUnitBtn", "lsPdfXeroxBtn"].forEach(function (id) { var x = document.getElementById(id); if (x) x.remove(); });
      var found = findMdHost();
      if (found && found.box) {
        if (found.btn && !found.btn.__lsMdSaveAsBound) {
          found.btn.__lsMdSaveAsBound = true;
          found.btn.addEventListener("click", function (ev) {
            if (typeof state !== "undefined" && state.activeTopicId) { ev.preventDefault(); ev.stopImmediatePropagation(); exportMd(); }
          }, true);
        }
        if (!found.box.querySelector("#lsUnifiedDownloadsWrap")) {
          var prev = document.getElementById("lsUnifiedDownloadsWrap"); if (prev) prev.remove();
          found.box.appendChild(createUnifiedBar());
        }
        return;
      }
      var pane = document.getElementById("readingPane");
      if (!pane || typeof state === "undefined" || !state.activeTopicId || document.getElementById("lsUnifiedDownloadsWrap")) return;
      var bar = document.getElementById("lsNoteCopyBar");
      if (!bar) {
        bar = document.createElement("div"); bar.id = "lsNoteCopyBar";
        bar.style.cssText = "display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin-bottom:12px;padding:8px 10px;border-radius:12px;background:#FAF7F2;border:1px solid #E8E0D5;";
        pane.insertBefore(bar, pane.firstChild);
      }
      bar.appendChild(createUnifiedBar());
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsPdfHookV321) {
        window.__lsPdfHookV321 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () { var r = orig.apply(this, arguments); setTimeout(mountInMdWindow, 40); return r; };
      }
      mountInMdWindow();
      if (!window.__lsDlObsV321 && typeof MutationObserver !== "undefined" && document.body) {
        window.__lsDlObsV321 = true;
        new MutationObserver(mountInMdWindow).observe(document.body, { childList: true, subtree: true });
      }
    } catch (e) {}
  }

  window.LSPdfExport = { exportTopic: exportPdf, exportUnit: exportUnit, exportHtml: exportHtml, exportMd: exportMd, safeTopicName: safeTopicName };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(hook, 350); setTimeout(hook, 1200); });
})();