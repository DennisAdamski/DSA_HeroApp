from __future__ import annotations

from pathlib import Path
from zipfile import ZipFile

import numpy as np
import pytest

from dsa_rules_mcp.config import McpConfig, SourceConfig
from dsa_rules_mcp.indexer import pipeline
from dsa_rules_mcp.indexer.pdf_extract import ExtractedPage
from dsa_rules_mcp.store.db import list_sources, open_database


class FakeEmbedder:
    """Deterministischer Ersatz-Embedder fuer Tests."""

    def __init__(self, dim: int = 4) -> None:
        self._dim = dim

    @property
    def dim(self) -> int:
        return self._dim

    def encode_many(self, texts, *, batch_size: int = 32) -> np.ndarray:  # noqa: ARG002
        matrix = np.zeros((len(texts), self._dim), dtype=np.float32)
        for row, text in enumerate(texts):
            for column in range(self._dim):
                matrix[row, column] = float((len(text) + column) % 17)
        return matrix

    def encode_one(self, text: str) -> np.ndarray:
        return self.encode_many([text])[0]


def _write_fake_pdf(path: Path, payload: bytes) -> None:
    path.write_bytes(b"%PDF-1.4\n" + payload + b"\n%%EOF")


def _write_fake_docx(path: Path, text: str) -> None:
    document_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>{text}</w:t></w:r></w:p>
  </w:body>
</w:document>
"""
    with ZipFile(path, "w") as archive:
        archive.writestr("word/document.xml", document_xml)


def _write_fake_odt(path: Path, text: str) -> None:
    content_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
  <office:body>
    <office:text>
      <text:p>{text}</text:p>
    </office:text>
  </office:body>
</office:document-content>
"""
    with ZipFile(path, "w") as archive:
        archive.writestr("content.xml", content_xml)


def _make_config(tmp_path: Path, regelbuecher_dir: Path) -> McpConfig:
    data_dir = tmp_path / "data"
    return McpConfig(
        sources=(
            SourceConfig(id="regelbuecher", title="Regelbuecher", path=regelbuecher_dir, priority=100),
            SourceConfig(id="hausregeln", title="Hausregeln", path=tmp_path / "absent_house", priority=110),
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
    """Ersetzt PyMuPDF-Extraktion mit vorhersagbarem Text pro Datei."""

    def _fake(pdf_path: Path):
        stem = pdf_path.stem
        return [
            ExtractedPage(
                page_number=1,
                text=(
                    f"Absatz eins aus {stem}. Parade und Attacke werden hier erklaert."
                    "\n\n"
                    f"Absatz zwei aus {stem}. Ausdauer und Lebensenergie werden dargestellt."
                ),
            ),
            ExtractedPage(
                page_number=2,
                text=(
                    f"Absatz drei aus {stem}. Zauberdauer modifizieren ist ein Thema."
                ),
            ),
        ]

    monkeypatch.setattr(pipeline, "extract_pages", _fake)


def test_initial_and_repeat_refresh_are_consistent(tmp_path: Path, fake_extract):
    regelbuecher_dir = tmp_path / "regelbuecher"
    regelbuecher_dir.mkdir()
    _write_fake_pdf(regelbuecher_dir / "regelwerk_alpha.pdf", b"alpha-content-v1")
    _write_fake_pdf(regelbuecher_dir / "regelwerk_beta.pdf", b"beta-content-v1")

    config = _make_config(tmp_path, regelbuecher_dir)
    connection = open_database(config.db_path)
    try:
        embedder = FakeEmbedder()

        first = pipeline.refresh_index(connection, config, embedder=embedder)
        assert len(first.processed) == 2
        assert not first.updated
        assert not first.skipped
        assert not first.removed

        sources_after_first = list_sources(connection)
        assert len(sources_after_first) == 2

        second = pipeline.refresh_index(connection, config, embedder=embedder)
        assert not second.processed
        assert not second.updated
        assert len(second.skipped) == 2
        assert not second.removed
    finally:
        connection.close()


def test_modified_file_is_updated_and_deleted_file_is_removed(tmp_path: Path, fake_extract):
    regelbuecher_dir = tmp_path / "regelbuecher"
    regelbuecher_dir.mkdir()
    alpha = regelbuecher_dir / "regelwerk_alpha.pdf"
    beta = regelbuecher_dir / "regelwerk_beta.pdf"
    _write_fake_pdf(alpha, b"alpha-content-v1")
    _write_fake_pdf(beta, b"beta-content-v1")

    config = _make_config(tmp_path, regelbuecher_dir)
    connection = open_database(config.db_path)
    try:
        embedder = FakeEmbedder()
        pipeline.refresh_index(connection, config, embedder=embedder)

        _write_fake_pdf(alpha, b"alpha-content-v2-different-bytes")
        import os
        current_mtime = alpha.stat().st_mtime
        os.utime(alpha, (current_mtime + 10, current_mtime + 10))

        beta.unlink()

        stats = pipeline.refresh_index(connection, config, embedder=embedder)
        assert not stats.processed
        assert len(stats.updated) == 1
        assert str(alpha.resolve()) in stats.updated
        assert len(stats.removed) == 1
        assert str(beta.resolve()) in stats.removed

        remaining = list_sources(connection)
        assert [row.title for row in remaining] == ["regelwerk_alpha"]
    finally:
        connection.close()


def test_force_refresh_reindexes_everything(tmp_path: Path, fake_extract):
    regelbuecher_dir = tmp_path / "regelbuecher"
    regelbuecher_dir.mkdir()
    _write_fake_pdf(regelbuecher_dir / "regelwerk_gamma.pdf", b"gamma-content-v1")

    config = _make_config(tmp_path, regelbuecher_dir)
    connection = open_database(config.db_path)
    try:
        embedder = FakeEmbedder()
        pipeline.refresh_index(connection, config, embedder=embedder)

        stats = pipeline.refresh_index(connection, config, embedder=embedder, force=True)
        assert len(stats.updated) == 1
        assert not stats.skipped
        assert not stats.removed
    finally:
        connection.close()


def test_office_documents_are_indexed_like_pdfs(tmp_path: Path, fake_extract):
    regelbuecher_dir = tmp_path / "regelbuecher"
    regelbuecher_dir.mkdir()
    _write_fake_pdf(regelbuecher_dir / "regelwerk_gamma.pdf", b"gamma-content-v1")
    _write_fake_docx(regelbuecher_dir / "regelwerk_delta.docx", "Delta")
    _write_fake_odt(regelbuecher_dir / "regelwerk_epsilon.odt", "Epsilon")

    config = _make_config(tmp_path, regelbuecher_dir)
    connection = open_database(config.db_path)
    try:
        embedder = FakeEmbedder()
        stats = pipeline.refresh_index(connection, config, embedder=embedder)

        assert len(stats.processed) == 3
        source_titles = [row.title for row in list_sources(connection)]
        assert source_titles == [
            "regelwerk_delta",
            "regelwerk_epsilon",
            "regelwerk_gamma",
        ]
    finally:
        connection.close()
