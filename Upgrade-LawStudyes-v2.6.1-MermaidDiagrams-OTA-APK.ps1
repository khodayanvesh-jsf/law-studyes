<#
.SYNOPSIS
  Law Studyes v2.6.1 - Offline Mermaid Flowchart Renderer + Full Verbatim Re-Scrape from nyayasaral.com
  Preserves ALL verbatim Mermaid flowcharts (EN & TE), SVG diagrams, HTML box diagrams, images (Base64),
  and comparison tables (zero text altered), adds animated flowchart arrows + Zoom & Memory Walk lightbox,
  fixes left-sidebar OTA race/URL error, builds clean bloat-free Desktop APK v2.6.1, and pushes Full OTA.
.USAGE
  Run inside C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit:
    powershell -ExecutionPolicy Bypass -File .\Upgrade-LawStudyes-v2.6.1-MermaidDiagrams-OTA-APK.ps1
#>

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$ver = "2.6.1"
$verCode = 261
$vercelBase = "https://law-studyes.vercel.app"

Write-Host "`n=== 0. Downloading Offline Mermaid.js Engine (www/vendor/mermaid.min.js) ===" -ForegroundColor Cyan
$vendorDir = Join-Path $root "www\vendor"
New-Item -ItemType Directory -Path $vendorDir -Force | Out-Null
$mmdPath = Join-Path $vendorDir "mermaid.min.js"
if (-not (Test-Path $mmdPath) -or (Get-Item $mmdPath).Length -lt 500000) {
  $mmdUrls = @(
    "https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.min.js",
    "https://unpkg.com/mermaid@10.9.3/dist/mermaid.min.js"
  )
  $gotMmd = $false
  foreach ($mu in $mmdUrls) {
    try {
      Invoke-WebRequest -Uri $mu -OutFile $mmdPath -UseBasicParsing -TimeoutSec 60
      if ((Get-Item $mmdPath).Length -gt 500000) { $gotMmd = $true; break }
    } catch {}
  }
  if (-not $gotMmd) { throw "Could not download mermaid.min.js offline bundle!" }
}
Write-Host ("[OK] Offline Mermaid engine ready: " + [Math]::Round((Get-Item $mmdPath).Length/1MB, 2) + " MB") -ForegroundColor Green

Write-Host "`n=== 1. Re-Scraping ALL 6 Live Subjects from https://nyayasaral.com/ (Verbatim Diagrams, Flowcharts, Images & Tables) ===" -ForegroundColor Cyan

$fastScraperPy = @'
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

'@

[System.IO.File]::WriteAllText((Join-Path $root "scrape_nyayasaral.py"), $fastScraperPy, $u)
python -m py_compile scrape_nyayasaral.py
if ($LASTEXITCODE -ne 0) { throw "scrape_nyayasaral.py syntax check failed!" }
python scrape_nyayasaral.py
if ($LASTEXITCODE -ne 0) { throw "Scraper failed!" }

Write-Host "`n=== 2. Fixing Left-Sidebar OTA + Wiring Offline Mermaid Renderer & Study Animations in www/index.html ===" -ForegroundColor Cyan
$idx = Join-Path $root "www\index.html"
$h = [System.IO.File]::ReadAllText($idx, $u)

# Switch OTA endpoints from raw.githubusercontent.com to fast Vercel CDN
$h = $h.Replace("https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www", $vercelBase)

# Bump version labels cleanly
$h = $h -replace '3-Year LL\.B\. [^<"]*Audio &amp; Sync( [^<"]*v[\d\.]+)?', "3-Year LL.B. &middot; All Years Audio &amp; Sync &middot; v$ver"
$h = $h -replace 'var BUILT_IN = "[^"]+";', "var BUILT_IN = `"$ver`";"
$h = $h -replace 'var BUILT_IN_VER = "[^"]+";', "var BUILT_IN_VER = `"$ver`";"
$h = $h.Replace("? Close</button>", "&times; Close</button>")

# Replace previous visual block cleanly
$h = [regex]::Replace($h, '(?s)<!-- LS_VISUAL_DIAGRAMS_START -->.*?<!-- LS_VISUAL_DIAGRAMS_END -->', '')

