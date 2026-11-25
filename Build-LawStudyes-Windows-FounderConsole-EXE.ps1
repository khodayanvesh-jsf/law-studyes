<#
.SYNOPSIS
  Law Studyes - Builds Native Windows Founder & Admin Console (.exe)
  Creates an isolated desktop-console/ Electron app that shares your existing www/ codebase,
  Google Sheet backend, and Push-LawStudyes-OTA.ps1 pipeline WITHOUT modifying a single line
  of your Android APK or OTA auto-update process.
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Build-LawStudyes-Windows-FounderConsole-EXE.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$deskDir = Join-Path $root "desktop-console"
New-Item -ItemType Directory -Path $deskDir -Force | Out-Null

Write-Host "`n=== 1. Writing Isolated Windows Founder Console Files (desktop-console/) ===" -ForegroundColor Cyan

$pkgJson = @'
{
  "name": "law-studyes-founder-console",
  "version": "3.0.0",
  "description": "Law Studyes - Windows Founder & Admin Console",
  "main": "main.js",
  "scripts": {
    "start": "electron .",
    "build": "electron-builder --win portable"
  },
  "devDependencies": {
    "electron": "^33.2.0",
    "electron-builder": "^25.1.8"
  },
  "build": {
    "appId": "com.lawstudyes.founderconsole",
    "productName": "LawStudyes-Founder-Console",
    "directories": {
      "output": "dist"
    },
    "files": [
      "main.js",
      "preload.js",
      "index.html",
      "icon.png"
    ],
    "win": {
      "target": [
        {
          "target": "portable",
          "arch": ["x64"]
        }
      ],
      "icon": "icon.png",
      "artifactName": "LawStudyes-Founder-Console-Windows.exe"
    }
  }
}

'@
$preloadJs = @'
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("LSDesktop", {
  getAppInfo: () => ipcRenderer.invoke("ls:getAppInfo"),
  checkOtaParity: () => ipcRenderer.invoke("ls:checkOtaParity"),
  runCommand: (cmdKey) => ipcRenderer.invoke("ls:runCommand", cmdKey),
  openExternal: (url) => ipcRenderer.invoke("ls:openExternal", url),
  openFolder: (which) => ipcRenderer.invoke("ls:openFolder", which),
  exportCsv: (filename, content) => ipcRenderer.invoke("ls:exportCsv", { filename, content }),
  notify: (title, body) => ipcRenderer.invoke("ls:notify", { title, body }),
  onLog: (cb) => ipcRenderer.on("ls:log", (_ev, data) => cb(data))
});

'@
$mainJs = @'
const { app, BrowserWindow, ipcMain, Menu, Tray, Notification, dialog, shell, nativeImage } = require("electron");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const https = require("https");
const { spawn } = require("child_process");

const VERCEL_BASE = "https://law-studyes.vercel.app";
const SHEET_URL = "https://docs.google.com/spreadsheets/d/1J0_DHEal-8UUyXjoCdKDCBi_9ibppintTNjsRPzSsGA/edit";

let mainWindow = null;
let tray = null;

function resolveProjectRoot() {
  const candidates = [
    path.resolve(__dirname, ".."),
    path.join(process.env.USERPROFILE || "", "OneDrive", "Desktop", "law-studyes-offline-apk-kit"),
    path.join(process.env.USERPROFILE || "", "Desktop", "law-studyes-offline-apk-kit")
  ];
  for (const c of candidates) {
    if (c && fs.existsSync(path.join(c, "www", "index.html"))) return c;
  }
  return path.resolve(__dirname, "..");
}

const PROJECT_ROOT = resolveProjectRoot();

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { timeout: 15000 }, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error("HTTP " + res.statusCode));
        return;
      }
      let raw = "";
      res.on("data", (ch) => (raw += ch));
      res.on("end", () => {
        try { resolve(JSON.parse(raw)); } catch (e) { reject(e); }
      });
    }).on("error", reject);
  });
}

