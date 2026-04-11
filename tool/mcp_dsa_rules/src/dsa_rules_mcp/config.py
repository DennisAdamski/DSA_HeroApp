"""Konfiguration der Quellen-Pfade, Prioritaeten und Datenordner."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


DEFAULT_SOURCE_DIRS: dict[str, str] = {
    "regelbuecher": r"C:\Users\denni\OneDrive\Rollenspiel\DSA\Regelbücher",
    "hausregeln": r"C:\Users\denni\OneDrive\Rollenspiel\DSA\hausregeln",
    "zusatzinformationen": r"C:\Users\denni\OneDrive\Rollenspiel\DSA\Zusatzinformationen",
    "regionalbuecher": r"C:\Users\denni\OneDrive\Rollenspiel\DSA\Bücher\Regionalbücher",
}

SOURCE_ENV_VARS: dict[str, str] = {
    "regelbuecher": "DSA_MCP_REGELBUECHER_DIR",
    "hausregeln": "DSA_MCP_HAUSREGELN_DIR",
    "zusatzinformationen": "DSA_MCP_ZUSATZ_DIR",
    "regionalbuecher": "DSA_MCP_REGIONALBUECHER_DIR",
}

SOURCE_PRIORITIES: dict[str, int] = {
    "hausregeln": 110,
    "regelbuecher": 100,
    "zusatzinformationen": 80,
    "regionalbuecher": 60,
}

SOURCE_TITLES: dict[str, str] = {
    "regelbuecher": "Regelbuecher",
    "hausregeln": "Hausregeln",
    "zusatzinformationen": "Zusatzinformationen",
    "regionalbuecher": "Regionalbuecher",
}

DEFAULT_SEARCH_SOURCES: tuple[str, ...] = ("regelbuecher", "hausregeln")

EMBEDDING_MODEL_NAME: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


@dataclass(frozen=True)
class SourceConfig:
    """Eine Quellen-Kategorie inklusive Pfad und Prioritaet."""

    id: str
    title: str
    path: Path
    priority: int

    @property
    def exists(self) -> bool:
        return self.path.exists() and self.path.is_dir()


@dataclass(frozen=True)
class McpConfig:
    """Gesamtkonfiguration des MCP-Servers."""

    sources: tuple[SourceConfig, ...]
    data_dir: Path
    db_path: Path
    model_cache_dir: Path
    embedding_model_name: str

    def source_by_id(self, source_id: str) -> SourceConfig | None:
        for source in self.sources:
            if source.id == source_id:
                return source
        return None


def _default_data_dir() -> Path:
    override = os.environ.get("DSA_MCP_DATA_DIR")
    if override:
        return Path(override).expanduser()
    local_appdata = os.environ.get("LOCALAPPDATA")
    if local_appdata:
        return Path(local_appdata) / "dsa-rules-mcp"
    return Path.home() / ".local" / "share" / "dsa-rules-mcp"


def load_config() -> McpConfig:
    """Lese Umgebungsvariablen und liefere eine aufgeloeste Konfiguration."""

    sources: list[SourceConfig] = []
    for source_id, default_path in DEFAULT_SOURCE_DIRS.items():
        env_var = SOURCE_ENV_VARS[source_id]
        resolved = os.environ.get(env_var, default_path)
        sources.append(
            SourceConfig(
                id=source_id,
                title=SOURCE_TITLES[source_id],
                path=Path(resolved).expanduser(),
                priority=SOURCE_PRIORITIES[source_id],
            )
        )

    data_dir = _default_data_dir()
    return McpConfig(
        sources=tuple(sources),
        data_dir=data_dir,
        db_path=data_dir / "index.sqlite",
        model_cache_dir=data_dir / "models",
        embedding_model_name=EMBEDDING_MODEL_NAME,
    )


def ensure_data_dirs(config: McpConfig) -> None:
    """Lege die Zielordner fuer Datenbank und Modell-Cache an."""

    config.data_dir.mkdir(parents=True, exist_ok=True)
    config.model_cache_dir.mkdir(parents=True, exist_ok=True)
