# Sicherheitsbetrieb

Stand: 17. Oktober 2026. Dieses Dokument ergänzt die technischen Regeln im
Repository; es ersetzt keine Datenschutz-Folgenabschätzung oder Rechtsberatung.

## Veröffentlichungsreihenfolge

1. Regeln und Konfiguration lokal prüfen (`tool/test_security_config.py`,
   Rules-Emulator, Function-Tests und Web-Release-Build).
2. App Check je Plattform registrieren und zunächst nur Metriken beobachten.
3. Gehärteten Client auf der Test-Site veröffentlichen und Auth, Feedback,
   Konto-Sync sowie Avatarabruf prüfen.
4. Erst danach App-Check-Prüfungen serverseitig erzwingen und die
   Produktionsversion veröffentlichen.
5. Live-Header, CORS und Cache-Verhalten gegen die Repo-Konfiguration prüfen.

Die Schritte werden nicht gemeinsam mit einem pauschalen `firebase deploy`
ausgeführt. Rules, Storage, Functions und jedes Hosting-Target bleiben getrennte
Freigaben mit eigener Rücknahme.

## Firebase-Schlüssel und App Check

Firebase-Clientschlüssel sind öffentliche Projektkennungen, müssen aber auf
die tatsächlich benötigten APIs und ihre Plattform begrenzt sein:

- Web: feste Hosting-Origins;
- Android: Paketname plus Release-Zertifikat;
- iOS/macOS: Bundle-ID;
- Windows: eigener Web-App-Schlüssel, nicht derselbe Schlüssel wie Web.

App Check verwendet im Web reCAPTCHA Enterprise, unter Android Play Integrity
und auf Apple-Plattformen App Attest mit Device-Check-Fallback. Debugprovider
und Debugtokens sind ausschließlich für lokale Entwicklung. Eine globale
Firestore-Erzwingung ist erst zulässig, wenn der Windows-REST-Zugriff über
einen authentifizierten und rate-limitierten Gateway läuft.

## Alarmierung und Rotation

- Budgetwarnungen für Functions, Firestore, Storage und ausgehenden Traffic;
- Alarm auf erhöhte 401/403/429/5xx-Raten und ungewöhnliche Schreibmengen;
- GitHub-PAT und Registrierungs-Keyword nach Plan sowie sofort nach einem
  Verdacht rotieren;
- Dependency-, Secret- und SAST-Scans in CI, Findings vor Releases bewerten;
- halbjährlich Firebase-/Google-Cloud-IAM, GitHub-Zugriffe, registrierte
  App-Check-Debugtokens und autorisierte Auth-Domains prüfen.

## Datenschutzvorfall

1. Betroffenen Dienst oder Feature-Flag deaktivieren, ohne Beweise zu löschen.
2. Zeitraum, betroffene Datenarten und Konten eingrenzen; keine Geheimnisse oder
   Feedbacktexte in neue Logs kopieren.
3. Tokens/Secrets rotieren und unzulässige Zugriffe sperren.
4. Auswirkungen, Gegenmaßnahmen und Entscheidungszeiten dokumentieren.
5. Melde- und Benachrichtigungspflichten mit der verantwortlichen Stelle
   bewerten; bei meldepflichtigen Vorfällen gilt die DSGVO-Frist.
6. Ursache mit Regressionstest und Runbook-Änderung dauerhaft schließen.
