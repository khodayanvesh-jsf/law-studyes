import copy, hashlib, io, json, os, re, sys, time, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

args = sys.argv[1:]
dry_run = "--dry-run" in args
only_sem = ""
clean_args = []
i = 0
while i < len(args):
    if args[i] == "--dry-run":
        i += 1
    elif args[i] == "--sem" and i + 1 < len(args):
        only_sem = args[i + 1].strip()
        i += 2
    else:
        clean_args.append(args[i])
        i += 1

db_file = Path(clean_args[0]) if len(clean_args) > 0 else Path("www/nyayasaral_db.json")
mat_arg = clean_args[1] if len(clean_args) > 1 else ""
index_file = Path(clean_args[2]) if len(clean_args) > 2 else Path("data/osmania_drive_index.json")
report_file = Path(clean_args[3]) if len(clean_args) > 3 else Path("reports/osmania_dual_source_report.json")

if not db_file.exists():
    raise SystemExit(f"ERROR: Database not found at {db_file}")

CANONICAL_SUBJECTS = [
    ("law-of-contract-i", "Law of Contract - I", "Semester 1", ["contract i", "contract prr", "law of contracts.pdf", "contract-i"]),
    ("family-law-i", "Family Law - I (Hindu Law)", "Semester 1", ["hindu law", "family law-1", "family law i", "family law - i"]),
    ("constitutional-law-i", "Constitutional Law - I", "Semester 1", ["constitutional law1", "constitutional law-i", "constitutional law.pdf", "prr constitutional"]),
    ("law-of-torts", "Law of Torts", "Semester 1", ["torts"]),
    ("environmental-law", "Environmental Law", "Semester 1", ["environmental"]),
    ("law-of-contract-ii", "Law of Contracts - II", "Semester 2", ["contract - ii", "contract ii", "contract-ii"]),
    ("family-law-ii", "Family Law - II (Muslim Law)", "Semester 2", ["family law - ii", "family law ii", "muslim law"]),
    ("constitutional-law-ii", "Constitutional Law - II", "Semester 2", ["constitutional law - ii", "constitutional law ii"]),
    ("law-of-crimes", "Law of Crimes (IPC / BNS)", "Semester 2", ["law of crimes", "crimes", "ipc"]),
    ("law-of-evidence", "Law of Evidence (IEA / BSA)", "Semester 2", ["law of evidence", "evidence"]),
    ("jurisprudence", "Jurisprudence", "Semester 3", ["jurisprudence"]),
    ("law-of-property", "Law of Property (TPA)", "Semester 3", ["law of property", "property"]),
    ("administrative-law", "Administrative Law", "Semester 3", ["administrative law", "administrative"]),
    ("company-law", "Company Law", "Semester 3", ["company law", "company"]),
    ("labour-law-i", "Labour Law - I", "Semester 3", ["labour law - i", "labour law i", "labour law-i"]),
    ("labour-law-ii", "Labour Law - II", "Semester 4", ["labour law - ii", "labour law ii", "labour law-ii"]),
    ("public-international-law", "Public International Law", "Semester 4", ["public international law", "international law"]),
    ("interpretation-of-statutes", "Interpretation of Statutes", "Semester 4", ["interpretation of statutes", "interpretation"]),
    ("land-laws", "Land Laws", "Semester 4", ["land laws", "land law"]),
    ("intellectual-property-law", "Intellectual Property Law", "Semester 4", ["intellectual property", "ipr"]),
    ("civil-procedure-code", "Civil Procedure Code & Limitation", "Semester 5", ["civil procedure code", "cpc"]),
    ("criminal-procedure-code", "Criminal Procedure Code (CrPC / BNSS)", "Semester 5", ["criminal procedure code", "cr. p c", "crpc"]),
    ("banking-law", "Banking Law", "Semester 5", ["banking"]),
    ("alternate-dispute-resolution", "Alternate Dispute Resolution (ADR)", "Semester 5", ["alternate dispute resolution", "adr"]),
    ("professional-ethics", "Professional Ethics & Accounting", "Semester 5", ["professional ethics"]),
    ("law-of-taxation", "Law of Taxation (Income Tax & GST)", "Semester 6", ["taxation", "taxiation"]),
    ("information-technology-law", "Information Technology & Cyber Law", "Semester 6", ["information technology", "it law", "info. tech"]),
    ("law-relating-to-women", "Law Relating to Women", "Semester 6", ["relating to women", "law of women"]),
    ("human-rights-law", "Human Rights Law", "Semester 6", ["human right", "humanright"]),
    ("drafting-pleading-conveyancing", "Drafting, Pleading & Conveyancing (DPC)", "Semester 6", ["dpc", "drafting"]),
    ("moot-court", "Moot Court & Trial Advocacy", "Semester 6", ["moot court"]),
]

