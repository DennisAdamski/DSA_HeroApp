#!/usr/bin/env python3
"""Validiert die Quelleninventur der Regel- und Katalogtests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


KINDS = {"official", "house_rule", "product_contract"}
STATUSES = {"verified", "conflict"}
CONFLICT_TYPES = {"contradiction", "source_gap", "unresolved"}
PRIORITIES = {"P1", "P2", "P3"}
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
FOLLOW_UP_PATTERN = re.compile(r"^RULE-FIX-\d{3}$")
PLACEHOLDER_PHRASES = (
    "noch nicht vollständig",
    "nicht belegt oder bewusst",
    "noch nicht geprüft",
)
SUMMARY_PLACEHOLDER_PREFIXES = (
    "Regeltestbestand:",
    "Technischer Katalogvertrag:",
)


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
    if isinstance(source.get("checkedOn"), str) and not DATE_PATTERN.match(
        source["checkedOn"]
    ):
        errors.append("Quelle benötigt checkedOn als YYYY-MM-DD")
    return errors


def _text(entry: dict[str, Any], key: str) -> str:
    value = entry.get(key)
    return value.strip() if isinstance(value, str) else ""


def _conflict_errors(path: str, entry: dict[str, Any]) -> list[str]:
    """Prüft einen einzelnen, fachlich abgegrenzten Konflikt."""

    errors: list[str] = []
    if not _text(entry, "conflictKey"):
        errors.append(f"{path}: Konflikt benötigt conflictKey")
    for key in ("finding", "expected", "deviation", "impact"):
        if not _text(entry, key):
            errors.append(f"{path}: Konflikt benötigt {key}")
    finding = _text(entry, "finding").lower()
    if any(phrase in finding for phrase in PLACEHOLDER_PHRASES):
        errors.append(f"{path}: Konflikt ist ein pauschaler Platzhalter")

    conflict_type = entry.get("conflictType")
    if conflict_type not in CONFLICT_TYPES:
        errors.append(f"{path}: ungültiger conflictType {conflict_type!r}")
    if entry.get("priority") not in PRIORITIES:
        errors.append(f"{path}: ungültige priority {entry.get('priority')!r}")

    follow_up = _text(entry, "followUp")
    if not follow_up:
        errors.append(f"{path}: Konflikt benötigt followUp")
    elif not FOLLOW_UP_PATTERN.match(follow_up):
        errors.append(f"{path}: followUp muss RULE-FIX-NNN heißen")

    cases = entry.get("testCases")
    if not isinstance(cases, list) or not cases or not all(
        isinstance(case, str) and case.strip() for case in cases
    ):
        errors.append(f"{path}: Konflikt benötigt testCases")

    if conflict_type == "source_gap":
        terms = entry.get("searchedTerms")
        if not isinstance(terms, list) or not terms or not all(
            isinstance(term, str) and term.strip() for term in terms
        ):
            errors.append(f"{path}: Quellenlücke benötigt searchedTerms")
    elif conflict_type in {"contradiction", "unresolved"}:
        book_rule = entry.get("bookRule")
        if not isinstance(book_rule, list) or not book_rule:
            errors.append(f"{path}: Konflikt benötigt bookRule")
        else:
            for source in book_rule:
                for source_error in _complete_source(source):
                    errors.append(f"{path}: bookRule: {source_error}")
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

    follow_ups: dict[str, set[str]] = {}
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
        elif entry["summary"].startswith(SUMMARY_PLACEHOLDER_PREFIXES):
            errors.append(f"{path}: summary ist ein Platzhalter")
        if kind == "product_contract" and not _text(entry, "rationale"):
            errors.append(f"{path}: product_contract benötigt rationale")

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
            conflicts = entry.get("conflicts")
            if not isinstance(conflicts, list) or not conflicts:
                errors.append(f"{path}: Konflikt benötigt eine Liste conflicts")
                conflicts = []
            for conflict in conflicts:
                if not isinstance(conflict, dict):
                    errors.append(f"{path}: Konflikteintrag ist kein Objekt")
                    continue
                errors.extend(_conflict_errors(path, conflict))
                follow_up = _text(conflict, "followUp")
                if follow_up:
                    follow_ups.setdefault(follow_up, set()).add(
                        _text(conflict, "conflictKey")
                    )
        elif entry.get("conflicts"):
            errors.append(f"{path}: verifizierte Datei darf keine conflicts tragen")
    for follow_up, keys in sorted(follow_ups.items()):
        if len(keys) > 1:
            errors.append(
                f"{follow_up}: Folgeauftrag gehört zu mehreren verschiedenen "
                f"Konflikten ({', '.join(sorted(keys))})"
            )
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
