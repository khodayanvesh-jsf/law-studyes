(function () {
  "use strict";
  if (window.__lsDiagramsRestoredV308) return;
  window.__lsDiagramsRestoredV308 = true;

  var mermaidInited = false;
  var zoomScale = 1;
  var walkTimer = null;

  function injectDiagramStyles() {
    if (document.getElementById("lsDiagramsExtraCss")) return;
    var st = document.createElement("style");
    st.id = "lsDiagramsExtraCss";
    st.textContent =
      ".ls-visual-card { background:#FFFFFF; border:1px solid #E8E0D5; border-radius:16px; padding:14px; margin-bottom:14px; box-shadow:0 2px 10px rgba(31,27,24,0.04); overflow:hidden; }" +
      ".ls-visual-box { overflow-x:auto; -webkit-overflow-scrolling:touch; padding:6px 2px; }" +
      ".ls-visual-box .dg { margin:0; font-size:12.5px; color:#1F1B18; }" +
      ".ls-visual-box .dg-title { display:block; font-weight:800; color:#7B1E2B; font-size:13.5px; margin-bottom:3px; }" +
      ".ls-visual-box .dg-how { display:block; font-size:11.5px; color:#5F554E; margin-bottom:10px; font-weight:500; }" +
      ".ls-visual-box .nest { border:2px solid #7B1E2B; border-radius:14px; padding:10px 12px; margin-top:8px; background:#FAF7F2; }" +
      ".ls-visual-box .nest .nest { border-color:#B45309; background:#FFFBF0; }" +
      ".ls-visual-box .nest .nest .nest { border-color:#0F766E; background:#F0FDFA; }" +
      ".ls-visual-box .nest-label { font-weight:700; font-size:12px; color:#1F1B18; }" +
      ".ls-visual-box .nest-label small { display:block; font-weight:600; color:#7B1E2B; font-size:10.5px; margin-top:2px; }" +
      ".ls-visual-box .dg-time ol { list-style:none; padding:0; margin:8px 0 0; display:grid; grid-template-columns:repeat(auto-fit,minmax(130px,1fr)); gap:8px; }" +
      ".ls-visual-box .dg-time li { background:#FAF7F2; border:1px solid #E8E0D5; border-left:3px solid #7B1E2B; border-radius:10px; padding:8px 10px; font-size:11.5px; line-height:1.4; }" +
      ".ls-visual-box .dg-time .when { display:block; font-weight:800; color:#7B1E2B; font-size:12px; margin-bottom:2px; }" +
      ".ls-visual-box .mermaid { text-align:center; }";
    document.head.appendChild(st);
  }

  function isRealVisual(v) {
    if (!v || !v.html) return false;
    var h = String(v.html);
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
      if (!isRealVisual(v)) continue;
      var norm = String(v.html).replace(/<[^>]+>/g, " ").replace(/&[a-z#0-9]+;/gi, " ").replace(/\s+/g, " ").trim().toLowerCase().slice(0, 140);
      if (norm && seen[norm]) continue;
      if (norm) seen[norm] = true;
      out.push(v);
    }
    return out;
  }

  function initMermaidOnce() {
    if (mermaidInited || !window.mermaid) return;
    mermaidInited = true;
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

  function renderMermaidNodes(container) {
    if (!container) return;
    var nodes = container.querySelectorAll(".mermaid");
    if (!nodes.length) return;
    if (!window.mermaid) {
      setTimeout(function () { renderMermaidNodes(container); }, 400);
      return;
    }
    initMermaidOnce();
    nodes.forEach(function (node, idx) {
      if (node.getAttribute("data-processed") === "true") return;
      var src = (node.textContent || "").trim();
      if (!src) return;
      var renderId = "ls_mm_" + Date.now() + "_" + idx;
      try {
        var res = window.mermaid.render(renderId, src);
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

  function stopMemoryWalk() {
    if (walkTimer) { clearInterval(walkTimer); walkTimer = null; }
    var canvas = document.getElementById("lsZoomCanvas");
    if (canvas) {
      canvas.querySelectorAll(".ls-spotlight-dim, .ls-spotlight-active, .ls-row-flash").forEach(function (el) {
        el.classList.remove("ls-spotlight-dim", "ls-spotlight-active", "ls-row-flash");
      });
    }
  }

  function startMemoryWalk() {
    stopMemoryWalk();
    var canvas = document.getElementById("lsZoomCanvas");
    if (!canvas) return;
    var items = Array.prototype.slice.call(canvas.querySelectorAll("svg .node, .dg-time li, .nest, tbody tr"));
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

  function openZoomForCard(cardEl, title) {
    var modal = document.getElementById("lsZoomModal");
    var canvas = document.getElementById("lsZoomCanvas");
    var titleEl = document.getElementById("lsZoomTitle");
    if (!modal || !canvas || !cardEl) return;
    stopMemoryWalk();
    zoomScale = 1;
    canvas.style.transform = "scale(1)";
    if (titleEl) titleEl.textContent = title || "Study Diagram";
    var box = cardEl.querySelector(".ls-visual-box");
    canvas.innerHTML = box ? box.innerHTML : cardEl.innerHTML;
    modal.classList.remove("hidden");
  }

  function wireZoomModalOnce() {
    var modal = document.getElementById("lsZoomModal");
    if (!modal || modal.__lsZoomWired) return;
    modal.__lsZoomWired = true;
    var canvas = document.getElementById("lsZoomCanvas");
    var btnClose = document.getElementById("lsZoomCloseBtn");
    var btnIn = document.getElementById("lsZoomInBtn");
    var btnOut = document.getElementById("lsZoomOutBtn");
    var btnReset = document.getElementById("lsZoomResetBtn");
    var btnWalk = document.getElementById("lsMemoryPulseBtn");
    if (btnClose) btnClose.addEventListener("click", function () { stopMemoryWalk(); modal.classList.add("hidden"); });
    if (btnIn) btnIn.addEventListener("click", function () { zoomScale = Math.min(2.4, +(zoomScale + 0.25).toFixed(2)); if (canvas) canvas.style.transform = "scale(" + zoomScale + ")"; });
    if (btnOut) btnOut.addEventListener("click", function () { zoomScale = Math.max(0.6, +(zoomScale - 0.25).toFixed(2)); if (canvas) canvas.style.transform = "scale(" + zoomScale + ")"; });
    if (btnReset) btnReset.addEventListener("click", function () { zoomScale = 1; if (canvas) canvas.style.transform = "scale(1)"; });
    if (btnWalk) btnWalk.addEventListener("click", startMemoryWalk);
    modal.addEventListener("click", function (ev) {
      if (ev.target === modal) { stopMemoryWalk(); modal.classList.add("hidden"); }
    });
  }

  function renderVisualDiagramsForActiveTopic() {
    injectDiagramStyles();
    wireZoomModalOnce();
    var pane = document.getElementById("readingPane");
    if (!pane || typeof state === "undefined" || !state.activeTopicId) return;

    var oldSec = document.getElementById("lsVisualDiagramsSection");
    if (oldSec) oldSec.remove();

    var rec = state.notes && state.notes[state.activeTopicId];
    if (!rec) return;
    var ld = rec[state.lang] || rec.en;
    var rawVis = (ld && Array.isArray(ld.visuals) && ld.visuals.length) ? ld.visuals : ((rec.en && Array.isArray(rec.en.visuals)) ? rec.en.visuals : []);
    var visuals = dedupeVisuals(rawVis);
    if (!visuals.length) return;

    var sec = document.createElement("section");
    sec.id = "lsVisualDiagramsSection";
    sec.className = "mt-6 space-y-3";

    var header = document.createElement("div");
    header.className = "flex items-center justify-between gap-2 px-1";
    header.innerHTML =
      '<div class="text-sm font-extrabold text-[#7B1E2B]">Visual Flowcharts, Diagrams &amp; Tables (' + visuals.length + ')</div>' +
      '<span class="text-[10.5px] font-bold px-2 py-0.5 rounded-full bg-[#FBF1F2] text-[#7B1E2B]">Offline Ready</span>';
    sec.appendChild(header);

    visuals.forEach(function (v, idx) {
      var card = document.createElement("div");
      card.className = "ls-visual-card";
      var cap = String(v.caption || (v.type === "table" ? "Comparison Table" : "Study Diagram " + (idx + 1)));

      var topBar = document.createElement("div");
      topBar.className = "flex items-center justify-between gap-2 mb-2 pb-1.5 border-b border-[#F3EDE4]";
      topBar.innerHTML =
        '<div class="text-xs font-bold text-[#7B1E2B] truncate">' + cap.replace(/</g, "&lt;") + '</div>' +
        '<button type="button" class="ls-zoom-open-btn px-2.5 py-1 rounded-lg bg-[#FAF7F2] border border-[#E8E0D5] text-[11px] font-bold text-[#7B1E2B] shrink-0">Zoom &amp; Walk</button>';

      var box = document.createElement("div");
      box.className = "ls-visual-box";
      box.innerHTML = v.html;

      topBar.querySelector(".ls-zoom-open-btn").addEventListener("click", function () {
        openZoomForCard(card, cap);
      });

      card.appendChild(topBar);
      card.appendChild(box);
      sec.appendChild(card);
    });

    pane.appendChild(sec);
    renderMermaidNodes(sec);
  }

  function hookReadingPane() {
    if (typeof window.renderReadingPane === "function" && !window.__lsDiagramsHooked) {
      window.__lsDiagramsHooked = true;
      var orig = window.renderReadingPane;
      window.renderReadingPane = function () {
        var r = orig.apply(this, arguments);
        try { renderVisualDiagramsForActiveTopic(); } catch (e) {}
        return r;
      };
      renderVisualDiagramsForActiveTopic();
    }
  }

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(hookReadingPane, 300);
    setTimeout(hookReadingPane, 1100);
  });
  window.LSDiagrams = { render: renderVisualDiagramsForActiveTopic };
})();