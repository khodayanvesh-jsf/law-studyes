var SHEET_NAME = "Registrations";
var HEADERS = ["Registered At","Phone","Student Name","State","University","College","Year","Semester","App Version"];
function getRegSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
  if (sh.getLastRow() === 0) { sh.appendRow(HEADERS); sh.setFrozenRows(1); }
  return sh;
}
function cleanPhone_(v) { return String(v || "").replace(/\D/g, "").slice(-10); }
function jsonOut_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }
function saveStudent_(d) {
  var ph = cleanPhone_(d.phone), nm = String(d.name || "").trim();
  if (ph.length !== 10 || !nm) return { ok: false, error: "Valid 10-digit phone and name required." };
  var lock = LockService.getScriptLock(); lock.waitLock(15000);
  try {
    var sh = getRegSheet_(), lr = sh.getLastRow();
    var row = [String(d.registeredAt || new Date().toISOString()), "'" + ph, nm, String(d.state || "").trim(), String(d.university || "").trim(), String(d.college || "").trim(), String(d.year || "").trim(), String(d.semester || "").trim(), String(d.appVersion || "2.6.3").trim()];
    var st = { registeredAt: row[0], phone: ph, name: row[2], state: row[3], university: row[4], college: row[5], year: row[6], semester: row[7], appVersion: row[8] };
    if (lr >= 2) {
      var phones = sh.getRange(2, 2, lr - 1, 1).getDisplayValues();
      for (var i = 0; i < phones.length; i++) {
        if (cleanPhone_(phones[i][0]) === ph) { sh.getRange(i + 2, 1, 1, row.length).setValues([row]); return { ok: true, updated: true, student: st }; }
      }
    }
    sh.appendRow(row);
    return { ok: true, created: true, student: st };
  } finally { lock.releaseLock(); }
}
function findStudent_(raw) {
  var ph = cleanPhone_(raw); if (ph.length !== 10) return { ok: false, found: false, error: "Invalid phone." };
  var sh = getRegSheet_(), lr = sh.getLastRow(); if (lr < 2) return { ok: true, found: false };
  var rows = sh.getRange(2, 1, lr - 1, HEADERS.length).getDisplayValues();
  for (var i = rows.length - 1; i >= 0; i--) {
    if (cleanPhone_(rows[i][1]) === ph) {
      return { ok: true, found: true, student: { registeredAt: rows[i][0], phone: ph, name: rows[i][2], state: rows[i][3], university: rows[i][4], college: rows[i][5], year: rows[i][6], semester: rows[i][7], appVersion: rows[i][8] } };
    }
  }
  return { ok: true, found: false };
}
function doPost(e) { try { return jsonOut_(saveStudent_(JSON.parse((e && e.postData && e.postData.contents) ? e.postData.contents : "{}"))); } catch (err) { return jsonOut_({ ok: false, error: String(err) }); } }
function doGet(e) {
  try {
    var p = (e && e.parameter) ? e.parameter : {}, a = String(p.action || "").toLowerCase();
    if (a === "ping") return jsonOut_({ ok: true, service: "LawStudyes-Registrations", sheet: SHEET_NAME });
    if (a === "register") return jsonOut_(saveStudent_(p));
    if (p.phone) return jsonOut_(findStudent_(p.phone));
    return jsonOut_({ ok: true, status: "ready" });
  } catch (err) { return jsonOut_({ ok: false, error: String(err) }); }
}