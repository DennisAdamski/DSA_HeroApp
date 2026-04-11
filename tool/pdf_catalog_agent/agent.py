"""Orchestrierung von Ingestion, Suche, Konfliktlogik und Reports."""

from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree
from zipfile import ZipFile

from pypdf import PdfReader

from pdf_catalog_agent.config import DEFAULT_CONFIG_PATH, default_artifact_root, load_source_configs
from pdf_catalog_agent.database import CatalogDatabase
from pdf_catalog_agent.models import (
    KNOWN_TOPICS,
    ChunkRecord,
    ConflictRecord,
    PageRecord,
    ProposalRecord,
    SearchResult,
    SourceConfig,
    SourceIngestResult,
)
from pdf_catalog_agent.text_processing import (
    alpha_ratio,
    build_fts_query,
    detect_topics,
    guess_section_title,
    normalize_text,
    split_into_chunks,
)


TOPIC_TEMPLATES: dict[str, dict[str, str]] = {
    'heldenbogen': {
        'titel': 'Heldenbogen um strukturierte Quellenfelder erweitern',
        'problem': 'Relevante Angaben fuer Heldenstammdaten und Freitextfelder liegen ueber mehrere PDF-Quellen verteilt.',
        'vorschlag': 'Die App sollte Quellfelder fuer Heldenbeschreibung, Herkunft, Profession und regelnahe Hinweise als strukturierte Abschnitte oder Referenzkarten abbilden.',
    },
    'eigenschaften': {
        'titel': 'Eigenschaftslogik und Referenzen staerker modellieren',
        'problem': 'Eigenschaftsregeln und abgeleitete Auswirkungen tauchen mehrfach in den Quellen auf und sollten konsistent erklaerbar sein.',
        'vorschlag': 'Die App sollte Eigenschaftswerte, Grenzwerte und abgeleitete Effekte mit zitierbaren Regelerlaeuterungen im Workspace verknuepfen.',
    },
    'talente': {
        'titel': 'Talente und Steigerung tiefer katalogisieren',
        'problem': 'Talentregeln, Anwendungen und Spezialisierungen werden aus mehreren Quellen relevant.',
        'vorschlag': 'Die App sollte Talentdefinitionen um kontextuelle Quellenhinweise, Spezialisierungen und Hausregel-Overlays erweitern.',
    },
    'kampf': {
        'titel': 'Kampfregeln als zitierbare Entscheidungshilfen ausbauen',
        'problem': 'Kampfregeln, Modifikatoren und Quellenlagen sind fuer schnelle Spielentscheidungen verteilt und zeitkritisch.',
        'vorschlag': 'Die App sollte im Kampfbereich kontextabhaengige Regelkarten, Quellenangaben und priorisierte Hausregel-Hinweise anzeigen.',
    },
    'magie': {
        'titel': 'Magische Detaildaten staerker strukturieren',
        'problem': 'Zauber-, Ritual- und Repraesentationswissen ist reichhaltig, aber aktuell nur teilweise strukturiert fuer die App nutzbar.',
        'vorschlag': 'Die App sollte Zauber- und Ritualdaten mit Varianten, Quellenverweisen und priorisierten Hausregel-Overrides anreichern.',
    },
    'sonderfertigkeiten': {
        'titel': 'Sonderfertigkeiten und Manoever feiner modellieren',
        'problem': 'Sonderfertigkeiten tragen viele Bedingungen und Querverweise, die in PDFs verteilt vorliegen.',
        'vorschlag': 'Die App sollte Voraussetzungen, Synergien und Quellhinweise fuer Sonderfertigkeiten als eigene Struktur- und Pruefregeln pflegen.',
    },
    'inventar': {
        'titel': 'Inventar- und Ausruestungswissen vernetzbar machen',
        'problem': 'Ausruestungsdaten und Einsatzkontexte liegen in Regel- und Zusatzquellen verteilt vor.',
        'vorschlag': 'Die App sollte Inventareintraege um Regelreferenzen, regionale Verfuegbarkeit und Hausregelhinweise erweitern.',
    },
    'reisebericht': {
        'titel': 'Reisebericht und Erfahrungsquellen enger verzahnen',
        'problem': 'Hausregeln und Abenteuerwissen liefern strukturierte Belohnungen und Fortschrittsideen fuer den Reisebericht.',
        'vorschlag': 'Die App sollte Reiseberichtseintraege aus Hausregeln und Zusatzquellen halbautomatisch in neue Katalogideen ueberfuehren.',
    },
    'orte_regionen': {
        'titel': 'Orte und Regionen als App-Kontext nutzbar machen',
        'problem': 'Regionalwissen steckt in vielen Quellen, ist aber fuer Abenteuer, Kontakte und Reisebericht noch nicht systematisch erschlossen.',
        'vorschlag': 'Die App sollte Orte, Regionen und geographische Schlagworte als referenzierbare Datenbasis fuer Abenteuer, Kontakte und Reisen erhalten.',
    },
    'weltwissen': {
        'titel': 'Weltwissen als kontextuelle Referenzschicht anbieten',
        'problem': 'Allgemeines Hintergrundwissen beeinflusst Abenteuer, Professionen und Rollenspielentscheidungen, ist aber schwer auffindbar.',
        'vorschlag': 'Die App sollte eine leichte Wissensschicht fuer Hintergrundwissen, Fraktionen, Institutionen und Kulturkontext anbieten.',
    },
    'hausregel_abweichung': {
        'titel': 'Hausregel-Overrides explizit abbilden',
        'problem': 'Hausregeln ueberschreiben offizielle Regeln und muessen fuer die App sichtbar und nachvollziehbar priorisiert werden.',
        'vorschlag': 'Die App sollte fuer betroffene Bereiche explizite Hausregel-Overrides mit Quelle, Wirkung und Rueckfall auf offizielle Regeln modellieren.',
    },
}