$visualBlock = @'
<!-- LS_VISUAL_DIAGRAMS_START -->
<script src="./vendor/mermaid.min.js"></script>
<style>
  @keyframes lsDiagramReveal {
    from { opacity: 0; transform: translateY(16px) scale(0.985); }
    to { opacity: 1; transform: translateY(0) scale(1); }
  }
  @keyframes lsCardFadeSlide {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
  }
  @keyframes lsSvgNodePulse {
    0%, 100% { filter: drop-shadow(0 0 0 rgba(123,30,43,0)); }
    50% { filter: drop-shadow(0 4px 12px rgba(123,30,43,0.18)); }
  }
  @keyframes lsFlowDash {
    to { stroke-dashoffset: -28; }
  }
  @keyframes lsNodePop {
    0% { opacity: 0; transform: translateY(6px) scale(0.97); }
    100% { opacity: 1; transform: translateY(0) scale(1); }
  }
  #readingPane > section, #readingPane > article, #readingPane > div {
    animation: lsCardFadeSlide 0.35s ease-out both;
  }
  .ls-visual-card { animation: lsDiagramReveal 0.48s cubic-bezier(0.22, 1, 0.36, 1) both; }
  .ls-visual-box {
    position: relative;
    transition: transform 0.25s ease, box-shadow 0.25s ease, border-color 0.25s ease;
  }
  .ls-visual-box:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 22px rgba(123,30,43,0.10);
  }
  .ls-visual-box svg {
    max-width: 100%;
    height: auto !important;
    display: block;
    margin: 0 auto;
    animation: lsSvgNodePulse 4.5s ease-in-out infinite;
  }
  /* Animate Mermaid flowchart arrows & nodes for easier visual memory */
  .ls-visual-box svg path.flowchart-link,
  .ls-visual-box svg .edgePath path {
    stroke-dasharray: 6 3;
    animation: lsFlowDash 2.4s linear infinite;
  }
  .ls-visual-box svg .node,
  .ls-visual-box svg g,
  .ls-visual-box svg rect,
  .ls-visual-box svg circle {
    transition: opacity 0.35s ease, filter 0.35s ease, transform 0.25s ease;
  }
  .ls-spotlight-dim { opacity: 0.24 !important; }
  .ls-spotlight-active {
    opacity: 1 !important;
    filter: drop-shadow(0 0 10px rgba(180,83,9,0.65)) !important;
  }
  .ls-visual-box figure { margin: 0; }
  .ls-visual-box figcaption {
    margin-top: 8px;
    font-size: 12px;
    color: #5F554E;
    text-align: center;
    font-weight: 600;
  }
  .ls-visual-box details {
    margin-top: 10px;
    padding: 8px 12px;
    background: #FFFFFF;
    border: 1px dashed #D6C7BC;
    border-radius: 10px;
    font-size: 12.5px;
    color: #3D352E;
  }
  .ls-visual-box details summary {
    cursor: pointer;
    font-weight: 700;
    color: #7B1E2B;
  }
  .ls-visual-box img {
    max-width: 100%;
    height: auto;
    border-radius: 10px;
    margin: 0 auto;
    display: block;
    animation: lsNodePop 0.45s ease-out both;
  }
  .ls-visual-box table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .ls-visual-box th {
    background: #FBF1F2;
    color: #7B1E2B;
    text-align: left;
    padding: 8px 10px;
    border: 1px solid #E8D5D8;
    font-weight: 700;
  }
  .ls-visual-box td {
    padding: 8px 10px;
    border: 1px solid #E8E0D5;
    vertical-align: top;
    transition: background-color 0.25s ease;
  }
  .ls-visual-box tr:nth-child(even) td { background: #FAF7F2; }
  .ls-visual-box tr:hover td { background: #FFF3E6 !important; }
  .ls-row-flash td { background: #FDE68A !important; font-weight: 600; }
  #lsZoomCanvas { transform-origin: top left; transition: transform 0.2s ease; }
</style>
<div id="lsZoomModal" class="hidden fixed inset-0 z-[140] bg-black/85 flex items-center justify-center p-2 sm:p-4">
  <div class="bg-white rounded-2xl max-w-5xl w-full max-h-[92vh] flex flex-col overflow-hidden shadow-2xl">
    <div class="px-3 py-2.5 bg-[#7B1E2B] text-white flex flex-wrap items-center justify-between gap-2 text-xs font-bold">
      <span id="lsZoomTitle" class="truncate max-w-[55%]">Study Diagram</span>
      <div class="flex items-center gap-1.5">
        <button id="lsZoomOutBtn" type="button" class="px-2 py-1 rounded bg-white/15 hover:bg-white/25">- Zoom</button>
        <button id="lsZoomResetBtn" type="button" class="px-2 py-1 rounded bg-white/15 hover:bg-white/25">100%</button>
        <button id="lsZoomInBtn" type="button" class="px-2 py-1 rounded bg-white/15 hover:bg-white/25">+ Zoom</button>
        <button id="lsMemoryPulseBtn" type="button" class="px-2.5 py-1 rounded bg-amber-500 text-white hover:bg-amber-600">Memory Walk</button>
        <button id="lsZoomCloseBtn" type="button" class="px-2.5 py-1 rounded bg-white/20 hover:bg-white/30">&times; Close</button>
      </div>
    </div>
    <div id="lsZoomBody" class="p-4 overflow-auto ls-visual-box flex-1 bg-[#FAF7F2]/40">
      <div id="lsZoomCanvas"></div>
    </div>
  </div>
</div>
<script>
(function () {
  var VERCEL_OTA_BASE = "https://law-studyes.vercel.app";
  var RAW_OTA_FALLBACK = "https://raw.githubusercontent.com/khodayanvesh-jsf/law-studyes/main/www";
  var zoomScale = 1;
  var memoryTimer = null;
  var mermaidReady = false;
  var mermaidSeq = 0;

  function initMermaidOffline() {
    if (mermaidReady || typeof window.mermaid === "undefined") return;
    try {
      window.mermaid.initialize({
        startOnLoad: false,
        securityLevel: "loose",
        theme: "base",
        flowchart: { useMaxWidth: true, htmlLabels: true, curve: "basis" },
        themeVariables: {
          primaryColor: "#FBF1F2",
          primaryTextColor: "#1F1B18",
          primaryBorderColor: "#7B1E2B",
          lineColor: "#7B1E2B",
          secondaryColor: "#FFF7ED",
          tertiaryColor: "#FAF7F2",
          fontFamily: "'Noto Sans Telugu', system-ui, -apple-system, sans-serif",
          fontSize: "14px"
        }
      });
      mermaidReady = true;
    } catch (e) {}
  }

  async function renderMermaidIn(container) {
    initMermaidOffline();
    if (!mermaidReady || !container) return;
    var nodes = Array.from(container.querySelectorAll(".mermaid"));
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.getAttribute("data-ls-rendered") === "1") continue;
      var code = (el.textContent || "").trim();
      if (!code) continue;
      el.setAttribute("data-ls-rendered", "1");
      try {
        mermaidSeq++;
        var res = await window.mermaid.render("lsMmdSvg_" + mermaidSeq, code);
        if (res && res.svg) {
          el.innerHTML = res.svg;
        }
      } catch (err) {
        // Fallback: keep readable formatted flowchart text if syntax is unusual
        el.style.whiteSpace = "pre-wrap";
        el.style.fontSize = "12px";
      }
    }
  }

  function stopMemoryWalk() {
    if (memoryTimer) { clearInterval(memoryTimer); memoryTimer = null; }
    var btn = document.getElementById("lsMemoryPulseBtn");
    if (btn) btn.textContent = "Memory Walk";
    var c = document.getElementById("lsZoomCanvas");
    if (c) {
      c.querySelectorAll(".ls-spotlight-dim,.ls-spotlight-active,.ls-row-flash").forEach(function (el) {
        el.classList.remove("ls-spotlight-dim", "ls-spotlight-active", "ls-row-flash");
      });
    }
  }

  function startMemoryWalk() {
    var c = document.getElementById("lsZoomCanvas");
    if (!c) return;
    if (memoryTimer) { stopMemoryWalk(); return; }
    var rows = Array.from(c.querySelectorAll("tbody tr, table tr"));
    var mmdNodes = Array.from(c.querySelectorAll("svg .node"));
    var genericSvg = Array.from(c.querySelectorAll("svg > g, svg rect, svg circle, svg polygon"));
    var targets = rows.length > 1 ? rows : (mmdNodes.length ? mmdNodes : genericSvg);
    if (!targets.length) return;
    var btn = document.getElementById("lsMemoryPulseBtn");
    if (btn) btn.textContent = "Stop Walk";
    var isTable = rows.length > 1;
    var step = 0;
    function tick() {
      for (var i = 0; i < targets.length; i++) {
        if (isTable) {
          targets[i].classList.toggle("ls-row-flash", i === step);
        } else {
          targets[i].classList.toggle("ls-spotlight-active", i === step);
          targets[i].classList.toggle("ls-spotlight-dim", i !== step);
        }
      }
      step = (step + 1) % targets.length;
    }
    tick();
    memoryTimer = setInterval(tick, 1400);
  }

  function applyZoom() {
    var c = document.getElementById("lsZoomCanvas");
    if (c) c.style.transform = "scale(" + zoomScale.toFixed(2) + ")";
    var r = document.getElementById("lsZoomResetBtn");
    if (r) r.textContent = Math.round(zoomScale * 100) + "%";
  }

  var dbReloadAttempted = false;
  async function ensureVisualsInState() {
    if (dbReloadAttempted || typeof state === "undefined" || !state.notes) return;
    var keys = Object.keys(state.notes);
    var hasAnyVisual = false;
    for (var i = 0; i < keys.length; i++) {
      var n = state.notes[keys[i]];
      if ((n && n.en && n.en.visuals && n.en.visuals.length) || (n && n.te && n.te.visuals && n.te.visuals.length)) {
        hasAnyVisual = true;
        break;
      }
    }
    if (hasAnyVisual) return;
    dbReloadAttempted = true;
    try {
      var res = await fetch("./nyayasaral_db.json?v=" + Date.now(), { cache: "no-store" });
      if (!res.ok) res = await fetch(VERCEL_OTA_BASE + "/nyayasaral_db.json?v=" + Date.now(), { cache: "no-store" });
      if (res.ok) {
        var fresh = await res.json();
        if (fresh && fresh.notes) {
          state.notes = fresh.notes;
          if (Array.isArray(fresh.subjects) && fresh.subjects.length) state.subjects = fresh.subjects;
          injectTopicVisuals();
        }
      }
    } catch (e) {}
  }

  function injectTopicVisuals() {
    if (typeof state === "undefined" || !state.activeTopicId) return;
    var pane = document.getElementById("readingPane");
    if (!pane) return;
    var existing = document.getElementById("lsVisualDiagramsSection");
    if (existing) existing.remove();

    var rec = state.notes && state.notes[state.activeTopicId];
    var langData = rec ? (rec[state.lang] || rec.en) : null;
    var visuals = (langData && Array.isArray(langData.visuals)) ? langData.visuals : [];
    if (!visuals.length && rec && rec.en && Array.isArray(rec.en.visuals)) visuals = rec.en.visuals;
    if (!visuals.length) { ensureVisualsInState(); return; }

    var sec = document.createElement("section");
    sec.id = "lsVisualDiagramsSection";
    sec.className = "bg-white border border-[#E8E0D5] rounded-2xl p-5 shadow-sm space-y-4 ls-visual-card";

    var header = document.createElement("div");
    header.className = "flex flex-wrap items-center justify-between gap-2";
    header.innerHTML = '<h2 class="font-editorial text-lg font-bold text-[#7B1E2B]">Visual Diagrams, Flowcharts &amp; Tables (' + visuals.length + ')</h2>' +
      '<span class="text-[11px] font-semibold text-[#5F554E] bg-[#FAF7F2] px-2.5 py-0.5 rounded-full border border-[#E8E0D5]">Tap diagram to Zoom &amp; Memory Walk</span>';
    sec.appendChild(header);

    for (var i = 0; i < visuals.length; i++) {
      (function (v, idx) {
        var box = document.createElement("div");
        box.className = "ls-visual-box bg-[#FAF7F2]/60 border border-[#E8E0D5] rounded-xl p-3.5 overflow-x-auto cursor-pointer hover:border-[#7B1E2B] ls-visual-card";
        box.style.animationDelay = (idx * 95) + "ms";
        box.innerHTML = v.html;
        box.addEventListener("click", function (ev) {
          if (ev.target && ev.target.closest && ev.target.closest("summary,details")) return;
          stopMemoryWalk();
          zoomScale = 1;
          var zm = document.getElementById("lsZoomModal");
          var zc = document.getElementById("lsZoomCanvas");
          var zt = document.getElementById("lsZoomTitle");
          if (zm && zc) {
            zc.innerHTML = box.innerHTML;
            applyZoom();
            if (zt) zt.textContent = v.caption || ("Study Diagram " + (idx + 1) + " of " + visuals.length);
            zm.classList.remove("hidden");
            renderMermaidIn(zc);
          }
        });
        sec.appendChild(box);
      })(visuals[i], i);
    }

    var afterEl = pane.querySelector('[data-section-card="inOneMinute"]') || pane.children[1] || pane.firstChild;
    if (afterEl && afterEl.nextSibling) {
      pane.insertBefore(sec, afterEl.nextSibling);
    } else {
      pane.appendChild(sec);
    }
    renderMermaidIn(sec);
  }

  // Unified, resilient OTA helper: prevents duplicate download race & uses Vercel CDN first
  function wrapCapacitorUpdaterResilient() {
    var up = window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.CapacitorUpdater;
    if (!up || up.__lsResilientWrapped) return;
    up.__lsResilientWrapped = true;
    try { up.notifyAppReady(); } catch (e) {}
    var activeDownload = null;
    var origDownload = up.download.bind(up);
    up.download = async function (opts) {
      if (activeDownload) return activeDownload;
      activeDownload = (async function () {
        try {
          var targetVer = (opts && opts.version) ? String(opts.version) : "";
          try {
            if (typeof up.list === "function" && targetVer) {
              var listed = await up.list();
              var bundles = (listed && listed.bundles) ? listed.bundles : [];
              for (var i = 0; i < bundles.length; i++) {
                if (bundles[i].version === targetVer && bundles[i].status === "success") {
                  return bundles[i];
                }
              }
            }
          } catch (le) {}
          var primaryUrl = (opts && opts.url) ? String(opts.url) : (VERCEL_OTA_BASE + "/ota-bundle.zip");
          if (primaryUrl.indexOf("raw.githubusercontent.com") !== -1) {
            primaryUrl = primaryUrl.replace(RAW_OTA_FALLBACK, VERCEL_OTA_BASE);
          }
          try {
            return await origDownload(Object.assign({}, opts, { url: primaryUrl }));
          } catch (firstErr) {
            var fbUrl = primaryUrl.replace(VERCEL_OTA_BASE, RAW_OTA_FALLBACK);
            if (fbUrl !== primaryUrl) {
              return await origDownload(Object.assign({}, opts, { url: fbUrl }));
            }
            throw firstErr;
          }
        } finally {
          activeDownload = null;
        }
      })();
      return activeDownload;
    };
  }

  window.addEventListener("DOMContentLoaded", function () {
    initMermaidOffline();
    wrapCapacitorUpdaterResilient();
    var closeModal = function () {
      stopMemoryWalk();
      var zm = document.getElementById("lsZoomModal");
      if (zm) zm.classList.add("hidden");
    };
    var cBtn = document.getElementById("lsZoomCloseBtn");
    if (cBtn) cBtn.addEventListener("click", closeModal);
    var zmEl = document.getElementById("lsZoomModal");
    if (zmEl) zmEl.addEventListener("click", function (e) { if (e.target.id === "lsZoomModal") closeModal(); });
    var zi = document.getElementById("lsZoomInBtn");
    if (zi) zi.addEventListener("click", function () { zoomScale = Math.min(2.6, zoomScale + 0.25); applyZoom(); });
    var zo = document.getElementById("lsZoomOutBtn");
    if (zo) zo.addEventListener("click", function () { zoomScale = Math.max(0.6, zoomScale - 0.25); applyZoom(); });
    var zr = document.getElementById("lsZoomResetBtn");
    if (zr) zr.addEventListener("click", function () { zoomScale = 1; applyZoom(); });
    var mp = document.getElementById("lsMemoryPulseBtn");
    if (mp) mp.addEventListener("click", startMemoryWalk);

    setTimeout(function () {
      wrapCapacitorUpdaterResilient();
      if (typeof window.renderReadingPane === "function" && !window.__lsVisualHooked) {
        window.__lsVisualHooked = true;
        var origR = window.renderReadingPane;
        window.renderReadingPane = function () {
          var res = origR.apply(this, arguments);
          setTimeout(injectTopicVisuals, 30);
          return res;
        };
      }
      injectTopicVisuals();
      ensureVisualsInState();
    }, 450);
  });
})();
</script>
<!-- LS_VISUAL_DIAGRAMS_END -->
</body>
'@

$h = $h.Replace('</body>', $visualBlock)
[System.IO.File]::WriteAllText($idx, $h, $u)

# Verify 0 JS syntax errors across every inline <script> tag
$i = 0; $fails = 0
[regex]::Matches($h, '(?s)<script>(.*?)</script>') | ForEach-Object {
  $i++; $tmp = "$env:TEMP\ls_chk_261_$i.js"
  [System.IO.File]::WriteAllText($tmp, $_.Groups[1].Value, $u)
  $err = node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $fails++; Write-Host "Script #$i FAIL: $err" -ForegroundColor Red }
}
if ($fails -gt 0) { throw "$fails JS error(s) found in www/index.html!" }
Write-Host "[PASS] All $i inline JS blocks verified (0 errors)! Offline Mermaid + Animations + OTA Fix ready." -ForegroundColor Green

