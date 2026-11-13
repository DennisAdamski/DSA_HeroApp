"""Schneidet das Kartenbild aus einem Avesmaps-Kartenpaket in Kacheln.

Avesmaps gibt seine Live-Kacheln nicht für fremde Apps frei, stellt aber über
seine Karten-API einen Zugang aus (Link oder Schlüssel, mit Frist und
begrenzten Abrufen). Darüber lädt man einmal ein ``paket.zip`` mit der Karte
als PNG, dem DSA-Fanprojekt-Logo und der Lizenz. Dieses Werkzeug macht daraus
eine Kachelpyramide für die App:

    build/karten/aktuell.json                 Manifest (zeigt auf die Revision)
    build/karten/<revision>/manifest.json     dasselbe Manifest, unveränderlich
    build/karten/<revision>/{z}/{x}/{y}.webp  512-px-Kacheln, y von Norden
    build/karten/<revision>/LIZENZ.txt        Lizenz aus dem Paket
    build/karten/<revision>/logo.<ext>        Fanprojekt-Logo aus dem Paket

Die Kacheln gehören nie ins Repository (``/build/`` ist ignoriert); sie gehen
nur auf die Karten-Site (``firebase deploy --config firebase.karten.json``).

Das Paket lädt man selbst im Browser über den Zugangslink herunter. So sieht
kein Skript den Schlüssel. Aufruf (Pillow oder pyvips nötig)::

    python -I tool/avesmaps_karte_kacheln.py --paket ~/Downloads/paket.zip

Ablauf und Lizenzpflichten: docs/web_deployment.md, Abschnitt
„Kartenkacheln“, und docs/reiseroute_plan.md.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import shutil
import sys
import tempfile
import zipfile

KACHEL = 512
LIZENZ_URI = "https://de.wiki-aventurica.de/wiki/Kartenpaket/Lizenz"
NENNUNG = (
    "Kartenmaterial © Ulisses Spiele",
    "Originalkarte: Ina Kramer",
    "Bearbeitung: Avesmaps (DSA-Fanprojekt)",
)
WEBP_QUALITAET = 82


class KartenFehler(Exception):
    """Das Paket oder das Bild taugt nicht für Kacheln."""


def waehle_bild(namen: list[str], serie: str, bild: str | None) -> str:
    """Wählt das PNG der gewünschten Serie aus den Einträgen des Pakets."""
    pngs = [n for n in namen if n.lower().endswith(".png") and "logo" not in n.lower()]
    if bild is not None:
        if bild not in pngs:
            raise KartenFehler(f"Das Paket enthält kein Bild {bild!r}. Vorhanden: {pngs}")
        return bild
    passend = [n for n in pngs if serie.lower() in pathlib.PurePosixPath(n).name.lower()]
    if len(passend) == 1:
        return passend[0]
    if not passend and len(pngs) == 1:
        return pngs[0]
    raise KartenFehler(
        "Das Kartenbild ist nicht eindeutig; bitte mit --bild wählen. "
        f"PNG im Paket: {pngs}"
    )


def pruefe_kante(breite: int, hoehe: int) -> int:
    """Liefert die höchste Zoomstufe; das Bild muss quadratisch sein und eine
    Zweierpotenz ab 512 px als Kante haben."""
    if breite != hoehe:
        raise KartenFehler(f"Das Kartenbild ist nicht quadratisch ({breite}×{hoehe}).")
    if breite < KACHEL or breite & (breite - 1):
        raise KartenFehler(
            f"Die Kante ({breite} px) ist keine Zweierpotenz ab {KACHEL} px."
        )
    return int(math.log2(breite // KACHEL))


class _Pillow:
    """Bildbearbeitung mit Pillow (lädt das ganze Bild in den Speicher)."""

    def __init__(self, pfad: pathlib.Path) -> None:
        from PIL import Image  # noqa: PLC0415 - optionale Abhängigkeit

        Image.MAX_IMAGE_PIXELS = None
        self._Image = Image
        bild = Image.open(pfad)
        self.bild = bild.convert("RGBA" if "A" in bild.getbands() else "RGB")

    @property
    def kante(self) -> tuple[int, int]:
        return self.bild.size

    def stufe(self, kante: int) -> "_Pillow":
        kopie = object.__new__(_Pillow)
        kopie._Image = self._Image
        kopie.bild = (
            self.bild
            if self.bild.size[0] == kante
            else self.bild.resize((kante, kante), self._Image.Resampling.LANCZOS)
        )
        return kopie

    def speichere_kachel(self, x: int, y: int, ziel: pathlib.Path) -> None:
        kachel = self.bild.crop((x * KACHEL, y * KACHEL, (x + 1) * KACHEL, (y + 1) * KACHEL))
        kachel.save(ziel, "WEBP", quality=WEBP_QUALITAET, method=4)


class _Vips:
    """Bildbearbeitung mit pyvips (für große Bilder sparsamer)."""

    def __init__(self, pfad: pathlib.Path) -> None:
        import pyvips  # noqa: PLC0415 - optionale Abhängigkeit

        self._pyvips = pyvips
        self.bild = pyvips.Image.new_from_file(str(pfad), access="random")

    @property
    def kante(self) -> tuple[int, int]:
        return self.bild.width, self.bild.height

    def stufe(self, kante: int) -> "_Vips":
        kopie = object.__new__(_Vips)
        kopie._pyvips = self._pyvips
        faktor = kante / self.bild.width
        kopie.bild = self.bild if faktor == 1 else self.bild.resize(faktor, kernel="lanczos3")
        return kopie

    def speichere_kachel(self, x: int, y: int, ziel: pathlib.Path) -> None:
        self.bild.crop(x * KACHEL, y * KACHEL, KACHEL, KACHEL).webpsave(
            str(ziel), Q=WEBP_QUALITAET
        )


def _oeffne(pfad: pathlib.Path):
    try:
        return _Vips(pfad)
    except ImportError:
        pass
    try:
        return _Pillow(pfad)
    except ImportError as fehler:
        raise KartenFehler(
            "Zum Schneiden wird Pillow oder pyvips gebraucht: "
            "python -m pip install pillow"
        ) from fehler


def schneide(
    paket: pathlib.Path,
    ausgabe: pathlib.Path,
    *,
    serie: str = "modern",
    bild: str | None = None,
    max_zoom: int | None = None,
) -> dict:
    """Schneidet das Kartenbild aus [paket] nach [ausgabe] und liefert das
    Manifest."""
    with zipfile.ZipFile(paket) as zip_datei:
        namen = zip_datei.namelist()
        bildname = waehle_bild(namen, serie, bild)
        with tempfile.TemporaryDirectory() as arbeit:
            arbeit_pfad = pathlib.Path(arbeit)
            png = arbeit_pfad / "karte.png"
            hasher = hashlib.sha256()
            with zip_datei.open(bildname) as quelle, png.open("wb") as ziel:
                for block in iter(lambda: quelle.read(1 << 20), b""):
                    hasher.update(block)
                    ziel.write(block)
            revision = hasher.hexdigest()[:12]

            karte = _oeffne(png)
            breite, hoehe = karte.kante
            hoechste = pruefe_kante(breite, hoehe)
            if max_zoom is not None:
                hoechste = min(hoechste, max_zoom)

            ziel_ordner = ausgabe / revision
            if ziel_ordner.exists():
                shutil.rmtree(ziel_ordner)
            ziel_ordner.mkdir(parents=True)

            for z in range(hoechste + 1):
                stufe = karte.stufe(KACHEL << z)
                anzahl = 1 << z
                for x in range(anzahl):
                    spalte = ziel_ordner / str(z) / str(x)
                    spalte.mkdir(parents=True, exist_ok=True)
                    for y in range(anzahl):
                        stufe.speichere_kachel(x, y, spalte / f"{y}.webp")

            logo = _kopiere_beigaben(zip_datei, namen, ziel_ordner)

    manifest = {
        "serie": serie,
        "revision": revision,
        "maxZoom": hoechste,
        "tileSize": KACHEL,
        "format": "webp",
        "pixel": breite,
        "quelle": pathlib.PurePosixPath(bildname).name,
        "nennung": list(NENNUNG),
        "lizenzUri": LIZENZ_URI,
    }
    if logo:
        manifest["logo"] = logo
    text = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    (ziel_ordner / "manifest.json").write_text(text, encoding="utf-8")
    (ausgabe / "aktuell.json").write_text(text, encoding="utf-8")
    return manifest


def _kopiere_beigaben(zip_datei: zipfile.ZipFile, namen: list[str], ziel: pathlib.Path) -> str:
    """Kopiert Lizenz und Logo aus dem Paket; liefert den Dateinamen des
    Logos oder leer."""
    logo = ""
    for name in namen:
        datei = pathlib.PurePosixPath(name).name
        klein = datei.lower()
        if klein.startswith("lizenz") and klein.endswith(".txt"):
            (ziel / "LIZENZ.txt").write_bytes(zip_datei.read(name))
        elif "logo" in klein and klein.rsplit(".", 1)[-1] in {"png", "svg", "webp"}:
            logo = "logo." + klein.rsplit(".", 1)[-1]
            (ziel / logo).write_bytes(zip_datei.read(name))
    if not (ziel / "LIZENZ.txt").exists():
        (ziel / "LIZENZ.txt").write_text(
            "Lizenzvereinbarung zum Ulisses-Kartenpaket: " + LIZENZ_URI + "\n",
            encoding="utf-8",
        )
    return logo


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--paket", required=True, type=pathlib.Path, help="paket.zip von Avesmaps")
    parser.add_argument("--ausgabe", type=pathlib.Path, default=pathlib.Path("build/karten"))
    parser.add_argument("--serie", default="modern", help="Kartenserie (modern, original, old)")
    parser.add_argument("--bild", help="Name des PNG im Paket, falls nicht eindeutig")
    parser.add_argument("--max-zoom", type=int, help="höchste Zoomstufe begrenzen")
    argumente = parser.parse_args(argv)
    try:
        manifest = schneide(
            argumente.paket,
            argumente.ausgabe,
            serie=argumente.serie,
            bild=argumente.bild,
            max_zoom=argumente.max_zoom,
        )
    except (KartenFehler, zipfile.BadZipFile, OSError) as fehler:
        print(f"Fehler: {fehler}", file=sys.stderr)
        return 1
    kacheln = sum(4**z for z in range(manifest["maxZoom"] + 1))
    print(
        f"{kacheln} Kacheln (z0–{manifest['maxZoom']}) unter "
        f"{argumente.ausgabe / manifest['revision']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
