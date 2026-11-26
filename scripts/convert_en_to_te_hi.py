import concurrent.futures, copy, json, re, sys, threading, time, urllib.parse, urllib.request
from pathlib import Path

args = sys.argv[1:]
rebuild_te = "--rebuild-te" in args
args = [a for a in args if a != "--rebuild-te"]

db_file = Path(args[0]) if len(args) > 0 else Path("www/nyayasaral_db.json")
batch_limit = int(args[1]) if len(args) > 1 else 0
workers = int(args[2]) if len(args) > 2 else 8
ckpt_file = Path(args[3]) if len(args) > 3 else Path(".ls_legal_tr_cache.json")

if not db_file.exists():
    raise SystemExit(f"ERROR: Database not found at {db_file}")

print(f"[INIT] Loading {db_file.name} (rebuild_te={rebuild_te}) ...", flush=True)
raw_str = db_file.read_text(encoding="utf-8")
db = json.loads(raw_str)
notes = db.get("notes")
if not isinstance(notes, dict) or not notes:
    raise SystemExit("ERROR: Invalid or empty 'notes' dictionary.")

bak_file = db_file.with_suffix(".json.bak")
if not bak_file.exists():
    bak_file.write_text(raw_str, encoding="utf-8")

LEGAL_TOKEN_RE = re.compile(
    r"(<[^>]+>"
    r"|\b(?:Section|Sec\.|Article|Art\.|Order|Rule|Schedule|Clause|Chapter|Entry)\s+\d+[A-Za-z0-9()\-/]*"
    r"|\b(?:IPC|CrPC|CPC|BNS|BNSS|BSA|ICA|TPA|HMA|SRA|NIA|IT Act|AIR|SCC|SCR|PIL|FIR|NHRC)\b"
    r"|\b\d{4}\s*(?:SCC|AIR|SCR|SC)\s*\d+\b"
    r"|\b(?:Mens Rea|Actus Reus|Ratio Decidendi|Obiter Dicta|Ultra Vires|Intra Vires|Res Judicata|Sub Judice|"
    r"Habeas Corpus|Mandamus|Certiorari|Quo Warranto|Prohibition|Locus Standi|Audi Alteram Partem|"
    r"Nemo Judex in Causa Sua|Caveat Emptor|Quid Pro Quo|Consensus ad Idem|Void ab Initio|"
    r"Uberrimae Fidei|Volenti Non Fit Injuria|Damnum Sine Injuria|Injuria Sine Damno|Strict Liability|"
    r"Absolute Liability|Vicarious Liability|Promissory Estoppel|Basic Structure)\b)",
    re.I,
)

SKIP_KEYS = {"id", "type", "html", "svg", "mermaid", "code", "citation", "year", "sectionNo", "articleNo", "visuals"}

TELUGU_CLEANUPS = [
    (r"\s+([,\.\;\:\?\!])", r"\1"),
    (r"([,\.\;\:])([^\s\d\"'\)\]])", r"\1 \2"),
    (r"\s{2,}", " "),
    (r"\(\s+", "("),
    (r"\s+\)", ")"),
]

def polish_telugu(text):
    s = str(text or "").strip()
    if not s:
        return ""
    for pat, rep in TELUGU_CLEANUPS:
        s = re.sub(pat, rep, s)
    return s.strip()

def sample_text(obj):
    if not isinstance(obj, dict):
        return ""
    out = []
    for f in ("inOneMinute", "meaning", "legalProvision", "keyPoints"):
        v = obj.get(f)
        if isinstance(v, str) and v.strip():
            out.append(v.strip())
        elif isinstance(v, list):
            for it in v[:3]:
                if isinstance(it, str) and it.strip():
                    out.append(it.strip())
                elif isinstance(it, dict):
                    for k in ("summary", "principle", "text", "point"):
                        if isinstance(it.get(k), str) and it[k].strip():
                            out.append(it[k].strip())
    return " ".join(out)[:600]

def has_good_script(obj, lang, en_obj=None):
    s = sample_text(obj)
    if len(s) < 8:
        return False
    lo, hi = ("\u0c00", "\u0c7f") if lang == "te" else ("\u0900", "\u097f")
    alpha = sum(1 for c in s if c.isalpha())
    if alpha == 0:
        return False
    if (sum(1 for c in s if lo <= c <= hi) / alpha) < 0.30:
        return False
    if isinstance(en_obj, dict):
        for req_f in ("inOneMinute", "meaning", "keyPoints"):
            en_v = en_obj.get(req_f)
            tr_v = obj.get(req_f)
            if isinstance(en_v, str) and len(en_v.strip()) > 30:
                if not isinstance(tr_v, str) or len(tr_v.strip()) < 10:
                    return False
            elif isinstance(en_v, list) and len(en_v) > 0:
                if not isinstance(tr_v, list) or len(tr_v) == 0:
                    return False
    return True

