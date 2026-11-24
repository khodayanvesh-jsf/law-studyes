#!/usr/bin/env python3
"""
Law Studyes Fast Parallel Scraper v2.6.1
Preserves ALL verbatim Mermaid flowcharts (flowchart TD/LR), SVG diagrams, HTML box diagrams,
comparison tables, and inline images (offline base64) from https://nyayasaral.com/
alongside clean structured EN & TE sections - zero legal text altered.
"""
import base64
import html
import json
import re
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
HEADERS = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) LawStudyesFastSync/2.6.1"}
SESSION = requests.Session()
SESSION.headers.update(HEADERS)
ADAPTER = requests.adapters.HTTPAdapter(pool_connections=16, pool_maxsize=16, max_retries=2)
SESSION.mount("https://", ADAPTER)
SESSION.mount("http://", ADAPTER)

MERMAID_RE = re.compile(
    r"^\s*(?:flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|erDiagram|gantt|pie|timeline|mindmap|gitGraph)\b",
    re.I,
)


def fetch_soup(url: str):
    try:
        r = SESSION.get(url, timeout=20)
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
        r = SESSION.get(full, timeout=15)
        if r.status_code == 200 and len(r.content) < 550_000:
            ctype = r.headers.get("Content-Type", "image/png").split(";")[0]
            if not ctype.startswith("image/"):
                ctype = "image/png"
            b64 = base64.b64encode(r.content).decode("ascii")
            return f"data:{ctype};base64,{b64}"
    except Exception:
        pass
    return full


def normalize_mermaid_nodes(container):
    """Ensure any Mermaid code block inside a captured visual has class='mermaid' and raw definition intact."""
    found_mermaid = False
    for el in list(container.find_all(["pre", "div", "code"])):
        cls_str = " ".join(el.get("class") or []).lower()
        raw_txt = el.get_text("\n", strip=False).strip()
        is_m = ("mermaid" in cls_str) or bool(MERMAID_RE.match(raw_txt))
        if not is_m:
            continue
        # If this is a <code> inside a <pre>, promote to <div class="mermaid"> on the <pre>
        target = el.parent if (el.name == "code" and el.parent and el.parent.name == "pre") else el
        if target.name in ("pre", "code", "div"):
            target.name = "div"
            target["class"] = ["mermaid", "ls-mermaid-src"]
            target.clear()
            target.append(raw_txt)
            found_mermaid = True
    return found_mermaid


