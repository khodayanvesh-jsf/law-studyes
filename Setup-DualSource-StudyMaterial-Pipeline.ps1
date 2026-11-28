param(
  [string]$MaterialPath = "",
  [switch]$DryRun,
  [switch]$TranslateAndPush
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$wwwDir = Join-Path $root "www"
$scriptsDir = Join-Path $root "scripts"
$dataDir = Join-Path $root "data"
$reportsDir = Join-Path $root "reports"
New-Item -ItemType Directory -Path $scriptsDir, $dataDir, $reportsDir -Force | Out-Null

if (-not $MaterialPath) {
  $desk = [Environment]::GetFolderPath("Desktop")
  $dl = Join-Path $env:USERPROFILE "Downloads"
  $candidates = @(
    (Join-Path $root "LLB 3YDC Study Material.zip"),
    (Join-Path $root "LLB 3YDC Study Material"),
    (Join-Path $desk "LLB 3YDC Study Material.zip"),
    (Join-Path $desk "LLB 3YDC Study Material"),
    (Join-Path $dl "LLB 3YDC Study Material.zip"),
    (Join-Path $dl "LLB 3YDC Study Material")
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { $MaterialPath = $c; break }
  }
}

Write-Host "`n=== 1. Installing Dual-Source Analyzer, Non-Overlap Merger & Strict Grammar Engine (scripts/merge_dual_source_notes.py) ===" -ForegroundColor Cyan
$pyMerge = @'
import copy, json, os, re, sys, time, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

args = sys.argv[1:]
dry_run = "--dry-run" in args
args = [a for a in args if a != "--dry-run"]

db_file = Path(args[0]) if len(args) > 0 else Path("www/nyayasaral_db.json")
mat_arg = args[1] if len(args) > 1 else ""
index_file = Path(args[2]) if len(args) > 2 else Path("data/study_material_index.json")
report_file = Path(args[3]) if len(args) > 3 else Path("reports/dual_source_report.json")

if not db_file.exists():
    raise SystemExit(f"ERROR: Database not found at {db_file}")

TYPO_MAP = [
    (r"\bsallent\b", "salient"),
    (r"\bsaleint\b", "salient"),
    (r"\bdefination\b", "definition"),
    (r"\bagrement\b", "agreement"),
    (r"\bconsideraton\b", "consideration"),
    (r"\bliablity\b", "liability"),
    (r"\bconstituton\b", "constitution"),
    (r"\benviroment\b", "environment"),
    (r"\bparnership\b", "partnership"),
    (r"\boccured\b", "occurred"),
    (r"\brecieve\b", "receive"),
    (r"\bseperate\b", "separate"),
    (r"\buntill\b", "until"),
    (r"\bwich\b", "which"),
    (r"\bteh\b", "the"),
    (r"\bthier\b", "their"),
    (r"\bgoverment\b", "government"),
    (r"\bjudical\b", "judicial"),
    (r"\bstatutary\b", "statutory"),
    (r"\bprincipel\b", "principle"),
    (r"\bprinicple\b", "principle"),
    (r"\bprovison\b", "provision"),
    (r"\bnegligance\b", "negligence"),
    (r"\bcompansation\b", "compensation"),
    (r"\binjurie\b", "injury"),
    (r"\bcontractural\b", "contractual"),
    (r"\bvoide\b", "void"),
    (r"\bevidance\b", "evidence"),
    (r"\bplaintif\b", "plaintiff"),
    (r"\bdefendent\b", "defendant"),
]

LEGAL_CAPS = [
    (r"\bindian contract act\b", "Indian Contract Act"),
    (r"\bconstitution of india\b", "Constitution of India"),
    (r"\bsupreme court\b", "Supreme Court"),
    (r"\bhigh court\b", "High Court"),
    (r"\bbharatiya nyaya sanhita\b", "Bharatiya Nyaya Sanhita"),
    (r"\bbharatiya nagarik suraksha sanhita\b", "Bharatiya Nagarik Suraksha Sanhita"),
    (r"\bbharatiya sakshya adhiniyam\b", "Bharatiya Sakshya Adhiniyam"),
    (r"\bindian penal code\b", "Indian Penal Code"),
    (r"\bindian partnership act\b", "Indian Partnership Act"),
    (r"\bsale of goods act\b", "Sale of Goods Act"),
    (r"\btransfer of property act\b", "Transfer of Property Act"),
    (r"\bhindu marriage act\b", "Hindu Marriage Act"),
    (r"\bhindu succession act\b", "Hindu Succession Act"),
    (r"\bspecific relief act\b", "Specific Relief Act"),
    (r"\bconsumer protection act\b", "Consumer Protection Act"),
    (r"\benvironment protection act\b", "Environment Protection Act"),
    (r"\bsection\s+(\d+[a-zA-Z0-9()\-]*)", r"Section \1"),
    (r"\bsec\.\s*(\d+[a-zA-Z0-9()\-]*)", r"Section \1"),
    (r"\barticle\s+(\d+[a-zA-Z0-9()\-]*)", r"Article \1"),
    (r"\bart\.\s*(\d+[a-zA-Z0-9()\-]*)", r"Article \1"),
]

A_AN_EXCEPT = re.compile(r"^(?:uni|use|usu|one|onc|eu|u[bcdfghjklmnpqrstvwxyz][aeiou]|hour|honest|honour|heir)", re.I)

def fix_a_an(m):
    word = m.group(2)
    if A_AN_EXCEPT.match(word):
        return m.group(0)
    art = "An" if m.group(1)[0].isupper() else "an"
    return f"{art} {word}"

def strict_grammar_polish(text, ensure_period=True):
    s = str(text or "")
    if not s.strip():
        return "", 0
    orig = s
    s = re.sub(r"([A-Za-z])-\s*\r?\n\s*([a-z])", r"\1\2", s)
    s = re.sub(r"[\r\n\t]+", " ", s)
    s = re.sub(r"\s{2,}", " ", s).strip()
    s = re.sub(r"\s+([,\.\;\:\?\!])", r"\1", s)
    s = re.sub(r"([,\.\;\:\?\!])([A-Za-z])", r"\1 \2", s)
    s = re.sub(r"\(\s+", "(", s)
    s = re.sub(r"\s+\)", ")", s)
    s = re.sub(r"\.{4,}", "...", s)

    for pat, rep in TYPO_MAP:
        s = re.sub(pat, lambda m, r=rep: (r.capitalize() if m.group(0)[0].isupper() else r), s, flags=re.I)
    for pat, rep in LEGAL_CAPS:
        s = re.sub(pat, rep, s, flags=re.I)
    s = re.sub(r"\b(a|A)\s+([aeiouAEIOU][a-z]{2,})\b", fix_a_an, s)

    if s and s[0].islower():
        s = s[0].upper() + s[1:]
    s = re.sub(r"([\.\?\!]\s+)([a-z])", lambda m: m.group(1) + m.group(2).upper(), s)

    if ensure_period and len(s) >= 18 and s[-1] not in ".?!:\"' )]}":
        s += "."

    changed = 1 if s != orig.strip() else 0
    return s, changed

def polish_title(title):
    s, ch = strict_grammar_polish(title, ensure_period=False)
    return s.rstrip("."), ch

def extract_docx_bytes(raw_bytes):
    import io
    out = []
    with zipfile.ZipFile(io.BytesIO(raw_bytes)) as zf:
        if "word/document.xml" not in zf.namelist():
            return ""
        root = ET.fromstring(zf.read("word/document.xml"))
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        for p in root.findall(".//w:p", ns):
            texts = [t.text for t in p.findall(".//w:t", ns) if t.text]
            line = "".join(texts).strip()
            if line:
                out.append(line)
    return "\n".join(out)

def extract_pdf_bytes(raw_bytes):
    import io
    try:
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(raw_bytes))
        return "\n".join((pg.extract_text() or "") for pg in reader.pages)
    except Exception:
        pass
    try:
        import fitz
        doc = fitz.open(stream=raw_bytes, filetype="pdf")
        return "\n".join(pg.get_text("text") for pg in doc)
    except Exception:
        return ""

