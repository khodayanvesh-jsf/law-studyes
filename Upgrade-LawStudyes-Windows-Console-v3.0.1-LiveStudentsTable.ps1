<#
.SYNOPSIS
  Law Studyes Windows Founder Console v3.0.1 - Live Searchable Registered Students & Today's Usage Tables!
  1. Copies Code.gs v3.0.1 (adds founder-keyed action=admin_dump endpoint returning Registrations + Daily_Usage) to clipboard.
  2. Waits for you to deploy New version in Apps Script, then live-verifies admin_dump data feed.
  3. Upgrades desktop-console/ (main.js, preload.js, index.html) with searchable tables, Today's Unique Users KPIs,
     1-click Student Photo viewer, and filtered CSV export.
  4. Rebuilds Desktop\LawStudyes-Founder-Console-Windows.exe without touching Android APK or OTA pipeline.
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Upgrade-LawStudyes-Windows-Console-v3.0.1-LiveStudentsTable.ps1
#>
param(
  [string]$SheetApiUrl = "https://script.google.com/macros/s/AKfycbzu-FFk-THjB-hDmtFRTlXswpCnIDhUW_ENA6nze4hL8gGshxWQLw3VdLTsUEJXxOg8/exec"
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$deskDir = Join-Path $root "desktop-console"
New-Item -ItemType Directory -Path $deskDir -Force | Out-Null

Write-Host "`n=== 1. Preparing Code.gs v3.0.1 (Adds Live Founder Admin Table Endpoint) ===" -ForegroundColor Cyan
$gsCode = @'
var SHEET_NAME = "Registrations";
var USAGE_SHEET_NAME = "Daily_Usage";
var DASH_SHEET_NAME = "Dashboard";
var PHOTO_FOLDER_NAME = "LawStudyes_Student_Photos";
var ADMIN_KEY = "LS_FOUNDER_2026";

var HEADERS = [
  "Sl. No",
  "Registered At",
  "Phone",
  "Student Name",
  "State",
  "University",
  "College",
  "Year",
  "Semester",
  "App Version",
  "Photo",
  "Photo URL"
];

var USAGE_HEADERS = [
  "Sl. No",
  "Date (IST)",
  "Login Time (IST)",
  "Phone",
  "Student Name",
  "College",
  "Year",
  "App Version",
  "Login Reason"
];

function getRegSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
  if (sh.getLastRow() === 0) {
    sh.appendRow(HEADERS);
    sh.setFrozenRows(1);
    return sh;
  }
  var firstHeader = String(sh.getRange(1, 1).getDisplayValue() || "").trim().toLowerCase();
  if (firstHeader !== "sl. no" && firstHeader !== "sl.no" && firstHeader !== "sl no") {
    sh.insertColumnBefore(1);
    sh.getRange(1, 1).setValue("Sl. No");
    var lr = sh.getLastRow();
    if (lr >= 2) {
      var nums = [];
      for (var r = 2; r <= lr; r++) nums.push([r - 1]);
      sh.getRange(2, 1, lr - 1, 1).setValues(nums);
    }
  }
  var maxCols = sh.getLastColumn();
  if (maxCols < HEADERS.length) {
    sh.insertColumnsAfter(maxCols, HEADERS.length - maxCols);
  }
  sh.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
  sh.setFrozenRows(1);
  return sh;
}

function getUsageSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(USAGE_SHEET_NAME) || ss.insertSheet(USAGE_SHEET_NAME);
  if (sh.getLastRow() === 0) {
    sh.appendRow(USAGE_HEADERS);
    sh.setFrozenRows(1);
  }
  return sh;
}

function ensureDashboardUsageMetrics_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var dash = ss.getSheetByName(DASH_SHEET_NAME);
  if (!dash) return;
  var marker = String(dash.getRange("A19").getDisplayValue() || "").trim();
  if (marker !== "DAILY USAGE METRICS (LIVE)") {
    dash.getRange("A19").setValue("DAILY USAGE METRICS (LIVE)").setFontWeight("bold");
    dash.getRange("A20:C20").setValues([["TODAY'S UNIQUE USERS", "TODAY'S TOTAL LOGINS", "ALL-TIME TOTAL LOGINS"]]).setFontWeight("bold");
    dash.getRange("A21:C21").setFormulas([[
      '=IFERROR(COUNTA(UNIQUE(FILTER(Daily_Usage!D2:D, Daily_Usage!B2:B=TEXT(NOW()+TIME(5,30,0),"yyyy-mm-dd")))), 0)',
      '=COUNTIF(Daily_Usage!B2:B, TEXT(NOW()+TIME(5,30,0),"yyyy-mm-dd"))',
      '=COUNTA(Daily_Usage!D2:D)'
    ]]);
  }
}

