from dsa_rules_mcp.indexer.chunker import (
    MAX_CHUNK_CHARS,
    MIN_CHUNK_CHARS,
    TARGET_CHUNK_CHARS,
    Chunk,
    PageText,
    chunk_pages,
    split_paragraphs,
    split_sentences,
)


def _make_page(number: int, paragraphs: list[str]) -> PageText:
    return PageText(page_number=number, text="\n\n".join(paragraphs))


def test_split_paragraphs_respects_blank_lines() -> None:
    text = "Erster Absatz.\n\nZweiter Absatz.\n\n\nDritter Absatz."
    assert split_paragraphs(text) == ["Erster Absatz.", "Zweiter Absatz.", "Dritter Absatz."]


def test_split_sentences_handles_german_punctuation() -> None:
    text = "Das ist Satz eins. Das ist Satz zwei! Und Satz drei?"
    assert split_sentences(text) == [
        "Das ist Satz eins.",
        "Das ist Satz zwei!",
        "Und Satz drei?",
    ]


def test_chunker_keeps_short_pages_together() -> None:
    page = _make_page(1, ["Ein kurzer Absatz.", "Noch ein kurzer Absatz."])
    chunks = chunk_pages([page])
    assert len(chunks) == 1
    assert chunks[0].page_start == 1
    assert chunks[0].page_end == 1
    assert "Ein kurzer Absatz." in chunks[0].text
    assert "Noch ein kurzer Absatz." in chunks[0].text


def test_chunker_flushes_when_target_reached() -> None:
    long_paragraph = ("Satz. " * 200).strip()  # ~1200 Zeichen
    page = _make_page(1, [long_paragraph, long_paragraph, long_paragraph])
    chunks = chunk_pages([page])
    assert len(chunks) >= 2
    assert all(chunk.page_start == 1 for chunk in chunks)


def test_chunker_splits_oversize_paragraph() -> None:
    oversized = "Satz. " * 2000  # ~12000 Zeichen, > MAX_CHUNK_CHARS
    page = _make_page(3, [oversized])
    chunks = chunk_pages([page])
    assert len(chunks) >= 2
    assert all(len(chunk.text) <= MAX_CHUNK_CHARS * 1.1 for chunk in chunks)
    assert all(chunk.page_start == 3 and chunk.page_end == 3 for chunk in chunks)


def test_chunker_tracks_page_range_across_pages() -> None:
    short = "Kurzer Absatz auf Seite {n}."
    pages = [
        _make_page(1, [short.format(n=1)]),
        _make_page(2, [short.format(n=2)]),
        _make_page(3, [short.format(n=3)]),
    ]
    chunks = chunk_pages(pages)
    assert len(chunks) == 1
    assert chunks[0].page_start == 1
    assert chunks[0].page_end == 3


def test_chunk_indexes_are_sequential() -> None:
    pages = [_make_page(i, [f"Absatz auf Seite {i}." * 200]) for i in range(1, 6)]
    chunks = chunk_pages(pages)
    assert [chunk.chunk_index for chunk in chunks] == list(range(len(chunks)))
