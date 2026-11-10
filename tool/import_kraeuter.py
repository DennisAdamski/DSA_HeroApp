#!/usr/bin/env python3
"""Erzeugt assets/catalogs/house_rules_v1/kraeuter.json.

Quelle: Wege des Entdeckers (WdE) S. 114-118, Abschnitt "Kraeuter und ihre
Verbreitung" (Landschaftstabellen mit "Besonderen Heilkraeutern" und
Bestimmungswerten); Erntezeit und Grundmenge aus dem Herbarium Aventuricum der
Zoo Botanica Aventurica (ZBA, S. 228-277). Uebernommen sind nur
Kurzfakten (Name, Bestimmung, Haeufigkeit je Landschaft, Gebietshinweis und die
einzeilige Wirkung aus der Tabelle), keine Beschreibungstexte; deshalb ist
nichts verschluesselt (siehe `tool/encrypt_catalog_fields.py`, Harte Regel 13).

Die Daten stehen hier als kuratierte Tabelle, weil das Regelbuch keine
maschinenlesbare Fassung hat. Jede Aenderung an der Tabelle ist gegen die
Buchseite zu pruefen (`dsa-rules`-MCP, Chunks 6310-6313).

Aufruf:  python tool/import_kraeuter.py
"""

from __future__ import annotations

import json
from pathlib import Path

ZIEL = (
    Path(__file__).resolve().parent.parent
    / "assets"
    / "catalogs"
    / "house_rules_v1"
    / "kraeuter.json"
)

