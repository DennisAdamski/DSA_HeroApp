# Sicherheitsstatus: Heldengruppen-Sharing

Stand: 17. Oktober 2026.

## Legacy-Pfad ist gesperrt

Die frühere Struktur `gruppen/{gruppenCode}` besaß weder eine belastbare
Besitzeridentität noch echte Mitgliedschaften. Ein Gruppencode war keine
Zugriffsgrenze: Firestore-`read` umfasst sowohl Einzelzugriffe als auch
Abfragen. Außerdem konnten anonyme Clients Mitgliedsdokumente ändern oder
löschen.

`firestore.rules` verweigert deshalb jeden Clientzugriff auf das
Legacy-Dokument und sämtliche Unterpfade. Die vorhandenen Dokumente werden
nicht gelöscht. Eine Übernahme darf nur nach administrativer Prüfung erfolgen,
weil aus den Altdaten keine vertrauenswürdige Besitzer-UID ableitbar ist.

## Zielstruktur `groups_v2`

Die neuen Regeln reservieren folgende, UID-gebundene Struktur:

```text
groups_v2/{groupId}
  ownerUid: <Firebase UID>
  name: <Gruppenname>
  members/{uid}
  hero_snapshots/{uid}
  invitations/{invitationId}  # nur Backendzugriff
```

- Nur eingetragene Mitglieder dürfen Gruppe, Mitgliedschaften und
  Heldensnapshots lesen.
- Nur der Besitzer darf die Gruppe und Mitgliedschaften verwalten.
- Mitglieder dürfen ausschließlich ihren eigenen Heldensnapshot schreiben
  oder löschen.
- Einladungen sind für Clients vollständig gesperrt. Ein späterer Backendweg
  speichert nur Hash, Ablaufzeit und Verwendungsstatus.

Die Rules-Emulatortests liegen in
`functions/test/firestore_rules.rules.ts` und prüfen Legacy-Sperre,
Mitgliedslesen, Besitzerverwaltung und den eigenen Snapshot-Schreibweg.

## Noch nicht freigegebene Anwendungsmigration

Die bestehende Flutter-Implementierung unter `lib/data/gruppen_sync_service.dart`
verwendet noch den gesperrten Legacy-Pfad. Bis zur vollständigen Umstellung auf
`groups_v2` dürfen alte Gruppen weder automatisch beansprucht noch clientseitig
migriert werden. Nutzer müssen anschließend neue Gruppen erstellen und ihre
Mitglieder erneut einladen.

Vor einer produktiven Aktivierung von `groups_v2` fehlen noch:

1. authentifizierte Backendoperationen für Erstellen, Einladen, Annehmen und
   Entfernen von Mitgliedern;
2. serverseitig gehashte, kurzlebige und einmal verwendbare Einladungen;
3. Umstellung des Flutter-Syncdienstes auf UID-basierte Snapshots;
4. klare UI für gesperrte Legacy-Gruppen und den Neuaufbau einer Gruppe;
5. Emulator- und Flutter-End-to-End-Tests für den vollständigen Ablauf.

## Betrieb

Rules werden getrennt von Hosting und Functions veröffentlicht:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
firebase deploy --only firestore:rules --project heldensync-ccf0b
```

Vorher ist immer `npm run test:rules` im Verzeichnis `functions/` auszuführen.
Die Firebase CLI benötigt dafür Java 21 oder neuer.