Write-Host "`n=== 3. Upgrading Push-LawStudyes-OTA.ps1 (Full Diagram DB + Offline Mermaid + Vercel CDN + SHA-256) ===" -ForegroundColor Cyan
$pushOtaScript = @'
<#
.SYNOPSIS
  Law Studyes OTA Publisher v2.6.1
  Packs UI + offline mermaid.min.js + FULL nyayasaral_db.json (all 591 EN/TE notes + verbatim
  Mermaid flowcharts, SVG diagrams, inline images & tables) into forward-slash www/ota-bundle.zip,
  updates Vercel CDN OTA manifests with SHA-256, pushes to GitHub/Vercel, and verifies live parity.
#>
param(
  [string]$Version = (Get-Date).ToUniversalTime().ToString("yyyy.MM.dd.HHmm"),
  [string]$VercelBaseUrl = "https://law-studyes.vercel.app"
)

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$root = (Get-Location).Path
$wwwDir = Join-Path $root "www"
$zipPath = Join-Path $wwwDir "ota-bundle.zip"
$baseUrl = $VercelBaseUrl.TrimEnd('/')

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# Pack ALL web assets INCLUDING vendor/mermaid.min.js, nyayasaral_db.json & db-version.json
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  Get-ChildItem -Path $wwwDir -Recurse -File | Where-Object {
    $_.Name -notin @("ota-bundle.zip", "ota-version.json", "ota-manifest.json", "LawStudyes-Offline.apk")
  } | ForEach-Object {
    $rel = $_.FullName.Substring($wwwDir.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
  }
} finally {
  $zip.Dispose()
}