# Name -> (Bestimmung, Wirkung kurz, Gebiet laut Tabelle, Bestimmungshinweis)
KRAEUTER: dict[str, tuple[int, str, str, str]] = {
    "Arganstrauch": (4, "fördert Heilung", "", ""),
    "Alraune": (9, "Grundlage für Elixiere", "", ""),
    "Atan-Kiefer": (6, "Grundlage für fiebersenkendes Mittel", "Ausläufer des Ehernen Schwerts", ""),
    "Atmon": (5, "Aufputschmittel", "", ""),
    "Axorda": (4, "Grundlage für ein Mittel gegen Zorgan-Pocken", "", ""),
    "Belmart": (6, "Gegengift, stoppt Krankheiten", "", ""),
    "Bleichmohn": (5, "Schmerzmittel", "", ""),
    "Blutblatt": (4, "zeigt Magie an", "", ""),
    "Boronie": (-2, "erleichtert Boron-Liturgien", "nur im Regenwald", ""),
    "Carlog": (5, "verleiht Dämmerungssicht", "Gewässer an der Westküste, um Vallusa und am Yslisee", ""),
    "Chonchinis": (5, "Heilmittel bei Brand- und Ätzwunden", "Garetien und weiter südlich", ""),
    "Donf": (6, "fiebersenkend", "", ""),
    "Egelschreck": (6, "Grundlage für Wundheilung und Parasitenabwehr", "", ""),
    "Finage": (5, "reduziert Eigenschaftsabzüge, Grundlage für Heilmittel", "südlich der Linie Neetha–Thalusa", ""),
    "Gulmond": (6, "erhöht Konstitution", "nördlich der Linie Nostria–Vallusa", ""),
    "Hiradwurz": (8, "hilft gegen Schlangengift", "Amhalassih, Mhanadistan, Gorien, Aranien", "+8 in der Trockenzeit, +5 in der Regenzeit"),
    "Horusche": (7, "verleiht Stärke", "", ""),
    "Joruga": (7, "Grundlage für Krankheitsbekämpfung", "Andergast, Nostria, Albernia, Nordmarken", ""),
    "Kajubo": (4, "ermöglicht Überleben ohne Atemluft", "Altoum, Souram, Nikkali", ""),
    "Khômknolle": (5, "enthält Wasser", "Gorien und Mhanadistan", "+5, ohne Blätter +12"),
    "Klippenzahn": (8, "beschleunigt Wundheilung", "Hochland von Orkland, Thorwal, Gjalsker Öden", ""),
    "Kukura": (10, "erhöht Ausdauer", "westliches Regengebirge", ""),
    "Lulanie": (5, "Beruhigungsmittel", "Mittelaventurien", ""),
    "Menchalkaktus": (4, "hilft gegen viele Gifte", "Randgebiete der Khôm, wüstenähnliche Gebiete in Gorien", ""),
    "Mibelrohr": (10, "Grundlage für Aufputschmittel", "See- und Flussufer der Westküste von Salza bis Mengbilla", ""),
    "Mirbelstein": (8, "Grundlage für ein Mittel gegen Ungeziefer und Elfen", "Garetien, Darpatien, Warunk, Beilunk", ""),
    "Neckerkraut": (4, "gegen Kerkersieche", "Westküste", ""),
    "Nothilf": (6, "heilt Brandwunden", "Salamandersteine und Umgebung", ""),
    "Olginwurz": (10, "Gegengift", "Raschtulswall", ""),
    "Quinya": (6, "erhöht Körperkraft", "südlich des Harodrôl", ""),
    "Rahjalieb": (5, "empfängnisverhütend", "nicht weiter nördlich als Festum", ""),
    "Rauschgurke": (3, "macht stärker und dümmer", "Umgebung von Khunchom", ""),
    "Rote Pfeilblüte": (7, "spendet Lebensenergie", "Südaventurien", ""),
    "Roter Drachenschlund": (10, "verhindert Ausbruch von Lykanthropie", "Waldränder, Gehölze, Flussufer in Nordaventurien", "zur Blütezeit +3"),
    "Satuariensbusch": (-2, "schützt vor Wundfieber", "südlicher als die Gelbe Sichel", ""),
    "Schlangenzünglein": (3, "zeigt Magie an", "Flussläufe auf Maraskan und am Golf von Perricum", ""),
    "Talaschin": (5, "verhindert Körpergeruch", "", ""),
    "Tarnele": (4, "schmerzlindernd und heilungsfördernd", "zwischen Mengbilla und Gerasim", ""),
    "Thonnys": (12, "erlaubt Astrale Meditation", "nördlich der Linie Thorwal–Festum", "während der Blüte +5"),
    "Tigermohn": (10, "Beruhigungsmittel", "Nord- und Mittelaventurien, Liebliches Feld, Aranien", ""),
    "Traschbart": (6, "fiebersenkend", "Steineichenwald, Finsterkamm, Koschberge, Eisenwald", ""),
    "Ulmenwürger": (2, "verbessert Regeneration, verhindert Wundfieber", "nördlich der Linie Havena–Perricum", ""),
    "Vierblättrige Einbeere": (5, "stoppt Blutungen und gibt Lebensenergie", "nördlich des Yaquir", ""),
    "Wirselkraut": (5, "stoppt Blutungen und gibt Lebensenergie", "", ""),
    "Yaganstrauch": (6, "erhöht Ausdauer", "Aranische Küste, Maraskan", ""),
    "Zunderschwamm": (4, "ermöglicht Feuermachen", "südlich des Blauen Sees", ""),
    "Zwölfblatt": (5, "schützt vor Ansteckung", "nicht weiter nördlich als Riva", ""),
}

MONATE = [
    "praios", "rondra", "efferd", "travia", "boron", "hesinde",
    "firun", "tsa", "phex", "peraine", "ingerimm", "rahja", "namenlose_tage",
]
WINTER = {"firun", "tsa", "phex"}


def bereich(von: str, bis: str) -> list[str]:
    """Monate von..bis in Kalenderfolge, über den Jahreswechsel inkl. Namenlose Tage."""
    a, b = MONATE.index(von), MONATE.index(bis)
    if a <= b:
        return MONATE[a : b + 1]
    return MONATE[a:] + MONATE[: b + 1]


def ausser(*monate: str) -> list[str]:
    return [m for m in MONATE if m not in monate]


GJ: list[str] = []  # ganzjährig: das Feld erntemonate entfällt

