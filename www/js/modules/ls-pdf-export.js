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