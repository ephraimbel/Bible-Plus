#!/usr/bin/env python3
"""Translate all keys in Resources/Localizable.xcstrings to every supported language
via the OpenAI Chat Completions API. One request per (language), asking the
model to return a JSON object mapping English → target-language for all keys
missing a translation.

Usage:
  OPENAI_API_KEY=sk-... python3 Scripts/translate_catalog.py                # all supported locales
  OPENAI_API_KEY=sk-... python3 Scripts/translate_catalog.py --langs es de  # subset
  OPENAI_API_KEY=sk-... python3 Scripts/translate_catalog.py --dry-run      # print plan

Notes:
  * Uses gpt-4o-mini for ~$0.15/1M input + $0.60/1M output. Full 301-key
    translation into 15 languages is under $5 total.
  * Keeps existing translations intact — only fills gaps.
  * Never runs without the env var. Writes incrementally so a mid-run error
    doesn't lose work.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
from collections import Counter
import sys
import threading
import time
from pathlib import Path

# Lazy import — only needed when actually calling the API. Keeps `--dry-run`
# working even if `openai` isn't installed.
def _import_openai():
    try:
        from openai import OpenAI
        return OpenAI
    except ImportError:
        print("ERROR: openai package not installed. Run: pip3 install --break-system-packages openai", file=sys.stderr)
        sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"

# Keep the target list tied to the app's actual 40-language catalog.
ALL_LANGUAGES = re.findall(
    r'SupportedLanguage\(code: "([^"]+)",\s*nativeName: "[^"]+",\s*englishName: "([^"]+)"',
    (ROOT / "Shared/Models/SupportedLanguage.swift").read_text(),
)
TARGET_LANGUAGES = [(code, name) for code, name in ALL_LANGUAGES if code != "en"]

SYSTEM_PROMPT = """You are translating UI strings for a Christian Bible app called Bible Plus.

The app has 5 core features: a personalized feed of verses and prayers, an AI pastoral chat, a Bible reader with audio, home-screen widgets, and a Sanctuary mode for ambient prayer.

Translation rules:
1. Preserve tone — warm, reverent, pastoral. Never casual or commercial.
2. Preserve Biblical terminology in the target language's standard Christian register (use the language's widely-accepted Bible translation vocabulary — e.g. "Psalms" → "Salmos" in Spanish, not a literal translation).
3. Preserve ALL placeholders and formatting exactly: `{name}`, `%@`, `%d`, `\\n`, backslashes, quote marks.
4. UI section headers that are ALL CAPS in English should remain ALL CAPS in the target language (where the script supports case).
5. Short button labels stay short. Never expand "OK" into a paragraph.
6. Do NOT translate: "Bible Plus" (product name), "Pro" (as in subscription tier — keep English), "AI", "KJV"/"WEB"/etc. (Bible translation abbreviations).
7. This batch includes legal consent and subscription disclosures. Preserve the exact
meaning of explicit permission, auto-renewal, cancellation deadlines, and third-party
sharing. Never weaken these statements. Preserve Bible+, OpenAI, WEB, KJV, BSB,
CC BY, CC BY-SA, 988, 911, and 112 verbatim. Do not translate Scripture quotations.
8. Return ONLY valid JSON. No commentary. No markdown fences.
"""

USER_TEMPLATE = """Translate the following English UI strings to {language}.

Return a JSON object mapping each English string (verbatim, as the key) to its {language} translation (as the value).

