#!/usr/bin/env python3
"""Download the openly licensed Bible translations Bible+ offers and bundle
them into the app as JSON, so the app makes NO runtime calls to any Bible API.

Output: Resources/Bible/bible-<ID>.json, same shape as Shared/Content/bible-kjv.json
plus a "bookNames" map of localized book names:
    {"translation": ID, "bookNames": {"GEN": "Génesis"}, "books": {"GEN": {"1": {"1": "..."}}}}

Run once when adding/updating a translation. Every ID here must also be listed in
Shared/Services/TranslationLicensePolicy.swift `bundledLicenses` (public domain,
or a license allowing commercial use AND derivatives). Source text is fetched
from bible.helloao.org's static files at build time only.
"""
import json
import os
import re
import sys
import urllib.request

IDS = [
    # Featured English (public domain)
    "BSB", "eng_asv", "eng_ylt", "eng_dra",
    # Language defaults
    "spa_r09", "por_blj", "fra_lsg", "deu_l12", "ita_riv", "rus_syn",
    "cmn_cu1", "cmn_cuv", "kor_old", "jpn_kou", "ind_tsi", "tgl_ulb", "swh_ulb",
]

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Resources", "Bible")


def clean(text: str) -> str:
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\s+", " ", text).strip()


def fragment_text(frag) -> str:
    if isinstance(frag, str):
        return frag
    if isinstance(frag, dict) and isinstance(frag.get("text"), str):
        return frag["text"]  # e.g. words-of-Jesus spans
    return ""  # footnote markers, line breaks, etc.


def convert(tid: str) -> dict:
    url = f"https://bible.helloao.org/api/{tid}/complete.json"
    with urllib.request.urlopen(url, timeout=120) as r:
        data = json.load(r)
    books, names = {}, {}
    for book in data["books"]:
        bid = book["id"]
        names[bid] = book.get("commonName") or book.get("name") or bid
        chapters = {}
        for ch in book["chapters"]:
            c = ch["chapter"]
            verses = {}
            for item in c["content"]:
                if item.get("type") != "verse":
                    continue
                text = clean(" ".join(fragment_text(f) for f in item.get("content", [])))
                if text:
                    verses[str(item["number"])] = text
            if verses:
                chapters[str(c["number"])] = verses
        if chapters:
            books[bid] = chapters
    return {"translation": tid, "bookNames": names, "books": books}


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for tid in sys.argv[1:] or IDS:
        out = convert(tid)
        path = os.path.join(OUT_DIR, f"bible-{tid}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        nv = sum(len(v) for ch in out["books"].values() for v in ch.values())
        print(f"{tid}: {len(out['books'])} books, {nv} verses, {os.path.getsize(path)//1024} KB")


if __name__ == "__main__":
    main()
