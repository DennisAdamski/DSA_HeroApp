# MCP-Server: dsa-rules

Lokaler MCP-Server für hybride Volltextsuche über DSA-Regelwerke,
Regionalbücher, Zusatzinformationen und Hausregeln.

## Architektur

```
PDF / ODT / DOCX
       │
   Chunking
       │
  ┌────┴────┐
  FTS5      Vektor-Index
(SQLite)  (sentence-transformers)
  └────┬────┘
Reciprocal Rank Fusion
  + Quellen-Priorität
       │
   MCP-Tools
```

- **FTS5**: SQLite-Volltextsuche für Keyword-Treffer.
- **Vektor-Index**: `paraphrase-multilingual-MiniLM-L12-v2` (~120 MB,
  wird beim ersten Start nach `%LOCALAPPDATA%/dsa-rules-mcp/models/`
  heruntergeladen).
- **RRF**: Kombiniert beide Ranking-Listen und gewichtet nach Quellen-Priorität.

Quellcode: `tool/mcp_dsa_rules/`  
Datenbank und Modell-Cache: `%LOCALAPPDATA%/dsa-rules-mcp/` (überschreibbar
via `DSA_MCP_DATA_DIR`).

## Voraussetzungen

- Python ≥ 3.10
- Mindestens eine der konfigurierten Quelldateien muss existieren

## Setup

```powershell
.\tool\mcp_dsa_rules\setup.ps1
```

Das Skript erstellt das `.venv`, installiert das Paket und baut den
Suchindex (inkrementell). Mehrfaches Ausführen ist sicher.

Manuelles Setup:

```powershell
cd tool/mcp_dsa_rules
python -m venv .venv
.venv\Scripts\activate
pip install -e ".[dev]"
dsa-rules-cli refresh
```

## Quellen und Umgebungsvariablen

| Kategorie             | Env-Var                       | Standard-Pfad                                              | Prio |
|-----------------------|-------------------------------|------------------------------------------------------------|------|
| `regelbuecher`        | `DSA_MCP_REGELBUECHER_DIR`    | `%USERPROFILE%\OneDrive\Rollenspiel\DSA\Regelbücher`      | 100  |
| `hausregeln`          | `DSA_MCP_HAUSREGELN_DIR`      | `%USERPROFILE%\OneDrive\Rollenspiel\DSA\hausregeln`       | 110  |
| `zusatzinformationen` | `DSA_MCP_ZUSATZ_DIR`          | `%USERPROFILE%\OneDrive\Rollenspiel\DSA\Zusatzinformationen` | 80 |
| `regionalbuecher`     | `DSA_MCP_REGIONALBUECHER_DIR` | `%USERPROFILE%\OneDrive\Rollenspiel\DSA\Bücher\Regionalbücher` | 60 |

Die Standard-Suche berücksichtigt nur `regelbuecher` und `hausregeln`.
`regionalbuecher` und `zusatzinformationen` müssen im Tool-Aufruf explizit
unter `sources` angegeben werden.

Unterstützte Formate: `pdf`, `odt`, `docx`.

## Index verwalten

```powershell
# Inkrementeller Refresh (erkennt neue/geänderte/entfernte Dokumente)
dsa-rules-cli refresh

# Nur eine Kategorie
dsa-rules-cli refresh --source hausregeln

# Vollständiger Rebuild
dsa-rules-cli refresh --force

# Manuell suchen (ohne MCP)
dsa-rules-cli search "Zauberdauer modifizieren"
dsa-rules-cli list
```

## MCP-Tools

| Tool             | Beschreibung                                                    |
|------------------|-----------------------------------------------------------------|
| `search_rules`   | Hybrid-Suche (FTS5 + Vektor) über ausgewählte Quellen          |
| `get_context`    | Vollen Text eines Treffers + benachbarter Chunks               |
| `list_sources`   | Alle indexierten Dokumente je Kategorie                         |
| `refresh_index`  | Inkrementeller oder vollständiger Index-Rebuild                 |
| `find_topic`     | Thematisch gebündelte Treffer für Anforderungs-Brainstorming   |

## Konfiguration für Claude Code

Die Datei `.mcp.json` im Projekt-Root ist bereits konfiguriert:

```json
{
  "mcpServers": {
    "dsa-rules": {
      "command": "tool/mcp_dsa_rules/.venv/Scripts/python.exe",
      "args": ["-m", "dsa_rules_mcp.server"]
    }
  }
}
```

Claude Code löst den relativen Pfad vom Workspace-Root auf. Der Server
erscheint nach einem Claude-Code-Neustart unter `/mcp`.

## Konfiguration für Codex CLI

Die Datei `codex.json` im Projekt-Root konfiguriert den Server für den
OpenAI Codex CLI:

```json
{
  "mcpServers": {
    "dsa-rules": {
      "command": "tool/mcp_dsa_rules/.venv/Scripts/python.exe",
      "args": ["-m", "dsa_rules_mcp.server"]
    }
  }
}
```

Für eine globale Konfiguration (alle Projekte) kann der Eintrag zusätzlich
in `~/.codex/config.toml` aufgenommen werden:

```toml
[mcp_servers.dsa-rules]
command = "tool/mcp_dsa_rules/.venv/Scripts/python.exe"
args = ["-m", "dsa_rules_mcp.server"]
```

## Troubleshooting

**Server erscheint nicht unter `/mcp`**
→ Prüfen, ob `.venv/Scripts/python.exe` existiert. Falls nicht: `setup.ps1` ausführen.
→ Claude Code neu starten, nachdem `.mcp.json` geändert wurde.

**Leerer Index / keine Treffer**
→ `dsa-rules-cli list` zeigt, ob Dokumente indexiert sind.
→ `dsa-rules-cli refresh` ohne `--force` ergänzt nur neue Dateien; bei
   Verdacht auf korrupten Index `--force` verwenden.

**Embedding-Modell fehlt**
→ Beim ersten `refresh` wird das Modell (~120 MB) heruntergeladen.
   Bei Verbindungsproblemen kann der Cache manuell nach
   `%LOCALAPPDATA%/dsa-rules-mcp/models/` kopiert werden.