def extract_visuals(main, page_url: str) -> list:
    """Extract all verbatim Mermaid diagrams, SVG diagrams, HTML box diagrams, images, and tables in page order."""
    visuals = []
    seen_html = set()
    captured_nodes = set()

    def is_inside_captured(node):
        p = node.parent
        while p is not None:
            if id(p) in captured_nodes:
                return True
            p = p.parent
        return False

    # Walk all candidate visual elements in exact document order
    candidates = main.find_all(["figure", "pre", "div", "svg", "table", "img"])
    for el in candidates:
        if is_inside_captured(el):
            continue
        cls_str = " ".join(el.get("class") or []).lower()

        # 1. <figure> wrappers (often hold Mermaid diagrams, SVGs, HTML diagrams, captions & text descriptions)
        if el.name == "figure":
            has_m = normalize_mermaid_nodes(el)
            for img in el.find_all("img"):
                raw_src = img.get("src") or img.get("data-src") or img.get("data-lazy-src") or ""
                if raw_src:
                    img["src"] = inline_img_to_data_uri(raw_src, page_url)
                    for attr in ("srcset", "data-src", "data-lazy-src", "loading"):
                        if attr in img.attrs:
                            del img.attrs[attr]
            for a in el.find_all("a"):
                a.unwrap()
            raw_html = str(el)
            if raw_html not in seen_html and len(raw_html) > 60:
                seen_html.add(raw_html)
                captured_nodes.add(id(el))
                cap_el = el.find("figcaption") or el.find("caption")
                caption = clean_text(cap_el) if cap_el else ""
                vtype = "mermaid" if has_m else ("table" if el.find("table") else "diagram")
                visuals.append({"type": vtype, "caption": caption, "html": raw_html})
            continue

        # 2. Standalone Mermaid blocks (<pre class="mermaid">, <div class="mermaid">, or raw flowchart TD/LR)
        if el.name in ("pre", "div"):
            # Skip large layout wrappers that contain headings (h1/h2)
            if el.name == "div" and el.find(["h1", "h2"]):
                continue
            raw_txt = el.get_text("\n", strip=False).strip()
            is_mermaid = ("mermaid" in cls_str) or (
                el.name == "pre" and bool(MERMAID_RE.match(raw_txt))
            ) or (
                el.name == "div" and not el.find("div") and bool(MERMAID_RE.match(raw_txt))
            )
            if is_mermaid and len(raw_txt) > 20:
                safe_code = html.escape(raw_txt)
                raw_html = f'<figure class="ls-mermaid-fig"><div class="mermaid ls-mermaid-src">{safe_code}</div></figure>'
                if raw_html not in seen_html:
                    seen_html.add(raw_html)
                    captured_nodes.add(id(el))
                    visuals.append({"type": "mermaid", "caption": "Flowchart Diagram", "html": raw_html})
                continue

            # HTML visual box/timeline/diagram blocks outside <figure>
            if el.name == "div" and any(k in cls_str for k in ("diagram", "flowchart", "timeline", "visual-box", "diagram-box", "comparison-grid")):
                has_m = normalize_mermaid_nodes(el)
                for img in el.find_all("img"):
                    raw_src = img.get("src") or img.get("data-src") or img.get("data-lazy-src") or ""
                    if raw_src:
                        img["src"] = inline_img_to_data_uri(raw_src, page_url)
                for a in el.find_all("a"):
                    a.unwrap()
                raw_html = str(el)
                if raw_html not in seen_html and len(raw_html) > 80:
                    seen_html.add(raw_html)
                    captured_nodes.add(id(el))
                    cap_el = el.find(["figcaption", "h3", "h4", "strong"])
                    caption = clean_text(cap_el)[:120] if cap_el else "Visual Diagram"
                    visuals.append({"type": "mermaid" if has_m else "diagram", "caption": caption, "html": raw_html})
            continue

        # 3. Standalone inline <svg> diagrams (skip tiny UI icons)
        if el.name == "svg":
            w = str(el.get("width", "")).replace("px", "").strip()
            if w in ("12", "14", "16", "18", "20", "22", "24", "28") or "icon" in cls_str:
                continue
            raw_html = str(el)
            if len(raw_html) < 250:
                continue
            if raw_html not in seen_html:
                seen_html.add(raw_html)
                captured_nodes.add(id(el))
                t_el = el.find("title")
                caption = clean_text(t_el) if t_el else "SVG Diagram"
                visuals.append({"type": "svg", "caption": caption, "html": raw_html})
            continue

        # 4. Standalone comparison <table>
        if el.name == "table":
            for a in el.find_all("a"):
                a.unwrap()
            raw_html = str(el)
            if raw_html not in seen_html and len(raw_html) > 80:
                seen_html.add(raw_html)
                captured_nodes.add(id(el))
                cap_el = el.find("caption")
                caption = clean_text(cap_el) if cap_el else "Comparison Table"
                visuals.append({"type": "table", "caption": caption, "html": raw_html})
            continue

        # 5. Standalone content <img> (inlined offline as Base64)
        if el.name == "img":
            src = el.get("src") or el.get("data-src") or el.get("data-lazy-src") or ""
            if not src or "icon-512" in src or "logo" in src.lower() or "avatar" in src.lower():
                continue
            data_uri = inline_img_to_data_uri(src, page_url)
            alt = (el.get("alt") or "Study Diagram").replace('"', "&quot;")
            raw_html = f'<figure class="ls-img-fig"><img src="{data_uri}" alt="{alt}" /><figcaption>{alt}</figcaption></figure>'
            if raw_html not in seen_html:
                seen_html.add(raw_html)
                captured_nodes.add(id(el))
                visuals.append({"type": "image", "caption": alt, "html": raw_html})

    return visuals


