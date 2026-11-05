# Konto, Sync und Konflikte

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026) und um den aktuellen
Konto-Lebenszyklus ergänzt. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die
harten Regeln und den Themenindex.

- Registrierungen verlangen clientseitig mindestens zwölf Passwortzeichen;
  Firebase prüft zusätzlich seine serverseitige Kennwortrichtlinie. Nach dem
  Anlegen sendet `AuthService` eine E-Mail-Verifikation. Die Registrierung ist
  nur nach aktiver Kenntnisnahme der verlinkten Datenschutzerklärung möglich.
  Ein unbestätigtes Konto kann die App lokal nutzen, aber weder Firestore,
  Storage, Gruppen noch geschützte Backend-Funktionen verwenden. Unter
  `Einstellungen > Konto & Sync` lässt sich die Nachricht erneut senden und
  der Status nachladen.
- `Passwort vergessen?` sendet über Firebase eine Reset-Mail. Die UI antwortet
  für vorhandene und unbekannte Adressen gleich, damit kein Konto-Bestand
  offengelegt wird. Neue Registrierungen sind derzeit offen; die vorbereitete,
  aber nicht aktive Keyword-Variante ist in
  [`registration_security.md`](../registration_security.md) abgegrenzt.
- Vor dem erstmaligen Erzwingen der verifizierten Cloud-Regeln werden bekannte
  Bestandskonten einmalig administrativ bestätigt. Das Werkzeug
  `npm run accounts:verify-existing` im Ordner `functions/` ist standardmäßig
  ein schreibfreier Trockenlauf; nur der ausdrücklich ergänzte Parameter
  `-- --apply` ändert Konten. Es protokolliert ausschließlich Summen und keine
  E-Mail-Adressen. Erst nach erfolgreicher Migration dürfen Firestore- und
  Storage-Regeln veröffentlicht werden.

- `Einstellungen > Konto & Sync` steuert optionalen Firebase-Login,
  manuellen Konto-Sync und Konfliktaufloesung. Ohne Login nutzt die App das
  lokale Offline-Profil; mit Login nutzt sie ein getrenntes Profil unter
  `Helden/accounts/<uid>`.
- Abmelden entfernt die Online-Helden von diesem Gerät. Vorher gleicht
  `bestaetigeUndMeldeAb` (`lib/ui/screens/auth/abmelden_dialog.dart`, Ablauf
  `pruefeVorAbmeldung`) ein letztes Mal ab; offene Konflikte, nicht
  abgeschlossene Entscheidungen oder ein Sync-Fehler lösen eine Warnung mit
  „Trotzdem abmelden“ aus. Die lokale Bereinigung läuft im `AppStartupGate`
  beim Wechsel der Konto-UID (`KontoProfilBereinigung`, nach dem Schließen aller
  Boxen) und deckt damit jeden Abmeldeweg ab. Sie löscht nie über
  `SyncingHeroRepository` (das schriebe Tombstones in die Cloud). Desktop/Mobil:
  Die Boxen des Kontoprofils (`KontoProfilBereinigung.kontoBoxen`) werden
  entfernt, Avatar-Dateien der Konto-Helden ebenfalls, außer ihre ID existiert
  auch im Offline-Profil (`keepLocal` kopiert mit gleicher ID). Web: Offline- und
  Konto-Profil teilen sich die Boxen, deshalb gehen nur Helden mit Sync-Stand
  (`HiveSyncMetadataStore.heldenIds`) samt Zustand und Avatar-Zwischenspeicher.
  `externe_helden_v1` bleibt bewusst unberührt: Die Box gehört nicht zum
  Heldensync; ihre Einträge stammen aus Gruppen (`groups_v2`, siehe unten) und
  kommen nach dem Anmelden mit dem Gruppen-Sync zurück. Nur manuelle Einträge
  alter, gesperrter Gruppen existieren ausschließlich lokal. Neue Konto-Boxen
  müssen in `kontoBoxen` eingetragen werden; der Test
  `test/data/konto_profil_bereinigung_test.dart` fängt Vergessenes ab.
- Konto-Sync für Helden läuft über `SyncingHeroRepository`, ein
  plattformspezifisches Remote-Gateway (`FirestoreHeroSyncGateway`, auf Windows
  `RestFirestoreHeroSyncGateway`), `HiveSyncMetadataStore` und die Modelle in
  `lib/domain/sync_models.dart`. Konflikte dürfen nicht still überschrieben
  werden; die UI muss lokal, online oder beide behalten anbieten.
