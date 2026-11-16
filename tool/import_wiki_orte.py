#!/usr/bin/env python3
"""Importiert Ortsnamen aus der Wiki Aventurica in den Orte-Katalog.

Quelle: MediaWiki-API des Wiki Aventurica (CC BY-SA). Übernommen werden nur
Kurzfakten (Name, Art, Unterart, Region), keine Beschreibungstexte.

Aufruf (aus dem Projektstamm):

    python tool/import_wiki_orte.py            # schreibt assets/catalogs/house_rules_v1/orte.json
    python tool/import_wiki_orte.py --dry-run  # nur zählen, nichts schreiben
    python tool/import_wiki_orte.py --limit 40 # je Vorlage nur die ersten 40 Seiten (Test)

Seiten werden über ihre Infobox-Vorlage gefunden (`list=embeddedin`), nicht
über Kategorien, weil Regionen und Landschaften keine einheitliche Kategorie
haben. Die Anfragen laufen höflich (eigener User-Agent, Pausen, `maxlag`).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

API = "https://de.wiki-aventurica.de/de/api.php"
USER_AGENT = "dsa-heldenverwaltung-katalogimport/1.0 (Orte-Katalog, CC BY-SA)"
ZIEL = Path("assets/catalogs/house_rules_v1/orte.json")

# Infobox-Vorlage -> (Art im Katalog, Parameter für die Unterart)
VORLAGEN: list[tuple[str, str, str | None]] = [
    ("Infobox Siedlung", "siedlung", "Siedlungsart"),
    ("Infobox Region", "region", "Art"),
    ("Infobox Staat", "staat", None),
    ("Infobox Fluss", "fluss", None),
    ("Infobox Straße", "strasse", None),
]

BATCH = 25  # Seiten je Inhaltsabruf
PAUSE = 0.4  # Sekunden zwischen Anfragen


def api(**params: object) -> dict:
    params["format"] = "json"
    params["maxlag"] = 5
    url = API + "?" + urllib.parse.urlencode(params)
    for versuch in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as antwort:
                daten = json.load(antwort)
            if "error" in daten and daten["error"].get("code") == "maxlag":
                time.sleep(5)
                continue
            time.sleep(PAUSE)
            return daten
        except (urllib.error.URLError, TimeoutError):
            time.sleep(2 * (versuch + 1))
    raise SystemExit("API nicht erreichbar: " + url)


def seiten_mit_vorlage(vorlage: str, limit: int | None) -> list[str]:
    titel: list[str] = []
    weiter: dict = {}
    while True:
        d = api(
            action="query",
            list="embeddedin",
            eititle="Vorlage:" + vorlage,
            einamespace=0,
            eilimit=500,
            **weiter,
        )
        titel += [s["title"] for s in d["query"]["embeddedin"]]
        if limit and len(titel) >= limit:
            return titel[:limit]
        if "continue" not in d:
            return titel
        weiter = d["continue"]


def wikitext(titel: list[str]) -> dict[str, str]:
    d = api(
        action="query",
        prop="revisions",
        rvprop="content",
        rvslots="main",
        titles="|".join(titel),
    )
    ergebnis: dict[str, str] = {}
    for seite in d["query"]["pages"].values():
        rev = seite.get("revisions")
        if rev:
            ergebnis[seite["title"]] = rev[0]["slots"]["main"]["*"]
    return ergebnis


def infobox_parameter(text: str, vorlage: str) -> dict[str, str]:
    """Liest die Parameter der ersten `{{vorlage …}}` mit Klammertiefe."""
    start = re.search(r"\{\{\s*" + re.escape(vorlage) + r"\s*(\||\n)", text, re.I)
    if not start:
        return {}
    i = start.end() - 1
    tiefe = 2
    teile: list[str] = []
    aktuell: list[str] = []
    wiki_tiefe = 0
    while i < len(text) and tiefe > 0:
        z = text[i : i + 2]
        if z in ("{{", "[["):
            if z == "{{":
                tiefe += 2
            else:
                wiki_tiefe += 1
            aktuell.append(z)
            i += 2
            continue
        if z in ("}}", "]]"):
            if z == "}}":
                tiefe -= 2
                if tiefe <= 0:
                    break
            else:
                wiki_tiefe -= 1
            aktuell.append(z)
            i += 2
            continue
        if text[i] == "|" and tiefe == 2 and wiki_tiefe == 0:
            teile.append("".join(aktuell))
            aktuell = []
        else:
            aktuell.append(text[i])
        i += 1
    teile.append("".join(aktuell))
    parameter: dict[str, str] = {}
    for teil in teile[1:]:
        if "=" in teil:
            name, wert = teil.split("=", 1)
            parameter[name.strip()] = wert.strip()
    return parameter


def bereinige(wert: str) -> str:
    """Entfernt Wiki-Markup, Vorlagen und Kommentare aus einem Parameterwert."""
    wert = re.sub(r"<!--.*?-->", "", wert, flags=re.S)
    wert = re.sub(r"<ref[^>]*>.*?</ref>|<ref[^>]*/>", "", wert, flags=re.S)
    wert = re.sub(r"\{\{[^{}]*\}\}", "", wert)
    wert = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", wert)
    wert = re.sub(r"<[^>]+>", " ", wert)
    wert = wert.replace("'''", "").replace("''", "")
    return re.sub(r"\s+", " ", wert).strip(" ,;")


def erster_eintrag(wert: str) -> str:
    """Nimmt bei Listen („A, B“ oder Zeilen) nur den ersten Eintrag."""
    wert = bereinige(wert)
    return re.split(r"\s*[,;/]\s*|\s{2,}", wert)[0].strip() if wert else ""


def anzeigename(titel: str) -> str:
    """Entfernt eine Wiki-Klammer wie „Havena (Siedlung)“ zu „Havena“.

    Avesmaps und die Auswahl kennen den Ort unter dem einfachen Namen; die
    Klammer dient im Wiki nur der Unterscheidung von Seiten. Der volle
    Seitenname bleibt als `seite` erhalten, wenn er abweicht.
    """
    kurz = re.sub(r"\s*\([^()]*\)$", "", titel).strip()
    return kurz or titel


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args()

    orte: dict[tuple[str, str], dict] = {}
    for vorlage, art, unterart_param in VORLAGEN:
        titel = seiten_mit_vorlage(vorlage, args.limit)
        print(f"{vorlage}: {len(titel)} Seiten", file=sys.stderr)
        for i in range(0, len(titel), BATCH):
            texte = wikitext(titel[i : i + BATCH])
            for name, text in texte.items():
                if re.match(r"\s*#(redirect|weiterleitung)", text, re.I):
                    continue
                p = infobox_parameter(text, vorlage)
                eintrag: dict[str, str] = {"name": anzeigename(name), "art": art}
                if eintrag["name"] != name:
                    eintrag["seite"] = name
                if unterart_param:
                    unterart = erster_eintrag(p.get(unterart_param, ""))
                    if unterart and len(unterart) <= 40:
                        eintrag["unterart"] = unterart
                region = erster_eintrag(p.get("Region", ""))
                if region and region != name and len(region) <= 60:
                    eintrag["region"] = region
                # Siedlung vor Region vor Staat, falls ein Name mehrfach vorkommt.
                orte.setdefault((eintrag["name"], art), eintrag)
            print(f"  {min(i + BATCH, len(titel))}/{len(titel)}", file=sys.stderr)

    liste = sorted(orte.values(), key=lambda e: e["name"].casefold())
    katalog = {
        "quelle": "Wiki Aventurica (https://de.wiki-aventurica.de)",
        "lizenz": "CC BY-SA, https://de.wiki-aventurica.de/wiki/Wiki_Aventurica:Lizenzbestimmungen",
        "stand": date.today().isoformat(),
        "orte": liste,
    }
    zaehlung: dict[str, int] = {}
    for e in liste:
        zaehlung[e["art"]] = zaehlung.get(e["art"], 0) + 1
    print(f"{len(liste)} Orte: {zaehlung}", file=sys.stderr)
    if args.dry_run:
        return 0
    ZIEL.write_text(
        json.dumps(katalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    print(f"geschrieben: {ZIEL}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
