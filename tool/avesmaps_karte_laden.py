"""Lädt ein Kartenpaket über den Karten-Zugang von Avesmaps.

Avesmaps stellt für die eigene Kartenkachel-Site einen Zugang aus: einen
Schlüssel ``avk_…`` oder einen Link ``https://avesmaps.de/paket#<token>``.
Beides gilt nur im Kopf einer Anfrage (``Authorization: Bearer …``), daher
reicht der Browser nicht. Dieses Werkzeug holt das ZIP (Karte als PNG,
``LIZENZ.txt``, DSA-Fanprojekt-Logo) und legt es außerhalb des Repositorys ab:

    python -I tool/avesmaps_karte_laden.py                 # Karten anzeigen, wählen, laden
    python -I tool/avesmaps_karte_laden.py --karte <id>    # ohne Liste direkt laden

Der Zugang wird verdeckt abgefragt oder aus ``AVESMAPS_KARTEN_SCHLUESSEL``
gelesen. Er steht nie in Argumenten, Dateien oder in der Ausgabe. Jeder Aufruf
zählt bei Avesmaps als Abruf, auch die Liste. Das Werkzeug wiederholt deshalb
nichts von sich aus. Ein abgebrochener Download wird beim nächsten Aufruf
fortgesetzt (``.part``-Datei, ``Range``).

Danach weiter mit ``tool/avesmaps_karte_kacheln.py``; Ablauf in
docs/avesmaps_kartenzugang.md.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from typing import Any, BinaryIO, Callable

BASIS = "https://avesmaps.de"
KENNUNG = "DSA_HeroApp/1.0 (+https://github.com/DennisAdamski/DSA_HeroApp)"
UMGEBUNG = "AVESMAPS_KARTEN_SCHLUESSEL"
SCHLUESSEL = re.compile(r"^avk_[A-Za-z0-9_-]{43}$")
KARTEN_ID = re.compile(r"^[a-z][a-z0-9-]{0,40}$")
BLOCK = 1 << 20
ZEITLIMIT = 60
VORSCHLAG_SERIE = "modern"
VORSCHLAG_PIXEL = 16384


class LadeFehler(Exception):
    """Der Abruf ist gescheitert; die Meldung ist für Menschen gedacht."""


def zugang_aus(eingabe: str) -> str:
    """Nimmt einen Schlüssel, ein Token oder den ganzen Link und liefert den Wert für ``Bearer``."""
    wert = eingabe.strip()
    if "#" in wert:
        wert = wert.split("#", 1)[1]
        if "=" in wert:
            # Fragment im Stil ``token=…``: den Wert nehmen, nicht den Namen.
            wert = urllib.parse.parse_qs(wert).get("token", [wert.split("=", 1)[1]])[0]
    wert = wert.strip()
    if not wert or any(z.isspace() for z in wert):
        raise LadeFehler("Der Zugang ist leer oder enthält Leerzeichen.")
    return wert


def ist_schluessel(zugang: str) -> bool:
    return SCHLUESSEL.match(zugang) is not None


def _anfrage(url: str, zugang: str | None, kopf: dict[str, str] | None = None) -> urllib.request.Request:
    felder = {"User-Agent": KENNUNG, "Accept": "application/json, application/zip"}
    if zugang is not None:
        felder["Authorization"] = f"Bearer {zugang}"
    felder.update(kopf or {})
    return urllib.request.Request(url, headers=felder)


def _fehler_aus(fehler: urllib.error.HTTPError) -> LadeFehler:
    """Übersetzt den Fehlerumschlag von Avesmaps (``error``/``code``, ``message``)."""
    code = ""
    text = ""
    try:
        roh = json.loads(fehler.read().decode("utf-8", "replace"))
        if isinstance(roh, dict):
            inhalt = roh.get("error") if isinstance(roh.get("error"), dict) else roh
            code = str(inhalt.get("code") or inhalt.get("error") or "")
            text = str(inhalt.get("message") or "")
    except (ValueError, OSError, AttributeError):
        pass
    finally:
        fehler.close()
    teile = [f"HTTP {fehler.code}"]
    if code:
        teile.append(code)
    meldung = " · ".join(teile)
    if text:
        meldung += f": {text}"
    warte = fehler.headers.get("Retry-After") if fehler.headers else None
    if fehler.code == 429 and warte:
        meldung += f" (frühestens in {warte} s erneut versuchen)"
    if fehler.code == 401:
        meldung += " – Schlüssel falsch, abgelaufen oder zurückgenommen."
    if fehler.code == 410:
        meldung += " – Link oder Ticket gilt nicht mehr."
    return LadeFehler(meldung)


def _json(url: str, zugang: str | None) -> Any:
    try:
        with urllib.request.urlopen(_anfrage(url, zugang), timeout=ZEITLIMIT) as antwort:
            return json.loads(antwort.read().decode("utf-8"))
    except urllib.error.HTTPError as fehler:
        raise _fehler_aus(fehler) from None
    except urllib.error.URLError as fehler:
        raise LadeFehler(f"Keine Verbindung zu {urllib.parse.urlsplit(url).netloc}: {fehler.reason}") from None


def liste_karten(basis: str, zugang: str) -> dict[str, Any]:
    """``GET /api/v1/karten``: Karten im Umfang des Schlüssels."""
    daten = _json(f"{basis}/api/v1/karten", zugang)
    if not isinstance(daten, dict) or not isinstance(daten.get("karten"), list):
        raise LadeFehler("Unerwartete Antwort auf die Kartenliste.")
    return daten


def oeffne_link(basis: str, zugang: str) -> dict[str, Any]:
    """``GET /api/karten-paket/oeffnen``: Sicht eines Token-Links samt Ticket-Adresse."""
    daten = _json(f"{basis}/api/karten-paket/oeffnen", zugang)
    if not isinstance(daten, dict) or not isinstance(daten.get("datei"), str):
        raise LadeFehler("Unerwartete Antwort beim Öffnen des Links.")
    return daten


def vorschlag(karten: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Die PNG der Serie ``modern`` mit 16384 px, sonst die kleinste PNG dieser Serie."""
    pngs = [k for k in karten if k.get("art") == "png" and k.get("bytes") is not None]
    serie = [k for k in pngs if VORSCHLAG_SERIE in f"{k.get('id', '')} {k.get('name', '')}".lower()]
    for kandidat in serie:
        if kandidat.get("pixel") == VORSCHLAG_PIXEL:
            return kandidat
    serie.sort(key=lambda k: k.get("pixel") or 0)
    return serie[0] if serie else None


