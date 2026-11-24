#!/usr/bin/env python3
"""
Law Studyes — Dynamic All-Years & All-Semesters Auto-Sync Scraper
Automatically discovers EVERY published subject across Years 1-3 (Semesters I-VI)
from https://nyayasaral.com/3-year-llb/ and https://nyayasaral.com/syllabus/,
fetches all live English & Telugu notes, and updates:
  1. www/nyayasaral_db.json   (Web App & Android APK auto-sync feed)
  2. nyayasaral_notes.sqlite  (local SQLite database)
  3. notes_markdown/          (organized Semester -> Subject -> Unit -> Topic .md files)
"""
import json
import re
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

BASE_URL = "https://nyayasaral.com"
DISCOVERY_PAGES = [
    "https://nyayasaral.com/3-year-llb/",
    "https://nyayasaral.com/syllabus/",
]
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) LawStudyesAutoSync/2.0"
}


def fetch_soup(session: requests.Session, url: str):
    try:
        r = session.get(url, headers=HEADERS, timeout=25)
        if r.status_code != 200:
            return None
        r.encoding = "utf-8"
        return BeautifulSoup(r.text, "html.parser")
    except Exception as exc:
        print(f"  [WARN] Failed to fetch {url}: {exc}")
        return None


def clean_text(el) -> str:
    return re.sub(r"\s+", " ", el.get_text(" ", strip=True)).strip()


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:60] or "topic"


def discover_all_subjects(session: requests.Session):
    """Dynamically discover all live subject pages across all Years & Semesters."""
    discovered = {}
    for page_url in DISCOVERY_PAGES:
        soup = fetch_soup(session, page_url)
        if not soup:
            continue
        current_sem = "3-Year LL.B."
        for el in soup.find_all(["h2", "h3", "h4", "a"]):
            txt = clean_text(el)
            if el.name in ("h2", "h3", "h4"):
                m = re.search(r"(Semester\s+[IVX1-6]+|Year\s+[1-3])", txt, re.I)
                if m:
                    current_sem = m.group(1).title()
                continue
            href = el.get("href", "")
            full_url = urljoin(BASE_URL, href).split("#")[0]
            m_subj = re.match(r"^https://nyayasaral\.com/subjects/([a-z0-9-]+)/?$", full_url)
            if m_subj:
                subj_id = m_subj.group(1)
                if subj_id.endswith("-te"):
                    continue
                canonical = f"{BASE_URL}/subjects/{subj_id}/"
                title = txt or subj_id.replace("-", " ").title()
                title = re.sub(r"\s*\d+\s*notes.*$", "", title, flags=re.I).strip()
                if subj_id not in discovered:
                    discovered[subj_id] = {
                        "id": subj_id,
                        "semester": current_sem,
                        "title": title,
                        "url": canonical,
                    }
    # Always include known live Semester II+ subjects even if not yet linked on /3-year-llb/
    for sid, sem, ttl in [
        ("law-of-contract-ii", "Semester II", "Law of Contracts – II"),
    ]:
        if sid not in discovered:
            discovered[sid] = {"id": sid, "semester": sem, "title": ttl, "url": f"{BASE_URL}/subjects/{sid}/"}
    for v in discovered.values():
        v["title"] = re.sub(r"\s*\d+\s*units\s*·?\s*$", "", v["title"], flags=re.I).strip()
        v["semester"] = re.sub(r"Semester\s+1\b", "Semester I", v["semester"], flags=re.I)
        v["semester"] = re.sub(r"Semester\s+2\b", "Semester II", v["semester"], flags=re.I)
    print(f"Discovered {len(discovered)} live subjects across all semesters.")
    return list(discovered.values())


