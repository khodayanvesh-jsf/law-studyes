const { app, BrowserWindow, ipcMain, Menu, Tray, Notification, dialog, shell, nativeImage } = require("electron");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");
const { spawn } = require("child_process");

const VERCEL_BASE = "https://law-studyes.vercel.app";
const SHEET_URL = "https://docs.google.com/spreadsheets/d/1J0_DHEal-8UUyXjoCdKDCBi_9ibppintTNjsRPzSsGA/edit";
const DEFAULT_GS_API = "https://script.google.com/macros/s/AKfycbzu-FFk-THjB-hDmtFRTlXswpCnIDhUW_ENA6nze4hL8gGshxWQLw3VdLTsUEJXxOg8/exec";
const FOUNDER_KEY = "LS_FOUNDER_2026";

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

function getSheetApiUrl() {
  try {
    const html = fs.readFileSync(path.join(PROJECT_ROOT, "www", "index.html"), "utf8");
    const m = html.match(/var\s+GS_API\s*=\s*"([^"]+)"/);
    if (m && m[1] && m[1].startsWith("https://")) return m[1];
  } catch (e) {}
  return DEFAULT_GS_API;
}

async function fetchJsonFollow(url, timeoutMs) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs || 25000);
  try {
    const res = await fetch(url, { redirect: "follow", cache: "no-store", signal: ctrl.signal });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const txt = await res.text();
    if (/<!doctype|<html/i.test(txt)) {
      throw new Error("Google Apps Script returned HTML instead of JSON. Confirm Code.gs v3.0.1 is deployed as New version.");
    }
    return JSON.parse(txt);
  } finally {
    clearTimeout(timer);
  }
}

function createWindow() {
  const iconPath = path.join(__dirname, "icon.png");
  mainWindow = new BrowserWindow({
    width: 1360,
    height: 860,
    minWidth: 1040,
    minHeight: 700,
    title: "Law Studyes - Founder & Admin Console v3.0.1",
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
        { label: "Open Live Vercel App", click: () => shell.openExternal(VERCEL_BASE) }
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

ipcMain.handle("ls:getAppInfo", async () => {
  const wwwDir = path.join(PROJECT_ROOT, "www");
  let dbMeta = { totalSubjects: 0, totalNotes: 0, totalVisuals: 0, updatedAt: "" };
  let otaMeta = { version: "Unknown", sha256: "", updatedAt: "" };
  try { dbMeta = JSON.parse(fs.readFileSync(path.join(wwwDir, "db-version.json"), "utf8")); } catch (e) {}
  try { otaMeta = JSON.parse(fs.readFileSync(path.join(wwwDir, "ota-version.json"), "utf8")); } catch (e) {}

  return {
    projectRoot: PROJECT_ROOT,
    localPreviewUrl: "file:///" + path.join(wwwDir, "index.html").replace(/\\/g, "/"),
    liveWebUrl: VERCEL_BASE,
    sheetUrl: SHEET_URL,
    gsApi: getSheetApiUrl(),
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
    const live = await fetchJsonFollow(VERCEL_BASE + "/ota-version.json?t=" + Date.now(), 15000);
    const match = (live.version === localVer) && (!live.sha256 || !localSha || live.sha256 === localSha);
    return { ok: true, localVer, localSha, liveVer: live.version, liveSha: live.sha256 || "", match };
  } catch (err) {
    return { ok: false, error: err.message, localVer, localSha };
  }
});

ipcMain.handle("ls:fetchAdminData", async () => {
  const api = getSheetApiUrl();
  if (!api) return { ok: false, error: "Google Sheet API URL not configured." };
  try {
    const url = api + "?action=admin_dump&key=" + encodeURIComponent(FOUNDER_KEY) + "&t=" + Date.now();
    return await fetchJsonFollow(url, 30000);
  } catch (err) {
    return { ok: false, error: err.message };
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
    title: "Export Law Studyes CSV",
    defaultPath: path.join(app.getPath("desktop"), filename || "LawStudyes-Export.csv"),
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
