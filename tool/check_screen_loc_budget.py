#!/usr/bin/env python3
"""Checks LOC budgets for screen Dart files."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Enforce a max LOC budget for Dart screen files."
    )
    parser.add_argument(
        "--root",
        default="lib/ui/screens",
        help="Root directory to scan (default: lib/ui/screens).",
    )
    parser.add_argument(
        "--max-lines",
        type=int,
        default=700,
        help="Maximum allowed line count per file (default: 700).",
    )
    parser.add_argument(
        "--glob",
        default="*.dart",
        help="Glob pattern under root (default: *.dart).",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="Scan recursively (default: only files directly under --root).",
    )
    return parser.parse_args()


def count_lines(path: Path) -> int:
    with path.open("r", encoding="utf-8") as handle:
        return sum(1 for _ in handle)


def main() -> int:
    args = parse_args()
    root = Path(args.root)
    if not root.exists():
        print(f"[loc-budget] root not found: {root}")
        return 2

    iterator = root.rglob(args.glob) if args.recursive else root.glob(args.glob)
    files = sorted(path for path in iterator if path.is_file())
    if not files:
        print(f"[loc-budget] no files found for {root} ({args.glob})")
        return 0

    violations: list[tuple[Path, int]] = []
    for path in files:
        lines = count_lines(path)
        if lines > args.max_lines:
            violations.append((path, lines))

    if violations:
        print(
            f"[loc-budget] {len(violations)} file(s) exceed {args.max_lines} lines:"
        )
        for path, lines in violations:
            print(f"  - {path.as_posix()}: {lines}")
        return 1

    print(
        f"[loc-budget] OK: {len(files)} file(s) within <= {args.max_lines} lines in {root.as_posix()}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
