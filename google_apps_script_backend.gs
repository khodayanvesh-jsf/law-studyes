/**
 * Law Studyes — 100% Free Forever Student Registration API (Google Sheets)
 * Setup:
 *   1. Open sheets.new -> name it "Law Studyes Students"
 *   2. Click Extensions -> Apps Script -> delete default code -> paste this file -> Save
 *   3. Click Deploy -> New deployment -> Select type: Web app
 *      - Execute as: Me
 *      - Who has access: Anyone
 *   4. Click Deploy -> Authorize -> Copy the Web app URL (ends with /exec)
 */
const SHEET_NAME = 'Students';
const HEADERS = [
  'phone', 'full_name', 'state', 'university', 'college',
  'course_year', 'semester', 'preferred_lang', 'registered_at', 'last_login_at'
];

function getSheet_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow(HEADERS);
    sh.setFrozenRows(1);
  }
  return sh;
}

function jsonOut_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

// Phone-only login lookup: GET ?phone=9876543210
function doGet(e) {
  try {
    const phone = String((e && e.parameter && e.parameter.phone) || '').replace(/\D/g, '');
    if (phone.length !== 10) return jsonOut_({ ok: false, error: 'Invalid phone' });
    const sh = getSheet_();
    const rows = sh.getDataRange().getValues();
    for (let i = 1; i < rows.length; i++) {
      if (String(rows[i][0]).replace(/\D/g, '') === phone) {
        const nowIso = new Date().toISOString();
        sh.getRange(i + 1, 10).setValue(nowIso);
        return jsonOut_({
          ok: true,
          student: {
            phone: String(rows[i][0]),
            name: String(rows[i][1]),
            state: String(rows[i][2]),
            university: String(rows[i][3]),
            college: String(rows[i][4]),
            year: String(rows[i][5]),
            semester: String(rows[i][6]),
            preferred_lang: String(rows[i][7] || 'en'),
            registeredAt: String(rows[i][8] || '')
          }
        });
      }
    }
    return jsonOut_({ ok: false, notFound: true });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}

// Register or update student: POST JSON body
function doPost(e) {
  try {
    const raw = (e && e.postData && e.postData.contents) ? e.postData.contents : '{}';
    const data = JSON.parse(raw);
    const phone = String(data.phone || '').replace(/\D/g, '');
    if (phone.length !== 10) return jsonOut_({ ok: false, error: 'Invalid 10-digit phone' });

    const sh = getSheet_();
    const rows = sh.getDataRange().getValues();
    const nowIso = new Date().toISOString();
    const rowValues = [
      phone,
      String(data.name || '').trim(),
      String(data.state || '').trim(),
      String(data.university || '').trim(),
      String(data.college || '').trim(),
      String(data.year || 'Year 1'),
      String(data.semester || 'Semester I'),
      String(data.preferred_lang || 'en'),
      String(data.registeredAt || nowIso),
      nowIso
    ];

    for (let i = 1; i < rows.length; i++) {
      if (String(rows[i][0]).replace(/\D/g, '') === phone) {
        rowValues[8] = String(rows[i][8] || nowIso); // preserve original registered_at
        sh.getRange(i + 1, 1, 1, HEADERS.length).setValues([rowValues]);
        return jsonOut_({ ok: true, updated: true });
      }
    }

    sh.appendRow(rowValues);
    return jsonOut_({ ok: true, created: true });
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err) });
  }
}