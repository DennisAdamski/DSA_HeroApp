#!/usr/bin/env python3
"""
Prueft assets/catalogs/house_rules_v1/kurzregeln.json auf Redaktionsregeln.

Verwendung:
    python tool/check_kurzregeln.py                      # Entwurf (Klartext erlaubt)
    python tool/check_kurzregeln.py --require-encrypted  # vor dem Commit

Geprueft wird (gleiche Regeln wie KurzregelDef.probleme in der App):
- id und titel vorhanden, ids eindeutig, thema bekannt,
- Quellenpflicht: mindestens ein Beleg, jeder Beleg mit Buch und Seite
  (z. B. "Wege des Schwerts, S. 112"),
- hausregel_text nur mit hausregel_quelle,
- kurztext vorhanden und eine Kurzfassung (Obergrenze MAX_KURZTEXT Zeichen),
- mit --require-encrypted: kurztext, hinweise und hausregel_text liegen
  als enc:3:-Wert vor (CLAUDE.md Regel 13).

Rueckgabewert 0 = ok, 1 = Befunde. Das Passwort wird nie gelesen.
"""

import argparse
import json
import re
import sys
from pathlib import Path

CATALOG = (
    Path(__file__).resolve().parent.parent
    / 'assets' / 'catalogs' / 'house_rules_v1' / 'kurzregeln.json'
)

# Spiegel von kurzregelThemen in lib/catalog/kurzregel_def.dart.
THEMEN = {
    'kampf', 'zustaende', 'wunden', 'proben', 'fernkampf',
    'reiten', 'umgebung', 'heilung', 'magie',
}
BELEG = re.compile(r'\S.*\bS\.\s?\d+')
MAX_KURZTEXT = 700
ENC_V3 = 'enc:3:'


def pruefe(eintraege: list, require_encrypted: bool) -> list[str]:
    """Liefert eine Liste lesbarer Befunde (leer = alles in Ordnung)."""
    befunde: list[str] = []
    gesehen: set[str] = set()
    for nr, e in enumerate(eintraege, start=1):
        if not isinstance(e, dict):
            befunde.append(f'#{nr}: kein Objekt')
            continue
        kennung = e.get('id') or f'#{nr}'

        def fehler(text: str) -> None:
            befunde.append(f'{kennung}: {text}')

        if not e.get('id'):
            fehler('id fehlt')
        elif e['id'] in gesehen:
            fehler('id doppelt')
        gesehen.add(e.get('id', ''))
        if not str(e.get('titel', '')).strip():
            fehler('titel fehlt')
        if e.get('thema') not in THEMEN:
            fehler(f"thema unbekannt: {e.get('thema')!r}")
        quellen = e.get('quellen') or []
        if not quellen:
            fehler('quellen fehlen (Quellenpflicht)')
        for beleg in quellen:
            if not BELEG.search(str(beleg)):
                fehler(f'quelle ohne Seitenangabe: {beleg!r}')
        text = e.get('kurztext')
        if not text:
            fehler('kurztext fehlt')
        elif not str(text).startswith(ENC_V3) and len(text) > MAX_KURZTEXT:
            fehler(f'kurztext laenger als {MAX_KURZTEXT} Zeichen (Kurzfassung!)')
        if e.get('hausregel_text') and not str(e.get('hausregel_quelle', '')).strip():
            fehler('hausregel_text ohne hausregel_quelle')
        if require_encrypted:
            for feld in ('kurztext', 'hinweise', 'hausregel_text'):
                wert = e.get(feld)
                leer = wert in (None, '', [])
                if not leer and not (isinstance(wert, str) and wert.startswith(ENC_V3)):
                    fehler(
                        f'{feld} liegt im Klartext '
                        '(tool/encrypt_catalog_fields.py --format v3)'
                    )
    return befunde


def main() -> int:
    parser = argparse.ArgumentParser(description='Prueft kurzregeln.json.')
    parser.add_argument('--require-encrypted', action='store_true')
    parser.add_argument('--file', type=Path, default=CATALOG)
    args = parser.parse_args()
    daten = json.loads(args.file.read_text(encoding='utf-8-sig'))
    if not isinstance(daten, list):
        print('Fehler: kurzregeln.json muss eine Liste sein.', file=sys.stderr)
        return 1
    befunde = pruefe(daten, args.require_encrypted)
    for b in befunde:
        print(f'  {b}')
    print(f'{len(daten)} Eintraege, {len(befunde)} Befunde.')
    return 1 if befunde else 0


if __name__ == '__main__':
    sys.exit(main())
