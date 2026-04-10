"""SQLite-Repository fuer Suche, Konflikte und Vorschlaege."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from pdf_catalog_agent.models import ConflictRecord, ProposalRecord, SearchResult
from pdf_catalog_agent.text_processing import build_excerpt


def encode_topics(topics: tuple[str, ...] | list[str]) -> str:
    """Speichert Topic-Listen kompakt und SQL-filterbar."""

    ordered = [topic for topic in topics if topic]
    if not ordered:
        return '|weltwissen|'
    return f"|{'|'.join(ordered)}|"


def topic_like_pattern(topic: str) -> str:
    """Erzeugt das SQL-LIKE-Muster fuer einen einzelnen Topic-Filter."""

    return f'%|{topic}|%'


class CatalogDatabase:
    """Kapselt Schema, Schreibpfade und Ausleseoperationen der Agent-Datenbank."""

    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(self.db_path)
        self.connection.row_factory = sqlite3.Row
        self._initialize()

    def _initialize(self) -> None:
        cursor = self.connection.cursor()
        cursor.executescript(
            '''
            CREATE TABLE IF NOT EXISTS sources (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                config_id TEXT NOT NULL,
                source_title TEXT NOT NULL,
                source_type TEXT NOT NULL,
                path TEXT NOT NULL UNIQUE,
                file_name TEXT NOT NULL,
                file_hash TEXT NOT NULL,
                file_size INTEGER NOT NULL,
                modified_time REAL NOT NULL,
                pages_count INTEGER NOT NULL,
                extracted_pages INTEGER NOT NULL,
                total_chars INTEGER NOT NULL,
                extraction_status TEXT NOT NULL,
                ocr_required INTEGER NOT NULL,
                default_topics TEXT NOT NULL,
                normative_weight INTEGER NOT NULL,
                priority INTEGER NOT NULL,
                ingested_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS pages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL,
                page_number INTEGER NOT NULL,
                text TEXT NOT NULL,
                char_count INTEGER NOT NULL,
                alpha_ratio REAL NOT NULL,
                section_title TEXT NOT NULL,
                topics TEXT NOT NULL,
                FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS chunks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL,
                page_start INTEGER NOT NULL,
                page_end INTEGER NOT NULL,
                chunk_index INTEGER NOT NULL,
                section_title TEXT NOT NULL,
                topics TEXT NOT NULL,
                normative_weight INTEGER NOT NULL,
                text TEXT NOT NULL,
                FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(text);

            CREATE TABLE IF NOT EXISTS conflicts (
                id TEXT PRIMARY KEY,
                topic TEXT NOT NULL,
                relation_type TEXT NOT NULL,
                summary TEXT NOT NULL,
                winner_source_type TEXT NOT NULL,
                loser_source_type TEXT NOT NULL,
                winner_source_title TEXT NOT NULL,
                loser_source_title TEXT NOT NULL,
                winner_path TEXT NOT NULL,
                loser_path TEXT NOT NULL,
                winner_page INTEGER NOT NULL,
                loser_page INTEGER NOT NULL,
                created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS proposals (
                id TEXT PRIMARY KEY,
                topic TEXT NOT NULL,
                titel TEXT NOT NULL,
                bereich TEXT NOT NULL,
                problem TEXT NOT NULL,
                vorschlag TEXT NOT NULL,
                quellen_json TEXT NOT NULL,
                konflikte_json TEXT NOT NULL,
                vertrauen REAL NOT NULL,
                status TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            ''',
        )
        self.connection.commit()

    def close(self) -> None:
        """Schliesst die geoeffnete SQLite-Verbindung."""

        self.connection.close()

    def get_source_state(self, path: str) -> sqlite3.Row | None:
        """Liefert den zuletzt bekannten Datenbankeintrag fuer eine PDF-Datei."""

        cursor = self.connection.execute(
            'SELECT * FROM sources WHERE path = ?',
            (path,),
        )
        return cursor.fetchone()

    def replace_source(self, ingest_result, *, ingested_at: str) -> None:
        """Ersetzt alle gespeicherten Artefakte einer Quelldatei atomar."""

        cursor = self.connection.cursor()
        existing = self.get_source_state(str(ingest_result.pdf_path))
        if existing is not None:
            source_id = int(existing['id'])
            chunk_ids = [
                row['id']
                for row in cursor.execute(
                    'SELECT id FROM chunks WHERE source_id = ?',
                    (source_id,),
                )
            ]
            for chunk_id in chunk_ids:
                cursor.execute('DELETE FROM chunk_fts WHERE rowid = ?', (chunk_id,))
            cursor.execute('DELETE FROM pages WHERE source_id = ?', (source_id,))
            cursor.execute('DELETE FROM chunks WHERE source_id = ?', (source_id,))
            cursor.execute('DELETE FROM sources WHERE id = ?', (source_id,))

        cursor.execute(
            '''
            INSERT INTO sources (
                config_id,
                source_title,
                source_type,
                path,
                file_name,
                file_hash,
                file_size,
                modified_time,
                pages_count,
                extracted_pages,
                total_chars,
                extraction_status,
                ocr_required,
                default_topics,
                normative_weight,
                priority,
                ingested_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            (
                ingest_result.config.id,
                ingest_result.config.title,
                ingest_result.config.source_type,
                str(ingest_result.pdf_path),
                ingest_result.pdf_path.name,
                ingest_result.file_hash,
                ingest_result.file_size,
                ingest_result.modified_time,
                ingest_result.pages_count,
                ingest_result.extracted_pages,
                ingest_result.total_chars,
                ingest_result.extraction_status,
                1 if ingest_result.ocr_required else 0,
                encode_topics(ingest_result.config.default_topics),
                ingest_result.config.normative_weight,
                ingest_result.config.priority,
                ingested_at,
            ),
        )
        source_id = int(cursor.lastrowid)

        for page_record in ingest_result.page_records:
            cursor.execute(
                '''
                INSERT INTO pages (
                    source_id,
                    page_number,
                    text,
                    char_count,
                    alpha_ratio,
                    section_title,
                    topics
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ''',
                (
                    source_id,
                    page_record.page_number,
                    page_record.text,
                    page_record.char_count,
                    page_record.alpha_ratio,
                    page_record.section_title,
                    encode_topics(page_record.topics),
                ),
            )

        for chunk_record in ingest_result.chunk_records:
            cursor.execute(
                '''
                INSERT INTO chunks (
                    source_id,
                    page_start,
                    page_end,
                    chunk_index,
                    section_title,
                    topics,
                    normative_weight,
                    text
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                (
                    source_id,
                    chunk_record.page_start,
                    chunk_record.page_end,
                    chunk_record.chunk_index,
                    chunk_record.section_title,
                    encode_topics(chunk_record.topics),
                    ingest_result.config.normative_weight,
                    chunk_record.text,
                ),
            )
            chunk_id = int(cursor.lastrowid)
            cursor.execute(
                'INSERT INTO chunk_fts (rowid, text) VALUES (?, ?)',
                (chunk_id, chunk_record.text),
            )

        self.connection.commit()

    def source_summary(self) -> dict[str, int]:
        """Liefert Gesamtzahlen fuer Manifest und CLI-Summary."""

        cursor = self.connection.cursor()
        return {
            'sources': cursor.execute('SELECT COUNT(*) FROM sources').fetchone()[0],
            'pages': cursor.execute('SELECT COUNT(*) FROM pages').fetchone()[0],
            'chunks': cursor.execute('SELECT COUNT(*) FROM chunks').fetchone()[0],
            'conflicts': cursor.execute('SELECT COUNT(*) FROM conflicts').fetchone()[0],
            'proposals': cursor.execute('SELECT COUNT(*) FROM proposals').fetchone()[0],
        }

    def search(
        self,
        *,
        fts_query: str,
        limit: int,
        topic: str | None = None,
        source_type: str | None = None,
    ) -> list[SearchResult]:
        """Sucht ueber die Chunk-FTS-Tabelle und reichert Treffer an."""

        sql = '''
            SELECT
                c.id,
                s.source_title,
                s.source_type,
                s.path,
                c.page_start,
                c.page_end,
                c.section_title,
                c.topics,
                c.normative_weight,
                c.text,
                bm25(chunk_fts) AS score
            FROM chunk_fts
            JOIN chunks c ON c.id = chunk_fts.rowid
            JOIN sources s ON s.id = c.source_id
            WHERE chunk_fts MATCH ?
        '''
        params: list[object] = [fts_query]
        if topic:
            sql += ' AND c.topics LIKE ?'
            params.append(topic_like_pattern(topic))
        if source_type:
            sql += ' AND s.source_type = ?'
            params.append(source_type)
        sql += ' ORDER BY bm25(chunk_fts), c.normative_weight DESC LIMIT ?'
        params.append(limit)

        results: list[SearchResult] = []
        for row in self.connection.execute(sql, params):
            topics = tuple(entry for entry in row['topics'].split('|') if entry)
            results.append(
                SearchResult(
                    id=f"chunk-{row['id']}",
                    source_title=row['source_title'],
                    source_type=row['source_type'],
                    path=row['path'],
                    page_start=int(row['page_start']),
                    page_end=int(row['page_end']),
                    section_title=row['section_title'],
                    topics=topics,
                    normative_weight=int(row['normative_weight']),
                    excerpt=build_excerpt(row['text']),
                    score=float(row['score']),
                ),
            )
        return results

    def evidence_for_topic(self, topic: str, *, limit: int) -> list[SearchResult]:
        """Liefert die staerksten Evidenz-Chunks fuer ein einzelnes Thema."""
        return self.evidence_for_topic_and_source_type(
            topic,
            limit=limit,
            source_type=None,
        )

    def evidence_for_topic_and_source_type(
        self,
        topic: str,
        *,
        limit: int,
        source_type: str | None,
    ) -> list[SearchResult]:
        """Liefert Evidenz-Chunks optional gefiltert nach Quelltyp."""

        sql = '''
            SELECT
                c.id,
                s.source_title,
                s.source_type,
                s.path,
                c.page_start,
                c.page_end,
                c.section_title,
                c.topics,
                c.normative_weight,
                c.text,
                s.ocr_required,
                CAST(c.normative_weight AS REAL) * -1 AS score
            FROM chunks c
            JOIN sources s ON s.id = c.source_id
            WHERE c.topics LIKE ?
        '''
        params: list[object] = [topic_like_pattern(topic)]
        if source_type:
            sql += ' AND s.source_type = ?'
            params.append(source_type)
        sql += (
            ' ORDER BY s.ocr_required ASC, length(c.text) DESC, '
            'c.normative_weight DESC, s.priority ASC, c.page_start ASC LIMIT ?'
        )
        params.append(limit)

        rows = self.connection.execute(sql, params)
        results: list[SearchResult] = []
        for row in rows:
            topics = tuple(entry for entry in row['topics'].split('|') if entry)
            results.append(
                SearchResult(
                    id=f"chunk-{row['id']}",
                    source_title=row['source_title'],
                    source_type=row['source_type'],
                    path=row['path'],
                    page_start=int(row['page_start']),
                    page_end=int(row['page_end']),
                    section_title=row['section_title'],
                    topics=topics,
                    normative_weight=int(row['normative_weight']),
                    excerpt=build_excerpt(row['text']),
                    score=float(row['score']),
                ),
            )
        return results

    def replace_conflicts(
        self,
        conflicts: list[ConflictRecord],
        *,
        created_at: str,
    ) -> None:
        """Ersetzt alle Konfliktdatensaetze auf Basis der letzten Ingestion."""

        cursor = self.connection.cursor()
        cursor.execute('DELETE FROM conflicts')
        for record in conflicts:
            cursor.execute(
                '''
                INSERT INTO conflicts (
                    id,
                    topic,
                    relation_type,
                    summary,
                    winner_source_type,
                    loser_source_type,
                    winner_source_title,
                    loser_source_title,
                    winner_path,
                    loser_path,
                    winner_page,
                    loser_page,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                (
                    record.id,
                    record.topic,
                    record.relation_type,
                    record.summary,
                    record.winner_source_type,
                    record.loser_source_type,
                    record.winner_source_title,
                    record.loser_source_title,
                    record.winner_path,
                    record.loser_path,
                    record.winner_page,
                    record.loser_page,
                    created_at,
                ),
            )
        self.connection.commit()

    def get_conflicts(self, topic: str | None = None) -> list[ConflictRecord]:
        """Liefert die zuletzt berechneten Konflikt- und Prioritaetshinweise."""

        sql = 'SELECT * FROM conflicts'
        params: list[object] = []
        if topic:
            sql += ' WHERE topic = ?'
            params.append(topic)
        sql += ' ORDER BY topic, relation_type, winner_source_title'

        rows = self.connection.execute(sql, params)
        return [
            ConflictRecord(
                id=row['id'],
                topic=row['topic'],
                relation_type=row['relation_type'],
                summary=row['summary'],
                winner_source_type=row['winner_source_type'],
                loser_source_type=row['loser_source_type'],
                winner_source_title=row['winner_source_title'],
                loser_source_title=row['loser_source_title'],
                winner_path=row['winner_path'],
                loser_path=row['loser_path'],
                winner_page=int(row['winner_page']),
                loser_page=int(row['loser_page']),
            )
            for row in rows
        ]

    def replace_proposals(
        self,
        topic: str,
        proposals: list[ProposalRecord],
        *,
        created_at: str,
    ) -> None:
        """Ersetzt gespeicherte Vorschlaege fuer ein Thema."""

        cursor = self.connection.cursor()
        cursor.execute('DELETE FROM proposals WHERE topic = ?', (topic,))
        for record in proposals:
            cursor.execute(
                '''
                INSERT INTO proposals (
                    id,
                    topic,
                    titel,
                    bereich,
                    problem,
                    vorschlag,
                    quellen_json,
                    konflikte_json,
                    vertrauen,
                    status,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                (
                    record.id,
                    topic,
                    record.titel,
                    record.bereich,
                    record.problem,
                    record.vorschlag,
                    json.dumps(record.quellen, ensure_ascii=False),
                    json.dumps(record.konflikte, ensure_ascii=False),
                    record.vertrauen,
                    record.status,
                    created_at,
                ),
            )
        self.connection.commit()

    def review_sources(self) -> list[sqlite3.Row]:
        """Liefert alle Quellen fuer Review-Berichte."""

        return list(
            self.connection.execute(
                '''
                SELECT
                    source_title,
                    source_type,
                    path,
                    pages_count,
                    extracted_pages,
                    total_chars,
                    extraction_status,
                    ocr_required,
                    file_hash
                FROM sources
                ORDER BY source_type, source_title
                ''',
            ),
        )
