# Offene Schritte: Heldengruppen-Sharing

Stand nach dem initialen Commit auf `claude/hero-group-sharing-PV6f8`.

---

## 1. Firebase-Projekt einrichten (Blocker)

Die App kann ohne Firebase-Projekt nicht starten. Alles Weitere haengt davon ab.

### Was fehlt
- `lib/firebase_options.dart` enthaelt nur Platzhalter (`'PLACEHOLDER'`)
- Plattform-Konfigurationsdateien fehlen komplett:
  - Android: `android/app/google-services.json`
  - iOS: `ios/Runner/GoogleService-Info.plist`
  - macOS: `macos/Runner/GoogleService-Info.plist`
- Android-Build: `com.google.gms.google-services`-Plugin fehlt in `android/app/build.gradle.kts`
- iOS/macOS: Keine Firebase-Pods konfiguriert (Podfiles fehlen oder unvollstaendig)

### Was zu tun ist
```bash
# 1. Firebase-Projekt in der Firebase-Konsole erstellen
#    https://console.firebase.google.com
#    → Neues Projekt → Cloud Firestore aktivieren

# 2. FlutterFire CLI installieren (falls nicht vorhanden)
dart pub global activate flutterfire_cli

# 3. Konfiguration generieren (ersetzt firebase_options.dart
#    und erzeugt plattformspezifische Dateien)
flutterfire configure --project=<dein-firebase-projekt-id>

# 4. iOS/macOS: Pods installieren
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```

---

## 2. Firestore Security Rules

Aktuell existieren keine Sicherheitsregeln. Die Datenbank ist vollstaendig offen.

Hinweis zum aktuellen Payload-Verhalten:
- `avatarThumbnailBase64` wird beim Sync nur noch als kompaktes PNG-Thumbnail
  uebertragen.
- Wenn selbst das kleinste Thumbnail die sichere Groessenobergrenze
  ueberschreitet, wird das Feld weggelassen und die UI zeigt einen
  Platzhalter-Avatar.

### Was zu tun ist
In der Firebase-Konsole oder via `firestore.rules` im Projekt:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Jeder mit dem Gruppencode kann lesen und schreiben
    match /gruppen/{gruppenCode} {
      allow read, write: if true;  // Vorerst offen — spaeter einschraenken
      match /mitglieder/{heroId} {
        allow read, write: if true;
      }
    }
  }
}
```

> Fuer den Anfang reicht offener Zugriff. Spaeter kann man
> Validierung hinzufuegen (z.B. nur eigene heroId schreiben).

---

## 3. Auto-Sync nach Held-Speichern

`syncVisitenkarten()` existiert, wird aber nirgends aufgerufen. Wenn ein
Spieler seinen Helden aendert, bekommen andere Gruppenmitglieder die
Aenderung nicht mit.

### Was zu tun ist
In `lib/state/hero_actions.dart` nach relevanten `saveHero()`-Aufrufen
`syncVisitenkarten(heroId)` einbauen — mindestens an diesen Stellen:

- Nach `erstelleGruppe()` (bereits erledigt via `_pushEigeneVisitenkarte`)
- Nach `trittGruppeBei()` (bereits erledigt via `_pushEigeneVisitenkarte`)
- **Nach dem normalen `saveHero()`** wenn der Held Profildaten aendert
  (Uebersicht-Tab speichern, Kampf-Tab speichern, etc.)

Empfehlung: Am Ende der oeffentlichen `saveHero()`-Methode pruefen,
ob der Held Gruppen hat, und dann `syncVisitenkarten()` aufrufen.

---

## 4. Firestore-Listener starten/stoppen

`listenToGruppe()` im `GruppenSyncService` ist implementiert, wird aber
nie aufgerufen. Es gibt keine Echtzeit-Updates.

### Was zu tun ist
In `lib/ui/screens/hero_gruppe_tab.dart`:

- **`initState()`**: Fuer jede Gruppe des Helden einen Firestore-Listener
  starten via `gruppenSyncServiceProvider.listenToGruppe()`
- **`dispose()`**: Alle Listener stoppen via `stopAlleListener()`
- **Gruppenwechsel**: Beim Wechsel zwischen Gruppen (Chip-Auswahl) den
  Listener fuer die neue Gruppe starten, falls noch nicht aktiv

---

## 5. Externe Helden automatisch verlinken

Wenn ein externer Held ueber Firebase synchronisiert wird, landet er zwar
im `HiveExterneHeldenRepository`, wird aber nicht in die
`externeHeldIds` der Gruppenmitgliedschaft eingetragen.

### Auswirkung
`gruppenMitgliederProvider` liefert leere Listen — synchronisierte Helden
erscheinen nicht in der UI.

### Was zu tun ist
In `lib/data/gruppen_sync_service.dart` → `listenToGruppe()`:

Nach dem Speichern des `ExternerHeld` muss dessen ID in die
`HeroGruppenMitgliedschaft.externeHeldIds` des lokalen Helden
eingetragen werden. Dafuer braucht der Listener entweder:
- Einen Callback `onNewMemberSynced(String externerHeldId)`, oder
- Zugriff auf `HeroActions` zum Aktualisieren der Gruppenconfig

---

## 6. Gruppenimport erweitern

Der bestehende Smart-Import (`workspace_import_export_actions.dart`)
erkennt `.dsa-gruppe.json`-Dateien und speichert sie lokal — bindet
sie aber nicht an Firebase an.

### Was zu tun ist (optional, nice-to-have)
- Beim Import eines Gruppen-Snapshots die enthaltenen Helden als
  `ExternerHeld`-Eintraege anlegen
- Den importierenden Helden automatisch der Gruppe zuordnen
- Optional: `trittGruppeBei()` aufrufen, falls ein `gruppenCode`
  im Snapshot enthalten ist

---

## 7. Tests

Es gibt keine Tests fuer die neuen Komponenten.

### Mindest-Testabdeckung
| Testdatei | Inhalt |
|-----------|--------|
| `test/domain/externer_held_test.dart` | Serialisierungs-Roundtrip, `fromVisitenkarte`, `copyWith` |
| `test/domain/hero_gruppen_config_test.dart` | Serialisierungs-Roundtrip, leere Defaults |
| `test/data/hive_externe_helden_repository_test.dart` | CRUD, Stream-Verhalten |
| `test/state/gruppen_providers_test.dart` | `gruppenMitgliederProvider` mit Mock-Daten |

---

## Empfohlene Reihenfolge

| # | Aufgabe | Grund |
|---|---------|-------|
| 1 | Firebase-Projekt + `flutterfire configure` | Blocker: App startet sonst nicht |
| 2 | Firestore Security Rules | Backend absichern |
| 3 | Listener-Lifecycle im Gruppe-Tab | Echtzeit-Updates aktivieren |
| 4 | Externe Helden automatisch verlinken | Synchronisierte Helden sichtbar machen |
| 5 | Auto-Sync bei Held-Speichern | Aenderungen an andere Geraete pushen |
| 6 | Tests | Stabilitaet absichern |
| 7 | Gruppenimport erweitern | Komfort-Feature |