Strings:
{payload}
"""

def load_catalog() -> dict:
    with open(CATALOG) as f:
        return json.load(f)

def save_catalog(cat: dict) -> None:
    with open(CATALOG, "w") as f:
        json.dump(cat, f, indent=2, ensure_ascii=False)
        f.write("\n")

def missing_keys_for(cat: dict, lang_code: str) -> list[str]:
    missing = []
    for key, val in cat["strings"].items():
        locs = val.get("localizations", {})
        if locs.get(lang_code, {}).get("stringUnit", {}).get("state") != "translated":
            missing.append(key)
    return missing

def set_translation(cat: dict, key: str, lang_code: str, value: str) -> None:
    entry = cat["strings"].setdefault(key, {"localizations": {}})
    locs = entry.setdefault("localizations", {})
    locs[lang_code] = {"stringUnit": {"state": "translated", "value": value}}

def chunked(lst: list[str], n: int):
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

def translate_batch(client, keys: list[str], lang_code: str, lang_name: str) -> dict[str, str]:
    payload = json.dumps(keys, ensure_ascii=False, indent=2)
    user = USER_TEMPLATE.format(language=lang_name, payload=payload)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        max_tokens=6000,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user},
        ],
        response_format={"type": "json_object"},
        temperature=0.3,
    )
    content = resp.choices[0].message.content
    parsed = json.loads(content)
    # Accept either {"translations": {...}} or a flat {key: value} object.
    if "translations" in parsed and isinstance(parsed["translations"], dict):
        return parsed["translations"]
    return parsed


def valid_translation(source: str, target: str) -> bool:
    if not target.strip():
        return False
    # Positional markers may reorder placeholders; their type/count must match.
    pattern = r"%(?:\d+\$)?(?:lld|ld|d|@|f|s)"
    normalize = lambda text: Counter(re.sub(r"%\d+\$", "%", p) for p in re.findall(pattern, text))
    if normalize(source) != normalize(target):
        return False
    protected = ["Bible+", "Bible Plus", "OpenAI", "WEB", "KJV", "BSB", "CC BY-SA", "CC BY", "988", "911", "112", "{name}"]
    return all(source.count(term) == target.count(term) for term in protected if term in source)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--langs", nargs="*", help="Subset of language codes (default: all supported locales)")
    ap.add_argument("--keys-file", type=Path, help="Translate only keys in this JSON list")
    ap.add_argument("--dry-run", action="store_true", help="Print scope, skip API calls")
    ap.add_argument("--chunk", type=int, default=80, help="Keys per API request (default 80)")
    ap.add_argument("--concurrency", type=int, default=14,
                    help="Number of languages to translate concurrently (default 14; set to 1 for sequential)")
    args = ap.parse_args()

    if not os.environ.get("OPENAI_API_KEY") and not args.dry_run:
        print("ERROR: OPENAI_API_KEY not set. Run with --dry-run to preview scope.", file=sys.stderr)
        sys.exit(1)

    targets = [(c, n) for c, n in TARGET_LANGUAGES if (not args.langs or c in args.langs)]
    if not targets:
        print("No matching languages.", file=sys.stderr)
        sys.exit(1)

    cat = load_catalog()
    if args.keys_file:
        selected_keys = set(json.loads(args.keys_file.read_text()))
        working_cat = {"strings": {k: v for k, v in cat["strings"].items() if k in selected_keys}}
    else:
        working_cat = cat
    print(f"Catalog: {len(cat['strings'])} keys", file=sys.stderr)
    print(f"Languages: {[c for c, _ in targets]}", file=sys.stderr)

    total_calls = 0
    total_keys = 0
    for code, name in targets:
        missing = missing_keys_for(working_cat, code)
        print(f"  [{code}] {len(missing)} missing", file=sys.stderr)
        total_keys += len(missing)
        for _ in chunked(missing, args.chunk):
            total_calls += 1

    print(f"Plan: {total_keys} translations across {total_calls} API calls", file=sys.stderr)

    if args.dry_run:
        return

    OpenAI = _import_openai()
    client = OpenAI()

    # Lock guards mutations to `cat` from concurrent threads. Each language
    # run still writes to disk serially so partial failures stay recoverable.
    write_lock = threading.Lock()

    def run_language(code: str, name: str) -> tuple[str, int, int]:
        missing = missing_keys_for(working_cat, code)
        if not missing:
            return (code, 0, 0)
        written = 0
        attempted = 0
        for chunk in chunked(missing, args.chunk):
            attempted += len(chunk)
            try:
                result = translate_batch(client, chunk, code, name)
            except Exception as e:
                print(f"  [{code}] ERROR: {e}", file=sys.stderr)
                continue
            with write_lock:
                for key in chunk:
                    if key in result and isinstance(result[key], str) and valid_translation(key, result[key]):
                        set_translation(cat, key, code, result[key])
                        written += 1
                save_catalog(cat)
        return (code, written, attempted)

    # Concurrency = 1 runs sequentially (legacy behavior); higher runs many
    # languages in parallel. OpenAI's API easily handles 14 concurrent
    # connections. Clamped to avoid rate-limit errors on stricter tiers.
    max_workers = min(args.concurrency, len(targets))
    print(f"Running {max_workers} languages concurrently…", file=sys.stderr)
    t0 = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {pool.submit(run_language, code, name): code for code, name in targets}
        for fut in concurrent.futures.as_completed(futures):
            code, written, attempted = fut.result()
            print(f"[{code}] {written}/{attempted} translated", file=sys.stderr)

    remaining = sum(len(missing_keys_for(working_cat, code)) for code, _ in targets)
    print(f"done in {time.time() - t0:.1f}s; {remaining} translations remaining.", file=sys.stderr)
    if remaining:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