SUPPORTED_DOCUMENT_SUFFIXES = ('.pdf', '.docx', '.odt')
DOCX_NAMESPACE = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
ODT_NAMESPACE = {'text': 'urn:oasis:names:tc:opendocument:xmlns:text:1.0'}


class PdfCatalogAgent:
    """Stellt das lokale CLI-Backend fuer PDF-Katalogisierung und Recherche bereit."""

    def __init__(
        self,
        *,
        config_path: Path | None = None,
        artifact_root: Path | None = None,
    ):
        self.config_path = config_path or DEFAULT_CONFIG_PATH
        self.artifact_root = artifact_root or default_artifact_root()
        self.reports_dir = self.artifact_root / 'reports'
        self.exports_dir = self.artifact_root / 'exports'
        self.manifest_path = self.artifact_root / 'manifest.json'
        self.db = CatalogDatabase(self.artifact_root / 'catalog.db')
        self.source_configs = load_source_configs(self.config_path)

    def close(self) -> None:
        """Schliesst offene Ressourcen des Agenten."""

        self.db.close()

    def ingest(self, *, force: bool = False) -> dict[str, object]:
        """Indexiert alle aktiven Quellen und erzeugt Manifest sowie Konflikte."""

        started_at = self._timestamp()
        processed = 0
        skipped = 0
        errors: list[str] = []

        for config in self.source_configs:
            if not config.enabled:
                continue
            for source_path in self._iter_source_documents(config.path):
                try:
                    file_hash = self._file_hash(source_path)
                    state = self.db.get_source_state(str(source_path))
                    if not force and state is not None and state['file_hash'] == file_hash:
                        skipped += 1
                        continue
                    ingest_result = self._ingest_document(config, source_path, file_hash)
                    self.db.replace_source(ingest_result, ingested_at=started_at)
                    processed += 1
                except Exception as exc:  # pragma: no cover - defensive CLI path
                    errors.append(f'{source_path}: {exc}')

        conflicts = self._build_conflicts()
        self.db.replace_conflicts(conflicts, created_at=started_at)

        summary = self.db.source_summary()
        manifest = {
            'generatedAt': started_at,
            'configPath': str(self.config_path),
            'artifactRoot': str(self.artifact_root),
            'ocrAvailable': bool(shutil.which('tesseract')),
            'processedFiles': processed,
            'skippedFiles': skipped,
            'errors': errors,
            'sourceRoots': [
                {
                    'id': config.id,
                    'title': config.title,
                    'path': str(config.path),
                    'sourceType': config.source_type,
                    'enabled': config.enabled,
                    'priority': config.priority,
                    'normativeWeight': config.normative_weight,
                    'defaultTopics': list(config.default_topics),
                }
                for config in self.source_configs
            ],
            'summary': summary,
        }
        self._ensure_artifact_dirs()
        self.manifest_path.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + '\n',
            encoding='utf-8',
        )
        return manifest

    def search(
        self,
        *,
        query: str,
        limit: int = 10,
        topic: str | None = None,
        source_type: str | None = None,
    ) -> list[SearchResult]:
        """Fuehrt eine zitierbare Volltextsuche gegen den Chunk-Index aus."""

        return self.db.search(
            fts_query=build_fts_query(query),
            limit=limit,
            topic=topic,
            source_type=source_type,
        )

    def propose(self, *, topic: str, limit: int = 8) -> list[ProposalRecord]:
        """Leitet App-Vorschlaege aus Evidenz und Konflikten fuer ein Thema ab."""

        resolved_topic = self._resolve_topic(topic)
        evidence = self._balanced_evidence(resolved_topic, limit=limit)
        if not evidence:
            evidence = self.search(query=topic, limit=limit, topic=resolved_topic)
        if not evidence:
            return []

        related_conflicts = self.db.get_conflicts(resolved_topic)
        template = TOPIC_TEMPLATES.get(
            resolved_topic,
            {
                'titel': f'Neue App-Ideen fuer {resolved_topic} ableiten',
                'problem': 'Relevante Informationen sind ueber mehrere PDFs verteilt und sollten strukturierter in die App einfliessen.',
                'vorschlag': 'Die App sollte dieses Themenfeld mit zitierbaren Quellen und priorisierten Hausregel-Hinweisen erschliessen.',
            },
        )
        sources_payload = tuple(
            {
                'quelle': result.source_title,
                'quelltyp': result.source_type,
                'pfad': result.path,
                'seiteStart': result.page_start,
                'seiteEnde': result.page_end,
                'sectionTitle': result.section_title,
                'topics': list(result.topics),
                'excerpt': result.excerpt,
            }
            for result in evidence
        )
        conflicts_payload = tuple(entry.to_dict() for entry in related_conflicts)
        confidence = self._proposal_confidence(evidence, related_conflicts)
        proposal = ProposalRecord(
            id=self._stable_id('proposal', resolved_topic, *[item.id for item in evidence]),
            titel=template['titel'],
            bereich=resolved_topic,
            problem=template['problem'],
            vorschlag=template['vorschlag'],
            quellen=sources_payload,
            konflikte=conflicts_payload,
            vertrauen=confidence,
            status='neu',
        )
        proposals = [proposal]
        self.db.replace_proposals(
            resolved_topic,
            proposals,
            created_at=self._timestamp(),
        )
        self._write_json_export(
            f'proposals_{resolved_topic}.json',
            [entry.to_dict() for entry in proposals],
        )
        return proposals

    def conflicts(self, *, topic: str | None = None) -> list[ConflictRecord]:
        """Liefert gespeicherte Konflikt- und Prioritaetshinweise."""

        records = self.db.get_conflicts(self._resolve_topic(topic) if topic else None)
        self._write_json_export(
            f'conflicts_{topic or "all"}.json',
            [entry.to_dict() for entry in records],
        )
        return records

    def review(self) -> dict[str, object]:
        """Erzeugt einen lokalen Review-Bericht zu Extraktionsqualitaet und Dubletten."""

        rows = self.db.review_sources()
        review = {
            'generatedAt': self._timestamp(),
            'ocrRequired': [],
            'emptyExtraction': [],
            'lowCoverage': [],
            'duplicateHashes': [],
            'duplicateTitles': [],
        }

        by_hash: dict[str, list[dict[str, object]]] = {}
        by_title: dict[str, list[dict[str, object]]] = {}
        for row in rows:
            record = {
                'quelle': row['source_title'],
                'quelltyp': row['source_type'],
                'pfad': row['path'],
                'seiten': int(row['pages_count']),
                'extrahierteSeiten': int(row['extracted_pages']),
                'zeichen': int(row['total_chars']),
                'status': row['extraction_status'],
            }
            if int(row['ocr_required']):
                review['ocrRequired'].append(record)
            if int(row['total_chars']) == 0:
                review['emptyExtraction'].append(record)
            elif int(row['extracted_pages']) < max(int(row['pages_count']) // 2, 1):
                review['lowCoverage'].append(record)

            by_hash.setdefault(row['file_hash'], []).append(record)
            by_title.setdefault(self._normalize_title(row['path']), []).append(record)

        review['duplicateHashes'] = [
            entries for entries in by_hash.values() if len(entries) > 1
        ]
        review['duplicateTitles'] = [
            entries for entries in by_title.values() if len(entries) > 1
        ]

        self._write_json_export('review.json', review)
        self._write_markdown_report('review.md', self._render_review_markdown(review))
        return review

    def _ingest_document(
        self,
        config: SourceConfig,
        source_path: Path,
        file_hash: str,
    ) -> SourceIngestResult:
        page_texts = self._extract_document_pages(source_path)
        page_records: list[PageRecord] = []
        chunk_records: list[ChunkRecord] = []
        extracted_pages = 0
        total_chars = 0

        for page_number, raw_text in enumerate(page_texts, start=1):
            normalized = normalize_text(raw_text)
            char_count = len(normalized)
            ratio = alpha_ratio(normalized)
            if char_count > 0:
                extracted_pages += 1
                total_chars += char_count

            section_title = guess_section_title(
                normalized,
                fallback=f'{source_path.stem} S. {page_number}',
            )
            topics = detect_topics(
                normalized,
                source_type=config.source_type,
                default_topics=config.default_topics,
            )
            page_records.append(
                PageRecord(
                    page_number=page_number,
                    text=normalized,
                    char_count=char_count,
                    alpha_ratio=ratio,
                    section_title=section_title,
                    topics=topics,
                ),
            )

            for chunk_index, chunk_text in enumerate(split_into_chunks(normalized), start=1):
                chunk_topics = detect_topics(
                    chunk_text,
                    source_type=config.source_type,
                    default_topics=topics,
                )
                chunk_records.append(
                    ChunkRecord(
                        page_start=page_number,
                        page_end=page_number,
                        chunk_index=chunk_index,
                        section_title=section_title,
                        topics=chunk_topics,
                        text=chunk_text,
                    ),
                )

        ocr_required = (
            source_path.suffix.lower() == '.pdf'
            and (extracted_pages == 0 or total_chars < max(len(page_texts) * 200, 400))
        )
        extraction_status = 'empty' if total_chars == 0 else 'ocr_required' if ocr_required else 'complete'
        return SourceIngestResult(
            config=config,
            source_path=source_path,
            file_hash=file_hash,
            file_size=source_path.stat().st_size,
            modified_time=source_path.stat().st_mtime,
            pages_count=len(page_texts),
            extracted_pages=extracted_pages,
            total_chars=total_chars,
            extraction_status=extraction_status,
            ocr_required=ocr_required,
            page_records=tuple(page_records),
            chunk_records=tuple(chunk_records),
        )

    def _iter_source_documents(self, source_root: Path) -> list[Path]:
        """Liefert alle unterstuetzten Dokumente eines Quellordners stabil sortiert."""

        documents = [
            path
            for path in source_root.rglob('*')
            if path.is_file() and path.suffix.lower() in SUPPORTED_DOCUMENT_SUFFIXES
        ]
        return sorted(documents)

    def _extract_document_pages(self, source_path: Path) -> list[str]:
        """Extrahiert Dokumenttext und normalisiert ihn in seitenartige Abschnitte."""

        suffix = source_path.suffix.lower()
        if suffix == '.pdf':
            return self._extract_pdf_pages(source_path)
        if suffix == '.docx':
            return self._extract_docx_pages(source_path)
        if suffix == '.odt':
            return self._extract_odt_pages(source_path)
        raise ValueError(f'Nicht unterstuetztes Dateiformat: {source_path.suffix}')

    def _extract_pdf_pages(self, source_path: Path) -> list[str]:
        """Extrahiert alle Textseiten eines PDFs ueber `pypdf`."""

        reader = PdfReader(str(source_path))
        return [page.extract_text() or '' for page in reader.pages]

    def _extract_docx_pages(self, source_path: Path) -> list[str]:
        """Extrahiert Abschnitte aus einem DOCX als pseudo-seitenartige Texte."""

        with ZipFile(source_path) as archive:
            document_xml = archive.read('word/document.xml')
        root = ElementTree.fromstring(document_xml)
        paragraphs: list[str] = []
        for paragraph in root.findall('.//w:p', DOCX_NAMESPACE):
            fragments = [
                node.text or ''
                for node in paragraph.findall('.//w:t', DOCX_NAMESPACE)
            ]
            combined = ''.join(fragments).strip()
            if combined:
                paragraphs.append(combined)
        return paragraphs or ['']

    def _extract_odt_pages(self, source_path: Path) -> list[str]:
        """Extrahiert Abschnitte aus einer ODT-Datei als pseudo-seitenartige Texte."""

        with ZipFile(source_path) as archive:
            content_xml = archive.read('content.xml')
        root = ElementTree.fromstring(content_xml)
        paragraphs: list[str] = []
        for tag_name in ('h', 'p'):
            nodes = root.findall(f'.//text:{tag_name}', ODT_NAMESPACE)
            for node in nodes:
                combined = ''.join(node.itertext()).strip()
                if combined:
                    paragraphs.append(combined)
        return paragraphs or ['']

    def _build_conflicts(self) -> list[ConflictRecord]:
        records: list[ConflictRecord] = []
        for topic in KNOWN_TOPICS:
            hausregel = self._first_evidence_for_source_type(topic, 'hausregeln')
            regelbuch = self._first_evidence_for_source_type(topic, 'regelbuch')
            regional = self._first_evidence_for_source_type(topic, 'regionalbuch')
            zusatz = self._first_evidence_for_source_type(topic, 'zusatzinfo')

            if hausregel is not None and regelbuch is not None:
                records.append(
                    ConflictRecord(
                        id=self._stable_id('conflict', topic, 'hausregeln', 'regelbuch'),
                        topic=topic,
                        relation_type='hausregel_override',
                        summary=(
                            f'Hausregeln ueberschreiben fuer das Thema "{topic}" '
                            'offizielle Regelbuch-Evidenz.'
                        ),
                        winner_source_type='hausregeln',
                        loser_source_type='regelbuch',
                        winner_source_title=hausregel.source_title,
                        loser_source_title=regelbuch.source_title,
                        winner_path=hausregel.path,
                        loser_path=regelbuch.path,
                        winner_page=hausregel.page_start,
                        loser_page=regelbuch.page_start,
                    ),
                )

            if regelbuch is not None and regional is not None:
                records.append(
                    ConflictRecord(
                        id=self._stable_id('conflict', topic, 'regelbuch', 'regionalbuch'),
                        topic=topic,
                        relation_type='regional_context',
                        summary=(
                            f'Regionalbuecher ergaenzen das Thema "{topic}", '
                            'ohne die offizielle Regelprioritaet zu ersetzen.'
                        ),
                        winner_source_type='regelbuch',
                        loser_source_type='regionalbuch',
                        winner_source_title=regelbuch.source_title,
                        loser_source_title=regional.source_title,
                        winner_path=regelbuch.path,
                        loser_path=regional.path,
                        winner_page=regelbuch.page_start,
                        loser_page=regional.page_start,
                    ),
                )

            if regelbuch is not None and zusatz is not None:
                records.append(
                    ConflictRecord(
                        id=self._stable_id('conflict', topic, 'regelbuch', 'zusatzinfo'),
                        topic=topic,
                        relation_type='zusatz_context',
                        summary=(
                            f'Zusatzinformationen liefern fuer "{topic}" Kontext, '
                            'aendern aber keine Regelwahrheit ohne Hausregelbezug.'
                        ),
                        winner_source_type='regelbuch',
                        loser_source_type='zusatzinfo',
                        winner_source_title=regelbuch.source_title,
                        loser_source_title=zusatz.source_title,
                        winner_path=regelbuch.path,
                        loser_path=zusatz.path,
                        winner_page=regelbuch.page_start,
                        loser_page=zusatz.page_start,
                    ),
                )
        return records

    def _balanced_evidence(self, topic: str, *, limit: int) -> list[SearchResult]:
        """Mischt Evidenz bewusst ueber Quelltypen, statt nur Gewichtung zu bevorzugen."""

        ordered_source_types = ('hausregeln', 'regelbuch', 'regionalbuch', 'zusatzinfo')
        results: list[SearchResult] = []
        seen_ids: set[str] = set()
        per_source_limit = max(1, min(2, limit))
        for source_type in ordered_source_types:
            entries = self.db.evidence_for_topic_and_source_type(
                topic,
                limit=per_source_limit,
                source_type=source_type,
            )
            for entry in entries:
                if entry.id in seen_ids:
                    continue
                seen_ids.add(entry.id)
                results.append(entry)
                if len(results) >= limit:
                    return results
        return results

    def _first_evidence_for_source_type(
        self,
        topic: str,
        source_type: str,
    ) -> SearchResult | None:
        """Liefert den reprasentativen Treffer eines Quelltyps fuer ein Thema."""

        entries = self.db.evidence_for_topic_and_source_type(
            topic,
            limit=1,
            source_type=source_type,
        )
        return entries[0] if entries else None

    def _proposal_confidence(
        self,
        evidence: list[SearchResult],
        conflicts: list[ConflictRecord],
    ) -> float:
        source_types = {entry.source_type for entry in evidence}
        raw = 0.35 + min(len(evidence), 6) * 0.07 + len(source_types) * 0.08
        if conflicts:
            raw += 0.05
        return min(raw, 0.95)

    def _ensure_artifact_dirs(self) -> None:
        self.reports_dir.mkdir(parents=True, exist_ok=True)
        self.exports_dir.mkdir(parents=True, exist_ok=True)

    def _write_json_export(self, name: str, payload: object) -> None:
        self._ensure_artifact_dirs()
        (self.exports_dir / name).write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + '\n',
            encoding='utf-8',
        )

    def _write_markdown_report(self, name: str, body: str) -> None:
        self._ensure_artifact_dirs()
        (self.reports_dir / name).write_text(body, encoding='utf-8')

    def _render_review_markdown(self, review: dict[str, object]) -> str:
        sections = [
            '# PDF-Agent Review',
            '',
            f"Erzeugt: {review['generatedAt']}",
            '',
        ]
        mapping = {
            'ocrRequired': 'OCR erforderlich',
            'emptyExtraction': 'Leere Extraktionen',
            'lowCoverage': 'Niedrige Abdeckung',
            'duplicateHashes': 'Dubletten per Datei-Hash',
            'duplicateTitles': 'Dubletten per normalisiertem Titel',
        }
        for key, title in mapping.items():
            sections.append(f'## {title}')
            entries = review[key]
            sections.append('')
            if not entries:
                sections.append('- Keine')
                sections.append('')
                continue
            if key.startswith('duplicate'):
                for group in entries:
                    sections.append('- Gruppe:')
                    for item in group:
                        sections.append(
                            f"  - {item['quelle']} ({item['quelltyp']}) - {item['pfad']}",
                        )
                sections.append('')
                continue
            for item in entries:
                sections.append(
                    f"- {item['quelle']} ({item['quelltyp']}) - "
                    f"{item['status']} - {item['pfad']}",
                )
            sections.append('')
        return '\n'.join(sections)

    def _resolve_topic(self, topic: str) -> str:
        if topic in KNOWN_TOPICS:
            return topic
        normalized = topic.strip().lower()
        aliases = {
            'orte': 'orte_regionen',
            'regionen': 'orte_regionen',
            'hausregeln': 'hausregel_abweichung',
            'sonderfertigkeit': 'sonderfertigkeiten',
            'sonderfertigkeiten': 'sonderfertigkeiten',
        }
        return aliases.get(normalized, normalized)

    def _normalize_title(self, title: str) -> str:
        lowered = Path(title).stem.lower()
        stripped = lowered.split('(')[0].strip()
        return ''.join(character for character in stripped if character.isalnum())

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).isoformat()

    def _file_hash(self, path: Path) -> str:
        digest = hashlib.sha256()
        with path.open('rb') as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b''):
                digest.update(chunk)
        return digest.hexdigest()

    def _stable_id(self, prefix: str, *parts: str) -> str:
        digest = hashlib.sha1('::'.join(parts).encode('utf-8')).hexdigest()[:12]
        return f'{prefix}_{digest}'
