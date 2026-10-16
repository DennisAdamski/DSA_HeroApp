# Avatare, Bilder und Web-Betrieb

Ausgelagert aus der früheren `CLAUDE.md` (Stand 16.10.2026), Wortlaut unverändert. Die kurze [CLAUDE.md](../../CLAUDE.md) enthält die harten Regeln und den Themenindex.

- Avatar-Bilddateien synchronisiert der Konto-Sync **nicht** mit: sein Payload
  ist `HeroSheet.toJson()` und trägt nur Dateinamen. Die Bytes wandern über
  Firebase Storage (`avatars/{uid}/{fileName}`). `SyncingAvatarStorage`
  (`lib/data/syncing_avatar_storage.dart`) legt sich dafür um die
  plattformspezifische `AvatarFileStorage`: schreiben local-first mit
  Best-Effort-Upload, lesen mit Cloud-Fallback samt lokalem Cachen. Ob der
  Decorator greift, entscheidet `AvatarFileStorage.isCloudBacked` — im Web ist
  die Plattformimplementierung selbst der Cloud-Speicher, dort wäre er ein
  doppelter Weg. Löschen betrifft immer beide Seiten und alle Quellen; die
  frühere Sonderbehandlung von `quelle == 'ki'` gibt es nicht mehr.
- Bestandsbilder holt `AvatarBackfillService`
  (`lib/data/avatar_backfill_service.dart`) nach, angestoßen in
  `AppStartupGate` **nach** `syncNow()` und ohne `await`. Die Reihenfolge ist
  korrektheitsrelevant: vor dem Sync wäre die lokale Galerie veraltet, und ein
  auf einem anderen Gerät gelöschtes Bild käme wieder hoch. Der Service darf
  **nie** `saveHero()` aufrufen — das änderte `lastModified` und löste bei
  jedem Start eine Konfliktwelle aus. Abgeglichene Dateien vermerkt die Box
  `avatar_sync_v1` (`lib/data/hive_avatar_sync_marker_store.dart`); sie liegt
  im Kontoprofil, weil der `avatare`-Ordner bewusst profilübergreifend geteilt
  bleibt (eine Umstellung auf `accounts/<uid>/avatare/` würde jeden
  Bestandsavatar unsichtbar machen).
- Dateinamen dürfen nie aus `heroId` und `entryId` rekonstruiert werden:
  Bestandshelden tragen den Legacy-Eintrag `{heroId}_legacy` mit dem Dateinamen
  `{heroId}.png`, der dabei verlorenginge. Maßgeblich ist immer
  `AvatarGalleryEntry.fileName`. Der Import
  (`lib/ablaeufe/held_importieren.dart`) übernimmt deshalb den Namen, den die
  Ablage zurückgibt, nie den aus dem Export.
- Ob ein Held ein Bild hat, beantwortet `HeroAppearance.hatBild`, welches
  angezeigt wird `HeroAppearance.aktivesBild`. `avatarFileName` bleibt als
  Bestandsfeld im Modell (Entfernen erzeugte auf jedem Gerät einen Helden-Diff
  und damit Konflikte), wird aber nicht mehr gelesen. Bilder rendert
  ausschließlich `AvatarGalleryImage`
  (`lib/ui/widgets/avatar_gallery_image.dart`) über `avatarBytesProvider`. Die
  Bytes sind `Uint8List` und müssen unverändert an `Image.memory` gereicht
  werden — ein `Uint8List.fromList(...)` im Widget verfehlt den globalen
  `ImageCache` bei jedem Rebuild, weil `MemoryImage` seine Bytes per Identität
  vergleicht.
- Beschnittene Avatarflächen (Heldenmarke, Album, Header, Gruppen-Thumbnail)
  richten sich am erkannten Gesicht aus: `AvatarGalleryImage(rahmung: ...)`,
  Geometrie in `lib/rules/derived/avatar_rahmung_rules.dart`. Erkannt wird mit
  BlazeFace **in reinem Dart** (`lib/data/avatar_gesicht/`, Modell-Asset aus
  `tool/avatar_gesicht/`), ohne native Bibliothek und ohne CDN. Neue Bilder
  bekommen den Befund **beim Anlegen** (`uploadHeroImage`, `saveHeroAvatar`)
  als `AvatarGalleryEntry.gesichtsbefund` — im selben `saveHero`, der ohnehin
  läuft, im JSON (`gesicht`) nur bei belegtem Wert. **Nie nachträglich** in
  einen Helden schreiben: das Feld geht in `heroContentHash` ein, ein
  Nachtragen für Bestandsbilder löste Sync-Konflikte aus. Bestandsbilder
  nutzen den lokalen Cache `avatar_gesicht_v1` (`AvatarGesichtService`);
  `avatarGesichtProvider` nimmt zuerst den Eintrag, dann den Cache. Der Golden-Test
  `test/data/avatar_gesicht/blazeface_golden_test.dart` pinnt den Rechenkern
  gegen Googles LiteRT; seine Fixtures werden nicht angepasst, wenn er bricht.
  Nach Modellwechsel steigt `kAvatarGesichtDetektorVersion`. In Widget-Tests
  `avatarGesichtServiceProvider` mit `festerAvatarGesichtService()`
  überschreiben: die echte Erkennung rechnet im Isolate und wird im
  Fake-Async nie fertig. Details in `docs/technical_overview.md` Abschnitt 1.
