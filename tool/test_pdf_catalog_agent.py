import json
import tempfile
import unittest
from pathlib import Path
import sys
from zipfile import ZipFile

from pypdf import PdfWriter

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pdf_catalog_agent.agent import PdfCatalogAgent
from pdf_catalog_agent.config import load_source_configs


def _escape_pdf_text(value: str) -> str:
    return value.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')


def _write_text_pdf(path: Path, lines: list[str]) -> None:
    text_commands = ['BT', '/F1 12 Tf', '72 720 Td']
    first = True
    for line in lines:
        if first:
            text_commands.append(f'({_escape_pdf_text(line)}) Tj')
            first = False
        else:
            text_commands.append('0 -16 Td')
            text_commands.append(f'({_escape_pdf_text(line)}) Tj')
    text_commands.append('ET')
    content = '\n'.join(text_commands).encode('latin-1', errors='replace')

    objects = [
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        (
            b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
            b'/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>'
        ),
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
        b'<< /Length %d >>\nstream\n%s\nendstream' % (len(content), content),
    ]

    payload = bytearray(b'%PDF-1.4\n')
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(len(payload))
        payload.extend(f'{index} 0 obj\n'.encode('ascii'))
        payload.extend(obj)
        payload.extend(b'\nendobj\n')

    xref_offset = len(payload)
    payload.extend(f'xref\n0 {len(objects) + 1}\n'.encode('ascii'))
    payload.extend(b'0000000000 65535 f \n')
    for offset in offsets[1:]:
        payload.extend(f'{offset:010d} 00000 n \n'.encode('ascii'))
    payload.extend(
        (
            'trailer\n'
            f'<< /Size {len(objects) + 1} /Root 1 0 R >>\n'
            'startxref\n'
            f'{xref_offset}\n'
            '%%EOF\n'
        ).encode('ascii'),
    )
    path.write_bytes(bytes(payload))


def _write_blank_pdf(path: Path) -> None:
    writer = PdfWriter()
    writer.add_blank_page(width=612, height=792)
    with path.open('wb') as handle:
        writer.write(handle)


def _write_docx(path: Path, paragraphs: list[str]) -> None:
    content_types = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>'''
    relationships = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''
    paragraph_xml = ''.join(
        f'<w:p><w:r><w:t>{line}</w:t></w:r></w:p>'
        for line in paragraphs
    )
    document = (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        f'<w:body>{paragraph_xml}</w:body>'
        '</w:document>'
    )
    with ZipFile(path, 'w') as archive:
        archive.writestr('[Content_Types].xml', content_types)
        archive.writestr('_rels/.rels', relationships)
        archive.writestr('word/document.xml', document)


def _write_odt(path: Path, paragraphs: list[str]) -> None:
    manifest = '''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.text"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
