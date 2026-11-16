#!/usr/bin/env python3
"""Importiert Kurzfakten zu Siedlungen und ihre Bauwerke aus der Wiki Aventurica.

Quelle: MediaWiki-API des Wiki Aventurica (CC BY-SA), wie das Ortsverzeichnis
(`tool/import_wiki_orte.py`, dessen Abruf- und Lesefunktionen hier wieder
verwendet werden). Übernommen werden nur Infobox-Kurzfakten, keine
Beschreibungstexte:

- je Siedlung (`Infobox Siedlung`): Einwohnerzahl, Oberhaupt,
  Herrschaftsform, Verkehrswege;
- je Bauwerk (`Infobox Bauwerk`): Name, Art (Tempel, Burg, Akademie …),
  Siedlung aus `Standort`, Zugehörigkeit (etwa die Kirche).

Aufruf (aus dem Projektstamm):

    python tool/import_wiki_ortsfakten.py            # schreibt ortsfakten.json
    python tool/import_wiki_ortsfakten.py --dry-run  # nur zählen
    python tool/import_wiki_ortsfakten.py --limit 40 # Stichprobe je Vorlage

Ziel: `assets/catalogs/house_rules_v1/ortsfakten.json`, Schlüssel ist der
Wiki-Seitenname der Siedlung (wie `seite` bzw. `name` in `orte.json`).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from import_wiki_orte import (  # noqa: E402
    BATCH,
    anzeigename,
    bereinige,
    erster_eintrag,
    infobox_parameter,
    seiten_mit_vorlage,
    wikitext,
)

ZIEL = Path("assets/catalogs/house_rules_v1/ortsfakten.json")

# Vorlagen, die nur einen Namen umschließen ({{Pol|Garetien}}, {{Reg|…}}).
_NAMENSVORLAGEN = re.compile(
    r"\{\{\s*(?:Pol|Reg|Reichsstadt|Org|Rel|Bauwerk)\s*\|([^|{}]*)(?:\|[^{}]*)?\}\}",
    re.I,
)
_LINK = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]")


def vorbereite(wert: str) -> str:
    """Ersetzt Namensvorlagen durch ihren Namen; danach greift `bereinige`."""
    return _NAMENSVORLAGEN.sub(lambda m: m.group(1).strip(), wert)


def kurz(wert: str, grenze: int) -> str:
    """Bereinigter Text, höchstens [grenze] Zeichen (sonst leer)."""
    text = bereinige(vorbereite(wert))
    text = re.sub(r"\(\s*\)", "", text).strip(" ,;:")
    return text if 0 < len(text) <= grenze else ""


def einwohner(wert: str) -> tuple[int | None, str]:
    """Hauptzahl und Anzeigetext der Einwohnerzahl.

    Die Hauptzahl ist die erste Zahl (Tausenderpunkte und Leerzeichen
    erlaubt), der Text der bereinigte Wert, etwa „170000 (sowie 1000 Zwerge
    …; 1040 BF)“.
    """
    text = kurz(wert, 200)
    if not text:
        return None, ""
    treffer = re.search(r"\d[\d.\s ]*\d|\d", text)
    zahl = None
    if treffer:
        ziffern = re.sub(r"[.\s ]", "", treffer.group(0))
        if ziffern.isdigit():
            zahl = int(ziffern)
    return zahl, text


def verkehrswege(wert: str) -> list[str]:
    """Die Verkehrswege als Namensliste (Links bzw. durch Komma getrennt)."""
    namen = [bereinige(vorbereite(teil)) for teil in re.split(r",|;|<br\s*/?>|\bund\b", vorbereite(wert))]
    ergebnis: list[str] = []
    for name in namen:
        name = re.sub(r"\s*\(.*$", "", name).strip(" .")
        if 1 < len(name) <= 50 and name not in ergebnis:
            ergebnis.append(name)
    return ergebnis[:8]


def erste_seite(wert: str) -> str:
    """Ziel des ersten Wiki-Links in [wert] (Seitenname), sonst leer."""
    treffer = _LINK.search(vorbereite(wert))
    if not treffer:
        return ""
    ziel = treffer.group(1).strip().replace("_", " ")
    return ziel[:1].upper() + ziel[1:]


def siedlungsfakten(p: dict[str, str]) -> dict:
    fakten: dict = {}
    zahl, text = einwohner(p.get("Einwohnerzahl", ""))
    if zahl is not None:
        fakten["einwohner"] = zahl
    if text:
        fakten["einwohnerText"] = text
    for schluessel, param, grenze in (
        ("oberhaupt", "Oberhaupt", 160),
        ("herrschaftsform", "Herrschaftsform", 60),
    ):
        wert = kurz(p.get(param, ""), grenze)
        if wert:
            fakten[schluessel] = wert
    wege = verkehrswege(p.get("Verkehrswege", ""))
    if wege:
        fakten["verkehrswege"] = wege
    return fakten


def bauwerk(seite: str, p: dict[str, str], siedlungen: set[str]) -> dict | None:
    ort = erste_seite(p.get("Standort", ""))
    if ort not in siedlungen:
        return None
    eintrag = {"name": anzeigename(seite), "ort": ort}
    if eintrag["name"] != seite:
        eintrag["seite"] = seite
    art = erster_eintrag(vorbereite(p.get("Art", "")))
    if art and len(art) <= 40:
        eintrag["art"] = art
    zugehoerigkeit = kurz(p.get("Zugehörigkeit", ""), 80)
    if zugehoerigkeit:
        eintrag["zugehoerigkeit"] = zugehoerigkeit
    return eintrag


def lies(vorlage: str, limit: int | None):
    titel = seiten_mit_vorlage(vorlage, limit)
    print(f"{vorlage}: {len(titel)} Seiten", file=sys.stderr)
    for i in range(0, len(titel), BATCH):
        for seite, text in wikitext(titel[i : i + BATCH]).items():
            if re.match(r"\s*#(redirect|weiterleitung)", text, re.I):
                continue
            yield seite, infobox_parameter(text, vorlage)
        print(f"  {min(i + BATCH, len(titel))}/{len(titel)}", file=sys.stderr)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()

    siedlungen: dict[str, dict] = {}
    for seite, p in lies("Infobox Siedlung", args.limit):
        siedlungen[seite] = siedlungsfakten(p)

    bauwerke: list[dict] = []
    for seite, p in lies("Infobox Bauwerk", args.limit):
        eintrag = bauwerk(seite, p, set(siedlungen))
        if eintrag is not None:
            bauwerke.append(eintrag)
    bauwerke.sort(key=lambda b: (b["ort"].casefold(), b["name"].casefold()))

    katalog = {
        "quelle": "Wiki Aventurica (https://de.wiki-aventurica.de)",
        "lizenz": "CC BY-SA, https://de.wiki-aventurica.de/wiki/Wiki_Aventurica:Lizenzbestimmungen",
        "stand": date.today().isoformat(),
        "siedlungen": {
            seite: fakten
            for seite, fakten in sorted(siedlungen.items(), key=lambda e: e[0].casefold())
            if fakten
        },
        "bauwerke": bauwerke,
    }
    arten: dict[str, int] = {}
    for b in bauwerke:
        arten[b.get("art", "?")] = arten.get(b.get("art", "?"), 0) + 1
    print(
        f"{len(katalog['siedlungen'])} Siedlungen mit Fakten, {len(bauwerke)} Bauwerke; "
        f"häufigste Arten: {sorted(arten.items(), key=lambda e: -e[1])[:12]}",
        file=sys.stderr,
    )
    if args.dry_run:
        print(json.dumps(katalog, ensure_ascii=False, indent=1)[:4000])
        return 0
    ZIEL.write_text(json.dumps(katalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"geschrieben: {ZIEL}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