def _mb(bytes_: Any) -> str:
    return "–" if not isinstance(bytes_, int) else f"{bytes_ / 1e6:,.0f} MB".replace(",", ".")


def zeige_karten(karten: list[dict[str, Any]], aus: Callable[[str], None] = print) -> None:
    for k in karten:
        pixel = f"{k['pixel']} px" if isinstance(k.get("pixel"), int) else "–"
        fehlt = "  (auf dem Server nicht vorhanden)" if k.get("bytes") is None else ""
        aus(f"  {k.get('id', '?'):<32} {k.get('art', '?'):<4} {pixel:>9} {_mb(k.get('bytes')):>9}  {k.get('name', '')}{fehlt}")


def lade_datei(
    url: str,
    zugang: str | None,
    ziel: pathlib.Path,
    aus: Callable[[str], None] = print,
) -> str | None:
    """Lädt ``url`` nach ``ziel`` über ``<ziel>.part``; setzt einen Rest fort. Liefert den ETag."""
    teil = ziel.with_name(ziel.name + ".part")
    vorhanden = teil.stat().st_size if teil.exists() else 0
    kopf = {"Range": f"bytes={vorhanden}-"} if vorhanden else {}
    try:
        antwort = urllib.request.urlopen(_anfrage(url, zugang, kopf), timeout=ZEITLIMIT)
    except urllib.error.HTTPError as fehler:
        if fehler.code == 416 and vorhanden:
            teil.unlink()
            raise LadeFehler("Der Rest passte nicht mehr zur Datei; .part gelöscht, bitte neu starten.") from None
        raise _fehler_aus(fehler) from None
    except urllib.error.URLError as fehler:
        raise LadeFehler(f"Keine Verbindung: {fehler.reason}") from None
    with antwort:
        fortsetzen = antwort.status == 206
        if vorhanden and not fortsetzen:
            vorhanden = 0
        gesamt = _gesamtgroesse(antwort.headers, vorhanden)
        etag = (antwort.headers.get("ETag") or "").strip().removeprefix("W/").strip('"') or None
        with teil.open("ab" if fortsetzen else "wb") as datei:
            _kopiere(antwort, datei, vorhanden, gesamt, aus)
    teil.replace(ziel)
    return etag