# Name -> (Erntezeit als Text laut Zoo Botanica, Erntemonate; leer = ganzjährig)
# Bei zusammengesetzten Angaben (Pflanzenteile, Gebiete) steht die Vereinigung.
ERNTE: dict[str, tuple[str, list[str]]] = {
    "Alraune": ("ganzjährig", GJ),
    "Arganstrauch": ("ganzjährig", GJ),
    "Atan-Kiefer": ("ganzjährig", GJ),
    "Atmon": ("Peraine", ["peraine"]),
    "Axorda": ("ganzjährig", GJ),
    "Belmart": ("Peraine bis Boron", bereich("peraine", "boron")),
    "Bleichmohn": ("Rondra", ["rondra"]),
    "Blutblatt": ("ganzjährig", GJ),
    "Boronie": ("im Süden jederzeit, in Mittelaventurien zwischen Tsa und Boron", GJ),
    "Carlog": ("Peraine oder Efferd", ["peraine", "efferd"]),
    "Chonchinis": ("Tsa bis Boron, vor allem im Efferd", bereich("tsa", "boron")),
    "Donf": ("ganzjährig", GJ),
    "Egelschreck": ("Spätsommer", ["efferd"]),
    "Finage": ("Triebe im Peraine, Bast in Boron bis Firun", ["boron", "hesinde", "firun", "peraine"]),
    "Gulmond": ("Frühling bis Herbst", ausser(*WINTER)),
    "Hiradwurz": ("ganzjährig", GJ),
    "Horusche": ("ganzjährig", GJ),
    "Joruga": ("Rahja bis Boron", bereich("rahja", "boron")),
    "Kajubo": ("Phex bis Travia", bereich("phex", "travia")),
    "Khômknolle": ("ganzjährig", GJ),
    "Klippenzahn": ("Peraine bis Rondra", bereich("peraine", "rondra")),
    "Kukura": ("ganzjährig", GJ),
    "Lulanie": ("Rahja bis Rondra", bereich("rahja", "rondra")),
    "Menchalkaktus": ("ganzjährig", GJ),
    "Mibelrohr": ("im Norden Ingerimm bis Efferd, im Süden stets außer Firun", ausser("firun")),
    "Mirbelstein": ("Peraine bis Boron", bereich("peraine", "boron")),
    "Neckerkraut": ("ganzjährig", GJ),
    "Nothilf": ("Blüten im Praios, Blätter im Peraine", ["praios", "peraine"]),
    "Olginwurz": ("ganzjährig", GJ),
    "Quinya": ("Ingerimm bis Travia", bereich("ingerimm", "travia")),
    "Rahjalieb": ("Phex bis Firun", bereich("phex", "firun")),
    "Rauschgurke": ("Tsa bis Boron", bereich("tsa", "boron")),
    "Rote Pfeilblüte": ("Peraine bis Rahja", bereich("peraine", "rahja")),
    "Roter Drachenschlund": ("ganzjährig (Blüte im Ingerimm und Rahja)", GJ),
    "Satuariensbusch": (
        "Blätter Ingerimm bis Praios, Blüten Ingerimm bis Rahja, Frucht Efferd bis Travia, Saft Phex bis Praios",
        sorted(
            set(bereich("ingerimm", "praios"))
            | set(bereich("efferd", "travia"))
            | set(bereich("phex", "praios")),
            key=MONATE.index,
        ),
    ),
    "Schlangenzünglein": ("ganzjährig", GJ),
    "Talaschin": ("ganzjährig", GJ),
    "Tarnele": ("Ingerimm bis Travia", bereich("ingerimm", "travia")),
    "Thonnys": ("Peraine bis Travia", bereich("peraine", "travia")),
    "Tigermohn": ("Travia", ["travia"]),
    "Traschbart": ("ganzjährig", GJ),
    "Ulmenwürger": ("Efferd bis Travia", bereich("efferd", "travia")),
    "Vierblättrige Einbeere": ("Phex bis Hesinde", bereich("phex", "hesinde")),
    "Wirselkraut": ("jede Zeit außer Winter", ausser(*WINTER)),
    "Yaganstrauch": ("Boron", ["boron"]),
    "Zunderschwamm": ("ganzjährig", GJ),
    "Zwölfblatt": ("Hesinde bis Praios", bereich("hesinde", "praios")),
}

