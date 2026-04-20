from __future__ import annotations

from pathlib import Path
from zipfile import ZipFile

from dsa_rules_mcp.indexer.pdf_extract import (
    count_pages,
    extract_pages,
    supported_document_suffixes,
)


def _write_minimal_docx(path: Path) -> None:
    document_xml = """<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Ueberschrift</w:t></w:r></w:p>
    <w:p><w:r><w:t>Erster Absatz im Dokument.</w:t></w:r></w:p>
    <w:p><w:r><w:t>Zweiter Absatz mit Zauber und Manoever.</w:t></w:r></w:p>
  </w:body>
</w:document>
"""
    with ZipFile(path, "w") as archive:
        archive.writestr("word/document.xml", document_xml)


def _write_minimal_odt(path: Path) -> None:
    content_xml = """<?xml version="1.0" encoding="UTF-8"?>
<office:document-content
  xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
  xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">
  <office:body>
    <office:text>
      <text:h>Hausregeln</text:h>
      <text:p>Erster Regelabsatz fuer Waffen.</text:p>
      <text:p>Zweiter Regelabsatz fuer epische Sonderfertigkeiten.</text:p>
    </office:text>
  </office:body>
</office:document-content>
"""
    with ZipFile(path, "w") as archive:
        archive.writestr("content.xml", content_xml)


def test_supported_document_suffixes_include_office_documents() -> None:
    assert supported_document_suffixes() == (".pdf", ".odt", ".docx")


def test_extract_pages_reads_docx_paragraphs(tmp_path: Path) -> None:
    path = tmp_path / "hausregeln.docx"
    _write_minimal_docx(path)

    pages = extract_pages(path)

    assert len(pages) == 1
    assert pages[0].page_number == 1
    assert "Ueberschrift" in pages[0].text
    assert "Erster Absatz im Dokument." in pages[0].text
    assert "Zweiter Absatz mit Zauber und Manoever." in pages[0].text
    assert count_pages(path) == 1


def test_extract_pages_reads_odt_paragraphs(tmp_path: Path) -> None:
    path = tmp_path / "epische_stufen.odt"
    _write_minimal_odt(path)

    pages = extract_pages(path)

    assert len(pages) == 1
    assert pages[0].page_number == 1
    assert "Hausregeln" in pages[0].text
    assert "Erster Regelabsatz fuer Waffen." in pages[0].text
    assert "epische Sonderfertigkeiten" in pages[0].text