def extract_html_text(raw_text):
    s = re.sub(r"(?is)<(script|style)[^>]*>.*?</\1>", " ", raw_text)
    s = re.sub(r"(?i)</?(p|div|li|br|h[1-6]|tr)[^>]*>", "\n", s)
    return re.sub(r"<[^>]+>", " ", s)

def decode_file_bytes(ext, raw):
    if ext == ".pdf":
        return extract_pdf_bytes(raw)
    if ext == ".docx":
        return extract_docx_bytes(raw)
    text = raw.decode("utf-8", errors="ignore")
    if ext in (".html", ".htm"):
        return extract_html_text(text)
    if ext == ".json":
        try:
            return json.dumps(json.loads(text), ensure_ascii=False, indent=1)
        except Exception:
            return text
    return text

def read_all_material_files(mat_path):
    docs = []
    p = Path(mat_path)
    supported = {".pdf", ".docx", ".txt", ".md", ".html", ".htm", ".json"}
    if p.is_file() and p.suffix.lower() == ".zip":
        with zipfile.ZipFile(p, "r") as zf:
            for info in zf.infolist():
                if info.is_dir():
                    continue
                ext = Path(info.filename).suffix.lower()
                if ext not in supported or "__MACOSX" in info.filename:
                    continue
                txt = decode_file_bytes(ext, zf.read(info.filename))
                if txt and len(txt.strip()) >= 40:
                    docs.append((info.filename, txt))
    elif p.is_dir():
        for fp in sorted(p.rglob("*")):
            if not fp.is_file():
                continue
            ext = fp.suffix.lower()
            if ext not in supported:
                continue
            txt = decode_file_bytes(ext, fp.read_bytes())
            if txt and len(txt.strip()) >= 40:
                docs.append((str(fp.relative_to(p)), txt))
    return docs

