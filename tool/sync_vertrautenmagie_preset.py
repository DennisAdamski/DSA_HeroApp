#!/usr/bin/env python3
"""Uebernimmt Wirkung und Technik aus vertrautenmagie_rituale.json ins Preset.

`lib/catalog/vertrautenmagie_preset.dart` spiegelt die JSON-Datei, damit das
Preset ohne Katalog-Ladevorgang als `const` verfuegbar ist. Wirkung und
Technik sind Regelbuchtext (Liber Cantiones Deluxe) und liegen in beiden
Dateien nur als `enc:3:`-Chiffretext vor (Harte Regel 13). Nach
`tool/encrypt_catalog_fields.py --format v3` dieses Skript ausfuehren; der
Abgleich `test/catalog/vertrautenmagie_preset_test.dart` prueft das Ergebnis.

Das Skript liest nur Chiffretext und gibt nie Klartext aus.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
JSON_PATH = PROJECT / 'assets/catalogs/house_rules_v1/vertrautenmagie_rituale.json'
PRESET_PATH = PROJECT / 'lib/catalog/vertrautenmagie_preset.dart'
FIELDS = ('wirkung', 'technik')

# Ein oder mehrere aneinandergereihte Dart-Stringliterale in einfachen
# Anfuehrungszeichen, abgeschlossen mit Komma.
_LITERALS = r"(?:'(?:[^'\\]|\\.)*'\s*)+,"


def main() -> int:
    data = json.loads(JSON_PATH.read_text(encoding='utf-8-sig'))
    preset = PRESET_PATH.read_text(encoding='utf-8')
    for ritual in data['rituals']:
        name = ritual['name']
        start = preset.find(f"name: '{name}',")
        if start < 0:
            print(f'Fehler: Ritual {name!r} fehlt im Preset.', file=sys.stderr)
            return 1
        end = preset.find('HeroRitualEntry(', start)
        end = len(preset) if end < 0 else end
        block = preset[start:end]
        for field in FIELDS:
            value = ritual.get(field, '')
            if value and not value.startswith('enc:3:'):
                print(
                    f'Fehler: {name}.{field} ist nicht verschluesselt; zuerst '
                    'tool/encrypt_catalog_fields.py --format v3 ausfuehren.',
                    file=sys.stderr,
                )
                return 1
            pattern = re.compile(rf'({field}:)\s*{_LITERALS}')
            if not pattern.search(block):
                print(f'Fehler: {name}.{field} fehlt im Preset.', file=sys.stderr)
                return 1
            block = pattern.sub(lambda m: f"{m.group(1)} '{value}',", block, count=1)
        preset = preset[:start] + block + preset[end:]
    PRESET_PATH.write_text(preset, encoding='utf-8')
    print(f'{len(data["rituals"])} Rituale abgeglichen.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