def parse_note_page(soup: BeautifulSoup) -> dict:
    main = soup.find("article") or soup.find("main") or soup.body
    subtitle, read_time = "", ""
    h1 = main.find("h1")
    if h1:
        sib = h1.find_next_sibling()
        if sib and sib.name in ("p", "div"):
            subtitle = clean_text(sib)
    rt_match = re.search(r"\b(\d+\s*(?:min read|నిమిషాల పఠనం))\b", main.get_text(" ", strip=True))
    if rt_match:
        read_time = rt_match.group(1)

    sections_map = {}
    for h in main.find_all(["h2", "h3"]):
        htitle = clean_text(h).lower()
        chunks = []
        node = h.find_next_sibling()
        while node and node.name not in ("h2",):
            if node.name == "h3" and h.name == "h3":
                break
            txt = clean_text(node)
            if txt:
                chunks.append(txt)
            node = node.find_next_sibling()
        if chunks:
            sections_map[htitle] = chunks

    def find_section(keywords):
        for k, v in sections_map.items():
            if any(kw in k for kw in keywords):
                return v
        return []

    in_one_min = " ".join(find_section(["in one minute", "ఒక్క నిమిషంలో"]))
    legal_prov = find_section(["legal provision", "చట్టపరమైన నిబంధన"])
    meaning = "\n\n".join(find_section(["meaning and definition", "అర్థం", "detailed explanation"]))
    key_points = find_section(["key points", "గుర్తుంచుకోవలసిన"])
    case_raw = find_section(["leading case", "ప్రముఖ కేసులు"])
    qa_raw = find_section(["quick self-test", "స్వీయ పరీక్ష"])

    if not in_one_min and not meaning:
        paras = [clean_text(p) for p in main.find_all("p") if len(clean_text(p)) > 30]
        in_one_min = paras[0] if paras else ""
        meaning = "\n\n".join(paras[1:8]) if len(paras) > 1 else ""

    case_laws = []
    for c in case_raw:
        if len(c) > 25:
            parts = c.split(".", 1)
            case_laws.append({
                "name": parts[0][:100],
                "citation": "",
                "facts": parts[1].strip() if len(parts) > 1 else c,
                "principle": "",
                "whyItMatters": ""
            })

    self_test = []
    for line in qa_raw:
        if "?" in line:
            q, _, a = line.partition("?")
            self_test.append({"q": q.strip() + "?", "a": a.strip() or "See note above."})

    return {
        "subtitle": subtitle,
        "readTime": read_time,
        "langData": {
            "inOneMinute": in_one_min,
            "legalProvision": legal_prov,
            "meaning": meaning,
            "keyPoints": key_points,
            "caseLaws": case_laws,
            "selfTest": self_test,
        },
    }


def parse_subject_page(session: requests.Session, subj_meta: dict, existing_notes: dict):
    subj_id = subj_meta["id"]
    url = subj_meta["url"]
    print(f"\n=== Syncing Subject: {subj_meta['title']} ({subj_meta['semester']}) ===")
    soup = fetch_soup(session, url)
    if not soup:
        return None, {}

    # Prefer H1 title from the subject page itself
    h1 = soup.find("h1")
    title = clean_text(h1) if h1 else subj_meta["title"]

    units_dict = {}
    notes_dict = {}
    prefix = f"/subjects/{subj_id}/"
    seen_urls = set()

    for a in soup.find_all("a", href=True):
        full_url = urljoin(BASE_URL, a["href"]).split("#")[0]
        if prefix not in full_url or full_url.rstrip("/") == url.rstrip("/"):
            continue
        if full_url.rstrip("/").endswith("-te") or full_url in seen_urls:
            continue
        seen_urls.add(full_url)

        row_text = clean_text(a)
        unit_match = re.search(r"Unit\s*(\d+)", row_text, re.I)
        unit_no = int(unit_match.group(1)) if unit_match else 1
        rt_match = re.search(r"(\d+\s*min read)", row_text, re.I)
        read_time = rt_match.group(1) if rt_match else "8 min read"
        topic_title = re.sub(r"Unit\s*\d+.*$", "", row_text, flags=re.I).strip(" ·-–>")
        if not topic_title:
            topic_title = full_url.rstrip("/").split("/")[-1].replace("-", " ").title()

        units_dict.setdefault(unit_no, []).append({
            "title": topic_title,
            "readTime": read_time,
            "url": full_url
        })

    unit_titles = {}
    for el in soup.find_all(["button", "a", "li", "h2", "h3"]):
        m = re.match(r"Unit\s*(\d+)\s*[:\-–]\s*(.+)", clean_text(el), re.I)
        if m:
            unit_titles[int(m.group(1))] = m.group(2).strip()

    units_list = []
    for unit_no in sorted(units_dict.keys()):
        topics_list = []
        for idx, t in enumerate(units_dict[unit_no], start=1):
            topic_id = f"{subj_id}-u{unit_no}-t{idx}"
            topics_list.append({
                "id": topic_id,
                "topicNo": idx,
                "title": t["title"],
                "readTime": t["readTime"],
                "url": t["url"]
            })

            # Reuse already-synced note if URL matches (fast incremental sync)
            if topic_id in existing_notes and existing_notes[topic_id].get("url") == t["url"]:
                notes_dict[topic_id] = existing_notes[topic_id]
                continue

            print(f"  [NEW U{unit_no} T{idx}] Fetching EN+TE: {t['title']}")
            en_soup = fetch_soup(session, t["url"])
            en_parsed = parse_note_page(en_soup) if en_soup else None
            te_soup = fetch_soup(session, t["url"].rstrip("/") + "-te/")
            te_parsed = parse_note_page(te_soup) if te_soup else None

            note_entry = {
                "id": topic_id,
                "subtitle": (en_parsed["subtitle"] if en_parsed else ""),
                "readTime": (en_parsed["readTime"] if en_parsed and en_parsed["readTime"] else t["readTime"]),
                "url": t["url"],
            }
            if en_parsed:
                note_entry["en"] = en_parsed["langData"]
            if te_parsed:
                note_entry["te"] = te_parsed["langData"]
            notes_dict[topic_id] = note_entry
            time.sleep(0.25)

        units_list.append({
            "unitNo": unit_no,
            "title": unit_titles.get(unit_no, f"Unit {unit_no}"),
            "topics": topics_list
        })

    if not units_list:
        return None, {}

    return {
        "id": subj_id,
        "semester": subj_meta["semester"],
        "title": title,
        "totalPublished": sum(len(u["topics"]) for u in units_list),
        "url": url,
        "units": units_list
    }, notes_dict


