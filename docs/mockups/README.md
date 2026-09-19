# Klickbarer Codex-Entwurf

Stand: 19.09.2026. Gestaltungsrichtung: heller Codex mit dunkler Navigation,
Petrol für Aktionen, Messing als Akzent und dezenten Fantasy-Details.

Die Datei [hero-workspace-redesign.html](hero-workspace-redesign.html) direkt
im Browser öffnen. CSS, JavaScript und die vorhandene lokale Cinzel-Schrift
werden über relative Pfade geladen. Es sind kein Build, keine Installation und
keine Internetverbindung nötig. Die Dateien innerhalb des Repositorys belassen,
damit die relativen Schriftpfade erhalten bleiben.

## Gezeigte Bereiche

- **Spielen:** Ressourcen, häufige Proben mit Filter und Suche, Beispielwürfe,
  Schaden übernehmen und zurücknehmen, Rast, Kampfrunden, Effektlaufzeit,
  Beispielherleitung der Attacke und Notizen zum Spielabend.
- **Held verwalten:** gemeinsames Inventar mit Waffenwechsel, Gegenstände
  hinzufügen, Merkmale mit expliziter Auswahl und editierbare Biografie.
- **Entwicklung planen:** Steigerungen vormerken, aus dem Entwurf entfernen,
  AP-Vorschau und gemeinsame Übernahme der ausgewählten Beispielsteigerungen.
  Vorgemerkte Schritte bleiben beim Bereichswechsel erhalten.

Die Ansicht passt sich schmalen Bildschirmen an. `Strg K` bzw. `Cmd K` fokussiert
die Suche; Dialoge sind per Tastatur bedienbar und mit `Escape` schließbar.
„Zurücksetzen“ lädt die Beispieldaten neu.

## Vorschaubilder

- [Spielen auf dem Desktop](hero-workspace-redesign-desktop.png)
- [Steigerungsplanung](hero-workspace-redesign-planning.png)
- [Spielen auf dem Smartphone](hero-workspace-redesign-mobile.png)

## Prüfung am 19.09.2026

Im Edge-Browser wurden die Navigation, Filter und Suche, Beispielwürfe, Schaden
und Rücknahme, Rast, Effektablauf, Waffenwechsel, Gegenstandserfassung,
Biografieänderungen sowie Steigerungsplanung und Übernahme geprüft.
Leere Suchergebnisse und als Text eingegebene HTML-Zeichen wurden ebenfalls
geprüft. Dabei traten keine JavaScript-Laufzeitfehler auf.

Alle drei Bereiche wurden bei 320, 390, 768, 1024 und 1440 Pixeln Breite auf
horizontalen Überlauf geprüft. Desktop-, Planungs- und Mobilansicht wurden
zusätzlich visuell begutachtet. Direktes Öffnen der HTML-Datei ohne Server und
das Laden der lokalen Gestaltung funktionieren.

`flutter analyze --no-pub` und die beiden Tests aus
`test/ui/smoke/widget_test.dart` waren erfolgreich. Wegen eines hängenden
Windows-Batch-Starts wurde dafür das installierte `flutter_tools.snapshot`
direkt mit dem zugehörigen Dart-SDK aufgerufen.

## Abgrenzung zur App

Dies ist ein eigenständiger HTML-Prototyp für
[ARCH-01 der Architektur-Roadmap](../architecture_roadmap.md#arch-01--oberfläche-nach-spielsituationen-organisieren),
mit sichtbaren Beispielen für die Ziele aus ARCH-02, ARCH-03, ARCH-04 und ARCH-06.
Er implementiert keine Flutter-Oberfläche und schließt keinen Roadmap-Punkt ab.

Die Spielfigur, AP-Kosten, Herleitungen, Regenerationswerte und Würfelergebnisse
sind vorgegebene Beispieldaten. JavaScript simuliert lediglich die Bedienung;
es enthält keine verbindliche DSA-Regelengine. Insbesondere werden Wunden und
die Auswirkungen aktiver Zauber nicht regeltechnisch berechnet.

Alle Änderungen bleiben im Arbeitsspeicher der Browserseite und verfallen beim
Neuladen. Es gibt keine Speicherung echter Heldendaten, keinen Konto-Zugriff,
keinen Netzwerk-Sync und keinen Import aus der App. „Offline verfügbar“ und das
Regelprofil sind Bestandteile des dargestellten Zielbilds.

## Dateien und Verantwortung

- `hero-workspace-redesign.html`: Struktur, Navigation und Dialogcontainer.
- `hero-workspace-redesign.css`: Gestaltung, lokale Schrift und Breakpoints.
- `hero-workspace-redesign.js`: Beispieldaten und flüchtiger Interaktionszustand.
- `hero-workspace-redesign-*.png`: überprüfte Vorschaubilder.

Das bestehende `combat-tracker-mockup.html` bleibt ein separater Entwurf.
Die neuen Redesign-Dateien und diese Anleitung werden gezielt versioniert;
die allgemeine Ignore-Regel für sonstige lokale Mockups bleibt bestehen.
Vor einer Umsetzung in Flutter die Roadmap-Abhängigkeiten, vollständige
Funktionsabdeckung und noch offenen Produktentscheidungen prüfen.

## Übergang zur Flutter-Umsetzung

Die [Redesign-Übergabe](../redesign_implementation.md) enthält drei konkrete
Umsetzungspläne mit Startprompts für weitere Agenten. Sie nutzen das inzwischen
vorhandene Kartograph-Fundament unter `lib/ui2/`, übernehmen die drei
Arbeitsbereiche und grenzen simulierte Funktionen von vorhandener Fachlogik ab.
Die Pläne sind Arbeitsaufträge, kein Nachweis ihrer Umsetzung.