def sync_visuals_verbatim(rec):
    en = rec.get("en")
    if not isinstance(en, dict):
        return False
    en_vis = en.get("visuals")
    if not isinstance(en_vis, list):
        return False
    changed = False
    for lang in ("te", "hi"):
        ld = rec.get(lang)
        if isinstance(ld, dict) and ld.get("visuals") != en_vis:
            ld["visuals"] = copy.deepcopy(en_vis)
            changed = True
    return changed

def protect_tokens(text):
    tokens = []
    def repl(m):
        tokens.append(m.group(0))
        return f"[[LTOK{len(tokens) - 1}]]"
    return LEGAL_TOKEN_RE.sub(repl, text), tokens

def restore_tokens(text, tokens):
    for i, tok in enumerate(tokens):
        text = re.sub(rf"\[\[\s*LTOK\s*{i}\s*\]\]", lambda _m, t=tok: t, text, flags=re.I)
        text = re.sub(rf"__\s*LTOK\s*{i}\s*__", lambda _m, t=tok: t, text, flags=re.I)
    return text

def split_text(s, limit=1050):
    s = s.strip()
    if len(s) <= limit:
        return [s] if s else []
    parts, rem = [], s
    while len(rem) > limit:
        cut = rem.rfind(". ", 200, limit)
        if cut == -1:
            cut = rem.rfind(" ", 200, limit)
        if cut == -1:
            cut = limit
        parts.append(rem[:cut + 1].strip())
        rem = rem[cut + 1:].strip()
    if rem:
        parts.append(rem)
    return parts