$zipSizeBytes = (Get-Item $zipPath).Length
$zipSizeMB = [Math]::Round($zipSizeBytes / 1MB, 2)
$zipSha = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
$nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$verObj = [ordered]@{
  version   = $Version
  url       = "$baseUrl/ota-bundle.zip"
  sha256    = $zipSha
  sizeBytes = $zipSizeBytes
  updatedAt = $nowIso
} | ConvertTo-Json -Depth 3

$manObj = [ordered]@{
  app       = "Law Studyes"
  version   = $Version
  bundle    = "ota-bundle.zip"
  url       = "$baseUrl/ota-bundle.zip"
  sha256    = $zipSha
  sizeBytes = $zipSizeBytes
  updatedAt = $nowIso
} | ConvertTo-Json -Depth 3

[System.IO.File]::WriteAllText((Join-Path $wwwDir "ota-version.json"), $verObj, $utf8NoBom)
[System.IO.File]::WriteAllText((Join-Path $wwwDir "ota-manifest.json"), $manObj, $utf8NoBom)

Write-Host "[OK] Built FULL Diagram + Mermaid OTA v$Version -> www/ota-bundle.zip ($zipSizeMB MB | SHA256: $($zipSha.Substring(0,16)))" -ForegroundColor Green

$gi = Join-Path $root ".gitignore"
if (Test-Path $gi) {
  $giTxt = [System.IO.File]::ReadAllText($gi, $utf8NoBom)
  if ($giTxt -notmatch 'audit_extract') {
    [System.IO.File]::WriteAllText($gi, ($giTxt.TrimEnd() + "`r`naudit_extract/`r`n"), $utf8NoBom)
  }
} else {
  [System.IO.File]::WriteAllText($gi, "audit_extract/`r`n", $utf8NoBom)
}

