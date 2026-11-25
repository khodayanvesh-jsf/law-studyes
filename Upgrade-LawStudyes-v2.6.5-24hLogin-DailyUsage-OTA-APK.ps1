<#
.SYNOPSIS
  Law Studyes v2.6.5 - 24-Hour Auto-Logout + Post-Update Phone Re-Login + Daily Usage Tracking in Google Sheet!
  1. Copies updated Code.gs v2.6.5 (keeps Sl. No + Photo, adds Daily_Usage tab & live Today's Active Users KPIs) to clipboard.
  2. Waits for you to deploy New Version in Apps Script, then live-tests Daily_Usage login logging.
  3. Patches www/index.html to auto-logout every 24h AND after any App/OTA update, pre-filling the student's phone number
     for 1-tap passwordless verification against your Google Sheet.
  4. Builds clean bloat-free Desktop APK v2.6.5 (versionCode 265) and pushes Full-Diagram OTA to GitHub & Vercel.
.USAGE
  Run in C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Upgrade-LawStudyes-v2.6.5-24hLogin-DailyUsage-OTA-APK.ps1
#>
param(
  [string]$SheetApiUrl = "https://script.google.com/macros/s/AKfycbzu-FFk-THjB-hDmtFRTlXswpCnIDhUW_ENA6nze4hL8gGshxWQLw3VdLTsUEJXxOg8/exec"
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.5"
$verCode = 265

Write-Host "`n=== 1. Preparing Code.gs v2.6.5 (Daily_Usage Tab + Today's Active Users + Sl. No + Photo) ===" -ForegroundColor Cyan
$gsCode = @'
var SHEET_NAME = "Registrations";
var USAGE_SHEET_NAME = "Daily_Usage";
var DASH_SHEET_NAME = "Dashboard";
var PHOTO_FOLDER_NAME = "LawStudyes_Student_Photos";

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
  var sh = ss.getSheetByName(USAGE_SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(USAGE_SHEET_NAME);
  }
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
  // Add Daily Usage KPIs in rows 7-8 if not already present
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
      String(appVersion || student.appVersion || "2.6.5").trim(),
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
    var appV = String(d.appVersion || "2.6.5").trim();

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
      return jsonOut_({ ok: true, version: "2.6.5", service: "LawStudyes-Registrations", sheet: SHEET_NAME, usageSheet: USAGE_SHEET_NAME });
    }
    if (a === "register") return jsonOut_(saveStudent_(p));
    if (p.phone) {
      var shouldLog = (a === "login" || String(p.log || "") === "1");
      return jsonOut_(findStudent_(p.phone, p.appVersion || "2.6.5", p.reason || "Daily 24h Login", shouldLog));
    }
    return jsonOut_({ ok: true, version: "2.6.5", status: "ready" });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

'@
[System.IO.File]::WriteAllText((Join-Path $root "Code.gs"), $gsCode, $u)
Set-Clipboard -Value $gsCode
Write-Host "[COPIED] Updated Code.gs v2.6.5 copied to clipboard & saved to .\Code.gs!" -ForegroundColor Green

while ($true) {
  try {
    $ping = (Invoke-WebRequest ($SheetApiUrl + "?action=ping&t=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
    if ($ping.ok -and $ping.version -eq "2.6.5") {
      Write-Host "[PASS] Apps Script v2.6.5 LIVE! Daily_Usage tab & Dashboard KPIs ready." -ForegroundColor Green
      break
    }
  } catch {}
  Write-Host "`nIn Apps Script tab: Ctrl+A -> Ctrl+V -> Ctrl+S -> Deploy -> Manage deployments -> Edit (pencil) -> Version: New version -> Deploy" -ForegroundColor Yellow
  $in = Read-Host "Press ENTER once deployed (or paste a new /exec URL)"
  if ($in.Trim() -match '^https://script\.google\.com/macros/s/.+/exec$') { $SheetApiUrl = $in.Trim() }
}

Write-Host "`n=== 2. Live-Testing Phone Verification & Daily_Usage Logging ===" -ForegroundColor Cyan
$loginTestUrl = $SheetApiUrl + "?action=login&phone=9999900001&log=1&appVersion=" + $ver + "&reason=VerificationTest&t=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$loginResp = (Invoke-WebRequest -Uri $loginTestUrl -UseBasicParsing -TimeoutSec 25).Content | ConvertFrom-Json
if (-not $loginResp.ok) { throw "Daily login test failed!" }
Write-Host ("[PASS] Daily_Usage endpoint verified! Found=" + $loginResp.found + " (Check Daily_Usage tab in your Sheet)") -ForegroundColor Green

Write-Host "`n=== 3. Patching www/index.html (24h Auto-Logout + Post-Update Phone Re-Login + Selfie Photo v$ver) ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

$h = [regex]::Replace($h, 'var\s+GS_API\s*=\s*"[^"]*";', ('var GS_API = "' + $SheetApiUrl + '";'))
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"

$h = [regex]::Replace($h, '(?s)<!-- LS_STRICT_SHEET_AUTH_START -->.*?<!-- LS_STRICT_SHEET_AUTH_END -->', '')
$authBlock = @'
<!-- LS_STRICT_SHEET_AUTH_START -->
<style>
  body.ls-auth-locked { overflow: hidden !important; touch-action: none; }
  #lawStudyesAuthOverlay:not(.hidden) {
    display: flex !important;
    z-index: 9999 !important;
    pointer-events: auto !important;
  }
  .ls-sheet-status-bar {
    margin-top: 8px;
    padding: 8px 10px;
    border-radius: 10px;
    font-size: 12px;
    font-weight: 600;
    display: none;
  }
  .ls-sheet-status-bar.show { display: block; }
  .ls-sheet-status-bar.err { background: #FEF2F2; color: #991B1B; border: 1px solid #FECACA; }
  .ls-sheet-status-bar.ok { background: #ECFDF5; color: #065F46; border: 1px solid #A7F3D0; }
  .ls-sheet-status-bar.info { background: #FFFBEB; color: #92400E; border: 1px solid #FDE68A; }
  .ls-photo-picker {
    margin: 10px 0;
    padding: 10px 12px;
    border-radius: 12px;
    border: 1px dashed #D6C7BC;
    background: #FAF7F2;
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .ls-photo-avatar {
    width: 62px;
    height: 62px;
    border-radius: 9999px;
    object-fit: cover;
    border: 2px solid #7B1E2B;
    background: #FBF1F2;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 11px;
    font-weight: 700;
    color: #7B1E2B;
    text-align: center;
    overflow: hidden;
  }
  .ls-photo-avatar img { width: 100%; height: 100%; object-fit: cover; display: block; }
  .ls-photo-actions { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 5px; }
  .ls-photo-btn {
    padding: 6px 10px;
    border-radius: 8px;
    font-size: 11.5px;
    font-weight: 700;
    cursor: pointer;
    border: 1px solid #7B1E2B;
  }
  .ls-photo-btn-cam { background: #7B1E2B; color: #FFFFFF; }
  .ls-photo-btn-gal { background: #FFFFFF; color: #7B1E2B; }
</style>
<script>
(function () {
  var SHEET_API = "__SHEET_API_URL__";
  var SK = "ls_active_student_v1";
  var RK = "ls_registered_students_v1";
  var LAST_PH_KEY = "ls_last_verified_phone";
  var OTA_VK = "law_studyes_ota_version";
  var APP_VER = "2.6.5";
  var SESSION_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours auto-logout
  window.__lsAuthUnlocked = false;
  window.__lsRegPhotoBase64 = "";
  window.__lsLogoutReason = "Daily 24h Login";

  function cleanPhone(v) {
    return String(v || "").replace(/\D/g, "").slice(-10);
  }

  function getCurrentOtaTag() {
    try { return localStorage.getItem(OTA_VK) || "Built-in"; } catch (e) { return "Built-in"; }
  }

  // Returns { valid: true } or { valid: false, reason: "...", lastPhone: "..." }
  function checkSessionState() {
    var lastPhone = "";
    try { lastPhone = cleanPhone(localStorage.getItem(LAST_PH_KEY) || ""); } catch (e) {}
    try {
      var raw = localStorage.getItem(SK);
      if (!raw) return { valid: false, reason: "First Login", lastPhone: lastPhone };
      var parsed = JSON.parse(raw);
      if (!parsed || parsed.sheetVerified !== true || !parsed.student) {
        return { valid: false, reason: "Unverified Session", lastPhone: lastPhone };
      }
      var ph = cleanPhone(parsed.student.phone);
      var nm = String(parsed.student.name || "").trim();
      if (ph.length !== 10 || nm.length < 2) {
        return { valid: false, reason: "Invalid Profile", lastPhone: lastPhone };
      }
      if (!lastPhone) lastPhone = ph;

      // 1. Force re-login with phone number whenever App or OTA version updated
      var curOta = getCurrentOtaTag();
      if (parsed.verifiedAppVer !== APP_VER || parsed.verifiedOtaVer !== curOta) {
        return { valid: false, reason: "Post-Update Login (v" + APP_VER + ")", lastPhone: ph };
      }

      // 2. Force auto-logout every 24 hours for daily active user verification
      var vTime = parsed.verifiedAt ? Date.parse(parsed.verifiedAt) : 0;
      if (!vTime || (Date.now() - vTime) >= SESSION_TTL_MS) {
        return { valid: false, reason: "Daily 24h Login", lastPhone: ph };
      }

      return { valid: true, student: parsed.student, lastPhone: ph };
    } catch (e) {
      return { valid: false, reason: "Session Reset", lastPhone: lastPhone };
    }
  }

  function switchOverlayToLoginTab(ov, prefillPhone, reasonText) {
    if (!ov) return;
    // Click the Login tab button if present so returning users land straight on 1-tap phone login
    if (prefillPhone && prefillPhone.length === 10) {
      ov.querySelectorAll("button").forEach(function (b) {
        var t = (b.textContent || "").trim().toLowerCase();
        var id = (b.id || "").toLowerCase();
        if ((t === "login" || t === "existing student" || t.indexOf("login") !== -1 || id.indexOf("logintab") !== -1) && b.type === "button") {
          try { b.click(); } catch (e) {}
        }
      });
      var lp = ov.querySelector("#loginPhoneInput");
      if (lp && !lp.value) lp.value = prefillPhone;
      var loginForm = lp && lp.closest ? lp.closest("form") : null;
      if (loginForm && reasonText) {
        var box = loginForm.querySelector(".ls-sheet-status-bar");
        if (!box) {
          box = document.createElement("div");
          box.className = "ls-sheet-status-bar";
          loginForm.appendChild(box);
        }
        showAuthMsg(box, reasonText + " - Tap Login to verify your mobile number.", "info");
      }
    }
  }

  function lockApp(reason, prefillPhone) {
    window.__lsAuthUnlocked = false;
    window.__lsLogoutReason = reason || "Daily 24h Login";
    try { localStorage.removeItem(SK); } catch (e) {}
    var ov = document.getElementById("lawStudyesAuthOverlay");
    if (ov) {
      ov.classList.remove("hidden");
      ov.style.display = "flex";
      switchOverlayToLoginTab(ov, prefillPhone, reason);
    }
    document.body.classList.add("ls-auth-locked");
  }

  function unlockApp(student) {
    window.__lsAuthUnlocked = true;
    var curOta = getCurrentOtaTag();
    try {
      var all = {};
      try { all = JSON.parse(localStorage.getItem(RK) || "{}"); } catch (e) {}
      all[student.phone] = student;
      localStorage.setItem(RK, JSON.stringify(all));
      localStorage.setItem(LAST_PH_KEY, student.phone);
      localStorage.setItem(SK, JSON.stringify({
        student: student,
        sheetVerified: true,
        verifiedAt: new Date().toISOString(),
        verifiedAppVer: APP_VER,
        verifiedOtaVer: curOta
      }));
    } catch (e) {}
    var ov = document.getElementById("lawStudyesAuthOverlay");
    if (ov) {
      ov.classList.add("hidden");
      ov.style.display = "none";
    }
    document.body.classList.remove("ls-auth-locked");
  }

  function showAuthMsg(box, text, kind) {
    if (!box) return;
    box.textContent = text;
    box.className = "ls-sheet-status-bar show " + (kind || "info");
  }

  function compressImageFile(file) {
    return new Promise(function (resolve, reject) {
      var reader = new FileReader();
      reader.onerror = function () { reject(new Error("Could not read photo file.")); };
      reader.onload = function () {
        var img = new Image();
        img.onerror = function () { reject(new Error("Invalid image file.")); };
        img.onload = function () {
          var maxDim = 320;
          var w = img.width, h = img.height;
          if (w > h && w > maxDim) { h = Math.round(h * maxDim / w); w = maxDim; }
          else if (h >= w && h > maxDim) { w = Math.round(w * maxDim / h); h = maxDim; }
          var canvas = document.createElement("canvas");
          canvas.width = w;
          canvas.height = h;
          var ctx = canvas.getContext("2d");
          ctx.drawImage(img, 0, 0, w, h);
          resolve(canvas.toDataURL("image/jpeg", 0.72));
        };
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
  }

  function injectPhotoPicker(regForm) {
    if (!regForm || regForm.querySelector("#lsRegPhotoBox")) return;
    var box = document.createElement("div");
    box.id = "lsRegPhotoBox";
    box.className = "ls-photo-picker";
    box.innerHTML =
      '<div id="lsPhotoPreview" class="ls-photo-avatar">Photo</div>' +
      '<div style="flex:1;min-width:0;">' +
        '<div style="font-size:12px;font-weight:700;color:#1F1B18;">Student Photo (Required)</div>' +
        '<div id="lsPhotoHint" style="font-size:11px;color:#5F554E;">Take a live selfie or choose from gallery</div>' +
        '<div class="ls-photo-actions">' +
          '<button type="button" id="lsSelfieBtn" class="ls-photo-btn ls-photo-btn-cam">Take Selfie</button>' +
          '<button type="button" id="lsGalleryBtn" class="ls-photo-btn ls-photo-btn-gal">Upload Gallery</button>' +
        '</div>' +
        '<input type="file" id="lsSelfieInput" accept="image/*" capture="user" style="display:none;" />' +
        '<input type="file" id="lsGalleryInput" accept="image/*" style="display:none;" />' +
      '</div>';

    var submitBtn = regForm.querySelector('button[type="submit"], button:not([type="button"])');
    if (submitBtn && submitBtn.parentNode) submitBtn.parentNode.insertBefore(box, submitBtn);
    else regForm.appendChild(box);

    var sIn = box.querySelector("#lsSelfieInput");
    var gIn = box.querySelector("#lsGalleryInput");
    var prev = box.querySelector("#lsPhotoPreview");
    var hint = box.querySelector("#lsPhotoHint");

    box.querySelector("#lsSelfieBtn").addEventListener("click", function () { sIn.value = ""; sIn.click(); });
    box.querySelector("#lsGalleryBtn").addEventListener("click", function () { gIn.value = ""; gIn.click(); });

    async function onFilePicked(ev) {
      var f = ev.target && ev.target.files && ev.target.files[0];
      if (!f) return;
      hint.textContent = "Optimizing photo...";
      try {
        var b64 = await compressImageFile(f);
        window.__lsRegPhotoBase64 = b64;
        prev.innerHTML = '<img src="' + b64 + '" alt="Student Selfie" />';
        var kb = Math.round((b64.length * 3) / 4 / 1024);
        hint.textContent = "Photo ready (" + kb + " KB) - will save to Sheet";
      } catch (err) {
        hint.textContent = "Photo error: " + (err && err.message ? err.message : String(err));
      }
    }
    sIn.addEventListener("change", onFilePicked);
    gIn.addEventListener("change", onFilePicked);
  }

  async function saveToGoogleSheet(student) {
    if (!navigator.onLine) {
      throw new Error("Internet connection required to save your registration & photo.");
    }
    var payload = Object.assign({}, student, {
      appVersion: APP_VER,
      photoBase64: window.__lsRegPhotoBase64 || ""
    });
    var r = await fetch(SHEET_API, {
      method: "POST",
      redirect: "follow",
      cache: "no-store",
      headers: { "Content-Type": "text/plain;charset=utf-8" },
      body: JSON.stringify(payload)
    });
    if (!r.ok) throw new Error("Sheet server HTTP " + r.status);
    var txt = await r.text();
    if (/<!doctype|<html|unable to open/i.test(txt)) {
      throw new Error("Apps Script returned HTML error. Re-deploy Web App with access=Anyone.");
    }
    var data = JSON.parse(txt);
    if (data && data.ok === true) {
      var saved = data.student || student;
      if (window.__lsRegPhotoBase64) saved.photoPreview = window.__lsRegPhotoBase64;
      return saved;
    }
    throw new Error((data && data.error) || "Could not confirm save in Google Sheet.");
  }

  async function verifyAndLogDailyLogin(phone, reason) {
    if (!navigator.onLine) {
      throw new Error("Internet connection required for daily mobile number verification.");
    }
    var qs = new URLSearchParams({
      action: "login",
      phone: phone,
      log: "1",
      appVersion: APP_VER,
      reason: reason || "Daily 24h Login",
      t: String(Date.now())
    });
    var r = await fetch(SHEET_API + "?" + qs.toString(), {
      method: "GET",
      redirect: "follow",
      cache: "no-store"
    });
    if (!r.ok) throw new Error("Sheet verification HTTP " + r.status);
    var txt = await r.text();
    if (/<!doctype|<html|unable to open/i.test(txt)) {
      throw new Error("Sheet server unreachable.");
    }
    var data = JSON.parse(txt);
    if (!data || data.ok !== true) throw new Error((data && data.error) || "Verification failed.");
    return (data.found && data.student) ? data.student : null;
  }

  function enforceSessionCheck() {
    var st = checkSessionState();
    if (st.valid) {
      window.__lsAuthUnlocked = true;
      var ov = document.getElementById("lawStudyesAuthOverlay");
      if (ov) { ov.classList.add("hidden"); ov.style.display = "none"; }
      document.body.classList.remove("ls-auth-locked");
    } else {
      lockApp(st.reason, st.lastPhone);
    }
  }

  function wireStrictAuthOverlay() {
    var ov = document.getElementById("lawStudyesAuthOverlay");
    if (!ov) return;

    ov.querySelectorAll("form").forEach(function (f) {
      if (!f.querySelector("#loginPhoneInput")) injectPhotoPicker(f);
    });

    if (ov.__lsStrictAuth265) return;
    ov.__lsStrictAuth265 = true;

    ov.querySelectorAll("button").forEach(function (b) {
      var t = (b.textContent || "").toLowerCase();
      var id = (b.id || "").toLowerCase();
      if (id === "lsselfiebtn" || id === "lsgallerybtn") return;
      if (t.indexOf("skip") !== -1 || t.indexOf("later") !== -1 || t.indexOf("guest") !== -1 || id.indexOf("skip") !== -1 || id.indexOf("close") !== -1) {
        b.style.display = "none";
      }
    });

    if (!window.__lsAuthObserver) {
      window.__lsAuthObserver = new MutationObserver(function () {
        if (!window.__lsAuthUnlocked && !checkSessionState().valid) {
          if (ov.classList.contains("hidden") || ov.style.display === "none") {
            var s = checkSessionState();
            lockApp(s.reason, s.lastPhone);
          }
        }
      });
      window.__lsAuthObserver.observe(ov, { attributes: true, attributeFilter: ["class", "style"] });
    }

    enforceSessionCheck();

    // Re-check 24h expiry whenever user returns to the app or every 60 seconds
    document.addEventListener("visibilitychange", function () {
      if (document.visibilityState === "visible") enforceSessionCheck();
    });
    setInterval(enforceSessionCheck, 60000);

    ov.addEventListener("submit", async function (ev) {
      var form = ev.target;
      if (!form || form.tagName !== "FORM") return;
      ev.preventDefault();
      ev.stopImmediatePropagation();

      var statusBox = form.querySelector(".ls-sheet-status-bar");
      if (!statusBox) {
        statusBox = document.createElement("div");
        statusBox.className = "ls-sheet-status-bar";
        form.appendChild(statusBox);
      }

      var loginPhoneInput = form.querySelector("#loginPhoneInput");
      var submitBtn = form.querySelector('button[type="submit"], button:not([type="button"])');
      var origBtnTxt = submitBtn ? submitBtn.textContent : "";

      try {
        if (loginPhoneInput) {
          var lPhone = cleanPhone(loginPhoneInput.value);
          if (lPhone.length !== 10) {
            showAuthMsg(statusBox, "Enter your registered 10-digit mobile number.", "err");
            return;
          }
          if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = "Verifying..."; }
          showAuthMsg(statusBox, "Verifying mobile number & logging daily attendance...", "info");
          var foundStudent = await verifyAndLogDailyLogin(lPhone, window.__lsLogoutReason || "Daily 24h Login");
          if (!foundStudent) {
            showAuthMsg(statusBox, "Mobile number not registered yet. Please switch to Register tab first.", "err");
            return;
          }
          showAuthMsg(statusBox, "Verified! Welcome back, " + foundStudent.name, "ok");
          unlockApp(foundStudent);
          if (typeof showToast === "function") showToast("Verified! Welcome back, " + foundStudent.name);
        } else {
          var phoneEl = form.querySelector('input[type="tel"], input[id*="Phone" i], input[name*="phone" i]');
          var nameEl = form.querySelector('input[id*="Name" i], input[name*="name" i], input[type="text"]');
          var selects = Array.from(form.querySelectorAll("select"));
          var sSel = form.querySelector('select[id*="State" i]') || selects[0];
          var uSel = form.querySelector('select[id*="Univ" i]') || selects[1];
          var cSel = form.querySelector('select[id*="Coll" i]') || selects[2];
          var ySel = form.querySelector('select[id*="Year" i]') || selects[3];
          var smSel = form.querySelector('select[id*="Sem" i]') || selects[4];
          var cCus = form.querySelector('input[id*="Custom" i], input[id*="Other" i]');

          var phone = cleanPhone(phoneEl ? phoneEl.value : "");
          var name = (nameEl ? nameEl.value : "").trim();
          if (name.length < 2) { showAuthMsg(statusBox, "Please enter your full name.", "err"); return; }
          if (phone.length !== 10) { showAuthMsg(statusBox, "Please enter a valid 10-digit mobile number.", "err"); return; }
          if (!window.__lsRegPhotoBase64) {
            showAuthMsg(statusBox, "Please take a selfie or upload a photo from gallery.", "err");
            return;
          }

          var college = cSel ? (cSel.value === "__OTHER__" ? (cCus ? cCus.value.trim() : "") : cSel.value) : "";
          var student = {
            phone: phone,
            name: name,
            state: sSel ? sSel.value : "",
            university: uSel ? uSel.value : "",
            college: college,
            year: ySel ? ySel.value : "",
            semester: smSel ? smSel.value : "",
            registeredAt: new Date().toISOString()
          };

          if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = "Uploading Photo & Saving..."; }
          showAuthMsg(statusBox, "Uploading photo & saving registration to Google Sheet...", "info");
          var savedStudent = await saveToGoogleSheet(student);
          showAuthMsg(statusBox, "Saved (Sl. No #" + (savedStudent.slNo || "") + ")! Welcome, " + savedStudent.name, "ok");
          unlockApp(savedStudent);
          if (typeof showToast === "function") showToast("Registered with photo! Welcome, " + savedStudent.name);
        }
      } catch (err) {
        showAuthMsg(statusBox, "Could not verify/save: " + (err && err.message ? err.message : String(err)), "err");
      } finally {
        if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = origBtnTxt; }
      }
    }, true);
  }

  window.addEventListener("DOMContentLoaded", function () {
    wireStrictAuthOverlay();
    setTimeout(wireStrictAuthOverlay, 350);
  });
})();
</script>
<!-- LS_STRICT_SHEET_AUTH_END -->
</body>
'@
$authBlock = $authBlock.Replace("__SHEET_API_URL__", $SheetApiUrl)
$h = $h.Replace('</body>', $authBlock)
[System.IO.File]::WriteAllText($idx, $h, $u)

$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_265_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS error(s) found in www/index.html!" }
Write-Host "[PASS] All $i inline JS blocks verified (0 errors)! 24h Auto-Logout + Post-Update Re-Login wired." -ForegroundColor Green

Write-Host "`n=== 4. Building Clean Signed Release APK v$ver (versionCode $verCode) ===" -ForegroundColor Cyan
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

Remove-Item (Join-Path $root "www\LawStudyes-Offline.apk"), (Join-Path $root "www\ota-bundle.zip") -ErrorAction SilentlyContinue
npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

Push-Location ".\android"
try {
  .\gradlew.bat assembleRelease
  if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
} finally {
  Pop-Location
}

$apk = ".\android\app\build\outputs\apk\release\app-release.apk"
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-24hLogin-DailyUsage-OTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 5. Pushing Full-Diagram + 24h Daily Usage OTA to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