HEADING_RE = re.compile(
    r"^(?:#{1,4}\s+|(?:UNIT|CHAPTER|TOPIC|MODULE|QUESTION|Q\.?)\s*[\dIVX]+[\.\:\-\)]\s*|\d{1,2}\.\s+)([^\n]{4,120})$",
    re.I,
)
CASE_RE = re.compile(r"\b([A-Z][A-Za-z\.&\s]{2,42}\s+(?:v\.|vs\.?)\s+[A-Z][A-Za-z\.&\s]{2,48})(?:\s*\((\d{4})\))?")
PROV_RE = re.compile(r"\b((?:Section|Sections|Sec\.|Article|Articles|Art\.|Order|Rule)\s+\d+[A-Za-z0-9()\-/,\s]*(?:of\s+(?:the\s+)?[A-Z][A-Za-z\s,]{3,55})?)", re.I)

def parse_doc_into_concepts(rel_path, raw_text):
    lines = [ln.strip() for ln in raw_text.splitlines() if ln.strip()]
    if not lines:
        return []
    stem = Path(rel_path).stem.replace("_", " ").replace("-", " ").strip()
    folder_hint = str(Path(rel_path).parent).replace("\\", " ").replace("/", " ")

    sections, cur_title, cur_lines = [], stem, []
    for ln in lines:
        m = HEADING_RE.match(ln)
        is_short_caps = (6 <= len(ln) <= 95 and ln.isupper() and not ln.endswith(".") and sum(c.isalpha() for c in ln) >= 5)
        if m or is_short_caps:
            if len(" ".join(cur_lines)) >= 80:
                sections.append((cur_title, cur_lines))
            cur_title = (m.group(1) if m else ln.title()).strip(" :-#")
            cur_lines = []
        else:
            cur_lines.append(ln)
    if len(" ".join(cur_lines)) >= 80:
        sections.append((cur_title, cur_lines))

    concepts = []
    for sec_title, body_lines in sections:
        full_body = re.sub(r"\s+", " ", " ".join(body_lines)).strip()
        if len(full_body) < 80:
            continue
        sentences = [x.strip() for x in re.split(r"(?<=[\.\?\!])\s+", full_body) if len(x.strip()) >= 25]
        provs = list(dict.fromkeys(m.group(1).strip(" ,.;:") for m in PROV_RE.finditer(full_body)))[:3]
        cases_found, seen_case = [], set()
        for cm in CASE_RE.finditer(full_body):
            cname = re.sub(r"\s+", " ", cm.group(1)).strip(" ,.;:")
            ckey = cname.lower()
            if ckey not in seen_case and len(cname) >= 8:
                seen_case.add(ckey)
                ctx = full_body[max(0, cm.start() - 40):min(len(full_body), cm.end() + 180)].strip()
                cases_found.append({"name": cname, "year": cm.group(2) or "", "principle": ctx})

        key_pts = []
        for ln in body_lines:
            if re.match(r"^(?:[\-\*\u2022]|\d+[\.\)]|\([a-z0-9]+\))\s+", ln):
                cleaned_pt = re.sub(r"^(?:[\-\*\u2022]|\d+[\.\)]|\([a-z0-9]+\))\s+", "", ln).strip()
                if 20 <= len(cleaned_pt) <= 320:
                    key_pts.append(cleaned_pt)
        if not key_pts:
            key_pts = sentences[2:7]

        concepts.append({
            "sourceFile": rel_path,
            "folderHint": folder_hint,
            "title": sec_title,
            "inOneMinute": " ".join(sentences[:2])[:420],
            "legalProvision": "; ".join(provs),
            "meaning": " ".join(sentences[1:4])[:650],
            "keyPoints": key_pts[:8],
            "caseLaws": cases_found[:4],
        })
    return concepts