function createWindow() {
  const iconPath = path.join(__dirname, "icon.png");
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 840,
    minWidth: 1024,
    minHeight: 680,
    title: "Law Studyes - Founder & Admin Console",
    backgroundColor: "#FAF7F2",
    icon: fs.existsSync(iconPath) ? iconPath : undefined,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      webviewTag: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, "index.html"));

  const menuTemplate = [
    {
      label: "File",
      submenu: [
        { label: "Open Project Folder", click: () => shell.openPath(PROJECT_ROOT) },
        { label: "Open Google Sheet", click: () => shell.openExternal(SHEET_URL) },
        { type: "separator" },
        { role: "reload" },
        { role: "quit" }
      ]
    },
    {
      label: "OTA & Sync",
      submenu: [
        { label: "Check Live Vercel OTA Parity", click: () => mainWindow.webContents.send("ls:log", { text: "[Menu] Triggering parity check...", kind: "info" }) },
        { label: "Open Live Web App", click: () => shell.openExternal(VERCEL_BASE) }
      ]
    },
    {
      label: "View",
      submenu: [
        { role: "togglefullscreen" },
        { role: "zoomIn" },
        { role: "zoomOut" },
        { role: "resetZoom" },
        { type: "separator" },
        { role: "toggleDevTools" }
      ]
    }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(menuTemplate));

  // Windows System Tray integration
  if (fs.existsSync(iconPath)) {
    const tImg = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 });
    tray = new Tray(tImg);
    tray.setToolTip("Law Studyes Founder Console");
    tray.setContextMenu(Menu.buildFromTemplate([
      { label: "Show Founder Console", click: () => { mainWindow.show(); mainWindow.focus(); } },
      { label: "Open Google Sheet", click: () => shell.openExternal(SHEET_URL) },
      { label: "Open Live Vercel App", click: () => shell.openExternal(VERCEL_BASE) },
      { type: "separator" },
      { label: "Quit", click: () => app.quit() }
    ]));
    tray.on("double-click", () => { mainWindow.show(); mainWindow.focus(); });
  }
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

// --- IPC HANDLERS ---
ipcMain.handle("ls:getAppInfo", async () => {
  const wwwDir = path.join(PROJECT_ROOT, "www");
  let dbMeta = { totalSubjects: 0, totalNotes: 0, totalVisuals: 0, updatedAt: "" };
  let otaMeta = { version: "Unknown", sha256: "", updatedAt: "" };
  let gsApi = "";

  try { dbMeta = JSON.parse(fs.readFileSync(path.join(wwwDir, "db-version.json"), "utf8")); } catch (e) {}
  try { otaMeta = JSON.parse(fs.readFileSync(path.join(wwwDir, "ota-version.json"), "utf8")); } catch (e) {}
  try {
    const html = fs.readFileSync(path.join(wwwDir, "index.html"), "utf8");
    const m = html.match(/var\s+GS_API\s*=\s*"([^"]+)"/);
    if (m) gsApi = m[1];
  } catch (e) {}

  return {
    projectRoot: PROJECT_ROOT,
    localPreviewUrl: "file:///" + path.join(wwwDir, "index.html").replace(/\\/g, "/"),
    liveWebUrl: VERCEL_BASE,
    sheetUrl: SHEET_URL,
    gsApi,
    dbMeta,
    otaMeta
  };
});

ipcMain.handle("ls:checkOtaParity", async () => {
  const wwwDir = path.join(PROJECT_ROOT, "www");
  let localVer = "N/A";
  let localSha = "";
  try {
    const loc = JSON.parse(fs.readFileSync(path.join(wwwDir, "ota-version.json"), "utf8"));
    localVer = loc.version || "N/A";
    localSha = loc.sha256 || "";
    if (!localSha && fs.existsSync(path.join(wwwDir, "ota-bundle.zip"))) {
      localSha = crypto.createHash("sha256").update(fs.readFileSync(path.join(wwwDir, "ota-bundle.zip"))).digest("hex");
    }
  } catch (e) {}

  try {
    const live = await fetchJson(VERCEL_BASE + "/ota-version.json?t=" + Date.now());
    const match = (live.version === localVer) && (!live.sha256 || !localSha || live.sha256 === localSha);
    return { ok: true, localVer, localSha, liveVer: live.version, liveSha: live.sha256 || "", match };
  } catch (err) {
    return { ok: false, error: err.message, localVer, localSha };
  }
});

