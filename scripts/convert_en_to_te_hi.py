import concurrent.futures, json, re, sys, threading, time, urllib.parse, urllib.request
from pathlib import Path

db_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("www/nyayasaral_db.json")
batch_limit = int(sys.argv[2]) if len(sys.argv) > 2 else 0
workers = int(sys.argv[3]) if len(sys.argv) > 3 else 8
ckpt_file = Path(sys.argv[4]) if len(sys.argv) > 4 else Path(".ls_legal_tr_cache.json")

if not db_file.exists():
    raise SystemExit(f"ERROR: Database not found at {db_file}")

print(f"[INIT] Loading {db_file.name} ...", flush=True)
raw_str = db_file.read_text(encoding="utf-8")
db = json.loads(raw_str)
notes = db.get("notes")
if not isinstance(notes, dict) or not notes:
    raise SystemExit("ERROR: Invalid or empty 'notes' dictionary.")

bak_file = db_file.with_suffix(".json.bak")
if not bak_file.exists():
    bak_file.write_text(raw_str, encoding="utf-8")

LEGAL_TOKEN_RE = re.compile(
    r"(<[^>]+>|\b(?:Section|Sec\.|Article|Art\.|Order|Rule|Schedule|Clause|Chapter)\s+\d+[A-Za-z0-9()\-/]*"
    r"|\b(?:IPC|CrPC|CPC|BNS|BNSS|BSA|ICA|TPA|HMA|SRA|NIA|AIR|SCC|SCR)\b|\b\d{4}\s*(?:SCC|AIR|SCR|SC)\s*\d+\b)"
)
SKIP_KEYS = {"id", "type", "html", "svg", "mermaid", "code", "citation", "year", "sectionNo", "articleNo", "visuals"}

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

def has_target_script(obj, lang):
    s = sample_text(obj)
    if len(s) < 8:
        return False
    lo, hi = ("\u0c00", "\u0c7f") if lang == "te" else ("\u0900", "\u097f")
    alpha = sum(1 for c in s if c.isalpha())
    if alpha == 0:
        return False
    return (sum(1 for c in s if lo <= c <= hi) / alpha) >= 0.25

def protect_tokens(text):
    tokens = []
    def repl(m):
        tokens.append(m.group(0))
        return f"__LTOK{len(tokens) - 1}__"
    return LEGAL_TOKEN_RE.sub(repl, text), tokens

def restore_tokens(text, tokens):
    for i, tok in enumerate(tokens):
        text = re.sub(rf"__\s*LTOK\s*{i}\s*__", lambda _m, t=tok: t, text, flags=re.I)
    return text

def split_text(s, limit=1100):
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
    ck = f"{tl}:{s}"
    with cache_lock:
        if ck in cache:
            return cache[ck]
    masked, tokens = protect_tokens(s)
    res = restore_tokens(" ".join(gtrans_raw(ch, tl).strip() for ch in split_text(masked, 1100)).strip(), tokens)
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
            hit = cache.get(f"{tl}:{clean}")
        if hit is not None:
            results[orig] = hit
        else:
            todo.append((orig, clean))

    batches, cur, cur_len = [], [], 0
    for orig, clean in todo:
        masked, tokens = protect_tokens(clean)
        if len(masked) > 1050:
            if cur:
                batches.append(cur); cur, cur_len = [], 0
            batches.append([(orig, clean, masked, tokens)])
            continue
        if cur and (cur_len + len(masked) + 1) > 1300:
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
                with cache_lock:
                    cache[f"{tl}:{clean}"] = val
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
    return {k: (v if k == "visuals" else apply_str(v, mp)) for k, v in en_obj.items()}

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

total = len(notes)
te_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_target_script(r.get("te"), "te"))
hi_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_target_script(r.get("hi"), "hi"))
work = [
    (tid, not has_target_script(rec.get("te"), "te"), not has_target_script(rec.get("hi"), "hi"))
    for tid, rec in notes.items()
    if isinstance(rec, dict) and isinstance(rec.get("en"), dict) and len(sample_text(rec["en"])) >= 4
    and (not has_target_script(rec.get("te"), "te") or not has_target_script(rec.get("hi"), "hi"))
]
if batch_limit > 0:
    work = work[:batch_limit]

print(f"[AUDIT] Total={total} | Verified Telugu={te_ok} | Verified Hindi={hi_ok} | Pending={len(work)}", flush=True)
if not work:
    print("[PASS] Every English note already has verified Telugu & Hindi script copies!", flush=True)
    sys.exit(0)

t0 = time.time()
probe = tr_single("Section 2(h) of the Indian Contract Act defines a contract.", "te")
print(f"[CHECK] Legal-token probe OK in {time.time() - t0:.2f}s (Section 2(h) preserved={'Section 2(h)' in probe})", flush=True)

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
                done += 1
                rate = done / max(0.01, time.time() - start_ts)
                print(f"  [{done}/{len(work)}] {tid} | +TE:{te_new} +HI:{hi_new} | ETA ~{int((len(work)-done)/rate)}s", flush=True)
                if done % 20 == 0:
                    save_atomic()
                    print(f"  [SAVED] Atomic checkpoint at {done}/{len(work)}", flush=True)
            except Exception as exc:
                print(f"  [SKIP] {tid}: {exc}", flush=True)
except KeyboardInterrupt:
    print("\n[STOPPED] Saving completed notes safely...", flush=True)

save_atomic()
te_f = sum(1 for r in notes.values() if isinstance(r, dict) and has_target_script(r.get("te"), "te"))
hi_f = sum(1 for r in notes.values() if isinstance(r, dict) and has_target_script(r.get("hi"), "hi"))
print(f"[PASS] Legal Conversion Complete: Total={total} | Verified TE={te_f}/{total} | Verified HI={hi_f}/{total}", flush=True)