#!/usr/bin/env python3
"""Translate bundled seed content (feed items, notifications, reading plans,
testimonials, curated verses) into Tier 1 languages, writing per-locale JSON
files next to the originals in Shared/Content.

Source files handled:
  feed-content.json          → feed-content.{lang}.json
  notification-content.json  → notification-content.{lang}.json
  reading-plans.json         → reading-plans.{lang}.json
  testimonials.json          → testimonials.{lang}.json

Scope decision: curated-verses.json is NOT translated — it's a thin list of
`{bookID, chapter, verse, slots, burdens, topic}` tuples that BibleRepository
resolves against the user's active translation. Verse text is always the
user's chosen Bible (helloao or bundled KJV/WEB), so translating the tuples
would do nothing.

Translation strategy:
  * Each source file defines `TRANSLATABLE_FIELDS` — a list of JSON paths
    (dot-notation) within each item that should be translated. Everything
    else (ids, category tags, book references, durations, etc.) passes
    through unchanged.
  * One OpenAI request per (file, language) chunk — default 40 items per
    request to stay under context limits.
  * Preserves `{name}` placeholders and markdown/punctuation.
  * Writes incrementally so a mid-run crash doesn't throw away progress.

Usage:
  OPENAI_API_KEY=sk-… python3 Scripts/translate_content.py
  OPENAI_API_KEY=sk-… python3 Scripts/translate_content.py --langs es de
  OPENAI_API_KEY=sk-… python3 Scripts/translate_content.py --files feed --langs es
  python3 Scripts/translate_content.py --dry-run
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "Shared" / "Content"

TIER_1 = [
    ("es", "Spanish"),
    ("pt-BR", "Brazilian Portuguese"),
    ("fr", "French"),
    ("de", "German"),
    ("it", "Italian"),
    ("pl", "Polish"),
    ("ru", "Russian"),
    ("zh-Hans", "Simplified Chinese"),
    ("zh-Hant", "Traditional Chinese"),
    ("ko", "Korean"),
    ("ja", "Japanese"),
    ("id", "Indonesian"),
    ("tl", "Filipino / Tagalog"),
    ("sw", "Swahili"),
    ("am", "Amharic"),
]

SYSTEM_PROMPT = """You are translating devotional content for a Christian Bible app called Bible Plus.

Rules:
1. Preserve tone — warm, reverent, pastoral. Prayers are prayers in every language; reflections stay reflective.
2. Use the standard Christian register in the target language (e.g. Spanish uses "Señor", Chinese uses "主", Korean uses "주님" for "Lord").
3. Preserve ALL placeholders EXACTLY: `{name}`, `%@`, `%d`, `\\n`, quote marks, backslashes.
4. Preserve formatting: keep line breaks, quotation marks around verses, em-dashes, etc.
5. Do NOT translate Scripture references (keep "John 3:16" as "Juan 3:16" style localized conventions, but preserve book names in standard native forms).
6. Do NOT translate the app name "Bible Plus", "Pro", "AI", or Bible translation abbreviations.
7. For content with a clear {name} placeholder, keep it exactly where it is so name-token substitution still works at runtime.
8. Return ONLY valid JSON. No commentary. No markdown code fences.
"""

# ---------------------------------------------------------------------------
# File configuration — declare which fields to translate per source.
# ---------------------------------------------------------------------------

FILES = {
    "feed": {
        "source": "feed-content.json",
        # Items have no `id` — script falls back to array index. `templateText`
        # is the prayer/devotional body; `verseText` is the attached scripture.
        # `verseReference` ("Psalm 23:1") we keep in the original English form
        # since the translated text lives in the Bible module, not here.
        "fields": ["templateText", "verseText"],
        "shape": "array",
        "id_field": None,  # use array index
    },
    "notifications": {
        "source": "notification-content.json",
        "fields": ["text"],
        "shape": "array",
        "id_field": "id",
    },
    "plans": {
        "source": "reading-plans.json",
        "fields": ["name", "description"],
        "shape": "array",
        "id_field": "id",
        "nested": {
            # Reading plans have nested `days` with `title` + `reflection`.
            "path": "days",
            "fields": ["title", "reflection"],
            "id_field": "day",
        },
    },
    "testimonials": {
        "source": "testimonials.json",
        "fields": ["quote"],   # name + role stay in English (proper nouns)
        "shape": "wrapped",
        "wrapper_key": "testimonials",
        "id_field": "id",
    },
}

# ---------------------------------------------------------------------------

def _import_openai():
    try:
        from openai import OpenAI
        return OpenAI
    except ImportError:
        print("ERROR: openai not installed. Run: pip3 install --break-system-packages openai", file=sys.stderr)
        sys.exit(1)

def load_json(path: Path):
    with open(path) as f:
        return json.load(f)

def save_json(path: Path, data) -> None:
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")

def target_path(src: Path, lang: str) -> Path:
    stem = src.stem
    return src.with_name(f"{stem}.{lang}.json")

def collect_strings(item: dict, fields: list[str], prefix: str = "") -> dict[str, str]:
    """Return a flat {jsonpath: english_text} dict for the translatable fields
    on `item`. Skips empty/non-string values."""
    hits = {}
    for field in fields:
        value = item.get(field)
        if isinstance(value, str) and value.strip():
            hits[f"{prefix}{field}"] = value
    return hits

def apply_strings(item: dict, translations: dict[str, str], prefix: str = "") -> None:
    for key, value in translations.items():
        if key.startswith(prefix):
            field = key[len(prefix):]
            if isinstance(item.get(field), str):
                item[field] = value

def chunked(lst, n):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def translate_chunk(client, payload: dict[str, str], lang_code: str, lang_name: str) -> dict[str, str]:
    user = f"""Translate the following strings to {lang_name}. Return a JSON object mapping each ID (the key) to its {lang_name} translation (the value). IDs must appear verbatim in the result.

