# Frühere Einstiegsliste der CLAUDE.md

Ausgelagert am 16.10.2026, Wortlaut unverändert (die langen Themenbullets stehen in den Dateien dieses Ordners). Die Zeiger sind in der kurzen [CLAUDE.md](../../CLAUDE.md) unter „Weitere Dokumente“ zusammengefasst.

- [Fantasy-Waffensymbole](../fantasy_weapon_assets.md): 29 transparente PNGs
  unter `assets/ui/fantasy_weapons_v1/`; `manifest.json` ordnet Waffenarten
  und die 27 Kampftalentgruppen anhand bestehender Katalogwerte und IDs zu.

- [Fantasy-Assets](../fantasy_assets.md): 12 transparente Symbole und drei
  dekorative PNGs unter `assets/ui/fantasy_v1/`, für Flutter registriert.
  Vorschau und Generierungsprompts liegen unter `docs/fantasy_assets*`.
- `AGENTS.md` ist die verbindliche Agentenrichtlinie.
- `README.md` beschreibt Produktumfang, Architekturueberblick und Standard-Workflows.
- `tool/sync_main_to_test.sh` mergt Main in Test;
  `tool/test_main_test_sync.py` sichert Erhalt, Konflikte und Wiederholungen ab.
- `docs/web_deployment.md` beschreibt Web-CI, Testbranch, automatischen Main-Test-Sync und Hosting-Targets.
- [Architektur-To-dos](../architecture_roadmap.md) halten sieben offene
  Verbesserungen mit Ist-Zustand, Abhängigkeiten und Abnahmekriterien fest.
  Bei Architekturarbeiten den Aufgabenstatus prüfen und nach abgeschlossenen
  Teilumfängen aktualisieren.
- [ARCH-02-Herkunftsmerkmale](../superpowers/specs/2026-10-10-arch02-herkunftsmerkmale-design.md)
  beschreibt die freigegebene Spezifikation: strukturierte direkte
  Herkunftsmodifikatoren und Herkunftsmetadaten an bestehenden Vor-/Nachteilen.
  Umgesetzt (13.10.2026, [Implementierungsplan](../superpowers/plans/2026-10-10-arch02-herkunftsmerkmale.md));
  offen ist nur die manuelle Bedienprüfung. Nächste Arbeitspakete stehen in der Roadmap.
- [ARCH-06-Abnahmeprüfung](../arch06_abnahme.md): technisch abgenommen am
  12.10.2026. Konfliktentscheidungen über Bogen und Zustand laufen als
  `SyncKonfliktVorgang` im Profiljournal (`lib/data/sync/`,
  `syncing_hero_repository_vorgang.dart`) und setzen nach Abbruch oder Neustart
  fort; betroffene IDs sind bis dahin für normalen Sync gesperrt. Grenzen und
  Vertrag: [Wiederanlaufvertrag](../superpowers/specs/2026-10-10-arch06-konflikt-wiederanlauf-design.md)
  und Speichervertrag. Geräte-/Live-Firebase-Prüfung steht aus.
- Detaildokumentation liegt bei Bedarf in `docs/technical_overview.md`, `docs/test_strategy.md`, `docs/catalog_import_workflow.md`, `docs/pdf_agent_workflow.md`, `docs/rule_audit_regelwerk_ueberarbeitung.md`, `docs/ios_xcode_setup.md` und `docs/windows_antivirus_audit.md`.