- **Konflikte entstehen nur noch für echte Widersprüche** (ARCH-06): Nach
  jedem Abgleich legt `_saveMetadata` den Inhalt des Stands mit seiner
  Revision in `SyncBasisStore` ab (Box `sync_basis_v1`, je Konto; ohne
  Inhalt, etwa bei Löschungen, entfällt sie). Ändern beide Geräte, führt
  `fuehreSyncZusammen` (`lib/domain/sync_zusammenfuehrung.dart`) Basis,
  Lokal und Online zusammen: Maps je Schlüssel, Listen über `id`/`instanzId`,
  AP und Ressourcen als Zähler, Würfelprotokoll als Vereinigung. Ohne
  Widerspruch geschieht das still
  (`syncing_hero_repository_zusammenfuehrung.dart`), sonst bleibt der
  Konflikt: `konfliktVorschau` nennt nur die widersprüchlichen Werte,
  `resolveConflictAutomatisch` führt mit Entscheidungen je Wert zusammen
  (Schlüssel `held:`/`zustand:`), der gebundene Zustand läuft mit. Die UI
  (`SyncKonfliktKarte`, `lib/ui/widgets/sync_konflikt_karte.dart`, im Gate und
  in den Einstellungen) bietet „Nur Online“, „Nur Lokal“, „Beide behalten“ und
  „Automatisch“, in der Reihenfolge der Spalten. Ohne gültige Basis
  (Revision passt nicht, ältere Abgleiche) gibt es kein „Automatisch“; ein
  Abgleich ohne lokale Änderung trägt die Basis nach. Neue Listenmodelle
  brauchen eine stabile `id`, sonst gelten sie als unteilbar.
- Die Sync-Basis ist der **lokale** Stand: Nach dem Übernehmen eines
  Online-Stands merken `_storeHeroMetadata`/`_storeStateMetadata` den Hash
  dessen, was lokal liegt. Den Schreiber-Hash (`remoteHash`) **nie** als
  `localHash` merken: Kann diese Version den Stand nicht verlustfrei
  darstellen, gälte die verkürzte Fassung sonst als lokale Änderung und würde
  ohne Konflikt hochgeladen (Befund ARCH-07-B10). Ein lokaler Stand, der der
  hiesigen Darstellung des Online-Stands gleicht, gilt als identisch. Ein
  Abgleich allein schreibt nie. Getestet wird das mit
  `speichereFremdenStand` in `test/data/sync_app_versionen_test.dart`.
- Entscheidungen zu Offline-Helden (`Offline-Held: …`-Konflikte beim Wechsel in
  ein Konto) müssen persistiert werden, sonst wiederholt sich die Frage bei
  jedem Start: die Konfliktliste lebt nur im Speicher und keiner der drei
  Auflösungswege verändert das Offline-Profil. `SyncingHeroRepository` schreibt
  dafür ein `OfflineHeroReview` in die Box `offline_hero_review_v1` im
  Konto-Profil (`lib/data/hive_offline_hero_review_store.dart`). Der Offline-Held
  selbst wird nie gelöscht. Widerrufbar unter
  `Einstellungen > Konto & Sync > Offline-Helden`.
- Die Vergleichstabelle kennzeichnet Offline-Helden über
  `SyncConflict.isOfflineHeroConflict`: „Nur Lokal“ ersetzt den Konto-Stand
  durch den Offline-Stand oder übernimmt einen fehlenden Konto-Held. Die
  Namenszeile trägt nur den Konto-Namen bzw. `—`; ein fehlender Konto-Held ist
  keine Cloud-Löschung. „Gespeichert“ erscheint nur mit beiden Zeitstempeln.
- Inhaltlich identische Datensätze sind aber kein Konflikt: `isSyncContentIdentical`
  (`lib/domain/sync_object_diff.dart`) entscheidet das mit derselben Logik wie
  die Konflikt-UI (umsortierte Listen, `lastModified`/`schemaVersion` zählen als
  gleich); in dem Fall übernimmt die App die Online-Version und überspringt den
  Datensatz. Nur echte Unterschiede erzeugen einen Konflikt und werden als
  Tabelle `Feld | Online | Lokal` gezeigt
  (`lib/ui/widgets/sync_conflict_comparison_table.dart` mit den deutschen
  Feldnamen aus `lib/ui/widgets/sync_conflict_field_labels.dart`), sowohl im
  Start-Gate als auch unter `Einstellungen > Konto & Sync`.
- Ein `HeroState` gehört zu genau einem Helden und wird nie gegenläufig zu ihm
  entschieden: Solange zu einem Helden ein Konflikt offen ist, bekommt sein
  Zustands-Konflikt keinen eigenen Listeneintrag, sondern hängt in
  `_boundStateConflicts` am Helden-Konflikt und folgt dessen Entscheidung
  (`keepLocal` schiebt die lokalen Laufzeitwerte hoch, `keepRemote` übernimmt
  die Online-Werte, `keepBoth` gibt der lokalen Kopie die lokalen Werte). Der
  lokale Zustand muss dafür **vor** dem ersten Schreibzugriff eingelesen
  werden, sonst bekommt die Kopie die bereits übernommenen Online-Werte. Ein
  eigener `Zustand:`-Konflikt entsteht nur ohne offenen Helden-Konflikt;
  `SyncConflict.includesHeroState` steuert den Hinweis in der Konflikt-UI.
