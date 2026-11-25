import concurrent.futures
import json
import re
import sys
import threading
import time
import urllib.parse
import urllib.request
from pathlib import Path

db_file = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("www/nyayasaral_db.json")
batch_limit = int(sys.argv[2]) if len(sys.argv) > 2 else 0
workers = int(sys.argv[3]) if len(sys.argv) > 3 else 8
ckpt_file = Path(sys.argv[4]) if len(sys.argv) > 4 else Path(".ls_te_hi_cache.json")

if not db_file.exists():
    print(f"[SKIP] Database not found: {db_file}", flush=True)
    sys.exit(0)

raw_str = db_file.read_text(encoding="utf-8")
db = json.loads(raw_str)
notes = db.get("notes")
if not isinstance(notes, dict):
    raise RuntimeError("Invalid database: missing 'notes' dictionary.")

skip_keys = {"id", "type", "html", "svg", "mermaid", "code", "citation", "year", "sectionNo", "articleNo", "visuals"}

def has_content(obj):
    if not isinstance(obj, dict) or not obj:
        return False
    for f in ("inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest"):
        v = obj.get(f)
        if isinstance(v, str) and v.strip():
            return True
        if isinstance(v, list) and len(v) > 0:
            return True
    return False

work = []
for tid, rec in notes.items():
    if not isinstance(rec, dict):
        continue
    en = rec.get("en")
    if not isinstance(en, dict) or not has_content(en):
        continue
    need_te = not has_content(rec.get("te"))
    need_hi = not has_content(rec.get("hi"))
    if need_te or need_hi:
        work.append((tid, need_te, need_hi))

total = len(notes)
if not work:
    print(f"[PASS] Trilingual check OK: all {total} topics already have EN, TE & HI notes.", flush=True)
    sys.exit(0)

if batch_limit > 0:
    work = work[:batch_limit]

print(f"[AUTO-TR] Found {len(work)} topic(s) needing TE/HI notes out of {total} total...", flush=True)

cache = {}
cache_lock = threading.Lock()
if ckpt_file.exists():
    try:
        loaded = json.loads(ckpt_file.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            cache = loaded
    except Exception:
        cache = {}

def split_text(s, limit=1200):
    s = s.strip()
    if len(s) <= limit:
        return [s] if s else []
    parts = []
    rem = s
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

def gtrans_raw(text, tl):
    q = urllib.parse.quote(text)
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={urllib.parse.quote(tl)}&dt=t&q={q}"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=8) as resp:
                payload = json.loads(resp.read().decode("utf-8", errors="ignore"))
                if isinstance(payload, list) and payload and isinstance(payload[0], list):
                    txt = "".join(
                        item[0] for item in payload[0]
                        if isinstance(item, list) and item and isinstance(item[0], str)
                    )
                    if txt.strip():
                        return txt
            return text
        except Exception:
            if attempt < 2:
                time.sleep(0.35 * (attempt + 1))
    return text

def tr_single(text, tl):
    s = str(text or "").strip()
    if not s:
        return ""
    ck = f"{tl}:{s}"
    with cache_lock:
        if ck in cache:
            return cache[ck]
    res = " ".join(gtrans_raw(ch, tl).strip() for ch in split_text(s, 1200)).strip()
    with cache_lock:
        cache[ck] = res
    return res

def tr_batch_strings(strings, tl):
    results = {}
    todo = []
    for s in strings:
        clean = re.sub(r"\s+", " ", str(s or "")).strip()
        if not clean:
            results[s] = ""
            continue
        ck = f"{tl}:{clean}"
        with cache_lock:
            hit = cache.get(ck)
        if hit is not None:
            results[s] = hit
        else:
            todo.append((s, clean))

    batches = []
    cur = []
    cur_len = 0
    for orig, clean in todo:
        if len(clean) > 1200:
            if cur:
                batches.append(cur)
                cur, cur_len = [], 0
            batches.append([(orig, clean)])
            continue
        if cur and (cur_len + len(clean) + 1) > 1400:
            batches.append(cur)
            cur, cur_len = [], 0
        cur.append((orig, clean))
        cur_len += len(clean) + 1
    if cur:
        batches.append(cur)

    for b in batches:
        if len(b) == 1:
            orig, clean = b[0]
            results[orig] = tr_single(clean, tl)
        else:
            joined = "\n".join(clean for _, clean in b)
            raw_out = gtrans_raw(joined, tl)
            lines = [ln.strip() for ln in raw_out.splitlines() if ln.strip()]
            if len(lines) == len(b):
                for (orig, clean), tr_ln in zip(b, lines):
                    with cache_lock:
                        cache[f"{tl}:{clean}"] = tr_ln
                    results[orig] = tr_ln
            else:
                for orig, clean in b:
                    results[orig] = tr_single(clean, tl)
    return results

def collect_strings(val, out_list):
    if isinstance(val, str):
        if val.strip():
            out_list.append(val)
    elif isinstance(val, list):
        for x in val:
            collect_strings(x, out_list)
    elif isinstance(val, dict):
        for k, v in val.items():
            if k not in skip_keys:
                collect_strings(v, out_list)

def apply_strings(val, mapping):
    if isinstance(val, str):
        return mapping.get(val, val)
    if isinstance(val, list):
        return [apply_strings(x, mapping) for x in val]
    if isinstance(val, dict):
        return {k: (v if k in skip_keys else apply_strings(v, mapping)) for k, v in val.items()}
    return val

def translate_note(en_obj, tl):
    strs = []
    collect_strings(en_obj, strs)
    mapping = tr_batch_strings(list(dict.fromkeys(strs)), tl)
    return {k: (v if k == "visuals" else apply_strings(v, mapping)) for k, v in en_obj.items()}

def save_atomic():
    tmp_file = db_file.with_suffix(".json.tmp")
    tmp_file.write_text(json.dumps(db, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    json.loads(tmp_file.read_text(encoding="utf-8"))
    tmp_file.replace(db_file)
    try:
        with cache_lock:
            ckpt_file.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass

def process_one(item):
    tid, need_te, need_hi = item
    en = notes[tid]["en"]
    return (
        tid,
        translate_note(en, "te") if need_te else None,
        translate_note(en, "hi") if need_hi else None,
    )

done = 0
with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
    futs = {ex.submit(process_one, w): w[0] for w in work}
    for fut in concurrent.futures.as_completed(futs):
        tid = futs[fut]
        try:
            tid, te_res, hi_res = fut.result()
            if te_res is not None:
                notes[tid]["te"] = te_res
            if hi_res is not None:
                notes[tid]["hi"] = hi_res
            done += 1
            print(f"  [AUTO-TR {done}/{len(work)}] {tid}", flush=True)
            if done % 25 == 0:
                save_atomic()
        except Exception as exc:
            print(f"  [WARN] Skipped {tid}: {exc}", flush=True)

save_atomic()
te_final = sum(1 for r in notes.values() if isinstance(r, dict) and has_content(r.get("te")))
hi_final = sum(1 for r in notes.values() if isinstance(r, dict) and has_content(r.get("hi")))
print(f"[PASS] Auto-translation complete: TE={te_final}/{total} | HI={hi_final}/{total}", flush=True)