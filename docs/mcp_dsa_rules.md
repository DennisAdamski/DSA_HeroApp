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

## Veröffentlichen über die Cloud (SPIEL-04)

Die App lädt die Wissensbasis nach dem Entsperren der Katalog-Inhalte
(Katalogpasswort) und mit Anmeldung **im Hintergrund** über die Cloud Function
`rulesIndexApi`. Die Datei liegt gepackt in Firebase Storage unter `rules/`,
`storage.rules` sperrt diesen Pfad für alle Clients. Die Function prüft
Firebase-Konto (bestätigte E-Mail), App Check und einen Passwortnachweis und
liefert dann eine **zehn Minuten gültige** signierte URL. Der Nachweis ist
`SHA-256("rules-index-v1|" + v3-Katalogschlüssel)`; Passwort und Schlüssel
verlassen das Gerät nie (`lib/data/rules_search/rules_index_proof.dart`,
`tool/rules_index_proof.py`, Parität per Golden-Test gesichert).

**Veröffentlichen** (nach `dsa-rules-cli refresh`):

```powershell
dsa-rules-cli publish                    # baut nur, zeigt die Upload-Befehle
dsa-rules-cli publish --upload <BUCKET>  # baut und lädt per gcloud hoch
```

`publish` baut eine Fassung **ohne Vektoren** (die App nutzt nur die
Volltextsuche) und **ohne lokale Quellpfade** (`sources.path` wird zu
`quelle-<id>`), prüft sie (Volltextsuche findet etwas, keine Pfade übrig),
packt sie mit gzip (rund 47 MB statt 168 MB) und schreibt
`index-<sha12>.sqlite.gz` und `latest.json` nach `<Datenordner>/publish`. Der
Upload lädt **erst die Datei** (`Content-Encoding: gzip`, damit Browser und Dart
sie selbst entpacken), **dann** `latest.json`; bricht er ab, zeigt der Verweis
weiter auf die alte Fassung. Ohne `--upload` läuft nichts nach außen.

**Einmalig einrichten** (nur der Projektinhaber kann das):

1. `python tool/rules_index_proof.py` gibt den Nachweis aus (Passwort aus
   `docs/Passwort.env`, wird nie ausgegeben), dann
   `firebase functions:secrets:set RULES_INDEX_PROOF` und den Nachweis einfügen.
   Ändern sich Katalogpasswort oder `catalog_salt_v3`, das Secret neu setzen.
2. Die Function braucht das Recht, URLs zu signieren: ihrem Dienstkonto die
   Rolle `Service Account Token Creator` auf sich selbst geben, sonst meldet sie
   `503 SERVICE_UNAVAILABLE`.
3. Einschalten: `RULES_INDEX_TEST_ENABLED=true` bzw.
   `RULES_INDEX_PRODUCTION_ENABLED=true` in `functions/.env.heldensync-ccf0b`
   eintragen (Standard `false`, wie beim Feedbackdienst), dann **gezielt**
   deployen, nie pauschal (siehe [feedback_betrieb.md](feedback_betrieb.md)):
   `firebase deploy --only storage`,
   `firebase deploy --only functions:rulesIndexApiTest`, später
   `firebase deploy --only functions:rulesIndexApi`.
4. Die Builds tragen die URL über `--dart-define=RULES_INDEX_API_URL=...`
   (`flutter-tests.yml`, `tool/deploy_web.ps1`); ein Build ohne URL hat nur den
   manuellen Weg.

App Check gilt wie beim Feedbackdienst: Windows kennt derzeit nur den
Debugprovider, der Cloud-Weg läuft dort nicht; Windows nutzt weiter den lokal
gebauten Index. Beim lokalen Web-Debuggen (`localhost:5000`) muss das
Debug-Token der Sitzung in der Firebase-Konsole registriert sein, sonst liefert
App Check 403 und die Function lehnt ab.

Grenzen: Wer das Katalogpasswort und ein bestätigtes Konto hat, kommt an die
Texte, das ist dasselbe Vertrauensmodell wie beim verschlüsselten Katalog. Der
Server bremst falsche Nachweise (eine Sekunde) und begrenzt sich auf drei
Instanzen, ein Ratelimit je Konto gibt es nicht. Ein Rückfall für Builds ohne
Cloud-Anbindung bleibt der Server-Sync unten.

## Veröffentlichen (Server-Sync für die App)

Die Flutter-App kann `index.sqlite` alternativ zum manuellen Weg (lokal
bauen bzw. Web-Upload) per Server-Sync beziehen (siehe
`docs/spielmodus_konzept.md` Abschnitt 6). Dafür nach einem vollständigen
Rebuild die Datei unverändert auf die konfigurierte Fritz!NAS/WebDAV-
Freigabe hochladen:

```powershell
dsa-rules-cli refresh --force
# Danach index.sqlite manuell (z.B. per Fritz!NAS-Weboberflaeche oder
# WebDAV-Client) auf die Freigabe hochladen, die in
# RulesIndexRemoteConfig / RULES_INDEX_SERVER_URL referenziert wird.
```

Kein Verschlüsselungsschritt nötig — die App gated den Download stattdessen
über das bestehende Katalog-Entschlüsselungspasswort. Kein CI-Automatismus,
bewusst ein manueller Betriebsschritt.

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