BOILERPLATE_RE = re.compile(
    r"(?im)^(?:"
    r".*fb\.com/groups/sucl\.hyd.*"
    r"|.*my\s+fair\s+garden.*"
    r"|.*harinath\s+janumpally.*"
    r"|.*abdul\s+kareem.*|.*sameer\s+hussain.*"
    r"|.*padala\s+rama\s+redd[iy]\s+law\s+college.*"
    r"|.*prrlawcollege.*"
    r"|.*sultan-ul-uloom.*"
    r"|.*yellareddyguda.*ameerpet.*"
    r"|.*law\s+students\s+federation.*"
    r"|.*contact\s+us\s*:.*|.*please\s+contact.*9603255350.*"
    r"|\s*-?\s*\d{1,3}\s*-?\s*"
    r"|\s*pg\.?\s*\d+\s*|\s*page\s*\d+\s*"
    r")$"
)

OCR_GRAMMAR_FIXES = [
    (r"\bsallent\b", "salient"), (r"\bsaleint\b", "salient"),
    (r"\btaxiation\b", "taxation"), (r"\bjuridications?\b", "jurisdiction"),
    (r"\bporonography\b", "pornography"), (r"\bdistrubated\b", "distributed"),
    (r"\bgodwon\b", "godown"), (r"\bchartable\b", "charitable"),
    (r"\bploice\b", "police"), (r"\bcababilities\b", "capabilities"),
    (r"\bsatergy\b", "strategy"), (r"\bterrorosim\b", "terrorism"),
    (r"\bintergration\b", "integration"), (r"\bmen['\u2019]s\s+rea\b", "Mens Rea"),
    (r"\blis\s+pen\s*dens\b", "Lis Pendens"), (r"\bres\s+ispa\s+loquitor\b", "Res Ipsa Loquitur"),
    (r"\bdamnum\s+sine\s+darnnum\b", "Damnum Sine Injuria"),
    (r"\bconsensus\s+ad\s+ledm\b", "Consensus ad Idem"),
    (r"\bdefination\b", "definition"), (r"\bagrement\b", "agreement"),
    (r"\bconsideraton\b", "consideration"), (r"\bliablity\b", "liability"),
    (r"\bconstituton\b", "constitution"), (r"\benviroment\b", "environment"),
    (r"\boccured\b", "occurred"), (r"\brecieve\b", "receive"),
    (r"\bseperate\b", "separate"), (r"\buntill\b", "until"),
    (r"\bgoverment\b", "government"), (r"\bjudical\b", "judicial"),
    (r"\bstatutary\b", "statutory"), (r"\bnegligance\b", "negligence"),
    (r"\bcompansation\b", "compensation"), (r"\bevidance\b", "evidence"),
    (r"\bplaintif\b", "plaintiff"), (r"\bdefendent\b", "defendant"),
    (r"\bin\s+in\b", "in"), (r"\bthese\s+is\s+details\b", "These are the details"),
    (r"\bthese\s+tax\s+is\b", "This tax is"), (r"\bthere\s+is\s+also\s+deduction\b", "Deduction is also allowed"),
]

