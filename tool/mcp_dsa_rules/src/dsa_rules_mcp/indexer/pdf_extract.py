"""PDF-Extraktion mit PyMuPDF inklusive einfacher Layout-Rekonstruktion."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ExtractedPage:
    page_number: int
    text: str


def extract_pages(pdf_path: Path) -> list[ExtractedPage]:
    """Liest ein PDF und liefert gereinigten Text pro Seite.

    Verwendet PyMuPDFs Block-Extraktion und sortiert nach (Spalte, y, x),
    damit zweispaltiger Satz nicht seitenweise ineinander rutscht. Kopf- und
    Fusszeilen im oberen/unteren ~5%-Bereich werden entfernt.
    """

    import fitz  # type: ignore[import-not-found]

    pages: list[ExtractedPage] = []
    with fitz.open(str(pdf_path)) as document:
        for page_index, page in enumerate(document, start=1):
            text = _extract_page_text(page)
            pages.append(ExtractedPage(page_number=page_index, text=text))
    return pages


def _extract_page_text(page) -> str:  # type: ignore[no-untyped-def]
    width = float(page.rect.width)
    height = float(page.rect.height)
    header_limit = height * 0.05
    footer_limit = height * 0.95
    mid_x = width / 2.0

    blocks = page.get_text("blocks") or []
    cleaned: list[tuple[int, float, float, str]] = []
    for block in blocks:
        if len(block) < 5:
            continue
        x0, y0, _x1, _y1, text = block[0], block[1], block[2], block[3], block[4]
        if not isinstance(text, str):
            continue
        normalized = text.strip()
        if not normalized:
            continue
        if y0 < header_limit or y0 > footer_limit:
            continue
        column = 0 if x0 < mid_x else 1
        cleaned.append((column, float(y0), float(x0), normalized))

    cleaned.sort(key=lambda item: (item[0], item[1], item[2]))
    lines = [entry[3] for entry in cleaned]
    return "\n".join(lines)


def count_pages(pdf_path: Path) -> int:
    import fitz  # type: ignore[import-not-found]

    with fitz.open(str(pdf_path)) as document:
        return int(document.page_count)