def _gesamtgroesse(kopf: Any, vorhanden: int) -> int | None:
    bereich = kopf.get("Content-Range") or ""
    if "/" in bereich and bereich.rsplit("/", 1)[1].isdigit():
        return int(bereich.rsplit("/", 1)[1])
    laenge = kopf.get("Content-Length")
    return vorhanden + int(laenge) if laenge and laenge.isdigit() else None


def _kopiere(quelle: BinaryIO, datei: BinaryIO, start: int, gesamt: int | None, aus: Callable[[str], None]) -> None:
    geladen = start
    letzte = -1
    while True:
        block = quelle.read(BLOCK)
        if not block:
            break
        datei.write(block)
        geladen += len(block)
        if gesamt:
            prozent = geladen * 100 // gesamt
            if prozent // 5 != letzte // 5:
                aus(f"  {prozent:3d} %  {_mb(geladen)} von {_mb(gesamt)}")
                letzte = prozent
    if gesamt is not None and geladen != gesamt:
        raise LadeFehler(f"Download unvollständig ({geladen} von {gesamt} Bytes); erneut aufrufen setzt fort.")


def sha256(pfad: pathlib.Path) -> str:
    pruef = hashlib.sha256()
    with pfad.open("rb") as datei:
        for block in iter(lambda: datei.read(BLOCK), b""):
            pruef.update(block)
    return pruef.hexdigest()


def pruefe_paket(pfad: pathlib.Path, etag: str | None, karten: list[dict[str, Any]], aus: Callable[[str], None]) -> None:
    """Prüft ZIP, ETag (Prüfsumme des Pakets) und die Prüfsummen der enthaltenen Karten."""
    if etag and re.fullmatch(r"[0-9a-f]{64}", etag):
        if sha256(pfad) == etag:
            aus("  Prüfsumme des Pakets stimmt.")
        else:
            aus("  Hinweis: Prüfsumme des Pakets weicht vom ETag ab; maßgeblich ist die Prüfung der Einträge.")
    try:
        with zipfile.ZipFile(pfad) as paket:
            namen = paket.namelist()
            kaputt = paket.testzip()
            if kaputt is not None:
                raise LadeFehler(f"Eintrag {kaputt} im ZIP ist beschädigt; Datei löschen und neu laden.")
            for karte in karten:
                name, soll = karte.get("datei"), karte.get("sha256")
                if not isinstance(name, str) or not isinstance(soll, str) or name not in namen:
                    continue
                pruef = hashlib.sha256()
                with paket.open(name) as eintrag:
                    for block in iter(lambda: eintrag.read(BLOCK), b""):
                        pruef.update(block)
                if pruef.hexdigest() != soll:
                    raise LadeFehler(f"Prüfsumme von {name} stimmt nicht.")
                aus(f"  Prüfsumme von {name} stimmt.")
    except zipfile.BadZipFile:
        raise LadeFehler("Die geladene Datei ist kein gültiges ZIP.") from None
    aus("  Inhalt: " + ", ".join(namen))