LEGAL_CAPS = [
    (r"\bindian contract act\b", "Indian Contract Act"),
    (r"\bconstitution of india\b", "Constitution of India"),
    (r"\bsupreme court\b", "Supreme Court"),
    (r"\bhigh court\b", "High Court"),
    (r"\bindian penal code\b", "Indian Penal Code"),
    (r"\bbharatiya nyaya sanhita\b", "Bharatiya Nyaya Sanhita"),
    (r"\bbharatiya nagarik suraksha sanhita\b", "Bharatiya Nagarik Suraksha Sanhita"),
    (r"\bbharatiya sakshya adhiniyam\b", "Bharatiya Sakshya Adhiniyam"),
    (r"\bcode of criminal procedure\b", "Code of Criminal Procedure"),
    (r"\bcode of civil procedure\b", "Code of Civil Procedure"),
    (r"\bindian evidence act\b", "Indian Evidence Act"),
    (r"\bincome tax act\b", "Income Tax Act"),
    (r"\binformation technology act\b", "Information Technology Act"),
    (r"\btransfer of property act\b", "Transfer of Property Act"),
    (r"\bhindu marriage act\b", "Hindu Marriage Act"),
    (r"\bhindu succession act\b", "Hindu Succession Act"),
    (r"\bsale of goods act\b", "Sale of Goods Act"),
    (r"\bindian partnership act\b", "Indian Partnership Act"),
    (r"\bconsumer protection act\b", "Consumer Protection Act"),
    (r"\buniversal declaration of human rights\b", "Universal Declaration of Human Rights"),
    (r"\bsection\s+(\d+[a-zA-Z0-9()\-]*)", r"Section \1"),
    (r"\bsec\.\s*(\d+[a-zA-Z0-9()\-]*)", r"Section \1"),
    (r"\barticle\s+(\d+[a-zA-Z0-9()\-]*)", r"Article \1"),
    (r"\bart\.\s*(\d+[a-zA-Z0-9()\-]*)", r"Article \1"),
]

A_AN_EXCEPT = re.compile(r"^(?:uni|use|usu|one|onc|eu|u[bcdfghjklmnpqrstvwxyz][aeiou]|hour|honest|honour|heir)", re.I)

def fix_a_an(m):
    w = m.group(2)
    if A_AN_EXCEPT.match(w):
        return m.group(0)
    return ("An " if m.group(1)[0].isupper() else "an ") + w

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

    for pat, rep in OCR_GRAMMAR_FIXES:
        s = re.sub(pat, lambda m, r=rep: (r[0].upper() + r[1:] if m.group(0)[0].isupper() and r[0].islower() else r), s, flags=re.I)
    for pat, rep in LEGAL_CAPS:
        s = re.sub(pat, rep, s, flags=re.I)
    s = re.sub(r"\b(a|A)\s+([aeiouAEIOU][a-z]{2,})\b", fix_a_an, s)

    if s and s[0].islower():
        s = s[0].upper() + s[1:]
    s = re.sub(r"([\.\?\!]\s+)([a-z])", lambda m: m.group(1) + m.group(2).upper(), s)
    if ensure_period and len(s) >= 18 and s[-1] not in ".?!:\"' )]}":
        s += "."
    return s, (1 if s != orig.strip() else 0)

def polish_title(title):
    s = re.sub(r"^(?:Q\.?\s*No\.?|Que\.?\s*No\.?|Q)\s*\d+[\.\:\-\)]*\s*", "", str(title or ""), flags=re.I)
    s = re.sub(r"^\d+[\.\)]\s*", "", s).strip(" :-.")
    if s.isupper() and len(s) > 6:
        s = s.title()
    s, ch = strict_grammar_polish(s, ensure_period=False)
    return s.rstrip("."), ch

def extract_pdf(raw_bytes):
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

def extract_docx(raw_bytes):
    out = []
    with zipfile.ZipFile(io.BytesIO(raw_bytes)) as zf:
        if "word/document.xml" not in zf.namelist():
            return ""
        root = ET.fromstring(zf.read("word/document.xml"))
        ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
        for p in root.findall(".//w:p", ns):
            ln = "".join(t.text for t in p.findall(".//w:t", ns) if t.text).strip()
            if ln:
                out.append(ln)
    return "\n".join(out)