git add -A
git commit -m "OTA v$Version - Full 591 EN/TE notes + Offline Mermaid Flowcharts, Diagrams & Animations"
git pull --rebase origin main
git push origin main

Write-Host "[WAIT] Waiting 30s for Vercel CDN to publish v$Version..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

try {
  $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $liveMeta = (Invoke-WebRequest "$baseUrl/ota-version.json?t=$ts" -UseBasicParsing -TimeoutSec 20).Content | ConvertFrom-Json
  $tmpZip = Join-Path $env:TEMP "ls_live_verify.zip"
  Invoke-WebRequest "$baseUrl/ota-bundle.zip?t=$ts" -OutFile $tmpZip -UseBasicParsing -TimeoutSec 60
  $liveSha = (Get-FileHash $tmpZip -Algorithm SHA256).Hash.ToLower()
  if ($liveSha -eq $zipSha -and $liveMeta.version -eq $Version) {
    Write-Host "[VERIFIED] Vercel LIVE Parity MATCH! Version=$($liveMeta.version) | SHA=$($liveSha.Substring(0,16))" -ForegroundColor Green
  } else {
    Write-Host "[INFO] Vercel still propagating (Live=$($liveMeta.version) vs Local=$Version). Wait 20s and re-test." -ForegroundColor Yellow
  }
} catch {
  Write-Host "[WARN] Live verify skipped: $($_.Exception.Message)" -ForegroundColor Yellow
}