def frage_zugang(eingabe: Callable[[str], str] = getpass.getpass) -> str:
    roh = os.environ.get(UMGEBUNG) or eingabe("Zugang (Schlüssel avk_… oder Link, Eingabe verdeckt): ")
    return zugang_aus(roh)


def waehle_karte(
    karten: list[dict[str, Any]],
    eingabe: Callable[[str], str] = input,
) -> dict[str, Any]:
    vorgabe = vorschlag(karten)
    hinweis = f" [{vorgabe['id']}]" if vorgabe else ""
    wahl = eingabe(f"Welche Karte laden?{hinweis} ").strip() or (vorgabe or {}).get("id", "")
    for karte in karten:
        if karte.get("id") == wahl:
            return karte
    raise LadeFehler(f"Keine Karte {wahl!r} im Umfang dieses Zugangs.")


def main(
    argv: list[str] | None = None,
    *,
    eingabe_geheim: Callable[[str], str] = getpass.getpass,
    eingabe: Callable[[str], str] = input,
    aus: Callable[[str], None] = print,
) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("--karte", help="Kennung der Karte; überspringt die Liste (spart einen Abruf)")
    parser.add_argument(
        "--ziel",
        type=pathlib.Path,
        default=pathlib.Path.home() / "Downloads" / "avesmaps-paket.zip",
        help="Zieldatei, außerhalb des Repositorys (Standard: ~/Downloads/avesmaps-paket.zip)",
    )
    parser.add_argument("--basis", default=BASIS, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    basis = args.basis.rstrip("/")
    try:
        if args.karte is not None and not KARTEN_ID.match(args.karte):
            raise LadeFehler(f"Ungültige Kartenkennung {args.karte!r}.")
        if _im_repository(args.ziel):
            raise LadeFehler("Das Paket gehört nicht ins Repository; bitte ein --ziel außerhalb wählen.")
        if args.ziel.exists():
            raise LadeFehler(f"{args.ziel} gibt es schon; löschen oder anderes --ziel wählen.")
        args.ziel.parent.mkdir(parents=True, exist_ok=True)
        zugang = frage_zugang(eingabe_geheim)
        karten: list[dict[str, Any]] = []
        if ist_schluessel(zugang):
            if args.karte is None:
                liste = liste_karten(basis, zugang)
                karten = [k for k in liste["karten"] if isinstance(k, dict)]
                aus(f"Zugang gilt bis {liste.get('laeuftAb', '?')}. Karten:")
                zeige_karten(karten, aus)
                karte = waehle_karte(karten, eingabe)
                karten = [karte]
                kennung = karte["id"]
            else:
                kennung = args.karte
            aus(f"Lade {kennung} nach {args.ziel} …")
            etag = lade_datei(f"{basis}/api/v1/karten/{kennung}.zip", zugang, args.ziel, aus)
        else:
            sicht = oeffne_link(basis, zugang)
            karten = [k for k in sicht.get("karten", []) if isinstance(k, dict)]
            aus(f"Link gilt bis {sicht.get('laeuftAb', '?')}. Paket enthält:")
            zeige_karten(karten, aus)
            datei = urllib.parse.urljoin(basis + "/", sicht["datei"])
            aus(f"Lade Paket nach {args.ziel} …")
            etag = lade_datei(datei, None, args.ziel, aus)
        pruefe_paket(args.ziel, etag, karten, aus)
    except LadeFehler as fehler:
        aus(f"Fehler: {fehler}")
        return 1
    except KeyboardInterrupt:
        aus("Abgebrochen; erneut aufrufen setzt den Download fort.")
        return 130
    aus(f"Fertig. Weiter mit: python -I tool/avesmaps_karte_kacheln.py --paket \"{args.ziel}\"")
    return 0


def _im_repository(ziel: pathlib.Path) -> bool:
    wurzel = pathlib.Path(__file__).resolve().parents[1]
    try:
        ziel.resolve().relative_to(wurzel)
    except ValueError:
        return False
    return True


if __name__ == "__main__":
    sys.exit(main())
