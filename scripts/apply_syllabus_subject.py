import json, os, sys, time
from pathlib import Path

args = sys.argv[1:]
replace_subject = "--replace-subject" in args
clean_args = [a for a in args if not a.startswith("--")]
db_path = Path(clean_args[0])
pack_path = Path(clean_args[1])

db = json.loads(db_path.read_text(encoding="utf-8"))
pack = json.loads(pack_path.read_text(encoding="utf-8"))

subjects = db.setdefault("subjects", [])
notes = db.setdefault("notes", {})
subj_by_id = {s["id"]: s for s in subjects if isinstance(s, dict) and "id" in s}

removed_old = added_topics = updated_topics = 0

for s in pack.get("subjects", []):
    sid = s["id"]
    if sid not in subj_by_id:
        subjects.append(s)
        subj_by_id[sid] = s
    else:
        ex = subj_by_id[sid]
        for k in ("title", "year", "paper", "semester"):
            if s.get(k):
                ex[k] = s[k]
        if replace_subject:
            old_tids = [t["id"] for u in ex.get("units", []) for t in u.get("topics", [])]
            protected = [tid for tid in old_tids if (notes.get(tid, {}).get("en", {}).get("visuals") or [])]
            if protected:
                raise RuntimeError(f"Refusing to replace {sid}: {len(protected)} topics have verbatim diagrams!")
            for tid in old_tids:
                if tid in notes:
                    del notes[tid]
                    removed_old += 1
            ex["units"] = s.get("units", [])
        else:
            unit_by_no = {u["unitNo"]: u for u in ex.get("units", [])}
            for u in s.get("units", []):
                uno = u["unitNo"]
                if uno not in unit_by_no:
                    ex.setdefault("units", []).append(u)
                    unit_by_no[uno] = u
                else:
                    ex_u = unit_by_no[uno]
                    ex_u["title"] = u.get("title", ex_u.get("title", ""))
                    ex_tids = {t["id"] for t in ex_u.get("topics", [])}
                    for t in u.get("topics", []):
                        if t["id"] not in ex_tids:
                            ex_u.setdefault("topics", []).append(t)
                            ex_tids.add(t["id"])
            ex["units"].sort(key=lambda x: x.get("unitNo", 99))

for tid, rec in pack.get("notes", {}).items():
    if tid in notes:
        notes[tid] = rec
        updated_topics += 1
    else:
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

print(f"[PASS] Applied {pack_path.name}: replaced_old={removed_old}, added={added_topics}, updated={updated_topics} | Total DB topics={len(notes)}")