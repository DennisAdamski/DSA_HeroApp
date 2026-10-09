# ARCH-06: technische Abnahmeprüfung

Stand: 10.10.2026, geprüft auf Branch `test`, Ausgangscommit `18e89307`.

ARCH-06 bleibt offen. Die vorhandenen Prüfungen bestehen, zwei zusätzliche
Abbruchproben widerlegen jedoch die Abnahme für zusammengehörige
Konfliktentscheidungen. Diese Prüfung verändert kein produktives Verhalten.

## Ergebnisse nach Abnahmekriterium

| Kriterium | Nachweis | Ergebnis |
|---|---|---|
| Keine halbe Buchung bei Abbruch | Steigerungsrunde und Schaden schreiben jeweils ein Dokument; Import hat Journal und Wiederanlauf | Für diese Abläufe geprüft; Konfliktauflösung hat die unten genannten Lücken |
| Neustart erhält ausstehenden Abgleich | `sync_speichervertrag_test.dart`, `sync_zwei_geraete_test.dart` | Bestehende Dokumentänderungen werden wieder übertragen |
| Wiederholungen buchen AP oder Schaden nicht doppelt | `steigerungsrunde_uebernehmen_test.dart`, `schaden_erhalten_test.dart`, `sync_speichervertrag_test.dart` | Geprüfte Buchungen sind wiederholbar |
| Heldenblatt und Zustand bleiben bei Konflikten zusammengehörig | Bestehende Konflikt- und Zwei-Geräte-Tests; zusätzliche Abbruchproben | **Nicht erfüllt bei abgebrochener Konfliktauflösung** |
| Korrekturen bleiben erkennbar, Steigerungshistorie bleibt erhalten | `schaden_zuruecknehmen_test.dart`, Steigerungsablauftests | Für vorhandene Korrekturaktionen geprüft |

## Reproduzierte Abbruchlücken

Beide Proben verwenden die Bestandsfixture `kriegerNormal` (`bestand-f01`),
zwei `SyncTestGeraet` und die gemeinsame `GeteilteCloud`. Sie laufen als
temporäre Diagnose unter `.dart_tool/arch06_probe/`, außerhalb der regulären
Testsuite. Die Proben erwarten das fachlich richtige Ergebnis und scheitern
am aktuellen Verhalten. Ihre Fehler sind keine erfolgreiche Abnahme.

Gemeinsamer Aufbau:

1. A und B gleichen denselben Helden mit 28 LeP ab.
2. Beide ändern offline denselben Bogenwert verschieden: A setzt Dukaten
   auf `20`, B auf `30`. A zieht 5 LeP ab, B zieht 7 LeP ab.
3. Nach Ende aller Hintergrunduploads gehen beide wieder online. A gleicht
   zuerst ab, danach B. Bei B entsteht ein Heldenkonflikt mit gebundenem
   Zustand: online 23 LeP, lokal 21 LeP.

### „Nur Lokal“ verliert die getroffene Zustandsentscheidung

- Bei B `remote.schreibvorgaengeBisAbbruch = 1` setzen.
- `resolveConflict(..., SyncResolutionChoice.keepLocal)` aufrufen: Der
  Heldenupload gelingt, der folgende Zustandsupload scheitert.
- Die Störung entfernen, B mit `neustart()` neu verbinden und `syncNow()`
  ausführen.
- **Erwartung:** Entweder wird die lokale Entscheidung vollständig
  fortgesetzt (Dukaten `30`, 21 LeP), oder die unvollständige Entscheidung
  bleibt sichtbar. **Beobachtet:** Dukaten `30`, 16 LeP, ohne offenen Konflikt.
  Die Online-Änderung wird zusätzlich zur lokalen Änderung eingerechnet.

Ursache: `_resolveHeroConflict` merkt nach dem Heldenupload bereits die neue
Heldenbasis. Die Entscheidung zum gebundenen Zustand bleibt nur im Speicher.
Nach dem Neustart ist der Heldenkonflikt verschwunden; der Zustand wird als
unabhängiger Dreiwege-Abgleich behandelt. Eine geänderte Schreibreihenfolge
allein würde das Abbruchfenster auf das jeweils andere Dokument verschieben.

