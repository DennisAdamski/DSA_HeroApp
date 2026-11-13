"""Tests für das Auslesen der Ortsfakten (ohne Netz)."""

from __future__ import annotations

import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import import_wiki_ortsfakten as fakten  # noqa: E402


class EinwohnerTest(unittest.TestCase):
    def test_hauptzahl_und_text(self) -> None:
        zahl, text = fakten.einwohner(
            "170000 <small>(sowie 1000 [[Zwerg]]e, 500 [[Elf]]en; [[1040 BF]])</small>"
        )
        self.assertEqual(zahl, 170000)
        self.assertEqual(text, "170000 (sowie 1000 Zwerge, 500 Elfen; 1040 BF)")

    def test_tausenderpunkte_und_ungefaehr(self) -> None:
        self.assertEqual(fakten.einwohner("ca. 2.500 (1042 BF)")[0], 2500)
        self.assertEqual(fakten.einwohner("")[0], None)
        self.assertEqual(fakten.einwohner("einige Hundert"), (None, "einige Hundert"))


class VerkehrswegeTest(unittest.TestCase):
    def test_links_werden_namen(self) -> None:
        self.assertEqual(
            fakten.verkehrswege("[[Yaquir]], [[Eisenstraße]], [[Reichsstraße 2]] nach [[Mhanadistan]]"),
            ["Yaquir", "Eisenstraße", "Reichsstraße 2 nach Mhanadistan"],
        )


class BauwerkTest(unittest.TestCase):
    def test_standort_ist_die_erste_verlinkte_siedlung(self) -> None:
        eintrag = fakten.bauwerk(
            "Stadt des Schweigens",
            {
                "Art": "Tempel",
                "Standort": "[[Al'Anfa]]: [[Silberberg]]",
                "Zugehörigkeit": "[[Boron-Kirche]]: [[Al'Anfaner Ritus]]",
            },
            {"Al'Anfa"},
        )
        self.assertEqual(
            eintrag,
            {
                "name": "Stadt des Schweigens",
                "ort": "Al'Anfa",
                "art": "Tempel",
                "zugehoerigkeit": "Boron-Kirche: Al'Anfaner Ritus",
            },
        )

    def test_ohne_bekannte_siedlung_kein_eintrag(self) -> None:
        self.assertIsNone(fakten.bauwerk("X", {"Standort": "[[Nirgendwo]]"}, {"Gareth"}))

    def test_namensvorlagen_werden_aufgeloest(self) -> None:
        self.assertEqual(fakten.erste_seite("{{Pol|Stadtmark Punin}} und [[punin|die Stadt]]"), "Punin")
        self.assertEqual(fakten.kurz("{{Pol|Baronie Raulsmark}}; [[Reichsstadt]]", 80), "Baronie Raulsmark; Reichsstadt")


if __name__ == "__main__":
    unittest.main()
