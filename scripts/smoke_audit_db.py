import json, sys
from pathlib import Path

p = Path(sys.argv[1])
data = json.loads(p.read_text(encoding="utf-8"))
notes = data.get("notes")
if not isinstance(notes, dict) or not notes:
    sys.exit("Invalid or empty notes object")

def ok(obj):
    if not isinstance(obj, dict) or not obj:
        return False
    for f in ("inOneMinute", "legalProvision", "meaning", "keyPoints", "caseLaws", "selfTest"):
        v = obj.get(f)
        if (isinstance(v, str) and v.strip()) or (isinstance(v, list) and len(v) > 0):
            return True
    return False

total = len(notes)
en = te = hi = vis = vis_mismatch = 0
for r in notes.values():
    if not isinstance(r, dict):
        continue
    en_o, te_o, hi_o = r.get("en"), r.get("te"), r.get("hi")
    if ok(en_o): en += 1
    if ok(te_o): te += 1
    if ok(hi_o): hi += 1
    if isinstance(en_o, dict) and isinstance(en_o.get("visuals"), list):
        ev = en_o["visuals"]
        vis += len(ev)
        if isinstance(te_o, dict) and te_o.get("visuals") != ev:
            vis_mismatch += 1
        if isinstance(hi_o, dict) and hi_o.get("visuals") != ev:
            vis_mismatch += 1

mb = p.stat().st_size / 1048576
print(json.dumps({
    "total": total, "en": en, "te": te, "hi": hi,
    "vis": vis, "visMismatch": vis_mismatch, "mb": round(mb, 2)
}))