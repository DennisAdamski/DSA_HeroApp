from __future__ import annotations

import json
from pathlib import Path

from dsa_rules_mcp.indexer.pdf_extract import ExtractedPage
from dsa_rules_mcp.tools.compare_hausregeln import (
    diff_sentences,
    document_sentences,
    load_catalog_entries,
    match_entries,
    normalize_stem,
)


def _sentences(*pages: str):
    return document_sentences([ExtractedPage(page_number=i + 1, text=t) for i, t in enumerate(pages)])


def test_normalize_stem_ignores_copy_suffix() -> None:
    assert normalize_stem(Path("Epische Stufen (1).pdf")) == normalize_stem(Path("epische  stufen.pdf"))


def test_reflow_and_hyphenation_are_not_changes() -> None:
    old = _sentences("Der Held erhält +1 LeP pro Stufe. Wunden wir-\nken auf Proben.")
    new = _sentences("Der Held erhält\n+1 LeP pro Stufe.", "Wunden wirken auf Proben.")
    assert diff_sentences(old, new) == []


def test_detects_added_changed_removed() -> None:
    old = _sentences("Satz eins bleibt. Satz zwei alt. Satz drei fällt weg. Ende hier.")
    new = _sentences("Satz eins bleibt. Satz zwei neu. Ende hier. Ganz neuer Satz.")
    ops = [(h["op"], h["old_text"], h["new_text"]) for h in diff_sentences(old, new)]
    assert ops == [
        ("changed", "Satz zwei alt. Satz drei fällt weg.", "Satz zwei neu."),
        ("added", "", "Ganz neuer Satz."),
    ]


def test_moved_section_is_not_a_change() -> None:
    old = _sentences("Kapitel A beginnt. Berserkerfinesse erlaubt Manöver im Rausch. Kapitel B beginnt.")
    new = _sentences("Kapitel A beginnt. Kapitel B beginnt.", "Anhang. Berserkerfinesse erlaubt Manöver im Rausch.")
    assert [(h["op"], h["new_text"]) for h in diff_sentences(old, new)] == [("added", "Anhang.")]


def test_catalog_matches_whole_words_and_skips_manifest_id(tmp_path: Path) -> None:
    catalog = tmp_path / "assets" / "catalogs" / "house_rules_v1"
    (catalog / "packs" / "p1").mkdir(parents=True)
    (catalog / "manoever.json").write_text(
        json.dumps([{"id": "man_binden", "name": "Binden"}, {"id": "man_tritt", "name": "Tritt"}]),
        encoding="utf-8",
    )
    (catalog / "packs" / "p1" / "manifest.json").write_text(
        json.dumps({"id": "p1", "name": "Paket", "patches": [{"addEntries": [{"id": "ksf_x", "name": "Eisenhagel"}]}]}),
        encoding="utf-8",
    )
    entries = load_catalog_entries(catalog, tmp_path)
    assert {e.id for e in entries} == {"man_binden", "man_tritt", "ksf_x"}

    hits = match_entries("Binden und SF Eisenhagel; Auftritt zählt nicht.", entries)
    assert [(e.id, e.pack) for e in hits] == [("ksf_x", "p1"), ("man_binden", None)]
