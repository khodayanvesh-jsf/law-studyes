$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$pyCode = @'
import asyncio, json, re, sys
from pathlib import Path

try:
    import edge_tts
except ImportError:
    print("[FAIL] edge-tts not installed. Run: python -m pip install -U edge-tts", flush=True)
    sys.exit(2)

VOICES = {
    "en": {"female": "en-IN-NeerjaNeural", "male": "en-IN-PrabhatNeural"},
    "te": {"female": "te-IN-ShrutiNeural", "male": "te-IN-MohanNeural"},
    "hi": {"female": "hi-IN-SwaraNeural",  "male": "hi-IN-MadhurNeural"},
}

def clean_text(s):
    s = re.sub(r"<[^>]+>", " ", str(s or ""))
    return re.sub(r"\s+", " ", s).strip()

def extract_note_dict(rec, lang):
    if not isinstance(rec, dict):
        return None
    ld = rec.get(lang)
    if isinstance(ld, dict) and ld:
        return ld
    if lang == "en" and any(k in rec for k in ("inOneMinute", "meaning", "legalProvision", "keyPoints", "content", "summary")):
        return rec
    return None

def build_professor_script(topic_title, ld, lang):
    one_min = clean_text(ld.get("inOneMinute") or ld.get("summary") or "")
    prov = clean_text(ld.get("legalProvision") or ld.get("provision") or "")
    meaning = clean_text(ld.get("meaning") or ld.get("content") or ld.get("explanation") or "")
    kp = ld.get("keyPoints") or []
    cases = ld.get("caseLaws") or []

    kp_lines = []
    if isinstance(kp, list):
        for item in kp[:5]:
            if isinstance(item, str) and item.strip():
                kp_lines.append(clean_text(item))
            elif isinstance(item, dict):
                val = clean_text(item.get("point") or item.get("text") or item.get("summary") or "")
                if val:
                    kp_lines.append(val)

    case_line = ""
    if isinstance(cases, list) and cases:
        c0 = cases[0]
        if isinstance(c0, str):
            case_line = clean_text(c0)
        elif isinstance(c0, dict):
            cname = clean_text(c0.get("name") or c0.get("title") or "")
            csum = clean_text(c0.get("principle") or c0.get("summary") or "")
            case_line = f"{cname}: {csum}".strip(": ")

    parts = []
    if lang == "te":
        parts.append(f"\u0c28\u0c2e\u0c38\u0c4d\u0c15\u0c3e\u0c30\u0c02 \u0c38\u0c4d\u0c1f\u0c42\u0c21\u0c46\u0c02\u0c1f\u0c4d\u0c38\u0c4d! \u0c08\u0c30\u0c4b\u0c1c\u0c41 \u0c2e\u0c28\u0c02 {topic_title} \u0c17\u0c41\u0c30\u0c3f\u0c02\u0c1a\u0c3f \u0c1a\u0c3e\u0c32\u0c3e \u0c38\u0c3f\u0c02\u0c2a\u0c41\u0c32\u0c4d\u200c\u0c17\u0c3e \u0c28\u0c47\u0c30\u0c4d\u0c1a\u0c41\u0c15\u0c41\u0c02\u0c26\u0c3e\u0c02.")
        if one_min: parts.append(f"\u0c2e\u0c41\u0c02\u0c26\u0c41\u0c17\u0c3e \u0c12\u0c15\u0c4d\u0c15 \u0c2e\u0c3e\u0c1f\u0c32\u0c4b \u0c05\u0c30\u0c4d\u0c25\u0c02 \u0c1a\u0c47\u0c38\u0c41\u0c15\u0c4b\u0c02\u0c21\u0c3f: {one_min}")
        if prov: parts.append(f"\u0c0e\u0c17\u0c4d\u0c1c\u0c3e\u0c2e\u0c4d\u200c\u0c32\u0c4b \u0c30\u0c3e\u0c2f\u0c3e\u0c32\u0c4d\u0c38\u0c3f\u0c28 \u0c38\u0c46\u0c15\u0c4d\u0c37\u0c28\u0c4d: {prov}")
        if meaning: parts.append(f"\u0c26\u0c40\u0c28\u0c3f \u0c05\u0c30\u0c4d\u0c25\u0c02: {meaning}")
        if kp_lines: parts.append("\u0c2e\u0c41\u0c16\u0c4d\u0c2f \u0c2a\u0c3e\u0c2f\u0c3f\u0c02\u0c1f\u0c4d\u0c32\u0c41: " + ". ".join(kp_lines))
        if case_line: parts.append(f"\u0c2e\u0c41\u0c16\u0c4d\u0c2f\u0c2e\u0c48\u0c28 \u0c15\u0c47\u0c38\u0c4d \u0c32\u0c3e: {case_line}")
    elif lang == "hi":
        parts.append(f"\u0928\u092e\u0938\u094d\u0924\u0947 \u0938\u094d\u091f\u0942\u0921\u0947\u0902\u091f\u094d\u0938! \u0906\u091c \u0939\u092e {topic_title} \u0915\u094b \u0906\u0938\u093e\u0928 \u0915\u094d\u0932\u093e\u0938\u0930\u0942\u092e \u0905\u0902\u0926\u093e\u091c \u092e\u0947\u0902 \u0938\u092e\u091d\u0947\u0902\u0917\u0947\u0964")
        if one_min: parts.append(f"\u090f\u0915 \u092e\u093f\u0928\u091f \u092e\u0947\u0902 \u0905\u0938\u0932\u0940 \u092c\u093e\u0924: {one_min}")
        if prov: parts.append(f"\u090f\u0917\u094d\u091c\u093e\u092e \u0938\u0947\u0915\u094d\u0936\u0928: {prov}")
        if meaning: parts.append(f"\u0907\u0938\u0915\u093e \u092e\u0924\u0932\u092c: {meaning}")
        if kp_lines: parts.append("\u092e\u0941\u0916\u094d\u092f \u092a\u0949\u0907\u0902\u091f\u094d\u0938: " + ". ".join(kp_lines))
        if case_line: parts.append(f"\u092a\u094d\u0930\u092e\u0941\u0916 \u0915\u0947\u0938 \u0932\u0949: {case_line}")
    else:
        parts.append(f"Hello students! Let us understand {topic_title} in simple Indian classroom style.")
        if one_min: parts.append(f"First, the core idea in one minute: {one_min}")
        if prov: parts.append(f"Note the exact legal provision: {prov}")
        if meaning: parts.append(f"In plain words: {meaning}")
        if kp_lines: parts.append("Scoring key points: " + ". ".join(kp_lines))
        if case_line: parts.append(f"Leading case law: {case_line}")
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

    if len(sys.argv) > 5:
        raw_langs = ",".join(sys.argv[5:])
        langs = [x.strip().lower() for x in re.split(r"[,\s]+", raw_langs) if x.strip()]
    else:
        langs = ["en", "te", "hi"]

    if not db_file.exists():
        print(f"[FAIL] DB file not found: {db_file.resolve()}", flush=True)
        sys.exit(1)

    data = json.loads(db_file.read_text(encoding="utf-8"))
    notes = data.get("notes")
    if not isinstance(notes, dict) or not notes:
        print(f"[FAIL] 'notes' missing or empty in {db_file.name}. Top-level keys: {list(data.keys())[:10]}", flush=True)
        sys.exit(1)

    sample_tid = next(iter(notes))
    sample_rec = notes[sample_tid]
    sample_keys = list(sample_rec.keys()) if isinstance(sample_rec, dict) else type(sample_rec).__name__
    print(f"[INFO] Loaded {len(notes)} notes | langs={langs} | gender={gender} | sample '{sample_tid}' keys={sample_keys}", flush=True)

    titles = {}
    for subj in data.get("subjects", []):
        if not isinstance(subj, dict): continue
        for unit in subj.get("units", []):
            if not isinstance(unit, dict): continue
            for t in unit.get("topics", []):
                if isinstance(t, dict) and t.get("id"):
                    titles[t["id"]] = t.get("title", t["id"])

    topic_ids = list(notes.keys())
    if limit > 0:
        topic_ids = topic_ids[:limit]

    manifest_path = audio_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.exists() else {}

    done, existed, skipped = 0, 0, 0
    for tid in topic_ids:
        rec = notes.get(tid, {})
        t_title = titles.get(tid, tid.replace("-", " ").title())
        for lang in langs:
            ld = extract_note_dict(rec, lang)
            if not ld:
                skipped += 1
                print(f"  [SKIP-NO-DATA] {lang}/{tid} (no '{lang}' dict in DB)", flush=True)
                continue
            out_mp3 = audio_root / lang / f"{tid}.mp3"
            if out_mp3.exists() and out_mp3.stat().st_size > 2048:
                manifest.setdefault(lang, {})[tid] = f"./audio/{lang}/{tid}.mp3"
                existed += 1
                print(f"  [EXISTS] {lang}/{tid}.mp3 ({out_mp3.stat().st_size // 1024} KB)", flush=True)
                continue
            script = build_professor_script(t_title, ld, lang)
            voice = VOICES.get(lang, VOICES["en"]).get(gender, VOICES["en"]["female"])
            try:
                await synth_one(script, voice, out_mp3)
                manifest.setdefault(lang, {})[tid] = f"./audio/{lang}/{tid}.mp3"
                done += 1
                print(f"  [AUDIO OK] {lang}/{tid}.mp3 ({voice}, {out_mp3.stat().st_size // 1024} KB)", flush=True)
            except Exception as ex:
                skipped += 1
                print(f"  [AUDIO ERR] {lang}/{tid} ({voice}): {ex}", flush=True)

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
    print(f"[PASS] Audio run complete: new={done} | existing={existed} | skipped={skipped} | Manifest -> {manifest_path}", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
'@

$outPath = Join-Path $root "scripts\generate_professor_audio.py"
[System.IO.File]::WriteAllText($outPath, $pyCode, $u)
python -m py_compile $outPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in scripts/generate_professor_audio.py!" }
Write-Host "[PASS] scripts/generate_professor_audio.py patched. Running 5-topic test now..." -ForegroundColor Green
python -u $outPath ".\www\nyayasaral_db.json" ".\www\audio" 5 female "en,te,hi"