# Name -> Grundmenge laut Zoo Botanica (Menge nutzbarer Pflanzenteile)
GRUNDMENGE: dict[str, str] = {
    "Alraune": "eine Pflanze",
    "Arganstrauch": "eine Wurzel",
    "Atan-Kiefer": "W20 Stein Rinde",
    "Atmon": "W6 Büschel der ganzen Pflanze",
    "Axorda": "ein Baum",
    "Belmart": "4W20 Blätter",
    "Bleichmohn": "W6 geschlossene Samenkapseln",
    "Blutblatt": "W20+2 Zweige pro 10 AsP der Quelle",
    "Boronie": "5 Blüten",
    "Carlog": "W6 Blüten mit je einem Stempel",
    "Chonchinis": "W20 Blätter",
    "Donf": "ein Stängel",
    "Egelschreck": "2W20 Blätter",
    "Finage": "ein Baum mit W20 Trieben",
    "Gulmond": "2W6 Blätter",
    "Hiradwurz": "eine Wurzel",
    "Horusche": "W6 erntereife Schoten pro Pflanze, W3 Kerne pro Schote",
    "Joruga": "eine Wurzel",
    "Kajubo": "2W6 Knospen",
    "Khômknolle": "eine Wurzel mit bis zu W6 Maß klarem Wasser",
    "Klippenzahn": "2W6 Stängel",
    "Kukura": "1W3 × 20 Blätter",
    "Lulanie": "eine Blüte",
    "Menchalkaktus": "ein Kaktus mit W6 halben Maß Menchalsaft",
    "Mibelrohr": "2W6 Kolben pro Fundort",
    "Mirbelstein": "eine Wurzelknolle",
    "Neckerkraut": "1W20+5 Blätter",
    "Nothilf": "W20+2 Blüten, 2W20+10 Blätter",
    "Olginwurz": "W3 Moosballen",
    "Quinya": "W3+2 Beeren",
    "Rahjalieb": "2W6 Blätter",
    "Rauschgurke": "3W6 reife Rauschgurken pro Baum",
    "Rote Pfeilblüte": "W6 Blüten",
    "Roter Drachenschlund": "W6 Blätter",
    "Satuariensbusch": "4W20 Blätter, W20 Blüten, W20 Früchte, W3 Flux Saft",
    "Schlangenzünglein": "Saft einer Pflanze",
    "Talaschin": "W6 Flechten",
    "Tarnele": "ganze Pflanze",
    "Thonnys": "W6+4 Blätter",
    "Tigermohn": "eine geschlossene Samenkapsel",
    "Traschbart": "W6 Flechten",
    "Ulmenwürger": "W20 Blüten",
    "Vierblättrige Einbeere": "ein Strauch mit 1W6 Beeren",
    "Wirselkraut": "W6+4 Blätter",
    "Yaganstrauch": "W6 Nüsse",
    "Zunderschwamm": "W6 Pilze",
    "Zwölfblatt": "12 Stängel pro Pflanze",
}

H = "haeufig"
SH = "sehrHaeufig"
G = "gelegentlich"
S = "selten"
SS = "sehrSelten"