def load_unique_material_files(mat_path):
    docs, seen_hashes, dup_files = [], set(), []
    p = Path(mat_path)
    supported = {".pdf", ".docx", ".txt", ".md"}

    def handle(rel_name, raw_bytes):
        low = rel_name.lower()
        if "syllubus" in low or "syllabus" in low:
            return
        h = hashlib.sha256(raw_bytes).hexdigest()
        if h in seen_hashes:
            dup_files.append(rel_name)
            return
        seen_hashes.add(h)
        ext = Path(rel_name).suffix.lower()
        txt = extract_pdf(raw_bytes) if ext == ".pdf" else (extract_docx(raw_bytes) if ext == ".docx" else raw_bytes.decode("utf-8", errors="ignore"))
        cleaned_lines = [ln.strip() for ln in txt.splitlines() if ln.strip() and not BOILERPLATE_RE.match(ln.strip())]
        cleaned = "\n".join(cleaned_lines)
        if len(cleaned) >= 120:
            docs.append((rel_name, cleaned))

    if p.is_file() and p.suffix.lower() == ".zip":
        with zipfile.ZipFile(p, "r") as zf:
            for info in zf.infolist():
                if info.is_dir() or "__MACOSX" in info.filename:
                    continue
                if Path(info.filename).suffix.lower() in supported:
                    handle(info.filename, zf.read(info.filename))
    elif p.is_dir():
        for fp in sorted(p.rglob("*")):
            if fp.is_file() and fp.suffix.lower() in supported:
                handle(str(fp.relative_to(p)), fp.read_bytes())
    return docs, dup_files

CASE_RE = re.compile(r"\b([A-Z][A-Za-z\.&\s]{2,42}\s+(?:v\.|vs\.?|Vs\.?)\s+[A-Z][A-Za-z\.&\s]{2,48})(?:\s*\((\d{4})\))?")
PROV_RE = re.compile(r"\b((?:Section|Sections|Sec\.|Article|Articles|Art\.|Order|Rule)\s+\d+[A-Za-z0-9()\-/,\s]*(?:of\s+(?:the\s+)?[A-Z][A-Za-z\s,]{3,55})?)", re.I)

def parse_qa_concepts(rel_path, cleaned_text):
    lines = cleaned_text.splitlines()
    blocks, cur_q, cur_body = [], "", []
    for ln in lines:
        if re.match(r"^(?:Q\.?\s*No\.?\s*\d+|Que\.?\s*No\.?\s*\d+|Q\d+|2\.No\d+)[\.\:\-\)]", ln, re.I):
            if cur_q and len(" ".join(cur_body)) >= 140:
                blocks.append((cur_q, cur_body))
            cur_q = ln
            cur_body = []
        elif re.match(r"^\d{1,2}\.\s+[A-Z]{4,}", ln) and len(ln) <= 130:
            if cur_q and len(" ".join(cur_body)) >= 140:
                blocks.append((cur_q, cur_body))
            cur_q = ln
            cur_body = []
        else:
            cur_body.append(ln)
    if cur_q and len(" ".join(cur_body)) >= 140:
        blocks.append((cur_q, cur_body))

    concepts = []
    for raw_q, body_lines in blocks:
        body_clean_lines = [re.sub(r"^(?:Ans(?:wer)?\.?\s*[:\-]*\s*)", "", ln, flags=re.I).strip() for ln in body_lines]
        body_clean_lines = [ln for ln in body_clean_lines if ln]
        full_body = re.sub(r"\s+", " ", " ".join(body_clean_lines)).strip()
        if len(full_body) < 140:
            continue

        title, _ = polish_title(raw_q)
        if len(title) < 6 or len(title) > 130:
            continue

        sents = [s.strip() for s in re.split(r"(?<=[\.\?\!])\s+", full_body) if len(s.strip()) >= 25]
        if len(sents) < 2:
            continue

        provs = list(dict.fromkeys(m.group(1).strip(" ,.;:") for m in PROV_RE.finditer(full_body)))[:4]
        cases, seen_c = [], set()
        for cm in CASE_RE.finditer(full_body):
            cn, _ = polish_title(cm.group(1))
            ck = cn.lower()
            if ck not in seen_c and len(cn) >= 8:
                seen_c.add(ck)
                ctx = full_body[max(0, cm.start() - 30):min(len(full_body), cm.end() + 180)].strip()
                pr_c, _ = strict_grammar_polish(ctx, ensure_period=True)
                cases.append({"name": cn, "citation": cm.group(2) or "", "principle": pr_c})

        kps = []
        for ln in body_clean_lines:
            if re.match(r"^(?:\d+[\.\)]|\([a-z0-9ivx]+\)|[\-\*\u2022])\s+", ln, re.I):
                pt = re.sub(r"^(?:\d+[\.\)]|\([a-z0-9ivx]+\)|[\-\*\u2022])\s+", "", ln, flags=re.I).strip()
                if 22 <= len(pt) <= 320:
                    kps.append(pt)
        if len(kps) < 3:
            kps = sents[2:8]

        m1, _ = strict_grammar_polish(" ".join(sents[:2])[:420], ensure_period=True)
        mn, _ = strict_grammar_polish(" ".join(sents[1:4])[:700], ensure_period=True)
        pv, _ = strict_grammar_polish("; ".join(provs), ensure_period=False)

        concepts.append({
            "sourceFile": rel_path,
            "title": title,
            "en": {
                "inOneMinute": m1,
                "legalProvision": pv,
                "meaning": mn,
                "keyPoints": [strict_grammar_polish(p, True)[0] for p in kps[:8]],
                "caseLaws": cases[:4],
                "selfTest": [{"q": f"Explain {title} with relevant legal provisions.", "a": m1}],
                "visuals": []
            }
        })
    return concepts