def parse_note_page(soup: BeautifulSoup, page_url: str) -> dict:
    main = soup.find("article") or soup.find("main") or soup.body
    subtitle, read_time = "", ""
    h1 = main.find("h1")
    if h1:
        sib = h1.find_next_sibling()
        if sib and sib.name in ("p", "div"):
            subtitle = clean_text(sib)
    rt_match = re.search(r"\b(\d+\s*(?:min read|\u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c3e\u0c32 \u0c2a\u0c20\u0c28\u0c02))\b", main.get_text(" ", strip=True))
    if rt_match:
        read_time = rt_match.group(1)

    # Extract visuals BEFORE reading text chunks (use a clean copy so nothing is disturbed)
    visual_soup = BeautifulSoup(str(main), "html.parser")
    visuals = extract_visuals(visual_soup, page_url)

    sections_map = {}
    for h in main.find_all(["h2", "h3"]):
        htitle = clean_text(h).lower()
        chunks = []
        node = h.find_next_sibling()
        while node and node.name not in ("h2",):
            if node.name == "h3" and h.name == "h3":
                break
            # Skip raw mermaid source text in plain-text TTS paragraphs so TTS reads clean legal prose
            cls_n = " ".join(node.get("class") or []).lower()
            txt = clean_text(node)
            if txt and "mermaid" not in cls_n and not MERMAID_RE.match(txt):
                chunks.append(txt)
            node = node.find_next_sibling()
        if chunks:
            sections_map[htitle] = chunks

    def find_section(keywords):
        for k, v in sections_map.items():
            if any(kw in k for kw in keywords):
                return v
        return []

    in_one_min = " ".join(find_section(["in one minute", "\u0c12\u0c15\u0c4d\u0c15 \u0c28\u0c3f\u0c2e\u0c3f\u0c37\u0c02\u0c32\u0c4b"]))
    legal_prov = find_section(["legal provision", "\u0c1a\u0c1f\u0c4d\u0c1f\u0c2a\u0c30\u0c2e\u0c48\u0c28 \u0c28\u0c3f\u0c2c\u0c02\u0c27\u0c28"])
    meaning = "\n\n".join(find_section(["meaning and definition", "\u0c05\u0c30\u0c4d\u0c25\u0c02", "detailed explanation"]))
    key_points = find_section(["key points", "\u0c17\u0c41\u0c30\u0c4d\u0c24\u0c41\u0c02\u0c1a\u0c41\u0c15\u0c4b\u0c35\u0c32\u0c38\u0c3f\u0c28"])
    case_raw = find_section(["leading case", "\u0c2a\u0c4d\u0c30\u0c2e\u0c41\u0c16 \u0c15\u0c47\u0c38\u0c41\u0c32\u0c41"])
    qa_raw = find_section(["quick self-test", "\u0c38\u0c4d\u0c35\u0c40\u0c2f \u0c2a\u0c30\u0c40\u0c15\u0c4d\u0c37"])

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
                "whyItMatters": "",
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
    for sid, sem, ttl in [("law-of-contract-ii", "Semester II", "Law of Contracts - II")]:
        if sid not in discovered:
            discovered[sid] = {"id": sid, "semester": sem, "title": ttl, "url": f"{BASE_URL}/subjects/{sid}/"}
    for v in discovered.values():
        v["title"] = re.sub(r"\s*\d+\s*units\s*\u00b7?\s*$", "", v["title"], flags=re.I).strip()
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
    print(f"Discovered {len(subjects_meta)} live subjects from nyayasaral.com. Collecting topic index...")
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
            tt = re.sub(r"Unit\s*\d+.*$", "", row_text, flags=re.I).strip(" \u00b7-\u2013>") or full_url.rstrip("/").split("/")[-1].replace("-", " ").title()
            units_dict.setdefault(unit_no, []).append({"title": tt, "readTime": rt, "url": full_url})

        unit_titles = {}
        for el in soup.find_all(["button", "a", "li", "h2", "h3"]):
            m = re.match(r"Unit\s*(\d+)\s*[:\-\u2013]\s*(.+)", clean_text(el), re.I)
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
            all_subjects.append({
                "id": sm["id"],
                "semester": sm["semester"],
                "title": title,
                "totalPublished": sum(len(u["topics"]) for u in units_list),
                "url": sm["url"],
                "units": units_list,
            })

    print(f"Fetching {len(tasks)} topics (EN + TE + Verbatim Mermaid Flowcharts + SVGs + Images + Tables) with 12 workers...")
    all_notes = {}
    stats = {"en_total": 0, "te_total": 0, "mermaid": 0, "svg": 0, "table": 0, "image": 0, "diagram": 0}
    done = 0
    with ThreadPoolExecutor(max_workers=12) as ex:
        futs = [ex.submit(fetch_topic_pair, tid, url, rt) for tid, url, rt in tasks]
        for f in as_completed(futs):
            tid, entry = f.result()
            all_notes[tid] = entry
            for lang_key in ("en", "te"):
                vlist = (entry.get(lang_key) or {}).get("visuals", [])
                if lang_key == "en":
                    stats["en_total"] += len(vlist)
                else:
                    stats["te_total"] += len(vlist)
                for v in vlist:
                    vt = v.get("type", "diagram")
                    stats[vt] = stats.get(vt, 0) + 1
            done += 1
            if done % 50 == 0 or done == len(tasks):
                print(f"  Progress: {done}/{len(tasks)} topics synced (EN: {stats['en_total']} | TE: {stats['te_total']} | Mermaid: {stats['mermaid']} | Tables: {stats['table']} | Images: {stats['image']})")

    now_iso = datetime.now(timezone.utc).isoformat()
    db_ver = datetime.now(timezone.utc).strftime("%Y.%m.%d.%H%M")
    Path("www/nyayasaral_db.json").write_text(
        json.dumps({"appName": "Law Studyes", "syncedAt": now_iso, "subjects": all_subjects, "notes": all_notes}, ensure_ascii=False),
        encoding="utf-8",
    )
    Path("www/db-version.json").write_text(
        json.dumps({
            "dbVersion": db_ver,
            "totalSubjects": len(all_subjects),
            "totalNotes": len(all_notes),
            "totalVisuals": stats["en_total"],
            "totalVisualsTe": stats["te_total"],
            "mermaidDiagrams": stats["mermaid"],
            "tables": stats["table"],
            "images": stats["image"],
            "updatedAt": now_iso,
        }, indent=2),
        encoding="utf-8",
    )
    print(f"\nDONE! {len(all_subjects)} subjects, {len(all_notes)} notes, {stats['en_total']} EN + {stats['te_total']} TE verbatim visuals saved (Mermaid={stats['mermaid']}, Tables={stats['table']}, SVGs={stats['svg']}, Images={stats['image']})!")


if __name__ == "__main__":
    main()
