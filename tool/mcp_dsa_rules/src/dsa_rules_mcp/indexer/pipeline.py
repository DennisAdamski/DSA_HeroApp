"""Inkrementelle Indexierungspipeline fuer alle Quellen."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Sequence

from dsa_rules_mcp.config import McpConfig, SourceConfig
from dsa_rules_mcp.indexer.chunker import Chunk, PageText, chunk_pages
from dsa_rules_mcp.indexer.embedder import Embedder, embedding_to_bytes
from dsa_rules_mcp.indexer.pdf_extract import ExtractedPage, extract_pages
from dsa_rules_mcp.store.db import (
    delete_source,
    delete_source_by_path,
    get_source_by_path,
    insert_chunk,
    insert_source,
    list_sources,
    set_embedding_model,
    store_embedding,
)


@dataclass
class RefreshStats:
    processed: list[str] = field(default_factory=list)
    updated: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)
    removed: list[str] = field(default_factory=list)
    errors: list[tuple[str, str]] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "added": self.processed,
            "updated": self.updated,
            "skipped": self.skipped,
            "removed": self.removed,
            "errors": [{"path": path, "error": message} for path, message in self.errors],
            "totals": {
                "added": len(self.processed),
                "updated": len(self.updated),
                "skipped": len(self.skipped),
                "removed": len(self.removed),
                "errors": len(self.errors),
            },
        }


def sha256_of_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def derive_book_title(pdf_path: Path) -> str:
    """Buchtitel ableiten. Sidecar `<pdf>.meta.json` hat Vorrang."""

    sidecar = pdf_path.with_suffix(pdf_path.suffix + ".meta.json")
    if sidecar.is_file():
        try:
            payload = json.loads(sidecar.read_text(encoding="utf-8"))
            title = payload.get("title")
            if isinstance(title, str) and title.strip():
                return title.strip()
        except (OSError, json.JSONDecodeError):
            pass
    return pdf_path.stem


def _pages_for_chunking(pages: Sequence[ExtractedPage]) -> list[PageText]:
    return [PageText(page_number=page.page_number, text=page.text) for page in pages]


def refresh_index(
    connection: sqlite3.Connection,
    config: McpConfig,
    *,
    embedder: Embedder,
    source_filter: str | None = None,
    force: bool = False,
    progress: Callable[[str], None] | None = None,
) -> RefreshStats:
    """Scannt Quellen-Ordner und aktualisiert den Index inkrementell."""

    stats = RefreshStats()
    set_embedding_model(connection, config.embedding_model_name)
    now = datetime.now(timezone.utc).isoformat()

    targets: list[SourceConfig] = []
    for source in config.sources:
        if source_filter and source.id != source_filter:
            continue
        targets.append(source)

    known_paths_by_category: dict[str, set[str]] = {}
    for row in list_sources(connection, [target.id for target in targets] or None):
        known_paths_by_category.setdefault(row.category, set()).add(row.path)

    for target in targets:
        seen_paths: set[str] = set()
        if not target.exists:
            if progress:
                progress(f"[warn] Quelle fehlt: {target.id} -> {target.path}")
            removed = known_paths_by_category.get(target.id, set())
            for path in removed:
                delete_source_by_path(connection, path)
                stats.removed.append(path)
            connection.commit()
            continue

        for pdf_path in sorted(target.path.rglob("*.pdf")):
            abs_path = str(pdf_path.resolve())
            seen_paths.add(abs_path)
            try:
                mtime = pdf_path.stat().st_mtime
                existing = get_source_by_path(connection, abs_path)
                if not force and existing is not None and abs(existing.mtime - mtime) < 1e-6:
                    stats.skipped.append(abs_path)
                    continue

                file_hash = sha256_of_file(pdf_path)
                if not force and existing is not None and existing.sha256 == file_hash:
                    stats.skipped.append(abs_path)
                    continue

                if progress:
                    action = "update" if existing else "index"
                    progress(f"[{action}] {target.id}: {pdf_path.name}")

                pages = extract_pages(pdf_path)
                chunk_objects = chunk_pages(_pages_for_chunking(pages))
                if not chunk_objects:
                    if progress:
                        progress(f"[warn] Keine Text-Chunks gefunden: {pdf_path.name}")
                    continue

                if existing is not None:
                    delete_source(connection, existing.id)

                source_id = insert_source(
                    connection,
                    category=target.id,
                    path=abs_path,
                    title=derive_book_title(pdf_path),
                    mtime=mtime,
                    sha256=file_hash,
                    page_count=len(pages),
                    indexed_at=now,
                )

                chunk_ids: list[int] = []
                texts: list[str] = []
                for chunk in chunk_objects:
                    chunk_id = insert_chunk(
                        connection,
                        source_id=source_id,
                        chunk_index=chunk.chunk_index,
                        page_start=chunk.page_start,
                        page_end=chunk.page_end,
                        text=chunk.text,
                    )
                    chunk_ids.append(chunk_id)
                    texts.append(chunk.text)

                vectors = embedder.encode_many(texts)
                for chunk_id, vector in zip(chunk_ids, vectors):
                    store_embedding(
                        connection,
                        chunk_id=chunk_id,
                        dim=vector.shape[0],
                        embedding_bytes=embedding_to_bytes(vector),
                    )

                connection.commit()
                if existing is None:
                    stats.processed.append(abs_path)
                else:
                    stats.updated.append(abs_path)
            except Exception as exc:  # pragma: no cover - defensive
                connection.rollback()
                stats.errors.append((abs_path, str(exc)))
                if progress:
                    progress(f"[error] {pdf_path.name}: {exc}")

        for path in known_paths_by_category.get(target.id, set()) - seen_paths:
            delete_source_by_path(connection, path)
            stats.removed.append(path)
            if progress:
                progress(f"[remove] {target.id}: {path}")
        connection.commit()

    return stats
