"""Tests für das Laden eines Kartenpakets über den Karten-Zugang von Avesmaps.

Arbeitet gegen einen lokalen Fake-Server mit synthetischem Paket, nie gegen
avesmaps.de.
"""

from __future__ import annotations

import hashlib
import http.server
import io
import json
import pathlib
import sys
import tempfile
import threading
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

import avesmaps_karte_laden as laden  # noqa: E402

SCHLUESSEL = "avk_" + "A" * 43
TOKEN = "linktoken" + "b" * 30
BILD = b"\x89PNG-synthetisch" * 4096


def _paket() -> bytes:
    puffer = io.BytesIO()
    with zipfile.ZipFile(puffer, "w") as paket:
        paket.writestr("aventurien-modern-16384.png", BILD)
        paket.writestr("LIZENZ.txt", "Lizenz")
        paket.writestr("logo.png", b"logo")
    return puffer.getvalue()


PAKET = _paket()
KARTEN = [
    {
        "id": "modern-8192",
        "art": "png",
        "name": "Modern",
        "datei": "aventurien-modern-8192.png",
        "bytes": 100,
        "pixel": 8192,
        "sha256": None,
    },
    {
        "id": "modern-16384",
        "art": "png",
        "name": "Modern",
        "datei": "aventurien-modern-16384.png",
        "bytes": len(BILD),
        "pixel": 16384,
        "sha256": hashlib.sha256(BILD).hexdigest(),
    },
    {"id": "svg-roh", "art": "svg", "name": "SVG", "datei": "a.svg", "bytes": None, "pixel": 1024, "sha256": None},
]


class _Fake(http.server.BaseHTTPRequestHandler):
    aufrufe: list[tuple[str, str | None, str | None, str | None]] = []

    def log_message(self, *args: object) -> None:  # noqa: D102
        pass

    def _json(self, status: int, daten: object) -> None:
        roh = json.dumps(daten).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(roh)))
        self.end_headers()
        self.wfile.write(roh)

    def _zip(self) -> None:
        bereich = self.headers.get("Range")
        start = int(bereich.split("=")[1].rstrip("-")) if bereich else 0
        teil = PAKET[start:]
        self.send_response(206 if bereich else 200)
        self.send_header("Content-Type", "application/zip")
        self.send_header("ETag", f'"{hashlib.sha256(PAKET).hexdigest()}"')
        self.send_header("Content-Length", str(len(teil)))
        if bereich:
            self.send_header("Content-Range", f"bytes {start}-{len(PAKET) - 1}/{len(PAKET)}")
        self.end_headers()
        self.wfile.write(teil)

    def do_GET(self) -> None:  # noqa: N802
        auth = self.headers.get("Authorization")
        _Fake.aufrufe.append((self.path, auth, self.headers.get("User-Agent"), self.headers.get("Range")))
        if self.path.startswith("/api/karten-paket/datei/"):
            return self._zip() if auth is None else self._json(400, {"error": {"code": "unerwartet"}})
        if self.path == "/api/karten-paket/oeffnen":
            if auth != f"Bearer {TOKEN}":
                return self._json(410, {"error": {"code": "link_abgelaufen", "message": "Dieser Link gilt nicht mehr."}})
            return self._json(
                200,
                {"karten": KARTEN[1:2], "laeuftAb": "2026-12-01T00:00:00Z", "datei": "/api/karten-paket/datei/t.1.x"},
            )
        if auth != f"Bearer {SCHLUESSEL}":
            return self._json(401, {"error": {"code": "unauthorized", "message": "Dieser Schlüssel gilt hier nicht."}})
        if self.path == "/api/v1/karten":
            return self._json(200, {"vertrag": 1, "laeuftAb": "2026-12-01T00:00:00Z", "karten": KARTEN})
        if self.path == "/api/v1/karten/modern-16384.zip":
            return self._zip()
        return self._json(404, {"error": {"code": "not_found"}})


class LadenTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), _Fake)
        cls.basis = f"http://127.0.0.1:{cls.server.server_address[1]}"
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self) -> None:
        _Fake.aufrufe = []
        self._tmp = tempfile.TemporaryDirectory()
        self.ziel = pathlib.Path(self._tmp.name) / "paket.zip"
        self.ausgabe: list[str] = []

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _main(self, zugang: str, *argv: str, wahl: str = "") -> int:
        return laden.main(
            ["--basis", self.basis, "--ziel", str(self.ziel), *argv],
            eingabe_geheim=lambda _: zugang,
            eingabe=lambda _: wahl,
            aus=self.ausgabe.append,
        )

    def test_zugang_aus_link_und_schluessel(self) -> None:
        self.assertEqual(laden.zugang_aus(f"  {SCHLUESSEL}\n"), SCHLUESSEL)
        self.assertEqual(laden.zugang_aus(f"https://avesmaps.de/paket#{TOKEN}"), TOKEN)
        self.assertEqual(laden.zugang_aus(f"https://avesmaps.de/paket#token={TOKEN}"), TOKEN)
        self.assertTrue(laden.ist_schluessel(SCHLUESSEL))
        self.assertFalse(laden.ist_schluessel(TOKEN))
        with self.assertRaises(laden.LadeFehler):
            laden.zugang_aus("   ")

    def test_vorschlag_nimmt_modern_16384(self) -> None:
        self.assertEqual(laden.vorschlag(KARTEN)["id"], "modern-16384")

    def test_schluessel_liste_und_vorschlag(self) -> None:
        self.assertEqual(self._main(SCHLUESSEL), 0, self.ausgabe)
        self.assertEqual(self.ziel.read_bytes(), PAKET)
        self.assertEqual([a[0] for a in _Fake.aufrufe], ["/api/v1/karten", "/api/v1/karten/modern-16384.zip"])
        self.assertTrue(all(a[2] == laden.KENNUNG for a in _Fake.aufrufe))
        text = "\n".join(self.ausgabe)
        self.assertIn("Prüfsumme des Pakets stimmt", text)
        self.assertIn("Prüfsumme von aventurien-modern-16384.png stimmt", text)
        self.assertNotIn(SCHLUESSEL, text)

    def test_karte_direkt_ohne_liste(self) -> None:
        self.assertEqual(self._main(SCHLUESSEL, "--karte", "modern-16384"), 0, self.ausgabe)
        self.assertEqual([a[0] for a in _Fake.aufrufe], ["/api/v1/karten/modern-16384.zip"])

    def test_link_ueber_ticket_ohne_kopf(self) -> None:
        self.assertEqual(self._main(f"https://avesmaps.de/paket#{TOKEN}"), 0, self.ausgabe)
        self.assertEqual(self.ziel.read_bytes(), PAKET)
        pfade = [(a[0], a[1]) for a in _Fake.aufrufe]
        self.assertEqual(
            pfade,
            [("/api/karten-paket/oeffnen", f"Bearer {TOKEN}"), ("/api/karten-paket/datei/t.1.x", None)],
        )

    def test_fehlerumschlag_ohne_geheimnis(self) -> None:
        falsch = "avk_" + "Z" * 43
        self.assertEqual(self._main(falsch), 1)
        text = "\n".join(self.ausgabe)
        self.assertIn("HTTP 401 · unauthorized", text)
        self.assertNotIn(falsch, text)
        self.assertFalse(self.ziel.exists())

    def test_setzt_abgebrochenen_download_fort(self) -> None:
        self.ziel.with_name("paket.zip.part").write_bytes(PAKET[:1000])
        self.assertEqual(self._main(SCHLUESSEL, "--karte", "modern-16384"), 0, self.ausgabe)
        self.assertEqual(_Fake.aufrufe[-1][3], "bytes=1000-")
        self.assertEqual(self.ziel.read_bytes(), PAKET)
        self.assertFalse(self.ziel.with_name("paket.zip.part").exists())

    def test_ziel_im_repository_abgelehnt(self) -> None:
        ergebnis = laden.main(
            ["--basis", self.basis, "--ziel", str(ROOT / "build" / "paket.zip")],
            eingabe_geheim=lambda _: SCHLUESSEL,
            aus=self.ausgabe.append,
        )
        self.assertEqual(ergebnis, 1)
        self.assertEqual(_Fake.aufrufe, [])


if __name__ == "__main__":
    unittest.main()
