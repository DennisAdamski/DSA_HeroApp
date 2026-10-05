# Web-CI und feste Testversion

## Ablauf

Arbeitsbranch -> PR nach `test` -> Abnahme -> PR von `test` nach `main`.
Nur Pull Requests nach `test`/`main` (einschließlich weiterer Commits) und Pushes
auf diese beiden Branches starten die CI. Arbeitsbranch-Pushes ohne offenen PR
starten keine Workflows. Die bisherigen automatischen Branch-Previews entfallen.

Die CI prüft Formatierung, Analyse, alle Unit-/Widget-Tests, Screen-LOC-Budget
und Web-Release-Build einschließlich Helden-Assets. Android wird nicht mehr gebaut.
PRs veröffentlichen nichts und benötigen keine Firebase-Secrets.

## Hosting und Daten

- Test: https://heldensync-test.web.app
- Produktion: https://heldensync-ccf0b.web.app

Beide Sites liegen im Projekt `heldensync-ccf0b`; `.firebaserc` ordnet die Targets
`test` und `production` eindeutig zu. Routing und Cache-Header sind identisch.
Die Test-Site hat keine Ablauffrist. Beide Versionen teilen Konten, Cloud-Helden
und Storage: Bearbeitungen synchronisierter Helden wirken in beiden Versionen.
Lokale Browserdaten sind wegen unterschiedlicher Origins getrennt.

Der Deploy-Job wartet auf alle Prüfungen und verwendet genau das Web-Artefakt
desselben Laufs. Nur Pushes deployen. Deployments je Branch sind serialisiert;
Überholte Branch-Stände werden vor Veröffentlichung übersprungen. Push-Läufe
werden nicht während eines Deployments abgebrochen. Fehler belassen die letzte
Veröffentlichung. Das bestehende Secret
`FIREBASE_SERVICE_ACCOUNT_HELDENSYNC_CCF0B` bedient beide Sites.

## Betrieb und manuelle Abnahme

Anmeldung, Heldenladen, Cloud-Sync, Avatare und Import/Export im Browser prüfen.
Testdomains müssen in Firebase Auth als autorisierte Domains eingetragen sein.
Die bestehende Storage-CORS-Regel erlaubt GET/HEAD für die Test-Site; Hosting
ändert die Bucket-CORS-Konfiguration nicht. Browser-Funktionstests bleiben manuell.

Manuelle Veröffentlichung nur mit explizitem Target:
`firebase deploy --only hosting:test` oder `firebase deploy --only hosting:production`.
`firebase deploy --only hosting` würde beide Sites veröffentlichen.
Zur Rücknahme in der Firebase-Konsole die vorherige Veröffentlichung der
betreffenden Site wiederherstellen. Der nächste erfolgreiche Branch-Push
veröffentlicht wieder automatisch. Keine geplanten oder manuellen Actions-Trigger.

## Automatische Übernahme von main

Jeder Push auf `main` mergt den aktuellen main-Stand automatisch nach `test`.
Bestehende Teständerungen bleiben erhalten. Ein Merge-Konflikt stoppt den Sync
mit einer Fehlermeldung in Actions; der entfernte Testbranch bleibt unverändert.
Der Konflikt muss manuell durch einen Merge von main nach test gelöst werden.
Bei konkurrierenden Test-Pushes wird bis zu dreimal neu geladen und gemergt;
es gibt keinen Force-Push. Branch-Schutz kann die Automatik blockieren.

Nach einem erfolgreichen Sync ruft der Workflow die bestehende Web-CI mit dem
exakten neuen Test-Commit auf. Das ist notwendig, weil ein Push mit dem
internen GITHUB_TOKEN keinen weiteren Push-Workflow startet. Analyse, Tests,
LOC-Prüfung und Web-Build bleiben Voraussetzungen für das Test-Deployment.
Ist main bereits in test enthalten, gibt es keinen neuen Commit oder CI-Lauf.
Der Sync ist unabhängig vom Erfolg der main-CI; beide Branches prüfen ihren Stand.