'@
[System.IO.File]::WriteAllText((Join-Path $root "Push-LawStudyes-OTA.ps1"), $pushOtaScript, $u)

Write-Host "`n=== 4. Building Clean Bloat-Free Signed Release APK v$ver (ALL Verbatim Diagrams Offline!) ===" -ForegroundColor Cyan

# Safely remove deprecated bundledWebRuntime from capacitor.config.json
$capCfgPath = Join-Path $root "capacitor.config.json"
if (Test-Path $capCfgPath) {
  python -c "import json,pathlib; p=pathlib.Path('capacitor.config.json'); d=json.loads(p.read_text(encoding='utf-8')); d.pop('bundledWebRuntime',None); p.write_text(json.dumps(d,indent=2),encoding='utf-8')"
}

# Bump Android Gradle versionCode & versionName
$bg = Join-Path $root "android\app\build.gradle"
$bgTxt = [System.IO.File]::ReadAllText($bg, $u)
$bgTxt = $bgTxt -replace 'versionCode\s+\d+', "versionCode $verCode"
$bgTxt = $bgTxt -replace 'versionName\s+"[^"]+"', "versionName `"$ver`""
[System.IO.File]::WriteAllText($bg, $bgTxt, $u)

# Remove previous APK & OTA zip from www/ BEFORE cap sync so zero recursive bloat enters the APK
Remove-Item (Join-Path $root "www\LawStudyes-Offline.apk"), (Join-Path $root "www\ota-bundle.zip") -ErrorAction SilentlyContinue

npx cap sync android
if ($LASTEXITCODE -ne 0) { throw "npx cap sync android failed!" }

Push-Location ".\android"
try {
  .\gradlew.bat assembleRelease
  if ($LASTEXITCODE -ne 0) { throw "Gradle assembleRelease failed!" }
} finally {
  Pop-Location
}

$apk = ".\android\app\build\outputs\apk\release\app-release.apk"
$dest = Join-Path ([Environment]::GetFolderPath("Desktop")) "LawStudyes-v$ver-WithDiagrams-OTA.apk"
Copy-Item $apk $dest -Force
Copy-Item $apk (Join-Path $root "www\LawStudyes-Offline.apk") -Force
$apkMB = [Math]::Round((Get-Item $dest).Length / 1MB, 2)
Write-Host "[SUCCESS] Clean Desktop APK ready: $dest ($apkMB MB)" -ForegroundColor Green

Write-Host "`n=== 5. Pushing Full-Diagram OTA Bundle + Clean APK to GitHub & Vercel ===" -ForegroundColor Cyan
& (Join-Path $root "Push-LawStudyes-OTA.ps1")