# Landschaft -> Liste (Haeufigkeit, Kraut, Hinweis dieser Landschaft)
LANDSCHAFTEN: dict[str, list[tuple[str, str, str]]] = {
    "dichterWald": [
        (H, "Mirbelstein", ""), (H, "Traschbart", ""), (H, "Vierblättrige Einbeere", ""), (H, "Zunderschwamm", ""),
        (G, "Belmart", ""), (G, "Gulmond", ""), (G, "Quinya", ""), (G, "Rahjalieb", ""), (G, "Tarnele", ""),
        (G, "Ulmenwürger", ""), (G, "Yaganstrauch", ""), (G, "Zwölfblatt", ""),
        (S, "Alraune", ""), (S, "Blutblatt", ""), (S, "Egelschreck", "nur am Waldrand"), (S, "Finage", ""),
        (S, "Joruga", ""), (S, "Lulanie", ""), (S, "Nothilf", ""), (S, "Olginwurz", ""),
        (S, "Rote Pfeilblüte", ""), (S, "Satuariensbusch", "Waldränder"), (S, "Tigermohn", "Waldrand"),
        (SS, "Boronie", ""), (SS, "Roter Drachenschlund", ""), (SS, "Thonnys", ""),
    ],
    "lichterWald": [
        (H, "Mirbelstein", ""), (H, "Traschbart", ""), (H, "Vierblättrige Einbeere", ""), (H, "Zunderschwamm", ""),
        (G, "Belmart", ""), (G, "Egelschreck", "nur am Waldrand"), (G, "Gulmond", ""), (G, "Joruga", ""),
        (G, "Mibelrohr", ""), (G, "Quinya", ""), (G, "Rahjalieb", ""), (G, "Satuariensbusch", ""),
        (G, "Tarnele", ""), (G, "Ulmenwürger", ""), (G, "Yaganstrauch", ""), (G, "Zwölfblatt", ""),
        (S, "Alraune", ""), (S, "Blutblatt", ""), (S, "Chonchinis", ""),
        # Das Buch führt Egelschreck hier zusätzlich unter "selten" (Doppelnennung).
        (S, "Egelschreck", "nur am Waldrand (Doppelnennung im Buch)"),
        (S, "Finage", ""), (S, "Lulanie", ""), (S, "Nothilf", ""), (S, "Olginwurz", ""),
        (S, "Rauschgurke", ""), (S, "Tigermohn", "Waldrand"),
        (SS, "Carlog", ""), (SS, "Rote Pfeilblüte", ""), (SS, "Roter Drachenschlund", ""), (SS, "Thonnys", ""),
    ],
    "dschungel": [
        (H, "Quinya", ""), (H, "Rahjalieb", ""),
        (G, "Arganstrauch", ""), (G, "Rote Pfeilblüte", "nur in Küstennähe"), (G, "Zunderschwamm", ""),
        (S, "Blutblatt", ""), (S, "Boronie", ""), (S, "Donf", "nur an Seeufern"), (S, "Finage", ""),
        (S, "Kajubo", "nur am Waldrand auf Altoum, Souram und Nikkali"), (S, "Kukura", ""),
        (SS, "Donf", "nur an Flussufern"),
    ],
    "maraskanDschungel": [
        (H, "Rahjalieb", ""),
        (G, "Rauschgurke", ""), (G, "Yaganstrauch", ""), (G, "Zunderschwamm", ""),
        (S, "Blutblatt", ""), (S, "Donf", "nur an Seeufern"), (S, "Horusche", "nur in feuchten Waldgebieten"),
        (S, "Schlangenzünglein", "nur Flussläufe"),
        (SS, "Arganstrauch", ""), (SS, "Axorda", ""), (SS, "Donf", "nur an Flussufern"),
    ],
    "suempfeNord": [
        (H, "Egelschreck", "im Norden nur bis zur Höhe von Lowangen"),
        (G, "Carlog", "nur an der Westküste, um Vallusa und am Yslisee"), (G, "Donf", "im Norden nur bis Gerasim"),
        (G, "Rahjalieb", ""), (G, "Tarnele", ""),
        (S, "Blutblatt", ""), (S, "Ulmenwürger", "nur an Waldrändern und in Gehölzen"),
        (S, "Zunderschwamm", "nur an Waldrändern und in Gehölzen südlich des Blauen Sees"),
        (SS, "Alraune", ""), (SS, "Belmart", ""), (SS, "Lulanie", "nur an Waldrändern und in Gehölzen Mittelaventuriens"),
        (SS, "Mibelrohr", "nur an der Westküste von Salza bis Mengbilla"), (SS, "Neckerkraut", "nur an der Westküste"),
        (SS, "Roter Drachenschlund", ""), (SS, "Vierblättrige Einbeere", ""),
    ],
    "suempfeSued": [
        (H, "Egelschreck", "im Süden nur bis zu den Echsensümpfen"),
        (G, "Carlog", "nur an der Westküste"), (G, "Donf", ""), (G, "Rahjalieb", ""),
        (G, "Rote Pfeilblüte", "nur in Küstennähe"), (G, "Tarnele", ""), (G, "Traschbart", ""),
        (S, "Arganstrauch", ""), (S, "Blutblatt", ""), (S, "Schlangenzünglein", "nur auf Maraskan und am Golf von Perricum"),
        (SS, "Atmon", "nur in Wüstenrandgebieten"), (SS, "Boronie", ""),
        (SS, "Kajubo", "nur an den Küsten von Altoum, Souram und Nikkali"),
        (SS, "Mibelrohr", "nur an der Westküste von Salza bis Mengbilla"),
    ],
    "tundra": [
        (H, "Gulmond", ""), (H, "Wirselkraut", ""),
        (G, "Vierblättrige Einbeere", ""),
        (S, "Blutblatt", ""), (S, "Ulmenwürger", "nur an Waldrändern und in Gehölzen"),
        (S, "Zunderschwamm", "nur an Waldrändern und in Gehölzen südlich des Blauen Sees"),
        (SS, "Alraune", ""), (SS, "Belmart", ""), (SS, "Roter Drachenschlund", ""), (SS, "Thonnys", ""),
    ],
    "graslandHeide": [
        (H, "Gulmond", ""), (H, "Tarnele", "nur in Flussauen und auf Wiesen zwischen Mengbilla und Gerasim"),
        (G, "Chonchinis", ""), (G, "Egelschreck", "nur auf feuchten Wiesen und in Flussauen"),
        (G, "Klippenzahn", ""), (G, "Mibelrohr", ""), (G, "Mirbelstein", ""),
        (G, "Neckerkraut", "nur am Strand der Westküste, selten auch auf Wiesen in Küstennähe"),
        (G, "Rahjalieb", ""), (G, "Vierblättrige Einbeere", ""), (G, "Wirselkraut", ""),
        (S, "Blutblatt", ""), (S, "Donf", "nur an Seeufern"), (S, "Joruga", ""), (S, "Olginwurz", ""),
        (S, "Satuariensbusch", "nur Waldränder und Gehölze"), (S, "Tigermohn", "Wiesen und Flussauen"),
        (S, "Ulmenwürger", "nur an Waldrändern und in Gehölzen"),
        (S, "Zunderschwamm", "nur an Waldrändern und in Gehölzen südlich des Blauen Sees"),
        (SS, "Alraune", ""), (SS, "Belmart", ""), (SS, "Boronie", ""), (SS, "Carlog", ""),
        (SS, "Donf", "nur in Flussauen"), (SS, "Lulanie", "nur an Waldrändern und in Gehölzen Mittelaventuriens"),
        (SS, "Roter Drachenschlund", ""), (SS, "Thonnys", ""),
    ],
    "savanneSteppe": [
        (H, "Wirselkraut", ""),
        (G, "Atmon", "nur in Wüstenrandgebieten"), (G, "Chonchinis", ""), (G, "Mibelrohr", ""), (G, "Rahjalieb", ""),
        (S, "Blutblatt", ""), (S, "Donf", "nur an Seeufern"), (S, "Hiradwurz", ""), (S, "Khômknolle", ""),
        (S, "Olginwurz", ""), (S, "Satuariensbusch", "nur Waldränder und Gehölze"),
        (S, "Schlangenzünglein", "nur an Flussläufen"),
        (S, "Zunderschwamm", "nur an Waldrändern und in Gehölzen"),
        (SS, "Arganstrauch", ""), (SS, "Donf", "nur in Flussauen"), (SS, "Finage", ""), (SS, "Menchalkaktus", ""),
    ],
    "gebirge": [
        (G, "Egelschreck", "nur auf feuchten Wiesen und in Flussauen"), (G, "Gulmond", ""),
        (G, "Klippenzahn", "nur im Orkland, Thorwal und in den Gjalsker Öden"), (G, "Rahjalieb", ""),
        (S, "Atan-Kiefer", ""), (S, "Atmon", "nur im Khoramgebirge"), (S, "Bleichmohn", ""), (S, "Blutblatt", ""),
        (S, "Donf", "nur an Seeufern"), (S, "Mirbelstein", ""), (S, "Olginwurz", ""),
        (S, "Satuariensbusch", "nur Waldränder und Gehölze"), (S, "Ulmenwürger", "nur an Waldrändern und in Gehölzen"),
        (S, "Yaganstrauch", "nur auf Maraskan und an der Aranischen Küste"),
        (S, "Zunderschwamm", "nur an Waldrändern und in Gehölzen"),
        (SS, "Axorda", "nur Maraskankette"), (SS, "Belmart", ""),
        (SS, "Chonchinis", "von Garetien bis zu den Echsensümpfen"), (SS, "Joruga", ""),
        (SS, "Roter Drachenschlund", ""), (SS, "Tarnele", "Hochland zwischen Mengbilla und Gerasim"),
        (SS, "Vierblättrige Einbeere", ""),
    ],
    "hochgebirge": [
        (S, "Atan-Kiefer", "nur im Ehernen Schwert"), (S, "Atmon", "nur im Raschtulswall"), (S, "Blutblatt", ""),
        (S, "Olginwurz", ""),
        (SS, "Bleichmohn", ""), (SS, "Talaschin", ""),
    ],
    "wueste": [
        (SS, "Blutblatt", ""), (SS, "Khômknolle", "nur in der östlichen Khôm"), (SS, "Menchalkaktus", ""),
        (SS, "Talaschin", ""),
    ],
}


