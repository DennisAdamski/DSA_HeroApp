# dsa-rules-mcp

Ein lokaler MCP-Server, der offizielle DSA-Regelwerke, Regionalbuecher,
Zusatzinformationen und eigene Hausregeln als durchsuchbare Wissensbasis fuer
Claude Code zugaenglich macht.

Der Server baut eine hybride Suchdatenbank aus:

- **SQLite FTS5** fuer Keyword-Suche.
- **Vektor-Index** (lokale `sentence-transformers`-Embeddings, mehrsprachig)
  fuer semantische Treffer.
- **Reciprocal Rank Fusion** kombiniert beide Ergebnisse und gewichtet nach
  Quellen-Prioritaet.

Der Code liegt versioniert im Repo unter `tool/mcp_dsa_rules/`, die Datenbank
und Embedding-Caches liegen nutzerlokal unter `%LOCALAPPDATA%/dsa-rules-mcp/`
(ueberschreibbar per `DSA_MCP_DATA_DIR`).

## Quellen

Der Server liest aus vier festen Kategorien. Pfade koennen per Env-Var
ueberschrieben werden; sonst gelten die unten gezeigten Defaults.

| Kategorie-ID            | Env-Var                         | Default-Pfad                                                       | Prio |
|-------------------------|---------------------------------|--------------------------------------------------------------------|------|
| `regelbuecher`          | `DSA_MCP_REGELBUECHER_DIR`      | `C:\Users\denni\OneDrive\Rollenspiel\DSA\Regelbücher`             | 100  |
| `hausregeln`            | `DSA_MCP_HAUSREGELN_DIR`        | `C:\Users\denni\OneDrive\Rollenspiel\DSA\hausregeln`              | 110  |
| `zusatzinformationen`   | `DSA_MCP_ZUSATZ_DIR`            | `C:\Users\denni\OneDrive\Rollenspiel\DSA\Zusatzinformationen`     | 80   |
| `regionalbuecher`       | `DSA_MCP_REGIONALBUECHER_DIR`   | `C:\Users\denni\OneDrive\Rollenspiel\DSA\Bücher\Regionalbücher`   | 60   |

Die Default-Suche beruecksichtigt nur `regelbuecher` und `hausregeln`.
`regionalbuecher` und `zusatzinformationen` muessen im Tool-Aufruf explizit
unter `sources` angegeben werden.

## Installation

```bash
cd tool/mcp_dsa_rules
python -m venv .venv
.venv\Scripts\activate         # Windows
pip install -e ".[dev]"
```

Beim ersten Indexlauf wird das Embedding-Modell
`paraphrase-multilingual-MiniLM-L12-v2` (~120 MB) einmalig nach
`%LOCALAPPDATA%/dsa-rules-mcp/models/` heruntergeladen.

## Index aufbauen oder refreshen

```bash
dsa-rules-cli refresh                      # inkrementell ueber alle Quellen
dsa-rules-cli refresh --source hausregeln  # nur eine Kategorie
dsa-rules-cli refresh --force              # komplettes Rebuild
```

`refresh` erkennt neue, geaenderte und entfernte PDFs anhand von `mtime` und
`sha256`. Die Aktion ist wiederholbar und ein zweiter Lauf ohne Aenderungen
ist ein No-Op.

## Manuelle Abfrage

```bash
dsa-rules-cli search "Zauberdauer modifizieren"
dsa-rules-cli search "Parade" --sources regelbuecher hausregeln --limit 5
dsa-rules-cli list
```

## Einbindung in Claude Code

```bash
claude mcp add dsa-rules -- python -m dsa_rules_mcp
```

Der Server stellt dann folgende MCP-Tools bereit:

| Tool             | Zweck                                                                         |
|------------------|-------------------------------------------------------------------------------|
| `search_rules`   | Hybrid-Suche (FTS5 + Vektor) ueber ausgewaehlte Quellen.                      |
| `get_context`    | Vollen Text eines Treffers + benachbarter Chunks zurueckgeben.                |
| `list_sources`   | Listet alle indexierten PDFs je Kategorie.                                    |
| `refresh_index`  | Inkrementeller oder vollstaendiger Neu-Index.                                 |
| `find_topic`     | Thematisch gebuendelte Treffer fuer Anforderungs-Brainstorming.               |

## Tests

```bash
pytest
```