- Ein fehlgeschlagener Bildzugriff darf nie stumm als „kein Bild" erscheinen.
  `AvatarLoadException` (`lib/data/avatar_load_failure.dart`) trägt den Grund
  (nicht angemeldet, keine Berechtigung, zu groß, Netzwerk, unbekannt);
  `AvatarGalleryImage` zeigt Laden, Fehlen und Fehlschlag als drei getrennte
  Zustände. Nur echtes `object-not-found` liefert weiterhin `null`. Wichtig für
  Web: `firebase_storage_web` lädt die Bytes nicht über das JS-SDK, sondern per
  `getMetadata()` → `getDownloadURL()` → `http.readBytes`, und `guard()` reicht
  alles außer Firebase-Fehlern unverändert durch — ein reines
  `on FirebaseException` verpasst deshalb Netzwerk- und Typfehler.
- Die Web-App läuft bewusst auch ohne Login (`WebAuthGate` reicht `null` durch).
  Ohne Konto gibt es keinen Cloud-Pfad und damit keine Avatarbilder.
- Beim lokalen Web-Debuggen ist `--web-port=5000` **Pflicht**, nicht Komfort:
  Firebase Auth und Hive persistieren pro Origin, und die CORS-Regel des
  Storage-Buckets nennt genau diesen Port. Ein zufälliger Port bedeutet
  abgemeldete Sitzung, leeren Speicher **und** blockierte Bilder. Die Pflicht
  hängt am Port, nicht am Browser: `flutter run -d chrome --web-port=5000`
  und `flutter run -d edge --web-port=5000` sind gleichwertig. Auf Maschinen
  ohne Chrome meldet `flutter doctor` „Cannot find Chrome" und `flutter
  devices` listet nur Edge — dann entweder `-d edge` nehmen oder
  `CHROME_EXECUTABLE` auf eine Chrome-Installation setzen.
- Der Storage-Bucket braucht eine **CORS-Konfiguration**, sonst sind Avatare im
  Web unsichtbar. `firebase_storage_web.getData()` lädt die Bytes per
  `http.readBytes` von der Download-URL — ein normaler Browser-Fetch. Diese
  Antwort trägt ohne Bucket-Konfiguration kein `Access-Control-Allow-Origin`,
  der Browser verwirft sie, und es kommt nur `ClientException: Failed to fetch`
  an. Achtung bei der Diagnose: Eine `OPTIONS`-Anfrage auf dieselbe URL
  antwortet mit `Access-Control-Allow-Origin: *` (Upload-Server) und führt in
  die Irre — geprüft werden muss der **GET**. Die Konfiguration liegt als
  `cors.json` im Repo und wird **nicht** von `firebase deploy` übertragen,
  sondern mit
  `gsutil cors set cors.json gs://heldensync-ccf0b.firebasestorage.app`
  (z. B. in der Google Cloud Shell). `cors.json` hat zwei Einträge: zuerst die
  drei bekannten Origins (die bekommen ihre exakte Origin zurückgespiegelt),
  danach eine Sammelregel `"origin": ["*"]` für lesende Zugriffe. Die
  Sammelregel deckt auch die feste Test-Site und manuelle Preview-Channels ab.
  Automatische Branch-Previews entfallen; siehe `docs/web_deployment.md`.
  GCS erlaubt keine Wildcard innerhalb einer Origin. Schreibzugriffe laufen
  über das Firebase-SDK und bleiben ohne CORS-Freigabe.
- Im Web liegen geladene Avatarbytes zusätzlich in der Hive-Box
  `avatar_blobs_v1` (IndexedDB, `lib/data/hive_avatar_blob_cache.dart`), damit
  ein Reload sie nicht erneut herunterlädt. Der Cache ist inhaltsadressiert und
  kann nicht veralten, weil `AvatarGalleryEntry.fileName` eine UUID trägt;
  aufzuräumen sind nur verwaiste Einträge, das erledigt
  `AvatarCacheReconciler` beim Start nach `syncNow()`. Bewusst **kein**
  `SyncingAvatarStorage` im Web: dort gilt der lokale Write als Erfolg, aber
  IndexedDB ist kein haltbarer Speicher — im Browser zählt ein Bild erst als
  gespeichert, wenn der Upload durch ist.
