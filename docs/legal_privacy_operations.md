# Datenschutz- und Rechtstext-Betrieb

Stand: 17. Oktober 2026. Diese technische Dokumentation ersetzt keine
individuelle Rechtsberatung. Die veröffentlichten Texte und die dokumentierte
Fanprojekt-Freigabe müssen vor dem öffentlichen Release fachlich geprüft werden.

## Öffentliche Seiten und Pflichtangaben

Die Flutter-Web-App stellt `/datenschutz` und `/impressum` ohne Anmeldung bereit.
Beide Texte sind außerdem unter `Einstellungen > Rechtliches` verlinkt. Die
Kontaktdaten kommen aus öffentlichen Build-Parametern:

- `LEGAL_RESPONSIBLE_NAME`
- `LEGAL_STREET_ADDRESS`
- `LEGAL_POSTAL_CODE`
- `LEGAL_CITY`
- `LEGAL_COUNTRY`
- `LEGAL_CONTACT_EMAIL`

CI und `tool/deploy_web.ps1` brechen einen Release ab, sobald einer dieser Werte
fehlt. Lokale Entwicklungsbuilds zeigen stattdessen eine unübersehbare Warnung.
Die Werte sind kein Secret: Sie erscheinen bestimmungsgemäß im Impressum.

## Verzeichnis der Verarbeitungstätigkeiten

| Vorgang | Daten | Zweck | Rechtsgrundlage | Empfänger | Löschung |
|---|---|---|---|---|---|
| Lokale Heldenverwaltung | Helden, Einstellungen, lokale Geheimnisse | App-Funktion | Vertrag bzw. Nutzeranfrage | keine | durch Nutzer oder Betriebssystem |
| Konto und Sync | E-Mail, Auth-Metadaten, Helden, Zustände, Sync-Metadaten | geräteübergreifender Sync | Art. 6 Abs. 1 lit. b DSGVO | Google/Firebase | Konto-/Einzellöschung, danach Anbieterfristen |
| Avatare | Bilddateien unter Konto-UID | Anzeige und Sync | Art. 6 Abs. 1 lit. b DSGVO | Google Cloud Storage | Einzellöschung oder Kontolöschung |
| App-Sicherheit | IP-, Geräte-, Token- und App-Check-Daten | Missbrauchs- und Zugriffsschutz | Art. 6 Abs. 1 lit. f DSGVO | Google/Firebase | Anbieter- und Sicherheitsfristen |
| Feedback | freigegebener Text, technische Diagnose, Request-ID | öffentliches GitHub-Issue | Art. 6 Abs. 1 lit. a DSGVO | GitHub, öffentlich | Metadaten 7 Tage; Issue grundsätzlich unbefristet bzw. auf Anfrage |
| Bildgenerierung | Prompt, optionales Referenzbild | angeforderte Bildgenerierung | Art. 6 Abs. 1 lit. a DSGVO | OpenAI | standardmäßige Abuse-Logs bis zu 30 Tage, vorbehaltlich Ausnahmen |

Firebase Authentication wird laut Firebase ausschließlich in US-Rechenzentren
verarbeitet. Andere verwendete Firebase-Dienste können auf globaler
Infrastruktur laufen. Maßgeblich bleiben die jeweils aktuellen
Verarbeitungsbedingungen, Unterauftragsverarbeiter und Transfermechanismen:

- https://firebase.google.com/support/privacy/
- https://firebase.google.com/terms/data-processing-terms
- https://developers.openai.com/api/docs/guides/your-data

## Technische und organisatorische Maßnahmen

- kontogebundene Firestore-/Storage-Regeln und standardmäßig gesperrte Pfade;
- TLS durch Firebase Hosting und Dienstendpunkte;
- App Check, widerrufsgeprüfte ID-Tokens und E-Mail-Verifikation vor
  gehärteten Feedback-Aufrufen;
- minimal berechtigte Service-Identitäten als Zielzustand;
- verschlüsselte Remote-Geheimnisse, getrennte Passphrase und keine
  dauerhafte Schlüsselablage im Web als Zielzustand;
- eng begrenzte CORS-Origins, Bild-MIME-Typen und Security-Header;
- Rate-Limits, kurze Metadatenfristen, Secret-Rotation und Zugriffsprüfungen;
- Dependency-, Secret- und SAST-Prüfungen sowie getrennte Deploy-Freigaben.

Offene Zielzustände dürfen nicht als bereits produktiv dargestellt werden.
Der konkrete Rollout- und Incident-Ablauf steht in
[`security_operations.md`](security_operations.md).

## Löschkonzept und Betroffenenanfragen

Die vollständige Kontolöschung muss Auth-Konto, Firestore-Unterbäume, Avatare,
Remote-Geheimnisse und Feedback-Metadaten idempotent entfernen. Lokale Daten
werden wegen ihrer Gerätebindung separat zur Löschung angeboten. Bis dieser
automatisierte Ablauf implementiert und abgenommen ist, werden Lösch- und
Auskunftsanfragen über `LEGAL_CONTACT_EMAIL` bearbeitet und dokumentiert.

Für Auskunft und Datenübertragbarkeit ist ein maschinenlesbarer Kontoexport
vorgesehen. Öffentliche GitHub-Issues benötigen eine gesonderte Prüfung, weil
Forks, Benachrichtigungen und externe Caches nicht vollständig kontrolliert
werden können.

## Speichertechnologien und Einwilligung

Die App nutzt lokale Browser-/Gerätespeicherung ausschließlich für die vom
Nutzer angeforderten Funktionen. Analytics, Marketing und Werbe-Tracking sind
nicht eingebunden. Daher wird derzeit kein Cookie-Banner angezeigt. Jede neue
Telemetrie oder Drittanbieter-Einbindung erfordert vor Aktivierung eine erneute
Prüfung von Datenschutzerklärung, Rechtsgrundlage und § 25 TDDDG.
