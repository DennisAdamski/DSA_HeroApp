from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest

from dsa_rules_mcp.config import McpConfig, SourceConfig
from dsa_rules_mcp.indexer import pipeline
from dsa_rules_mcp.indexer.pdf_extract import ExtractedPage
from dsa_rules_mcp.store.db import open_database
from dsa_rules_mcp.store.search import hybrid_search, reciprocal_rank_fusion
from dsa_rules_mcp.tools.search_rules import run_search_rules


class FakeEmbedder:
    def __init__(self, dim: int = 4) -> None:
        self._dim = dim

    @property
    def dim(self) -> int:
        return self._dim

    def encode_many(self, texts, *, batch_size: int = 32) -> np.ndarray:  # noqa: ARG002
        matrix = np.zeros((len(texts), self._dim), dtype=np.float32)
        for row, text in enumerate(texts):
            base = float(sum(ord(character) for character in text[:32]) % 13)
            for column in range(self._dim):
                matrix[row, column] = base + column
        return matrix

    def encode_one(self, text: str) -> np.ndarray:
        return self.encode_many([text])[0]


def _write_fake_pdf(path: Path, payload: bytes) -> None:
    path.write_bytes(b"%PDF-1.4\n" + payload + b"\n%%EOF")


def _make_config(tmp_path: Path, regelbuecher_dir: Path, hausregeln_dir: Path) -> McpConfig:
    data_dir = tmp_path / "data"
    return McpConfig(
        sources=(
            SourceConfig(id="regelbuecher", title="Regelbuecher", path=regelbuecher_dir, priority=100),
            SourceConfig(id="hausregeln", title="Hausregeln", path=hausregeln_dir, priority=110),
            SourceConfig(id="zusatzinformationen", title="Zusatz", path=tmp_path / "absent_zusatz", priority=80),
            SourceConfig(id="regionalbuecher", title="Regional", path=tmp_path / "absent_reg", priority=60),
        ),
        data_dir=data_dir,
        db_path=data_dir / "index.sqlite",
        model_cache_dir=data_dir / "models",
        embedding_model_name="fake-model",
    )


@pytest.fixture
def fake_extract(monkeypatch):
    texts_by_name = {
        "regelwerk_parade": (
            "Die Parade gegen eine Attacke gelingt mit einer Probe auf den Paradewert."
            "\n\n"
            "Erschwernisse wirken additiv auf den Paradewert."
        ),
        "regelwerk_zauberdauer": (
            "Die Zauberdauer kann durch Modifikationen an Zauber oder Zauberer veraendert werden."
            "\n\n"
            "Relevante Modifikationen ergeben sich aus Meisterschaften und Umstaenden."
        ),
        "hausregel_parade": (
            "Hausregel: Paraden gegen Angriffe erhalten einen zusaetzlichen Bonus."
        ),
    }

    def _fake(pdf_path: Path):
        text = texts_by_name.get(
            pdf_path.stem,
            f"Generischer Text aus {pdf_path.stem}.",
        )
        return [ExtractedPage(page_number=1, text=text)]

    monkeypatch.setattr(pipeline, "extract_pages", _fake)


def _build_index(tmp_path: Path, fake_extract) -> tuple[McpConfig, "sqlite3.Connection"]:  # type: ignore[name-defined]
    regelbuecher_dir = tmp_path / "regelbuecher"
    hausregeln_dir = tmp_path / "hausregeln"
    regelbuecher_dir.mkdir()
    hausregeln_dir.mkdir()

    _write_fake_pdf(regelbuecher_dir / "regelwerk_parade.pdf", b"parade-v1")
    _write_fake_pdf(regelbuecher_dir / "regelwerk_zauberdauer.pdf", b"zauberdauer-v1")
    _write_fake_pdf(hausregeln_dir / "hausregel_parade.pdf", b"hausregel-parade-v1")

    config = _make_config(tmp_path, regelbuecher_dir, hausregeln_dir)
    connection = open_database(config.db_path)
    pipeline.refresh_index(connection, config, embedder=FakeEmbedder())
    return config, connection


def test_fts_only_search_finds_matching_chunk(tmp_path: Path, fake_extract):
    _config, connection = _build_index(tmp_path, fake_extract)
    try:
        hits = hybrid_search(
            connection,
            query="Parade",
            query_embedding=None,
            categories=("regelbuecher", "hausregeln"),
            limit=5,
        )
        assert hits, "FTS-only-Suche muss Treffer liefern"
        assert any("Parade" in hit.text for hit in hits)
    finally:
        connection.close()


def test_hybrid_search_includes_vector_results(tmp_path: Path, fake_extract):
    _config, connection = _build_index(tmp_path, fake_extract)
    try:
        embedder = FakeEmbedder()
        query_embedding = embedder.encode_one("Parade")
        hits = hybrid_search(
            connection,
            query="Parade",
            query_embedding=query_embedding,
            categories=("regelbuecher", "hausregeln"),
            limit=5,
        )
        assert hits
        assert all(hit.score > 0 for hit in hits)
    finally:
        connection.close()


def test_search_rules_tool_restricts_to_requested_sources(tmp_path: Path, fake_extract):
    _config, connection = _build_index(tmp_path, fake_extract)
    try:
        result = run_search_rules(
            connection,
            embedder=FakeEmbedder(),
            query="Parade",
            sources=["hausregeln"],
            limit=10,
        )
        assert result["sources"] == ["hausregeln"]
        assert result["hits"], "Haus-regel-Suche muss etwas finden"
        for hit in result["hits"]:
            assert hit["category"] == "hausregeln"
    finally:
        connection.close()


def test_reciprocal_rank_fusion_weights_by_priority() -> None:
    fts_ranking = [(10, 0.1), (20, 0.2)]
    vector_ranking = [(20, 0.9), (10, 0.8)]
    category_by_source_id = {1: "regelbuecher", 2: "hausregeln"}
    chunk_source_lookup = {10: 1, 20: 2}

    fused = reciprocal_rank_fusion(
        fts_ranking=fts_ranking,
        vector_ranking=vector_ranking,
        category_by_source_id=category_by_source_id,
        chunk_source_lookup=chunk_source_lookup,
    )

    assert len(fused) == 2
    first_id, first_score = fused[0]
    second_id, second_score = fused[1]
    assert first_score >= second_score
    assert first_id == 20
    assert second_id == 10