function logDailyUsage_(student, appVersion, reason) {
  try {
    var sh = getUsageSheet_();
    var now = new Date();
    var dateStr = Utilities.formatDate(now, "Asia/Kolkata", "yyyy-MM-dd");
    var timeStr = Utilities.formatDate(now, "Asia/Kolkata", "HH:mm:ss");
    var lr = sh.getLastRow();
    var nextSl = (lr >= 2) ? lr : 1;
    sh.appendRow([
      nextSl,
      "'" + dateStr,
      "'" + timeStr,
      "'" + cleanPhone_(student.phone),
      String(student.name || "").trim(),
      String(student.college || "").trim(),
      String(student.year || "").trim(),
      String(appVersion || student.appVersion || "3.0.1").trim(),
      String(reason || "24h Login").trim()
    ]);
    ensureDashboardUsageMetrics_();
  } catch (e) {}
}

function cleanPhone_(v) { return String(v || "").replace(/\D/g, "").slice(-10); }
function jsonOut_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }

function savePhotoToDrive_(photoBase64, phone, name) {
  if (!photoBase64) return { imgFormula: "", url: "" };
  var raw = String(photoBase64).trim();
  if (raw.indexOf("http://") === 0 || raw.indexOf("https://") === 0) {
    return { imgFormula: '=IMAGE("' + raw + '", 1)', url: raw };
  }
  var m = raw.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
  if (!m) return { imgFormula: "", url: "" };
  try {
    var mime = m[1];
    var ext = mime.indexOf("png") !== -1 ? "png" : "jpg";
    var bytes = Utilities.base64Decode(m[2]);
    var safeName = String(name || "Student").replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 30);
    var fileName = "LS_" + phone + "_" + safeName + "_" + Date.now() + "." + ext;
    var folders = DriveApp.getFoldersByName(PHOTO_FOLDER_NAME);
    var folder = folders.hasNext() ? folders.next() : DriveApp.createFolder(PHOTO_FOLDER_NAME);
    var blob = Utilities.newBlob(bytes, mime, fileName);
    var file = folder.createFile(blob);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    var fid = file.getId();
    var directImg = "https://lh3.googleusercontent.com/d/" + fid + "=w300";
    var viewUrl = "https://drive.google.com/file/d/" + fid + "/view";
    return { imgFormula: '=IMAGE("' + directImg + '", 1)', url: viewUrl };
  } catch (err) {
    return { imgFormula: "", url: "DriveError: " + String(err) };
  }
}

function saveStudent_(d) {
  var ph = cleanPhone_(d.phone), nm = String(d.name || "").trim();
  if (ph.length !== 10 || !nm) return { ok: false, error: "Valid 10-digit phone and student name required." };
  var lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    var sh = getRegSheet_();
    var lr = sh.getLastRow();
    var photoInfo = savePhotoToDrive_(d.photoBase64 || d.photo || "", ph, nm);
    var regAt = String(d.registeredAt || new Date().toISOString());
    var state = String(d.state || "").trim();
    var univ = String(d.university || "").trim();
    var col = String(d.college || "").trim();
    var yr = String(d.year || "").trim();
    var sem = String(d.semester || "").trim();
    var appV = String(d.appVersion || "3.0.1").trim();

    if (lr >= 2) {
      var phones = sh.getRange(2, 3, lr - 1, 1).getDisplayValues();
      for (var i = 0; i < phones.length; i++) {
        if (cleanPhone_(phones[i][0]) === ph) {
          var rowIdx = i + 2;
          var slNo = sh.getRange(rowIdx, 1).getValue() || (i + 1);
          var existingPhoto = sh.getRange(rowIdx, 11).getFormula() || sh.getRange(rowIdx, 11).getDisplayValue();
          var existingUrl = sh.getRange(rowIdx, 12).getDisplayValue();
          var finalPhoto = photoInfo.imgFormula || existingPhoto || "";
          var finalUrl = photoInfo.url || existingUrl || "";
          var updRow = [slNo, regAt, "'" + ph, nm, state, univ, col, yr, sem, appV, finalPhoto, finalUrl];
          sh.getRange(rowIdx, 1, 1, updRow.length).setValues([updRow]);
          if (finalPhoto) sh.setRowHeight(rowIdx, 64);
          var stUpd = { slNo: slNo, registeredAt: regAt, phone: ph, name: nm, state: state, university: univ, college: col, year: yr, semester: sem, appVersion: appV, photoUrl: finalUrl };
          logDailyUsage_(stUpd, appV, "Re-Registration");
          return { ok: true, updated: true, student: stUpd };
        }
      }
    }

    var nextSl = (lr >= 2) ? lr : 1;
    var newRow = [nextSl, regAt, "'" + ph, nm, state, univ, col, yr, sem, appV, photoInfo.imgFormula, photoInfo.url];
    sh.appendRow(newRow);
    var appendedRow = sh.getLastRow();
    if (photoInfo.imgFormula) sh.setRowHeight(appendedRow, 64);
    var stNew = { slNo: nextSl, registeredAt: regAt, phone: ph, name: nm, state: state, university: univ, college: col, year: yr, semester: sem, appVersion: appV, photoUrl: photoInfo.url };
    logDailyUsage_(stNew, appV, "New Registration");
    return { ok: true, created: true, student: stNew };
  } finally {
    lock.releaseLock();
  }
}