### „Beide behalten“ verliert den Zustand der lokalen Kopie

- Bei B `remote.schreibvorgaengeBisAbbruch = 0` setzen.
- `resolveConflict(..., SyncResolutionChoice.keepBoth)` aufrufen.
- Originalheld und Originalzustand werden lokal durch die Online-Fassung
  ersetzt. Die lokale Kopie des Bogens wird gespeichert; ihr Upload scheitert.
- Die Störung entfernen, B neu starten und abgleichen.
- **Erwartung:** Die lokale Kopie behält ihren Zustand mit 21 LeP.
  **Beobachtet:** Ihr Zustand fehlt (`null`); das Original hat 23 LeP.

Ursache: `_resolveHeroConflict` hält den lokalen Zustand nur in einer
Variablen. Erst nach dem Upload der Kopie würde er an deren ID gespeichert.
Das Original ist zuvor schon überschrieben. Ein Neustart kann diese Werte
nicht aus dem Bogen oder den Sync-Metadaten zurückgewinnen.

## Ausgeführte Prüfungen

- `flutter analyze --no-pub`: kein Befund.
- Folgender serieller Lauf: **101 Tests bestanden**.

```powershell
flutter test --no-pub --concurrency=1 `
  test/data/sync_speichervertrag_test.dart `
  test/data/sync_zusammenfuehrung_repository_test.dart `
  test/data/sync_zwei_geraete_test.dart `
  test/data/sync_zwei_geraete_inventar_test.dart `
  test/data/sync_app_versionen_test.dart `
  test/ablaeufe/vorgaenge_wiederaufnehmen_test.dart `
  test/ablaeufe/steigerungsrunde_uebernehmen_test.dart `
  test/ablaeufe/schaden_erhalten_test.dart `
  test/ablaeufe/schaden_zuruecknehmen_test.dart `
  test/ui/screens/sync_conflict_gate_test.dart
```

Die zwei zusätzlichen Diagnoseproben scheitern mit `21 != 16` bzw.
`21 != null`. Keine vollständige Testsuite, Gerätebedienprüfung oder
Live-Firebase-Prüfung wurde durchgeführt.

## Nächster notwendiger Teilumfang

Konfliktentscheidungen mit mehreren Dokumenten brauchen einen dauerhaften
Wiederanlaufvertrag. Die gewählte Fassung und gegebenenfalls die ID samt
Zustand einer Kopie müssen vor dem ersten überschreibenden Zugriff erhalten
bleiben. Erst wenn beide Dokumente vollständig sind, darf die Entscheidung
als abgeschlossen gelten. Eine verlorene Antwort oder Wiederholung darf keine
weitere Kopie erzeugen oder Ressourcenänderungen erneut zusammenführen.

Das vorhandene Vorgangsjournal ist ein möglicher Ansatz, ohne die vereinbarte
dokumentbasierte Synchronisierung durch eine Operationswarteschlange zu
ersetzen. Der konkrete Vertrag muss auch Online-Änderungen während des
Wiederanlaufs sowie „Automatisch“ und die nativen/REST-Pfade berücksichtigen.
Die Abbruchproben sind im Korrekturpaket als dauerhafte Regressionstests zu
übernehmen und um diese Fälle sowie echte Hive-Neustarts zu ergänzen.

Die sonstigen Grenzen des [Speichervertrags](schreibpfade_inventar.md#speichervertrag-arch-06)
bleiben bestehen. Insbesondere sind Avatar-Dateien, Löschabläufe und neuere
Begleiteraktionen damit nicht zusätzlich abgesichert.

**Folgestand 10.10.2026:** Der Nutzer hat die Ausarbeitung des Vertrags
freigegeben. Der [schriftliche Entwurf](superpowers/specs/2026-10-10-arch06-konflikt-wiederanlauf-design.md)
liegt zur Prüfung vor. Die hier dokumentierten Fehler sind weiterhin offen.