STOP = {"the", "and", "for", "with", "from", "that", "this", "under", "into", "law", "act", "india", "indian", "explain", "discuss", "define", "what", "are", "short", "notes", "sem", "semester", "llb", "ydc", "prr", "lsf", "pdf"}

def tokset(s):
    return {w for w in re.findall(r"[a-z0-9]+", str(s or "").lower()) if len(w) >= 3 and w not in STOP}

def jaccard(a, b):
    return (len(a & b) / max(1, len(a | b))) if (a and b) else 0.0

def overlaps(cand, pool, thresh=0.50):
    ct = tokset(cand)
    if len(ct) < 3:
        return True
    cl = cand.strip().lower()
    for ex in pool:
        el = str(ex or "").strip().lower()
        if not el:
            continue
        if cl in el or el in cl or jaccard(ct, tokset(el)) >= thresh:
            return True
    return False

def resolve_canonical_subject(rel_path):
    low = rel_path.lower().replace("\\", "/")
    for sid, title, sem, aliases in CANONICAL_SUBJECTS:
        for a in aliases:
            if a in low:
                return sid, title, sem
    return None, None, None

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
subj_by_id = {s.get("id"): s for s in subjects if isinstance(s, dict)}

docs, dup_files = load_unique_material_files(mat_arg) if (mat_arg and Path(mat_arg).exists()) else ([], [])
all_concepts = []
for rel_p, txt in docs:
    sid, stitle, sem = resolve_canonical_subject(rel_p)
    if not sid:
        continue
    if only_sem and only_sem.lower() not in sem.lower():
        continue
    for c in parse_qa_concepts(rel_p, txt):
        c["subjectId"] = sid
        c["subjectTitle"] = stitle
        c["semester"] = sem
        all_concepts.append(c)

stats = {
    "uniqueFilesParsed": len(docs),
    "exactDuplicatePdfsSkipped": len(dup_files),
    "conceptsExtracted": len(all_concepts),
    "newSubjectsAdded": [],
    "existingTopicsEnriched": 0,
    "newTopicsCreated": 0,
    "pointsAdded": 0,
    "casesAdded": 0,
    "overlapsBlocked": 0
}

