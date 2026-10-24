#!/usr/bin/env python3
"""Verteilt Flutter-Testdateien deterministisch auf unabhaengige CI-Shards."""

from __future__ import annotations

import argparse
from pathlib import Path


def test_files_for_shard(
    root: Path,
    *,
    total_shards: int,
    shard_index: int,
) -> list[str]:
    """Liefert den disjunkten, nach Dateinamen verteilten Testbestand."""

    if total_shards <= 0:
        raise ValueError("total_shards muss positiv sein")
    if not 0 <= shard_index < total_shards:
        raise ValueError("shard_index liegt ausserhalb der Shards")

    files = sorted(
        path.relative_to(root).as_posix()
        for path in (root / "test").rglob("*_test.dart")
    )
    return files[shard_index::total_shards]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument("--total-shards", type=int, required=True)
    parser.add_argument("--shard-index", type=int, required=True)
    args = parser.parse_args()

    try:
        files = test_files_for_shard(
            args.root.resolve(),
            total_shards=args.total_shards,
            shard_index=args.shard_index,
        )
    except ValueError as error:
        parser.error(str(error))
    print(*files, sep="\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
