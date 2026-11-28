import json, os, sys, time
from pathlib import Path

db_path = Path(sys.argv[1])
pack_path = Path(sys.argv[2])

db = json.loads(db_path.read_text(encoding="utf-8"))
pack = json.loads(pack_path.read_text(encoding="utf-8"))

subjects = db.setdefault("subjects", [])
notes = db.setdefault("notes", {})
subj_by_id = {s["id"]: s for s in subjects if isinstance(s, dict) and "id" in s}

added_subjs, added_topics = 0, 0
for s in pack.get("subjects", []):
    if s["id"] not in subj_by_id:
        subjects.append(s)
        subj_by_id[s["id"]] = s
        added_subjs += 1
    else:
        ex_s = subj_by_id[s["id"]]
        ex_tids = {t["id"] for u in ex_s.get("units", []) for t in u.get("topics", [])}
        for u in s.get("units", []):
            new_ts = [t for t in u.get("topics", []) if t["id"] not in ex_tids]
            if new_ts:
                ex_s.setdefault("units", []).append({
                    "unitNo": len(ex_s["units"]) + 1,
                    "title": u["title"],
                    "topics": new_ts
                })

for tid, rec in pack.get("notes", {}).items():
    if tid not in notes:
        notes[tid] = rec
        added_topics += 1

out = json.dumps(db, ensure_ascii=False, separators=(",", ":"))
tmp = db_path.with_name(f"{db_path.name}.{os.getpid()}.tmp")
tmp.write_text(out, encoding="utf-8")
json.loads(tmp.read_text(encoding="utf-8"))
for i in range(12):
    try:
        os.replace(str(tmp), str(db_path))
        break
    except (PermissionError, OSError):
        time.sleep(0.3 * (i + 1))

print(f"[PASS] Merged {pack_path.name}: +{added_subjs} subjects, +{added_topics} English topics (Total topics: {len(notes)})")