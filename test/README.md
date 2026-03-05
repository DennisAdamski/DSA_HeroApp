# Test Layout

## Struktur

- `rules/`: nur pure Logik-/Regel-/Formeltests
- `ui/`: nur technische Widget-Tests
- `state/`: Provider-/Stream-Tests
- `data/`: Loader/Transfer/Repository-nahe Tests
- `domain/`: Modell- und Serialisierungs-Tests
- `workspace/`: Workspace-Koordinationslogik

## Konventionen

- Dateinamen bleiben `*_test.dart`.
- Testnamen beschreiben Verhalten, nicht Implementierungsdetails.
- Neue Regelchecks immer unter `rules/`, nie in `ui/`.

## Keine Mischtests

- Nicht erlaubt: eine Testdatei prueft gleichzeitig
  Formelarithmetik und UI-Interaktion.
- Stattdessen:
  - Formel in `test/rules/...`
  - UI-Flow in `test/ui/...`
