#!/usr/bin/env python3
"""
Verschluesselt oder entschluesselt geschuetzte Felder in Katalog-JSON-Dateien.

Verwendung:
    python tool/encrypt_catalog_fields.py --password "geheim"
    python tool/encrypt_catalog_fields.py --password "geheim" --decrypt

Algorithmus: AES-256-CBC mit PBKDF2-Key-Derivation (identisch zur Dart-App).
Verschluesselte Felder werden mit dem Praefix "enc:" markiert.
"""

import argparse
import base64
import hashlib
import json
import os
import sys
from pathlib import Path

# pip install pycryptodome
try:
    from Crypto.Cipher import AES
    from Crypto.Util.Padding import pad, unpad
except ImportError:
    print(
        'Fehler: pycryptodome ist nicht installiert.\n'
        'Installieren mit: pip install pycryptodome',
        file=sys.stderr,
    )
    sys.exit(1)

# --- Konstanten (muessen mit catalog_crypto.dart uebereinstimmen) ---

SALT = b'dsa_helden_catalog_salt_2026'
PBKDF2_ITERATIONS = 10000
KEY_LENGTH = 32  # 256 Bit
IV_LENGTH = 16
ENCRYPTED_PREFIX = 'enc:'

# --- Geschuetzte Felder pro Katalogdatei ---

PROTECTED_FIELDS: dict[str, dict[str, str]] = {
    'manoever.json': {
        'erklarung_lang': 'string',
    },
    'kampf_sonderfertigkeiten.json': {
        'erklarung_lang': 'string',
    },
    'magie.json': {
        'wirkung': 'string',
        'variants': 'list',
    },
}


def derive_key(password: str) -> bytes:
    """Leitet einen 256-Bit AES-Schluessel aus dem Passwort ab (PBKDF2-HMAC-SHA256)."""
    return hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        SALT,
        PBKDF2_ITERATIONS,
        dklen=KEY_LENGTH,
    )


def encrypt_value(plaintext: str, key: bytes) -> str:
    """Verschluesselt einen String und gibt 'enc:<base64>' zurueck."""
    if not plaintext:
        return plaintext
    iv = os.urandom(IV_LENGTH)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded = pad(plaintext.encode('utf-8'), AES.block_size)
    ciphertext = cipher.encrypt(padded)
    combined = iv + ciphertext
    return ENCRYPTED_PREFIX + base64.b64encode(combined).decode('ascii')


def decrypt_value(encrypted: str, key: bytes) -> str | None:
    """Entschluesselt einen 'enc:<base64>'-String."""
    if not encrypted.startswith(ENCRYPTED_PREFIX):
        return encrypted
    payload = encrypted[len(ENCRYPTED_PREFIX):]
    try:
        combined = base64.b64decode(payload)
        if len(combined) <= IV_LENGTH:
            return None
        iv = combined[:IV_LENGTH]
        ciphertext = combined[IV_LENGTH:]
        cipher = AES.new(key, AES.MODE_CBC, iv)
        padded = cipher.decrypt(ciphertext)
        plaintext = unpad(padded, AES.block_size)
        return plaintext.decode('utf-8')
    except Exception:
        return None


def is_encrypted(value) -> bool:
    return isinstance(value, str) and value.startswith(ENCRYPTED_PREFIX)


def process_file(
    file_path: Path,
    fields: dict[str, str],
    key: bytes,
    decrypt_mode: bool,
) -> int:
    """Verarbeitet eine einzelne JSON-Datei. Gibt die Anzahl geaenderter Felder zurueck."""
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    if not isinstance(data, list):
        print(f'  Warnung: {file_path.name} ist kein Array, uebersprungen.', file=sys.stderr)
        return 0

    changed = 0
    for entry in data:
        if not isinstance(entry, dict):
            continue
        for field_name, field_type in fields.items():
            value = entry.get(field_name)
            if value is None:
                continue

            if decrypt_mode:
                # Entschluesseln
                if field_type == 'string' and is_encrypted(value):
                    result = decrypt_value(value, key)
                    if result is not None:
                        entry[field_name] = result
                        changed += 1
                    else:
                        print(
                            f'  Warnung: Entschluesselung fehlgeschlagen fuer '
                            f'{entry.get("id", "?")}:{field_name}',
                            file=sys.stderr,
                        )
                elif field_type == 'list' and is_encrypted(value):
                    result = decrypt_value(value, key)
                    if result is not None:
                        try:
                            entry[field_name] = json.loads(result)
                            changed += 1
                        except json.JSONDecodeError:
                            print(
                                f'  Warnung: JSON-Parse fehlgeschlagen fuer '
                                f'{entry.get("id", "?")}:{field_name}',
                                file=sys.stderr,
                            )
                    else:
                        print(
                            f'  Warnung: Entschluesselung fehlgeschlagen fuer '
                            f'{entry.get("id", "?")}:{field_name}',
                            file=sys.stderr,
                        )
            else:
                # Verschluesseln
                if field_type == 'string' and isinstance(value, str) and not is_encrypted(value):
                    if value.strip():
                        entry[field_name] = encrypt_value(value, key)
                        changed += 1
                elif field_type == 'list' and isinstance(value, list):
                    if value:
                        json_str = json.dumps(value, ensure_ascii=False)
                        entry[field_name] = encrypt_value(json_str, key)
                        changed += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

    return changed


def main():
    parser = argparse.ArgumentParser(
        description='Verschluesselt oder entschluesselt geschuetzte Katalogfelder.',
    )
    parser.add_argument(
        '--password',
        required=True,
        help='Passwort fuer die AES-Verschluesselung.',
    )
    parser.add_argument(
        '--decrypt',
        action='store_true',
        help='Felder entschluesseln statt verschluesseln.',
    )
    parser.add_argument(
        '--catalog-dir',
        default=None,
        help='Pfad zum Katalogverzeichnis (Standard: assets/catalogs/house_rules_v1/).',
    )
    args = parser.parse_args()

    # Projektverzeichnis ermitteln
    script_dir = Path(__file__).resolve().parent
    project_dir = script_dir.parent
    catalog_dir = (
        Path(args.catalog_dir)
        if args.catalog_dir
        else project_dir / 'assets' / 'catalogs' / 'house_rules_v1'
    )

    if not catalog_dir.is_dir():
        print(f'Fehler: Katalogverzeichnis nicht gefunden: {catalog_dir}', file=sys.stderr)
        sys.exit(1)

    key = derive_key(args.password)
    mode = 'Entschluesseln' if args.decrypt else 'Verschluesseln'
    print(f'{mode} in {catalog_dir}')

    total_changed = 0
    for filename, fields in PROTECTED_FIELDS.items():
        file_path = catalog_dir / filename
        if not file_path.is_file():
            print(f'  Warnung: {filename} nicht gefunden, uebersprungen.')
            continue
        count = process_file(file_path, fields, key, args.decrypt)
        print(f'  {filename}: {count} Felder geaendert.')
        total_changed += count

    print(f'Fertig. {total_changed} Felder insgesamt geaendert.')


if __name__ == '__main__':
    main()
