(function () {
  "use strict";
  if (window.__lsSourceDiagramsV311) return;
  window.__lsSourceDiagramsV311 = true;

  var mermaidReady = false;
  var zoomScale = 1;
  var walkTimer = null;

  function injectSourceDiagramCss() {
    if (document.getElementById("lsSourceDiagramCssV311")) return;
    var st = document.createElement("style");
    st.id = "lsSourceDiagramCssV311";
    st.textContent =
      ".ls-src-vis-wrap { margin-top:22px; display:flex; flex-direction:column; gap:14px; }" +
      ".ls-src-vis-card { background:#FFFFFF; border:1px solid #E8E0D5; border-radius:16px; padding:14px; box-shadow:0 2px 10px rgba(31,27,24,0.04); overflow:hidden; }" +
      ".ls-src-vis-head { display:flex; align-items:center; justify-content:space-between; gap:8px; margin-bottom:10px; padding-bottom:8px; border-bottom:1px solid #F3EDE4; }" +
      ".ls-src-vis-box { overflow-x:auto; -webkit-overflow-scrolling:touch; padding:4px 2px; max-width:100%; }" +
      ".ls-src-vis-box figure { margin:0; }" +
      ".ls-src-vis-box figcaption { margin-bottom:10px; font-size:12.5px; color:#3D352E; line-height:1.45; }" +
      ".ls-src-vis-box .dg { margin:0; font-size:12.5px; color:#1F1B18; }" +
      ".ls-src-vis-box .dg-title { display:block; font-weight:800; color:#7B1E2B; font-size:14px; margin-bottom:3px; }" +
      ".ls-src-vis-box .dg-how { display:block; font-size:11.5px; color:#5F554E; margin-bottom:10px; font-weight:500; }" +
      ".ls-src-vis-box .nest { border:2px solid #7B1E2B; border-radius:14px; padding:10px 12px; margin-top:8px; background:#FAF7F2; }" +
      ".ls-src-vis-box .nest.n2, .ls-src-vis-box .nest .nest { border-color:#B45309; background:#FFFBF0; }" +
      ".ls-src-vis-box .nest.n3, .ls-src-vis-box .nest .nest .nest { border-color:#0F766E; background:#F0FDFA; }" +
      ".ls-src-vis-box .nest.n4, .ls-src-vis-box .nest .nest .nest .nest { border-color:#1D4ED8; background:#EFF6FF; }" +
      ".ls-src-vis-box .nest-label { font-weight:800; font-size:12.5px; color:#1F1B18; }" +
      ".ls-src-vis-box .nest-label small { display:block; font-weight:600; color:#7B1E2B; font-size:11px; margin-top:2px; }" +
      ".ls-src-vis-box .dg-time ol, .ls-src-vis-box .dg-steps ol, .ls-src-vis-box .dg-flow ol { list-style:none; padding:0; margin:8px 0 0; display:grid; grid-template-columns:repeat(auto-fit,minmax(145px,1fr)); gap:9px; }" +
      ".ls-src-vis-box .dg-time li, .ls-src-vis-box .dg-steps li, .ls-src-vis-box .dg-flow li { background:#FAF7F2; border:1px solid #E8E0D5; border-left:3.5px solid #7B1E2B; border-radius:10px; padding:9px 10px; font-size:12px; line-height:1.45; }" +
      ".ls-src-vis-box .dg-time li.hi, .ls-src-vis-box .dg-time li.accent { background:#ECFDF5; border-color:#A7F3D0; border-left-color:#059669; }" +
      ".ls-src-vis-box .dg-time .when, .ls-src-vis-box .dg-steps .step-no { display:block; font-weight:800; color:#7B1E2B; font-size:12.5px; margin-bottom:3px; }" +
      ".ls-src-vis-box .dg-grid, .ls-src-vis-box .dg-cols, .ls-src-vis-box .dg-split { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:10px; }" +
      ".ls-src-vis-box .dg-box, .ls-src-vis-box .dg-col, .ls-src-vis-box .dg-card { background:#FAF7F2; border:1px solid #E8E0D5; border-radius:12px; padding:10px 12px; }" +
      ".ls-src-vis-box .mermaid { text-align:center; padding:6px 0; }" +
      ".ls-src-vis-box svg { max-width:100% !important; height:auto !important; display:block; margin:0 auto; }" +
      ".ls-src-vis-box table { width:100%; border-collapse:collapse; font-size:12.5px; min-width:300px; }" +
      ".ls-src-vis-box th { background:#FBF1F2; color:#7B1E2B; text-align:left; padding:8px 10px; border:1px solid #E8D5D8; font-weight:800; }" +
      ".ls-src-vis-box td { padding:8px 10px; border:1px solid #E8E0D5; vertical-align:top; color:#1F1B18; }" +
      ".ls-src-vis-box tr:nth-child(even) td { background:#FAF7F2; }";
    document.head.appendChild(st);
  }

  function isGenuineVisual(v) {
    if (!v || !v.html) return false;
    var h = String(v.html).trim();
    if (!h) return false;
    if (v.type === "svg") {
      if (/height=["']?(1[0-9]|2[0-4])["']?/i.test(h) && /width=["']?(1[0-9]|2[0-4])["']?/i.test(h)) return false;
      if (/viewbox=["']0 0 24 24["']/i.test(h) && h.length < 700) return false;
    }
    return true;
  }

  function dedupeVisuals(list) {
    var out = [];
    var seen = {};
    for (var i = 0; i < list.length; i++) {
      var v = list[i];
      if (!isGenuineVisual(v)) continue;
      var norm = String(v.html)
        .replace(/<[^>]+>/g, " ")
        .replace(/&[a-z#0-9]+;/gi, " ")
        .replace(/\s+/g, " ")
        .trim()
        .toLowerCase()
        .slice(0, 150);
      if (norm && seen[norm]) continue;
      if (norm) seen[norm] = true;
      out.push(v);
    }
    return out;
  }

  function initMermaidOnce() {
    if (mermaidReady || !window.mermaid) return;
    mermaidReady = true;
    try {
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "loose",
        theme: "base",
        themeVariables: {
          primaryColor: "#FBF1F2",
          primaryTextColor: "#1F1B18",
          primaryBorderColor: "#7B1E2B",
          lineColor: "#7B1E2B",
          secondaryColor: "#FFFBF0",
          tertiaryColor: "#FAF7F2",
          fontFamily: "system-ui, -apple-system, sans-serif",
          fontSize: "13px"
        },
        flowchart: { htmlLabels: true, curve: "basis", useMaxWidth: true }
      });
    } catch (e) {}
  }

  function renderMermaidSafe(rootEl) {
    if (!rootEl) return;
    var nodes = rootEl.querySelectorAll(".mermaid");
    if (!nodes.length) return;
    if (!window.mermaid) {
      setTimeout(function () { renderMermaidSafe(rootEl); }, 350);
      return;
    }
    initMermaidOnce();
    nodes.forEach(function (node, idx) {
      if (node.getAttribute("data-processed") === "true") return;
      var src = (node.textContent || "").trim();
      if (!src) return;
      var renderId = "ls_mm_" + Date.now() + "_" + idx + "_" + Math.floor(Math.random() * 1000);
      try {
        var out = window.mermaid.render(renderId, src);
        if (out && typeof out.then === "function") {
          out.then(function (res) {
            if (res && res.svg) {
              node.innerHTML = res.svg;
              node.setAttribute("data-processed", "true");
            }
          }).catch(function () {
            node.setAttribute("data-processed", "error");
          });
        }
      } catch (e) {
        node.setAttribute("data-processed", "error");
      }
    });
  }

  function stopWalk() {
    if (walkTimer) { clearInterval(walkTimer); walkTimer = null; }
    var c = document.getElementById("lsZoomCanvas");
    if (c) {
      c.querySelectorAll(".ls-spotlight-dim, .ls-spotlight-active, .ls-row-flash").forEach(function (el) {
        el.classList.remove("ls-spotlight-dim", "ls-spotlight-active", "ls-row-flash");
      });
    }
  }

  function startWalk() {
    stopWalk();
    var c = document.getElementById("lsZoomCanvas");
    if (!c) return;
    var items = Array.prototype.slice.call(c.querySelectorAll("svg .node, .dg-time li, .dg-steps li, .nest, tbody tr"));
    if (!items.length) return;
    var step = 0;
    items.forEach(function (el) { el.classList.add("ls-spotlight-dim"); });
    function tick() {
      items.forEach(function (el, idx) {
        var on = (idx === step);
        el.classList.toggle("ls-spotlight-active", on);
        el.classList.toggle("ls-spotlight-dim", !on);
        if (el.tagName === "TR") el.classList.toggle("ls-row-flash", on);
      });
      step = (step + 1) % items.length;
    }
    tick();
    walkTimer = setInterval(tick, 1400);
  }

  function openZoom(cardEl, title) {
    try {
      var modal = document.getElementById("lsZoomModal");
      var canvas = document.getElementById("lsZoomCanvas");
      var titleEl = document.getElementById("lsZoomTitle");
      if (!modal || !canvas || !cardEl) return;
      stopWalk();
      zoomScale = 1;
      canvas.style.transform = "scale(1)";
      if (titleEl) titleEl.textContent = title || "Study Diagram";
      var box = cardEl.querySelector(".ls-src-vis-box");
      canvas.innerHTML = box ? box.innerHTML : cardEl.innerHTML;
      modal.classList.remove("hidden");
      renderMermaidSafe(canvas);
    } catch (e) {}
  }

  function wireZoomOnce() {
    var modal = document.getElementById("lsZoomModal");
    if (!modal || modal.__lsDiagV311Wired) return;
    modal.__lsDiagV311Wired = true;
    var canvas = document.getElementById("lsZoomCanvas");
    var bCl = document.getElementById("lsZoomCloseBtn");
    var bIn = document.getElementById("lsZoomInBtn");
    var bOut = document.getElementById("lsZoomOutBtn");
    var bRs = document.getElementById("lsZoomResetBtn");
    var bWk = document.getElementById("lsMemoryPulseBtn");
    if (bCl) bCl.addEventListener("click", function () { stopWalk(); modal.classList.add("hidden"); });
    if (bIn) bIn.addEventListener("click", function () { zoomScale = Math.min(2.4, +(zoomScale + 0.25).toFixed(2)); if (canvas) canvas.style.transform = "scale(" + zoomScale + ")"; });
    if (bOut) bOut.addEventListener("click", function () { zoomScale = Math.max(0.6, +(zoomScale - 0.25).toFixed(2)); if (canvas) canvas.style.transform = "scale(" + zoomScale + ")"; });
    if (bRs) bRs.addEventListener("click", function () { zoomScale = 1; if (canvas) canvas.style.transform = "scale(1)"; });
    if (bWk) bWk.addEventListener("click", startWalk);
    modal.addEventListener("click", function (ev) {
      if (ev.target === modal) { stopWalk(); modal.classList.add("hidden"); }
    });
  }

  function renderSourceDiagrams() {
    try {
      injectSourceDiagramCss();
      wireZoomOnce();
      var pane = document.getElementById("readingPane");
      if (!pane || typeof state === "undefined" || !state.activeTopicId) return;

      ["lsVisualDiagramsSection", "lsSourceVisualsSection"].forEach(function (oldId) {
        var el = document.getElementById(oldId);
        if (el) el.remove();
      });

      var rec = state.notes && state.notes[state.activeTopicId];
      if (!rec) return;
      var active = rec[state.lang] || rec.en;
      var raw = (active && Array.isArray(active.visuals) && active.visuals.length)
        ? active.visuals
        : ((rec.en && Array.isArray(rec.en.visuals)) ? rec.en.visuals : []);
      var visuals = dedupeVisuals(raw);
      if (!visuals.length) return;

      var sec = document.createElement("section");
      sec.id = "lsSourceVisualsSection";
      sec.className = "ls-src-vis-wrap";

      var header = document.createElement("div");
      header.className = "flex items-center justify-between gap-2 px-1";
      header.innerHTML =
        '<div class="text-sm font-extrabold text-[#7B1E2B]">Source Diagrams, Flowcharts &amp; Tables (' + visuals.length + ')</div>' +
        '<span class="text-[10.5px] font-bold px-2 py-0.5 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Offline Ready</span>';
      sec.appendChild(header);

      visuals.forEach(function (v, idx) {
        var card = document.createElement("div");
        card.className = "ls-src-vis-card";
        var cap = String(v.caption || (v.type === "table" ? "Comparison Table" : "Study Diagram " + (idx + 1)));

        var top = document.createElement("div");
        top.className = "ls-src-vis-head";
        top.innerHTML =
          '<div class="text-xs font-bold text-[#7B1E2B] truncate">' + cap.replace(/</g, "&lt;") + '</div>' +
          '<button type="button" class="ls-zoom-btn px-2.5 py-1 rounded-lg bg-[#FAF7F2] border border-[#E8E0D5] text-[11px] font-bold text-[#7B1E2B] shrink-0">Zoom &amp; Walk</button>';

        var box = document.createElement("div");
        box.className = "ls-src-vis-box";
        box.innerHTML = v.html;

        top.querySelector(".ls-zoom-btn").addEventListener("click", function () {
          openZoom(card, cap);
        });

        card.appendChild(top);
        card.appendChild(box);
        sec.appendChild(card);
      });

      pane.appendChild(sec);
      renderMermaidSafe(sec);
    } catch (e) {}
  }

  function hookReadingPane() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsSrcDiagHookV311) {
        window.__lsSrcDiagHookV311 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () {
          var r = orig.apply(this, arguments);
          renderSourceDiagrams();
          return r;
        };
        renderSourceDiagrams();
      }
    } catch (e) {}
  }

  window.LSDiagrams = { render: renderSourceDiagrams };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(hookReadingPane, 300);
    setTimeout(hookReadingPane, 1100);
  });
})();