cache, cache_lock = {}, threading.Lock()
if ckpt_file.exists():
    try:
        loaded = json.loads(ckpt_file.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            cache = loaded
    except Exception:
        pass

def gtrans_raw(text, tl):
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={urllib.parse.quote(tl)}&dt=t&q={urllib.parse.quote(text)}"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=9) as resp:
                arr = json.loads(resp.read().decode("utf-8", errors="ignore"))
                if isinstance(arr, list) and arr and isinstance(arr[0], list):
                    txt = "".join(x[0] for x in arr[0] if isinstance(x, list) and x and isinstance(x[0], str))
                    if txt.strip():
                        return txt
            return text
        except Exception:
            if attempt < 2:
                time.sleep(0.35 * (attempt + 1))
    return text

def tr_single(text, tl):
    s = re.sub(r"\s+", " ", str(text or "")).strip()
    if not s:
        return ""
    ck = f"v2:{tl}:{s}"
    with cache_lock:
        if ck in cache:
            return cache[ck]
    masked, tokens = protect_tokens(s)
    res = restore_tokens(" ".join(gtrans_raw(ch, tl).strip() for ch in split_text(masked, 1050)).strip(), tokens)
    if tl == "te":
        res = polish_telugu(res)
    with cache_lock:
        cache[ck] = res
    return res

def tr_batch(strings, tl):
    results, todo = {}, []
    for orig in strings:
        clean = re.sub(r"\s+", " ", str(orig or "")).strip()
        if not clean:
            results[orig] = ""
            continue
        with cache_lock:
            hit = cache.get(f"v2:{tl}:{clean}")
        if hit is not None:
            results[orig] = hit
        else:
            todo.append((orig, clean))

    batches, cur, cur_len = [], [], 0
    for orig, clean in todo:
        masked, tokens = protect_tokens(clean)
        if len(masked) > 1000:
            if cur:
                batches.append(cur); cur, cur_len = [], 0
            batches.append([(orig, clean, masked, tokens)])
            continue
        if cur and (cur_len + len(masked) + 1) > 1250:
            batches.append(cur); cur, cur_len = [], 0
        cur.append((orig, clean, masked, tokens))
        cur_len += len(masked) + 1
    if cur:
        batches.append(cur)

    for b in batches:
        if len(b) == 1:
            results[b[0][0]] = tr_single(b[0][1], tl)
            continue
        raw_out = gtrans_raw("\n".join(x[2] for x in b), tl)
        lines = [ln.strip() for ln in raw_out.splitlines() if ln.strip()]
        if len(lines) == len(b):
            for (orig, clean, _, tokens), ln in zip(b, lines):
                val = restore_tokens(ln, tokens)
                if tl == "te":
                    val = polish_telugu(val)
                with cache_lock:
                    cache[f"v2:{tl}:{clean}"] = val
                results[orig] = val
        else:
            for orig, clean, _, _ in b:
                results[orig] = tr_single(clean, tl)
    return results

def collect_str(val, out):
    if isinstance(val, str) and val.strip():
        out.append(val)
    elif isinstance(val, list):
        for x in val:
            collect_str(x, out)
    elif isinstance(val, dict):
        for k, v in val.items():
            if k not in SKIP_KEYS:
                collect_str(v, out)

def apply_str(val, mp):
    if isinstance(val, str):
        return mp.get(val, val)
    if isinstance(val, list):
        return [apply_str(x, mp) for x in val]
    if isinstance(val, dict):
        return {k: (v if k in SKIP_KEYS else apply_str(v, mp)) for k, v in val.items()}
    return val

def prepare_copy(en_obj, tl):
    strs = []
    collect_str(en_obj, strs)
    mp = tr_batch(list(dict.fromkeys(strs)), tl)
    out = {}
    for k, v in en_obj.items():
        if k == "visuals":
            out[k] = copy.deepcopy(v)
        else:
            out[k] = apply_str(v, mp)
    out["_trQuality"] = "v2-legal"
    return out

def save_atomic():
    tmp = db_file.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(db, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    json.loads(tmp.read_text(encoding="utf-8"))
    tmp.replace(db_file)
    try:
        with cache_lock:
            ckpt_file.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass

vis_synced = 0
for tid, rec in notes.items():
    if isinstance(rec, dict) and sync_visuals_verbatim(rec):
        vis_synced += 1

total = len(notes)
work = []
for tid, rec in notes.items():
    if not isinstance(rec, dict):
        continue
    en = rec.get("en")
    if not isinstance(en, dict) or len(sample_text(en)) < 4:
        continue
    te_obj = rec.get("te")
    hi_obj = rec.get("hi")
    need_te = (not has_good_script(te_obj, "te", en)) or (rebuild_te and (not isinstance(te_obj, dict) or te_obj.get("_trQuality") != "v2-legal"))
    need_hi = not has_good_script(hi_obj, "hi", en)
    if need_te or need_hi:
        work.append((tid, need_te, need_hi))

if batch_limit > 0:
    work = work[:batch_limit]

print(f"[AUDIT] Total={total} | Verbatim Diagrams Synced={vis_synced} | Pending Conversion/Upgrade={len(work)}", flush=True)
if not work:
    if vis_synced > 0:
        save_atomic()
    print("[PASS] All EN/TE/HI notes verified & diagrams locked verbatim!", flush=True)
    sys.exit(0)

def run_topic(item):
    tid, need_te, need_hi = item
    en = notes[tid]["en"]
    return tid, (prepare_copy(en, "te") if need_te else None), (prepare_copy(en, "hi") if need_hi else None)

done, te_new, hi_new, start_ts = 0, 0, 0, time.time()
try:
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(run_topic, w): w[0] for w in work}
        for fut in concurrent.futures.as_completed(futs):
            tid = futs[fut]
            try:
                tid, te_c, hi_c = fut.result()
                if te_c is not None:
                    notes[tid]["te"] = te_c; te_new += 1
                if hi_c is not None:
                    notes[tid]["hi"] = hi_c; hi_new += 1
                sync_visuals_verbatim(notes[tid])
                done += 1
                rate = done / max(0.01, time.time() - start_ts)
                print(f"  [{done}/{len(work)}] {tid} | TE_Upgraded:{te_new} HI_Added:{hi_new} | ETA ~{int((len(work)-done)/rate)}s", flush=True)
                if done % 20 == 0:
                    save_atomic()
                    print(f"  [SAVED] Atomic checkpoint at {done}/{len(work)}", flush=True)
            except Exception as exc:
                print(f"  [SKIP] {tid}: {exc}", flush=True)
except KeyboardInterrupt:
    print("\n[STOPPED] Saving completed upgrades safely...", flush=True)

save_atomic()
te_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_good_script(r.get("te"), "te", r.get("en")))
hi_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_good_script(r.get("hi"), "hi", r.get("en")))
print(f"[PASS] Upgrade Complete: Total={total} | Verified TE={te_ok}/{total} | Verified HI={hi_ok}/{total} | Diagrams=100% Verbatim", flush=True)