STOPWORDS = {
    "the", "and", "for", "with", "from", "that", "this", "under", "into", "over", "about",
    "law", "laws", "act", "india", "indian", "unit", "topic", "notes", "study", "material",
    "meaning", "definition", "introduction", "concept", "nature", "scope", "importance",
    "llb", "ydc", "year", "sem", "semester", "paper", "part", "chapter", "section", "article"
}

def norm_tokens(text):
    return {w for w in re.findall(r"[a-z0-9]+", str(text or "").lower()) if len(w) >= 3 and w not in STOPWORDS}

def jaccard(a, b):
    return (len(a & b) / max(1, len(a | b))) if (a and b) else 0.0

def is_overlapping_text(candidate, existing_list, threshold=0.52):
    ct = norm_tokens(candidate)
    if len(ct) < 3:
        return True
    c_low = candidate.strip().lower()
    for ex in existing_list:
        e_low = str(ex or "").strip().lower()
        if not e_low:
            continue
        if c_low in e_low or e_low in c_low:
            return True
        if jaccard(ct, norm_tokens(e_low)) >= threshold:
            return True
    return False

def match_subject(concept, subjects):
    hint_tokens = norm_tokens(concept["folderHint"] + " " + concept["sourceFile"] + " " + concept["title"])
    best_s, best_sc = None, 0.0
    for subj in subjects:
        st = norm_tokens(subj.get("title", "") + " " + subj.get("id", ""))
        sc = jaccard(hint_tokens, st)
        low_path = (concept["folderHint"] + " " + concept["sourceFile"]).lower()
        low_st = str(subj.get("title", "")).lower()
        for alias in (low_st, low_st.replace("law of ", ""), str(subj.get("id", "")).replace("-", " ")):
            if alias and len(alias) >= 5 and alias in low_path:
                sc += 0.65
        if sc > best_sc:
            best_sc, best_s = sc, subj
    return best_s if best_sc >= 0.15 else None