</manifest:manifest>'''
    body = ''.join(f'<text:p>{line}</text:p>' for line in paragraphs)
    content = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document-content '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">'
        f'<office:body><office:text>{body}</office:text></office:body>'
        '</office:document-content>'
    )
    with ZipFile(path, 'w') as archive:
        archive.writestr('mimetype', 'application/vnd.oasis.opendocument.text')
        archive.writestr('META-INF/manifest.xml', manifest)
        archive.writestr('content.xml', content)


class PdfCatalogAgentTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.artifact_root = self.root / 'artifacts'

        self.regel_dir = self.root / 'regel'
        self.regional_dir = self.root / 'regional'
        self.zusatz_dir = self.root / 'zusatz'
        self.haus_dir = self.root / 'haus'
        for directory in (
            self.regel_dir,
            self.regional_dir,
            self.zusatz_dir,
            self.haus_dir,
        ):
            directory.mkdir(parents=True, exist_ok=True)

        _write_text_pdf(
            self.regel_dir / 'regel.pdf',
            [
                'Kampf Regeln',
                'Attacke Parade Talent Sonderfertigkeit',
                'Heldenbogen und Eigenschaften fuer Helden.',
            ],
        )
        _write_docx(
            self.regional_dir / 'regional.docx',
            [
                'Region Gareth',
                'Kampftraditionen der Stadt und Orte Regionen.',
            ],
        )
        _write_odt(
            self.zusatz_dir / 'zusatz.odt',
            [
                'Magie Akademie Hintergrund',
                'Kampf und Weltwissen in Zusatzinformationen.',
            ],
        )
        _write_text_pdf(
            self.haus_dir / 'haus.pdf',
            [
                'Hausregel Kampf',
                'Reisebericht und Hausregel Abweichung statt offizieller Parade.',
            ],
        )

        self.config_path = self.root / 'sources.json'
        self.config_path.write_text(
            json.dumps(
                [
                    {
                        'id': 'haus',
                        'title': 'Haus',
                        'path': str(self.haus_dir),
                        'sourceType': 'hausregeln',
                        'priority': 10,
                        'normativeWeight': 400,
                        'enabled': True,
                        'defaultTopics': ['hausregel_abweichung', 'kampf', 'reisebericht'],
                    },
                    {
                        'id': 'regel',
                        'title': 'Regel',
                        'path': str(self.regel_dir),
                        'sourceType': 'regelbuch',
                        'priority': 20,
                        'normativeWeight': 300,
                        'enabled': True,
                        'defaultTopics': ['kampf', 'talente', 'eigenschaften'],
                    },
                    {
                        'id': 'regional',
                        'title': 'Regional',
                        'path': str(self.regional_dir),
                        'sourceType': 'regionalbuch',
                        'priority': 30,
                        'normativeWeight': 200,
                        'enabled': True,
                        'defaultTopics': ['orte_regionen', 'weltwissen', 'kampf'],
                    },
                    {
                        'id': 'zusatz',
                        'title': 'Zusatz',
                        'path': str(self.zusatz_dir),
                        'sourceType': 'zusatzinfo',
                        'priority': 40,
                        'normativeWeight': 150,
                        'enabled': True,
                        'defaultTopics': ['weltwissen', 'magie', 'kampf'],
                    },
                ],
                indent=2,
                ensure_ascii=False,
            ) + '\n',
            encoding='utf-8',
        )

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _agent(self) -> PdfCatalogAgent:
        return PdfCatalogAgent(
            config_path=self.config_path,
            artifact_root=self.artifact_root,
        )

    def test_load_source_configs_reads_temp_sources(self) -> None:
        configs = load_source_configs(self.config_path)

        self.assertEqual([entry.id for entry in configs], ['haus', 'regel', 'regional', 'zusatz'])
        self.assertEqual(configs[0].source_type, 'hausregeln')
        self.assertEqual(configs[-1].normative_weight, 150)

    def test_ingest_indexes_sources_and_builds_conflicts(self) -> None:
        agent = self._agent()
        try:
            manifest = agent.ingest()
            conflicts = agent.conflicts()
        finally:
            agent.close()

        self.assertEqual(manifest['summary']['sources'], 4)
        self.assertGreaterEqual(manifest['summary']['chunks'], 4)
        relation_types = {entry.relation_type for entry in conflicts if entry.topic == 'kampf'}
        self.assertIn('hausregel_override', relation_types)
        self.assertIn('regional_context', relation_types)
        self.assertIn('zusatz_context', relation_types)

    def test_ingest_skips_unchanged_files_on_second_run(self) -> None:
        agent = self._agent()
        try:
            first = agent.ingest()
            second = agent.ingest()
        finally:
            agent.close()

        self.assertEqual(first['processedFiles'], 4)
        self.assertEqual(second['processedFiles'], 0)
        self.assertEqual(second['skippedFiles'], 4)

    def test_search_returns_citations(self) -> None:
        agent = self._agent()
        try:
            agent.ingest()
            results = agent.search(query='Kampf', limit=5)
        finally:
            agent.close()

        self.assertTrue(results)
        self.assertIn(Path(results[0].path).suffix, {'.pdf', '.docx', '.odt'})
        self.assertGreaterEqual(results[0].page_start, 1)
        self.assertIn('quelle', results[0].to_dict())

    def test_ingest_supports_docx_and_odt_sources(self) -> None:
        agent = self._agent()
        try:
            manifest = agent.ingest()
            regional_results = agent.search(query='Gareth', limit=10)
            zusatz_results = agent.search(query='Akademie', limit=10)
        finally:
            agent.close()

        self.assertEqual(manifest['summary']['sources'], 4)
        self.assertTrue(any(result.path.endswith('.docx') for result in regional_results))
        self.assertTrue(any(result.path.endswith('.odt') for result in zusatz_results))

    def test_propose_requires_evidence_and_exposes_conflicts(self) -> None:
        agent = self._agent()
        try:
            agent.ingest()
            proposals = agent.propose(topic='kampf')
        finally:
            agent.close()

        self.assertEqual(len(proposals), 1)
        proposal = proposals[0].to_dict()
        self.assertEqual(proposal['bereich'], 'kampf')
        self.assertTrue(proposal['quellen'])
        self.assertTrue(proposal['konflikte'])
        self.assertGreaterEqual(
            len({entry['quelltyp'] for entry in proposal['quellen']}),
            2,
        )

    def test_review_flags_ocr_required_blank_pdf(self) -> None:
        _write_blank_pdf(self.haus_dir / 'blank.pdf')
        agent = self._agent()
        try:
            agent.ingest(force=True)
            review = agent.review()
        finally:
            agent.close()

        self.assertTrue(review['ocrRequired'])
        self.assertTrue(review['emptyExtraction'])


if __name__ == '__main__':
    unittest.main()
