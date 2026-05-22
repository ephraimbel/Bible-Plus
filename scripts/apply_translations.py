#!/usr/bin/env python3
"""Merge a JSON blob of {lang_code: {english_key: translation}} into the
String Catalog. Used when translations are produced in-conversation instead
of from an API call.

Input shape:
{
  "es": { "Home": "Inicio", "Settings": "Ajustes", ... },
  "fr": { "Home": "Accueil", ... },
  ...
}

Usage:
  python3 Scripts/apply_translations.py path/to/batch.json
  python3 Scripts/apply_translations.py -     # read stdin
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"

def main():
    if len(sys.argv) < 2:
        print("usage: apply_translations.py <json-file|->", file=sys.stderr)
        sys.exit(1)
    if sys.argv[1] == "-":
        batch = json.load(sys.stdin)
    else:
        with open(sys.argv[1]) as f:
            batch = json.load(f)

    with open(CATALOG) as f:
        cat = json.load(f)

    total_written = 0
    for lang_code, mapping in batch.items():
        if not isinstance(mapping, dict):
            continue
        written = 0
        for key, value in mapping.items():
            if not isinstance(value, str) or not value:
                continue
            if key not in cat["strings"]:
                # Skip unknown keys so noise doesn't pollute the catalog.
                continue
            entry = cat["strings"][key]
            locs = entry.setdefault("localizations", {})
            locs[lang_code] = {
                "stringUnit": {"state": "translated", "value": value}
            }
            written += 1
        print(f"[{lang_code}] wrote {written}/{len(mapping)}", file=sys.stderr)
        total_written += written

    with open(CATALOG, "w") as f:
        json.dump(cat, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"total: {total_written} translations merged", file=sys.stderr)

if __name__ == "__main__":
    main()
