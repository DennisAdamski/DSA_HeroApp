"""Gemeinsame Datentypen fuer den PDF-Katalog-Agenten."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


KNOWN_SOURCE_TYPES = {
    'hausregeln',
    'regelbuch',
    'regionalbuch',
    'zusatzinfo',
}

KNOWN_TOPICS = (
    'heldenbogen',
    'eigenschaften',
    'talente',
    'kampf',
    'magie',
    'sonderfertigkeiten',
    'inventar',
    'reisebericht',
    'orte_regionen',
    'weltwissen',
    'hausregel_abweichung',
)


@dataclass(frozen=True)
class SourceConfig:
    """Beschreibt einen statischen PDF-Quellordner des Agenten."""

    id: str
    title: str
    path: Path
    source_type: str
    priority: int
    normative_weight: int
    enabled: bool
    default_topics: tuple[str, ...]


@dataclass(frozen=True)
class SourceIngestResult:
    """Haelt die zusammengefassten Extraktionsdaten einer PDF-Datei."""

    config: SourceConfig
    pdf_path: Path
    file_hash: str
    file_size: int
    modified_time: float
    pages_count: int
    extracted_pages: int
    total_chars: int
    extraction_status: str
    ocr_required: bool
    page_records: tuple['PageRecord', ...]
    chunk_records: tuple['ChunkRecord', ...]


@dataclass(frozen=True)
class PageRecord:
    """Repraesentiert eine extrahierte PDF-Seite."""

    page_number: int
    text: str
    char_count: int
    alpha_ratio: float
    section_title: str
    topics: tuple[str, ...]


@dataclass(frozen=True)
class ChunkRecord:
    """Repraesentiert einen durchsuchbaren Textabschnitt."""

    page_start: int
    page_end: int
    chunk_index: int
    section_title: str
    topics: tuple[str, ...]
    text: str


@dataclass(frozen=True)
class SearchResult:
    """Darstellung eines Suchtreffers fuer CLI-Ausgabe und Exporte."""

    id: str
    source_title: str
    source_type: str
    path: str
    page_start: int
    page_end: int
    section_title: str
    topics: tuple[str, ...]
    normative_weight: int
    excerpt: str
    score: float

    def to_dict(self) -> dict[str, object]:
        """Serialisiert den Treffer in ein stabiles JSON-Format."""

        return {
            'id': self.id,
            'quelle': self.source_title,
            'quelltyp': self.source_type,
            'pfad': self.path,
            'seiteStart': self.page_start,
            'seiteEnde': self.page_end,
            'sectionTitle': self.section_title,
            'topics': list(self.topics),
            'normativeWeight': self.normative_weight,
            'excerpt': self.excerpt,
            'score': round(self.score, 6),
        }


@dataclass(frozen=True)
class ConflictRecord:
    """Beschreibt eine priorisierte Quellenbeziehung zu einem Thema."""

    id: str
    topic: str
    relation_type: str
    summary: str
    winner_source_type: str
    loser_source_type: str
    winner_source_title: str
    loser_source_title: str
    winner_path: str
    loser_path: str
    winner_page: int
    loser_page: int

    def to_dict(self) -> dict[str, object]:
        """Serialisiert den Konfliktdatensatz fuer JSON-Exporte."""

        return {
            'id': self.id,
            'topic': self.topic,
            'relationType': self.relation_type,
            'summary': self.summary,
            'winnerSourceType': self.winner_source_type,
            'loserSourceType': self.loser_source_type,
            'winnerSourceTitle': self.winner_source_title,
            'loserSourceTitle': self.loser_source_title,
            'winnerPath': self.winner_path,
            'loserPath': self.loser_path,
            'winnerPage': self.winner_page,
            'loserPage': self.loser_page,
        }


@dataclass(frozen=True)
class ProposalRecord:
    """Beschreibt einen strukturierten App-Vorschlag aus PDF-Evidenz."""

    id: str
    titel: str
    bereich: str
    problem: str
    vorschlag: str
    quellen: tuple[dict[str, object], ...]
    konflikte: tuple[dict[str, object], ...]
    vertrauen: float
    status: str

    def to_dict(self) -> dict[str, object]:
        """Serialisiert den Vorschlag in das geforderte Schema."""

        return {
            'id': self.id,
            'titel': self.titel,
            'bereich': self.bereich,
            'problem': self.problem,
            'vorschlag': self.vorschlag,
            'quellen': list(self.quellen),
            'konflikte': list(self.konflikte),
            'vertrauen': round(self.vertrauen, 4),
            'status': self.status,
        }
