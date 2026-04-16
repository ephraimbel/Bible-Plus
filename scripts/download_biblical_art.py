#!/usr/bin/env python3
"""
Download Tier 1 biblical art assets from Wikimedia Commons and install them
into Resources/Assets.xcassets/BiblicalArt/ as Xcode .imageset folders.

What this does
--------------
For each Tier 1 key in BiblicalImageService.acquisitionPriority, this script:
  1. Resolves a known Wikimedia "File:" page name (or searches Commons if no
     hard-coded match exists).
  2. Calls the Wikimedia API to get a download URL for a 2000px-wide rendering
     of the original (Wikimedia auto-thumbs giant TIFFs down for us).
  3. Downloads to Resources/Assets.xcassets/BiblicalArt/biblical_<key>.imageset/
     biblical_<key>.jpg
  4. Writes the matching Contents.json so Xcode picks it up.

Idempotency
-----------
If an .imageset already contains a .jpg, the entry is skipped. Delete the
imageset folder to force a re-download.

Safety
------
- Only stdlib (urllib, json, os, sys, pathlib). No third-party deps.
- Per-image try/except: one failure does not abort the batch.
- Prints the resolved Wikimedia source URL for every image so you can verify
  the painting is the one you expected, and replace it manually if not.
- All listed paintings are public domain (pre-1900 or PD-by-author).
  Wikimedia's image-info response includes the file's licensing for confirmation.

Usage
-----
    python3 scripts/download_biblical_art.py            # Tier 1 only
    python3 scripts/download_biblical_art.py --all      # All missing tiers

You can re-run this safely. After it finishes, regenerate the Xcode project
with `xcodegen generate` if needed (asset catalogs are usually picked up
automatically — but new imagesets sometimes need a clean build).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "Resources" / "Assets.xcassets" / "BiblicalArt"

WIKIMEDIA_API = "https://commons.wikimedia.org/w/api.php"
USER_AGENT = "BiblePlusArtFetcher/1.0 (https://bibleplus.io; assets@bibleplus.io)"
TARGET_WIDTH = 2000  # px — Wikimedia auto-thumbs down for us

# -----------------------------------------------------------------------------
# Manifest
# -----------------------------------------------------------------------------
# Each entry: (key, wikimedia_file_or_search_query, is_search, expected_artist)
#
# - If `is_search` is False, the second item is treated as a literal File: page
#   name on Wikimedia Commons (without the "File:" prefix). Use this when you
#   know the canonical filename — it's far more reliable than searching.
# - If `is_search` is True, the second item is a search query handed to the
#   Wikimedia search API. The first File:* result is used. Always verify the
#   resolved URL printed at runtime.
#
# `expected_artist` is informational only — it appears in the resolved-URL log
# so you can sanity-check that the file the API returned is the one you wanted.

TIER_1 = [
    ("empty_tomb",
     "Carl_Heinrich_Bloch_-_The_Resurrection.jpg",
     False,
     "Carl Bloch"),

    ("last_supper",
     "Carl_Bloch_-_Last_Supper.jpg",
     True,  # Bloch's Last Supper file name is uncertain — search instead
     "Carl Bloch"),

    ("prodigal_son",
     "Rembrandt_Harmensz_van_Rijn_-_Return_of_the_Prodigal_Son_-_Google_Art_Project.jpg",
     False,
     "Rembrandt"),

    ("good_samaritan",
     "Rembrandt_Harmensz._van_Rijn_033.jpg",
     False,
     "Rembrandt"),

    ("annunciation",
     "Henry Ossawa Tanner Annunciation",
     True,
     "Henry Ossawa Tanner"),

    ("burning_bush",
     "Sébastien_Bourdon_-_Burning_bush.jpg",
     False,
     "Sébastien Bourdon"),

    ("parting_red_sea",
     "Doré_-_The_Egyptians_Drowned_in_the_Red_Sea.jpg",
     False,
     "Gustave Doré"),

    ("gethsemane",
     "Carl_Heinrich_Bloch_-_Gethsemane.jpg",
     False,
     "Carl Bloch"),

    ("pentecost",
     "Jean Restout Pentecost",
     True,
     "Jean Restout"),

    ("lazarus_raised",
     "Carl_Heinrich_Bloch_-_The_Raising_of_Lazarus.jpg",
     False,
     "Carl Bloch"),
]

# Tier 2 — added if --all is passed. Format identical to TIER_1.
# These are best-effort lookups; verify each resolved URL by hand.
TIER_2 = [
    ("jonah_whale", "Jonah and the whale Pieter Lastman", True, "Pieter Lastman"),
    ("noah_ark", "Edward_Hicks_-_Noah%27s_Ark.jpg", False, "Edward Hicks"),
    ("joseph_egypt", "Joseph reveals himself to his brothers", True, "Léon Pierre Urbain Bourgeois"),
    ("ezekiel_bones", "Doré valley of dry bones", True, "Gustave Doré"),
    ("road_emmaus", "Robert Zünd Road to Emmaus", True, "Robert Zünd"),
    ("walking_water", "Christ walking on the sea", True, "Amédée Varint"),
    ("elijah_carmel", "Elijah Mount Carmel Lucas Cranach", True, "Lucas Cranach"),
    ("doubting_thomas", "Caravaggio_-_The_Incredulity_of_Saint_Thomas.jpg", False, "Caravaggio"),
    ("feeding_5000", "Giovanni Lanfranco loaves and fishes", True, "Giovanni Lanfranco"),
    ("transfiguration", "Transfiguration_Raphael.jpg", False, "Raphael"),
]


# -----------------------------------------------------------------------------
# Wikimedia API helpers
# -----------------------------------------------------------------------------

def _http_get_json(url: str) -> dict:
    """GET a URL and parse the response as JSON. Sets a UA per Wikimedia policy."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _http_download(url: str, dest: Path) -> int:
    """Download `url` to `dest`. Returns bytes written."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return len(data)


def search_for_file(query: str) -> str | None:
    """Search Commons File: namespace and return the first matching file title
    (without the "File:" prefix), or None.
    """
    params = {
        "action": "query",
        "list": "search",
        "srsearch": query,
        "srnamespace": "6",  # File:
        "srlimit": "5",
        "format": "json",
    }
    url = f"{WIKIMEDIA_API}?{urllib.parse.urlencode(params)}"
    data = _http_get_json(url)
    results = data.get("query", {}).get("search", [])
    for hit in results:
        title = hit.get("title", "")
        if title.startswith("File:"):
            return title[len("File:"):]
    return None


def resolve_image_url(file_name: str, width: int = TARGET_WIDTH) -> tuple[str, dict] | None:
    """Resolve a Wikimedia File:* name to a (download_url, info) pair.
    Uses imageinfo with iiurlwidth so we get a sensibly sized rendering rather
    than a 50MB original TIFF. Returns None on failure.
    """
    params = {
        "action": "query",
        "titles": f"File:{file_name}",
        "prop": "imageinfo",
        "iiprop": "url|extmetadata|size",
        "iiurlwidth": str(width),
        "format": "json",
    }
    url = f"{WIKIMEDIA_API}?{urllib.parse.urlencode(params)}"
    data = _http_get_json(url)
    pages = data.get("query", {}).get("pages", {})
    for _, page in pages.items():
        if page.get("missing") is not None:
            return None
        infos = page.get("imageinfo", [])
        if not infos:
            return None
        info = infos[0]
        # Prefer the resized thumb if available, else original.
        download_url = info.get("thumburl") or info.get("url")
        if download_url:
            return download_url, info
    return None


# -----------------------------------------------------------------------------
# Imageset writing
# -----------------------------------------------------------------------------

def imageset_dir_for(key: str) -> Path:
    return ASSETS_DIR / f"biblical_{key}.imageset"


def write_contents_json(imageset_dir: Path, filename: str) -> None:
    contents = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }
    (imageset_dir / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n",
        encoding="utf-8",
    )


def already_downloaded(key: str) -> bool:
    """True if the imageset already has *any* .jpg/.png/.jpeg file."""
    d = imageset_dir_for(key)
    if not d.is_dir():
        return False
    for f in d.iterdir():
        if f.suffix.lower() in {".jpg", ".jpeg", ".png"}:
            return True
    return False


# -----------------------------------------------------------------------------
# Per-entry pipeline
# -----------------------------------------------------------------------------

def process_entry(key: str, query_or_file: str, is_search: bool, expected_artist: str) -> tuple[bool, str]:
    """Returns (success, message)."""
    if already_downloaded(key):
        return True, f"skipped — biblical_{key} already has an image"

    # Step 1: resolve a File: name
    if is_search:
        print(f"  searching: {query_or_file!r}")
        file_name = search_for_file(query_or_file)
        if not file_name:
            return False, "search returned no results"
        print(f"  → found:   File:{file_name}")
    else:
        file_name = query_or_file

    # Step 2: resolve to a download URL
    resolved = resolve_image_url(file_name)
    if not resolved:
        return False, f"could not resolve File:{file_name}"
    download_url, info = resolved
    width = info.get("thumbwidth") or info.get("width")
    height = info.get("thumbheight") or info.get("height")
    print(f"  url:       {download_url}")
    print(f"  size:      {width}x{height}")
    print(f"  expected:  {expected_artist}")

    # Step 3: download
    imageset = imageset_dir_for(key)
    filename = f"biblical_{key}.jpg"
    dest = imageset / filename
    try:
        size = _http_download(download_url, dest)
    except Exception as e:
        return False, f"download failed: {e}"

    # Step 4: write Contents.json
    write_contents_json(imageset, filename)

    return True, f"downloaded {size:,} bytes → {dest.relative_to(REPO_ROOT)}"


def run(entries: list[tuple[str, str, bool, str]]) -> int:
    if not ASSETS_DIR.is_dir():
        print(f"FATAL: assets dir not found at {ASSETS_DIR}", file=sys.stderr)
        return 2

    print(f"Target: {ASSETS_DIR.relative_to(REPO_ROOT)}")
    print(f"User-Agent: {USER_AGENT}")
    print(f"Target width: {TARGET_WIDTH}px")
    print(f"Processing {len(entries)} entries\n")

    successes: list[str] = []
    failures: list[tuple[str, str]] = []

    for key, query, is_search, artist in entries:
        print(f"━━━ {key} ━━━")
        try:
            ok, msg = process_entry(key, query, is_search, artist)
        except Exception as e:
            ok, msg = False, f"unhandled error: {e}"
        if ok:
            successes.append(f"{key}: {msg}")
            print(f"  ✓ {msg}")
        else:
            failures.append((key, msg))
            print(f"  ✗ {msg}")
        print()

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"DONE — {len(successes)} succeeded, {len(failures)} failed")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    if failures:
        print("\nFailures:")
        for key, msg in failures:
            print(f"  • {key}: {msg}")
        print("\nFor any failure, find the painting on commons.wikimedia.org,")
        print("copy the File:NAME from the URL, and either:")
        print("  (a) edit this script's manifest with the literal File: name, or")
        print("  (b) drop the .jpg into the imageset folder by hand and run")
        print("      this script again — it will skip already-populated entries.")

    return 0 if not failures else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--all",
        action="store_true",
        help="Also process Tier 2 entries (default: Tier 1 only).",
    )
    args = parser.parse_args()

    entries = list(TIER_1)
    if args.all:
        entries.extend(TIER_2)
    return run(entries)


if __name__ == "__main__":
    sys.exit(main())