def match_topic_in_subject(concept, subj, notes):
    ct = norm_tokens(concept["title"])
    c_body_t = norm_tokens(concept["title"] + " " + concept["legalProvision"] + " " + concept["inOneMinute"])
    best_t, best_sc = None, 0.0
    for unit in subj.get("units", []):
        for t in unit.get("topics", []):
            tt = norm_tokens(t.get("title", ""))
            sc_title = jaccard(ct, tt)
            rec = notes.get(t.get("id", ""), {})
            en_rec = rec.get("en", {}) if isinstance(rec, dict) else {}
            ex_body_t = norm_tokens(str(t.get("title", "")) + " " + str(en_rec.get("legalProvision", "")) + " " + str(en_rec.get("inOneMinute", "")))
            sc_body = jaccard(c_body_t, ex_body_t)
            sc = max(sc_title, 0.7 * sc_title + 0.3 * sc_body, sc_body * 0.9)
            if sc > best_sc:
                best_sc, best_t = sc, t
    return best_t, best_sc

def write_onedrive_safe(target, text_data):
    tmp = target.with_name(f"{target.name}.{os.getpid()}.tmp")
    tmp.write_text(text_data, encoding="utf-8")
    json.loads(tmp.read_text(encoding="utf-8"))
    for attempt in range(12):
        try:
            os.replace(str(tmp), str(target))
            return
        except (PermissionError, OSError):
            time.sleep(min(2.0, 0.25 * (attempt + 1)))
    with open(target, "w", encoding="utf-8", newline="") as fh:
        fh.write(text_data)
    try:
        tmp.unlink(missing_ok=True)
    except Exception:
        pass

db = json.loads(db_file.read_text(encoding="utf-8"))
subjects = db.get("subjects", [])
notes = db.get("notes", {})

