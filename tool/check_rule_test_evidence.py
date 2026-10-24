#!/usr/bin/env python3
"""Validiert die Quelleninventur der Regel- und Katalogtests."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


KINDS = {"official", "house_rule", "product_contract"}
STATUSES = {"verified", "conflict"}


def _test_paths(root: Path) -> set[str]:
    paths: set[str] = set()
    for folder in (root / "test" / "rules", root / "test" / "catalog"):
        if not folder.exists():
            continue
        for pattern in ("*_test.dart", "*_cases.dart"):
            paths.update(
                path.relative_to(root).as_posix()
                for path in folder.rglob(pattern)
            )
    return paths


def _complete_source(source: Any) -> list[str]:
    if not isinstance(source, dict):
        return ["Quelle ist kein Objekt"]
    errors: list[str] = []
    for key in ("title", "pages", "checkedOn"):
        if not isinstance(source.get(key), str) or not source[key].strip():
            errors.append(f"Quelle benötigt {key}")
    chunks = source.get("mcpChunks")
    if not isinstance(chunks, list) or not chunks or not all(
        isinstance(chunk, int) and chunk > 0 for chunk in chunks
    ):
        errors.append("Quelle benötigt positive mcpChunks")
    return errors


def validate_inventory(root: Path, inventory_path: Path) -> list[str]:
    """Liefert alle strukturellen Fehler einer Regeltest-Inventur."""

    payload = json.loads(inventory_path.read_text(encoding="utf-8"))
    files = payload.get("files")
    if payload.get("schemaVersion") != 1 or not isinstance(files, dict):
        return ["Inventur benötigt schemaVersion 1 und ein files-Objekt"]

    expected = _test_paths(root)
    registered = set(files)
    errors = [
        f"nicht inventarisiert: {path}" for path in sorted(expected - registered)
    ]
    errors.extend(
        f"veralteter Pfad: {path}" for path in sorted(registered - expected)
    )

    for path in sorted(expected & registered):
        entry = files[path]
        if not isinstance(entry, dict):
            errors.append(f"{path}: Eintrag ist kein Objekt")
            continue
        kind = entry.get("kind")
        status = entry.get("status")
        if kind not in KINDS:
            errors.append(f"{path}: ungültige Art {kind!r}")
        if status not in STATUSES:
            errors.append(f"{path}: ungültiger Status {status!r}")
        if not isinstance(entry.get("summary"), str) or not entry["summary"].strip():
            errors.append(f"{path}: summary fehlt")

        sources = entry.get("sources")
        if not isinstance(sources, list):
            errors.append(f"{path}: sources muss eine Liste sein")
            sources = []
        if status == "verified" and kind in {"official", "house_rule"}:
            if not sources:
                errors.append(f"{path}: verifizierte Regel benötigt eine Quelle")
            for source in sources:
                for source_error in _complete_source(source):
                    errors.append(f"{path}: {source_error}")
        if status == "conflict":
            if not isinstance(entry.get("finding"), str) or not entry[
                "finding"
            ].strip():
                errors.append(f"{path}: Konflikt benötigt finding")
            if not isinstance(entry.get("followUp"), str) or not entry[
                "followUp"
            ].strip():
                errors.append(f"{path}: Konflikt benötigt followUp")
    return errors


def main() -> int:
    """Prüft standardmäßig die Inventur des aktuellen Repositorys."""

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument(
        "--inventory",
        type=Path,
        default=Path(__file__).with_name("rule_test_evidence.json"),
    )
    args = parser.parse_args()
    errors = validate_inventory(args.root.resolve(), args.inventory.resolve())
    if errors:
        for error in errors:
            print(error)
        return 1
    file_count = len(json.loads(args.inventory.read_text(encoding="utf-8"))["files"])
    print(f"Regeltest-Inventur gültig: {file_count} Dateien.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
