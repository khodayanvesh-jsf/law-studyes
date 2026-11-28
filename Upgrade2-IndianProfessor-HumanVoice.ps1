param(
  [switch]$GenerateSampleAudio,
  [int]$SampleCount = 5,
  [ValidateSet("female", "male")]
  [string]$VoiceGender = "female"
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$wwwDir = Join-Path $root "www"
$modDir = Join-Path $wwwDir "js\modules"
$scriptsDir = Join-Path $root "scripts"
$audioDir = Join-Path $wwwDir "audio"
New-Item -ItemType Directory -Path $modDir, $scriptsDir, $audioDir -Force | Out-Null

Write-Host "`n=== 1. Installing Real Human Neural Voice Generator (scripts/generate_professor_audio.py) ===" -ForegroundColor Cyan
$pyAudioGen = @'
import asyncio, json, re, sys
from pathlib import Path

try:
    import edge_tts
except ImportError:
    print("[INSTALL] edge-tts not installed. Install once with: pip install edge-tts", flush=True)
    sys.exit(2)

VOICES = {
    "en": {"female": "en-IN-NeerjaNeural", "male": "en-IN-PrabhatNeural"},
    "te": {"female": "te-IN-ShrutiNeural", "male": "te-IN-MohanNeural"},
    "hi": {"female": "hi-IN-SwaraNeural",  "male": "hi-IN-MadhurNeural"},
}

def clean_text(s):
    s = re.sub(r"<[^>]+>", " ", str(s or ""))
    s = re.sub(r"\s+", " ", s).strip()
    return s

def build_professor_script(topic_title, ld, lang):
    one_min = clean_text(ld.get("inOneMinute", ""))
    prov = clean_text(ld.get("legalProvision", ""))
    meaning = clean_text(ld.get("meaning", ""))
    kp = ld.get("keyPoints") or []
    cases = ld.get("caseLaws") or []

    kp_lines = []
    for item in kp[:5]:
        if isinstance(item, str) and item.strip():
            kp_lines.append(clean_text(item))
        elif isinstance(item, dict):
            val = clean_text(item.get("point") or item.get("text") or item.get("summary") or "")
            if val:
                kp_lines.append(val)

    case_line = ""
    if cases:
        c0 = cases[0]
        if isinstance(c0, str):
            case_line = clean_text(c0)
        elif isinstance(c0, dict):
            cname = clean_text(c0.get("name") or c0.get("title") or "")
            csum = clean_text(c0.get("principle") or c0.get("summary") or "")
            case_line = f"{cname}: {csum}".strip(": ")

    parts = []
    if lang == "te":
        parts.append(f"\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d! \u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 {topic_title} \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c1a\u0c3e\u0c32\u0c3e \u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d\u200c\u0c17\u0c3e, \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d \u0c38\u0c4d\u0c1f\u0c48\u0c32\u0c4d\u200c\u0c32\u0c4b \u0c28\u0c47\u0c30\u0c4d\u0c1a\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02.")
        if one_min:
            parts.append(f"\u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c12\u0c15\u0c4d\u0c15 \u0c2e\u0c3e\u0c1f\u0c32\u0c4b \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f: {one_min}")
        if prov:
            parts.append(f"\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d\u200c\u0c32\u0c4b \u0c24\u0c2a\u0c4d\u0c2a\u0c15\u0c41\u0c02\u0c21\u0c3e \u0c30\u0c3e\u0c2f\u0c3e\u0c32\u0c4d\u0c38\u0c3f\u0c28 \u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d \u0c2e\u0c30\u0c3f\u0c2f\u0c41 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28 \u0c07\u0c26\u0c3f: {prov}")
        if meaning:
            parts.append(f"\u0c07\u0c2a\u0c4d\u0c2a\u0c41\u0c21\u0c41 \u0c26\u0c40\u0c28\u0c3f \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c38\u0c4d\u0c2a\u0c37\u0c4d\u0c1f\u0c02\u0c17\u0c3e \u0c1a\u0c42\u0c26\u0c4d\u0c26\u0c3e\u0c02: {meaning}")
        if kp_lines:
            parts.append("\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c2a\u0c47\u0c2a\u0c30\u0c4d\u200c\u0c32\u0c4b \u0c2e\u0c3e\u0c30\u0c4d\u0c15\u0c41\u0c32\u0c41 \u0c24\u0c46\u0c1a\u0c4d\u0c1a\u0c47 \u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41: " + ". ".join(kp_lines))
        if case_line:
            parts.append(f"\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e \u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41\u0c2a\u0c46\u0c1f\u0c4d\u0c1f\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f: {case_line}")
        parts.append("\u0c30\u0c3f\u0c35\u0c3f\u0c1c\u0c28\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d: \u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d \u0c30\u0c3e\u0c38\u0c3f, \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41 \u0c2e\u0c30\u0c3f\u0c2f\u0c41 \u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e \u0c1c\u0c24 \u0c1a\u0c47\u0c38\u0c4d\u0c24\u0c47 \u0c2b\u0c41\u0c32\u0c4d \u0c2e\u0c3e\u0c30\u0c4d\u0c15\u0c41\u0c32\u0c41 \u0c16\u0c3e\u0c2f\u0c02!")
    elif lang == "hi":
        parts.append(f"\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938! \u0906\u091c \u0939\u092e {topic_title} \u0915\u094b \u092c\u093f\u0932\u094d\u0915\u0941\u0932 \u0906\u0938\u093e\u0928 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0905\u0902\u0926\u093e\u091c \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964")
        if one_min:
            parts.append(f"\u0938\u092c\u0938\u0947 \u092a\u0939\u0932\u0947 \u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902 \u0905\u0938\u0932\u0940 \u092c\u093e\u0924 \u0938\u092e\u091d\u093f\u090f: {one_min}")
        if prov:
            parts.append(f"\u090f\u0917\u094d\u091c\u093e\u092e \u092e\u0947\u0902 \u0938\u0940\u0927\u093e \u092f\u0939\u0940 \u0938\u0947\u0915\u094d\u0936\u0928 \u092a\u0942\u091b\u093e \u091c\u093e\u0924\u093e \u0939\u0948: {prov}")
        if meaning:
            parts.append(f"\u0905\u092c \u0907\u0938\u0915\u093e \u092e\u0924\u0932\u092c \u0927\u094d\u092f\u093e\u0928 \u0938\u0947 \u0938\u092e\u091d\u093f\u090f: {meaning}")
        if kp_lines:
            parts.append("\u0906\u0902\u0938\u0930 \u0936\u0940\u091f \u092e\u0947\u0902 \u092f\u0947 \u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938 \u091c\u0930\u0942\u0930 \u0932\u093f\u0916\u093f\u090f: " + ". ".join(kp_lines))
        if case_line:
            parts.append(f"\u092f\u0939 \u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949 \u092f\u093e\u0926 \u0930\u0916\u093f\u090f: {case_line}")
        parts.append("\u090f\u0917\u094d\u091c\u093e\u092e \u091f\u093f\u092a: \u0936\u0941\u0930\u0941\u0906\u0924 \u0938\u0947\u0915\u094d\u0936\u0928 \u0938\u0947 \u0915\u0930\u0947\u0902, \u092b\u093f\u0930 \u092a\u0949\u0907\u0902\u091f\u094d\u0938 \u0914\u0930 \u0915\u0947\u0938 \u0932\u0949 \u0932\u093f\u0916\u0947\u0902, \u092c\u0922\u093c\u093f\u092f\u093e \u0928\u0902\u092c\u0930 \u092a\u0915\u094d\u0915\u0947 \u0939\u0948\u0902!")
    else:
        parts.append(f"Hello students! Let us understand {topic_title} in simple Indian classroom style, zero confusion.")
        if one_min:
            parts.append(f"First, catch the core idea in one minute: {one_min}")
        if prov:
            parts.append(f"Now note the exact legal provision for your exam answer: {prov}")
        if meaning:
            parts.append(f"Here is what it actually means in plain words: {meaning}")
        if kp_lines:
            parts.append("Remember these scoring key points for the exam hall: " + ". ".join(kp_lines))
        if case_line:
            parts.append(f"And do not forget to quote this leading case law: {case_line}")
        parts.append("Quick exam tip: start with the section number, write crisp bullet points, underline the case name, and you are set for top marks!")
    return " ".join(parts)[:3200]

async def synth_one(text, voice, out_file):
    out_file.parent.mkdir(parents=True, exist_ok=True)
    comm = edge_tts.Communicate(text, voice, rate="-2%")
    await comm.save(str(out_file))

async def main():
    db_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("www/nyayasaral_db.json")
    audio_root = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("www/audio")
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 5
    gender = sys.argv[4] if len(sys.argv) > 4 else "female"
    langs = (sys.argv[5].split(",") if len(sys.argv) > 5 else ["en", "te", "hi"])

    data = json.loads(db_file.read_text(encoding="utf-8"))
    notes = data.get("notes", {})
    titles = {}
    for subj in data.get("subjects", []):
        for unit in subj.get("units", []):
            for t in unit.get("topics", []):
                if isinstance(t, dict) and t.get("id"):
                    titles[t["id"]] = t.get("title", t["id"])

    topic_ids = list(notes.keys())
    if limit > 0:
        topic_ids = topic_ids[:limit]

    manifest_path = audio_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}

    done = 0
    for tid in topic_ids:
        rec = notes.get(tid, {})
        t_title = titles.get(tid, tid.replace("-", " ").title())
        for lang in langs:
            ld = rec.get(lang)
            if not isinstance(ld, dict):
                continue
            out_mp3 = audio_root / lang / f"{tid}.mp3"
            if out_mp3.exists() and out_mp3.stat().st_size > 2048:
                manifest.setdefault(lang, {})[tid] = f"./audio/{lang}/{tid}.mp3"
                continue
            script = build_professor_script(t_title, ld, lang)
            voice = VOICES.get(lang, VOICES["en"]).get(gender, VOICES["en"]["female"])
            try:
                await synth_one(script, voice, out_mp3)
                manifest.setdefault(lang, {})[tid] = f"./audio/{lang}/{tid}.mp3"
                done += 1
                print(f"  [AUDIO OK] {lang}/{tid}.mp3 ({voice}, {out_mp3.stat().st_size // 1024} KB)", flush=True)
            except Exception as ex:
                print(f"  [AUDIO SKIP] {lang}/{tid}: {ex}", flush=True)

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
    print(f"[PASS] Studio Neural Audio generated: {done} new MP3 file(s) | Manifest updated -> {manifest_path}", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
'@

$pyAudioPath = Join-Path $scriptsDir "generate_professor_audio.py"
[System.IO.File]::WriteAllText($pyAudioPath, $pyAudioGen, $u)
python -m py_compile $pyAudioPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in scripts/generate_professor_audio.py!" }
Write-Host "[PASS] scripts/generate_professor_audio.py installed & verified." -ForegroundColor Green

Write-Host "`n=== 2. Installing AI Indian Professor Module (www/js/modules/ls-indian-professor.js) ===" -ForegroundColor Cyan
$profJs = @'
(function () {
  "use strict";
  if (window.__lsIndianProfessorV320) return;
  window.__lsIndianProfessorV320 = true;

  var PREF_STYLE_KEY = "ls_prof_style_v1";
  var PREF_GENDER_KEY = "ls_prof_gender_v1";
  var AUDIO_CACHE_NAME = "ls-prof-audio-v1";
  var CDN_BASE = "https://law-studyes.vercel.app";

  var audioManifest = null;
  var htmlAudio = null;
  var profPlaying = false;
  var profPaused = false;
  var activeSentenceIdx = 0;
  var activeSentences = [];
  var speakToken = 0;

  function getStyle() {
    try { return localStorage.getItem(PREF_STYLE_KEY) || "professor"; } catch (e) { return "professor"; }
  }
  function setStyle(v) {
    try { localStorage.setItem(PREF_STYLE_KEY, v); } catch (e) {}
  }
  function getGender() {
    try { return localStorage.getItem(PREF_GENDER_KEY) || "female"; } catch (e) { return "female"; }
  }
  function setGender(v) {
    try { localStorage.setItem(PREF_GENDER_KEY, v); } catch (e) {}
  }

  function cleanStr(s) {
    return String(s || "").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
  }

  function getActiveBcp47(lang) {
    var l = String(lang || "en").toLowerCase();
    if (l === "te") return "te-IN";
    if (l === "hi") return "hi-IN";
    return "en-IN";
  }

  function getTopicTitle(topicId) {
    try {
      if (typeof findTopicMeta === "function") {
        var meta = findTopicMeta(topicId);
        if (meta && meta.topic && meta.topic.title) return meta.topic.title;
      }
    } catch (e) {}
    return String(topicId || "Legal Topic").replace(/-/g, " ");
  }

  function extractPoints(ld) {
    var out = [];
    var kp = ld && ld.keyPoints;
    if (Array.isArray(kp)) {
      for (var i = 0; i < kp.length && out.length < 5; i++) {
        var it = kp[i];
        var txt = typeof it === "string" ? cleanStr(it) : cleanStr((it && (it.point || it.text || it.summary)) || "");
        if (txt) out.push(txt);
      }
    }
    return out;
  }

  function extractTopCase(ld) {
    var cs = ld && ld.caseLaws;
    if (!Array.isArray(cs) || !cs.length) return "";
    var c = cs[0];
    if (typeof c === "string") return cleanStr(c);
    if (c && typeof c === "object") {
      var n = cleanStr(c.name || c.title || "");
      var p = cleanStr(c.principle || c.summary || "");
      return n && p ? (n + " - " + p) : (n || p);
    }
    return "";
  }

  function buildLessonBlocks(topicId, lang) {
    var rec = (typeof state !== "undefined" && state.notes) ? state.notes[topicId] : null;
    if (!rec) return null;
    var ld = rec[lang] || rec.en;
    if (!ld) return null;

    var title = getTopicTitle(topicId);
    var oneMin = cleanStr(ld.inOneMinute);
    var prov = cleanStr(ld.legalProvision);
    var meaning = cleanStr(ld.meaning);
    var pts = extractPoints(ld);
    var topCase = extractTopCase(ld);

    if (lang === "te") {
      return {
        heading: "\u0c07\u0c02\u0c21\u0c3f\u0c2f\u0c28\u0c4d \u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d\u200c\u0c30\u0c42\u0c2e\u0c4d (AI Teaching Mode)",
        sub: "\u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d \u0c24\u0c46\u0c32\u0c41\u0c17\u0c41 \u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d \u0c35\u0c3f\u0c35\u0c30\u0c23 + \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d\u0c38\u0c4d",
        steps: [
          { tag: "\u0c15\u0c4d\u0c32\u0c3e\u0c38\u0c4d \u0c38\u0c4d\u0c1f\u0c3e\u0c30\u0c4d\u0c1f\u0c4d", text: "\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d! \u0c08\u0c30\u0c4b\u0c1c\u0c41 " + title + " \u0c1f\u0c3e\u0c2a\u0c3f\u0c15\u0c4d\u200c\u0c28\u0c3f \u0c1f\u0c46\u0c28\u0c4d\u0c37\u0c28\u0c4d \u0c32\u0c47\u0c15\u0c41\u0c02\u0c21\u0c3e \u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d\u200c\u0c17\u0c3e \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02." },
          oneMin ? { tag: "\u0c12\u0c15\u0c4d\u0c15 \u0c2e\u0c3e\u0c1f\u0c32\u0c4b \u0c38\u0c3e\u0c30\u0c3e\u0c02\u0c36\u0c02", text: "\u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c2e\u0c46\u0c2f\u0c3f\u0c28\u0c4d \u0c15\u0c3e\u0c28\u0c4d\u0c38\u0c46\u0c2a\u0c4d\u0c1f\u0c4d \u0c35\u0c3f\u0c28\u0c02\u0c21\u0c3f: " + oneMin } : null,
          prov ? { tag: "\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d \u0c39\u0c41\u0c15\u0c4d", text: "\u0c06\u0c28\u0c4d\u0c38\u0c30\u0c4d \u0c36\u0c40\u0c1f\u0c4d\u200c\u0c32\u0c4b \u0c2b\u0c38\u0c4d\u0c1f\u0c4d \u0c08 \u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d \u0c30\u0c3e\u0c2f\u0c02\u0c21\u0c3f: " + prov } : null,
          meaning ? { tag: "\u0c38\u0c30\u0c33\u0c2e\u0c48\u0c28 \u0c35\u0c3f\u0c35\u0c30\u0c23", text: meaning } : null,
          pts.length ? { tag: "\u0c2e\u0c3e\u0c30\u0c4d\u0c15\u0c41\u0c32\u0c41 \u0c24\u0c46\u0c1a\u0c4d\u0c1a\u0c47 \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41", text: "\u0c08 \u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41 \u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41\u0c02\u0c1a\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f: " + pts.join(" | ") } : null,
          topCase ? { tag: "\u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e \u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41", text: "\u0c08 \u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e \u0c24\u0c2a\u0c4d\u0c2a\u0c15\u0c41\u0c02\u0c21\u0c3e \u0c05\u0c02\u0c21\u0c30\u0c4d\u200c\u0c32\u0c48\u0c28\u0c4d \u0c1a\u0c47\u0c38\u0c3f \u0c30\u0c3e\u0c2f\u0c02\u0c21\u0c3f: " + topCase } : null,
          { tag: "\u0c2a\u0c4d\u0c30\u0c4a\u0c2b\u0c46\u0c38\u0c30\u0c4d \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d \u0c1f\u0c3f\u0c2a\u0c4d", text: "\u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d \u0c2b\u0c3e\u0c30\u0c4d\u0c2e\u0c41\u0c32\u0c3e: \u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d + \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41 + \u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e + \u0c1a\u0c3f\u0c28\u0c4d\u0c28 \u0c21\u0c2f\u0c3e\u0c17\u0c4d\u0c30\u0c2e\u0c4d \u0c35\u0c47\u0c38\u0c4d\u0c24\u0c47 \u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c3f\u0c28\u0c30\u0c4d \u0c2b\u0c41\u0c32\u0c4d \u0c2e\u0c3e\u0c30\u0c4d\u0c15\u0c41\u0c32\u0c41 \u0c35\u0c47\u0c38\u0c4d\u0c24\u0c3e\u0c30\u0c41!" }
        ].filter(Boolean)
      };
    }

    if (lang === "hi") {
      return {
        heading: "\u0907\u0902\u0921\u093f\u092f\u0928 \u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e (AI Teaching Mode)",
        sub: "\u0906\u0938\u093e\u0928 \u0939\u093f\u0902\u0926\u0940 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0938\u092e\u091d + \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u094d\u0930\u093f\u0915\u094d\u0938",
        steps: [
          { tag: "\u0915\u094d\u0932\u093e\u0938 \u0936\u0941\u0930\u0942", text: "\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938! \u091a\u0932\u093f\u090f \u0906\u091c " + title + " \u0915\u094b \u092c\u093f\u0928\u093e \u0930\u091f\u094d\u091f\u093e \u092e\u093e\u0930\u0947 \u0926\u0947\u0938\u0940 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0905\u0902\u0926\u093e\u091c \u092e\u0947\u0902 \u0938\u092e\u091d\u0924\u0947 \u0939\u0948\u0902\u0964" },
          oneMin ? { tag: "\u0905\u0938\u0932\u0940 \u0915\u0949\u0928\u094d\u0938\u0947\u092a\u094d\u091f", text: "\u0927\u094d\u092f\u093e\u0928 \u0938\u0947 \u0938\u0941\u0928\u093f\u090f, \u092a\u0942\u0930\u0947 \u091f\u0949\u092a\u093f\u0915 \u0915\u093e \u0928\u093f\u091a\u094b\u0921\u093c \u092f\u0939 \u0939\u0948: " + oneMin } : null,
          prov ? { tag: "\u090f\u0917\u094d\u091c\u093e\u092e \u0938\u0947\u0915\u094d\u0936\u0928", text: "\u0906\u0902\u0938\u0930 \u0915\u0940 \u0936\u0941\u0930\u0941\u0906\u0924 \u092e\u0947\u0902 \u092f\u0939 \u0938\u0947\u0915\u094d\u0936\u0928 \u091c\u0930\u0942\u0930 \u0932\u093f\u0916\u093f\u090f: " + prov } : null,
          meaning ? { tag: "\u0906\u0938\u093e\u0928 \u092d\u093e\u0937\u093e \u092e\u0947\u0902 \u0905\u0930\u094d\u0925", text: meaning } : null,
          pts.length ? { tag: "\u0938\u094d\u0915\u094b\u0930\u093f\u0902\u0917 \u092a\u0949\u0907\u0902\u091f\u094d\u0938", text: "\u092f\u0947 \u092e\u0941\u0916\u094d\u092f \u092c\u093e\u0924\u0947\u0902 \u092f\u093e\u0926 \u0930\u0916\u093f\u090f: " + pts.join(" | ") } : null,
          topCase ? { tag: "\u0915\u0947\u0938 \u0932\u0949 \u0939\u093f\u091f", text: "\u092f\u0939 \u0915\u0947\u0938 \u0932\u0949 \u0905\u0902\u0921\u0930\u0932\u093e\u0907\u0928 \u0915\u0930\u0915\u0947 \u0932\u093f\u0916\u0947\u0902: " + topCase } : null,
          { tag: "\u092a\u094d\u0930\u094b\u092b\u0947\u0938\u0930 \u090f\u0917\u094d\u091c\u093e\u092e \u091f\u093f\u092a", text: "\u0938\u0940\u0927\u093e \u092b\u0949\u0930\u094d\u092e\u0942\u0932\u093e: \u0938\u0947\u0915\u094d\u0936\u0928 + \u092a\u0949\u0907\u0902\u091f\u094d\u0938 + \u0915\u0947\u0938 \u0932\u0949 + \u092b\u094d\u0932\u094b\u091a\u093e\u0930\u094d\u091f \u092c\u0928\u093e \u0926\u0940\u091c\u093f\u090f, \u092c\u0922\u093c\u093f\u092f\u093e \u0928\u0902\u092c\u0930 \u092a\u0915\u094d\u0915\u0947 \u0939\u0948\u0902!" }
        ].filter(Boolean)
      };
    }

    return {
      heading: "Indian Professor Classroom (AI Teaching Mode)",
      sub: "Relatable Indian LL.B. classroom explanation + exam answer strategy",
      steps: [
        { tag: "Class Start", text: "Hello students! Relax and listen closely. Let us break down " + title + " in plain Indian classroom style so you remember it right inside the exam hall." },
        oneMin ? { tag: "Core Logic (1 Min)", text: "First, catch the heart of this topic in one minute: " + oneMin } : null,
        prov ? { tag: "Section Hook", text: "Always open your LL.B. answer with this exact provision: " + prov } : null,
        meaning ? { tag: "Plain Meaning", text: "In everyday terms, here is what the law is actually saying: " + meaning } : null,
        pts.length ? { tag: "Scoring Points", text: "Keep these exam-scoring points on your fingertips: " + pts.join(" | ") } : null,
        topCase ? { tag: "Landmark Case", text: "Quote and underline this leading case law to impress the examiner: " + topCase } : null,
        { tag: "Exam Formula", text: "Simple winning formula: Section Number + Crisp Points + Case Law + Source Flowchart = guaranteed strong marks!" }
      ].filter(Boolean)
    };
  }

  function injectCss() {
    if (document.getElementById("lsProfCssV320")) return;
    var st = document.createElement("style");
    st.id = "lsProfCssV320";
    st.textContent =
      ".ls-prof-card { margin:14px 0 16px; border-radius:16px; background:linear-gradient(135deg,#FFFBF2 0%,#FDF4F5 100%); border:1.5px solid #E5C9A8; padding:12px 14px; box-shadow:0 4px 14px rgba(123,30,43,0.06); }" +
      ".ls-prof-top { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:8px; }" +
      ".ls-prof-title { font-size:13.5px; font-weight:800; color:#7B1E2B; }" +
      ".ls-prof-sub { font-size:11px; color:#6B5B4D; font-weight:600; }" +
      ".ls-prof-controls { display:flex; flex-wrap:wrap; align-items:center; gap:6px; margin-top:10px; }" +
      ".ls-prof-btn { padding:6px 11px; border-radius:999px; border:1px solid #DFC5A4; background:#FFFFFF; color:#7B1E2B; font-size:11.5px; font-weight:800; cursor:pointer; }" +
      ".ls-prof-btn.primary { background:#7B1E2B; color:#FFFFFF; border-color:#7B1E2B; }" +
      ".ls-prof-btn.active { background:#8C6D46; color:#FFFFFF; border-color:#8C6D46; }" +
      ".ls-prof-status { font-size:11px; color:#7B1E2B; font-weight:700; margin-top:8px; }" +
      ".ls-prof-body { margin-top:10px; display:flex; flex-direction:column; gap:7px; }" +
      ".ls-prof-step { background:#FFFFFF; border:1px solid #EFE4D6; border-left:3.5px solid #7B1E2B; border-radius:10px; padding:8px 10px; font-size:12.5px; line-height:1.55; color:#231D19; }" +
      ".ls-prof-step.speaking { background:#FFF7E6; border-left-color:#B45309; box-shadow:0 0 0 2px rgba(180,83,9,0.18); }" +
      ".ls-prof-tag { display:inline-block; font-size:10px; font-weight:800; text-transform:uppercase; letter-spacing:0.3px; color:#7B1E2B; background:#FBF1F2; padding:2px 7px; border-radius:999px; margin-bottom:4px; }";
    document.head.appendChild(st);
  }

  async function loadAudioManifest() {
    if (audioManifest !== null) return audioManifest;
    audioManifest = {};
    try {
      var r = await fetch("./audio/manifest.json", { cache: "no-store" });
      if (r.ok) audioManifest = await r.json();
    } catch (e) {}
    return audioManifest;
  }

  function stopProfessorAudio() {
    speakToken++;
    profPlaying = false;
    profPaused = false;
    if (htmlAudio) {
      try { htmlAudio.pause(); htmlAudio.currentTime = 0; } catch (e) {}
      htmlAudio = null;
    }
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && typeof tts.stop === "function") { try { tts.stop().catch(function () {}); } catch (e) {} }
    if (typeof window.speechSynthesis !== "undefined") { try { window.speechSynthesis.cancel(); } catch (e) {} }
    updateProfButtons();
    highlightStep(-1);
  }

  function highlightStep(idx) {
    var steps = document.querySelectorAll("#lsProfLessonBody .ls-prof-step");
    steps.forEach(function (el, i) { el.classList.toggle("speaking", i === idx); });
  }

  function setStatusText(msg) {
    var el = document.getElementById("lsProfStatus");
    if (el) el.textContent = msg || "";
  }

  function updateProfButtons() {
    var playBtn = document.getElementById("lsProfPlayBtn");
    var stopBtn = document.getElementById("lsProfStopBtn");
    if (playBtn) {
      playBtn.textContent = profPlaying ? (profPaused ? "Resume Class" : "Pause Class") : "Listen to Professor";
    }
    if (stopBtn) stopBtn.style.display = (profPlaying || profPaused) ? "inline-block" : "none";
  }

  async function tryPlayStudioMp3(topicId, lang, myToken) {
    var manifest = await loadAudioManifest();
    var rel = (manifest && manifest[lang] && manifest[lang][topicId]) ? manifest[lang][topicId] : null;
    if (!rel) return false;

    var candidates = [rel, CDN_BASE + "/" + rel.replace(/^\.\//, "")];
    for (var i = 0; i < candidates.length; i++) {
      var url = candidates[i];
      try {
        var playUrl = url;
        if ("caches" in window) {
          var cache = await caches.open(AUDIO_CACHE_NAME);
          var hit = await cache.match(url);
          if (hit) {
            playUrl = URL.createObjectURL(await hit.blob());
          } else {
            var resp = await fetch(url);
            if (!resp.ok) continue;
            try { cache.put(url, resp.clone()); } catch (e) {}
            playUrl = URL.createObjectURL(await resp.blob());
          }
        }
        if (myToken !== speakToken) return true;
        htmlAudio = new Audio(playUrl);
        htmlAudio.onended = function () {
          profPlaying = false; profPaused = false;
          setStatusText("Class completed (Studio Human Neural Voice).");
          updateProfButtons();
        };
        htmlAudio.onerror = function () {
          if (myToken === speakToken) { htmlAudio = null; }
        };
        await htmlAudio.play();
        profPlaying = true; profPaused = false;
        setStatusText("Playing Real Human Indian Neural Voice (Studio MP3 - Offline Cached)");
        updateProfButtons();
        return true;
      } catch (e) {}
    }
    return false;
  }

  function pickBestIndianVoice(voices, bcp47, gender) {
    if (!Array.isArray(voices) || !voices.length) return -1;
    var target = bcp47.toLowerCase();
    var pref = target.split("-")[0];
    var femHints = /neerja|shruti|swara|heera|kalpana|veena|lekha|female|wavenet-a|wavenet-d|sfg|isf|inf/i;
    var maleHints = /prabhat|mohan|madhur|ravi|hemant|male|wavenet-b|wavenet-c|ism|inm/i;
    var bestIdx = -1, bestScore = -999;

    for (var i = 0; i < voices.length; i++) {
      var v = voices[i];
      var vl = String((v && v.lang) || "").toLowerCase().replace("_", "-");
      var vn = String((v && (v.name || v.voiceURI)) || "");
      if (vl.indexOf("ar") === 0) continue;
      if (vl !== target && vl.indexOf(pref + "-") !== 0) continue;

      var sc = (vl === target) ? 50 : 20;
      if (/neural|natural|network|wavenet|online|google/i.test(vn)) sc += 30;
      if (gender === "female" && femHints.test(vn)) sc += 15;
      if (gender === "male" && maleHints.test(vn)) sc += 15;
      if (sc > bestScore) { bestScore = sc; bestIdx = i; }
    }
    return bestIdx;
  }

  async function speakSentenceNeural(text, lang, gender) {
    var bcp47 = getActiveBcp47(lang);
    var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
    if (tts && typeof tts.speak === "function") {
      var voiceIdx;
      try {
        if (typeof tts.getSupportedVoices === "function") {
          var out = await tts.getSupportedVoices();
          var pick = pickBestIndianVoice((out && out.voices) || [], bcp47, gender);
          if (pick !== -1) voiceIdx = pick;
        }
      } catch (e) {}
      var opts = { text: text, lang: bcp47, rate: 0.98, pitch: gender === "male" ? 0.95 : 1.02, volume: 1.0, category: "ambient" };
      if (typeof voiceIdx === "number") opts.voice = voiceIdx;
      await tts.speak(opts);
      return;
    }

    if ("speechSynthesis" in window) {
      await new Promise(function (resolve) {
        try {
          var u = new SpeechSynthesisUtterance(text);
          u.lang = bcp47;
          u.rate = 0.98;
          u.pitch = gender === "male" ? 0.95 : 1.02;
          var vs = window.speechSynthesis.getVoices ? window.speechSynthesis.getVoices() : [];
          var pick = pickBestIndianVoice(vs, bcp47, gender);
          if (pick !== -1 && vs[pick]) u.voice = vs[pick];
          u.onend = resolve;
          u.onerror = resolve;
          window.speechSynthesis.speak(u);
        } catch (e) { resolve(); }
      });
    }
  }

  async function startProfessorPlayback() {
    if (typeof state === "undefined" || !state.activeTopicId) return;

    if (profPlaying && !profPaused) {
      profPaused = true;
      if (htmlAudio) { try { htmlAudio.pause(); } catch (e) {} }
      else {
        speakToken++;
        var tts = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.TextToSpeech;
        if (tts && tts.stop) { try { tts.stop().catch(function () {}); } catch (e) {} }
        if ("speechSynthesis" in window) { try { window.speechSynthesis.cancel(); } catch (e) {} }
      }
      setStatusText("Class paused.");
      updateProfButtons();
      return;
    }

    if (profPlaying && profPaused) {
      profPaused = false;
      if (htmlAudio) {
        try { await htmlAudio.play(); } catch (e) {}
        setStatusText("Resumed Studio Human Neural Voice.");
        updateProfButtons();
        return;
      }
      runSentenceLoop(activeSentenceIdx);
      return;
    }

    if (window.LSAudioEngine && typeof window.LSAudioEngine.stop === "function") {
      window.LSAudioEngine.stop();
    }
    stopProfessorAudio();

    var myToken = ++speakToken;
    var topicId = state.activeTopicId;
    var lang = state.lang || "en";
    var body = document.getElementById("lsProfLessonBody");
    if (body) body.style.display = "flex";

    setStatusText("Starting Indian Professor voice...");
    var playedMp3 = await tryPlayStudioMp3(topicId, lang, myToken);
    if (playedMp3) return;

    var lesson = buildLessonBlocks(topicId, lang);
    if (!lesson || !lesson.steps.length) return;
    activeSentences = lesson.steps.map(function (s) { return s.text; });
    activeSentenceIdx = 0;
    runSentenceLoop(0);
  }

  async function runSentenceLoop(startIdx) {
    var myToken = ++speakToken;
    var lang = (typeof state !== "undefined" && state.lang) ? state.lang : "en";
    var gender = getGender();
    profPlaying = true;
    profPaused = false;
    updateProfButtons();
    setStatusText("Speaking in Indian Professor Voice (" + getActiveBcp47(lang) + " - " + (gender === "male" ? "Sir" : "Ma'am") + ")");

    for (var i = startIdx; i < activeSentences.length; i++) {
      if (myToken !== speakToken) return;
      activeSentenceIdx = i;
      highlightStep(i);
      await speakSentenceNeural(activeSentences[i], lang, gender);
      if (myToken !== speakToken) return;
      await new Promise(function (r) { setTimeout(r, 260); });
    }
    if (myToken === speakToken) {
      profPlaying = false;
      profPaused = false;
      highlightStep(-1);
      setStatusText("Classroom explanation complete!");
      updateProfButtons();
    }
  }

  function renderProfessorCard() {
    try {
      injectCss();
      if (typeof state === "undefined" || !state.activeTopicId) return;
      var pane = document.getElementById("readingPane");
      if (!pane) return;

      var old = document.getElementById("lsIndianProfessorCard");
      if (old) old.remove();

      var lang = state.lang || "en";
      var lesson = buildLessonBlocks(state.activeTopicId, lang);
      if (!lesson) return;

      var card = document.createElement("section");
      card.id = "lsIndianProfessorCard";
      card.className = "ls-prof-card";

      var gender = getGender();
      card.innerHTML =
        '<div class="ls-prof-top">' +
          '<div>' +
            '<div class="ls-prof-title">' + lesson.heading + '</div>' +
            '<div class="ls-prof-sub">' + lesson.sub + '</div>' +
          '</div>' +
        '</div>' +
        '<div class="ls-prof-controls">' +
          '<button type="button" id="lsProfPlayBtn" class="ls-prof-btn primary">Listen to Professor</button>' +
          '<button type="button" id="lsProfStopBtn" class="ls-prof-btn" style="display:none;">Stop</button>' +
          '<button type="button" id="lsProfToggleBodyBtn" class="ls-prof-btn">Show Classroom Notes</button>' +
          '<button type="button" id="lsProfVoiceFemBtn" class="ls-prof-btn' + (gender === "female" ? " active" : "") + '">Ma\'am Voice</button>' +
          '<button type="button" id="lsProfVoiceMaleBtn" class="ls-prof-btn' + (gender === "male" ? " active" : "") + '">Sir Voice</button>' +
        '</div>' +
        '<div id="lsProfStatus" class="ls-prof-status"></div>' +
        '<div id="lsProfLessonBody" class="ls-prof-body" style="display:none;"></div>';

      var body = card.querySelector("#lsProfLessonBody");
      lesson.steps.forEach(function (st) {
        var row = document.createElement("div");
        row.className = "ls-prof-step";
        row.innerHTML = '<span class="ls-prof-tag">' + st.tag.replace(/</g, "&lt;") + '</span><div>' + st.text.replace(/</g, "&lt;") + '</div>';
        body.appendChild(row);
      });

      card.querySelector("#lsProfPlayBtn").addEventListener("click", startProfessorPlayback);
      card.querySelector("#lsProfStopBtn").addEventListener("click", stopProfessorAudio);
      card.querySelector("#lsProfToggleBodyBtn").addEventListener("click", function (ev) {
        var open = body.style.display !== "none";
        body.style.display = open ? "none" : "flex";
        ev.currentTarget.textContent = open ? "Show Classroom Notes" : "Hide Classroom Notes";
      });
      card.querySelector("#lsProfVoiceFemBtn").addEventListener("click", function () {
        setGender("female");
        card.querySelector("#lsProfVoiceFemBtn").classList.add("active");
        card.querySelector("#lsProfVoiceMaleBtn").classList.remove("active");
        if (typeof showToast === "function") showToast("Selected Indian Female Professor Voice");
      });
      card.querySelector("#lsProfVoiceMaleBtn").addEventListener("click", function () {
        setGender("male");
        card.querySelector("#lsProfVoiceMaleBtn").classList.add("active");
        card.querySelector("#lsProfVoiceFemBtn").classList.remove("active");
        if (typeof showToast === "function") showToast("Selected Indian Male Professor Voice");
      });

      var copyBar = document.getElementById("lsNoteCopyBar");
      if (copyBar && copyBar.parentNode === pane) {
        copyBar.insertAdjacentElement("afterend", card);
      } else {
        pane.insertBefore(card, pane.firstChild);
      }
      updateProfButtons();
    } catch (e) {}
  }

  function hook() {
    try {
      if (typeof window.renderReadingPane === "function" && !window.__lsProfHookV320) {
        window.__lsProfHookV320 = true;
        var orig = window.renderReadingPane;
        window.renderReadingPane = function () {
          stopProfessorAudio();
          var r = orig.apply(this, arguments);
          renderProfessorCard();
          return r;
        };
        renderProfessorCard();
      }
    } catch (e) {}
  }

  window.addEventListener("ls:lang-changed", stopProfessorAudio);
  window.LSIndianProfessor = {
    play: startProfessorPlayback,
    stop: stopProfessorAudio,
    getStyle: getStyle,
    setStyle: setStyle
  };

  window.addEventListener("DOMContentLoaded", function () {
    setTimeout(hook, 400);
    setTimeout(hook, 1250);
  });
})();
'@

$profPath = Join-Path $modDir "ls-indian-professor.js"
[System.IO.File]::WriteAllText($profPath, $profJs, $u)
node --check $profPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in ls-indian-professor.js!" }
Write-Host "[PASS] www/js/modules/ls-indian-professor.js installed & verified (0 errors)." -ForegroundColor Green

if ($GenerateSampleAudio) {
  Write-Host "`n=== 3. Generating Real Human Indian Neural Studio MP3s (edge-tts) ===" -ForegroundColor Cyan
  python -c "import edge_tts" 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[SETUP] Installing edge-tts for free Microsoft Indian Neural Voices..." -ForegroundColor Yellow
    python -m pip install -q edge-tts
  }
  python -u $pyAudioPath (Join-Path $wwwDir "nyayasaral_db.json") $audioDir $SampleCount $VoiceGender "en,te,hi"
  if ($LASTEXITCODE -ne 0) { throw "Sample studio audio generation failed!" }
}

Write-Host "`n[DONE] Upgrade Part 2 complete! Reply 'next' for Part 3 (1-Tap Hard-Copy PDF Download for Students)." -ForegroundColor Green