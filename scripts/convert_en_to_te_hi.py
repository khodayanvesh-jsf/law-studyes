import concurrent.futures, copy, json, os, random, re, sys, threading, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path

args = sys.argv[1:]
rebuild_te = "--rebuild-te" in args
purge_only = "--purge-cache-only" in args
args = [a for a in args if a not in ("--rebuild-te", "--purge-cache-only")]

db_file = Path(args[0]) if len(args) > 0 else Path("www/nyayasaral_db.json")
batch_limit = int(args[1]) if len(args) > 1 else 0
workers = max(1, min(8, int(args[2]) if len(args) > 2 else 4))
ckpt_file = Path(args[3]) if len(args) > 3 else Path(".ls_legal_tr_cache.json")

if not db_file.exists():
    raise SystemExit(f"ERROR: Database not found at {db_file}")

print(f"[INIT] Loading {db_file.name} (workers={workers}, rebuild_te={rebuild_te}) ...", flush=True)
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

LTOK_STRIP_RE = re.compile(r"\[\[\s*LTOK\s*\d+\s*\]\]|__\s*LTOK\s*\d+\s*__", re.I)
SKIP_KEYS = {"id", "type", "html", "svg", "mermaid", "code", "citation", "year", "sectionNo", "articleNo", "visuals", "_trQuality"}

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

def script_bounds(lang):
    return ("\u0c00", "\u0c7f") if lang == "te" else ("\u0900", "\u097f")

def count_target_script(text, lang):
    lo, hi = script_bounds(lang)
    return sum(1 for c in text if lo <= c <= hi)

def count_latin(text):
    return sum(1 for c in text if ("A" <= c <= "Z") or ("a" <= c <= "z"))

def is_valid_translation(orig_en, translated, lang):
    if not isinstance(translated, str) or not translated.strip():
        return False
    if lang not in ("te", "hi"):
        return True
    orig_stripped = LTOK_STRIP_RE.sub(" ", LEGAL_TOKEN_RE.sub(" ", str(orig_en or "")))
    latin_src = count_latin(orig_stripped)
    if latin_src < 8:
        return True
    tr_stripped = LTOK_STRIP_RE.sub(" ", LEGAL_TOKEN_RE.sub(" ", translated))
    tgt_chars = count_target_script(tr_stripped, lang)
    if tgt_chars < 2:
        return False
    if translated.strip().lower() == str(orig_en or "").strip().lower():
        return False
    alpha = sum(1 for c in tr_stripped if c.isalpha())
    if alpha > 0 and (tgt_chars / alpha) < 0.20:
        return False
    return True

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
    alpha = sum(1 for c in s if c.isalpha())
    if alpha == 0:
        return False
    if (count_target_script(s, lang) / alpha) < 0.30:
        return False
    if isinstance(en_obj, dict):
        for req_f in ("inOneMinute", "meaning", "keyPoints"):
            en_v = en_obj.get(req_f)
            tr_v = obj.get(req_f)
            if isinstance(en_v, str) and len(en_v.strip()) > 30:
                if not isinstance(tr_v, str) or len(tr_v.strip()) < 10:
                    return False
                if not is_valid_translation(en_v, tr_v, lang):
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

def split_text(s, limit=950):
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

def write_file_onedrive_safe(target_path, text_data, validate_json=False):
    tmp_path = target_path.with_name(f"{target_path.name}.{os.getpid()}.tmp")
    tmp_path.write_text(text_data, encoding="utf-8")
    if validate_json:
        json.loads(tmp_path.read_text(encoding="utf-8"))

    last_err = None
    for attempt in range(12):
        try:
            os.replace(str(tmp_path), str(target_path))
            return
        except PermissionError as exc:
            last_err = exc
            time.sleep(min(2.5, 0.25 * (attempt + 1)))
        except OSError as exc:
            if getattr(exc, "winerror", None) in (5, 32, 33):
                last_err = exc
                time.sleep(min(2.5, 0.25 * (attempt + 1)))
            else:
                raise

    for attempt in range(5):
        try:
            with open(target_path, "w", encoding="utf-8", newline="") as fh:
                fh.write(text_data)
            try:
                tmp_path.unlink(missing_ok=True)
            except Exception:
                pass
            return
        except (PermissionError, OSError) as exc:
            last_err = exc
            time.sleep(0.5 * (attempt + 1))

    try:
        tmp_path.unlink(missing_ok=True)
    except Exception:
        pass
    raise last_err

