import hashlib, io, json, sys, time, urllib.request, zipfile

base = sys.argv[1].rstrip("/")
expected_ver = sys.argv[2]

def fetch(path):
    sep = "&" if "?" in path else "?"
    url = f"{base}/{path.lstrip('/')}{sep}t={int(time.time())}"
    req = urllib.request.Request(url, headers={"User-Agent": "LawStudyes-SmokeTest/3.2", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.status, r.read()

out = {"ok": True, "errors": [], "info": {}}
try:
    meta = {}
    for mf in ("ota-manifest.json", "ota-version.json"):
        try:
            _, raw = fetch(mf)
            parsed = json.loads(raw.decode("utf-8"))
            if isinstance(parsed, dict):
                for k, v in parsed.items():
                    if k not in meta or not meta[k]:
                        meta[k] = v
        except Exception:
            pass

    ver = str(meta.get("version", ""))
    exp_sha = str(meta.get("sha256") or meta.get("checksum") or "").lower().strip()
    zip_url = str(meta.get("url") or f"{base}/ota-bundle.zip")
    out["info"]["liveVersion"] = ver or "unknown"
    if not ver.startswith(expected_ver):
        out["ok"] = False
        out["errors"].append(f"Live version '{ver}' != '{expected_ver}'")

    sep = "&" if "?" in zip_url else "?"
    req_z = urllib.request.Request(f"{zip_url}{sep}t={int(time.time())}", headers={"User-Agent": "LawStudyes-SmokeTest/3.2"})
    with urllib.request.urlopen(req_z, timeout=45) as rz:
        zbytes = rz.read()

    actual_sha = hashlib.sha256(zbytes).hexdigest().lower()
    out["info"]["zipMB"] = round(len(zbytes) / 1048576, 2)
    out["info"]["actualSha"] = actual_sha[:16]
    out["info"]["shaMatch"] = (actual_sha == exp_sha) if exp_sha else True
    if exp_sha and actual_sha != exp_sha:
        out["ok"] = False
        out["errors"].append(f"SHA mismatch: manifest={exp_sha[:16]} vs zip={actual_sha[:16]}")

    with zipfile.ZipFile(io.BytesIO(zbytes), "r") as zf:
        names = zf.namelist()
        bad_slashes = sum(1 for n in names if "\\" in n)
        mp3_count = sum(1 for n in names if n.lower().endswith(".mp3"))
        has_idx = ("index.html" in names)
        has_bun = ("js/ls-app-bundle.js" in names)
        has_db = ("nyayasaral_db.json" in names)
        out["info"].update({
            "zipFiles": len(names), "badSlashes": bad_slashes, "mp3InZip": mp3_count,
            "hasIdx": has_idx, "hasBundle": has_bun, "hasDb": has_db
        })
        if bad_slashes > 0:
            out["ok"] = False
            out["errors"].append(f"{bad_slashes} backslash path(s) in live ZIP")
        if not has_idx or not has_bun or not has_db:
            out["ok"] = False
            out["errors"].append(f"Missing core file in ZIP (index={has_idx}, bundle={has_bun}, db={has_db})")
except Exception as e:
    out["ok"] = False
    out["errors"].append(f"OTA verify error: {e}")

try:
    _, raw_d = fetch("download.html")
    out["info"]["downloadHtmlVerMatch"] = (f"v{expected_ver}" in raw_d.decode("utf-8", errors="ignore"))
except Exception:
    out["info"]["downloadHtmlVerMatch"] = False

print(json.dumps(out))