def write_sqlite(db_path: Path, subjects: list, notes: dict):
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.executescript("""
        CREATE TABLE subjects (id TEXT PRIMARY KEY, semester TEXT, title TEXT, total_published INTEGER, url TEXT);
        CREATE TABLE units (id TEXT PRIMARY KEY, subject_id TEXT, unit_no INTEGER, title TEXT);
        CREATE TABLE topics (id TEXT PRIMARY KEY, subject_id TEXT, unit_no INTEGER, topic_no INTEGER, title TEXT, read_time TEXT, url TEXT);
        CREATE TABLE notes (topic_id TEXT PRIMARY KEY, subtitle TEXT, read_time TEXT, url TEXT, en_json TEXT, te_json TEXT);
    """)
    for s in subjects:
        cur.execute("INSERT INTO subjects VALUES (?,?,?,?,?)", (s["id"], s["semester"], s["title"], s["totalPublished"], s["url"]))
        for u in s["units"]:
            cur.execute("INSERT INTO units VALUES (?,?,?,?)", (f"{s['id']}-u{u['unitNo']}", s["id"], u["unitNo"], u["title"]))
            for t in u["topics"]:
                cur.execute("INSERT INTO topics VALUES (?,?,?,?,?,?,?)", (t["id"], s["id"], u["unitNo"], t["topicNo"], t["title"], t["readTime"], t["url"]))
    for tid, n in notes.items():
        cur.execute("INSERT INTO notes VALUES (?,?,?,?,?,?)",
                    (tid, n.get("subtitle", ""), n.get("readTime", ""), n.get("url", ""),
                     json.dumps(n.get("en"), ensure_ascii=False), json.dumps(n.get("te"), ensure_ascii=False)))
    conn.commit()
    conn.close()


def write_markdown_tree(base_dir: Path, subjects: list, notes: dict):
    base_dir.mkdir(parents=True, exist_ok=True)
    for s in subjects:
        s_dir = base_dir / f"{slugify(s['semester'])}_{s['id']}"
        for u in s["units"]:
            u_dir = s_dir / f"Unit_{u['unitNo']:02d}_{slugify(u['title'])}"
            u_dir.mkdir(parents=True, exist_ok=True)
            for t in u["topics"]:
                n = notes.get(t["id"], {})
                en = n.get("en", {})
                md_lines = [f"# {t['title']}", f"**Subject:** {s['title']} ({s['semester']}) | **Unit {u['unitNo']}:** {u['title']}", f"**Source:** {t['url']}", ""]
                if en.get("inOneMinute"):
                    md_lines += ["## In One Minute", en["inOneMinute"], ""]
                if en.get("legalProvision"):
                    md_lines += ["## Legal Provision"] + [f"- {x}" for x in en["legalProvision"]] + [""]
                if en.get("meaning"):
                    md_lines += ["## Meaning and Definition", en["meaning"], ""]
                if en.get("keyPoints"):
                    md_lines += ["## Key Points to Remember"] + [f"- {x}" for x in en["keyPoints"]] + [""]
                (u_dir / f"{t['topicNo']:02d}_{slugify(t['title'])}.md").write_text("\n".join(md_lines), encoding="utf-8")


def main():
    out_json = Path("www/nyayasaral_db.json")
    existing_notes = {}
    if out_json.exists():
        try:
            existing_notes = json.loads(out_json.read_text(encoding="utf-8")).get("notes", {})
            print(f"Loaded {len(existing_notes)} existing synced notes for incremental update.")
        except Exception:
            pass

    session = requests.Session()
    subject_metas = discover_all_subjects(session)
    all_subjects, all_notes = [], {}

    for meta in subject_metas:
        subj_obj, notes_dict = parse_subject_page(session, meta, existing_notes)
        if subj_obj:
            all_subjects.append(subj_obj)
            all_notes.update(notes_dict)

    out_json.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "appName": "Law Studyes",
        "syncedAt": datetime.now(timezone.utc).isoformat(),
        "source": "https://nyayasaral.com/3-year-llb/",
        "subjects": all_subjects,
        "notes": all_notes,
    }
    out_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    Path("www/db-version.json").write_text(json.dumps({"dbVersion": datetime.now(timezone.utc).strftime("%Y.%m.%d.%H%M"), "totalSubjects": len(all_subjects), "totalNotes": len(all_notes)}, indent=2), encoding="utf-8")
    write_sqlite(Path("nyayasaral_notes.sqlite"), all_subjects, all_notes)
    write_markdown_tree(Path("notes_markdown"), all_subjects, all_notes)
    print(f"\nSYNC COMPLETE: {len(all_subjects)} subjects, {len(all_notes)} notes saved.")


if __name__ == "__main__":
    main()
