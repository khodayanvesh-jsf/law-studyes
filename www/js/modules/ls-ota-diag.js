(function () {
  "use strict";
  if (window.__lsOtaDiagV307) return;
  window.__lsOtaDiagV307 = true;

  window.__lsOtaDiagLog = window.__lsOtaDiagLog || [];
  function pushDiag(msg) {
    var ts = new Date().toLocaleTimeString();
    window.__lsOtaDiagLog.push("[" + ts + "] " + msg);
    if (window.__lsOtaDiagLog.length > 80) window.__lsOtaDiagLog.shift();
  }
  window.__lsPushOtaDiag = pushDiag;

  function ensureDiagModal() {
    if (!document.getElementById("lsOtaDiagStyle")) {
      var st = document.createElement("style");
      st.id = "lsOtaDiagStyle";
      st.textContent =
        "#lsOtaBannerDiag { display:none; background:#FAD676; color:#56111B; border:none; border-radius:6px; padding:3px 9px; font-size:11px; font-weight:800; cursor:pointer; flex-shrink:0; }" +
        "#lsOtaBannerDiag.show { display:inline-block; }" +
        "#lsOtaDiagModal { position:fixed; inset:0; z-index:10090; background:rgba(20,14,12,0.62); backdrop-filter:blur(3px); display:none; align-items:center; justify-content:center; padding:14px; }" +
        "#lsOtaDiagModal.show { display:flex; }" +
        "#lsOtaDiagCard { background:#FFFFFF; width:100%; max-width:500px; max-height:86vh; border-radius:20px; padding:16px; display:flex; flex-direction:column; gap:10px; box-shadow:0 20px 44px rgba(0,0,0,0.3); }" +
        "#lsOtaDiagPre { background:#181412; color:#F5EFE6; font-family:monospace; font-size:11px; line-height:1.45; padding:12px; border-radius:12px; overflow:auto; max-height:52vh; white-space:pre-wrap; word-break:break-word; margin:0; }";
      document.head.appendChild(st);
    }

    var closeBtn = document.getElementById("lsOtaBannerClose");
    if (closeBtn && !document.getElementById("lsOtaBannerDiag")) {
      var dBtn = document.createElement("button");
      dBtn.id = "lsOtaBannerDiag";
      dBtn.type = "button";
      dBtn.textContent = "Details";
      dBtn.addEventListener("click", function () { openDiagModal(true); });
      closeBtn.parentNode.insertBefore(dBtn, closeBtn);
    }

    var toolsGrid = document.querySelector("#lsMoreCard .grid");
    if (toolsGrid && !document.getElementById("lsMoreOtaDiag")) {
      var tile = document.createElement("button");
      tile.id = "lsMoreOtaDiag";
      tile.type = "button";
      tile.className = "ls-tool-tile col-span-2";
      tile.style.cssText = "padding:12px;border-radius:16px;border:1px solid #E8D5A8;background:#FFFBF0;text-align:left;";
      tile.innerHTML = '<div style="font-size:12px;font-weight:700;color:#7B1E2B;">OTA Diagnostics (In-App)</div><div style="font-size:10.5px;color:#5F554E;margin-top:2px;">Inspect Vercel, GitHub &amp; SHA-256 checksum download status</div>';
      tile.addEventListener("click", function () {
        var sheet = document.getElementById("lsMoreSheet");
        if (sheet) sheet.classList.remove("show");
        openDiagModal(true);
      });
      toolsGrid.appendChild(tile);
    }

    if (document.getElementById("lsOtaDiagModal")) return;

    var dm = document.createElement("div");
    dm.id = "lsOtaDiagModal";
    dm.innerHTML =
      '<div id="lsOtaDiagCard">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;gap:8px;">' +
          '<div><div style="font-size:14px;font-weight:800;color:#7B1E2B;">OTA Live Diagnostics</div><div style="font-size:11px;color:#5F554E;">Vercel, GitHub &amp; Native SHA-256 Probe</div></div>' +
          '<button type="button" id="lsOtaDiagClose" style="font-size:11.5px;font-weight:700;padding:5px 11px;border-radius:999px;border:1px solid #E8E0D5;background:#FAF7F2;color:#5F554E;cursor:pointer;">Close</button>' +
        '</div>' +
        '<pre id="lsOtaDiagPre">Tap Check Mirrors or Test Native Download...</pre>' +
        '<div style="display:flex;flex-wrap:wrap;gap:8px;">' +
          '<button type="button" id="lsOtaDiagRun" style="flex:1;padding:9px 10px;border-radius:11px;border:none;background:#7B1E2B;color:#fff;font-size:12px;font-weight:700;cursor:pointer;">Check Mirrors</button>' +
          '<button type="button" id="lsOtaDiagNative" style="flex:1;padding:9px 10px;border-radius:11px;border:1px solid #7B1E2B;background:#FBF1F2;color:#7B1E2B;font-size:12px;font-weight:700;cursor:pointer;">Test Native Download</button>' +
          '<button type="button" id="lsOtaDiagCopy" style="padding:9px 12px;border-radius:11px;border:1px solid #D6C7BC;background:#FAF7F2;color:#1F1B18;font-size:12px;font-weight:700;cursor:pointer;">Copy</button>' +
        '</div>' +
      '</div>';
    document.body.appendChild(dm);
    dm.addEventListener("click", function (ev) {
      if (ev.target === dm || ev.target.id === "lsOtaDiagClose") dm.classList.remove("show");
    });
    dm.querySelector("#lsOtaDiagRun").addEventListener("click", runMirrorCheck);
    dm.querySelector("#lsOtaDiagNative").addEventListener("click", runNativeDownloadProbe);
    dm.querySelector("#lsOtaDiagCopy").addEventListener("click", copyReport);
  }

  function copyReport() {
    var txt = (document.getElementById("lsOtaDiagPre") || {}).textContent || "";
    if (!txt) return;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(txt).then(function () {
        if (typeof showToast === "function") showToast("OTA Diagnostics copied!");
      }).catch(function () {});
    }
  }

  async function runMirrorCheck() {
    ensureDiagModal();
    var pre = document.getElementById("lsOtaDiagPre");
    var lines = [];
    function out(s) { lines.push(s); if (pre) { pre.textContent = lines.join("\n"); pre.scrollTop = pre.scrollHeight; } }

    out("=== LAW STUDYES OTA DIAGNOSTICS (v3.0.7) ===");
    out("Time: " + new Date().toLocaleString() + " | Online: " + navigator.onLine);
    out("Last Status: " + (window.__lsOtaLastStatus || "None"));

    var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
    if (!up) {
      out("Capgo Plugin: Web/Preview mode");
    } else {
      try {
        var cur = await up.current();
        var b = cur && (cur.bundle || cur);
        out("Active Bundle: id=" + (b && b.id) + " | ver=" + (b && b.version) + " | status=" + (b && b.status));
      } catch (e) { out("current() ERR: " + (e.message || e)); }
      try {
        var lst = await up.list();
        var arr = (lst && lst.bundles) ? lst.bundles : [];
        out("Stored Bundles (" + arr.length + "): " + (arr.length ? arr.map(function (x) { return x.version + "[" + x.status + "]"; }).join(", ") : "none"));
      } catch (e) {}
    }

    if (window.__lsOtaLastErrors && window.__lsOtaLastErrors.length) {
      out("\n--- Last Mirror Errors ---");
      window.__lsOtaLastErrors.forEach(function (l) { out("  * " + l); });
    }

    out("\n--- Live Mirror Probes ---");
    var ts = Date.now();
    var probes = [
      { name: "Vercel JSON", url: "https://law-studyes.vercel.app/ota-version.json?t=" + ts },
      { name: "GitHub Raw JSON", url: "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www/ota-version.json?t=" + ts }
    ];
    for (var i = 0; i < probes.length; i++) {
      var p = probes[i];
      var t0 = Date.now();
      try {
        var r = await fetch(p.url, { cache: "no-store" });
        var j = await r.json();
        out("[OK] " + p.name + " (" + (Date.now() - t0) + "ms) -> ver=" + j.version + " | sha=" + String(j.sha256 || "").slice(0, 12));
      } catch (err) {
        out("[FAIL] " + p.name + " -> " + ((err && err.message) || String(err)));
      }
    }
  }

  async function runNativeDownloadProbe() {
    ensureDiagModal();
    var pre = document.getElementById("lsOtaDiagPre");
    function add(s) { if (pre) { pre.textContent += "\n" + s; pre.scrollTop = pre.scrollHeight; } }
    var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
    if (!up) { add("\n[SKIP] Native test only runs on Android."); return; }

    add("\n=== NATIVE SHA-256 DOWNLOAD PROBE ===");
    try {
      var r = await fetch("https://law-studyes.vercel.app/ota-version.json?t=" + Date.now(), { cache: "no-store" });
      var meta = await r.json();
      var sha = String(meta.sha256 || "").trim().toLowerCase();
      var testVer = "0.0.0-probe" + String(Date.now()).slice(-4);
      var t0 = Date.now();
      add("Downloading with checksum=" + sha.slice(0, 12) + "...");
      var bdl = await up.download({ url: meta.url + "?probe=" + Date.now(), version: testVer, checksum: sha });
      add("[NATIVE OK] Downloaded & SHA-256 verified in " + (Date.now() - t0) + "ms | id=" + (bdl && bdl.id));
      if (bdl && bdl.id && typeof up.delete === "function") {
        await up.delete({ id: bdl.id });
        add("(Cleaned up probe bundle)");
      }
    } catch (err) {
      add("[NATIVE FAIL] " + ((err && err.message) || String(err)));
    }
  }

  function openDiagModal(autoRun) {
    ensureDiagModal();
    var dm = document.getElementById("lsOtaDiagModal");
    if (dm) dm.classList.add("show");
    if (autoRun !== false) runMirrorCheck();
  }

  window.LSOtaDiag = { open: openDiagModal, runMirrorCheck: runMirrorCheck, runNativeProbe: runNativeDownloadProbe, push: pushDiag };
  window.addEventListener("DOMContentLoaded", function () { setTimeout(ensureDiagModal, 350); });
})();