function findStudent_(raw, appVersion, reason, shouldLog) {
  var ph = cleanPhone_(raw);
  if (ph.length !== 10) return { ok: false, found: false, error: "Invalid phone." };
  var sh = getRegSheet_();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, found: false };
  var rows = sh.getRange(2, 1, lr - 1, HEADERS.length).getDisplayValues();
  for (var i = rows.length - 1; i >= 0; i--) {
    if (cleanPhone_(rows[i][2]) === ph) {
      var st = {
        slNo: rows[i][0],
        registeredAt: rows[i][1],
        phone: ph,
        name: rows[i][3],
        state: rows[i][4],
        university: rows[i][5],
        college: rows[i][6],
        year: rows[i][7],
        semester: rows[i][8],
        appVersion: rows[i][9],
        photoUrl: rows[i][11]
      };
      if (shouldLog) {
        var lock = LockService.getScriptLock();
        lock.waitLock(15000);
        try { logDailyUsage_(st, appVersion, reason); } finally { lock.releaseLock(); }
      }
      return { ok: true, found: true, student: st };
    }
  }
  return { ok: true, found: false };
}

function getAdminDump_(key) {
  if (String(key || "") !== ADMIN_KEY) {
    return { ok: false, error: "Unauthorized founder key." };
  }
  var todayIst = Utilities.formatDate(new Date(), "Asia/Kolkata", "yyyy-MM-dd");

  // 1. Fetch all Registered Students (newest first)
  var regSh = getRegSheet_();
  var regLr = regSh.getLastRow();
  var students = [];
  if (regLr >= 2) {
    var regRows = regSh.getRange(2, 1, regLr - 1, HEADERS.length).getDisplayValues();
    for (var i = regRows.length - 1; i >= 0; i--) {
      var r = regRows[i];
      if (!String(r[2] || "").trim() && !String(r[3] || "").trim()) continue;
      students.push({
        slNo: r[0],
        registeredAt: r[1],
        phone: cleanPhone_(r[2]),
        name: r[3],
        state: r[4],
        university: r[5],
        college: r[6],
        year: r[7],
        semester: r[8],
        appVersion: r[9],
        photoUrl: r[11]
      });
    }
  }

  // 2. Fetch Daily Usage (today's logins + recent 250 logins)
  var useSh = getUsageSheet_();
  var useLr = useSh.getLastRow();
  var todayUsage = [];
  var recentUsage = [];
  var todayUniqueMap = {};
  var allTimeLogins = 0;

  if (useLr >= 2) {
    var useRows = useSh.getRange(2, 1, useLr - 1, USAGE_HEADERS.length).getDisplayValues();
    allTimeLogins = useRows.length;
    for (var j = useRows.length - 1; j >= 0; j--) {
      var u = useRows[j];
      var dStr = String(u[1] || "").replace(/^'/, "").trim();
      var phStr = cleanPhone_(u[3]);
      var item = {
        slNo: u[0],
        date: dStr,
        time: String(u[2] || "").replace(/^'/, "").trim(),
        phone: phStr,
        name: u[4],
        college: u[5],
        year: u[6],
        appVersion: u[7],
        reason: u[8]
      };
      if (recentUsage.length < 250) recentUsage.push(item);
      if (dStr === todayIst) {
        todayUsage.push(item);
        if (phStr) todayUniqueMap[phStr] = true;
      }
    }
  }

  return {
    ok: true,
    version: "3.0.1",
    todayIst: todayIst,
    stats: {
      totalStudents: students.length,
      todayUniqueUsers: Object.keys(todayUniqueMap).length,
      todayTotalLogins: todayUsage.length,
      allTimeLogins: allTimeLogins
    },
    students: students,
    todayUsage: todayUsage,
    recentUsage: recentUsage
  };
}

function doPost(e) {
  try {
    var body = (e && e.postData && e.postData.contents) ? e.postData.contents : "{}";
    return jsonOut_(saveStudent_(JSON.parse(body)));
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

function doGet(e) {
  try {
    var p = (e && e.parameter) ? e.parameter : {};
    var a = String(p.action || "").toLowerCase();
    if (a === "ping") {
      getRegSheet_();
      getUsageSheet_();
      ensureDashboardUsageMetrics_();
      return jsonOut_({ ok: true, version: "3.0.1", service: "LawStudyes-Registrations", sheet: SHEET_NAME, usageSheet: USAGE_SHEET_NAME });
    }
    if (a === "admin_dump") return jsonOut_(getAdminDump_(p.key));
    if (a === "register") return jsonOut_(saveStudent_(p));
    if (p.phone) {
      var shouldLog = (a === "login" || String(p.log || "") === "1");
      return jsonOut_(findStudent_(p.phone, p.appVersion || "3.0.1", p.reason || "Daily 24h Login", shouldLog));
    }
    return jsonOut_({ ok: true, version: "3.0.1", status: "ready" });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

'@
[System.IO.File]::WriteAllText((Join-Path $root "Code.gs"), $gsCode, $u)
Set-Clipboard -Value $gsCode
Write-Host "[COPIED] Updated Code.gs v3.0.1 copied to clipboard & saved to .\Code.gs!" -ForegroundColor Green

while ($true) {
  try {
    $ping = (Invoke-WebRequest ($SheetApiUrl + "?action=ping&t=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
    if ($ping.ok -and $ping.version -eq "3.0.1") {
      Write-Host "[PASS] Apps Script v3.0.1 LIVE!" -ForegroundColor Green
      break
    }
  } catch {}
  Write-Host "`nIn Apps Script tab: Ctrl+A -> Ctrl+V -> Ctrl+S -> Deploy -> Manage deployments -> Edit (pencil) -> Version: New version -> Deploy" -ForegroundColor Yellow
  $in = Read-Host "Press ENTER once deployed (or paste a new /exec URL)"
  if ($in.Trim() -match '^https://script\.google\.com/macros/s/.+/exec$') { $SheetApiUrl = $in.Trim() }
}

Write-Host "`n=== 2. Live-Testing Founder Table Data Feed (Registrations + Daily_Usage) ===" -ForegroundColor Cyan
$dumpUrl = $SheetApiUrl + "?action=admin_dump&key=LS_FOUNDER_2026&t=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$dump = (Invoke-WebRequest -Uri $dumpUrl -UseBasicParsing -TimeoutSec 30).Content | ConvertFrom-Json
if (-not $dump.ok) { throw "admin_dump failed!" }
Write-Host ("[PASS] Live Feed Verified -> Registered=" + $dump.stats.totalStudents + " | Today Unique=" + $dump.stats.todayUniqueUsers + " | Today Logins=" + $dump.stats.todayTotalLogins) -ForegroundColor Green

Write-Host "`n=== 3. Upgrading desktop-console/ UI & IPC Handlers ===" -ForegroundColor Cyan
$preloadJs = @'
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("LSDesktop", {
  getAppInfo: () => ipcRenderer.invoke("ls:getAppInfo"),
  checkOtaParity: () => ipcRenderer.invoke("ls:checkOtaParity"),
  fetchAdminData: () => ipcRenderer.invoke("ls:fetchAdminData"),
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
const { spawn } = require("child_process");

const VERCEL_BASE = "https://law-studyes.vercel.app";
const SHEET_URL = "https://docs.google.com/spreadsheets/d/1J0_DHEal-8UUyXjoCdKDCBi_9ibppintTNjsRPzSsGA/edit";
const DEFAULT_GS_API = "__SHEET_API_URL__";
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

'@
$mainJs = $mainJs.Replace("__SHEET_API_URL__", $SheetApiUrl)
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
    .grid-4 { display:grid; grid-template-columns:repeat(4,1fr); gap:14px; margin-bottom:16px; }
    .card { background:var(--card); border:1px solid var(--border); border-radius:16px; padding:16px 18px; box-shadow:0 2px 8px rgba(31,27,24,0.04); }
    .kpi-val { font-size:24px; font-weight:800; color:var(--burgundy); margin-top:4px; }
    .kpi-lbl { font-size:11px; font-weight:700; color:var(--muted); text-transform:uppercase; }
    .btn { padding:8px 14px; border-radius:10px; font-size:12.5px; font-weight:700; cursor:pointer; border:1px solid var(--burgundy); background:var(--burgundy); color:#fff; }
    .btn.alt { background:#fff; color:var(--burgundy); }
    .btn.sm { padding:5px 10px; font-size:11.5px; border-radius:8px; }
    .btn:disabled { opacity:0.55; cursor:not-allowed; }
    .row { display:flex; flex-wrap:wrap; gap:10px; align-items:center; }
    pre.console { background:#181412; color:#E8E0D5; padding:14px; border-radius:12px; height:360px; overflow:auto; font-family:Consolas, monospace; font-size:12px; line-height:1.45; white-space:pre-wrap; }
    .badge { display:inline-block; padding:3px 9px; border-radius:99px; font-size:11px; font-weight:700; }
    .badge.ok { background:#ECFDF5; color:#065F46; border:1px solid #A7F3D0; }
    .badge.warn { background:#FFFBEB; color:#92400E; border:1px solid #FDE68A; }
    .subtabs { display:flex; gap:8px; margin-bottom:12px; border-bottom:1px solid var(--border); padding-bottom:10px; }
    .subtab-btn { padding:7px 14px; border-radius:9px; border:1px solid var(--border); background:#fff; color:var(--muted); font-size:12.5px; font-weight:700; cursor:pointer; }
    .subtab-btn.active { background:var(--burgundy); color:#fff; border-color:var(--burgundy); }
    .table-wrap { overflow:auto; max-height:calc(100vh - 350px); border:1px solid var(--border); border-radius:12px; background:#fff; }
    table { width:100%; border-collapse:collapse; font-size:12.5px; }
    thead th { position:sticky; top:0; background:#FBF1F2; color:var(--burgundy); text-align:left; padding:10px 12px; font-size:11.5px; text-transform:uppercase; border-bottom:1px solid var(--border); white-space:nowrap; }
    tbody td { padding:9px 12px; border-bottom:1px solid #F3EDE4; vertical-align:middle; }
    tbody tr:hover { background:#FAF7F2; }
    .search-box { flex:1; min-width:240px; padding:8px 12px; border-radius:10px; border:1px solid #D6C7BC; font-size:13px; background:#fff; }
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
      <button class="nav-btn" data-tab="students">Students &amp; Daily Usage</button>
      <button class="nav-btn" data-tab="ota">OTA &amp; Source Sync</button>
      <button class="nav-btn" data-tab="preview">Shared App Preview</button>
    </nav>
    <div class="side-footer">
      <div>Unified Cross-Platform Engine</div>
      <div id="sideVer">v3.0.1 &middot; Android + Windows</div>
    </div>
  </aside>

  <main>
    <!-- TAB 1: DASHBOARD -->
    <section id="tab-dash" class="tab active">
      <div class="row" style="justify-content:space-between; margin-bottom:14px;">
        <div>
          <h2 style="margin:0;">Founder Control Center</h2>
          <div style="font-size:12.5px; color:var(--muted);">One shared <code>www/</code> codebase &rarr; Android APK + Windows Console via unchanged OTA.</div>
        </div>
        <div class="row">
          <button class="btn alt" id="btnOpenFolder">Open Project Folder</button>
          <button class="btn" id="btnCheckParity">Refresh Health &amp; Live Sheet</button>
        </div>
      </div>

      <div class="grid-4">
        <div class="card"><div class="kpi-lbl">Registered Students</div><div class="kpi-val" id="dTotalStu">--</div></div>
        <div class="card"><div class="kpi-lbl">Today's Unique Users</div><div class="kpi-val" id="dTodayUniq">--</div></div>
        <div class="card"><div class="kpi-lbl">Bilingual Notes</div><div class="kpi-val" id="kNotes">--</div></div>
        <div class="card"><div class="kpi-lbl">Live OTA Parity</div><div style="margin-top:8px;" id="kParity"><span class="badge warn">Checking...</span></div></div>
      </div>

      <div class="card" style="margin-bottom:14px;">
        <h3 style="margin:0 0 8px; font-size:14px; color:var(--burgundy);">Unified Android + Windows OTA Pipeline</h3>
        <div id="otaDetails" style="font-size:12.5px; color:var(--muted); line-height:1.6;">Loading local and Vercel metadata...</div>
      </div>

      <div class="card">
        <h3 style="margin:0 0 10px; font-size:14px; color:var(--burgundy);">Quick Actions</h3>
        <div class="row">
          <button class="btn" id="qPushOta">Push OTA Update Now</button>
          <button class="btn alt" id="qViewStudents">View Registered Students</button>
          <button class="btn alt" id="qScrape">Re-Sync Source (nyayasaral.com)</button>
          <button class="btn alt" id="qOpenSheet">Open Google Sheet</button>
          <button class="btn alt" id="qOpenWeb">Open Live Vercel App</button>
        </div>
      </div>
    </section>

    <!-- TAB 2: LIVE REGISTERED STUDENTS & TODAY'S DAILY USAGE -->
    <section id="tab-students" class="tab">
      <div class="row" style="justify-content:space-between; margin-bottom:14px;">
        <div>
          <h2 style="margin:0;">Registered Students &amp; Daily Usage</h2>
          <div id="stuSyncMeta" style="font-size:12px; color:var(--muted);">Fetching live records from Google Sheet...</div>
        </div>
        <div class="row">
          <button class="btn alt" id="btnRefreshSheet">Refresh Live Data</button>
          <button class="btn alt" id="btnExportTableCsv">Export Filtered CSV</button>
          <button class="btn" id="btnSheetDirect">Open Google Sheet</button>
        </div>
      </div>

      <div class="grid-4">
        <div class="card"><div class="kpi-lbl">Total Registered</div><div class="kpi-val" id="sTotal">--</div></div>
        <div class="card"><div class="kpi-lbl">Today's Unique Users</div><div class="kpi-val" id="sTodayUniq">--</div></div>
        <div class="card"><div class="kpi-lbl">Today's Total Logins</div><div class="kpi-val" id="sTodayLogins">--</div></div>
        <div class="card"><div class="kpi-lbl">All-Time Logins</div><div class="kpi-val" id="sAllLogins">--</div></div>
      </div>

      <div class="card">
        <div class="subtabs">
          <button class="subtab-btn active" data-sub="reg">Registered Students (<span id="cntReg">0</span>)</button>
          <button class="subtab-btn" data-sub="today">Today's Usage (<span id="cntToday">0</span>)</button>
          <button class="subtab-btn" data-sub="recent">All Recent Logins (<span id="cntRecent">0</span>)</button>
        </div>

        <div class="row" style="margin-bottom:12px;">
          <input id="tableSearch" class="search-box" type="search" placeholder="Search by student name, 10-digit phone, college, university, state, or year..." />
          <span id="filterCount" style="font-size:12px; font-weight:700; color:var(--muted);"></span>
        </div>

        <div class="table-wrap">
          <table>
            <thead id="liveTableHead"></thead>
            <tbody id="liveTableBody">
              <tr><td colspan="8" style="text-align:center; padding:26px; color:#5F554E;">Loading live Google Sheet data...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <!-- TAB 3: OTA & SYNC -->
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
    let ADMIN_DATA = { students: [], todayUsage: [], recentUsage: [], stats: {} };
    let ACTIVE_SUB = "reg";
    let LAST_FILTERED_ROWS = [];

    function esc(s) {
      return String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    function fmtDate(iso) {
      if (!iso) return "";
      try {
        const d = new Date(iso);
        if (!isNaN(d.getTime())) return d.toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
      } catch (e) {}
      return String(iso);
    }

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

    document.querySelectorAll(".subtab-btn").forEach((b) => {
      b.addEventListener("click", () => {
        document.querySelectorAll(".subtab-btn").forEach((x) => x.classList.remove("active"));
        b.classList.add("active");
        ACTIVE_SUB = b.dataset.sub;
        renderLiveTable();
      });
    });

    function appendLog(txt) {
      const el = document.getElementById("cmdLog");
      el.textContent += txt;
      el.scrollTop = el.scrollHeight;
    }
    window.LSDesktop.onLog((d) => appendLog(d.text));

    function renderLiveTable() {
      const q = (document.getElementById("tableSearch").value || "").trim().toLowerCase();
      const thead = document.getElementById("liveTableHead");
      const tbody = document.getElementById("liveTableBody");
      const fCount = document.getElementById("filterCount");

      if (ACTIVE_SUB === "reg") {
        thead.innerHTML = "<tr><th>Sl. No</th><th>Student Name</th><th>Phone</th><th>College &amp; University</th><th>State</th><th>Year / Sem</th><th>Registered At</th><th>Photo</th></tr>";
        const src = ADMIN_DATA.students || [];
        const rows = q ? src.filter((r) => (r.slNo + " " + r.name + " " + r.phone + " " + r.college + " " + r.university + " " + r.state + " " + r.year + " " + r.semester).toLowerCase().includes(q)) : src;
        LAST_FILTERED_ROWS = rows;
        fCount.textContent = "Showing " + rows.length + " of " + src.length + " students";
        if (!rows.length) {
          tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:24px; color:#5F554E;">No matching registered students.</td></tr>';
          return;
        }
        tbody.innerHTML = rows.map((r) => {
          const photoCell = (r.photoUrl && r.photoUrl.startsWith("http"))
            ? '<button type="button" class="btn alt sm" data-open-url="' + esc(r.photoUrl) + '">View Photo</button>'
            : '<span style="color:#9A8E84; font-size:11px;">None</span>';
          return "<tr>" +
            "<td><b>" + esc(r.slNo) + "</b></td>" +
            "<td><b>" + esc(r.name) + "</b><br><span style='font-size:11px;color:#8C6D46;'>v" + esc(r.appVersion) + "</span></td>" +
            "<td style='font-family:Consolas,monospace;font-weight:700;'>" + esc(r.phone) + "</td>" +
            "<td>" + esc(r.college) + "<br><span style='font-size:11px;color:#5F554E;'>" + esc(r.university) + "</span></td>" +
            "<td>" + esc(r.state) + "</td>" +
            "<td>" + esc(r.year) + "<br><span style='font-size:11px;color:#5F554E;'>" + esc(r.semester) + "</span></td>" +
            "<td style='font-size:11.5px;color:#5F554E;'>" + esc(fmtDate(r.registeredAt)) + "</td>" +
            "<td>" + photoCell + "</td>" +
          "</tr>";
        }).join("");
      } else {
        thead.innerHTML = "<tr><th>Sl. No</th><th>Date (IST)</th><th>Time (IST)</th><th>Phone</th><th>Student Name</th><th>College</th><th>Year</th><th>Version / Reason</th></tr>";
        const src = ACTIVE_SUB === "today" ? (ADMIN_DATA.todayUsage || []) : (ADMIN_DATA.recentUsage || []);
        const rows = q ? src.filter((r) => (r.date + " " + r.time + " " + r.phone + " " + r.name + " " + r.college + " " + r.year + " " + r.reason).toLowerCase().includes(q)) : src;
        LAST_FILTERED_ROWS = rows;
        fCount.textContent = "Showing " + rows.length + " of " + src.length + " login events";
        if (!rows.length) {
          tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding:24px; color:#5F554E;">No login activity found for this filter.</td></tr>';
          return;
        }
        tbody.innerHTML = rows.map((r) => (
          "<tr>" +
            "<td><b>" + esc(r.slNo) + "</b></td>" +
            "<td>" + esc(r.date) + "</td>" +
            "<td style='font-family:Consolas,monospace;'>" + esc(r.time) + "</td>" +
            "<td style='font-family:Consolas,monospace;font-weight:700;'>" + esc(r.phone) + "</td>" +
            "<td><b>" + esc(r.name) + "</b></td>" +
            "<td>" + esc(r.college) + "</td>" +
            "<td>" + esc(r.year) + "</td>" +
            "<td><span class='badge ok'>" + esc(r.reason) + "</span> <span style='font-size:11px;color:#5F554E;'>v" + esc(r.appVersion) + "</span></td>" +
          "</tr>"
        )).join("");
      }
    }

    document.getElementById("tableSearch").addEventListener("input", renderLiveTable);
    document.getElementById("liveTableBody").addEventListener("click", (ev) => {
      const btn = ev.target.closest("[data-open-url]");
      if (btn) window.LSDesktop.openExternal(btn.getAttribute("data-open-url"));
    });

    async function loadLiveSheetData() {
      const metaEl = document.getElementById("stuSyncMeta");
      metaEl.textContent = "Syncing live records from Google Sheet...";
      const res = await window.LSDesktop.fetchAdminData();
      if (!res || !res.ok) {
        const msg = (res && res.error) ? res.error : "Could not reach Google Sheet.";
        metaEl.textContent = "Sync error: " + msg;
        document.getElementById("liveTableBody").innerHTML =
          '<tr><td colspan="8" style="text-align:center; padding:24px; color:#991B1B;">' + esc(msg) + '</td></tr>';
        return;
      }
      ADMIN_DATA = res;
      const st = res.stats || {};
      document.getElementById("dTotalStu").textContent = st.totalStudents || 0;
      document.getElementById("dTodayUniq").textContent = st.todayUniqueUsers || 0;
      document.getElementById("sTotal").textContent = st.totalStudents || 0;
      document.getElementById("sTodayUniq").textContent = st.todayUniqueUsers || 0;
      document.getElementById("sTodayLogins").textContent = st.todayTotalLogins || 0;
      document.getElementById("sAllLogins").textContent = st.allTimeLogins || 0;
      document.getElementById("cntReg").textContent = (res.students || []).length;
      document.getElementById("cntToday").textContent = (res.todayUsage || []).length;
      document.getElementById("cntRecent").textContent = (res.recentUsage || []).length;
      metaEl.textContent = "Live synced for IST Date " + (res.todayIst || "") + " at " + new Date().toLocaleTimeString("en-IN");
      renderLiveTable();
    }

    async function refreshParity() {
      const kp = document.getElementById("kParity");
      kp.innerHTML = '<span class="badge warn">Checking...</span>';
      const r = await window.LSDesktop.checkOtaParity();
      if (r.ok && r.match) kp.innerHTML = '<span class="badge ok">MATCH: ' + r.liveVer + '</span>';
      else if (r.ok) kp.innerHTML = '<span class="badge warn">Live: ' + r.liveVer + '</span>';
      else kp.innerHTML = '<span class="badge warn">Offline</span>';

      document.getElementById("otaDetails").innerHTML =
        "<b>Project Root:</b> " + (APP_INFO ? esc(APP_INFO.projectRoot) : "") + "<br>" +
        "<b>Local OTA Version:</b> " + esc(r.localVer) + " (SHA: " + esc((r.localSha || "").slice(0, 16)) + ")<br>" +
        "<b>Live Vercel Version:</b> " + esc(r.liveVer || "Offline") + " (SHA: " + esc((r.liveSha || "").slice(0, 16)) + ")";
    }

    async function init() {
      APP_INFO = await window.LSDesktop.getAppInfo();
      document.getElementById("kNotes").textContent = APP_INFO.dbMeta.totalNotes || 0;
      await Promise.all([refreshParity(), loadLiveSheetData()]);
    }

    async function runTask(key) {
      document.querySelector('[data-tab="ota"]').click();
      await window.LSDesktop.runCommand(key);
      await refreshParity();
    }

    function csvEscape(v) {
      const s = String(v == null ? "" : v);
      return /[",\n]/.test(s) ? ('"' + s.replace(/"/g, '""') + '"') : s;
    }

    document.getElementById("btnExportTableCsv").onclick = async () => {
      const rows = LAST_FILTERED_ROWS || [];
      if (!rows.length) return;
      let lines = [];
      let fname = "LawStudyes-Registered-Students.csv";
      if (ACTIVE_SUB === "reg") {
        lines.push("Sl. No,Registered At,Phone,Student Name,State,University,College,Year,Semester,App Version,Photo URL");
        rows.forEach((r) => lines.push([r.slNo, r.registeredAt, r.phone, r.name, r.state, r.university, r.college, r.year, r.semester, r.appVersion, r.photoUrl].map(csvEscape).join(",")));
      } else {
        fname = ACTIVE_SUB === "today" ? "LawStudyes-Todays-Usage.csv" : "LawStudyes-Recent-Usage.csv";
        lines.push("Sl. No,Date (IST),Time (IST),Phone,Student Name,College,Year,App Version,Reason");
        rows.forEach((r) => lines.push([r.slNo, r.date, r.time, r.phone, r.name, r.college, r.year, r.appVersion, r.reason].map(csvEscape).join(",")));
      }
      const res = await window.LSDesktop.exportCsv(fname, lines.join("\r\n"));
      if (res.ok) window.LSDesktop.notify("CSV Exported", "Saved " + rows.length + " rows to " + res.filePath);
    };

    document.getElementById("btnOpenFolder").onclick = () => window.LSDesktop.openFolder("root");
    document.getElementById("btnCheckParity").onclick = () => Promise.all([refreshParity(), loadLiveSheetData()]);
    document.getElementById("btnRefreshSheet").onclick = loadLiveSheetData;
    document.getElementById("qViewStudents").onclick = () => document.querySelector('[data-tab="students"]').click();
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

    init();
  </script>
</body>
</html>

'@

[System.IO.File]::WriteAllText((Join-Path $deskDir "preload.js"), $preloadJs, $u)
[System.IO.File]::WriteAllText((Join-Path $deskDir "main.js"), $mainJs, $u)
[System.IO.File]::WriteAllText((Join-Path $deskDir "index.html"), $consoleHtml, $u)

foreach ($f in @("main.js", "preload.js")) {
  $err = node --check (Join-Path $deskDir $f) 2>&1
  if ($LASTEXITCODE -ne 0) { throw "$f syntax error: $err" }
}
Write-Host "[PASS] desktop-console main.js & preload.js verified (0 errors)!" -ForegroundColor Green

Write-Host "`n=== 4. Rebuilding Portable Windows Founder Console (.exe) ===" -ForegroundColor Cyan
Push-Location $deskDir
try {
  if (-not (Test-Path (Join-Path $deskDir "node_modules"))) {
    npm install --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw "npm install failed!" }
  }
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
Write-Host "`n[SUCCESS] Upgraded Windows Founder Console ready on Desktop: $destExe ($exeMB MB)" -ForegroundColor Green
Write-Host "[INFO] Android APK, www/ folder, and OTA auto-update pipeline remain 100% untouched." -ForegroundColor Cyan
