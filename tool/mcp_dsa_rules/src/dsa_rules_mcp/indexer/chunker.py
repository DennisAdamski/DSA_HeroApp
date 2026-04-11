"""Absatzweises Chunking mit Ziel-Groessen und Seiten-Metadaten."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable, Sequence


MIN_CHUNK_CHARS = 400 * 4       # ca. 400 Tokens
TARGET_CHUNK_CHARS = 600 * 4    # ca. 600 Tokens
MAX_CHUNK_CHARS = 800 * 4       # ca. 800 Tokens


@dataclass(frozen=True)
class PageText:
    page_number: int
    text: str


@dataclass(frozen=True)
class Chunk:
    chunk_index: int
    page_start: int
    page_end: int
    text: str


def split_paragraphs(text: str) -> list[str]:
    """Zerlege einen Seitentext in weiche Absaetze."""

    parts = re.split(r"\n{2,}|\r\n{2,}", text)
    return [part.strip() for part in parts if part.strip()]


def split_sentences(text: str) -> list[str]:
    """Einfache Satz-Trennung fuer deutsche Texte."""

    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    return [sentence.strip() for sentence in sentences if sentence.strip()]


def _flush(
    buffer_parts: list[str],
    page_start: int,
    page_end: int,
    chunks: list[Chunk],
) -> None:
    if not buffer_parts:
        return
    text = "\n\n".join(buffer_parts).strip()
    if not text:
        return
    chunks.append(
        Chunk(
            chunk_index=len(chunks),
            page_start=page_start,
            page_end=page_end,
            text=text,
        )
    )


def chunk_pages(pages: Sequence[PageText]) -> list[Chunk]:
    """Baut Chunks absatzweise mit weicher Satztrennung bei Ueberlaenge."""

    chunks: list[Chunk] = []
    buffer: list[str] = []
    buffer_len = 0
    current_page_start: int | None = None
    current_page_end: int = 0

    def commit() -> None:
        nonlocal buffer, buffer_len, current_page_start, current_page_end
        if current_page_start is None:
            return
        _flush(buffer, current_page_start, current_page_end, chunks)
        buffer = []
        buffer_len = 0
        current_page_start = None
        current_page_end = 0

    for page in pages:
        paragraphs = split_paragraphs(page.text)
        if not paragraphs:
            continue
        for paragraph in paragraphs:
            if len(paragraph) > MAX_CHUNK_CHARS:
                commit()
                for sentence_chunk in _split_oversize_paragraph(paragraph):
                    chunks.append(
                        Chunk(
                            chunk_index=len(chunks),
                            page_start=page.page_number,
                            page_end=page.page_number,
                            text=sentence_chunk,
                        )
                    )
                continue

            prospective = buffer_len + len(paragraph) + 2
            if prospective > MAX_CHUNK_CHARS and buffer_len >= MIN_CHUNK_CHARS:
                commit()

            if current_page_start is None:
                current_page_start = page.page_number
            current_page_end = page.page_number
            buffer.append(paragraph)
            buffer_len += len(paragraph) + 2

            if buffer_len >= TARGET_CHUNK_CHARS:
                commit()

    commit()
    return chunks


def _split_oversize_paragraph(paragraph: str) -> list[str]:
    sentences = split_sentences(paragraph) or [paragraph]
    out: list[str] = []
    current: list[str] = []
    current_len = 0
    for sentence in sentences:
        if current_len + len(sentence) > MAX_CHUNK_CHARS and current:
            out.append(" ".join(current).strip())
            current = []
            current_len = 0
        current.append(sentence)
        current_len += len(sentence) + 1
    if current:
        out.append(" ".join(current).strip())
    return [entry for entry in out if entry]
