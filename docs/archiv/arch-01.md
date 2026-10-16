# Archiv — ARCH-01 Oberfläche nach Spielsituationen organisieren

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

## ARCH-01 — Oberfläche nach Spielsituationen organisieren

**Ist-Zustand:** Der Workspace ist nach Fachgebieten wie Talente, Kampf, Magie
und Inventar gegliedert. Bearbeiten und Steigern sind bereits getrennt;
Steigerungsrunden, Proben-Schnellsuche und Inspector existieren.

**Ziel:** Drei verständliche Arbeitsbereiche: **Spielen**, **Held verwalten**
und **Entwicklung planen**. Spielen priorisiert Ressourcen, häufige Proben,
Kampfaktionen und aktive Effekte. Verwaltung erschließt die vollständigen Daten
und manuelle Korrekturen. Entwicklung bündelt Erwerb, Voraussetzungen, AP und
Auswirkungsvorschau.

**Einstieg:** `lib/ui/screens/hero_workspace_screen.dart`,
`lib/ui/screens/workspace/workspace_tab_spec.dart`,
`lib/ui/screens/workspace/probe_quick_search.dart`,
`lib/ui/screens/workspace/inspector/`, `lib/ui/screens/advancement/` und
[Spielmodus-Konzept](../spielmodus_konzept.md).

**Entwurfsstand 19.09.2026:** Ein [klickbares Codex-Mockup](../mockups/hero-workspace-redesign.html)
zeigt die drei Arbeitsbereiche mit Beispieldaten. Bedienung und Abgrenzungen
stehen in der [Mockup-Anleitung](../mockups/README.md). Es ist ein visueller Entwurf;
die Flutter-Umsetzung und die vollständige Funktionszuordnung bleiben offen.

- [x] Vorhandene Aktionen den drei Arbeitsbereichen zuordnen und Navigation für
  schmale sowie breite Ansichten entwerfen; aktuelle Funktionen vollständig erfassen.
  *(Funktionsparität-Tabelle in [redesign_acceptance.md](../redesign_acceptance.md),
  geprüft gegen die neun Abschnitte aus `workspace_tab_spec.dart`; Raster
  320–1440 dp, 28 Kombinationen.)*
- [x] Bestehende Proben-, Steigerungs- und Inspector-Komponenten wiederverwenden;
  die Spielansicht um direkten Zugriff auf häufige Aktionen ergänzen.
  *(R2 samt Schnellproben, Rast, Effekte, Schaden; Gefecht unter `lib/ui2/gefecht/`.)*
- [x] „Schaden erhalten“ als zusammenhängenden Ablauf mit Ressourcenänderung,
  gegebenenfalls Wunden und nachvollziehbarer Korrekturmöglichkeit anbieten.
  *(Ablauf, Dialog und UI2-Schnellaktion umgesetzt, siehe ARCH-05 Teilstand
  (3); Rücknahme am Protokolleintrag seit ARCH-06 Teilstand 2.)*

**Abnahme:** Häufige Spielaktionen sind direkt aus der Spielansicht erreichbar.
Manuelle Korrektur und AP-pflichtige Entwicklung bleiben unterscheidbar. Ein
Bereichswechsel verliert keine ungespeicherten Eingaben oder Steigerungsentwürfe.
Der Schadensablauf verwendet dieselben Regeln wie die übrige App.

**Prüfung:** Widgettests unter `test/ui/workspace/`, `test/ui/advancement/` und
`test/ui/shared/`; Bedienprüfung auf schmalen und breiten Fenstern. Neue fachliche
Schadensregeln separat unter `test/rules/` prüfen.

**Umsetzungsstand 19.09.2026:** Die Flutter-Umsetzung hat als
Oberflächen-Neubau begonnen. Bestand (`lib/ui/`) und Neubau (`lib/ui2/`)
laufen parallel, `AppSettings.oberflaeche` schaltet um. Fertig sind:

- **Aufräumen.** Toter Legacy-Screen entfernt, UI-Variante `klassisch` samt
  zweitem Theme gestrichen.
- **Naht und Umschalter.** `AppRootSwitch` als `child` von `SyncConflictGate`;
  ein Wechsel tauscht nur den Bildschirm und baut Heldenspeicher, Sync und
  Katalog nicht neu auf (`test/ui2/shell/app_root_switch_test.dart`).
