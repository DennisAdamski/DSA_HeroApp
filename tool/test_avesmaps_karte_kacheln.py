"""Tests für das Schneiden der Kartenkacheln und die Karten-Site.

Arbeitet mit einem synthetischen Bild, nie mit Kartenmaterial.
"""

from __future__ import annotations

import importlib.util
import io
import json
import pathlib
import sys
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

import avesmaps_karte_kacheln as kacheln  # noqa: E402

HAT_PILLOW = importlib.util.find_spec("PIL") is not None


def _paket(pfad: pathlib.Path, kante: int, *, name: str = "aventurien-modern.png") -> None:
    from PIL import Image  # noqa: PLC0415

    bild = Image.new("RGB", (kante, kante), (90, 120, 160))
    # Eine Ecke markieren, damit die Lage der Kacheln prüfbar ist.
    for x in range(16):
        for y in range(16):
            bild.putpixel((x, y), (255, 0, 0))
    puffer = io.BytesIO()
    bild.save(puffer, "PNG")
    with zipfile.ZipFile(pfad, "w") as zip_datei:
        zip_datei.writestr(name, puffer.getvalue())
        zip_datei.writestr("LIZENZ.txt", "Lizenztext")
        zip_datei.writestr("dsa-fanprojekt-logo.png", b"\x89PNG logo")


class AuswahlTest(unittest.TestCase):
    def test_waehlt_die_serie_und_ignoriert_das_logo(self) -> None:
        namen = ["a/aventurien-modern.png", "a/aventurien-original.png", "logo.png"]
        self.assertEqual(kacheln.waehle_bild(namen, "modern", None), namen[0])

    def test_ein_einziges_bild_gilt_auch_ohne_seriennamen(self) -> None:
        self.assertEqual(kacheln.waehle_bild(["karte.png"], "modern", None), "karte.png")

    def test_mehrdeutig_verlangt_bild(self) -> None:
        with self.assertRaises(kacheln.KartenFehler):
            kacheln.waehle_bild(["x.png", "y.png"], "modern", None)

    def test_kante_muss_quadratische_zweierpotenz_sein(self) -> None:
        self.assertEqual(kacheln.pruefe_kante(512, 512), 0)
        self.assertEqual(kacheln.pruefe_kante(16384, 16384), 5)
        for breite, hoehe in ((1024, 512), (1000, 1000), (256, 256)):
            with self.assertRaises(kacheln.KartenFehler):
                kacheln.pruefe_kante(breite, hoehe)


@unittest.skipUnless(HAT_PILLOW, "Pillow ist nicht installiert")
class SchneidenTest(unittest.TestCase):
    def test_pyramide_manifest_und_beigaben(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_pfad = pathlib.Path(tmp)
            paket = tmp_pfad / "paket.zip"
            _paket(paket, 1024)
            ausgabe = tmp_pfad / "karten"
            manifest = kacheln.schneide(paket, ausgabe)

            self.assertEqual(manifest["maxZoom"], 1)
            self.assertEqual(manifest["tileSize"], 512)
            self.assertRegex(manifest["revision"], r"^[0-9a-f]{12}$")
            ordner = ausgabe / manifest["revision"]
            webp = sorted(p.relative_to(ordner).as_posix() for p in ordner.rglob("*.webp"))
            self.assertEqual(webp, ["0/0/0.webp", "1/0/0.webp", "1/0/1.webp", "1/1/0.webp", "1/1/1.webp"])
            self.assertEqual(
                json.loads((ausgabe / "aktuell.json").read_text(encoding="utf-8")),
                manifest,
            )
            self.assertEqual(manifest["logo"], "logo.png")
            self.assertTrue((ordner / "LIZENZ.txt").exists())

            from PIL import Image  # noqa: PLC0415

            # Die rote Ecke liegt in der Kachel oben links (y von Norden).
            with Image.open(ordner / "1/0/0.webp") as oben_links:
                r, g, b = oben_links.convert("RGB").getpixel((2, 2))
                self.assertGreater(r, 200)
                self.assertLess(b, 80)

    def test_max_zoom_begrenzt_die_pyramide(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_pfad = pathlib.Path(tmp)
            paket = tmp_pfad / "paket.zip"
            _paket(paket, 1024)
            manifest = kacheln.schneide(paket, tmp_pfad / "karten", max_zoom=0)
            self.assertEqual(manifest["maxZoom"], 0)


class KartenSiteTest(unittest.TestCase):
    def test_karten_site_ist_getrennt_und_cachefest(self) -> None:
        config = json.loads((ROOT / "firebase.karten.json").read_text(encoding="utf-8"))
        hosting = config["hosting"]
        self.assertEqual(hosting["public"], "build/karten")
        regeln = {regel["source"]: {h["key"]: h["value"] for h in regel["headers"]} for regel in hosting["headers"]}
        self.assertEqual(regeln["/aktuell.json"]["Cache-Control"], "no-cache")
        self.assertIn("immutable", regeln["**/*.@(webp|png|svg|txt)"]["Cache-Control"])
        alle = regeln["**"]
        self.assertEqual(alle["X-Content-Type-Options"], "nosniff")
        self.assertIn("default-src 'none'", alle["Content-Security-Policy"])
        # Die Kacheln liegen nicht im App-Build und nicht in der App-Konfiguration.
        app = json.loads((ROOT / "firebase.json").read_text(encoding="utf-8"))
        for ziel in app["hosting"]:
            self.assertNotEqual(ziel["public"], "build/karten")

    def test_app_csp_erlaubt_die_karten_site_fuer_bilder_und_abrufe(self) -> None:
        site = "https://" + json.loads(
            (ROOT / "firebase.karten.json").read_text(encoding="utf-8")
        )["hosting"]["site"] + ".web.app"
        app = json.loads((ROOT / "firebase.json").read_text(encoding="utf-8"))
        for ziel in app["hosting"]:
            csp = next(
                h["value"]
                for regel in ziel["headers"]
                if regel["source"] == "**"
                for h in regel["headers"]
                if h["key"] == "Content-Security-Policy"
            )
            teile = {teil.split()[0]: teil.split()[1:] for teil in csp.split(";") if teil.strip()}
            self.assertIn(site, teile["img-src"], ziel["target"])
            self.assertIn(site, teile["connect-src"], ziel["target"])


if __name__ == "__main__":
    unittest.main()
