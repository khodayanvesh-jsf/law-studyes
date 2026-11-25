var SHEET_NAME = "Registrations";
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

function getRegSheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
  if (sh.getLastRow() === 0) {
    sh.appendRow(HEADERS);
    sh.setFrozenRows(1);
    return sh;
  }
  // Auto-migrate older sheet: insert "Sl. No" as Column A if missing
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
  // Ensure all 12 headers (including Photo & Photo URL) exist
  var maxCols = sh.getLastColumn();
  if (maxCols < HEADERS.length) {
    sh.insertColumnsAfter(maxCols, HEADERS.length - maxCols);
  }
  sh.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
  sh.setFrozenRows(1);
  return sh;
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
    return {
      imgFormula: '=IMAGE("' + directImg + '", 1)',
      url: viewUrl
    };
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
    var appV = String(d.appVersion || "2.6.4").trim();

    // Update existing row if phone already exists (keeps original Sl. No)
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
          return {
            ok: true,
            updated: true,
            student: {
              slNo: slNo, registeredAt: regAt, phone: ph, name: nm,
              state: state, university: univ, college: col, year: yr,
              semester: sem, appVersion: appV, photoUrl: finalUrl
            }
          };
        }
      }
    }

    var nextSl = (lr >= 2) ? lr : 1;
    var newRow = [nextSl, regAt, "'" + ph, nm, state, univ, col, yr, sem, appV, photoInfo.imgFormula, photoInfo.url];
    sh.appendRow(newRow);
    var appendedRow = sh.getLastRow();
    if (photoInfo.imgFormula) sh.setRowHeight(appendedRow, 64);
    return {
      ok: true,
      created: true,
      student: {
        slNo: nextSl, registeredAt: regAt, phone: ph, name: nm,
        state: state, university: univ, college: col, year: yr,
        semester: sem, appVersion: appV, photoUrl: photoInfo.url
      }
    };
  } finally {
    lock.releaseLock();
  }
}

function findStudent_(raw) {
  var ph = cleanPhone_(raw);
  if (ph.length !== 10) return { ok: false, found: false, error: "Invalid phone." };
  var sh = getRegSheet_();
  var lr = sh.getLastRow();
  if (lr < 2) return { ok: true, found: false };
  var rows = sh.getRange(2, 1, lr - 1, HEADERS.length).getDisplayValues();
  for (var i = rows.length - 1; i >= 0; i--) {
    if (cleanPhone_(rows[i][2]) === ph) {
      return {
        ok: true,
        found: true,
        student: {
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
        }
      };
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
      getRegSheet_(); // Auto-applies Sl. No + Photo columns immediately on ping!
      return jsonOut_({ ok: true, version: "2.6.4", service: "LawStudyes-Registrations", sheet: SHEET_NAME, columns: HEADERS });
    }
    if (a === "register") return jsonOut_(saveStudent_(p));
    if (p.phone) return jsonOut_(findStudent_(p.phone));
    return jsonOut_({ ok: true, version: "2.6.4", status: "ready" });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}