- Laufzeitzustände (`HeroState`) tragen wie `HeroSheet` ein `lastModified`,
  damit die Konflikt-UI beim `Zustand:`-Konflikt nicht auf beiden Seiten
  `Unbekannt` anzeigt. Gehasht wird ein Zustand ausschließlich über
  `heroStateContentHash` (`lib/domain/sync_models.dart`), das den Zeitstempel
  entfernt — genau wie `heroContentHash`. Wer irgendwo `stableContentHash`
  direkt auf `state.toJson()` anwendet, baut einen Scheinkonflikt bei jedem
  Speichern ein.
- Ohne Helden **und** ohne Login zeigen beide Startseiten eine hervorgehobene
  Konto-Karte (`Anmelden`, `Konto anlegen`) vor dem Anlegen: Bestand über
  `HeroHomeAccountPrompt` (`lib/ui/screens/home/`), UI2 in `KartoHeldenwahl`
  über die Adaptermethode `KartoBestandsAdapter.anmelden`. Sichtbar nur, wenn
  `authServiceProvider` einen Dienst liefert. Geöffnet wird immer
  `openSignInScreen` (`lib/ui/screens/auth/open_sign_in.dart`); der
  `SignInScreen` schließt sich nach Erfolg selbst.
- `FirebaseBootstrapResult.isAccountSyncAvailable` und eine bestätigte
  E-Mail-Adresse steuern gemeinsam den privaten Konto-Sync;
  `isFirestoreAvailable` steht für native Firestore-Funktionen wie
  Gruppen-Cloudaktionen und bleibt auf Windows deaktiviert.
- **Gruppen (`groups_v2`)** laufen über `GruppenSyncService`
  (`lib/data/gruppen_sync_service.dart`) und die Gruppenaktionen in
  `HeroActions` (`erstelleGruppe`, `trittGruppeBei`, `syncGruppen`, …). Aufbau:
  `groups_v2/{id}` (`name`, `ownerUid`, `joinCode`) mit `members/{uid}`,
  `hero_snapshots/{uid}` (eigene Heldenkarte), `shared_heroes/{eintrag}` und
  `shared_info/notizen` und `shared_info/regelprofil` (Regelprofil-Vorgabe,
  nur der Besitzer schreibt, siehe `regeln_herleitung.md`). Beitritt ohne Backend: Der teilbare Beitrittscode ist
  `<groupId>.<joinCode>` (`GruppenBeitrittscode`); die Regel `canJoinGroup`
  vergleicht den `joinCode` per `get()` mit dem Gruppendokument, das nur
  Mitglieder lesen. Der Besitzer erneuert den Code jederzeit (alte Codes
  verfallen). Gemeinsame Einträge (NSC-Begleiter) und Notizen dürfen **alle**
  Mitglieder schreiben; Heldenkarten nur das jeweilige Mitglied (eine Karte je
  Konto und Gruppe). Mitglieder gehen selbst, der Besitzer löscht nur die ganze
  Gruppe. Am Helden markiert `HeroGruppenMitgliedschaft.kontoGruppe` das neue
  Format (nur bei `true` im JSON, Hash-Schutz); Gruppen ohne die Markierung
  stammen aus dem gesperrten Pfad `gruppen/*`, werden nie synchronisiert und
  lassen sich nur lokal entfernen. `syncGruppen` zieht den neueren Stand je
  gemeinsamem Eintrag, schreibt neuere lokale Stände hoch und entfernt
  Verschwundenes aus der Gruppe des Helden; es ändert nur `externeHeldIds` und
  `gruppenName`. Ein gemeinsamer Eintrag landet erst nach dem Upload lokal.
  Abgeglichen wird beim „Synchronisieren“ auf der Gruppen-Seite und automatisch
  vor „Gefecht beginnen“ (`syncGruppenVorGefecht` in `GefechtEinstieg`, acht
  Sekunden Zeitlimit; ein Fehler zeigt nur eine Meldung, das Gefecht startet
  mit dem lokalen Stand).
  Regeln: `functions/test/firestore_rules.rules.ts` (`npm run test:rules`,
  Java 21). Offen: Mitglieder entfernen (Dienst `entferneMitglied` vorhanden,
  keine Oberfläche), Live-Listener statt manuellem „Synchronisieren“, Gruppen
  unter Windows (REST-Transport ohne Firestore-SDK).
