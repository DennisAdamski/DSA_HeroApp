# Konto, Sync und Konflikte

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- `Einstellungen > Konto & Sync` steuert optionalen Firebase-Login,
  manuellen Konto-Sync und Konfliktaufloesung. Ohne Login nutzt die App das
  lokale Offline-Profil; mit Login nutzt sie ein getrenntes Profil unter
  `Helden/accounts/<uid>`.
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
- `FirebaseBootstrapResult.isAccountSyncAvailable` steuert den privaten
  Konto-Sync; `isFirestoreAvailable` steht für native Firestore-Funktionen wie
  Gruppen-Cloudaktionen und bleibt auf Windows deaktiviert.