concepts, files_parsed = [], 0
if mat_arg and Path(mat_arg).exists():
    print(f"[READ] Parsing study material from: {mat_arg}", flush=True)
    raw_docs = read_all_material_files(mat_arg)
    files_parsed = len(raw_docs)
    for rel_p, txt in raw_docs:
        concepts.extend(parse_doc_into_concepts(rel_p, txt))
    if concepts and not dry_run:
        index_file.parent.mkdir(parents=True, exist_ok=True)
        index_file.write_text(json.dumps({
            "sourcePath": str(Path(mat_arg).resolve()),
            "indexedAt": time.strftime("%Y-%m-%d %H:%M:%S"),
            "filesParsed": files_parsed,
            "concepts": concepts
        }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[INDEX] Extracted {len(concepts)} structured concept(s) from {files_parsed} file(s).", flush=True)
elif index_file.exists():
    cached = json.loads(index_file.read_text(encoding="utf-8"))
    concepts = cached.get("concepts", [])
    files_parsed = cached.get("filesParsed", 0)
    print(f"[INDEX] Loaded persistent study material mirror ({len(concepts)} concepts from {files_parsed} files).", flush=True)
else:
    print("[INFO] No study material ZIP/folder or mirror found yet. Running strict English grammar polish on website notes only.", flush=True)

stats = {
    "filesParsed": files_parsed,
    "conceptsExtracted": len(concepts),
    "topicsEnriched": 0,
    "newTopicsCreated": 0,
    "pointsAddedNonOverlap": 0,
    "casesAddedNonOverlap": 0,
    "overlapsBlocked": 0,
    "grammarFixesApplied": 0,
    "unmatchedSubjects": 0,
    "enrichedTopicIds": [],
    "createdTopicIds": []
}

for concept in concepts:
    subj = match_subject(concept, subjects)
    if not subj:
        stats["unmatchedSubjects"] += 1
        continue

    matched_topic, score = match_topic_in_subject(concept, subj, notes)
    if matched_topic and score >= 0.42:
        tid = matched_topic["id"]
        rec = notes.get(tid)
        if not isinstance(rec, dict) or not isinstance(rec.get("en"), dict):
            continue
        en = rec["en"]

        existing_texts = [en.get("inOneMinute", ""), en.get("meaning", ""), en.get("legalProvision", "")]
        existing_kps = en.get("keyPoints") if isinstance(en.get("keyPoints"), list) else []
        for kp in existing_kps:
            existing_texts.append(kp if isinstance(kp, str) else str((kp or {}).get("point") or (kp or {}).get("text") or ""))

        added_here = False
        for pt in concept.get("keyPoints", []):
            pt_clean, g_ch = strict_grammar_polish(pt, ensure_period=True)
            stats["grammarFixesApplied"] += g_ch
            if not pt_clean or is_overlapping_text(pt_clean, existing_texts, threshold=0.50):
                stats["overlapsBlocked"] += 1
                continue
            existing_kps.append(pt_clean)
            existing_texts.append(pt_clean)
            stats["pointsAddedNonOverlap"] += 1
            added_here = True
        en["keyPoints"] = existing_kps

        existing_cases = en.get("caseLaws") if isinstance(en.get("caseLaws"), list) else []
        existing_case_names = [
            (c if isinstance(c, str) else str((c or {}).get("name") or (c or {}).get("title") or "")).lower()
            for c in existing_cases
        ]
        for cl in concept.get("caseLaws", []):
            cn_clean, g1 = polish_title(cl.get("name", ""))
            pr_clean, g2 = strict_grammar_polish(cl.get("principle", ""), ensure_period=True)
            stats["grammarFixesApplied"] += g1 + g2
            if not cn_clean or is_overlapping_text(cn_clean, existing_case_names, threshold=0.55):
                stats["overlapsBlocked"] += 1
                continue
            existing_cases.append({"name": cn_clean, "year": cl.get("year", ""), "principle": pr_clean})
            existing_case_names.append(cn_clean.lower())
            stats["casesAddedNonOverlap"] += 1
            added_here = True
        en["caseLaws"] = existing_cases

        if not str(en.get("legalProvision", "")).strip() and concept.get("legalProvision"):
            pv, g3 = strict_grammar_polish(concept["legalProvision"], ensure_period=False)
            en["legalProvision"] = pv
            stats["grammarFixesApplied"] += g3
            added_here = True

        if added_here:
            en["_sources"] = ["website", "study_material"]
            for tl in ("te", "hi"):
                rec.pop(tl, None)
            stats["topicsEnriched"] += 1
            stats["enrichedTopicIds"].append(tid)
    else:
        clean_title, g0 = polish_title(concept["title"])
        if len(clean_title) < 5:
            continue
        slug = re.sub(r"[^a-z0-9]+", "-", clean_title.lower()).strip("-")[:40] or "concept"
        new_tid = f"{subj['id']}-sm-{slug}"
        if new_tid in notes:
            stats["overlapsBlocked"] += 1
            continue

        units = subj.setdefault("units", [])
        target_unit = next((u for u in units if "study material" in str(u.get("title", "")).lower()), None)
        if target_unit is None:
            target_unit = {"unitNo": len(units) + 1, "title": "Additional Study Material Concepts", "topics": []}
            units.append(target_unit)

        m1, g1 = strict_grammar_polish(concept.get("inOneMinute", ""), ensure_period=True)
        pr, g2 = strict_grammar_polish(concept.get("legalProvision", ""), ensure_period=False)
        mn, g3 = strict_grammar_polish(concept.get("meaning", ""), ensure_period=True)
        stats["grammarFixesApplied"] += g0 + g1 + g2 + g3

        kps_clean = []
        for pt in concept.get("keyPoints", []):
            pc, gc = strict_grammar_polish(pt, ensure_period=True)
            stats["grammarFixesApplied"] += gc
            if pc and not is_overlapping_text(pc, kps_clean, threshold=0.55):
                kps_clean.append(pc)

        cls_clean = []
        for cl in concept.get("caseLaws", []):
            cn, ga = polish_title(cl.get("name", ""))
            cp, gb = strict_grammar_polish(cl.get("principle", ""), ensure_period=True)
            stats["grammarFixesApplied"] += ga + gb
            if cn:
                cls_clean.append({"name": cn, "year": cl.get("year", ""), "principle": cp})

        target_unit["topics"].append({"id": new_tid, "title": clean_title})
        notes[new_tid] = {
            "id": new_tid,
            "subtitle": f"{subj.get('title', '')} - Study Material",
            "readTime": "4 min read",
            "url": "",
            "en": {
                "inOneMinute": m1,
                "legalProvision": pr,
                "meaning": mn,
                "keyPoints": kps_clean,
                "caseLaws": cls_clean,
                "selfTest": [],
                "visuals": [],
                "_sources": ["study_material"]
            }
        }
        stats["newTopicsCreated"] += 1
        stats["createdTopicIds"].append(new_tid)

# Strict Grammar Polish Across All English Titles & Notes (Never Modifies `visuals`)
for subj in subjects:
    for unit in subj.get("units", []):
        for t in unit.get("topics", []):
            if isinstance(t, dict) and isinstance(t.get("title"), str):
                nt, ch = polish_title(t["title"])
                if ch:
                    t["title"] = nt
                    stats["grammarFixesApplied"] += ch

for tid, rec in notes.items():
    if not isinstance(rec, dict) or not isinstance(rec.get("en"), dict):
        continue
    en = rec["en"]
    for fld, need_p in (("inOneMinute", True), ("meaning", True), ("legalProvision", False)):
        if isinstance(en.get(fld), str) and en[fld].strip():
            fixed, ch = strict_grammar_polish(en[fld], ensure_period=need_p)
            if ch:
                en[fld] = fixed
                stats["grammarFixesApplied"] += ch
    if isinstance(en.get("keyPoints"), list):
        new_kps = []
        for kp in en["keyPoints"]:
            if isinstance(kp, str):
                fk, ch = strict_grammar_polish(kp, ensure_period=True)
                stats["grammarFixesApplied"] += ch
                new_kps.append(fk)
            elif isinstance(kp, dict):
                kp_c = dict(kp)
                for k in ("point", "text", "summary"):
                    if isinstance(kp_c.get(k), str):
                        fk, ch = strict_grammar_polish(kp_c[k], ensure_period=True)
                        stats["grammarFixesApplied"] += ch
                        kp_c[k] = fk
                new_kps.append(kp_c)
            else:
                new_kps.append(kp)
        en["keyPoints"] = new_kps
    if isinstance(en.get("visuals"), list):
        for tl in ("te", "hi"):
            if isinstance(rec.get(tl), dict) and rec[tl].get("visuals") != en["visuals"]:
                rec[tl]["visuals"] = copy.deepcopy(en["visuals"])

report_file.parent.mkdir(parents=True, exist_ok=True)
report_file.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")

if not dry_run:
    write_onedrive_safe(db_file, json.dumps(db, ensure_ascii=False, separators=(",", ":")))
    print(f"[SAVED] Updated {db_file.name} safely (OneDrive-safe atomic write).", flush=True)
else:
    print("[DRY-RUN] No changes written to nyayasaral_db.json yet.", flush=True)

print("\n=== DUAL-SOURCE MERGE & STRICT GRAMMAR REPORT ===", flush=True)
print(f"  Study Material Files Parsed:    {stats['filesParsed']}", flush=True)
print(f"  Concepts Extracted:             {stats['conceptsExtracted']}", flush=True)
print(f"  Existing Topics Enriched:       {stats['topicsEnriched']} (+{stats['pointsAddedNonOverlap']} non-overlap points, +{stats['casesAddedNonOverlap']} cases)", flush=True)
print(f"  Brand-New Concepts Added:       {stats['newTopicsCreated']}", flush=True)
print(f"  Overlapping Items Blocked:      {stats['overlapsBlocked']}", flush=True)
print(f"  Strict Grammar Fixes Applied:   {stats['grammarFixesApplied']}", flush=True)
print(f"  Report saved -> {report_file}", flush=True)
'@

$mergePyPath = Join-Path $scriptsDir "merge_dual_source_notes.py"
[System.IO.File]::WriteAllText($mergePyPath, $pyMerge, $u)
python -m py_compile $mergePyPath
if ($LASTEXITCODE -ne 0) { throw "Syntax error in scripts/merge_dual_source_notes.py!" }
Write-Host "[PASS] scripts/merge_dual_source_notes.py installed & syntax verified." -ForegroundColor Green

Write-Host "`n=== 2. Hooking Dual-Source Merger Permanently into Sync-And-Translate-BeforeDeploy.ps1 ===" -ForegroundColor Cyan
$syncHookPath = Join-Path $root "Sync-And-Translate-BeforeDeploy.ps1"
if (Test-Path $syncHookPath) {
  $syncTxt = [System.IO.File]::ReadAllText($syncHookPath, $u)
  if ($syncTxt -notmatch 'merge_dual_source_notes\.py') {
    $dualStep = @"
# === LS_DUAL_SOURCE_SYNC_START ===
Write-Host "`n=== Dual-Source Sync: Comparing Website + Study Material & Strict Grammar Polish ===" -ForegroundColor Cyan
`$__dualPy = Join-Path `$root "scripts\merge_dual_source_notes.py"
if (Test-Path `$__dualPy) {
  python -u `$__dualPy (Join-Path `$root "www\nyayasaral_db.json") "" (Join-Path `$root "data\study_material_index.json") (Join-Path `$root "reports\dual_source_report.json")
  if (`$LASTEXITCODE -ne 0) { throw "Dual-source merge/grammar sync failed!" }
}
# === LS_DUAL_SOURCE_SYNC_END ===
"@
    $syncTxt = $syncTxt -replace '(# === LS_DUAL_SOURCE_SYNC_START ===[\s\S]*?# === LS_DUAL_SOURCE_SYNC_END ===\r?\n?)', ''
    $mConv = [regex]::Match($syncTxt, '(?m)^[^\r\n]*convert_en_to_te_hi\.py[^\r\n]*')
    if ($mConv.Success) {
      $syncTxt = $syncTxt.Substring(0, $mConv.Index) + $dualStep + "`r`n" + $syncTxt.Substring($mConv.Index)
    } else {
      $syncTxt = $dualStep + "`r`n" + $syncTxt
    }
    [System.IO.File]::WriteAllText($syncHookPath, $syncTxt, $u)
    Write-Host "[PASS] Hooked into Sync-And-Translate-BeforeDeploy.ps1 (every future website sync now merges BOTH sources + grammar check!)." -ForegroundColor Green
  } else {
    Write-Host "[OK] Sync-And-Translate-BeforeDeploy.ps1 already wired to Dual-Source Merger." -ForegroundColor DarkGray
  }
}

Write-Host "`n=== 3. Checking PDF Reader & Running Dual-Source Analysis ===" -ForegroundColor Cyan
$prevEa = $ErrorActionPreference
$ErrorActionPreference = "Continue"
python -c "import pypdf" 2>$null
$hasPypdf = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prevEa
if (-not $hasPypdf) {
  Write-Host "[SETUP] Installing pypdf for PDF study material extraction..." -ForegroundColor Yellow
  python -m pip install -q pypdf
}

if (-not $MaterialPath) {
  Write-Host "[ACTION NEEDED] Could not auto-locate 'LLB 3YDC Study Material' on Desktop/Downloads/Project Root." -ForegroundColor Yellow
  Write-Host "Run again with the exact path to your ZIP or folder, e.g.:" -ForegroundColor Cyan
  Write-Host '  powershell -ExecutionPolicy Bypass -File .\Setup-DualSource-StudyMaterial-Pipeline.ps1 -MaterialPath "C:\Users\khoda\Downloads\LLB 3YDC Study Material.zip" -DryRun' -ForegroundColor White
  exit 0
}

Write-Host "[FOUND] Study Material: $MaterialPath" -ForegroundColor Green
$pyArgs = @("-u", $mergePyPath, (Join-Path $wwwDir "nyayasaral_db.json"), $MaterialPath, (Join-Path $dataDir "study_material_index.json"), (Join-Path $reportsDir "dual_source_report.json"))
if ($DryRun) { $pyArgs += "--dry-run" }
& python @pyArgs
if ($LASTEXITCODE -ne 0) { throw "Dual-source analysis failed!" }

if ((-not $DryRun) -and $TranslateAndPush) {
  Write-Host "`n=== 4. Translating New/Enriched Topics to Verified TE & HI + Deploying Live OTA ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "Dual-Source Study Material + Website Merge (Zero Overlap + Strict Grammar + EN/TE/HI)"
}