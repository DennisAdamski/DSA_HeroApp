import argparse
import re
from pathlib import Path


# Greift bewusst breit auf alle '.dart'-Stringliterale, damit auch
# conditional imports mit mehreren Pfaden erkannt werden.
IMPORT_RE = re.compile(r"'([^']+\.dart)'")


def resolve_target(repo_root: Path, source: Path, uri: str) -> Path | None:
    if uri.startswith("dart:"):
        return None
    if uri.startswith("package:dsa_heldenverwaltung/"):
        rel = uri.removeprefix("package:dsa_heldenverwaltung/")
        target = repo_root / "lib" / rel
        return target if target.exists() else None
    if uri.startswith("package:"):
        return None
    target = (source.parent / uri).resolve()
    return target if target.exists() else None


def collect_dart_files(root: Path, folders: list[str]) -> list[Path]:
    files: list[Path] = []
    for folder in folders:
        base = root / folder
        if base.exists():
            files.extend(base.rglob("*.dart"))
    return files


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Report unreferenced lib/*.dart files for this project."
    )
    parser.add_argument(
        "--repo-root",
        default=".",
        help="Path to repository root (default: current directory)",
    )
    parser.add_argument(
        "--entrypoint",
        default="lib/main.dart",
        help="Dart entrypoint that is considered referenced by default",
    )
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    all_sources = collect_dart_files(root, ["lib", "test"])
    lib_files = collect_dart_files(root, ["lib"])

    referenced: set[Path] = set()
    for source in all_sources:
        try:
            text = source.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = source.read_text(encoding="latin-1")
        for uri in IMPORT_RE.findall(text):
            target = resolve_target(root, source, uri)
            if target is not None:
                referenced.add(target.resolve())

    entrypoint = (root / args.entrypoint).resolve()
    unreferenced = [
        p for p in sorted((f.resolve() for f in lib_files))
        if p not in referenced and p != entrypoint
    ]

    print(f"Repo root: {root}")
    print(f"Referenced lib files: {len(referenced)}")
    print(f"Total lib files: {len(lib_files)}")
    print(f"Unreferenced lib files: {len(unreferenced)}")
    for file in unreferenced:
        print(file.relative_to(root).as_posix())


if __name__ == "__main__":
    main()