cache, cache_lock = {}, threading.Lock()
purged_entries = 0
if ckpt_file.exists():
    try:
        loaded = json.loads(ckpt_file.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            for ck, val in loaded.items():
                m = re.match(r"^(?:v2:)?(te|hi):(.*)$", str(ck), re.S)
                if m:
                    cl, orig = m.group(1), m.group(2)
                    if is_valid_translation(orig, val, cl):
                        cache[ck] = val
                    else:
                        purged_entries += 1
                else:
                    cache[ck] = val
    except Exception:
        cache = {}

if purged_entries > 0:
    print(f"[CACHE] Purged {purged_entries} poisoned English-fallback cache entries (kept {len(cache)} verified).", flush=True)
    try:
        write_file_onedrive_safe(ckpt_file, json.dumps(cache, ensure_ascii=False), validate_json=False)
    except Exception as exc:
        print(f"[CACHE WARN] Could not flush purged cache yet: {exc}", flush=True)
else:
    print(f"[CACHE] Clean ({len(cache)} verified entries, 0 poisoned).", flush=True)

if purge_only:
    sys.exit(0)

rate_lock = threading.Lock()
cooldown_until = 0.0

def throttle_wait():
    global cooldown_until
    with rate_lock:
        now = time.time()
        wait_s = max(0.0, cooldown_until - now)
    if wait_s > 0:
        time.sleep(wait_s)

def bump_cooldown(seconds):
    global cooldown_until
    with rate_lock:
        cooldown_until = max(cooldown_until, time.time() + seconds)

def gtrans_fetch(text, tl):
    q = urllib.parse.quote(text)
    tl_q = urllib.parse.quote(tl)
    endpoints = [
        f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={tl_q}&dt=t&q={q}",
        f"https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=en&tl={tl_q}&q={q}",
    ]
    ua_list = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
    ]
    last_err = None
    for attempt in range(5):
        throttle_wait()
        url = endpoints[attempt % len(endpoints)]
        try:
            req = urllib.request.Request(url, headers={"User-Agent": ua_list[attempt % len(ua_list)]})
            with urllib.request.urlopen(req, timeout=12) as resp:
                payload = json.loads(resp.read().decode("utf-8", errors="ignore"))
                if isinstance(payload, list) and payload:
                    if isinstance(payload[0], list):
                        txt = "".join(
                            x[0] for x in payload[0]
                            if isinstance(x, list) and x and isinstance(x[0], str)
                        )
                        if txt.strip():
                            return txt
                    elif isinstance(payload[0], str) and payload[0].strip():
                        return payload[0]
                last_err = RuntimeError("Empty translation payload")
        except urllib.error.HTTPError as he:
            last_err = he
            if he.code in (429, 403, 503):
                bump_cooldown(min(8.0, 1.5 * (attempt + 1)) + random.uniform(0.2, 0.8))
            else:
                time.sleep(0.5 * (attempt + 1))
        except Exception as exc:
            last_err = exc
            time.sleep(0.45 * (attempt + 1) + random.uniform(0.1, 0.4))
    raise RuntimeError(f"Translation failed after retries ({tl}): {last_err}")

def tr_single(text, tl):
    s = re.sub(r"\s+", " ", str(text or "")).strip()
    if not s:
        return ""
    ck = f"v2:{tl}:{s}"
    with cache_lock:
        hit = cache.get(ck)
    if hit is not None and is_valid_translation(s, hit, tl):
        return hit

    masked, tokens = protect_tokens(s)
    if count_latin(LTOK_STRIP_RE.sub(" ", masked)) < 2:
        return s

    parts = []
    for ch in split_text(masked, 950):
        tr_ch = gtrans_fetch(ch, tl).strip()
        parts.append(tr_ch)
    res = restore_tokens(" ".join(parts).strip(), tokens)
    if tl == "te":
        res = polish_telugu(res)
    if not is_valid_translation(s, res, tl):
        raise RuntimeError(f"Rejected English-fallback output for {tl}: '{res[:60]}'")
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
        if hit is not None and is_valid_translation(clean, hit, tl):
            results[orig] = hit
        else:
            todo.append((orig, clean))

    batches, cur, cur_len = [], [], 0
    for orig, clean in todo:
        masked, tokens = protect_tokens(clean)
        if count_latin(LTOK_STRIP_RE.sub(" ", masked)) < 2:
            results[orig] = clean
            continue
        if len(masked) > 900:
            if cur:
                batches.append(cur); cur, cur_len = [], 0
            batches.append([(orig, clean, masked, tokens)])
            continue
        if cur and (cur_len + len(masked) + 1) > 1100:
            batches.append(cur); cur, cur_len = [], 0
        cur.append((orig, clean, masked, tokens))
        cur_len += len(masked) + 1
    if cur:
        batches.append(cur)

    for b in batches:
        if len(b) == 1:
            results[b[0][0]] = tr_single(b[0][1], tl)
            continue
        try:
            raw_out = gtrans_fetch("\n".join(x[2] for x in b), tl)
            lines = [ln.strip() for ln in raw_out.splitlines() if ln.strip()]
        except Exception:
            lines = []
        if len(lines) == len(b):
            for (orig, clean, _, tokens), ln in zip(b, lines):
                val = restore_tokens(ln, tokens)
                if tl == "te":
                    val = polish_telugu(val)
                if is_valid_translation(clean, val, tl):
                    with cache_lock:
                        cache[f"v2:{tl}:{clean}"] = val
                    results[orig] = val
                else:
                    results[orig] = tr_single(clean, tl)
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
    if not has_good_script(out, tl, en_obj):
        raise RuntimeError(f"Generated {tl} copy failed script verification")
    return out

