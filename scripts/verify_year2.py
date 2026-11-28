import json, sys

with open(r".\www\nyayasaral_db.json", "r", encoding="utf-8") as f:
    db = json.load(f)

expected = {
    "jurisprudence": 25,
    "law-of-property": 30,
    "administrative-law": 19,
    "company-law": 25,
    "labour-law-i": 20,
    "labour-law-ii": 19,
    "public-international-law": 20,
    "principles-of-taxation-law": 21,
    "land-laws": 20,
    "intellectual-property-law": 21,
}

subjects_by_id = {s["id"]: s for s in db.get("subjects", [])}
notes = db.get("notes", {})
errors = []
total_topics = 0

print(f"{'Subject ID':<28} {'Units':>5} {'Topics':>6} {'EN':>4} {'TE':>4} {'HI':>4}  Status")
print("-" * 68)

for sid, exp_count in expected.items():
    sub = subjects_by_id.get(sid)
    if not sub:
        errors.append(f"Missing subject: {sid}")
        continue
    units = sub.get("units", [])
    tids = [t["id"] for u in units for t in u.get("topics", [])]
    total_topics += len(tids)

    en_ok = te_ok = hi_ok = 0
    for tid in tids:
        rec = notes.get(tid)
        if not rec:
            errors.append(f"Missing note record: {tid}")
            continue
        for lang in ("en", "te", "hi"):
            block = rec.get(lang)
            has_content = isinstance(block, dict) and bool(block.get("inOneMinute")) and bool(block.get("keyPoints"))
            if lang == "en" and has_content: en_ok += 1
            if lang == "te" and has_content: te_ok += 1
            if lang == "hi" and has_content: hi_ok += 1
            if not has_content:
                errors.append(f"Incomplete [{lang}] note: {tid}")

    status = "OK" if (len(units) == 5 and len(tids) == exp_count and en_ok == te_ok == hi_ok == exp_count) else "CHECK"
    if len(tids) != exp_count:
        errors.append(f"{sid}: expected {exp_count} topics, found {len(tids)}")
    print(f"{sid:<28} {len(units):>5} {len(tids):>6} {en_ok:>4} {te_ok:>4} {hi_ok:>4}  {status}")

print("-" * 68)
print(f"Total Year 2 Topics: {total_topics}/220 | Errors: {len(errors)}")
if errors:
    print("\nFirst 15 issues:")
    for e in errors[:15]:
        print(" -", e)
    sys.exit(1)
print("YEAR 2 VERIFICATION PASSED 100% (EN + TE + HI)!")