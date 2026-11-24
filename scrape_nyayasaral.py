#!/usr/bin/env python3
"""
Law Studyes Fast Parallel Scraper v2.6
Preserves ALL verbatim SVG diagrams, comparison tables, and inline images (offline base64)
alongside clean structured sections for Professor Audio TTS — zero text altered.
"""
import base64
import json
import re
import sqlite3
from concurrent.futures import ThreadPoolExecutor, as_completed
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
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) LawStudyesFastSync/2.6"}


def fetch_soup(url: str):
    try:
        r = requests.get(url, headers=HEADERS, timeout=20)
        if r.status_code != 200:
            return None
        r.encoding = "utf-8"
        return BeautifulSoup(r.text, "html.parser")
    except Exception:
        return None


def clean_text(el) -> str:
    return re.sub(r"\s+", " ", el.get_text(" ", strip=True)).strip()


def inline_img_to_data_uri(img_src: str, page_url: str) -> str:
    if not img_src or img_src.startswith("data:"):
        return img_src
    full = urljoin(page_url, img_src)
    try:
        r = requests.get(full, headers=HEADERS, timeout=12)
        if r.status_code == 200 and len(r.content) < 350_000:
            ctype = r.headers.get("Content-Type", "image/png").split(";")[0]
            b64 = base64.b64encode(r.content).decode("ascii")
            return f"data:{ctype};base64,{b64}"
    except Exception:
        pass
    return full


def extract_visuals(main, page_url: str) -> list:
    """Extract all verbatim SVG diagrams, figures, images, and comparison tables."""
    visuals = []
    # 1. Inline SVG diagrams & figure wrappers
    seen_html = set()
    for fig in main.find_all(["figure", "svg", "table"]):
        # Skip nested svg/table if parent figure already captured
        if fig.name != "figure" and fig.find_parent("figure"):
            continue
        if fig.name == "svg":
            # Skip tiny UI icons (width/height <= 28px)
            w = str(fig.get("width", ""))
            cls = " ".join(fig.get("class", []))
            if w in ("14", "16", "18", "20", "24") or "icon" in cls.lower():
                continue
            if len(str(fig)) < 250:
                continue
        # Inline any <img> inside figure
        for img in fig.find_all("img"):
            if img.get("src"):
                img["src"] = inline_img_to_data_uri(img["src"], page_url)
        # Strip external links inside tables/figures so users never leave the app
        for a in fig.find_all("a"):
            a.unwrap()
        raw_html = str(fig)
        if raw_html not in seen_html and len(raw_html) > 80:
            seen_html.add(raw_html)
            caption = ""
            cap_el = fig.find("figcaption") or fig.find("caption")
            if cap_el:
                caption = clean_text(cap_el)
            vtype = "table" if fig.name == "table" else "diagram"
            visuals.append({"type": vtype, "caption": caption, "html": raw_html})
    # 2. Standalone content images outside figures
    for img in main.find_all("img"):
        if img.find_parent("figure"):
            continue
        src = img.get("src", "")
        if not src or "icon-512" in src or "logo" in src.lower():
            continue
        data_uri = inline_img_to_data_uri(src, page_url)
        alt = img.get("alt", "Study Diagram")
        html_str = f'<figure class="ls-img-fig"><img src="{data_uri}" alt="{alt}" /><figcaption>{alt}</figcaption></figure>'
        if html_str not in seen_html:
            seen_html.add(html_str)
            visuals.append({"type": "image", "caption": alt, "html": html_str})
    return visuals


def parse_note_page(soup: BeautifulSoup, page_url: str) -> dict:
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

    visuals = extract_visuals(main, page_url)

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
            case_laws.append({"name": parts[0][:100], "citation": "", "facts": parts[1].strip() if len(parts) > 1 else c, "principle": "", "whyItMatters": ""})

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
            "visuals": visuals,
        },
    }


def discover_all_subjects():
    discovered = {}
    for page_url in DISCOVERY_PAGES:
        soup = fetch_soup(page_url)
        if not soup:
            continue
        current_sem = "Semester I"
        for el in soup.find_all(["h2", "h3", "h4", "a"]):
            txt = clean_text(el)
            if el.name in ("h2", "h3", "h4"):
                m = re.search(r"(Semester\s+[IVX1-6]+)", txt, re.I)
                if m:
                    current_sem = m.group(1).title()
                continue
            full_url = urljoin(BASE_URL, el.get("href", "")).split("#")[0]
            m_subj = re.match(r"^https://nyayasaral\.com/subjects/([a-z0-9-]+)/?$", full_url)
            if m_subj and not m_subj.group(1).endswith("-te"):
                sid = m_subj.group(1)
                if sid not in discovered:
                    title = re.sub(r"\s*\d+\s*(notes|units).*$", "", txt, flags=re.I).strip() or sid.replace("-", " ").title()
                    discovered[sid] = {"id": sid, "semester": current_sem, "title": title, "url": f"{BASE_URL}/subjects/{sid}/"}
    for sid, sem, ttl in [("law-of-contract-ii", "Semester II", "Law of Contracts – II")]:
        if sid not in discovered:
            discovered[sid] = {"id": sid, "semester": sem, "title": ttl, "url": f"{BASE_URL}/subjects/{sid}/"}
    for v in discovered.values():
        v["title"] = re.sub(r"\s*\d+\s*units\s*·?\s*$", "", v["title"], flags=re.I).strip()
        v["semester"] = re.sub(r"Semester\s+1\b", "Semester I", v["semester"], flags=re.I)
        v["semester"] = re.sub(r"Semester\s+2\b", "Semester II", v["semester"], flags=re.I)
    return list(discovered.values())


