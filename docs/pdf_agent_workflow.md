# PDF-Agent Workflow

Der PDF-Agent ist ein lokales Repo-Tool fuer die Katalogisierung externer
DSA-Dokumente (`pdf`, `docx`, `odt`) als zitierbare Wissensbasis. Er aendert
keine Runtime-Kataloge direkt,
sondern erzeugt Suchindex, Konflikt-Hinweise, Reports und App-Vorschlaege.

## Standardquellen

Die Default-Konfiguration liegt in `tool/pdf_catalog_agent/config/sources.json`
und verarbeitet diese Ordner fuer Dateien mit den Endungen `pdf`, `docx` und
`odt`:

- `C:\Users\denni\OneDrive\Rollenspiel\DSA\Regelbuecher`
- `C:\Users\denni\OneDrive\Rollenspiel\DSA\Buecher\Regionalbuecher`
- `C:\Users\denni\OneDrive\Rollenspiel\DSA\Zusatzinformationen`
- `C:\Users\denni\OneDrive\Rollenspiel\DSA\hausregeln`

Quellprioritaet:

1. `hausregeln`
2. `regelbuch`
3. `regionalbuch`
4. `zusatzinfo`

Das bedeutet:

- Hausregeln ueberschreiben offizielle Regeln bewusst.
- Regelbuecher bleiben die offizielle Basis unterhalb der Hausregeln.
- Regional- und Zusatzbuecher liefern Kontext und Ideen, ueberschreiben Regeln
  aber nicht stillschweigend.

## Artefakte

Lokale Artefakte liegen unter `.codex/pdf_catalog/` und sind nicht fuer Git
gedacht:

- `catalog.db`: SQLite-Datenbank mit FTS5
- `manifest.json`: letzter Ingest-Lauf und Gesamtzahlen
- `reports/review.md`: Review-Bericht
- `exports/*.json`: exportierte Konflikte, Reviews und Vorschlaege

## Befehle

Index aufbauen oder aktualisieren:

```bash
python tool/pdf_catalog_agent/cli.py ingest
```

Alles neu einlesen:

```bash
python tool/pdf_catalog_agent/cli.py ingest --force
```

Volltextsuche mit zitierbaren Treffern:

```bash
python tool/pdf_catalog_agent/cli.py search --query "Kampf Parade Hausregel"
```

Thematische Vorschlaege erzeugen:

```bash
python tool/pdf_catalog_agent/cli.py propose --topic kampf --json
```

Konflikt- und Prioritaetshinweise anzeigen:

```bash
python tool/pdf_catalog_agent/cli.py conflicts --topic kampf
```

Review-Bericht erzeugen:

```bash
python tool/pdf_catalog_agent/cli.py review
```

## OCR und Grenzen

- Primaere Extraktion erfolgt ueber `pypdf`.
- Wenn Text schlecht oder leer extrahierbar ist, markiert der Agent die Datei
  als `ocr_required`, stoppt den Lauf aber nicht.
- AES-verschluesselte PDFs koennen zusaetzlich das Python-Paket
  `cryptography>=3.1` benoetigen. Solche Fehler werden im `manifest.json`
  protokolliert.
- `tesseract` ist als optionaler spaeterer Fallback vorgesehen. Ohne
  installierten OCR-Stack bleibt v1 trotzdem voll benutzbar.

## Tests

Fuer das Tool gibt es synthetische Python-Tests:

```bash
python -m unittest tool.test_pdf_catalog_agent
```

Die Tests pruefen:

- Konfigurationsauflosung
- Inkrementelles Ingest-Verhalten
- Chunking und FTS-Suche
- Konfliktbeziehungen zwischen Quelltypen
- Vorschlagsobjekte mit Evidenz
- OCR-/Leerausgabe-Review fuer nicht extrahierbare PDFs
