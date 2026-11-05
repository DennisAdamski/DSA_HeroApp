#!/usr/bin/env python3
"""Entscheidet, ob geaenderte Pfade die teure Produkt-CI benoetigen."""

from __future__ import annotations

import sys
from collections.abc import Iterable


def has_relevant_changes(paths: Iterable[str]) -> bool:
    """Liefert true, sobald mindestens ein Pfad mehr als Dokumentation ist."""

    for raw_path in paths:
        path = raw_path.strip().replace("\\", "/")
        if not path:
            continue
        if path.startswith("docs/") or path.lower().endswith(".md"):
            continue
        return True
    return False


def main() -> int:
    """Liest einen geaenderten Pfad je Zeile und schreibt true oder false."""

    print("true" if has_relevant_changes(sys.stdin) else "false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