ipcMain.handle("ls:runCommand", async (_ev, cmdKey) => {
  let exe = "powershell.exe";
  let args = [];
  if (cmdKey === "push-ota") {
    args = ["-ExecutionPolicy", "Bypass", "-File", path.join(PROJECT_ROOT, "Push-LawStudyes-OTA.ps1")];
  } else if (cmdKey === "scrape") {
    exe = "python";
    args = [path.join(PROJECT_ROOT, "scrape_nyayasaral.py")];
  } else {
    return { ok: false, error: "Unknown command" };
  }

  return new Promise((resolve) => {
    const send = (text, kind) => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send("ls:log", { text, kind });
      }
    };
    send(`\n>>> Running ${cmdKey} in ${PROJECT_ROOT}...\n`, "info");
    const child = spawn(exe, args, { cwd: PROJECT_ROOT, windowsHide: true });
    child.stdout.on("data", (d) => send(d.toString(), "out"));
    child.stderr.on("data", (d) => send(d.toString(), "err"));
    child.on("close", (code) => {
      send(`\n>>> Completed with exit code ${code}\n`, code === 0 ? "ok" : "err");
      if (Notification.isSupported()) {
        new Notification({
          title: "Law Studyes Founder Console",
          body: code === 0 ? `${cmdKey} completed successfully!` : `${cmdKey} failed (exit ${code})`
        }).show();
      }
      resolve({ ok: code === 0, code });
    });
  });
});

ipcMain.handle("ls:openExternal", (_ev, url) => shell.openExternal(url));
ipcMain.handle("ls:openFolder", (_ev, which) => {
  if (which === "www") return shell.openPath(path.join(PROJECT_ROOT, "www"));
  return shell.openPath(PROJECT_ROOT);
});

ipcMain.handle("ls:exportCsv", async (_ev, { filename, content }) => {
  const { canceled, filePath } = await dialog.showSaveDialog(mainWindow, {
    title: "Export Law Studyes Report",
    defaultPath: path.join(app.getPath("desktop"), filename || "LawStudyes-Report.csv"),
    filters: [{ name: "CSV Spreadsheet", extensions: ["csv"] }]
  });
  if (canceled || !filePath) return { ok: false, canceled: true };
  fs.writeFileSync(filePath, content, "utf8");
  return { ok: true, filePath };
});

ipcMain.handle("ls:notify", (_ev, { title, body }) => {
  if (Notification.isSupported()) new Notification({ title, body }).show();
  return { ok: true };
});

