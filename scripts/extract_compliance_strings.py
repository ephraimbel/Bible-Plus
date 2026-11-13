#!/usr/bin/env python3
"""Merge compiler-extracted release strings without decoding Unicode as escapes."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    'AIConsentView', 'PaywallContainerView', 'StoreKitService', 'ChatView',
    'ChatBubbleView', 'MemorySettingsView', 'SettingsView', 'VoicePickerView',
    'ChapterReaderView', 'BibleTranslationPickerView', 'TranslationLicensePolicy',
    'BibleReaderViewModel', 'ConversationalOnboardingView', 'OnboardingProofStatsView',
    'AIService', 'BibleRepository',
}

def main():
    p = argparse.ArgumentParser()
    p.add_argument('derived_data', type=Path)
    args = p.parse_args()
    catalog_path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(catalog_path.read_text())
    keys = set()
    for path in args.derived_data.rglob('*.stringsdata'):
        if path.stem not in SOURCES:
            continue
        data = json.loads(path.read_text())
        for entry in data.get('tables', {}).get('Localizable', []):
            key = entry['key']
            if key.strip() and any(c.isalpha() for c in key.replace('%lld', '').replace('%@', '')):
                keys.add(key)
    assert keys, 'Build with SWIFT_EMIT_LOC_STRINGS first.'
    added = 0
    for key in sorted(keys):
        if key not in catalog['strings']:
            added += 1
            catalog['strings'][key] = {'extractionState': 'manual'}
        entry = catalog['strings'][key]
        entry.setdefault('localizations', {})['en'] = {'stringUnit': {'state': 'translated', 'value': key}}
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    (ROOT / 'scripts/compliance_strings.json').write_text(json.dumps(sorted(keys), ensure_ascii=False, indent=2) + '\n')
    print(f'{len(keys)} release strings; {added} added to catalog.')

if __name__ == '__main__':
    main()