- **Token-Schicht.** Farb-, Abstands-, Linien- und Schriftskalen unter
  `lib/ui2/theme/` und `lib/ui2/foundation/`, Sichtprüfung über das
  Token-Blatt. Dabei fiel auf, dass Merriweather und Cinzel ihren Fettschnitt
  nur behaupten: Regular und 700 zeigen in `pubspec.yaml` auf dieselbe Datei.
  Der Neubau verhindert das durch zwei Tests, einen auf das Manifest und einen,
  der die Zeichenbreiten misst.

**Planungsstand nach Mockup-Freigabe, 19.09.2026:** Die
[Umsetzungspläne mit Agentenprompts](../redesign_implementation.md) setzen auf dem
vorhandenen UI2-Fundament auf. Für diese Folgeaufträge gelten die **drei
Arbeitsbereiche des freigegebenen Mockups**. Damit wird der ältere Vorschlag
mit zwei Bereichen ersetzt. Entwicklung bleibt technisch eine Sitzung, erhält
aber einen eigenen sichtbaren Bereich. R1–R3 decken den ersten produktiven
UI-Stand ab, nicht den zusätzlichen atomaren Schadensablauf.

**Umsetzungsstand 20.09.2026 — Paket R1 fertig:** Der Neubau ist ein
benutzbarer Rahmen mit echten Helden. Umgesetzt sind die drei Arbeitsbereiche
mit dunkler Navigation, die Heldenwahl über die vorhandenen Provider und der
Schutz ungespeicherter Eingaben bei Modus-, Helden- und Oberflächenwechsel
einschließlich System-Zurück. Tabs, Editoraktionen und Leave-Guard der
Verwaltung liegen jetzt im gemeinsamen `WorkspaceManagementCoordinator`, den
beide Oberflächen benutzen; die vollständigen Fachansichten erreicht der
Neubau vorerst über die injizierte Brücke `KartoBestandsAdapter`. Nachweise,
Commit-IDs und Abgrenzungen stehen unter „R1: Übergabe“ in den
[Umsetzungsplänen](../redesign_implementation.md).

**ARCH-01 ist abgenommen (funktional 11.10.2026, manuelle Bedienprüfung
15.10.2026).** Die Spielanordnung mit echten Werten und
Bestandsaktionen ist umgesetzt (R2), ebenso die gestalterische Integration der
Fachansichten und der Entwicklungsbereich samt Gesamtabnahme (R3, siehe
[redesign_acceptance.md](../redesign_acceptance.md)). „Schaden erhalten“ gibt es
seit dem ARCH-05-Teilstand (3) als geführten Ablauf in beiden Oberflächen,
zurücknehmbar seit ARCH-06 Teilstand 2.

**Abnahmeprüfung 11.10.2026 — funktional abgenommen; manuelle Prüfung am
15.10.2026 nachgeholt.** Der Hauptpunkt wurde erst mit der Bedienprüfung abgehakt.

- *Automatisiert:* `flutter analyze --no-pub` ohne Befund;
  `flutter test --no-pub --concurrency=1 test/ui2 test/ui/workspace
  test/ui/advancement test/ui/shared`: 805 bestanden, 3 übersprungen.
- *Kriterien:* Direktzugriff (Spielansicht, Gefecht, Schaden mit Rücknahme),
  Schutz vor Datenverlust bei Bereichs-/Helden-/Oberflächenwechsel und die
  Trennung Verwaltung/Entwicklung sind durch die Tests in
  [redesign_acceptance.md](../redesign_acceptance.md) belegt.
- *Abgespalten:* Persönliche Favoriten (eigener Auftrag, Persistenz und Sync
  zu entscheiden); Offline-/Sync-Statusanzeige (gehört zu ARCH-06); persistenter
  Kampfrundenzähler bleibt aus, das Gefecht führt Runden flüchtig.
- *Manuell:* Checkliste in
  [redesign_acceptance.md](../redesign_acceptance.md#manuelle-bedienprüfung-abgenommen-15102026)
  am 15.10.2026 vom Nutzer vollständig bestätigt (Gerät nicht vermerkt).

**Abhängigkeiten / offene Entscheidungen:** Schreibende Spielaktionen auf
ARCH-05/06 aufbauen. Navigation und Korrekturbedienung sind umgesetzt;
Favoritenverhalten ist noch zu konkretisieren. Die im Spielmodus-Konzept vereinbarte Spielerrolle
beibehalten; eine Spielleiterverwaltung ist kein impliziter Bestandteil.