Strings:
{json.dumps(payload, ensure_ascii=False, indent=2)}
"""
    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user},
        ],
        response_format={"type": "json_object"},
        temperature=0.3,
    )
    parsed = json.loads(resp.choices[0].message.content)
    if "translations" in parsed and isinstance(parsed["translations"], dict):
        return parsed["translations"]
    return parsed

def _items_for(cfg, data):
    """Unwrap to the underlying array of items regardless of shape."""
    if cfg["shape"] == "wrapped":
        return data.get(cfg["wrapper_key"], [])
    return data

def _id_for(cfg, item, index):
    if cfg.get("id_field"):
        return str(item.get(cfg["id_field"], f"idx{index}"))
    return f"idx{index}"

def translate_file(client_or_none, file_key: str, lang_code: str, lang_name: str, dry_run: bool, chunk_size: int):
    cfg = FILES[file_key]
    src = CONTENT / cfg["source"]
    if not src.exists():
        print(f"  [skip] {src.name} not found", file=sys.stderr)
        return
    dst = target_path(src, lang_code)
    data = load_json(src)
    items = _items_for(cfg, data)

    # Build a flat map of "itemID::field" → english-text across the whole file.
    flat: dict[str, str] = {}
    for i, item in enumerate(items):
        item_id = _id_for(cfg, item, i)
        prefix = f"{item_id}::"
        flat.update({f"{prefix}{k}": v for k, v in collect_strings(item, cfg["fields"]).items()})
        if "nested" in cfg:
            n = cfg["nested"]
            for j, sub in enumerate(item.get(n["path"], []) or []):
                sub_id = str(sub.get(n["id_field"], f"idx{j}"))
                sub_prefix = f"{item_id}::{n['path']}::{sub_id}::"
                flat.update({f"{sub_prefix}{k}": v for k, v in collect_strings(sub, n["fields"]).items()})

    if not flat:
        print(f"  [skip] {src.name} no translatable strings", file=sys.stderr)
        return

    print(f"  [{file_key}/{lang_code}] {len(flat)} strings → {dst.name}", file=sys.stderr)
    if dry_run:
        return

    # Translate in chunks.
    translated: dict[str, str] = {}
    for idx, chunk in enumerate(chunked(list(flat.items()), chunk_size), 1):
        payload = dict(chunk)
        print(f"    chunk {idx}  ({len(payload)})", file=sys.stderr)
        t0 = time.time()
        try:
            result = translate_chunk(client_or_none, payload, lang_code, lang_name)
        except Exception as e:
            print(f"    ERROR: {e}", file=sys.stderr)
            continue
        translated.update({k: v for k, v in result.items() if isinstance(v, str)})
        print(f"    {len(result)} returned in {time.time() - t0:.1f}s", file=sys.stderr)

    # Apply translations to a deep-copied tree and write out.
    from copy import deepcopy
    out = deepcopy(data)
    out_items = _items_for(cfg, out)
    for i, item in enumerate(out_items):
        item_id = _id_for(cfg, item, i)
        prefix = f"{item_id}::"
        for field in cfg["fields"]:
            key = f"{prefix}{field}"
            if key in translated:
                item[field] = translated[key]
        if "nested" in cfg:
            n = cfg["nested"]
            for j, sub in enumerate(item.get(n["path"], []) or []):
                sub_id = str(sub.get(n["id_field"], f"idx{j}"))
                sub_prefix = f"{item_id}::{n['path']}::{sub_id}::"
                for field in n["fields"]:
                    key = f"{sub_prefix}{field}"
                    if key in translated:
                        sub[field] = translated[key]
    save_json(dst, out)
    print(f"  [wrote] {dst.name}", file=sys.stderr)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--langs", nargs="*", help="Subset of language codes (default: all Tier 1)")
    ap.add_argument("--files", nargs="*", choices=list(FILES.keys()),
                    help="Subset of files (default: all)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--chunk", type=int, default=40)
    ap.add_argument("--concurrency", type=int, default=15,
                    help="Number of (file, language) pairs to translate concurrently")
    args = ap.parse_args()

    if not os.environ.get("OPENAI_API_KEY") and not args.dry_run:
        print("ERROR: OPENAI_API_KEY not set. Use --dry-run to preview scope.", file=sys.stderr)
        sys.exit(1)

    targets = [(c, n) for c, n in TIER_1 if (not args.langs or c in args.langs)]
    files_to_run = args.files or list(FILES.keys())

    client = None if args.dry_run else _import_openai()()

    print(f"Languages: {[c for c, _ in targets]}", file=sys.stderr)
    print(f"Files:     {files_to_run}", file=sys.stderr)

    # Flatten (file × language) into tasks and run them concurrently. Each
    # task writes to its own per-locale JSON file, so there's no contention.
    tasks = [(file_key, code, name) for code, name in targets for file_key in files_to_run]
    if args.dry_run or args.concurrency <= 1:
        for file_key, code, name in tasks:
            translate_file(client, file_key, code, name, args.dry_run, args.chunk)
    else:
        max_workers = min(args.concurrency, len(tasks))
        print(f"\nRunning {max_workers} tasks concurrently…", file=sys.stderr)
        t0 = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
            futures = [pool.submit(translate_file, client, fk, code, name, False, args.chunk)
                       for fk, code, name in tasks]
            concurrent.futures.wait(futures)
        print(f"\nall tasks done in {time.time() - t0:.1f}s.", file=sys.stderr)

if __name__ == "__main__":
    main()