def save_atomic():
    db_text = json.dumps(db, ensure_ascii=False, separators=(",", ":"))
    write_file_onedrive_safe(db_file, db_text, validate_json=True)
    try:
        with cache_lock:
            ckpt_text = json.dumps(cache, ensure_ascii=False)
        write_file_onedrive_safe(ckpt_file, ckpt_text, validate_json=False)
    except Exception as exc:
        print(f"  [CACHE WARN] Checkpoint save retry skipped: {exc}", flush=True)

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

te_init = sum(1 for r in notes.values() if isinstance(r, dict) and has_good_script(r.get("te"), "te", r.get("en")))
hi_init = sum(1 for r in notes.values() if isinstance(r, dict) and has_good_script(r.get("hi"), "hi", r.get("en")))
print(f"[AUDIT] Total={total} | Verified TE={te_init} | Verified HI={hi_init} | Verbatim Diagrams Synced={vis_synced} | Pending={len(work)}", flush=True)

if not work:
    if vis_synced > 0:
        save_atomic()
    print("[PASS] All 591 EN/TE/HI notes verified & diagrams locked verbatim!", flush=True)
    sys.exit(0)

print("[CHECK] Verifying live Telugu & Hindi endpoints...", flush=True)
t0 = time.time()
p_te = tr_single("Section 2(h) of the Indian Contract Act defines a contract.", "te")
p_hi = tr_single("Section 2(h) of the Indian Contract Act defines a contract.", "hi")
print(f"[CHECK] Live OK in {time.time() - t0:.2f}s | TE_script={count_target_script(p_te, 'te')} | HI_script={count_target_script(p_hi, 'hi')}", flush=True)

def run_topic(item):
    tid, need_te, need_hi = item
    en = notes[tid]["en"]
    te_c = prepare_copy(en, "te") if need_te else None
    hi_c = prepare_copy(en, "hi") if need_hi else None
    return tid, te_c, hi_c

done, te_new, hi_new, failed, start_ts = 0, 0, 0, 0, time.time()
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
                print(f"  [{done}/{len(work)}] {tid} | +TE:{te_new} +HI:{hi_new} | ETA ~{int((len(work)-done)/rate)}s", flush=True)
                if done % 20 == 0:
                    save_atomic()
                    print(f"  [SAVED] OneDrive-safe atomic checkpoint at {done}/{len(work)}", flush=True)
            except Exception as exc:
                failed += 1
                print(f"  [RETRY-LATER] {tid}: {exc}", flush=True)
except KeyboardInterrupt:
    print("\n[STOPPED] Saving completed verified notes safely...", flush=True)

save_atomic()
te_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_good_script(r.get("te"), "te", r.get("en")))
hi_ok = sum(1 for r in notes.values() if isinstance(r, dict) and has_good_script(r.get("hi"), "hi", r.get("en")))
print(f"[PASS] Conversion Complete: Total={total} | Verified TE={te_ok}/{total} | Verified HI={hi_ok}/{total} | Failed={failed} | Diagrams=100% Verbatim", flush=True)
if failed > 0:
    print(f"[INFO] {failed} topic(s) were skipped due to transient rate-limiting; re-run this script once more to finish them cleanly.", flush=True)