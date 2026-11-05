"""Passwortnachweis fuer den Zugang zur Regel-Wissensbasis.

Die Cloud Function `rulesIndexApi` kennt das Katalogpasswort nicht, sondern nur
einen daraus abgeleiteten Nachweis: SHA-256 ueber ein festes Praefix und den
v3-Katalogschluessel (PBKDF2 100k, globaler Salt aus dem Katalog-Manifest). Die
App rechnet denselben Wert (`lib/data/rules_search/rules_index_proof.dart`).

Aufruf (Passwort wie bei `encrypt_catalog_fields.py` aus `docs/Passwort.env`,
`KATALOG_PASSWORT` oder `--password`):

    python tool/rules_index_proof.py            # gibt NUR den Nachweis aus
    firebase functions:secrets:set RULES_INDEX_PROOF

Den Nachweis beim Setzen des Secrets einfuegen. Das Passwort selbst wird nie
ausgegeben und nirgends gespeichert. Aendert sich das Katalogpasswort oder der
Salt, muss das Secret neu gesetzt werden.

Bewusst ohne `pycryptodome`: gebraucht wird nur PBKDF2 aus der Standardbibliothek.
Die Ableitung muss mit `derive_key_v3` in `encrypt_catalog_fields.py` und
`deriveCatalogKey` in `lib/catalog/catalog_crypto.dart` uebereinstimmen; ein
Dart-Test pinnt den Wert fuer ein festes Passwort und einen festen Salt.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import sys
import unicodedata
from pathlib import Path

#: Praefix der Nachweisbildung. Ein anderer Zweck desselben Schluessels ergibt
#: so einen anderen Hash, der Katalogschluessel selbst verlaesst nie den Client.
PROOF_PREFIX = b"rules-index-v1|"

PBKDF2_ITERATIONS = 100000
KEY_LENGTH = 32
PASSWORD_ENV_VAR = "KATALOG_PASSWORT"
PASSWORD_FILE = "docs/Passwort.env"
MANIFEST_SALT_KEY = "catalog_salt_v3"

PROJECT_DIR = Path(__file__).resolve().parent.parent
CATALOG_DIR = PROJECT_DIR / "assets" / "catalogs" / "house_rules_v1"


def rules_index_proof(password: str, salt: bytes) -> str:
    """Nachweis (64 Zeichen hex) fuer [password] und den Katalog-[salt]."""
    key = hashlib.pbkdf2_hmac(
        "sha256",
        unicodedata.normalize("NFC", password).encode("utf-8"),
        salt,
        PBKDF2_ITERATIONS,
        dklen=KEY_LENGTH,
    )
    return hashlib.sha256(PROOF_PREFIX + key).hexdigest()


def _resolve_password(cli_value: str | None) -> str | None:
    if cli_value:
        return cli_value
    env_value = os.environ.get(PASSWORD_ENV_VAR)
    if env_value:
        return env_value
    file_path = PROJECT_DIR / PASSWORD_FILE
    if file_path.is_file():
        for line in file_path.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            prefix = f"{PASSWORD_ENV_VAR}="
            if line.startswith(prefix):
                line = line[len(prefix):]
            if line:
                return line
    return None


def _read_salt() -> bytes | None:
    manifest = json.loads((CATALOG_DIR / "manifest.json").read_text(encoding="utf-8-sig"))
    raw = manifest.get(MANIFEST_SALT_KEY)
    if not isinstance(raw, str) or not raw.strip():
        return None
    salt = base64.b64decode(raw)
    return salt if len(salt) >= 16 else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--password", default=None, help="Katalogpasswort (sonst Datei/Umgebung)")
    args = parser.parse_args()

    password = _resolve_password(args.password)
    if password is None:
        print(
            f"Fehler: kein Passwort. --password angeben, {PASSWORD_ENV_VAR} setzen "
            f"oder {PASSWORD_FILE} anlegen.",
            file=sys.stderr,
        )
        return 1
    salt = _read_salt()
    if salt is None:
        print("Fehler: kein catalog_salt_v3 im Katalog-Manifest.", file=sys.stderr)
        return 1
    print(rules_index_proof(password, salt))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
