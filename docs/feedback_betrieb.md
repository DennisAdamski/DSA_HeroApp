# Betrieb des In-App-Feedbackdienstes

Stand: 16. Oktober 2026. `feedbackApiTest` und `feedbackApi` sind im Projekt
`heldensync-ccf0b` in `europe-west10` bereitgestellt und aktiviert. Der
Staging-Smoke-Test war erfolgreich. Die Produktions-Webapp wird über den
geprüften `main`-Workflow mit `feedbackApi` veröffentlicht.

Die erforderlichen Gen-2-Dienste sind aktiviert. Das Secret
`GITHUB_FEEDBACK_TOKEN` hat eine aktive Version. Der Tokenwert wurde nicht
ausgelesen; der erfolgreiche Staging-Smoke-Test bestätigt seine Nutzbarkeit.
`FEEDBACK_TEST_ENABLED` und `FEEDBACK_PRODUCTION_ENABLED` steuern die beiden
Endpunkte unabhängig; beide stehen nach dem freigegebenen Rollout auf `true`.
Die Test-Webapp ist unter `https://heldensync-test.web.app` auf `feedbackApiTest`
konfiguriert. Die Produktions-Webapp ist unter
`https://heldensync-ccf0b.web.app` auf `feedbackApi` konfiguriert.

## Dienste und feste Grenzen

Die Gen-2-Functions `feedbackApiTest` und `feedbackApi` laufen in
`europe-west10` mit Node.js 22. Beide schreiben ausschließlich in
`DennisAdamski/DSA_HeroApp`. Der Testendpunkt ergänzt `feedback-test`, beide
Endpunkte ergänzen `in-app-feedback` sowie genau eines der Labels `bug`,
`enhancement` oder `question`.

Der gehärtete Endpunkt akzeptiert nur widerrufsgeprüfte Firebase-ID-Tokens von
E-Mail-verifizierten Konten und zusätzlich einen gültigen App-Check-Token. Die
Web-/Mobile-Clients holen beide Tokens unmittelbar vor dem Aufruf. Eine neue
Function-Version darf deshalb erst bereitgestellt werden, wenn App Check für
die betreffende App registriert, der Site-Key in den Builds gesetzt und die
Clientversion veröffentlicht ist. Windows unterstützt derzeit nur den
App-Check-Debugprovider; produktive Windows-Aufrufe bleiben bis zu einem
eigenen Attestierungs-/Gatewayweg deaktiviert.

Das Secret `GITHUB_FEEDBACK_TOKEN` ist ein Fine-grained PAT mit Zugriff nur auf
dieses Repository und `Issues: write`. Es wird niemals in einer Datei, einem
Build-Parameter oder Firestore gespeichert. Geplanter Ablauf: 180 Tage.

## Einmalige Vorbereitung

1. Die bereits aktivierten Cloud-Functions-, Cloud-Build-, Artifact-Registry-,
   Cloud-Run- und Eventarc-Dienste müssen nicht erneut aktiviert werden.
2. In GitHub die Labels `in-app-feedback` und `feedback-test` anlegen. Die
   Standardlabels `bug`, `enhancement` und `question` müssen bestehen bleiben.
3. Das PAT lokal mit `firebase functions:secrets:set GITHUB_FEEDBACK_TOKEN`
   setzen. Den Tokenwert nie in Shell-Historie, Chat oder Dokumentation kopieren.
4. `FEEDBACK_TEST_ENABLED` nur für Staging und `FEEDBACK_PRODUCTION_ENABLED`
   nur für den freigegebenen Produktivbetrieb aktivieren. Sonst bleiben beide
   Endpunkte deaktiviert.
5. Vor der App-Check-Erzwingung zuerst Metriken im Monitoring-Modus beobachten,
   Debugtokens nur lokal registrieren und niemals in Release-Bundles ablegen.
6. Für beide Functions eine dedizierte Runtime-Service-Identity verwenden. Sie
   benötigt nur Zugriff auf die beiden Feedback-Collections und genau die
   verwendete Secret-Version; die Standard-Compute-Identity ist kein Zielzustand.

## Prüfung und gezieltes Deployment

Lokale Backendprüfung:

```powershell
Set-Location functions
npm ci
npm test
npm run build
npm run test:rules
```

Der Firestore-Emulator benötigt Java 21. Unter Windows kann dafür beispielsweise
die mit Android Studio ausgelieferte JBR verwendet werden.

Die Testfunction ist bereits bereitgestellt. Ihr Parameter wird in der lokalen
Projekt-Parameterdatei gesetzt und ausschließlich die Testfunction aktualisiert:

```powershell
firebase deploy --only functions:feedbackApiTest
```

Der Smoke-Test erstellt ein öffentliches Issue, prüft Inhalt, Labels und Link
und schließt es mit einem eindeutigen Testhinweis. Er löscht das Issue nicht.
Die Produktionsfunction wird separat und gezielt mit `functions:feedbackApi`
bereitgestellt; ein pauschales `firebase deploy` ist ausgeschlossen.

CI-Builds auf `test` und `main` erhalten jeweils explizit die URL ihrer
Feedback-Function (`feedbackApiTest` bzw. `feedbackApi`) und verifizieren sie
im Bundle. Ohne eine solche Definition bleibt der Client deaktiviert; eine URL
wird nicht automatisch geraten.

## Datenschutz, Limits und Störungen

Firestore speichert keine Feedbacktexte. Interne Dokumente enthalten nur
Kontozuordnung, Request-ID, Payload-Hash, Korrelationsmarker, Status und bei
Erfolg die öffentliche Issue-Referenz. `expiresAt` wird auf sieben Tage nach
Anlage gesetzt; die Firestore-TTL löscht abgelaufene Dokumente. Direkter
App-Zugriff auf `feedbackSubmissions` und `feedbackRateLimits` bleibt durch die
abschließende Deny-Regel gesperrt.

Je Konto gelten drei neue Meldungen pro Stunde und zehn pro rollierendem Tag.
Ein identischer Retry verbraucht keine weitere Quote. `uncertain` bedeutet,
dass GitHub das Issue möglicherweise erstellt hat; in diesem Zustand niemals
einen neuen POST auslösen. Der Statusabgleich sucht nur nach dem unpersönlichen
Korrelationsmarker.

Bei Missbrauch zuerst den betroffenen Function-Parameter deaktivieren. Danach
Functions- und GitHub-Metriken prüfen, ohne Token, Feedbacktext, UID oder
GitHub-Antwortkörper in Betriebslogs zu übernehmen.

## Rotation

Vor Ablauf des PAT einen neuen Fine-grained Token mit denselben Minimalrechten
erstellen, das Firebase-Secret ersetzen, ausschließlich den Testendpunkt
bereitstellen und den Smoke-Test wiederholen. Erst danach das alte PAT löschen
und die Produktionsfunction gezielt neu bereitstellen.
