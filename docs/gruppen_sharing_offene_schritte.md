# Sicherheitsstatus: Heldengruppen-Sharing

Stand: 21. Oktober 2026.

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
Alte Gruppen werden in der App weder synchronisiert noch migriert; sie
erscheinen mit Sperrhinweis und lassen sich nur lokal vom Helden entfernen.

## Struktur `groups_v2`

```text
groups_v2/{groupId}
  name, ownerUid, joinCode
  members/{uid}              role: owner | member
  hero_snapshots/{uid}       Heldenkarte des Mitglieds
  shared_heroes/{entryId}    gemeinsame Einträge (z. B. NSC-Begleiter)
  shared_info/notizen        gemeinsame Gruppennotizen
  invitations/{id}           für ein späteres Backend reserviert, gesperrt
```

- Nur eingetragene Mitglieder lesen Gruppe, Mitgliedschaften, Heldenkarten und
  gemeinsame Inhalte.
- **Beitritt:** Wer den `joinCode` kennt, trägt sich per Regel als einfaches
  Mitglied (`role: member`) ein. Der Code steht im Gruppendokument, das nur
  Mitglieder lesen; der Besitzer erneuert ihn, ohne Mitglieder zu verlieren.
  Der Code ist weder einmalig noch befristet: Wer ihn weitergibt, lädt ein.
  Ein Backend mit gehashten, einmaligen Einladungen bleibt eine mögliche
  spätere Verschärfung (`invitations` ist dafür reserviert).
- **Schreibrechte:** Gruppe und Mitgliedereinträge verwaltet der Besitzer.
  Jedes Mitglied schreibt nur die eigene Heldenkarte. Gemeinsame Einträge und
  Notizen dürfen **alle Mitglieder** anlegen, ändern und löschen; der Ersteller
  (`createdByUid`) eines Eintrags bleibt unveränderlich.
- **Austritt:** Mitglieder löschen ihren eigenen Eintrag. Der Besitzer kann nur
  die ganze Gruppe löschen und fremde Heldenkarten entfernen.

Die Rules-Emulatortests liegen in `functions/test/firestore_rules.rules.ts`
und decken Legacy-Sperre, Lesen, Besitzerverwaltung, Beitritt mit richtigem und
falschem Code, Austritt, gemeinsame Einträge und Notizen ab.

## Anwendung

`lib/data/gruppen_sync_service.dart` und die Gruppenaktionen in
`lib/state/hero_actions.dart` verwenden ausschließlich `groups_v2`. Die
Oberfläche (`lib/ui/screens/hero_gruppe*`) bietet Erstellen, Beitreten per
Beitrittscode, Code kopieren/erneuern, Verlassen bzw. Löschen,
gemeinsame Einträge und gemeinsame Notizen.

Noch offen:

1. Mitglieder entfernen in der Oberfläche (Dienst `entferneMitglied` ist da);
2. Live-Listener statt manuellem „Synchronisieren“;
3. Gruppen unter Windows (REST-Transport ohne Firestore-SDK; dort bleibt
   `isFirestoreAvailable` aus);
4. Flutter-End-to-End-Test gegen den Firestore-Emulator;
5. optional: serverseitig gehashte, einmalige Einladungen.

## Betrieb

Rules werden getrennt von Hosting und Functions veröffentlicht:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
firebase deploy --only firestore:rules --project heldensync-ccf0b
```

Vorher ist immer `npm run test:rules` im Verzeichnis `functions/` auszuführen.
Die Firebase CLI benötigt dafür Java 21 oder neuer. **Ohne das Veröffentlichen
der Regeln funktionieren neue Gruppen nicht**, weil die bisherigen Regeln den
Selbstbeitritt und die gemeinsamen Inhalte verweigern.