def baue() -> dict:
    vorkommen: dict[str, list[dict[str, str]]] = {name: [] for name in KRAEUTER}
    for landschaft, eintraege in LANDSCHAFTEN.items():
        for haeufigkeit, name, hinweis in eintraege:
            if name not in KRAEUTER:
                raise SystemExit(f"Unbekanntes Kraut in {landschaft}: {name}")
            eintrag = {"landschaft": landschaft, "haeufigkeit": haeufigkeit}
            if hinweis:
                eintrag["hinweis"] = hinweis
            vorkommen[name].append(eintrag)
    kraeuter = []
    for name in sorted(KRAEUTER):
        bestimmung, wirkung, gebiet, bestimmung_hinweis = KRAEUTER[name]
        if not vorkommen[name]:
            raise SystemExit(f"Kraut ohne Vorkommen: {name}")
        eintrag: dict = {"name": name, "bestimmung": bestimmung, "wirkung": wirkung}
        if bestimmung_hinweis:
            eintrag["bestimmungHinweis"] = bestimmung_hinweis
        if gebiet:
            eintrag["gebiet"] = gebiet
        if name not in ERNTE or name not in GRUNDMENGE:
            raise SystemExit(f"Ernte oder Grundmenge fehlt: {name}")
        ernte_text, ernte_monate = ERNTE[name]
        eintrag["erntezeit"] = ernte_text
        if ernte_monate:
            eintrag["erntemonate"] = ernte_monate
        eintrag["grundmenge"] = GRUNDMENGE[name]
        eintrag["vorkommen"] = vorkommen[name]
        kraeuter.append(eintrag)
    return {
        "quelle": "Wege des Entdeckers S. 114-118 (Kräuter und ihre Verbreitung); "
        "Erntezeit und Grundmenge: Zoo Botanica Aventurica, Herbarium",
        "stand": "2026-11-11",
        "kraeuter": kraeuter,
    }


def main() -> None:
    daten = baue()
    ZIEL.write_text(
        json.dumps(daten, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    print(f"{len(daten['kraeuter'])} Kräuter nach {ZIEL} geschrieben")


if __name__ == "__main__":
    main()
