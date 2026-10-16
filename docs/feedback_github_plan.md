# Direktes App-Feedback als GitHub-Issue

Stand: 16. Oktober 2026. Implementierung und Staging-Smoke-Test sind
abgeschlossen. Der Produktionsendpoint ist bereitgestellt und aktiviert; der
Produktions-Webbuild verwendet ihn nach dem geprüften `main`-Deployment.
Betriebsschritte stehen in [feedback_betrieb.md](feedback_betrieb.md).

## Umgesetzter Umfang

Angemeldete Nutzer können drei getrennte, öffentlich sichtbare Meldungen senden:

- Bug → `bug`: Titel, tatsächliches und erwartetes Verhalten, optionale
  Reproduktionsschritte und ein vollständig abwählbares Diagnosepaket.
- Feature-Anfrage → `enhancement`: Titel, zu lösendes Problem und gewünschtes
  Verhalten.
- Regelfrage → `question`: Titel und Frage sowie optional Fundstelle und eigene
  Auslegung.

Alle Meldungen enthalten App-Version, Buildnummer, Commit, Bauzeit, Plattform
und einen korrigierbaren, heldenunabhängigen Bereich. Die erlaubten Bereiche
sind Heldenauswahl, Übersicht, Talente, Kampf, Magie, Inventar, Notizen,
Reisebericht, Begleiter, Gruppe, Spielmodus, Entwicklung, Einstellungen,
Katalogverwaltung und Sonstiges.

Die Bugdiagnose enthält ausschließlich Betriebssystem/-version, Sprache,
Fenstergröße, Pixeldichte, Layoutklasse, Codex/Kartograph, Hell/Dunkel,
Tabellenmodus sowie Firebase- und Anmeldestatus. Gerätekennung/-modell, UID,
E-Mail, Helden- und Sync-Inhalte, Speicherpfade, Navigation, Logs, Screenshots
und Anhänge werden nicht übertragen.

## App-Architektur

Die typisierten Verträge liegen unter `lib/domain/feedback/`, Transport,
Diagnosesammler und textfreie Wiederherstellung unter `lib/data/feedback/`.
Provider und Controller liegen unter `lib/state/feedback/`. Die gemeinsame UI
liegt bewusst unter `lib/ui_shared/feedback/`, damit Codex und Kartograph
dieselbe Implementierung verwenden, ohne die Importgrenze `lib/ui2 → lib/ui`
zu verletzen.

Zugänge bestehen in den Einstellungen sowie als gemeinsame Aktion in beiden
Heldenauswahlen und beiden Workspaces. Workspace-Einstiege respektieren die
vorhandenen Editor-Guards; eine offene Entwicklungsplanung bleibt beim
aufgelegten Feedback-Screen bestehen. Ohne bestehende App-Anmeldung erscheint
nur der Anmeldehinweis.

Die Vorschau zeigt Issue-Titel, Markdown-Text und sämtliche öffentlichen
Metadaten. GitHub-Erwähnungen sind bereits dort neutralisiert. Während des
Sendens ist die Aktion gesperrt. Nur `created` zeigt Issue-Nummer und Link als
Erfolg. `processing` und `uncertain` behalten eine kontogebundene, textfreie
Referenz und bieten ausschließlich eine Statusabfrage an; es gibt keinen
automatischen zweiten POST.

Der Endpoint wird ausschließlich mit `--dart-define=FEEDBACK_API_URL=...`
gesetzt. Ohne gültige URL bleibt Feedback deaktiviert. Damit wählen Test- und
Produktionsbuild explizit genau einen Endpoint; Repository, Umgebung und Labels
sind niemals Clientparameter.

## Backend-Architektur

Unter `functions/` stehen zwei Gen-2-Functions mit gemeinsamem Handler in
`europe-west10` und Node.js 22:

- `feedbackApiTest`: ergänzt `feedback-test`.
- `feedbackApi`: produktiver Endpoint ohne Testlabel.

Beide ergänzen `in-app-feedback` und genau `bug`, `enhancement` oder `question`.
Das Ziel ist fest `DennisAdamski/DSA_HeroApp`. Firebase-ID-Tokens werden mit dem
Admin SDK geprüft; das Fine-grained PAT kommt ausschließlich aus dem Secret
`GITHUB_FEEDBACK_TOKEN`. Beide Functions sind standardmäßig deaktiviert.

Der Vertrag `schemaVersion: 1` lehnt unbekannte Felder ab. Grenzen sind 5–120
Grapheme für Titel, 20–8.000 für Pflichttexte, höchstens 300 für Fundstellen
und 32 KiB für den gesamten Request. Serverseitige Markdown-Vorlagen
neutralisieren Erwähnungen und erzeugen die feste öffentliche Darstellung.

Ein atomarer Firestore-Claim bindet `requestId`, normalisierten Payload-Hash
und Status an das authentifizierte Konto. Neue Meldungen sind auf drei pro
rollierender Stunde und zehn pro rollierendem Tag begrenzt; identische
Wiederholungen zählen nicht erneut. Ein unklarer GitHub-Ausgang wird
`uncertain` und nie automatisch erneut gepostet. Eine spätere Statusabfrage
sucht nach dem unpersönlichen Korrelationsmarker. Firestore erhält keine
Nutzertexte, sondern nur Eigentümerzuordnung, Hash, Status, Marker,
Issue-Referenz und `expiresAt` für 7 Tage.

## Prüfungen

Automatisiert vorhanden:

- Backendschemas, Grenzen, unbekannte Felder, Auth, CORS, feste Ziele/Labels,
  GitHub-Fehler, parallele Requests, Hashkonflikt, Quoten, fremde Statusabfrage
  und Wiederherstellung nach einem unklaren POST-Ausgang.
- Firestore-Emulatortest: App-Nutzer können `feedbackSubmissions` und
  `feedbackRateLimits` weder lesen noch schreiben.
- Flutter-Vertragstests für JSON, Header, Tokenwechsel, Timeout ohne Retry,
  Statusabfrage, Diagnose-Abwahl und kontogebundene Wiederherstellung.
- Widgettests für alle Formulare, Vorschau, fehlende Anmeldung,
  Doppelklickschutz, Fehlererhalt, `uncertain`, 320 Pixel und große Schrift.
- Navigationstests für Einstellungen, Codex und Kartograph sowie bestehende
  Import- und Editorgrenzen.

Lokale und CI-Abschlussbefehle:

```powershell
Set-Location functions
npm ci
npm test
npm run build
npm run test:rules # benötigt Java 21

Set-Location ..
flutter analyze
flutter test
python tool/check_screen_loc_budget.py --max-lines 700
flutter build web --release --dart-define=FEEDBACK_API_URL=<freigegebener Endpoint>
```

## Betriebsstand

- `feedbackApiTest` und `feedbackApi` sind in `europe-west10` bereitgestellt;
  der Staging-Smoke-Test wurde manuell erfolgreich bestätigt.
- Der Produktionsendpoint ist aktiviert. Die Test- und Produktions-Webbuilds
  erhalten getrennte URLs und verifizieren diese im Bundle.
- Firestore-TTL ist aktiv; Metadatensätze verfallen sieben Tage nach Anlage
  beziehungsweise letzter Aktivität.

Version 1 bleibt ein Einwegkanal ohne Kontaktdaten, Entwurfsspeicherung,
Anhänge, Screenshots oder Ticketpostfach.
