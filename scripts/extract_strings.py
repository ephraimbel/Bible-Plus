#!/usr/bin/env python3
"""Scan Swift source for hardcoded user-facing string literals that should
live in the String Catalog. Report what's already in the catalog vs missing,
and optionally merge missing strings in as English source values.

Usage:
  python3 Scripts/extract_strings.py --report          # dry run
  python3 Scripts/extract_strings.py --merge           # write new keys to xcstrings

Patterns recognized (string-literal first-positional arg):
  Text("…")              Label("…", systemImage: …)
  Button("…") { … }       TextField("…", text: …)
  SecureField("…", …)     Toggle("…", isOn: …)
  Link("…", destination: …)
  Picker("…", selection: …)
  .navigationTitle("…")
  .navigationBarTitle("…")
  .alert("…", …)
  .confirmationDialog("…", …)
  .searchable(text: …, prompt: "…")     (prompt only)

Deliberately skipped:
  Text(verbatim:)         Text(Image(…))
  Image("…")              Image(systemName: "…")
  URL strings             String interpolations (contain \\( )
  Empty strings           SF Symbol-ish names (lowercase.dot.separated)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"

SWIFT_DIRS = [
    ROOT / "BiblePlus",
    ROOT / "BiblePlusWidgets",
    ROOT / "Shared",
]

# Patterns: each is a (call_name, position). We match the first positional
# string literal argument.
# Using a single regex per pattern keeps things simple and lets us skip
# verbatim/Image forms cleanly.
STRING_LITERAL = r'"((?:[^"\\\n]|\\.)*)"'

# Prefix lookaheads — we require the call to *start* with a string literal
# (no label before it).
PATTERNS = [
    # Text("…") but NOT Text(verbatim:…) or Text(Image(…)) or Text(<var>)
    (re.compile(r'\bText\(\s*' + STRING_LITERAL + r'\s*\)'), 'Text'),
    # .navigationTitle("…")
    (re.compile(r'\.navigationTitle\(\s*' + STRING_LITERAL + r'\s*\)'), 'navigationTitle'),
    (re.compile(r'\.navigationBarTitle\(\s*' + STRING_LITERAL + r'\s*\)'), 'navigationBarTitle'),
    # Button("…", …) or Button("…") { … }
    (re.compile(r'\bButton\(\s*' + STRING_LITERAL + r'\s*[,)]'), 'Button'),
    # Label("…", systemImage: …)
    (re.compile(r'\bLabel\(\s*' + STRING_LITERAL + r'\s*,\s*systemImage:'), 'Label'),
    # TextField("…", …)
    (re.compile(r'\bTextField\(\s*' + STRING_LITERAL + r'\s*,'), 'TextField'),
    # SecureField("…", …)
    (re.compile(r'\bSecureField\(\s*' + STRING_LITERAL + r'\s*,'), 'SecureField'),
    # Toggle("…", isOn: …)
    (re.compile(r'\bToggle\(\s*' + STRING_LITERAL + r'\s*,\s*isOn:'), 'Toggle'),
    # Link("…", destination: …)
    (re.compile(r'\bLink\(\s*' + STRING_LITERAL + r'\s*,\s*destination:'), 'Link'),
    # Picker("…", selection: …)
    (re.compile(r'\bPicker\(\s*' + STRING_LITERAL + r'\s*,\s*selection:'), 'Picker'),
    # Section("…") or Section { … } header: { Text(…) }
    (re.compile(r'\bSection\(\s*' + STRING_LITERAL + r'\s*[,)]'), 'Section'),
    # NavigationLink("…", destination: …)
    (re.compile(r'\bNavigationLink\(\s*' + STRING_LITERAL + r'\s*,\s*destination:'), 'NavigationLink'),
    # .alert("…", isPresented: …)
    (re.compile(r'\.alert\(\s*' + STRING_LITERAL + r'\s*,'), 'alert'),
    # .confirmationDialog("…", …)
    (re.compile(r'\.confirmationDialog\(\s*' + STRING_LITERAL + r'\s*,'), 'confirmationDialog'),
    # String(localized: "…") — captures the enum displayName wrapping pattern
    (re.compile(r'String\(\s*localized:\s*' + STRING_LITERAL + r'\s*\)'), 'String(localized:)'),
]

# Strings to always skip (empty, too short, obvious non-UI).
SKIP_EXACT = {"", " "}
SYMBOL_NAME_RE = re.compile(r'^[a-z0-9]+(\.[a-z0-9]+)+$')  # e.g. "person.fill"

def should_skip(s: str) -> bool:
    if s in SKIP_EXACT:
        return True
    if len(s) == 1 and not s.isalpha():
        return True
    if SYMBOL_NAME_RE.match(s):
        return True  # SF Symbol name, not UI text
    if s.startswith(("http://", "https://", "mailto:", "tel:", "bibleplus://")):
        return True
    if "\\(" in s:  # interpolation — needs manual handling
        return True
    # Pure numbers ("16", "17") — usually font size labels, not UI copy.
    stripped = s.strip()
    if stripped and all(c.isdigit() or c in ".," for c in stripped):
        return True
    # Leading-whitespace artifacts (' Pro', '/ week') are UI fragments but
    # come through as keys that won't round-trip cleanly. Skip and revisit.
    if s != s.strip() and len(s.strip()) < 6:
        return True
    return False

def load_catalog_keys() -> set[str]:
    with open(CATALOG) as f:
        d = json.load(f)
    return set(d.get("strings", {}).keys())

def scan_file(path: Path) -> list[tuple[str, str, int]]:
    """Return list of (string, pattern_name, line_number)."""
    try:
        text = path.read_text()
    except UnicodeDecodeError:
        return []
    hits: list[tuple[str, str, int]] = []
    # Compute line numbers on the fly.
    line_offsets = [0]
    for i, ch in enumerate(text):
        if ch == "\n":
            line_offsets.append(i + 1)
    def line_of(pos: int) -> int:
        # Binary search
        lo, hi = 0, len(line_offsets) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if line_offsets[mid] <= pos:
                lo = mid
            else:
                hi = mid - 1
        return lo + 1
    for regex, name in PATTERNS:
        for m in regex.finditer(text):
            s = m.group(1)
            # Unescape basic sequences to get the actual display string.
            try:
                s_unescaped = bytes(s, "utf-8").decode("unicode_escape")
            except Exception:
                s_unescaped = s
            if should_skip(s_unescaped):
                continue
            hits.append((s_unescaped, name, line_of(m.start())))
    return hits

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--merge", action="store_true", help="Write missing keys to the catalog")
    args = ap.parse_args()

    existing = load_catalog_keys()

    all_hits: dict[str, list[tuple[Path, str, int]]] = {}
    for swift_dir in SWIFT_DIRS:
        for path in swift_dir.rglob("*.swift"):
            for s, name, line in scan_file(path):
                all_hits.setdefault(s, []).append((path.relative_to(ROOT), name, line))

    found = set(all_hits.keys())
    missing = sorted(found - existing)
    already = sorted(found & existing)
    orphan = sorted(existing - found)

    print(f"=== String Catalog audit ===", file=sys.stderr)
    print(f"Catalog keys:       {len(existing)}", file=sys.stderr)
    print(f"Strings in source:  {len(found)}", file=sys.stderr)
    print(f"  In catalog:       {len(already)}", file=sys.stderr)
    print(f"  MISSING:          {len(missing)}", file=sys.stderr)
    print(f"  Orphan in catalog (no source use): {len(orphan)}", file=sys.stderr)
    print("", file=sys.stderr)

    if missing:
        print("=== Missing keys (first 40) ===", file=sys.stderr)
        for s in missing[:40]:
            occ = all_hits[s][0]
            print(f"  [{occ[1]}] {s!r}  ({occ[0]}:{occ[2]})", file=sys.stderr)
        if len(missing) > 40:
            print(f"  … and {len(missing) - 40} more", file=sys.stderr)

    if args.merge and missing:
        with open(CATALOG) as f:
            cat = json.load(f)
        for key in missing:
            cat["strings"][key] = {
                "extractionState": "manual",
                "localizations": {
                    "en": {
                        "stringUnit": {
                            "state": "translated",
                            "value": key,
                        }
                    }
                },
            }
        with open(CATALOG, "w") as f:
            json.dump(cat, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"\nMerged {len(missing)} new keys into {CATALOG.relative_to(ROOT)}", file=sys.stderr)

if __name__ == "__main__":
    main()
