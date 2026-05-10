#!/usr/bin/env python3
"""
Verschluesselt oder entschluesselt geschuetzte Felder in Katalog-JSON-Dateien.

Verwendung:
    # v1 (Legacy, AES-CBC mit fixem Salt, 10k PBKDF2):
    python tool/encrypt_catalog_fields.py --password "geheim"
    python tool/encrypt_catalog_fields.py --password "geheim" --decrypt

    # v3 (AES-GCM, globaler Salt im Manifest, 100k PBKDF2):
    python tool/encrypt_catalog_fields.py --password "geheim" --format v3
    python tool/encrypt_catalog_fields.py --password "geheim" --format v3 --decrypt

Algorithmen:
- v1: AES-256-CBC mit PBKDF2-Key-Derivation aus festem Salt (Legacy, 10k).
      Verschluesselte Werte: "enc:<base64>".
- v3: AES-256-GCM mit pre-derived Key. Salt wird einmal pro Katalog im
      manifest.json (Top-Level "catalog_salt_v3", base64) gespeichert.
      Verschluesselte Werte: "enc:3:<base64(nonce[12]+ciphertext+tag)>".
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

# --- Konstanten ---

# v1 (Legacy, muss mit catalog_crypto.dart _decryptLegacy uebereinstimmen)
LEGACY_SALT = b'dsa_helden_catalog_salt_2026'
LEGACY_PBKDF2_ITERATIONS = 10000
LEGACY_IV_LENGTH = 16

# v2 (muss mit catalog_crypto.dart _decryptV2 uebereinstimmen)
V2_SALT_LENGTH = 32
V2_NONCE_LENGTH = 12
V2_PBKDF2_ITERATIONS = 100000
V2_MARKER = '2:'

# v3 (muss mit catalog_crypto.dart deriveCatalogKey/encryptCatalogValueV3 uebereinstimmen)
V3_SALT_LENGTH = 32
V3_NONCE_LENGTH = 12
V3_PBKDF2_ITERATIONS = 100000
V3_MARKER = '3:'

# Allgemein
KEY_LENGTH = 32  # 256 Bit
ENCRYPTED_PREFIX = 'enc:'
MANIFEST_NAME = 'manifest.json'
MANIFEST_SALT_KEY = 'catalog_salt_v3'

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
    'vertrautenmagie_rituale.json': {
        'wirkung': 'string',
        'technik': 'string',
    },
}


# --- v1 (Legacy CBC) ---

def derive_key_v1(password: str) -> bytes:
    """Leitet einen 256-Bit AES-Schluessel aus dem Passwort ab (Legacy v1)."""
    return hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        LEGACY_SALT,
        LEGACY_PBKDF2_ITERATIONS,
        dklen=KEY_LENGTH,
    )


def encrypt_value_v1(plaintext: str, key: bytes) -> str:
    """Verschluesselt einen String mit v1-Format ('enc:<base64>')."""
    if not plaintext:
        return plaintext
    iv = os.urandom(LEGACY_IV_LENGTH)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    padded = pad(plaintext.encode('utf-8'), AES.block_size)
    ciphertext = cipher.encrypt(padded)
    combined = iv + ciphertext
    return ENCRYPTED_PREFIX + base64.b64encode(combined).decode('ascii')


def decrypt_value_v1(encrypted: str, key: bytes) -> str | None:
    """Entschluesselt einen v1 'enc:<base64>'-String."""
    payload = encrypted[len(ENCRYPTED_PREFIX):]
    try:
        combined = base64.b64decode(payload)
        if len(combined) <= LEGACY_IV_LENGTH:
            return None
        iv = combined[:LEGACY_IV_LENGTH]
        ciphertext = combined[LEGACY_IV_LENGTH:]
        cipher = AES.new(key, AES.MODE_CBC, iv)
        padded = cipher.decrypt(ciphertext)
        plaintext = unpad(padded, AES.block_size)
        return plaintext.decode('utf-8')
    except Exception:
        return None


# --- v2 (AES-GCM, per-Wert random Salt + Nonce) ---

def decrypt_value_v2(encrypted: str, password: str) -> str | None:
    """Entschluesselt einen v2 'enc:2:<base64>'-String (PBKDF2 pro Wert)."""
    payload = encrypted[len(ENCRYPTED_PREFIX):]
    if not payload.startswith(V2_MARKER):
        return None
    b64 = payload[len(V2_MARKER):]
    try:
        combined = base64.b64decode(b64)
        if len(combined) <= V2_SALT_LENGTH + V2_NONCE_LENGTH + 16:
            return None
        salt = combined[:V2_SALT_LENGTH]
        nonce = combined[V2_SALT_LENGTH:V2_SALT_LENGTH + V2_NONCE_LENGTH]
        body = combined[V2_SALT_LENGTH + V2_NONCE_LENGTH:]
        ciphertext = body[:-16]
        tag = body[-16:]
        key = hashlib.pbkdf2_hmac(
            'sha256',
            password.encode('utf-8'),
            salt,
            V2_PBKDF2_ITERATIONS,
            dklen=KEY_LENGTH,
        )
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        plaintext = cipher.decrypt_and_verify(ciphertext, tag)
        return plaintext.decode('utf-8')
    except Exception:
        return None


# --- v3 (AES-GCM, globaler Salt) ---

def derive_key_v3(password: str, salt: bytes) -> bytes:
    """Leitet einen 256-Bit AES-Schluessel ab (v3, 100k PBKDF2-HMAC-SHA256)."""
    return hashlib.pbkdf2_hmac(
        'sha256',
        password.encode('utf-8'),
        salt,
        V3_PBKDF2_ITERATIONS,
        dklen=KEY_LENGTH,
    )


def encrypt_value_v3(plaintext: str, key: bytes) -> str:
    """Verschluesselt einen String mit v3-Format ('enc:3:<base64>')."""
    if not plaintext:
        return plaintext
    nonce = os.urandom(V3_NONCE_LENGTH)
    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    ciphertext, tag = cipher.encrypt_and_digest(plaintext.encode('utf-8'))
    combined = nonce + ciphertext + tag
    return ENCRYPTED_PREFIX + V3_MARKER + base64.b64encode(combined).decode('ascii')


def decrypt_value_v3(encrypted: str, key: bytes) -> str | None:
    """Entschluesselt einen v3 'enc:3:<base64>'-String."""
    payload = encrypted[len(ENCRYPTED_PREFIX):]
    if not payload.startswith(V3_MARKER):
        return None
    b64 = payload[len(V3_MARKER):]
    try:
        combined = base64.b64decode(b64)
        if len(combined) <= V3_NONCE_LENGTH + 16:
            return None
        nonce = combined[:V3_NONCE_LENGTH]
        # GCM-Tag ist die letzten 16 Bytes
        ciphertext = combined[V3_NONCE_LENGTH:-16]
        tag = combined[-16:]
        cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
        plaintext = cipher.decrypt_and_verify(ciphertext, tag)
        return plaintext.decode('utf-8')
    except Exception:
        return None


# --- Format-Dispatch ---

def is_encrypted(value) -> bool:
    return isinstance(value, str) and value.startswith(ENCRYPTED_PREFIX)


def encrypt_value(plaintext: str, key: bytes, fmt: str) -> str:
    if fmt == 'v3':
        return encrypt_value_v3(plaintext, key)
    return encrypt_value_v1(plaintext, key)


def decrypt_value(encrypted: str, key: bytes, password: str | None = None) -> str | None:
    """Erkennt das Format anhand des Praefixes und delegiert.

    [key] wird passend zum Wert-Format verwendet (v3-key fuer v3-Werte).
    v1 leitet den Schluessel intern aus [password] ab (Legacy-Salt).
    v2 nutzt per-Wert-Salt und benoetigt ebenfalls [password].
    Wenn ein anderes Format als das passende auftritt und [password] fehlt,
    liefert die Funktion `None`.
    """
    if not encrypted.startswith(ENCRYPTED_PREFIX):
        return encrypted
    payload = encrypted[len(ENCRYPTED_PREFIX):]
    if payload.startswith(V3_MARKER):
        return decrypt_value_v3(encrypted, key)
    if payload.startswith(V2_MARKER):
        if password is None:
            return None
        return decrypt_value_v2(encrypted, password)
    # v1-Praefix (`enc:` ohne Versions-Marker)
    if password is None:
        # Nur dann sicher dass `key` bereits ein v1-Key ist, wenn kein Password mitgegeben.
        return decrypt_value_v1(encrypted, key)
    return decrypt_value_v1(encrypted, derive_key_v1(password))


# --- Manifest-Salt-Handling ---

def load_or_create_manifest_salt(catalog_dir: Path, create_if_missing: bool) -> bytes | None:
    """Liest den v3-Salt aus manifest.json oder generiert einen neuen."""
    manifest_path = catalog_dir / MANIFEST_NAME
    if not manifest_path.is_file():
        print(f'Fehler: {MANIFEST_NAME} nicht gefunden in {catalog_dir}.', file=sys.stderr)
        sys.exit(1)
    with open(manifest_path, 'r', encoding='utf-8-sig') as f:
        manifest = json.load(f)

    raw = manifest.get(MANIFEST_SALT_KEY)
    if isinstance(raw, str) and raw.strip():
        try:
            salt = base64.b64decode(raw)
            if len(salt) >= 16:
                return salt
        except Exception:
            pass

    if not create_if_missing:
        return None

    salt = os.urandom(V3_SALT_LENGTH)
    manifest[MANIFEST_SALT_KEY] = base64.b64encode(salt).decode('ascii')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'  Neuer v3-Salt generiert und in {MANIFEST_NAME} gespeichert.')
    return salt


# --- Datei-Verarbeitung ---

def process_file(
    file_path: Path,
    fields: dict[str, str],
    key: bytes,
    decrypt_mode: bool,
    fmt: str,
    migrate_password: str | None = None,
) -> int:
    """Verarbeitet eine einzelne JSON-Datei. Gibt die Anzahl geaenderter Felder zurueck.

    Wenn [migrate_password] gesetzt ist, werden bestehende `enc:`-Werte
    (auch v1/v2) zuerst entschluesselt und dann im Zielformat re-encryptet.
    """
    with open(file_path, 'r', encoding='utf-8-sig') as f:
        data = json.load(f)

    # Eintraege ermitteln: Top-Level-Array oder verschachteltes 'rituals'-Array.
    if isinstance(data, list):
        entries = data
    elif isinstance(data, dict) and isinstance(data.get('rituals'), list):
        entries = data['rituals']
    else:
        print(f'  Warnung: {file_path.name} hat kein bekanntes Format, uebersprungen.', file=sys.stderr)
        return 0

    changed = 0
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        for field_name, field_type in fields.items():
            value = entry.get(field_name)
            if value is None:
                continue

            if decrypt_mode:
                if field_type == 'string' and is_encrypted(value):
                    result = decrypt_value(value, key)
                    if result is not None:
                        entry[field_name] = result
                        changed += 1
                    else:
                        print(
                            f'  Warnung: Entschluesselung fehlgeschlagen fuer '
                            f'{entry.get("id", entry.get("name", "?"))}:{field_name}',
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
                                f'{entry.get("id", entry.get("name", "?"))}:{field_name}',
                                file=sys.stderr,
                            )
                    else:
                        print(
                            f'  Warnung: Entschluesselung fehlgeschlagen fuer '
                            f'{entry.get("id", entry.get("name", "?"))}:{field_name}',
                            file=sys.stderr,
                        )
            else:
                # Migrationspfad: bestehenden enc:-Wert mit altem Format
                # entschluesseln, dann im Zielformat re-encrypten.
                if migrate_password and is_encrypted(value):
                    plain = decrypt_value(value, key, password=migrate_password)
                    if plain is None:
                        print(
                            f'  Warnung: Migration fehlgeschlagen fuer '
                            f'{entry.get("id", entry.get("name", "?"))}:{field_name}',
                            file=sys.stderr,
                        )
                        continue
                    if field_type == 'list':
                        try:
                            json.loads(plain)  # validate JSON
                        except json.JSONDecodeError:
                            print(
                                f'  Warnung: Re-Encrypt-JSON ungueltig fuer '
                                f'{entry.get("id", entry.get("name", "?"))}:{field_name}',
                                file=sys.stderr,
                            )
                            continue
                    entry[field_name] = encrypt_value(plain, key, fmt)
                    changed += 1
                    continue

                if field_type == 'string' and isinstance(value, str) and not is_encrypted(value):
                    if value.strip():
                        entry[field_name] = encrypt_value(value, key, fmt)
                        changed += 1
                elif field_type == 'list' and isinstance(value, list):
                    if value:
                        json_str = json.dumps(value, ensure_ascii=False)
                        entry[field_name] = encrypt_value(json_str, key, fmt)
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
        '--format',
        choices=['v1', 'v3'],
        default='v1',
        help='Krypto-Format. v1 = AES-CBC Legacy, v3 = AES-GCM mit globalem Salt.',
    )
    parser.add_argument(
        '--catalog-dir',
        default=None,
        help='Pfad zum Katalogverzeichnis (Standard: assets/catalogs/house_rules_v1/).',
    )
    parser.add_argument(
        '--migrate',
        action='store_true',
        help='Bestehende enc:-Werte (v1/v2/v3) entschluesseln und im --format Zielformat re-encrypten.',
    )
    args = parser.parse_args()

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

    if args.format == 'v3':
        salt = load_or_create_manifest_salt(
            catalog_dir,
            create_if_missing=not args.decrypt,
        )
        if salt is None:
            print(
                f'Fehler: kein {MANIFEST_SALT_KEY} im Manifest und Decrypt-Modus '
                f'(kann nicht generieren).',
                file=sys.stderr,
            )
            sys.exit(1)
        key = derive_key_v3(args.password, salt)
    else:
        key = derive_key_v1(args.password)

    mode = 'Entschluesseln' if args.decrypt else 'Verschluesseln'
    print(f'{mode} ({args.format}) in {catalog_dir}')

    total_changed = 0
    for filename, fields in PROTECTED_FIELDS.items():
        file_path = catalog_dir / filename
        if not file_path.is_file():
            print(f'  Warnung: {filename} nicht gefunden, uebersprungen.')
            continue
        count = process_file(
            file_path,
            fields,
            key,
            args.decrypt,
            args.format,
            migrate_password=args.password if args.migrate else None,
        )
        print(f'  {filename}: {count} Felder geaendert.')
        total_changed += count

    print(f'Fertig. {total_changed} Felder insgesamt geaendert.')


if __name__ == '__main__':
    main()