'@
$consoleHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Law Studyes - Founder &amp; Admin Console</title>
  <style>
    :root { --burgundy:#7B1E2B; --burgundy-dark:#56111B; --gold:#FAD676; --bg:#FAF7F2; --card:#FFFFFF; --border:#E8E0D5; --text:#1F1B18; --muted:#5F554E; }
    * { box-sizing: border-box; }
    body { margin:0; font-family: "Segoe UI", system-ui, sans-serif; background: var(--bg); color: var(--text); display:flex; height:100vh; overflow:hidden; }
    aside { width:245px; background:linear-gradient(180deg, #8A2231 0%, #56111B 100%); color:#FAF7F2; display:flex; flex-direction:column; padding:18px 14px; flex-shrink:0; }
    .brand { padding:6px 8px 18px; border-bottom:1px solid rgba(255,255,255,0.14); }
    .brand h1 { margin:0; font-size:18px; font-family: Georgia, serif; letter-spacing:0.4px; }
    .brand small { color:var(--gold); font-size:11px; font-weight:700; text-transform:uppercase; }
    nav { margin-top:14px; display:flex; flex-direction:column; gap:6px; flex:1; }
    .nav-btn { background:transparent; border:none; color:#FAF7F2; text-align:left; padding:10px 12px; border-radius:10px; font-size:13px; font-weight:600; cursor:pointer; transition:background 0.15s; }
    .nav-btn:hover { background:rgba(255,255,255,0.12); }
    .nav-btn.active { background:var(--gold); color:var(--burgundy-dark); font-weight:700; }
    .side-footer { border-top:1px solid rgba(255,255,255,0.14); padding-top:12px; font-size:11px; color:rgba(250,247,242,0.75); }
    main { flex:1; overflow:auto; padding:22px 26px; }
    .tab { display:none; }
    .tab.active { display:block; }
    .grid-4 { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:18px; }
    .card { background:var(--card); border:1px solid var(--border); border-radius:16px; padding:16px 18px; box-shadow:0 2px 8px rgba(31,27,24,0.04); }
    .kpi-val { font-size:26px; font-weight:800; color:var(--burgundy); margin-top:4px; }
    .kpi-lbl { font-size:11.5px; font-weight:700; color:var(--muted); text-transform:uppercase; }
    .btn { padding:9px 14px; border-radius:10px; font-size:12.5px; font-weight:700; cursor:pointer; border:1px solid var(--burgundy); background:var(--burgundy); color:#fff; }
    .btn.alt { background:#fff; color:var(--burgundy); }
    .btn:disabled { opacity:0.55; cursor:not-allowed; }
    .row { display:flex; flex-wrap:wrap; gap:10px; align-items:center; }
    pre.console { background:#181412; color:#E8E0D5; padding:14px; border-radius:12px; height:360px; overflow:auto; font-family:Consolas, monospace; font-size:12px; line-height:1.45; white-space:pre-wrap; }
    .badge { display:inline-block; padding:3px 9px; border-radius:99px; font-size:11px; font-weight:700; }
    .badge.ok { background:#ECFDF5; color:#065F46; border:1px solid #A7F3D0; }
    .badge.warn { background:#FFFBEB; color:#92400E; border:1px solid #FDE68A; }
    .preview-bar { display:flex; justify-content:space-between; align-items:center; margin-bottom:10px; }
    iframe.app-frame { width:100%; height:calc(100vh - 130px); border:1px solid var(--border); border-radius:14px; background:#fff; }
    iframe.app-frame.mobile { width:412px; display:block; margin:0 auto; box-shadow:0 10px 30px rgba(0,0,0,0.12); }
  </style>
</head>
<body>
  <aside>
    <div class="brand">
      <h1>LAW STUDYES</h1>
      <small>Founder &amp; Admin Console</small>
    </div>
    <nav>
      <button class="nav-btn active" data-tab="dash">Dashboard &amp; Health</button>
      <button class="nav-btn" data-tab="ota">OTA &amp; Source Sync</button>
      <button class="nav-btn" data-tab="students">Students &amp; Sheet</button>
      <button class="nav-btn" data-tab="preview">Shared App Preview</button>
    </nav>
    <div class="side-footer">
      <div>Unified Cross-Platform Engine</div>
      <div id="sideVer">v3.0.0 &middot; Android + Windows</div>
    </div>
  </aside>

  <main>
    <!-- TAB 1: DASHBOARD -->
    <section id="tab-dash" class="tab active">
      <div class="row" style="justify-content:space-between; margin-bottom:14px;">
        <div>
          <h2 style="margin:0;">Founder Control Center</h2>
          <div style="font-size:12.5px; color:var(--muted);">One shared <code>www/</code> codebase &rarr; pushes simultaneously to Android APK &amp; Windows Console via unchanged OTA.</div>
        </div>
        <div class="row">
          <button class="btn alt" id="btnOpenFolder">Open Project Folder</button>
          <button class="btn" id="btnCheckParity">Verify Live OTA Parity</button>
        </div>
      </div>

      <div class="grid-4">
        <div class="card"><div class="kpi-lbl">Subjects</div><div class="kpi-val" id="kSubj">--</div></div>
        <div class="card"><div class="kpi-lbl">Bilingual Notes</div><div class="kpi-val" id="kNotes">--</div></div>
        <div class="card"><div class="kpi-lbl">Diagrams &amp; Tables</div><div class="kpi-val" id="kVis">--</div></div>
        <div class="card"><div class="kpi-lbl">Live OTA Status</div><div style="margin-top:8px;" id="kParity"><span class="badge warn">Checking...</span></div></div>
      </div>

      <div class="card" style="margin-bottom:14px;">
        <h3 style="margin:0 0 8px; font-size:14px; color:var(--burgundy);">Unified Android + Windows OTA Pipeline</h3>
        <div id="otaDetails" style="font-size:12.5px; color:var(--muted); line-height:1.6;">Loading local and Vercel metadata...</div>
      </div>

      <div class="card">
        <h3 style="margin:0 0 10px; font-size:14px; color:var(--burgundy);">Quick Actions</h3>
        <div class="row">
          <button class="btn" id="qPushOta">Push OTA Update Now</button>
          <button class="btn alt" id="qScrape">Re-Sync Source (nyayasaral.com)</button>
          <button class="btn alt" id="qOpenSheet">Open Google Sheet</button>
          <button class="btn alt" id="qOpenWeb">Open Live Vercel App</button>
        </div>
      </div>
    </section>

    <!-- TAB 2: OTA & SYNC -->
    <section id="tab-ota" class="tab">
      <h2 style="margin:0 0 6px;">OTA &amp; Source Sync Command Center</h2>
      <p style="margin:0 0 14px; font-size:12.5px; color:var(--muted);">Run your existing <code>scrape_nyayasaral.py</code> and <code>Push-LawStudyes-OTA.ps1</code> directly from Windows with live streaming logs. Zero changes to your Android OTA process.</p>
      <div class="row" style="margin-bottom:12px;">
        <button class="btn" id="btnRunScrape">1. Sync Source Website</button>
        <button class="btn" id="btnRunOta">2. Push OTA to GitHub &amp; Vercel</button>
        <button class="btn alt" id="btnClearLog">Clear Console</button>
      </div>
      <pre class="console" id="cmdLog">Ready. Select an action above to run with live output.</pre>
    </section>

    <!-- TAB 3: STUDENTS & SHEET -->
    <section id="tab-students" class="tab">
      <div class="row" style="justify-content:space-between; margin-bottom:14px;">
        <div>
          <h2 style="margin:0;">Student Registrations &amp; Daily Usage</h2>
          <div style="font-size:12.5px; color:var(--muted);">Connected directly to your live Google Sheet Apps Script backend.</div>
        </div>
        <div class="row">
          <button class="btn alt" id="btnExportSummary">Export Status CSV</button>
          <button class="btn" id="btnSheetDirect">Open Full Google Sheet</button>
        </div>
      </div>
      <div class="card">
        <div class="row" style="margin-bottom:10px;">
          <input id="lookupPhone" type="text" placeholder="Enter 10-digit student mobile to verify..." style="flex:1; padding:9px 12px; border-radius:10px; border:1px solid var(--border); font-size:13px;" />
          <button class="btn" id="btnLookupPhone">Verify Student in Sheet</button>
        </div>
        <pre class="console" id="lookupOut" style="height:220px;">Enter a 10-digit student mobile number to inspect their live registration record, Sl. No, and photo link.</pre>
      </div>
    </section>

    <!-- TAB 4: SHARED APP PREVIEW -->
    <section id="tab-preview" class="tab">
      <div class="preview-bar">
        <div style="font-size:13px; font-weight:700; color:var(--burgundy);">Live Shared App Preview (Loads exact same <code>www/</code> as Android APK)</div>
        <div class="row">
          <button class="btn alt" id="btnPrevLocal">Local www/</button>
          <button class="btn alt" id="btnPrevLive">Live Vercel OTA</button>
          <button class="btn" id="btnToggleMobile">Toggle Mobile / Desktop View</button>
        </div>
      </div>
      <iframe id="appFrame" class="app-frame" src="about:blank"></iframe>
    </section>
  </main>

  <script>
    let APP_INFO = null;

    document.querySelectorAll(".nav-btn").forEach((b) => {
      b.addEventListener("click", () => {
        document.querySelectorAll(".nav-btn").forEach((x) => x.classList.remove("active"));
        document.querySelectorAll(".tab").forEach((x) => x.classList.remove("active"));
        b.classList.add("active");
        document.getElementById("tab-" + b.dataset.tab).classList.add("active");
        if (b.dataset.tab === "preview" && APP_INFO) {
          const fr = document.getElementById("appFrame");
          if (fr.src === "about:blank") fr.src = APP_INFO.localPreviewUrl;
        }
      });
    });

    function appendLog(txt) {
      const el = document.getElementById("cmdLog");
      el.textContent += txt;
      el.scrollTop = el.scrollHeight;
    }

    window.LSDesktop.onLog((d) => appendLog(d.text));

    async function refreshParity() {
      const kp = document.getElementById("kParity");
      kp.innerHTML = '<span class="badge warn">Checking...</span>';
      const r = await window.LSDesktop.checkOtaParity();
      if (r.ok && r.match) {
        kp.innerHTML = '<span class="badge ok">MATCH: ' + r.liveVer + '</span>';
      } else if (r.ok) {
        kp.innerHTML = '<span class="badge warn">Live: ' + r.liveVer + '</span>';
      } else {
        kp.innerHTML = '<span class="badge warn">Offline</span>';
      }
      document.getElementById("otaDetails").innerHTML =
        "<b>Project Root:</b> " + (APP_INFO ? APP_INFO.projectRoot : "") + "<br>" +
        "<b>Local OTA Version:</b> " + r.localVer + " (SHA: " + (r.localSha || "").slice(0, 16) + ")<br>" +
        "<b>Live Vercel Version:</b> " + (r.liveVer || "Offline") + " (SHA: " + (r.liveSha || "").slice(0, 16) + ")";
    }

    async function init() {
      APP_INFO = await window.LSDesktop.getAppInfo();
      document.getElementById("kSubj").textContent = APP_INFO.dbMeta.totalSubjects || 0;
      document.getElementById("kNotes").textContent = APP_INFO.dbMeta.totalNotes || 0;
      document.getElementById("kVis").textContent = APP_INFO.dbMeta.totalVisuals || 0;
      await refreshParity();
    }

    async function runTask(key) {
      document.querySelector('[data-tab="ota"]').click();
      await window.LSDesktop.runCommand(key);
      await refreshParity();
    }

    document.getElementById("btnOpenFolder").onclick = () => window.LSDesktop.openFolder("root");
    document.getElementById("btnCheckParity").onclick = refreshParity;
    document.getElementById("qPushOta").onclick = () => runTask("push-ota");
    document.getElementById("qScrape").onclick = () => runTask("scrape");
    document.getElementById("btnRunScrape").onclick = () => runTask("scrape");
    document.getElementById("btnRunOta").onclick = () => runTask("push-ota");
    document.getElementById("btnClearLog").onclick = () => { document.getElementById("cmdLog").textContent = ""; };
    document.getElementById("qOpenSheet").onclick = () => APP_INFO && window.LSDesktop.openExternal(APP_INFO.sheetUrl);
    document.getElementById("btnSheetDirect").onclick = () => APP_INFO && window.LSDesktop.openExternal(APP_INFO.sheetUrl);
    document.getElementById("qOpenWeb").onclick = () => APP_INFO && window.LSDesktop.openExternal(APP_INFO.liveWebUrl);

    document.getElementById("btnPrevLocal").onclick = () => { if (APP_INFO) document.getElementById("appFrame").src = APP_INFO.localPreviewUrl; };
    document.getElementById("btnPrevLive").onclick = () => { if (APP_INFO) document.getElementById("appFrame").src = APP_INFO.liveWebUrl; };
    document.getElementById("btnToggleMobile").onclick = () => document.getElementById("appFrame").classList.toggle("mobile");

    document.getElementById("btnLookupPhone").onclick = async () => {
      const out = document.getElementById("lookupOut");
      const ph = (document.getElementById("lookupPhone").value || "").replace(/\D/g, "").slice(-10);
      if (ph.length !== 10) { out.textContent = "Enter a valid 10-digit mobile number."; return; }
      if (!APP_INFO || !APP_INFO.gsApi) { out.textContent = "GS_API URL not found in www/index.html."; return; }
      out.textContent = "Querying live Google Sheet for " + ph + "...";
      try {
        const res = await fetch(APP_INFO.gsApi + "?phone=" + encodeURIComponent(ph) + "&t=" + Date.now());
        const data = await res.json();
        out.textContent = JSON.stringify(data, null, 2);
      } catch (e) {
        out.textContent = "Lookup error: " + e.message;
      }
    };

    document.getElementById("btnExportSummary").onclick = async () => {
      if (!APP_INFO) return;
      const csv = "Metric,Value\nSubjects," + (APP_INFO.dbMeta.totalSubjects || 0) +
        "\nNotes," + (APP_INFO.dbMeta.totalNotes || 0) +
        "\nDiagrams," + (APP_INFO.dbMeta.totalVisuals || 0) +
        "\nOTA_Version," + (APP_INFO.otaMeta.version || "") + "\n";
      const r = await window.LSDesktop.exportCsv("LawStudyes-Console-Summary.csv", csv);
      if (r.ok) window.LSDesktop.notify("Export Saved", "Saved CSV to " + r.filePath);
    };

    init();
  </script>
</body>
</html>

'@

[System.IO.File]::WriteAllText((Join-Path $deskDir "package.json"), $pkgJson, $u)
[System.IO.File]::WriteAllText((Join-Path $deskDir "preload.js"), $preloadJs, $u)
[System.IO.File]::WriteAllText((Join-Path $deskDir "main.js"), $mainJs, $u)
[System.IO.File]::WriteAllText((Join-Path $deskDir "index.html"), $consoleHtml, $u)

# Copy your custom Law Studyes 512x512 icon for the Windows .exe & System Tray
$srcIcon = Join-Path $root "www\icon-512.png"
if (Test-Path $srcIcon) {
  Copy-Item $srcIcon (Join-Path $deskDir "icon.png") -Force
  Write-Host "[OK] Copied Law Studyes brand icon -> desktop-console/icon.png" -ForegroundColor Green
}

# Verify JS syntax
foreach ($f in @("main.js", "preload.js")) {
  $err = node --check (Join-Path $deskDir $f) 2>&1
  if ($LASTEXITCODE -ne 0) { throw "$f syntax error: $err" }
}
Write-Host "[PASS] main.js & preload.js syntax verified (0 errors)!" -ForegroundColor Green

Write-Host "`n=== 2. Adding desktop-console/node_modules & dist to .gitignore ===" -ForegroundColor Cyan
$giPath = Join-Path $root ".gitignore"
$giTxt = if (Test-Path $giPath) { [System.IO.File]::ReadAllText($giPath, $u) } else { "" }
foreach ($rule in @("desktop-console/node_modules/", "desktop-console/dist/")) {
  if ($giTxt -notmatch [regex]::Escape($rule)) {
    $giTxt = $giTxt.TrimEnd() + "`r`n" + $rule
  }
}
[System.IO.File]::WriteAllText($giPath, ($giTxt.TrimEnd() + "`r`n"), $u)

Write-Host "`n=== 3. Installing Electron & Building Portable Windows .exe ===" -ForegroundColor Cyan
Push-Location $deskDir
try {
  npm install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { throw "npm install failed in desktop-console!" }
  npm run build
  if ($LASTEXITCODE -ne 0) { throw "electron-builder failed!" }
} finally {
  Pop-Location
}

$exeSrc = Join-Path $deskDir "dist\LawStudyes-Founder-Console-Windows.exe"
if (-not (Test-Path $exeSrc)) {
  $found = Get-ChildItem (Join-Path $deskDir "dist") -Filter "*.exe" -File | Select-Object -First 1
  if ($found) { $exeSrc = $found.FullName } else { throw "No .exe produced in desktop-console/dist!" }
}

$destExe = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-Founder-Console-Windows.exe"
Copy-Item $exeSrc $destExe -Force
$exeMB = [Math]::Round((Get-Item $destExe).Length / 1MB, 2)
Write-Host "`n[SUCCESS] Windows Founder Console ready on Desktop: $destExe ($exeMB MB)" -ForegroundColor Green
Write-Host "[INFO] Your Android APK, www/ folder, and OTA auto-update pipeline were NOT modified." -ForegroundColor Cyan
