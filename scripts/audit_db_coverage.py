import json, re, sys
from collections import defaultdict
from pathlib import Path

db_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("www/nyayasaral_db.json")
db = json.loads(db_path.read_text(encoding="utf-8"))

subjects = db.get("subjects", [])
notes = db.get("notes", {})
REQUIRED_KEYS = {"inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest", "visuals"}
TE_RE = re.compile(r"[\u0c00-\u0c7f]")
HI_RE = re.compile(r"[\u0900-\u097f]")

linked_ids = set()
sem_groups = defaultdict(list)
issues = []
total_diagrams = 0
diagram_mismatches = 0

def sem_order(label):
    m = re.search(r"(\d+)", str(label or ""))
    return int(m.group(1)) if m else 99

for s in subjects:
    sem = s.get("semester") or "Unassigned"
    units = s.get("units", [])
    t_count = ok_tri = s_diags = s_bad = 0
    for u in units:
        for t in u.get("topics", []):
            tid = t.get("id")
            linked_ids.add(tid)
            t_count += 1
            rec = notes.get(tid)
            if not isinstance(rec, dict):
                issues.append(f"MISSING NOTE: {tid}")
                s_bad += 1
                continue
            en, te, hi = rec.get("en"), rec.get("te"), rec.get("hi")
            v_en = isinstance(en, dict) and REQUIRED_KEYS.issubset(en.keys()) and bool(str(en.get("inOneMinute", "")).strip())
            v_te = isinstance(te, dict) and REQUIRED_KEYS.issubset(te.keys()) and bool(TE_RE.search(str(te.get("inOneMinute", ""))))
            v_hi = isinstance(hi, dict) and REQUIRED_KEYS.issubset(hi.keys()) and bool(HI_RE.search(str(hi.get("inOneMinute", ""))))
            if v_en and v_te and v_hi:
                ok_tri += 1
            else:
                s_bad += 1
                issues.append(f"INCOMPLETE ({tid}): EN={v_en} TE={v_te} HI={v_hi}")
            if isinstance(en, dict):
                ev = en.get("visuals") or []
                tv = (te or {}).get("visuals") or []
                hv = (hi or {}).get("visuals") or []
                s_diags += len(ev)
                total_diagrams += len(ev)
                if ev != tv or ev != hv:
                    diagram_mismatches += 1
                    issues.append(f"DIAGRAM MISMATCH: {tid}")
    sem_groups[sem].append((s.get("title", s.get("id", "")), len(units), t_count, ok_tri, s_diags, s_bad))

orphans = set(notes.keys()) - linked_ids

print(f"\n{'SEM':<12} | {'SUBJECT':<44} | {'UNITS':>5} | {'TOPICS':>6} | {'TRI-OK':>6} | {'DIAGS':>5} | {'STATUS'}")
print("-" * 102)
for sem in sorted(sem_groups.keys(), key=sem_order):
    for title, u_cnt, t_cnt, ok_cnt, d_cnt, bad_cnt in sem_groups[sem]:
        flag = "OK" if bad_cnt == 0 and u_cnt >= 5 else (f"WARN ({u_cnt}u)" if bad_cnt == 0 else f"ERR ({bad_cnt})")
        print(f"{sem:<12} | {title[:44]:<44} | {u_cnt:>5} | {t_cnt:>6} | {ok_cnt:>6} | {d_cnt:>5} | {flag}")

print("-" * 102)
print(f"TOTALS: Subjects={len(subjects)} | Linked Topics={len(linked_ids)} | Notes Dict={len(notes)} | Orphans={len(orphans)}")
print(f"VERBATIM DIAGRAMS: Total={total_diagrams} | Mismatches={diagram_mismatches} | Schema/Lang Issues={len(issues)}")
if orphans:
    print("ORPHAN NOTE IDS (first 10):", sorted(orphans)[:10])
if issues:
    print("ISSUES (first 15):")
    for x in issues[:15]:
        print("  -", x)