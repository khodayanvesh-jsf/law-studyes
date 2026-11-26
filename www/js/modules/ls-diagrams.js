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