for c in all_concepts:
    sid, stitle, sem = c["subjectId"], c["subjectTitle"], c["semester"]
    subj = subj_by_id.get(sid)
    if subj is None:
        subj = {"id": sid, "title": stitle, "semester": sem, "url": "", "units": []}
        subjects.append(subj)
        subj_by_id[sid] = subj
        stats["newSubjectsAdded"].append(f"{stitle} ({sem})")

    best_t, best_sc = None, 0.0
    ct = tokset(c["title"])
    for u in subj.get("units", []):
        for t in u.get("topics", []):
            sc = jaccard(ct, tokset(t.get("title", "")))
            if sc > best_sc:
                best_sc, best_t = sc, t

    if best_t and best_sc >= 0.45:
        rec = notes.get(best_t["id"])
        if not isinstance(rec, dict) or not isinstance(rec.get("en"), dict):
            continue
        en = rec["en"]
        pool = [en.get("inOneMinute", ""), en.get("meaning", ""), en.get("legalProvision", "")]
        kps = en.get("keyPoints") if isinstance(en.get("keyPoints"), list) else []
        for k in kps:
            pool.append(k if isinstance(k, str) else str((k or {}).get("point") or (k or {}).get("text") or ""))

        added = False
        for pt in c["en"]["keyPoints"]:
            if overlaps(pt, pool, 0.50):
                stats["overlapsBlocked"] += 1
                continue
            kps.append(pt); pool.append(pt); stats["pointsAdded"] += 1; added = True
        en["keyPoints"] = kps

        ex_cases = en.get("caseLaws") if isinstance(en.get("caseLaws"), list) else []
        ex_cnames = [(x if isinstance(x, str) else str((x or {}).get("name") or "")).lower() for x in ex_cases]
        for cl in c["en"]["caseLaws"]:
            if overlaps(cl["name"], ex_cnames, 0.55):
                stats["overlapsBlocked"] += 1
                continue
            ex_cases.append(cl); ex_cnames.append(cl["name"].lower()); stats["casesAdded"] += 1; added = True
        en["caseLaws"] = ex_cases

        if not str(en.get("legalProvision", "")).strip() and c["en"]["legalProvision"]:
            en["legalProvision"] = c["en"]["legalProvision"]; added = True

        if added:
            for tl in ("te", "hi"):
                rec.pop(tl, None)
            stats["existingTopicsEnriched"] += 1
    else:
        slug = re.sub(r"[^a-z0-9]+", "-", c["title"].lower()).strip("-")[:42] or "topic"
        tid = f"{sid}-ou-{slug}"
        if tid in notes:
            stats["overlapsBlocked"] += 1
            continue
        units = subj.setdefault("units", [])
        target_u = next((u for u in units if "osmania" in str(u.get("title", "")).lower()), None)
        if target_u is None:
            u_name = "Osmania LL.B. Exam Units" if not units else "Osmania Study Material Supplement"
            target_u = {"unitNo": len(units) + 1, "title": u_name, "topics": []}
            units.append(target_u)
        target_u["topics"].append({"id": tid, "title": c["title"]})
        notes[tid] = {
            "id": tid,
            "subtitle": f"{stitle} - {sem}",
            "readTime": "4 min read",
            "url": "",
            "en": c["en"]
        }
        stats["newTopicsCreated"] += 1

report_file.parent.mkdir(parents=True, exist_ok=True)
report_file.write_text(json.dumps(stats, ensure_ascii=False, indent=2), encoding="utf-8")

if not dry_run:
    write_onedrive_safe(db_file, json.dumps(db, ensure_ascii=False, separators=(",", ":")))
    print(f"[SAVED] Updated English DB -> {db_file.name}", flush=True)
else:
    print("[DRY-RUN] Preview only (nyayasaral_db.json untouched).", flush=True)

print("\n=== OSMANIA 3YDC DUAL-SOURCE REPORT ===", flush=True)
print(f"  Unique PDFs Parsed:          {stats['uniqueFilesParsed']} (Skipped {stats['exactDuplicatePdfsSkipped']} exact duplicate PDFs)", flush=True)
print(f"  Structured Concepts Found:   {stats['conceptsExtracted']}", flush=True)
print(f"  New Subjects Scaffolded:     {len(stats['newSubjectsAdded'])} -> {stats['newSubjectsAdded']}", flush=True)
print(f"  Existing Topics Enriched:    {stats['existingTopicsEnriched']} (+{stats['pointsAdded']} points, +{stats['casesAdded']} cases)", flush=True)
print(f"  New English Topics Added:    {stats['newTopicsCreated']}", flush=True)
print(f"  Overlaps Blocked:            {stats['overlapsBlocked']}", flush=True)