def fetch_topic_pair(topic_id: str, url: str, read_time: str):
    en_soup = fetch_soup(url)
    en_p = parse_note_page(en_soup, url) if en_soup else None
    te_url = url.rstrip("/") + "-te/"
    te_soup = fetch_soup(te_url)
    te_p = parse_note_page(te_soup, te_url) if te_soup else None
    entry = {
        "id": topic_id,
        "subtitle": en_p["subtitle"] if en_p else "",
        "readTime": (en_p["readTime"] if en_p and en_p["readTime"] else read_time),
        "url": url,
    }
    if en_p:
        entry["en"] = en_p["langData"]
    if te_p:
        entry["te"] = te_p["langData"]
    return topic_id, entry


def main():
    subjects_meta = discover_all_subjects()
    print(f"Discovered {len(subjects_meta)} live subjects. Collecting topic index...")
    all_subjects = []
    tasks = []

    for sm in subjects_meta:
        soup = fetch_soup(sm["url"])
        if not soup:
            continue
        h1 = soup.find("h1")
        title = clean_text(h1) if h1 else sm["title"]
        prefix = f"/subjects/{sm['id']}/"
        units_dict, seen = {}, set()
        for a in soup.find_all("a", href=True):
            full_url = urljoin(BASE_URL, a["href"]).split("#")[0]
            if prefix not in full_url or full_url.rstrip("/") == sm["url"].rstrip("/") or full_url.rstrip("/").endswith("-te") or full_url in seen:
                continue
            seen.add(full_url)
            row_text = clean_text(a)
            um = re.search(r"Unit\s*(\d+)", row_text, re.I)
            unit_no = int(um.group(1)) if um else 1
            rm = re.search(r"(\d+\s*min read)", row_text, re.I)
            rt = rm.group(1) if rm else "8 min read"
            tt = re.sub(r"Unit\s*\d+.*$", "", row_text, flags=re.I).strip(" ·-–>") or full_url.rstrip("/").split("/")[-1].replace("-", " ").title()
            units_dict.setdefault(unit_no, []).append({"title": tt, "readTime": rt, "url": full_url})

        unit_titles = {}
        for el in soup.find_all(["button", "a", "li", "h2", "h3"]):
            m = re.match(r"Unit\s*(\d+)\s*[:\-–]\s*(.+)", clean_text(el), re.I)
            if m:
                unit_titles[int(m.group(1))] = m.group(2).strip()

        units_list = []
        for uno in sorted(units_dict.keys()):
            tlist = []
            for idx, t in enumerate(units_dict[uno], start=1):
                tid = f"{sm['id']}-u{uno}-t{idx}"
                tlist.append({"id": tid, "topicNo": idx, "title": t["title"], "readTime": t["readTime"], "url": t["url"]})
                tasks.append((tid, t["url"], t["readTime"]))
            units_list.append({"unitNo": uno, "title": unit_titles.get(uno, f"Unit {uno}"), "topics": tlist})
        if units_list:
            all_subjects.append({"id": sm["id"], "semester": sm["semester"], "title": title, "totalPublished": sum(len(u["topics"]) for u in units_list), "url": sm["url"], "units": units_list})

    print(f"Fetching {len(tasks)} topics (EN + TE + SVG Diagrams + Tables) with 8 parallel workers...")
    all_notes = {}
    visual_count = 0
    done = 0
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = [ex.submit(fetch_topic_pair, tid, url, rt) for tid, url, rt in tasks]
        for f in as_completed(futs):
            tid, entry = f.result()
            all_notes[tid] = entry
            visual_count += len((entry.get("en") or {}).get("visuals", []))
            done += 1
            if done % 50 == 0 or done == len(tasks):
                print(f"  Progress: {done}/{len(tasks)} topics synced ({visual_count} diagrams/tables preserved)")

    now_iso = datetime.now(timezone.utc).isoformat()
    db_ver = datetime.now(timezone.utc).strftime("%Y.%m.%d.%H%M")
    Path("www/nyayasaral_db.json").write_text(json.dumps({"appName": "Law Studyes", "syncedAt": now_iso, "subjects": all_subjects, "notes": all_notes}, ensure_ascii=False), encoding="utf-8")
    Path("www/db-version.json").write_text(json.dumps({"dbVersion": db_ver, "totalSubjects": len(all_subjects), "totalNotes": len(all_notes), "totalVisuals": visual_count, "updatedAt": now_iso}, indent=2), encoding="utf-8")
    print(f"\nDONE! {len(all_subjects)} subjects, {len(all_notes)} notes, {visual_count} verbatim SVG diagrams & tables saved!")


if __name__ == "__main__":
    main()