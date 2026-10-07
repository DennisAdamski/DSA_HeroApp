# Technische Gesamtdokumentation — DSA Heldenverwaltung

Dieses Dokument beschreibt die vollständige technische Struktur der App `dsa_heldenverwaltung`:
Architektur, Datenmodelle, Berechnungsregeln, Zustandsverwaltung und I/O-Pfade.

---

## Inhaltsverzeichnis

1. [Überblick & Architektur](#1-überblick--architektur)
2. [Datenmodelle (Domain Layer)](#2-datenmodelle-domain-layer)
3. [Katalog-Datenmodelle (Catalog Layer)](#3-katalog-datenmodelle-catalog-layer)
4. [Berechnungsregeln (Rules Layer)](#4-berechnungsregeln-rules-layer)
5. [Zustandsverwaltung (State Layer)](#5-zustandsverwaltung-state-layer)
6. [Persistenz (Data Layer)](#6-persistenz-data-layer)
7. [UI-Schicht (Überblick)](#7-ui-schicht-überblick)
8. [Entwicklungshinweise](#8-entwicklungshinweise)

---

## 1. Überblick & Architektur

### Zweck

**DSA Heldenverwaltung** ist eine plattformübergreifende Flutter-App zur Verwaltung von
Helden im Pen-&-Paper-Rollenspiel *Das Schwarze Auge* (DSA). Die App bietet:

- Lokale Persistenz mit der Hive-Datenbank
- DSA-Regelberechnungen (Eigenschaften, abgeleitete Werte, Talente, Kampf)
- Heldenimport/-export als JSON
- Katalogdaten (Talente, Waffen, Zauber, Manöver, Kampf-Sonderfertigkeiten) aus aufgesplitteten JSON-Assets

### Technologie-Stack

| Schicht | Technologie |
|---|---|
| Sprache | Dart ^3.13.0 |
| Framework | Flutter (Material 3), >=3.47.1 |
| Zustandsverwaltung | flutter_riverpod ^3.4.2 |
| Lokale Datenbank | hive_ce ^2.19.3, hive_ce_flutter ^2.3.4 |
| Volltextsuche | sqlite3 ^3.6.0 (native Libs ueber Build-Hook) |
| Datei-I/O | file_picker ^13.1.0, path_provider ^2.1.5 |
| Web-Interop | web ^1.1.1 (`package:web` + `dart:js_interop`) |
| Teilen | share_plus ^13.3.0 |
| Sichere Speicherung | flutter_secure_storage ^11.0.0 |
| Krypto | pointycastle ^4.0.0 (`lib/crypto/aes_primitives.dart`) |
| IDs | uuid ^4.5.1 |
| Linting | flutter_lints ^6.0.0 |
| Tests | flutter_test, integration_test |

### Schichtenarchitektur

```
UI (flutter_riverpod ConsumerWidgets)
        │  .watch() / .read()
        ▼
State Layer (Riverpod Providers — lib/state/)
        │  liest/schreibt, bindet Abläufe (lib/state/ablauf_providers.dart)
        ▼
Anwendungsabläufe (lib/ablaeufe/, ohne Riverpod; ARCH-05)
        │  laden frisch, rechnen über Regeln, stempeln, speichern
        ▼
Domain Models (lib/domain/)  ←→  Rules (lib/rules/derived/)
        │
        ├── Repository Interface (lib/data/hero_repository.dart)
        │       └── HiveHeroRepository (lib/data/hive_hero_repository.dart)
        └── Catalog (lib/catalog/)
                └── CatalogLoader → RulesCatalog
```

**Kernprinzip:** Domain-Modelle sind reine, unveränderliche Dart-Klassen ohne
Flutter-Abhängigkeiten. Regelberechnungen sind seiteneffektfreie Funktionen. Der
State Layer verbindet beides reaktiv über Riverpod. Fachlich benannte
Schreibabläufe liegen seit ARCH-05 in `lib/ablaeufe/`: Sie hängen nur von
Domain, Regeln, Katalog und der `HeroRepository`-Schnittstelle ab (Wächter:
`test/ablaeufe/abhaengigkeiten_test.dart`), bekommen ihre Abhängigkeiten per
Konstruktor und reichen Fehler an die Oberfläche durch. Die Bestandsaufnahme
aller Schreibwege steht in [schreibpfade_inventar.md](schreibpfade_inventar.md).

### App-Start (`lib/main.dart`)

Seit 2026-03-13 laeuft der Start in zwei Stufen: Zuerst wird ein lokaler
Einstellungsordner fuer `HiveSettingsRepository` vorbereitet. Danach loest
`AppStartupGate` den effektiven Heldenspeicherpfad auf, initialisiert
`HiveHeroRepository` mit diesem Ordner und fuehrt anschliessend den
Seed-Import aus. Auf Web wird statt eines nativen Ordners ein logischer
`Browser-Speicher`-Pfad verwendet, damit der Start ohne `path_provider`
funktioniert.

Seit 2026-06-01 ist der Konto-Login auf allen Plattformen optional. Ohne Login
nutzt die App weiterhin das lokale Offline-Profil. Bei Login wird ein getrenntes
lokales Konto-Profil unter `Helden/accounts/<uid>` geoeffnet und durch
`SyncingHeroRepository` mit Firestore synchronisiert. Offline-Helden werden beim
Wechsel in ein Konto nicht still importiert, sondern als Konflikte vor die
Heldenliste gelegt, damit der Nutzer lokal, online oder beide behalten waehlen
kann.

Avatar-Bilddateien wandern seit 2026-08-20 ueber Firebase Storage
(`avatars/{uid}/{fileName}`) mit; der Firestore-Payload traegt weiterhin nur
die Dateinamen. Zustaendig ist `SyncingAvatarStorage`
(`lib/data/syncing_avatar_storage.dart`), ein Decorator um die
plattformspezifische `AvatarFileStorage`: Schreiben ist local-first mit
Best-Effort-Upload, Lesen faellt bei fehlender lokaler Datei auf die Cloud
zurueck und legt die Bytes lokal ab. Im Web entfaellt der Decorator, weil die
Plattformimplementierung selbst der Cloud-Speicher ist (`isCloudBacked`).
Bestandsbilder holt `AvatarBackfillService`
(`lib/data/avatar_backfill_service.dart`) nach, angestossen in
`AppStartupGate` nach `syncNow()`. Die Reihenfolge ist zwingend: vor dem Sync
waere die lokale Galerie veraltet und auf einem anderen Geraet geloeschte
Bilder kaemen zurueck. Bereits abgeglichene Dateien vermerkt
`avatar_sync_v1` im Kontoprofil, sodass der Steady State keine
Netzwerkaufrufe braucht. Das Ergebnis des letzten Laufs steht unter
`Einstellungen > Konto & Sync`.

Fehlschlaege beim Bildzugriff werden nicht verschluckt: `AvatarLoadException`
(`lib/data/avatar_load_failure.dart`) benennt den Grund, und
`AvatarGalleryImage` unterscheidet Laden, Fehlen und Fehlschlag. Das ist im Web
noetig, weil dort sechs verschiedene Ursachen (kein Login, fehlendes Objekt,
Regelverstoss, Groessenlimit, Netzwerkfehler, Typfehler im Plugin) sonst
identisch als leerer Platzhalter aussehen. Ohne Login gibt es im Web keinen
Cloud-Pfad; beim lokalen Debuggen deshalb `--web-port` fixieren, da Firebase
Auth pro Origin persistiert.

Damit der Browser die Bytes ueberhaupt lesen darf, braucht der Storage-Bucket
eine CORS-Konfiguration (`cors.json` im Repo, angewendet per
`gsutil cors set cors.json gs://heldensync-ccf0b.firebasestorage.app`).
`firebase deploy` uebertraegt sie nicht. Fehlt sie, liefert der Download zwar
`200 OK`, aber ohne `Access-Control-Allow-Origin` — der Browser verwirft die
Antwort und meldet nur `ClientException: Failed to fetch`. Eine
`OPTIONS`-Gegenprobe taugt zur Diagnose nicht, weil sie vom Upload-Server
beantwortet wird und CORS-Header setzt.

Geladene Bytes legt die Web-Ablage zusaetzlich in der Hive-Box
`avatar_blobs_v1` (IndexedDB) ab. Der Cache ist inhaltsadressiert und veraltet
nicht, weil Dateinamen eine UUID tragen; `AvatarCacheReconciler` entfernt beim
Start lediglich Eintraege ohne Galerie-Bezug.

Beschnittene Avatarflaechen richten sich seit 2026-09-26 am erkannten Gesicht
aus: die runde Heldenmarke der neuen Oberflaeche, Albumkacheln, der
Workspace-Header und das Gruppen-Thumbnail. Vollansichten wie die Uebersicht
(`BoxFit.contain`) und der Vollbilddialog bleiben unveraendert.

- **Erkennung** (`lib/data/avatar_gesicht/`): Googles BlazeFace Short Range
  aus dem MediaPipe Face Detector (Apache 2.0), gerechnet in reinem Dart. Es
  gibt also keine native Bibliothek und kein CDN; Windows, macOS, Linux, iOS,
  Android und Web liefern dasselbe Ergebnis. `tool/avatar_gesicht/` wandelt
  das `.tflite` in `assets/models/blazeface_short_range.bin` um (JSON-Kopf mit
  Op-Folge plus float16-Gewichte). `BlazeFaceRechenkern` ist ein generischer
  Interpreter fuer genau die vorkommenden Ops (`blazeface_ops.dart`).
  `BlazeFaceErkennung` setzt Letterbox, 896 SSD-Anker, Sigmoid-Schwelle 0,5
  und gewichtetes NMS (IoU 0,3) nach MediaPipe um. Findet der erste Durchlauf
  nichts, sucht ein zweiter auf ueberlappenden Kacheln der halben kurzen
  Bildseite, bei Hochformat nur in den oberen 60 %. Das Short-Range-Modell
  ist fuer grosse Gesichter gebaut und uebersieht bei Ganzkoerperbildern sonst
  den Kopf. Dekodiert wird ueber `dart:ui` auf hoechstens 512 px; das Netz
  rechnet nativ per `compute` im Hintergrund-Isolate. Im Web laeuft es inline
  und gibt zwischen den Ops die Kontrolle ab.
- **Golden-Test**: `test/data/avatar_gesicht/blazeface_golden_test.dart` pinnt
  die Rohausgaben gegen Googles LiteRT-Laufzeit
  (`tool/avatar_gesicht/reference_outputs.py`), die Ende-zu-Ende-Tests laufen
  auf zwei gemeinfreien Gemaelden unter `test/fixtures/avatar_gesicht/`.
  Faellt der Golden-Test, rechnet der Kern falsch; die Fixtures werden dann
  nicht angepasst.
- **Befund am Eintrag, sonst lokaler Cache**: Neue Bilder bekommen den
  Befund beim Anlegen. `uploadHeroImage` und `saveHeroAvatar` starten
  `AvatarGesichtService.erkenneNeu` parallel zum Speichern der Bilddatei
  (Zeitlimit 5 s) und haengen das Ergebnis als
  `AvatarGalleryEntry.gesichtsbefund` samt Detektorversion an den neuen
  Eintrag. Das geschieht im selben `saveHero`, der ohnehin laeuft, also ohne
  zusaetzlichen Schreibvorgang oder Konflikt. Andere Geraete und das Web
  zeigen das Bild damit sofort richtig. Im JSON steht der Schluessel `gesicht`
  nur bei belegtem Wert, Bestandseintraege serialisieren bytegleich. Auch
  „kein Gesicht“ wird gespeichert (nur Bildgroesse). Export und Import tragen
  das Feld mit.
  **Nachgetragen wird nie:** Ein Feld an einem Bestandseintrag aenderte
  `heroContentHash` und loeste beim Konto-Sync Konflikte aus. Bestandsbilder
  und Eintraege mit veralteter Detektorversion nutzen deshalb
  `AvatarGesichtService` (`lib/data/avatar_gesicht_service.dart`) mit der
  Hive-Box `avatar_gesicht_v1` im Heldenspeicher, geschluesselt nach
  `AvatarGalleryEntry.fileName`. Jedes Geraet erkennt dort einmal selbst. Der
  Cache-Eintrag traegt `kAvatarGesichtDetektorVersion` und die Bytelaenge
  (Schutz fuer den Legacy-Namen `{heroId}.png`); weicht eines ab, wird neu
  erkannt. `avatarGesichtProvider` nimmt zuerst den Eintrag
  (`gespeicherterGesichtsbefund`, per `select` auf den Helden), dann den
  Cache. Der Service wirft nie: Fehler und Zeitueberschreitung (15 s)
  ergeben `null` und damit den Rueckfall-Ausschnitt. Eine laenger laufende
  Erkennung schreibt ihr Ergebnis trotzdem noch in den Cache. Erkennungen
  laufen nacheinander, damit ein frisch geoeffnetes Album nicht fuer jede
  Kachel gleichzeitig rechnet.
- **Rahmung** (`lib/rules/derived/avatar_rahmung_rules.dart`):
  `berechneAvatarAusschnitt` liefert einen Quellausschnitt mit exakt dem
  Seitenverhaeltnis der Zielflaeche. `portraet` fasst den Gesichtsrahmen auf
  36 % der Hoehe mit der Mitte bei 52 %, `kopfzeile` enger (42 % / 56 %);
  beide lassen Haar und Kopfbedeckung im Bild.
  Gezoomt wird hoechstens vierfach gegenueber dem Cover-Ausschnitt. Ohne
  Gesicht gilt der groesste Ausschnitt, bei Hochformat mit der Mitte bei
  38 % der Bildhoehe.
- **Darstellung**: `AvatarGalleryImage(rahmung: ...)` liest
  `avatarGesichtProvider` und zeichnet ueber `AvatarAusschnittBild` das ganze
  Bild vergroessert und verschoben — die Bytes gehen weiter unveraendert an
  `Image.memory`. Bis der Befund vorliegt, bleibt der Ladezustand stehen,
  damit das Bild nicht erst mittig und dann versetzt erscheint. Im Header
  gewinnt ein manuell gesetzter Ausschnitt (`headerFocusX/Y`, `headerZoom`);
  der Dialog dafuer startet ohne eigenen Fokus auf der Gesichtsmitte.
- **Gruppen-Thumbnail**: `AvatarThumbnailEncoder` schneidet ein Quadrat aus,
  um das Gesicht herum oder mittig, statt das ganze Bild aufs Quadrat zu
  stauchen. `HeroActions` holt den Befund dafuer direkt beim Service, nicht
  ueber `ref.read(provider.future)`.
- In Widget-Tests `avatarGesichtServiceProvider` mit
  `festerAvatarGesichtService()` (`lib/test_support/`) ueberschreiben: Die
  echte Erkennung rechnet in einem Isolate, das im Fake-Async nie fertig wird.

Seit 2026-08-08 gilt beim Startabgleich zusaetzlich: Sind lokale und
Online-Version inhaltlich identisch, wird kommentarlos die Online-Version
uebernommen und der Datensatz uebersprungen — es entsteht kein Konflikt. Das
Praedikat dafuer ist `isSyncContentIdentical` in
`lib/domain/sync_object_diff.dart`; es nutzt dieselbe Vergleichslogik wie die
Konflikt-UI und ist damit toleranter als `heroContentHash`: reine
Umsortierungen von Listen sowie `lastModified`/`schemaVersion` gelten als
gleich. `SyncingHeroRepository._adoptRemoteHero` bzw. `_adoptRemoteState`
schreiben dabei nur, wenn sich die lokal gespeicherten Daten wirklich
unterscheiden. Geloeschte Gegenseiten gelten nie als identisch und bleiben
Nutzerentscheidungen.

Echte Unterschiede werden als dreispaltige Vergleichstabelle
`Feld | Online | Lokal` dargestellt
(`lib/ui/widgets/sync_conflict_comparison_table.dart`, deutsche Feldnamen aus
`lib/ui/widgets/sync_conflict_field_labels.dart`). Die Zusammenfassung (Name,
Zeitstempel, AP gesamt, AP frei) bildet die stets sichtbaren ersten Zeilen, die
einzelnen Feldunterschiede lassen sich darunter ein- und ausklappen. Dasselbe
Widget nutzen der blockierende Startbildschirm `SyncConflictGate` und die
Konflikt-Kachel unter `Einstellungen > Konto & Sync`.

Seit 2026-08-17 werden Entscheidungen zu Offline-Helden dauerhaft festgehalten.
Vorher war das eine echte Luecke: `queueOfflineProfileConflicts` liest die
Offline-Box bei jedem Start neu, die Konfliktliste lebt nur im Speicher, und
keiner der drei Auflösungswege veraendert das Offline-Profil. `Online behalten`
war deshalb ein No-Op — dieselbe Frage kam bei jedem Start wieder.
`SyncingHeroRepository` schreibt nun in allen drei Zweigen ein
`OfflineHeroReview` (`lib/domain/sync_models.dart`) in die Box
`offline_hero_review_v1` im Konto-Profilpfad
(`lib/data/hive_offline_hero_review_store.dart`, Vertrag und In-Memory-Variante
in `lib/data/sync/offline_hero_review_store.dart`). Gefragt wird nur noch, wenn
kein Beschluss vorliegt oder sich der Offline-Held seither geaendert hat; der
Vergleich laeuft ueber `heroContentHash`, ist also unabhaengig von
`lastModified`. Der Offline-Held selbst wird dabei bewusst nie geloescht, damit
ein spaeterer Offline-Start seine Daten noch findet.

Das Gate ist dadurch auch keine Sackgasse mehr: `Später entscheiden` gibt die
App fuer die laufende Sitzung frei (die Konflikte bleiben unter
`Einstellungen > Konto & Sync` loesbar), `Abmelden` wechselt zurueck ins
Offline-Profil, und bei mehr als einem Konflikt loesen
`Alle: Online behalten` / `Alle: Lokal behalten` den Stapel in einem Zug auf.
Getroffene Beschluesse listet der Abschnitt `Offline-Helden` unter
`Einstellungen > Konto & Sync`; sie sind dort einzeln (`Erneut prüfen`) oder
komplett widerrufbar.

Seit 2026-08-20 ist auch der Zustands-Konflikt (`SyncObjectType.heroState`,
Laufzeitwerte wie LeP/AsP, temporaere Modifikatoren, aktive Zaubereffekte und
Wuerfelprotokoll) entscheidbar statt nur anzeigbar. Zwei Luecken standen dem
entgegen:

- Der Titel lautete `Zustand: <heroId>` und zeigte damit eine rohe UUID.
  `_openStateConflict` loest den Namen jetzt ueber `local.loadHeroById` auf;
  fehlt das Heldenblatt (verwaister Zustand), bleibt die ID als Notnagel.
- `HeroState` hatte kein `lastModified`, weshalb die Zusammenfassungszeile
  `Gespeichert` auf beiden Seiten `Unbekannt` zeigte — ausgerechnet die
  Information, die die Frage "welche Version ist neuer?" beantwortet. Das Feld
  existiert nun (`lib/domain/hero_state.dart`) und wird analog zu `HeroSheet`
  auf zwei Ebenen gestempelt: `SyncingHeroRepository.saveHeroState` setzt bei
  jedem Speichern einen frischen Wert, `HiveHeroRepository.saveHeroState`
  ergaenzt ihn offline, falls er fehlt. Die Online-Seite kam schon vorher als
  `RemoteHeroStateRecord.updatedAt` an und wurde nur nicht durchgereicht.
- Ohne Konto blieb der Stempel trotzdem stehen: Hive ergaenzt ihn nur, und
  jeder geladene Held oder Zustand brachte seinen alten mit (Befund
  ARCH-07-B4). Seit 2026-09-27 stempeln deshalb `HeroActions.saveHero`,
  `saveHeroState` und `updateHeroState` jede Nutzeraenderung frisch. Hive
  bleibt beim Ergaenzen, damit uebernommene Online-Staende ihren Zeitpunkt
  behalten.

Wichtig dabei: Der Zeitstempel darf nicht in die Konflikterkennung geraten,
sonst meldet jedes Neuspeichern einen Scheinkonflikt. Dafuer gibt es
`heroStateContentHash` (`lib/domain/sync_models.dart`), das `lastModified`
entfernt — exakt das Muster von `heroContentHash`. **Alle** Stellen, die einen
Zustand hashen, muessen diese Funktion verwenden, nicht `stableContentHash` auf
`state.toJson()`: die beiden Gateways, `hero_sync_record_codec.dart` und die
vier Stellen in `syncing_hero_repository.dart`. Bestandsdaten haben zunaechst
kein `lastModified` und zeigen bis zum naechsten Speichern weiterhin
`Unbekannt`; das ist gewollt, geraten wird nichts.

`syncNow` laedt einen lokal geaenderten Zustand auch dann hoch, wenn es ihn
online schon gibt: Weicht sein Hash vom zuletzt abgeglichenen ab, waehrend die
Online-Revision noch der Basis entspricht, wartet er auf den Upload
(`_hasPendingLocalStateChange`, Gegenstueck zur Heldenpruefung in
`_syncHeroes`). Vorher erreichten offline geaenderte LeP, AsP oder Wunden die
Cloud erst mit der naechsten Zustandsaenderung (Befund ARCH-07-B8). Ist zum
Helden eine Entscheidung offen, wartet der Zustand darauf.

**Die Sync-Basis ist der lokale Stand, nicht der des Schreibers**
(Befund ARCH-07-B10, seit 2026-09-27). Jeder Online-Datensatz bringt den
Inhalts-Hash seines Schreibers mit. Diese App liest ihn aber mit ihrem eigenen
`fromJson`. Stammt der Stand von einer neueren Version, deren Felder hier
nicht bewahrt werden (vor 2026-09-28 alles ausserhalb der Ausruestung und
unbekannte Enum-Werte, heute nur noch, was eine Normalisierung verwirft),
weicht die lokale Darstellung von diesem Hash ab. Frueher merkte
sich die Basis nach dem Uebernehmen den **Schreiber-Hash** als `localHash`.
Die verkuerzte lokale Fassung galt danach als lokale Aenderung und wurde im
selben `syncNow()` ohne Konflikt hochgeladen: Ein blosser Abgleich loeschte
die fremden Felder auf allen Geraeten.

Heute gilt:

- Nach dem Uebernehmen merken `_storeHeroMetadata`/`_storeStateMetadata` den
  Hash dessen, was lokal liegt. `remoteHash` bleibt der des Schreibers. Nie
  den `remoteHash` als `localHash` speichern.
- Als inhaltlich identisch gilt auch ein lokaler Stand, der genau der
  hiesigen Darstellung des Online-Stands gleicht. Das greift nach einem
  App-Update, dessen Laden Altdaten umstellt, und bei Basen aus der Zeit vor
  dem Fix: Die Basis wird nachgefuehrt, hochgeladen wird nichts.
- Ein Abgleich allein schreibt also nie. Hochgeladen wird erst bei einer
  echten Aenderung, und dann in der Fassung dieser Version. Fuer nicht
  bewahrte Felder bleibt das ein Verlust, aber nur noch durch eine
  Nutzeraenderung und bei gleichzeitig geaendertem Online-Stand als
  sichtbarer Konflikt.
- Die bereits veroeffentlichte App (Stand `main` vor diesem Fix) verhaelt
  sich weiter wie frueher. Nach jedem Upload einer neueren Version schreibt
  sie einmal ihre Fassung zurueck (Echo). Diese Version uebernimmt das Echo
  ohne erneuten Upload, ein Ping-Pong entsteht nicht.

Seit 2026-08-31 wird ein Zustands-Konflikt nicht mehr unabhaengig vom Helden
entschieden. Ein `HeroState` gehoert zu genau einem Heldenblatt; zwei getrennte
Fragen (`Held: Alrik` und `Zustand: Alrik`) liessen sich gegenlaeufig
beantworten und ergaben dann ein Heldenblatt der einen Seite mit den
Laufzeitwerten der anderen. `SyncingHeroRepository` haelt Zustands-Konflikte
zu einem Helden mit offener Entscheidung deshalb in `_boundStateConflicts`
(Schluessel: Helden-ID) statt in der Konfliktliste — welcher der beiden zuerst
erkannt wird, haengt nur an der Reihenfolge von `_syncHeroes` und
`_syncHeroStates`, weshalb die Bindung in beide Richtungen greift
(`_absorbStateConflict` beim Oeffnen des Helden-Konflikts, die Pruefung
`_hasOpenHeroConflict` in `_openStateConflict`).

Die Entscheidung zum Helden zieht den Zustand dann mit, auch ohne offenen
Zustands-Konflikt:

- `keepLocal` schiebt die lokalen Laufzeitwerte mit hoch
  (`_pushLocalStateWithHero`).
- `keepRemote` uebernimmt die Online-Laufzeitwerte (`_adoptRemoteStateWithHero`);
  ist die Online-Version ein Tombstone, faellt der Held lokal weg und der
  Zustand mit ihm (`local.deleteHero` raeumt beides, `_tombstoneStateBestEffort`
  setzt den Remote-Tombstone).
- `keepBoth` gibt der lokalen Kopie die lokalen Laufzeitwerte und dem Original
  die Online-Werte. Der lokale Zustand wird deshalb **vor** dem ersten
  Schreibzugriff eingelesen, sonst haette die Kopie bereits die uebernommenen
  Online-Werte.
- Der Loesch-Konflikt (`Lokal geloescht` vs. online geaendert) verhaelt sich
  analog: `keepLocal` setzt den Zustands-Tombstone, `keepRemote` holt mit dem
  Helden auch dessen Online-Zustand zurueck.

Fehlt online ein Zustandsdokument, bleibt der lokale Stand stehen — der
naechste Sync legt ihn an. Laeuft der Zustands-Push in eine
`SyncPreconditionException`, wird bewusst nur ein eigener Zustands-Konflikt
geoeffnet: der Helden-Konflikt ist an dieser Stelle bereits entschieden und
darf nicht erneut aufgehen. Ein eigener `Zustand:`-Eintrag entsteht damit nur
noch, wenn zum selben Helden kein Helden-Konflikt offen ist (der Normalfall:
zwei Geraete tracken Laufzeitwerte, das Heldenblatt bleibt gleich).
`SyncConflict.includesHeroState` sagt der UI, dass die Entscheidung den Zustand
mit umfasst; die Vergleichstabelle blendet dazu einen Hinweis ein.

Windows-Sonderfall: Firebase Auth bleibt dort verfügbar, der Konto-Sync nutzt
aber bewusst den Firestore-REST-Transport (`RestFirestoreHeroSyncGateway` und
`RestFirestoreSecretsRepository`) statt des nativen `cloud_firestore`-Pluginpfads.
Damit bleibt der persistente Login startfähig und der Sync verwendet weiterhin
Firebase-ID-Token plus Firestore Security Rules. Deshalb trennt
`FirebaseBootstrapResult` `isAccountSyncAvailable` von `isFirestoreAvailable`:
Der private Konto-Sync ist auf Windows aktiv, andere native Firestore-Funktionen
wie Gruppen-Cloudaktionen bleiben dort deaktiviert.

```
main()
  1. Flutter-Binding initialisieren
  2. HiveHeroRepository.create() (async — öffnet Hive-Boxen)
  3. StartupHeroImporter.importFromAssets() (Seed-Helden laden)
  4. ProviderScope mit Repository-Override starten
  5. DsaApp (Material 3, Seed-Color #2A5A73, Font Merriweather)
```

Aktueller Konto-Sync-Zusatz: Nach Firebase-Initialisierung beobachtet
`WebAuthGate` den optionalen Auth-Stream auf allen Plattformen. `AppStartupGate`
oeffnet ohne User das Offline-Profil und mit User das Konto-Profil, startet
`SyncingHeroRepository` plus plattformspezifisches Remote-Gateway
(`FirestoreHeroSyncGateway` oder auf Windows `RestFirestoreHeroSyncGateway`)
und übergibt den Controller über `syncControllerProvider`.

### App-weites Tablet-Layout

Seit 2026-04-12 nutzt die UI ein gemeinsames Layoutmodell für breite
Oberflächen:

- `lib/ui/config/app_layout.dart` klassifiziert Fenster in `compact`,
  `tabletPortrait`, `tabletLandscape` und `desktopWide`.
- `lib/ui/widgets/codex_split_view.dart` kapselt wiederverwendbare
  Split-Layouts für Master-Detail-Ansichten.
- `CodexPageScaffold` trennt den dekorativen Hintergrund durch eine transparente
  `Material`-Fläche vom Inhalt. So zeichnen `ListTile` und `ExpansionTile`
  ihre Hintergründe und Ink-Effekte über der Pergamentfläche, auch ohne Dekoration.
- `HeroesHomeScreen` nutzt auf iPad-Landscape ein persistentes
  Archiv-/Vorschau-Layout und stellt die zuletzt gespeicherte
  Heldenauswahl beim Start wieder her.
- `HeroWorkspaceScreen` trennt zwischen kompakter Mobilansicht,
  iPad-Portrait mit Icon-Rail, iPad-Landscape mit permanentem Inspector
  und einem breiten Desktop-Wide-Modus.
- Tablet- und Desktop-Workspaces nutzen einen kompakten zweizeiligen Header:
  oben Identitaet mit aktivem Bereich und optionalem PrimÃ¤rbild, darunter
  eine eingebettete Rail fuer Eigenschaften, Ressourcen, BE und Wunden.

---

## 2. Datenmodelle (Domain Layer)

Alle Domain-Modelle sind **unveränderlich** (immutable): `final`-Felder,
`const`-Konstruktoren, `copyWith()` für Updates, `toJson()`/`fromJson()` für
Serialisierung. Das `fromJson()` ist immer **lenient** (tolerant gegenüber fehlenden
Feldern; `?? Standardwert` für jedes Feld).

### 2.1 `HeroSheet` — Persistierte Heldendaten

**Datei:** `lib/domain/hero_sheet.dart` | **Schema-Version:** 28

`HeroSheet` enthält alle dauerhaft gespeicherten Heldendaten. Laufzeitwerte
(aktuelle LeP etc.) werden separat in `HeroState` gespeichert.

**Daten neuerer App-Versionen.** `fromJson` bewahrt, was diese Version nicht
kennt, und `toJson` schreibt es unverändert zurück — sonst löschte ein Gerät
mit älterer App per Sync die Felder einer neueren (Befunde ARCH-07-B5/B6):

- Schlüssel oberster Ebene, die nicht in `HeroSheet.jsonSchluessel` stehen,
  landen in `unbekannteFelder` (`lib/domain/unbekannte_json_felder.dart`);
  `HeroState` macht es genauso. Der Satz umfasst auch die flach eingebetteten
  Schlüssel von `HeroAppearance` und `HeroBackground` sowie alle nur bedingt
  geschriebenen. **Jedes neue Feld muss dort eingetragen werden**, sonst käme
  ein bewusst weggelassener Wert als „unbekannt“ zurück; ein Test in
  `test/domain/bestandshelden_kompatibilitaet_test.dart` prüft das.
- Verlaufseinträge mit unbekannter Steigerungsart bleiben als
  `UnbekannterVerlaufseintrag` an ihrer Position erhalten, statt den Helden
  unlesbar zu machen. Sie werden nicht ausgewertet; der Verlauf nennt ihre
  Anzahl.
- **Jedes verschachtelte Modell** bewahrt Unbekanntes auf seiner Ebene
  (Teilstände ARCH-03 vom 28.09.2026). Jedes trägt dafür einen eigenen Satz
  `unbekannteFelder` und ein eigenes `jsonSchluessel`:
  - Ausrüstung: `CombatConfig`, `MainWeaponSlot`, `RangedWeaponProfile`,
    `RangedProjectile`, `RangedDistanceBand`, `ArmorConfig`, `ArmorPiece`,
    `OffhandEquipmentEntry`, `HeroInventoryEntry`, `InventoryItemModifier`;
  - Kampfeinstellungen: `OffhandAssignment`, `CombatSpecialRules`,
    `CombatManualMods`, `WaffenmeisterConfig`, `WaffenmeisterBonus`;
  - Talente und Magie: `HeroTalentEntry`, `HeroTalentModifier` (auch in
    `statModifiers`/`attributeModifiers`), `HeroMetaTalent`,
    `TalentSpecialAbility`, `HeroSpellEntry`, `HeroSpellTextOverrides`,
    `HeroRitualCategory`, `HeroRitualKnowledge`, `HeroRitualEntry`,
    `HeroRitualFieldDef`, `HeroRitualFieldValue`, `MagicSpecialAbility`,
    `HeroLanguageEntry`, `HeroScriptEntry`;
  - Vor- und Nachteile: `HeroMerkmal` (`vorteilEintraege`/`nachteilEintraege`, ARCH-02);
  - Begleiter und Chronik: `HeroCompanion`, `HeroCompanionAttack`,
    `HeroCompanionSonderfertigkeit`, `HeroCompanionSpeed`,
    `HeroAdventureEntry`, `HeroAdventureSeReward`, `HeroAdventureDateValue`,
    `HeroAdventurePersonEntry`, `HeroAdventureLootEntry`, `HeroNoteEntry`,
    `HeroConnectionEntry`, `HeroReisebericht`, `ReiseberichtOpenItem`,
    `HeroGruppenMitgliedschaft`;
  - Werte, Bilder, Verlauf: `Attributes` (alle fünf Verwendungen),
    `StatModifiers`, `BoughtStats`, `HeroAttributeSePool`, `HeroStatSePool`,
    `HeroResourceActivationConfig`, `AventurianDate` (Geburtsdatum),
    `AvatarGalleryEntry`, `AvatarGesichtsbefund`, `AvatarGesichtsrahmen`,
    `AvatarSnapshot`, `HeroAdvancementEntry`;
  - Laufzeitzustand: `AttributeModifiers`, `ActiveSpellEffectsState`,
    `ActiveSpellEffectDetail`, `SpellDuration`, `WundZustand`, `DiceLogEntry`.

  Ausgenommen ist nur `OffhandSlot`: der Altschlüssel `offhand` wird beim
  Laden migriert und nie geschrieben. Drei Regeln halten das dicht:
  1. **Jeder gelesene Altschlüssel gehört in den Schlüsselsatz.** Das betrifft
     `offhand`, `wmFk`, `fkMod` (Geschoss und manuelle Modifikatoren),
     `schnellladenBogen`/`schnellladenArmbrust`, `eigenAp`, `vorNachteile`
     und den Alias `note` der magischen SF. Als „unbekannt“
     zurückgeschrieben, käme etwa ein gelöschter migrierter Schild beim
     nächsten Laden wieder.
  2. **Bestehende Objekte ändert man nur per `copyWith`.** Wer sie per
     Konstruktor neu aufbaut, verliert die Felder. Editoren arbeiten deshalb
     auf der Bestandsinstanz — auch zeilenweise Dialoge wie die
     Modifikatorlisten, die dafür das Original je Zeile mitführen. Neu
     errechnete oder aus Formularen gelesene Werte übernimmt
     `Attributes.uebernimmWerte` bzw. `AttributeModifiers.uebernimmWerte` in
     die vorhandene Instanz (effektive Startwerte in `saveHero`, epische
     Werte, Attributo). Ohne das erbten die Startwerte die Felder der
     Rohstartwerte.
  3. **Felder einer neueren Version zählen als Inhalt.** Text-Overrides,
     Zusatzdaten eines Zaubereffekts und das Geburtsdatum werden nur
     geschrieben, wenn sie belegt sind; Objekte, die ausschließlich
     unbekannte Felder tragen, gelten dabei als belegt. Ein Objekt ohne
     beides schreibt weiterhin nichts.

  Katalogwaffen setzen die Felder ihrer Geschosse und Stufen beim Laden leer
  (`weapon_def.dart`). Katalogschlüssel sind keine Heldendaten.
  `test/domain/unbekannte_verschachtelte_felder_test.dart` prüft neben den
  Modellen einzeln jede Objektebene eines voll belegten Helden und aller
  Bestandshelden (Vollständigkeitswächter); ein neues Modell ohne
  `unbekannteFelder` fällt dort auf.
- Nicht erhalten bleibt, was eine bestehende **Normalisierung verwirft**:
  Personen, SE-Zeilen und Beute ohne Inhalt, Talentmodifikatoren ohne
  Beschreibung, Ritualkategorien ohne oder mit doppelter ID, Zusatzfelder
  ohne Bezeichnung und ungültige Gesichtsbefunde fallen samt ihren
  unbekannten Feldern weg. `mainWeapon` spiegelt nur die gewählte Waffe.
- **Unbekannte Aufzählungswerte** bleiben ebenfalls erhalten. Kennt diese
  Version einen Wert nicht, rechnen Modell und Regeln mit dem Ersatzwert;
  den Rohwert hält das Modell in `unbekannteEnumWerte` (JSON-Schlüssel →
  Rohwert, getrennt von `unbekannteFelder`), und `toJson` schreibt ihn
  anstelle des Ersatzes zurück. Fehlende oder leere Angaben gelten wie
  bisher als fehlend. Betroffen sind 18 Felder: `HeroInventoryEntry`
  (`itemType`, `source`, `traegerTyp`), `InventoryItemModifier` (`kind`),
  `MainWeaponSlot` (`combatType`), `OffhandEquipmentEntry` (`type`,
  `shieldSize`), `WaffenmeisterBonus` (`type`), `HeroRitualCategory`
  (`knowledgeMode`), `HeroRitualFieldDef` (`type`), `HeroCompanion` (`typ`),
  `HeroAdventureEntry` (`status`), `HeroAdventureSeReward` (`targetType`),
  `HeroAdventureLootEntry` (`itemType`), `SpellDuration` (`unit`),
  `DiceLogEntry` (`type`, `automaticOutcome`) und `AventurianDate`
  (`month`). Muster beim Lesen: `leseEnumWert` mit einer Erkennerfunktion,
  die `null` für Unbekanntes liefert, dann `festeEnumWerte`; beim Schreiben
  `mitUnbekanntenEnumWerten` über `mitUnbekanntenFeldern`.
  **Änderungsregel:** `copyWith` mit einem *anderen* Wert überschreibt den
  Rohwert (`ohneGeaenderteEnumWerte`), derselbe Wert lässt ihn stehen —
  Dialoge, die alle Felder neu durchreichen, verlieren ihn also nicht.
  Unbekannte Wundzonen hält `WundZustand.unbekannteZonen` je Map
  (`wundenProZone`, `unterdrueckteWundenProZone`); sie zählen nicht mit
  und entfallen erst bei der vollen Rast. Zwei Stellen berücksichtigen
  den Rohwert ausdrücklich, weil der Ersatz Daten verlöre:
  `MainWeaponSlot.fuehrtGeschosse` behandelt eine unbekannte Kampfart wie
  Fernkampf, damit Verweise und Abgleich die Geschosse samt Inventardaten
  behalten (Befund ARCH-07-B13), und der Inventarabgleich lässt einen
  Eintrag mit Verweis, aber unbekannter Quelle unverändert stehen und
  legt für seinen Slot keinen zweiten an (B12). Sonst rechnet alles mit
  dem Ersatz; verknüpfte Einträge übernehmen `itemType` und `source` beim
  Abgleich aus ihrem Slot.

**Formatregel für künftige Versionen:** Änderungen am gespeicherten Format
bleiben additiv. Erhalten wird nur, was eine ältere Version nicht versteht;
ändert sich dagegen die Bedeutung eines vorhandenen Schlüssels, schriebe sie
ihn nach ihrem alten Verständnis fort. Eine neue Bedeutung bekommt deshalb
einen neuen Schlüssel. Nur ein Formatwechsel, der sich so nicht ausdrücken
lässt, bräuchte eine sichtbare Schreibsperre in älteren Versionen — die gibt
es bisher nicht.

Bestandsdaten enthalten nichts Unbekanntes, ihr JSON und ihre Inhalts-Hashes
ändern sich dadurch nicht.

#### Felder

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | `String` | Eindeutige UUID; bleibt über Exporte stabil |
| `schemaVersion` | `int` (= 28) | Format-Version fuer Migrationskompatibilitaet |
| `name` | `String` | Anzeigename des Helden |
| `level` | `int` | Stufe (wird aus `apSpent` berechnet) |
| `rawStartAttributes` | `Attributes` | Beim Anlegen erfasste Roh-Startwerte vor R/K/P-Modifikatoren |
| `attributes` | `Attributes` | Aktuelle Eigenschaftswerte (8 Werte) |
| `startAttributes` | `Attributes` | Abgeleitet: `computeHeroEffectiveStartAttributes`. Nie als Basis einer erneuten Modifikation verwenden (Abschnitt 4.10) |
| `persistentMods` | `StatModifiers` | Schnellmodifikatoren des Inspectors (±-Knöpfe für Ini, GS, AW, AT, PA, RS); zählen zusätzlich zu `statModifiers` |
| `bought` | `BoughtStats` | Gekaufte Ressourcenerhöhungen |
| `combatConfig` | `CombatConfig` | Gesamte Kampfkonfiguration |
| `combatConfig.waffenmeisterschaften` | `List<WaffenmeisterConfig>` | Waffenmeister-Baukasten mit Waffenart, Boni und Voraussetzungen |
| `talents` | `Map<String, HeroTalentEntry>` | Alle Talente (Schlüssel: Talent-ID) |
| `metaTalents` | `List<HeroMetaTalent>` | Heldenspezifische Meta-Talente mit Komponenten, Eigenschaften und BE-Regel |
| `hiddenTalentIds` | `List<String>` | IDs ausgeblendeter Talente |
| `talentSpecialAbilities` | `List<TalentSpecialAbility>` | Strukturierte Talent-Sonderfertigkeiten (Name + optionale Notiz), Legacy-Strings werden tolerant migriert |
| `spells` | `Map<String, HeroSpellEntry>` | Aktivierte oder gelernte Zauber des Helden |
| `ritualCategories` | `List<HeroRitualCategory>` | Heldenspezifische Ritualkategorien mit Ritualkenntnis oder Talentbezug |
| `repraesentationsTraditionen` | `Map<String, String>` | Gewählte Tradition je Repräsentationskürzel; nur bei mehrdeutigen Kürzeln nötig (aktuell nur `Geo`) |
| `magicLeadAttribute` | `String` | Bewusst abweichende Leiteigenschaft (`MU` bis `KK`); ohne Eintrag wird sie aus der Tradition abgeleitet |
| `rasse` / `rasseModText` | `String` | Rasse und Rassenmodifikator-Text |
| `kultur` / `kulturModText` | `String` | Kultur und Kulturmodifikator-Text |
| `profession` / `professionModText` | `String` | Profession und Professions-Mod-Text |
| `geschlecht`, `alter`, `groesse`, `gewicht` | `String` | Körperdaten; `alter` ist der Freitextwert aus der Erschaffung und altert nicht mit |
| `geburtsdatum` | `AventurianDate` | Aventurisches Geburtsdatum als Bezugspunkt für das berechnete aktuelle Alter; wird nur bei belegtem Wert serialisiert |
| `haarfarbe`, `augenfarbe`, `aussehen` | `String` | Äußere Erscheinung |
| `stand`, `titel` | `String` | Sozialer Stand und Titel |
| `familieHerkunftHintergrund` | `String` | Familiengeschichte/Herkunft |
| `sozialstatus` | `int` | Numerischer Sozialstatus |
| `vorteilEintraege` / `nachteilEintraege` | `List<HeroMerkmal>` | Erworbene Vor-/Nachteile mit Katalog-ID, Wert, Auswahl und Textfragment (ARCH-02, Abschnitt 4.11). Maßgeblich, sobald belegt; nur dann geschrieben |
| `vorteileText` / `nachteileText` | `String` | Projektion der Listen für ältere App-Versionen (`; `-getrennt); bei Bestandshelden ohne Liste der Alttext, der beim nächsten Speichern migriert wird |
| `apTotal` | `int` | Gesamte Abenteuerpunkte |
| `apSpent` | `int` | Ausgegebene Abenteuerpunkte |
| `apAvailable` | `int` | Verfügbare AP (= apTotal − apSpent) |
| `dukaten` | `String` | Geldmenge (Freitext) |
| `resourceActivationConfig` | `HeroResourceActivationConfig` | Nullable Auto-/Override-Schalter fuer Magie und goettliche Ressourcen |
| `showInapplicableSpecialAbilities` | `bool` | Unpassende Magie-/Karma-Sonderfertigkeiten anzeigen; Standard `false`, nur bei `true` serialisiert |
| `inventoryEntries` | `List<HeroInventoryEntry>` | Ausrüstung/Inventar |
| `notes` | `List<HeroNoteEntry>` | Freie Chroniken mit Titel und Beschreibung |
| `connections` | `List<HeroConnectionEntry>` | Kontakte/Verbindungen mit Ort, Sozialstatus, Loyalität, Beschreibung und optionaler Abenteuer-Referenz |
| `adventures` | `List<HeroAdventureEntry>` | Manuell sortierte Abenteuer-Etappen mit Status, weltlichen und aventurischen Datumsfeldern, Notizen, Personen sowie Abschluss-Belohnungen fuer AP, feste SE-Ziele, Dukaten, strukturierte Beute und Anwendungsstatus |
| `attributeSePool` | `HeroAttributeSePool` | Persistierte Abenteuer-SE für Eigenschaften (`MU` bis `KK`) |
| `statSePool` | `HeroStatSePool` | Persistierte Abenteuer-SE für Grundwerte (`LeP`, `Au`, `AsP`, `KaP`, `MR`) |
| `unknownModifierFragments` | `List<String>` | Unparsbare Modifier-Fragmente (UI-Hinweis) |

#### Kompositions-Baum

```
HeroSheet
  ├── Attributes rawStartAttributes
  ├── Attributes attributes
  ├── Attributes startAttributes
  ├── StatModifiers persistentMods
  ├── BoughtStats bought
  ├── CombatConfig combatConfig
  │     ├── MainWeaponSlot mainWeapon          (Legacy-Fallback)
  │     ├── List<MainWeaponSlot> weapons
  │     ├── int selectedWeaponIndex
  │     ├── OffhandSlot offhand
  │     │     └── OffhandMode mode (none/shield/parryWeapon/linkhand)
  │     ├── ArmorConfig armor
  │     │     └── List<ArmorPiece> pieces
  │     ├── CombatSpecialRules specialRules
  │     └── CombatManualMods manualMods
  ├── Map<String, HeroTalentEntry> talents
  ├── List<HeroMetaTalent> metaTalents
  ├── List<HeroInventoryEntry> inventoryEntries
  ├── List<HeroNoteEntry> notes
  └── List<HeroConnectionEntry> connections
```

---

### 2.2 `HeroState` — Laufzeitzustand

**Datei:** `lib/domain/hero_state.dart` | **Schema-Version:** 5

Enthält ausschließlich zur Laufzeit veränderliche Werte. Wird separat von `HeroSheet`
persistiert (eigene Hive-Box `hero_states_v1`).

| Feld | Typ | Bedeutung |
|---|---|---|
| `schemaVersion` | `int` (= 5) | Format-Version |
| `currentLep` | `int` | Aktuelle Lebenspunkte |
| `currentAsp` | `int` | Aktuelle Astralpunkte |
| `currentKap` | `int` | Aktuelle Karmapunkte |
| `currentAu` | `int` | Aktueller Ausdauerwert |
| `erschoepfung` | `int` | Aktuelle Erschöpfung für Rast- und Schlafregeln |
| `ueberanstrengung` | `int` | Aktuelle Überanstrengung; wird vor Erschöpfung abgebaut |
| `tempMods` | `StatModifiers` | Temporäre Stat-Modifikatoren |
| `tempAttributeMods` | `AttributeModifiers` | Temporäre Eigenschaftsmodifikatoren |

`HeroState.empty()` liefert einen Standardzustand mit allen Werten = 0.

---

### 2.3 `Attributes` & Ableitungen

**Datei:** `lib/domain/attributes.dart`

Die acht DSA-Grundeigenschaften:

| Kürzel | Feld | Eigenschaft |
|---|---|---|
| MU | `mu` | Mut |
| KL | `kl` | Klugheit |
| IN | `inn` | Intuition |
| CH | `ch` | Charisma |
| FF | `ff` | Fingerfertigkeit |
| GE | `ge` | Gewandtheit |
| KO | `ko` | Konstitution |
| KK | `kk` | Körperkraft |

**`AttributeModifiers`** (`lib/domain/attribute_modifiers.dart`): Spiegelt dieselben 8
Felder als Modifikatoren (alle `int`, Standard 0). Unterstützt Addition via `operator +`.

**`AttributeCode`** Enum (`lib/domain/attribute_codes.dart`): Typisierte Eigenschaftskürzel
mit `parseAttributeCode(String raw)` (toleriert Aliase und Umlaute) und
`readAttributeValue(Attributes, AttributeCode)`.

---

### 2.4 `StatModifiers` & `BoughtStats`

**`StatModifiers`** (`lib/domain/stat_modifiers.dart`): Aggregiert Modifikatoren mehrerer
Quellen. Unterstützt feldweises Addieren via `operator +`.

| Feld | Bedeutung |
|---|---|
| `lep` | LeP-Modifikator |
| `au` | Ausdauer-Modifikator |
| `asp` | AsP-Modifikator |
| `kap` | KaP-Modifikator |
| `mr` | Magieresistenz-Modifikator |
| `iniBase` | Initiativgrundwert-Modifikator |
| `at` | Angriff-Modifikator |
| `pa` | Parade-Modifikator |
| `fk` | Fernkampf-Modifikator |
| `gs` | Geschwindigkeits-Modifikator |
| `ausweichen` | Ausweichen-Modifikator |

In `HeroSheet` stehen `persistentMods` (Inspector-Schnellmodifikatoren) und
die benannten `statModifiers` (mit Beschreibung, gepflegt im Modifikator-Dialog
der Übersicht) nebeneinander und zählen beide; in `HeroState` liegen die
temporären `tempMods` (z. B. durch Zauber). Textmodifikatoren aus Herkunft und
Vor-/Nachteilen werden nicht gespeichert, sondern bei jeder Berechnung geparst.

`HeroSheet.fromJson` kopiert `persistentMods` **nicht** nach `statModifiers`.
Von März bis September 2026 tat es das, sobald `statModifiers` leer war, und
jeder Inspector-Wert zählte danach doppelt (Befund ARCH-07-B1). Beim Laden
entfällt deshalb ein benannter Eintrag „Manuell“, der genau dem Inspector-Wert
desselben Feldes entspricht; abweichende Einträge bleiben stehen.

**`BoughtStats`** (`lib/domain/bought_stats.dart`): Durch AP erkaufte Ressourcenerhöhungen.

| Feld | Bedeutung |
|---|---|
| `lep` | Gekaufte LeP-Erhöhung |
| `au` | Gekaufte Ausdauer-Erhöhung |
| `asp` | Gekaufte AsP-Erhöhung |
| `kap` | Gekaufte KaP-Erhöhung |
| `mr` | Gekaufte MR-Erhöhung |

---

### 2.5 Combat-Konfiguration

`CombatConfig` verwaltet neben `mainWeapon`/`weapons` jetzt auch
`offhandAssignment` (Referenz auf die aktuelle Nebenhand-Belegung) und
`offhandEquipment` (inventarisierte Schilde und Parierwaffen).

**`CombatConfig`** (`lib/domain/combat_config.dart`) ist der Hub für alle Kampfdaten.

#### `MainWeaponSlot` (`lib/domain/combat_config/main_weapon_slot.dart`)

| Feld | Typ | Bedeutung |
|---|---|---|
| `name` | `String` | Anzeigename |
| `inventarInstanzId` | `String` | Verweis Slot → Inventarinstanz (ARCH-03); abgeleitet, gesetzt nur in `saveHero`, nur geschrieben, wenn belegt. Gilt ebenso für `RangedProjectile`, `ArmorPiece` und `OffhandEquipmentEntry` |
| `talentId` | `String` | Zugehöriges Kampftalent (ID aus Katalog) |
| `combatType` | `WeaponCombatType` | Explizite Einordnung als Nah- oder Fernkampfwaffe |
| `weaponType` | `String` | Waffenkategorie |
| `distanceClass` | `String` | Distanzklasse der Nahkampfwaffe (Legacy-kompatibel) |
| `kkBase` | `int` | KK-Basis für TP-Bonus-Berechnung; `0` zusammen mit `kkThreshold = 0` deaktiviert TP/KK und INI/GE |
| `kkThreshold` | `int` | KK-Schwelle für TP-Schritte; `0` ist nur zusammen mit `kkBase = 0` als Deaktivierung erlaubt |
| `breakFactor` | `int` | Bruchfaktor der Waffe |
| `tpDiceCount` | `int` | Anzahl TP-Würfel |
| `tpDiceSides` | `int` (= 6) | Seiten des TP-Würfels (immer 6) |
| `tpFlat` | `int` | Flacher TP-Bonus |
| `wmAt` | `int` | Waffenmodifikator Angriff |
| `wmPa` | `int` | Waffenmodifikator Parade |
| `iniMod` | `int` | Initiative-Modifikator |
| `beTalentMod` | `int` | BE-Modifikator für diese Waffe |
| `isOneHanded` | `bool` | Einhändig vs. zweihändig |
| `isArtifact` | `bool` | Markiert die Waffe als Artefakt |
| `artifactDescription` | `String` | Freitext-Beschreibung des Artefakts |
| `isGeweiht` | `bool` | Markiert die Waffe als geweiht |
| `geweihtDescription` | `String` | Freitext-Beschreibung der Weihe |
| `rangedProfile` | `RangedWeaponProfile?` | Zusatzdaten für Distanzstufen, Ladezeit und Geschosse |

`CombatConfig.weaponSlots` gibt `[mainWeapon]` zurück falls `weapons` leer ist (Legacy-
Kompatibilität), sonst `weapons`.

Legacy-Waffen ohne `combatType` werden tolerant als Nahkampfwaffen geladen.
Fernkampfwaffen persistieren ihre aktive Distanzstufe und den aktuell gewählten
Geschosstyp direkt im Waffenslot.

In der Kampf-UI bleiben nur `Waffentalent` und `BF` inline editierbar. Weitere
Waffenbasiswerte werden im gruppierten Waffen-Dialog bearbeitet; berechnete
TP-/INI-/AT-Zwischenwerte sind dort als read-only Vorschau sichtbar.

#### `WeaponCombatType`

**Datei:** `lib/domain/combat_config/weapon_combat_type.dart`

| Wert | Bedeutung |
|---|---|
| `melee` | Nahkampfwaffe |
| `ranged` | Fernkampfwaffe |

#### `RangedDistanceBand`

**Datei:** `lib/domain/combat_config/ranged_distance_band.dart`

| Feld | Typ | Bedeutung |
|---|---|---|
| `label` | `String` | Frei benennbare Entfernungsstufe |
| `tpMod` | `int` | TP-Modifikator dieser Distanz |

#### `RangedProjectile`

**Datei:** `lib/domain/combat_config/ranged_projectile.dart`

| Feld | Typ | Bedeutung |
|---|---|---|
| `name` | `String` | Anzeigename des Geschosses |
| `count` | `int` | Persistenter Bestand |
| `tpMod` | `int` | TP-Modifikator des Geschosses |
| `iniMod` | `int` | INI-Modifikator des Geschosses |
| `atMod` | `int` | AT-Modifikator des Geschosses |
| `description` | `String` | Beschreibung / Notiz |

#### `RangedWeaponProfile`

**Datei:** `lib/domain/combat_config/ranged_weapon_profile.dart`

| Feld | Typ | Bedeutung |
|---|---|---|
| `reloadTime` | `int` | Feste Ladezeit der Waffe |
| `distanceBands` | `List<RangedDistanceBand>` | Genau fünf editierbare Distanzstufen |
| `projectiles` | `List<RangedProjectile>` | Frei pflegbare Geschossarten |
| `selectedDistanceIndex` | `int` | Aktive Distanzstufe im Kampf-Tab |
| `selectedProjectileIndex` | `int` | Aktives Geschoss im Kampf-Tab |

#### `OffhandAssignment` & `OffhandEquipmentEntry`

**Datei:** `lib/domain/combat_config/offhand_assignment.dart`,
`lib/domain/combat_config/offhand_equipment_entry.dart`

| Typ / Feld | Bedeutung |
|---|---|
| `OffhandAssignment.weaponIndex` | Referenz auf eine Nebenhand-Waffe oder `-1` |
| `OffhandAssignment.equipmentIndex` | Referenz auf Schild/Parierwaffe oder `-1` |
| `OffhandEquipmentEntry.name` | Anzeigename |
| `OffhandEquipmentEntry.type` | `parryWeapon` oder `shield` |
| `OffhandEquipmentEntry.breakFactor` | BF des Eintrags |
| `OffhandEquipmentEntry.shieldSize` | Schildgroesse (`small`, `large`, `veryLarge`) |
| `OffhandEquipmentEntry.iniMod` | INI-Modifikator auf die Hauptwaffe |
| `OffhandEquipmentEntry.atMod` | AT-Modifikator auf die Hauptwaffe |
| `OffhandEquipmentEntry.paMod` | PA-Modifikator fuer Parierwaffe oder Schild-Parade |

Fuer echte Nebenhand-Waffen leitet die Kampfvorschau zusaetzlich die Mali der
`falschen Hand` sowie moegliche Aktionsoptionen wie `Doppelangriff`,
`Zusatzangriff links` und `Zusatzparade links` ueber
`lib/rules/derived/two_weapon_combat_rules.dart` ab.

#### `ArmorConfig` & `ArmorPiece`

**Datei:** `lib/domain/combat_config/armor_config.dart`,
`lib/domain/combat_config/armor_piece.dart`

`ArmorConfig` enthält eine Liste von `ArmorPiece`-Einträgen und einen
`globalArmorTrainingLevel` (gültige Werte: 0, 2, 3).

| `ArmorPiece`-Feld | Bedeutung |
|---|---|
| `name` | Bezeichnung |
| `isActive` | Aktuell angelegt? |
| `rg1Active` | Rüstungsgewöhnung Stufe 1 aktiv? |
| `rs` | Rüstungsschutz |
| `be` | Behinderung |

#### `CombatSpecialRules`

**Datei:** `lib/domain/combat_config/combat_special_rules.dart`

Aktivierungsstatus von Kampf-Sonderfertigkeiten (alle `bool`):

| Feld | Sonderfertigkeit |
|---|---|
| `kampfreflexe` | Kampfreflexe |
| `kampfgespuer` | Kampfgespür |
| `schnellziehen` | Schnellziehen |
| `schnellladenBogen` | Schnellladen (Bogen) |
| `schnellladenArmbrust` | Schnellladen (Armbrust) |
| `ausweichenI/II/III` | Ausweichen I/II/III |
| `schildkampfI/II` | Schildkampf I/II |
| `parierwaffenI/II` | Parierwaffe I/II |
| `linkhandActive` | Sonderfertigkeit Linkhand |
| `flink` | Vorteil: Flink |
| `behaebig` | Nachteil: Behäbig |
| `axxeleratusActive` | Zauber Axxeleratus (verdoppelt Ini-Basisanteil und GS; weitere Kampfboni) |
| `klingentaenzer` | Klingentänzer (2W6 statt 1W6 für Initiative) |
| `aufmerksamkeit` | Aufmerksamkeit |
| `activeCombatSpecialAbilityIds` | `List<String>` — Aktiv geschaltete katalogbasierte Kampf-Sonderfertigkeiten ohne bereits separat modellierte Manöver oder fest verdrahtete Regel-Schalter |
| `gladiatorStyleTalent` | `String` | Talentwahl fuer den Gladiatorenstil (`raufen` oder `ringen`) |
| `activeManeuvers` | `List<String>` — Manuell aktivierte Manöver-IDs |

Beidhaendiger Kampf I/II und `Tod von Links` werden fuer die Regellogik ueber
`activeCombatSpecialAbilityIds` ausgewertet, damit die Kampf-UI diese
Katalog-Sonderfertigkeiten ohne zusaetzliches Persistenzfeld in die
Nebenhand-Aktionskarte uebernehmen kann.

Waffenmeisterschaften sind bewusst **nicht** Teil von `CombatSpecialRules`,
sondern liegen in `CombatConfig.waffenmeisterschaften`.

#### `CombatManualMods`

**Datei:** `lib/domain/combat_config/combat_manual_mods.dart`

Manuell eingetragene Kampfmodifikatoren (situativ):

| Feld | Bedeutung |
|---|---|
| `iniMod` | Initiative-Modifikator |
| `ausweichenMod` | Ausweichen-Modifikator |
| `atMod` | Angriff-Modifikator |
| `paMod` | Parade-Modifikator |
| `iniWurf` | Gewürfeltes Ini-Ergebnis (1W6 oder 2W6) |

---

### 2.5a `WaffenmeisterConfig`

**Datei:** `lib/domain/combat_config/waffenmeister_config.dart`

`WaffenmeisterConfig` beschreibt eine Waffenmeisterschaft fuer eine konkrete
Waffenart innerhalb von `CombatConfig.waffenmeisterschaften`.

| Feld | Typ | Bedeutung |
|---|---|---|
| `talentId` | `String` | Zugehoeriges Kampftalent |
| `weaponType` | `String` | Konkrete Waffenart |
| `bonuses` | `List<WaffenmeisterBonus>` | Vergebene Baukasten-Boni |
| `additionalWeaponTypes` | `List<String>` | Bis zu zwei weitere aehnliche Waffenarten |
| `styleName` | `String` | Optionaler Stilname |
| `masterName` | `String` | Optionaler Lehrmeister |
| `requiredAttribute1/2` | `String` | Geforderte Eigenschaften |
| `requiredAttribute1Value/2Value` | `int` | Mindestwerte der Eigenschaften |

Die automatische Wirkung der Waffenmeisterschaft wird in
`lib/rules/derived/waffenmeister_rules.dart` aus den vergebenen Boni abgeleitet.

---

### 2.6 `HeroTalentEntry`

**Datei:** `lib/domain/hero_talent_entry.dart`

Speichert die Werte eines Helden in einem einzelnen Talent.

| Feld | Typ | Bedeutung |
|---|---|---|
| `talentValue` | `int` | Talentwert (TaW) |
| `atValue` | `int` | AT-Wert (nur Kampftalente) |
| `paValue` | `int` | PA-Wert (nur Kampftalente) |
| `modifier` | `int` | Situativer Modifikator |
| `specialExperiences` | `int` | Sondererfahrungspunkte |
| `specializations` | `String` | Varianten/Spezialisierungen (Legacy-Freitext) |
| `combatSpecializations` | `List<String>` | Geparste Spezialisierungsliste |
| `gifted` | `bool` | Talent begabt (kostenlos/verstärkt)? |
| `ebe` | `int` | Erweiterungspunkte |

**Kampftalent-Validierung** (`lib/domain/validation/combat_talent_validation.dart`):

| Regel | Bedingung |
|---|---|
| Alle Werte ≥ 0 | immer |
| TaW = 0 → AT = 0, PA = 0 | immer |
| Nahkampf: AT + PA = TaW | wenn `type == 'nahkampf'` |
| Fernkampf: AT = TaW, PA = 0 | wenn `type == 'fernkampf'` |

---

### 2.6a `HeroMetaTalent`

**Datei:** `lib/domain/hero_meta_talent.dart`

Beschreibt ein heldenspezifisches Meta-Talent. Es wird nicht aus dem
Regelkatalog geladen, sondern direkt im `HeroSheet` gespeichert.

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | `String` | Stabile ID innerhalb des Helden |
| `name` | `String` | Anzeigename |
| `componentTalentIds` | `List<String>` | Referenzierte Talent-IDs fuer die Mittelwert-Berechnung |
| `attributes` | `List<String>` | Genau 3 Eigenschaftskuerzel fuer Probe und Max-TaW |
| `be` | `String` | Optionale BE-Regel (`''`, `-`, `-N`, `xN`) |

Der Meta-TaW wird nicht persistiert, sondern aus den referenzierten
`HeroTalentEntry.talentValue`-Werten dynamisch berechnet.

---

### 2.6b `HeroRitualCategory`, `HeroRitualKnowledge` und `HeroRitualEntry`

**Dateien:** `lib/domain/hero_rituals.dart`, `lib/rules/derived/ritual_rules.dart`

Rituale werden nicht aus dem globalen Regelkatalog geladen, sondern pro Held
direkt in `HeroSheet.ritualCategories` gespeichert. Eine Ritualkategorie
enthaelt entweder eine eigene Ritualkenntnis mit TaW und Lernkomplexitaet oder
eine Liste referenzierter Talent-IDs, deren TaWs im Magie-Tab angezeigt werden.

| Typ | Kernfelder |
|---|---|
| `HeroRitualCategory` | `id`, `name`, `knowledgeMode`, `ownKnowledge`, `derivedTalentIds`, `additionalFieldDefs`, `rituals` |
| `HeroRitualKnowledge` | `name`, `value`, `learningComplexity` |
| `HeroRitualFieldDef` | `id`, `label`, `type` (`text`, `threeAttributes`) |
| `HeroRitualFieldValue` | `fieldDefId`, `textValue`, `attributeCodes` |
| `HeroRitualEntry` | `name`, `wirkung`, `kosten`, `wirkungsdauer`, `merkmale`, optionale Felder wie `zauberdauer`, `zielobjekt`, `reichweite`, `technik` |

`ritual_rules.dart` normalisiert Zusatzfelder, entfernt verwaiste Feldwerte,
kanonisiert `threeAttributes`-Eingaben auf `MU/KL/IN/CH/FF/GE/KO/KK` und loest
talentbasierte Ritualkategorien fuer die UI auf.

Fuer Vertraute existiert zusaetzlich ein festes Preset in
`lib/catalog/vertrautenmagie_preset.dart`. Das gleichwertige
JSON-Referenzformat liegt unter
`assets/catalogs/house_rules_v1/vertrautenmagie_rituale.json`.

---

### 2.7 `HeroInventoryEntry`

**Datei:** `lib/domain/hero_inventory_entry.dart`

Repraesentiert einen Inventargegenstand. Legacy-Stringfelder bleiben fuer
Rueckwaertskompatibilitaet erhalten; zusaetzlich existieren typisierte
Inventarfelder fuer Quelle, Gewicht, Wert, Modifier und magisch/geweiht.

| Feld | Bedeutung |
|---|---|
| `gegenstand` | Gegenstandsname |
| `woGetragen` | Wo getragen |
| `typ` | Typ/Kategorie |
| `welchesAbenteuer` | In welchem Abenteuer erworben |
| `gewicht` | Gewicht |
| `wert` | Wert |
| `artefakt` | Legacy-Artefakt-Kennzeichnung fuer Altbestaende |
| `anzahl` | Menge als Text; Projektion von `menge`, Freitext bedeutet „Menge offen“ |
| `amKoerper` | Am Körper getragen? |
| `woDann` | Aufbewahrungsort |
| `gruppe` | Gruppe/Kategorie |
| `beschreibung` | Beschreibung |
| `itemType` | Typisierte Inventarkategorie (`ausruestung`, `verbrauchsgegenstand`, `wertvolles`, `sonstiges`) |
| `source` | Herkunft des Eintrags (`manuell`, Kampf-Sync oder `abenteuer`) |
| `sourceRef` | Namensverweis auf einen Kampf-Slot (`w:<Name>` …), den auch die veröffentlichte App versteht, oder Verweis auf Abenteuerbeute |
| `slotRef` | Stabiler ID-Verweis auf den Kampf-Slot (`w#<id>` …); nur geschrieben, wenn belegt |
| `istAusgeruestet` | Steuert, ob Modifier des Eintrags aktiv wirken. Bei verknüpften Einträgen setzt der Abgleich ihn (07.10.2026): Waffe nur in der Hand (gewählte Hauptwaffe oder Nebenhand), Schild/Parierwaffe nur in der Nebenhand, Rüstungsteil nur angelegt |
| `modifiers` | Typisierte Inventar-Modifikatoren |
| `gewichtGramm` | Numerisches Gewicht in Gramm **pro Stück** (ARCH-03, 07.10.2026); Summen rechnen Menge × Stückgewicht, offene Menge = 1 Stück (`inventar_summen_rules.dart`) |
| `wertSilber` | Numerischer Wert in Silbertalern **pro Stück**; Summen wie beim Gewicht |
| `herkunft` | Fundort, Quelle oder Haendler |
| `isMagisch` / `magischDescription` | Magische Markierung und Beschreibung |
| `isGeweiht` / `geweihtDescription` | Geweihte Markierung und Beschreibung |
| `traegerTyp` / `traegerId` | Zuordnung zum Helden oder zu einem Begleiter |
| `instanzId` | Stabile Instanz-ID des Stapels/Exemplars (ARCH-03); nur im Helden eindeutig, bei einer Kopie unverändert; vergeben erst in `saveHero`, nur geschrieben, wenn belegt |
| `menge` | Strukturierte Stückzahl (ARCH-03); `null` = offen; nur geschrieben, wenn belegt |
| `abgelegt` | `AbgelegterKampfgegenstand` (`lib/domain/abgelegter_kampfgegenstand.dart`): gemerkte Kampfwerte eines im Kampfbereich nur abgelegten Exemplars — genau einer von `waffe`, `geschoss`, `ruestungsteil`, `nebenhandteil`; nur geschrieben, wenn belegt |

**Kampf-/Inventarverweise (ARCH-03, Teilfix B2/B3).** Waffen, Geschosse,
Ruestungsstuecke und Nebenhand-Teile speichern eine Slot-ID.
`CombatConfig.fromJson` vergibt fehlende IDs deterministisch in
Listenreihenfolge (`w1`, `p1`, `a1`, `oh1`). `HeroActions.saveHero` gibt neu
angelegten Slots UUIDs, damit ein geloeschter Slot seine ID nicht an einen
neuen Namensvetter vererbt. Die Editoren fuer Geschosse und Nebenhand-Teile
tragen die bestehende ID beim Speichern weiter.

Ein verknuepfter Inventareintrag traegt **zwei Verweise**
(`lib/domain/combat_config/inventar_verweise.dart`):

- `sourceRef` ist der Namensverweis (`w:<Name>`, `a:<Name>`, `oh:<Name>`,
  `w:<Waffe>|p:<Geschoss>`). Nur ihn kennt die bereits veroeffentlichte App
  (`main`, Stand vor ARCH-03). Ihr Abgleich laeuft bei jedem Speichern und
  verwirft Eintraege, deren Verweis er nicht zuordnen kann. Eine Vorabfassung
  mit ID-Verweis in `sourceRef` haette dort alle verknuepften Inventardaten
  geloescht.
- `slotRef` ist der ID-Verweis (`w#<id>`, `a#<id>`, `oh#<id>`,
  `w#<waffen-id>|p#<geschoss-id>`). Er unterscheidet gleichnamige Exemplare.
  Die veroeffentlichte App verwirft ihn beim Speichern, zusammen mit den
  Slot-IDs.

Zuordnung beim **Abgleich** (`reconcileInventoryWithCombat`) und bei der
Uebernahme magischer/geweihter Angaben (`applyLinkedInventoryDetailsToConfig`;
beide nutzen dieselbe Paarung):

0. **Instanz zuerst** (ARCH-03, Verweis Slot → Instanz): Traegt der Slot eine
   `inventarInstanzId`, passt der verknuepfte Eintrag derselben Quelle mit
   dieser Instanz-ID — es sei denn, sein `slotRef` zeigt auf einen *anderen
   bestehenden* Slot (etwa weil der Slot eine Kopie ist, die die Instanz
   ihres Vorbilds mitgenommen hat). Ohne `slotRef` oder mit einem auf einen
   entfernten Slot entscheidet die Instanz. Jeder Eintrag wird einmal
   vergeben; ein neu angelegter Eintrag uebernimmt die Instanz des Slots
   nicht, er bekommt seine eigene erst in `vergibInstanzIds`.
1. Ein Eintrag mit `slotRef` passt nur ueber diesen. Verweist er auf einen
   entfernten Slot, faellt er weg. Er wandert nie ueber den Namen zu einem
   gleichnamigen Exemplar weiter (Befund B2).
2. Ueber den Namen gleicht der Abgleich nicht mehr ab (ARCH-03, Schritt 3,
   07.10.2026). Altdaten ohne `slotRef` ordnet einmalig das Laden zu
   (`migriereInventarVerweise`, Tabelle unten). Nur ein Slot ohne ID — den
   gibt es allein im Speicher vor dem ersten Speichern — paart noch Eintraege
   ohne `slotRef` ueber den Namen.
3. Die Ausgabe bleibt „manuelle Eintraege, dann verknuepfte in
   Slot-Reihenfolge“. Die veroeffentlichte App paart gleichnamige Eintraege
   ueber diese Reihenfolge; sie darf sich nicht aendern.

Geschossmengen gehen ueber `slotRef ?? sourceRef` zurueck in die
Kampfkonfiguration. Mit dem Namen allein bekaeme bei zwei gleichnamigen
Boegen immer der erste die Menge.

**Beim Laden** ergaenzt `migriereInventarVerweise` den ID-Verweis. Die
Migration ist deterministisch und ein Fixpunkt:

| Eintrag | Ergebnis |
|---|---|
| mit `slotRef` | unveraendert |
| Vorabfassung, ID-Verweis in `sourceRef`, Slot vorhanden | `slotRef` = ID, `sourceRef` = Name des Slots |
| Vorabfassung, Slot entfernt | `slotRef` = ID, `sourceRef` bleibt; der naechste Abgleich verwirft ihn |
| Namensverweis ohne `slotRef` | `slotRef` des ersten freien gleichnamigen Slots |
| Namensverweis ohne freien Slot, manuell, Abenteuerbeute | unveraendert |

**Mischbetrieb mit der veroeffentlichten App.** Speichert sie einen Helden,
entfallen Slot-IDs, `slotRef` und alle unbekannten Felder. Diese Version
leitet die IDs danach deterministisch neu ab (`w1` …) und ordnet die
Eintraege ueber den Namen wieder zu. Jeder Slot behaelt so seine
Inventardaten; UUIDs und Felder neuerer Versionen gehen dort verloren.
Innerhalb der veroeffentlichten App gilt weiter ihr eigenes Verhalten bei
gleichnamigen Exemplaren (B2/B3). Nach jedem Upload dieser Version schreibt
sie einmal ihre Fassung zurueck (Echo). Diese Version uebernimmt das Echo
ohne erneuten Upload (Abschnitt Konto-Sync, Befund B10). Faellt eine
Offline-Aenderung hier mit dem Echo zusammen, entsteht ein sichtbarer
Konflikt; im Vergleich erscheinen dann auch die geaenderten IDs.

Das Format aendert die Helden-Inhalts-Hashes der Bestandshelden mit
verknuepfter Ausruestung (f01, f02, f04, f06). Fixtures, Hash-Pins,
Domain-, Regel-, Widget-, Hive- und Sync-Tests sichern es ab. Kampfkonfiguration
und Inventar bleiben zwei Darstellungen: Ein gemeinsames Gegenstandsmodell,
Katalog-IDs und die vollstaendige ARCH-03-Migration sind noch offen. Der
Abgleich aendert bestehende verknuepfte Eintraege nur per `copyWith` und
uebernimmt aus dem Slot allein dessen Felder; Typ und Traeger bleiben
erhalten (Befund B9 behoben).

**Verweis Slot → Instanz (ARCH-03, Teilstand 06.10.2026).** Waffe,
Geschoss, Ruestungsstueck und Nebenhand-Teil tragen `inventarInstanzId`, die
Instanz-ID ihres verknuepften Eintrags. `bindeSlotsAnInstanzen`
(`rules/derived/inventar_slot_instanz_rules.dart`) setzt sie in `saveHero`
nach Abgleich und Instanzvergabe, nie beim Laden; ohne Eintrag wird ein
veralteter Verweis geleert. Der Verweis ist abgeleitet und kein Profil:
Inhaltsvergleiche gegen „inzwischen geaendert“ (`kampf_aenderung_rules.dart`,
`gefecht_hand_rules.dart`) und Gefechts-Fingerabdruecke (Ziel-, Lade- und
Bruchprofil) lassen ihn ueber `ohneInstanzverweise` weg. Sonst verloere etwa
ein gebundener Ladezustand beim ersten Speichern nach dem Update seine Waffe.
`slotRef` am Eintrag bleibt bestehen; die Ladermigration
(`migriereInventarVerweise`) ordnet weiterhin nur ueber Name und Slot-ID zu.

**Ablegen und Zurückholen (ARCH-03, Entscheidung vom 06.10.2026).** Wer im
Kampf-Tab eine Waffe, ein Rüstungsteil oder ein Schild bzw. eine Parierwaffe
entfernt, wird gefragt: „Nur ablegen“ oder „Ganz entfernen“
(`kampfgegenstand_entfernen_dialog.dart`). Geschosse, die das Ergebnis des
Waffeneditors nicht mehr führt, fragen dasselbe beim Speichern der Waffe.
Regeln in `rules/derived/kampfgegenstand_ablegen_rules.dart`:

- *Ablegen* entfernt den Slot und macht seinen verknüpften Eintrag (gefunden
  über Instanz, `slotRef`, Name) zu einem **manuellen** Eintrag ohne
  Verweise, mit derselben Instanz-ID, nicht ausgerüstet und mit
  `abgelegt` = Slot ohne Instanzverweis. Eine abgelegte Waffe merkt sich
  keine Geschosse. Manuell, weil mehrere Stellen allein an der Quelle
  „verknüpft“ festmachen; Liste und Filter zeigen ihn über
  `anzeigeQuelleImInventar` trotzdem als Waffe, Geschoss usw.
- *Ganz entfernen* entfernt nur den Slot; der Abgleich verwirft den Eintrag
  wie bisher.
- **Geschosse gehen nie still verloren:** Eine entfernte Fernkampfwaffe legt
  ihre benannten Geschosse in beiden Fällen ab, auch mit Bestand 0. Ein
  Bestand von 0 löscht nirgends einen Eintrag.
- *In Kampfbereich übernehmen* (Inventareditor,
  `inventory_kampf_uebernehmen.dart`, `mitUebernommenemKampfgegenstand`)
  hängt den Slot aus den gemerkten Werten hinten an; Name und
  magisch/geweiht kommen vom Eintrag, ein Geschoss bekommt die Menge und
  wählt seine Fernkampfwaffe. Der Eintrag wird wieder verknüpft
  (`sourceRef` = Namensverweis, ohne `slotRef`); der Abgleich paart ihn über
  die Instanz, Angaben wie Beschreibung und Gewicht bleiben.
- Der Kampf-Tab schreibt beides über `_aendereKampfUndInventar`; im
  Bearbeitungsmodus hält er dafür einen Inventarentwurf (`_draftInventar`),
  den „Speichern“ zusammen mit der Kampfkonfiguration übernimmt.

**Menge und Stapel (ARCH-03, Entscheidungen vom 04. und 06.10.2026).** Ein
Stapel ist ein Gegenstand mit einer Instanz-ID und einer Menge. Die Lesart
liegt in `rules/derived/inventar_menge_rules.dart`:

| `anzahl` | `menge` | wirksame Menge |
|---|---|---|
| reine Zahl | fehlt | die Zahl (`saveHero` ergänzt `menge`) |
| reine Zahl | dieselbe Zahl | die Zahl |
| reine Zahl | andere Zahl | `anzahl` — eine ältere Version hat geändert; der Editor zeigt die Abweichung, nur eine Bearbeitung des Eintrags löst sie auf |
| leer oder Freitext | beliebig | offen (`null`), wird nie geraten |

Diese Version schreibt beide immer gemeinsam (`mitInventarMenge`). Der
Abgleich vergibt keine `menge`, damit er auf Bestandsdaten ein Fixpunkt
bleibt; hat ein Geschoss schon eine, hält er sie mit dem Slot synchron, der
die Menge führt. Ein Geschoss ohne eindeutige Menge wird im Editor
abgewiesen. **Stapel teilen** (`inventar_stapel_rules.dart`) spaltet einen
unverknüpften Stapel mit neuer Instanz-ID ab; bei einem verknüpften Geschoss
sinkt die Menge am eigenen Slot. **Zusammenführen** (gleiche Datei,
Entscheidung vom 07.10.2026) addiert einen Stapel in einen anderen:
gleicher Name (ohne Groß-/Kleinschreibung), Typ, magisch/geweiht samt
Beschreibung und Modifikatoren, beide mit eindeutiger Menge; Ort und übrige
Angaben kommen vom Ziel, gemerkte Kampfwerte eines abgelegten Stapels
bleiben. Die Quelle darf nicht verknüpft sein; ein verknüpftes Ziel nur als
Geschoss, dessen Slot dann die Summe führt. Abenteuerbeute ist kein Ziel,
weil das Zurücknehmen des Abenteuers sie über ihren Verweis entfernt.
Inventarwege treffen Einträge über die Instanz-ID
(`findeInventarEintragZurAenderung`), Altdaten ohne ID über den Inhalt.
Slots verweisen zusätzlich über `inventarInstanzId` auf ihr Exemplar.

**Verkaufen** (`rules/derived/inventar_verkauf_rules.dart`, Dialog
`inventory_verkaufen_dialog.dart`, Entscheidung vom 07.10.2026) verkauft den
ganzen Gegenstand oder einen Teil des Stapels; eine offene Menge zählt als
ein Stück. Der Erlös ist frei wählbar, vorbelegt mit dem vollen Wert (Wert
pro Stück × Anzahl), und kommt über `mitDukatenSchritt` auf den Geldstand
(unlesbarer Geldstand: abgewiesen). Unverknüpft sinkt die Menge, der letzte
Rest entfernt den Eintrag. Ausgerüstete Waffen, Rüstungsteile und
Nebenhandteile verlassen samt Slot den Kampfbereich (wie „Ganz entfernen“,
die Geschosse einer Fernkampfwaffe werden abgelegt; die letzte Waffe bleibt
gesperrt). Pfeile am Bogen senken den Bestand ihres Slots und bleiben bei 0
stehen.

---

### 2.8 `HeroNoteEntry` und `HeroConnectionEntry`

**Dateien:** `lib/domain/hero_note_entry.dart`, `lib/domain/hero_connection_entry.dart`

Heldenspezifische Freitexteinträge für den Notizen-Tab.

| Typ | Kernfelder |
|---|---|
| `HeroNoteEntry` | `title`, `description` |
| `HeroConnectionEntry` | `name`, `ort`, `sozialstatus`, `loyalitaet`, `beschreibung` |

---

### 2.9 `HeroTransferBundle` — Export-/Import-Hülle

**Datei:** `lib/domain/hero_transfer_bundle.dart`

Kapselt einen vollständigen Heldenexport.

| Feld/Konstante | Wert/Typ | Bedeutung |
|---|---|---|
| `kind` (const) | `'dsa.hero.export'` | Format-Kennzeichnung |
| `transferSchemaVersion` (const) | `3` | Export-Formatversion (strict) |
| `exportedAt` | `DateTime` (UTC) | Exportzeitpunkt |
| `hero` | `HeroSheet` | Persistierte Heldendaten |
| `state` | `HeroState` | Laufzeitzustand zum Exportzeitpunkt |
| `catalogEntries` | `List<HeroTransferCatalogEntry>?` | Optional eingebettete referenzierte Custom-Katalogeintraege |

`fromJson()` validiert strikt: `kind`, `transferSchemaVersion`, ISO-8601-Zeitstempel,
Vorhandensein von `hero` und `state`. Wirft `FormatException` bei Validierungsfehlern.

---

## 3. Katalog-Datenmodelle (Catalog Layer)

### Übersicht

**`RulesCatalog`** (`lib/catalog/rules_catalog.dart`) hält alle Spielregeldaten:

| Feld | Typ | Inhalt |
|---|---|---|
| `version` | `String` | Katalogversion (z. B. `'house_rules_v1'`) |
| `source` | `String` | Ursprungsdateien |
| `talents` | `List<TalentDef>` | Alle Talente (regulär + Kampf) |
| `spells` | `List<SpellDef>` | Alle Zaubersprüche |
| `weapons` | `List<WeaponDef>` | Alle Waffen |
| `maneuvers` | `List<ManeuverDef>` | Kampfmanöver (optional) |
| `combatSpecialAbilities` | `List<CombatSpecialAbilityDef>` | Kampf-Sonderfertigkeiten |
| `generalSpecialAbilities` | `List<SpecialAbilityDef>` | Allgemeine Sonderfertigkeiten |
| `magicSpecialAbilities` | `List<SpecialAbilityDef>` | Magische Sonderfertigkeiten |
| `karmalSpecialAbilities` | `List<SpecialAbilityDef>` | Karmale Sonderfertigkeiten |
| `advantages` | `List<HeroTraitDef>` | Katalogisierte Vorteile |
| `disadvantages` | `List<HeroTraitDef>` | Katalogisierte Nachteile |
| `sprachen` / `schriften` | `List<SpracheDef>` / `List<SchriftDef>` | Sprach- und Schriftkatalog |
| `reisebericht` | `List<ReiseberichtDef>` | Separater Reisebericht-Katalog |
| `metadata` | `Map<String, dynamic>` | Weitere Metadaten |

#### Mehrfach erwerbbare Sonderfertigkeiten mit Auswahl

Einige allgemeine Sonderfertigkeiten werden laut Regelwerk mehrfach mit
jeweils einer anderen Auswahl erworben — Kulturkunde je Kultur, Gelaendekunde
je Gelaendetyp, Ortskenntnis je Oertlichkeit, Akklimatisierung je Klima,
Berufsgeheimnis je Geheimwissen. `SpecialAbilityDef`
(`lib/catalog/special_ability_def.dart`) traegt dafuer optionale Felder:

| Feld | JSON | Inhalt |
|---|---|---|
| `mehrfachwaehlbar` | `mehrfachwaehlbar` | SF darf mehrfach erworben werden |
| `variantenLabel` | `varianten_label` | Feldbeschriftung im Dialog, z. B. `Kultur` |
| `varianten` | `varianten` | Katalogisierte Auswahlvorschlaege (darf leer sein) |
| `variantenGruppen` | `varianten_gruppen` | Varianten mit gruppenspezifischen AP-Kosten |
| `variantenFreitext` | `varianten_freitext` | Freie Eingabe erlaubt (Default `true`) |
| `apErstwerb` | `ap_erstwerb` | AP-Vorschlag fuer den ersten Erwerb |
| `apFolgeerwerb` | `ap_folgeerwerb` | AP-Vorschlag fuer jeden weiteren Erwerb |

`varianten_gruppen` traegt Kosten, die an der Auswahl selbst haengen statt an
der Reihenfolge des Erwerbs — Merkmalsgrossmeister nach Merkmalsklassifikation
(600/800/1000 AP), die Traditionsrituale je Einzelritual. Eine Gruppe besteht
aus `label`, `ap` und `varianten`; der Getter `alleVarianten` fuehrt flache
Liste und Gruppen zusammen. Liegt die gewaehlte Variante in einer Gruppe,
schlaegt deren Preis die Erst-/Folgeerwerb-Staffelung (`variantGroupFor` und
`suggestVariantApCost`).

Fehlen die Felder, verhaelt sich die SF wie bisher (einmaliger An/Aus-Erwerb,
AP-Vorschlag aus `parseLeadingApAmount(kosten)`). Jede erworbene Instanz wird
als eigener Eintrag im Format `Basisname (Variante)` gespeichert —
`Kulturkunde (Novadi)`. Aufbau, Zerlegung und der gestaffelte AP-Vorschlag
liegen in `lib/rules/derived/special_ability_variant_rules.dart`;
`matchCatalogSpecialAbility` faellt fuer solche Namen auf den Basisnamen
zurueck, damit Kostenhinweis und Detailansicht weiter greifen.

Im Magiebereich nutzen das die drei epischen bzw. gruppierten SF
(Merkmalsgrossmeister, Arkane Meisterschaft, Elementaraspekt) sowie die 17
Ritualgruppen der Kategorie `Traditionsrituale` — Hexenflueche, Kugelzauber,
Keulenrituale und so fort — mit rund 150 einzeln erwerbbaren Ritualen.

#### AP-Verrechnung ausserhalb des Sonderfertigkeiten-Katalogs

Merkmalskenntnisse und Repraesentationen sind keine Katalog-SF, sondern eigene
Felder im Heldenmodell (`HeroSheet.merkmalskenntnisse`,
`HeroSheet.representationen`) mit FilterChips im Magie-Header; die Chips
zeigen den Klartextnamen der Tradition. Die Kosten
liegen in `lib/rules/derived/magic_acquisition_rules.dart`:
`merkmalsklassifikation` (I/II/III) speist alle drei Merkmals-Preistabellen,
`repraesentationApCost` liefert 2.000/3.000/4.000 AP je nach Anzahl und
Voll-/Halbzauberer. Beim Aktivieren eines Chips oeffnet sich der
Erwerbsdialog; beim Deaktivieren werden — wie ueberall in der App — keine AP
zurueckerstattet.

Zauberspezialisierungen liegen in `HeroSpellEntry.specializations` und werden
in der Spalte `Spez.` der Zaubertabelle gepflegt. Kosten und ZfW-Schwellen
teilen sich die Formel mit der Talentspezialisierung
(`spellSpecializationApCost`, `requiredZfwForSpecialization`).

Seit 2026-03-29 wird der Asset-Katalog intern zunaechst als
`CatalogSourceData` geladen. Danach kombiniert `CatalogRuntimeData` die
Basisdaten mit konfliktfreien Custom-Dateien aus dem aktiven Heldenspeicher.
`CatalogAdminSnapshot` bildet daraus die Settings-Ansicht fuer die
Katalogverwaltung.

Katalogisierte Regelobjekte koennen optional ein strukturiertes `ruleMeta`
tragen. Darin liegen maschinenlesbare Herkunft (`official` oder
`house_rule`), zitierbare Belege, optionale Verweise auf ueberschriebene
Basiseintraege sowie epische Freischaltmetadaten
(`requiresOptIn`, `eligibleFromLevel`).

### `TalentDef`

| Feld | Bedeutung |
|---|---|
| `id` | Eindeutige ID (z. B. `'tal_empathie'`) |
| `name` | Anzeigename (Deutsch) |
| `group` | Gruppe (z. B. `'Kampftalent'`, `'Gabe'`) |
| `steigerung` | Steigerungskategorie (D/E/F) |
| `attributes` | Array mit 3 Eigenschaftskürzel für Proben |
| `type` | Typ (`'nahkampf'`, `'fernkampf'`, `'Gabe'`, …) |
| `be` | BE-Anforderung (`'-'`, `'-2'`, `'xBE'`, …) |
| `weaponCategory` | Zugehörige Waffenkategorien (kommagetrennt) |
| `alternatives` | Alternative Kategorienamen |
| `ruleMeta` | Optionale Herkunfts-, Beleg- und Epik-Metadaten |
| `active` | Im App verfügbar? |

Kampftalente erkennt man an: `group == 'Kampftalent'` **oder** `weaponCategory != ''`
**oder** `type in ['nahkampf', 'fernkampf']`.

### `WeaponDef`

| Feld | Bedeutung |
|---|---|
| `id` | Eindeutige ID (z. B. `'wpn_anderthalbhaender'`) |
| `name` | Waffenname |
| `type` | `'Nahkampf'` oder `'Fernkampf'` |
| `combatSkill` | Verknüpftes Kampftalent (Name) |
| `tp` | Schadens-/TP-Formel |
| `weaponCategory` | Kategorie(n) für Spezialisierungsabgleich |
| `possibleManeuvers` | Alle verfügbaren Manöver |
| `activeManeuvers` | Standardmäßig aktivierte Manöver |
| `tpkk` | TP/KK-Skalierungsnotation |
| `iniMod`, `atMod`, `paMod` | Waffenmodifikatoren |
| `reach` | Reichweite |
| `weight` | Arsenal-Rohgewicht aus dem Katalog |
| `length` | Arsenal-Rohlaenge aus dem Katalog |
| `breakFactor` | Arsenal-Roh-Bruchfaktor aus dem Katalog |
| `price` | Arsenal-Rohpreis aus dem Katalog |
| `remarks` | Arsenal-Rohbemerkungen aus dem Katalog |
| `reloadTime` | Feste Ladezeit von Fernkampfwaffen |
| `reloadTimeText` | Arsenal-Rohladezeit inklusive Zusatznotationen |
| `rangedDistanceBands` | Optionale Vorlage für die 5 Distanzstufen einer Fernkampfwaffe |
| `rangedProjectiles` | Optionale Geschoss-Vorlagen |
| `ruleMeta` | Optionale Herkunfts-, Beleg- und Epik-Metadaten |
| `active` | Im App verfügbar? |

### `SpellDef`

| Feld | Bedeutung |
|---|---|
| `id` | Eindeutige ID |
| `name` | Zaubername |
| `tradition` | Magie-Tradition |
| `steigerung` | Steigerungskategorie |
| `attributes` | Eigenschaftskürzel für Proben |
| `availability` | Alle Verbreitungs-Eintraege, z. B. `Elf6` oder `Dru(Elf)2` |
| `aspCost` | AsP-Kosten |
| `targetObject` | Zielobjekt |
| `castingTime` | Zauberdauer |
| `range` | Reichweite |
| `duration` | Wirkungsdauer |
| `wirkung` | Wirkungsbeschreibung |
| `modifications` | Modifikationen ohne Varianten-Liste |
| `variants` | Definierte Zauber-Varianten |
| `source` | Quellenangabe, beim LC-Import die erste Zauberseite |
| `traits` | Zaubereigenschaften |
| `ruleMeta` | Optionale Herkunfts-, Beleg- und Epik-Metadaten |
| `active` | Im App verfügbar? |

Der Zauberdetaildialog zeigt Merkmale und einen MR-Hinweis an. Der Hinweis
wird ueber `describeSpellMagicResistanceProbe` aus expliziten MR-Texten und
dem Zielobjekt abgeleitet, solange `(+MR)` nicht als eigenes Katalogfeld
vorliegt.

### `ManeuverDef`

| Feld | Bedeutung |
|---|---|
| `id` | Eindeutige ID |
| `name` | Manövername |
| `gruppe` | Kategorie |
| `erschwernis` | Erschwernis-Modifikator |
| `seite` | Quellseite |
| `erklarung` | Erklärungstext |

### `HeroTraitDef`

| Feld | Bedeutung |
|---|---|
| `id` | Eindeutige ID, getrennt nach Vorteilen und Nachteilen |
| `name` | Anzeigename des Vor- oder Nachteils |
| `traitType` | `advantage` oder `disadvantage`; validiert gegen die Katalogsektion |
| `costText` | GP-/Kostenangabe als kurzer Quellfakt, nicht als Regeltext |
| `valueKind` | Auswahlverhalten: `binary`, `level`, `points` oder `choice` |
| `minValue` / `maxValue` | Optionaler Wertebereich für Zahlen- und Stufenangaben |
| `unit` | Optionale Einheit für Zahlenwerte |
| `selectionTemplate` | Textvorlage für die Speicherung, z. B. `{name} {value}` oder `{name} ({choice})` |
| `markers` | Kurzmarker aus der Übersicht, z. B. `M`, `SE`, `Gabe`, `Z/H/V` |
| `source` | Kurze Quellenreferenz |
| `ruleMeta` | Optionale Herkunfts-, Beleg- und Paketmetadaten |
| `active` | Im App verfügbar? |
| `wirkungen` | Deklarative Regelwirkungen (`HeroTraitEffect`, `lib/catalog/hero_trait_effect.dart`), nur geschrieben, wenn belegt |

`HeroTraitDef` speichert bewusst nur katalogisierbare Fakten und keine
Langregeltexte. Regelwirkungen stehen deklarativ in `wirkungen` und werden
über die Katalog-ID ausgewertet (ARCH-02), nicht über den Anzeigenamen:

| `art` | Felder | Wirkung | Beispiele |
|---|---|---|---|
| `basiswert` | `ziel` (`lep`, `au`, `asp`, `kap`, `mr`, `ini`, `gs`, `ausweichen`), `jeWert`, `max`, optional `standard` | Wert × `jeWert`, Betrag auf `max` gekappt | Hohe Lebenskraft, Kurzatmig |
| `eigenschaft` | `standard`, `max`, `startwert` | Eigenschaft aus der Auswahl (`{choice}`), mit `startwert` auch Startwert und Maximum | Herausragende Eigenschaft |
| `schalter` | `ziel` (`flink`, `behaebig`, `linkshaender`) | feste Wirkung: GS ±1 und Ausweichen ±1 bzw. linker Arm als Schwertarm für Armwunden (`ModifierParseResult.hasLinkshaenderFromVorteile`) | Flink, Behäbig, Linkshänder |
| `wundschwelle` | `betrag` | fester Bonus auf alle Wundschwellenstufen | Eisern, Glasknochen |
| `rast` | `ziel` (`lepStufe`, `aspStufe`, `schlechteRegeneration`, `astralerBlock`), `standard`, `max` | Regenerationsstufe bzw. -einschränkung | Schnelle Heilung, Astraler Block |

Eine unbekannte `art` bleibt beim Laden roh erhalten und wirkt nicht.
`test/catalog/trait_effect_catalog_test.dart` prüft Arten, Ziele und
Vorzeichen gegen den echten Katalog. Hausregel-Pakete können `wirkungen` per
`setFields` ersetzen.

### Split-JSON-Struktur & Ladevorgang

**Basis-Dateipfad:** `assets/catalogs/house_rules_v1/`

```
manifest.json          ← Einstiegspunkt; enthält Dateipfade der Teilkataloge
talente.json           ← Nicht-Kampftalente (group != 'Kampftalent')
waffentalente.json     ← Kampftalente (group == 'Kampftalent')
waffen.json            ← Waffen
magie.json             ← Zaubersprüche
manoever.json          ← Manöver (optional)
kampf_sonderfertigkeiten.json ← Kampf-Sonderfertigkeiten (optional)
allgemeine_sonderfertigkeiten.json ← Allgemeine Sonderfertigkeiten (optional)
magische_sonderfertigkeiten.json ← Magische Sonderfertigkeiten (optional)
karmale_sonderfertigkeiten.json ← Karmale Sonderfertigkeiten (optional)
vorteile.json          ← Katalogisierte Vorteile (optional)
nachteile.json         ← Katalogisierte Nachteile (optional)
sprachen.json          ← Sprachen (optional)
schriften.json         ← Schriften (optional)
```

**Separater Reisebericht-Pfad:** `assets/catalogs/reiseberichte/house_rules_v1/`

**Synchronisierbare Custom-Dateien im Heldenspeicher:**
`<hero-storage>/custom_catalogs/<version>/<sektion>/<id>.json`

**Synchronisierbare Hausregel-Pakete im Heldenspeicher:**
`<hero-storage>/house_rule_packs/<version>/<packId>/manifest.json`

Hausregel-Pakete koennen zusaetzlich direkt in der App unter
`Einstellungen > Hausregeln > Hausregelverwaltung` gepflegt werden.
Der Settings-Bereich selbst nutzt adaptive Unterseiten: schmale Layouts fuehren
per Drilldown in einzelne Bereiche, breite Layouts zeigen links die Bereiche
und rechts die jeweilige Detailseite. Der Bereich `Rechtliches` zeigt den
Autor-, Fanprojekt-, Marken- und Rechtehinweis zu DSA und Ulisses Spiele.
Der Editor bietet eine strukturierte Manifest-Ansicht, einen JSON-Tab sowie
Import/Export einzelner Paketdateien; eingebaute Pakete bleiben read-only und
koennen nur als Vorlage geklont werden.

Hinweis:
`manoever.json` bleibt die kanonische Quelle für manöverartige
Kampfoptionen. `kampf_sonderfertigkeiten.json` enthält nur eigenständige
Kampf-Sonderfertigkeiten; die Kampf-UI filtert katalogbasierte
Namensdopplungen gegen den Manöverkatalog heraus.

**`CatalogLoader.loadSourceData()` + `buildCatalogFromSourceData()`**
(`lib/catalog/catalog_loader.dart`):

1. `manifest.json` laden (Dateipfade, Version, Metadaten)
2. Alle Teilkataloge laden (relative Pfade auflösen; Reisebericht darf ausserhalb des Basisordners liegen)
3. **Kampf-Split validieren**: `talente.json` darf keine `'Kampftalent'`-Einträge enthalten;
   `waffentalente.json` muss ausschließlich `'Kampftalent'`-Einträge enthalten
4. **IDs validieren**: Jede Sektion muss eindeutige, nicht-leere IDs haben
5. Eingebaute und importierte Hausregel-Pakete laden
6. Basisdaten mit aktiven Hausregel-Patches auflösen
7. Aufgelöste Basisdaten mit konfliktfreien Custom-Dateien aus dem Heldenspeicher mergen
8. Zusammengeführten `RulesCatalog` zurückgeben

### Eingebaute Hausregel-Pakete

- Eingebaute Packs liegen unter `assets/catalogs/house_rules_v1/packs/<packId>/manifest.json`.
- Jedes eingebaute `manifest.json` muss zusaetzlich in `pubspec.yaml` als
  Flutter-Asset registriert sein; sonst wird das Paket nicht gebuendelt und
  taucht im Settings-Screen nicht als aktivierbare Hausregel auf.
- Reine Opt-in-Einträge koennen direkt im Basiskatalog liegen, solange ihr
  `ruleMeta.sourceKey` auf eine bekannte Pack-ID zeigt. Der Resolver blendet
  solche Eintraege aus, sobald das zugehoerige Pack deaktiviert ist.
- Feld-Overrides wie Lernkomplexitaeten werden ueber `patches[].setFields`
  modelliert und im `HouseRuleProvenanceIndex` mitsamt Gewinner-Paket
  dokumentiert.
- Das Pack `regelwerk_ueberarbeitung_v1` nutzt diese Schichtung fuer
  `Körperliche Talente`: Die Baseline in `talente.json` wurde fuer die
  betroffenen Eintraege auf `Wege der Helden.pdf` S. 316 (`official`)
  zurueckgefuehrt; das Kind-Pack
  `regelwerk_ueberarbeitung_v1.talents_learning` legt die Hausregel-
  Abweichungen aus `Erweiterung und Überarbeitung des Regelwerks.pdf`
  selektiv wieder darueber.

---

## 4. Berechnungsregeln (Rules Layer)

Alle Regeln sind **pure Dart-Funktionen** ohne Seiteneffekte in `lib/rules/derived/`.

### 4.1 Ressourcen-Maximalwerte

**Datei:** `lib/rules/derived/ressourcen_rules.dart`

| Wert | Formel |
|---|---|
| MaxLeP | `round((KO + KO + KK) / 2) + min(level, 21) + bought.lep + Mod` |
| MaxAu | `round((MU + KO + GE) / 2) + level × 2 + bought.au + Mod` |
| MaxAsP | `round((MU + INN + CH) / 2) + level × 2 + bought.asp + Mod` |
| MaxKaP | `bought.kap + Mod` (kein Eigenschaftsanteil) |
| MR | `round((MU + KL + KO) / 5) + bought.mr + Mod` |

`Mod` = Summe aus `persistentMods` (Inspector-Schnellmodifikatoren), benannten
Stat-Modifikatoren, Textmodifikatoren aus Herkunft und Vor-/Nachteilen,
`tempMods`, ausgerüstetem Inventar und den armunabhängigen Wundabzügen für
den jeweiligen Wert. `DerivedStats.modifiers` trägt diese Summe; die
Kampfvorschau rechnet AT-/PA-Basis, RS und Eigenschafts-INI damit weiter,
sodass etwa eine Wunde AT, PA und Ausweichen genauso senkt wie die
Basiswerte. Armgebundene Wundabzüge rechnet erst die Waffe im jeweiligen Arm
an, wundbedingte Eigenschaftsverluste gelten nur für Proben
(`probenEigenschaften`, siehe „Zonenwunden nach WdS“ unten).

**Zukauf-Grenzen:** `lib/rules/derived/bought_stat_limit_rules.dart`
begrenzt den AP-Zukauf im Steigerungsdialog fuer Grundwerte. LeP duerfen bis
`floor(KO / 2)`, Au bis `KO` und MR bis `floor(MU / 2)` gekauft werden. Fuer
AsP und KaP gibt es derzeit keine harte Zukauf-Grenze; dort begrenzen nur die
verfuegbaren AP. Die Berechnung nutzt permanente effektive Eigenschaften ohne
temporaere Zustandseffekte.

### 4.2 Kampfbasiswerte

**Datei:** `lib/rules/derived/kampfbasis_rules.dart`

| Wert | Formel |
|---|---|
| AT (Basis) | `round((MU + GE + KK) / 5) + at-Mod` |
| PA (Basis) | `round((INN + GE + KK) / 5) + pa-Mod` |
| FK (Basis) | `round((INN + FF + KK) / 5) + fk-Mod` |
| GS | `8` (Basis); +1 wenn GE > 15; −1 wenn GE < 11; + gs-Mod; bei Axxeleratus wird der Endwert verdoppelt |

### 4.3 Initiative

**Datei:** `lib/rules/derived/ini_rules.dart`

| Wert | Formel |
|---|---|
| IniBase | `round((MU + MU + INN + GE) / 5) + iniBase-Mod` |
| IniGe | `truncate((GE − geBase) / geThreshold)` (Waffen-Komponente) |
| IniDiceCount | `1` (normal) oder `2` (Klingentänzer) |
| IniParadeMod | `max(0, truncate((kampfIni − 11) / 10))` |

Bei aktivem Axxeleratus wird der berechnete `IniBase`-Anteil in der
Heldeninitiative verdoppelt. Der Ini-Wurf selbst bleibt unverändert.

Sonderfertigkeits-Boni auf IniBase:

| Sonderfertigkeit | Bonus |
|---|---|
| Kampfreflexe | +4 |
| Kampfgespür | +2 |

### 4.4 Rüstung & Behinderung

**Datei:** `lib/rules/derived/ruestung_be_rules.dart`

| Wert | Berechnung |
|---|---|
| `rsTotal` | Summe `rs` aller aktiven `ArmorPiece` + `rs`-Mod + `armatrutzRsBonus` |
| `armatrutzRsBonus` | erzauberter RS eines laufenden `Armatrutz` (siehe 4.5b) |
| `beTotalRaw` | Summe `be` aller aktiven `ArmorPiece` |
| `rgReduction` | 0 / 1 / 2 je nach Training-Level und aktiven RG1-Stücken |
| `beKampf` | `max(0, beTotalRaw − rgReduction)` |
| `EBE` | `max(0, −beKampf − beMod)` (negative BE invertiert) |
| AT-EBE-Anteil | `truncate(EBE / 2)` |
| PA-EBE-Anteil | `ceil(EBE / 2)` (größere Hälfte bei ungeradem EBE) |

BE-Modifikatoren aus Talenten: Notation `"-"`, `"-N"`, `"xN"`.

### 4.4a Meta-Talente

**Datei:** `lib/rules/derived/meta_talent_rules.dart`

| Wert | Berechnung |
|---|---|
| Roh-TaW | kaufmaennisch gerundeter Mittelwert aller `HeroTalentEntry.talentValue` der Komponenten |
| `eBE` | `computeTalentEbe(baseBe, beRule)` mit der BE-Regel des Meta-Talents |
| `TaW*` | `Roh-TaW + eBE` |
| `max TaW` | bestehende Talent-Maximum-Logik ueber die drei konfigurierten Eigenschaften |

Kampftalente duerfen als Komponenten referenziert werden; dabei zaehlt nur
deren `talentValue`, nicht `AT` oder `PA`.
Im Talente-Workspace werden Meta-Talente analog zu normalen Talenten als
oeffnende Namenslinks mit Detaildialog und eigener Talentprobe dargestellt.

### 4.5 Ausweichen

**Datei:** `lib/rules/derived/ausweichen_rules.dart`

```
sfAusweichenBonus = 3×AusweichenI + 3×AusweichenII + 3×AusweichenIII
akrobatikBonus    = max(0, floor((AkrobatikTaW − 9) / 3))
ausweichenMod     = manualMod + Flink − Behäbig
Ausweichen        = max(0, PABasis + sfBonus + akrobatikBonus + ausweichenMod − beKampf)
```

Bei aktivem Axxeleratus erhoeht sich `PABasis` um `+2` und Ausweichen
zusaetzlich um weitere `+2`.

### 4.5a Axxeleratus

**Datei:** `lib/rules/derived/magic_rules.dart`

| Effekt | Wirkung |
|---|---|
| TP | `+2` auf Nahkampfangriffe |
| PA-Basis | `+2` |
| Ausweichen | weiterer Bonus `+2` |
| Helden-INI | `IniBase` wird effektiv verdoppelt |
| GS | finaler GS-Wert wird verdoppelt |
| Kampf-SF | aktiviert temporaer `Schnellziehen`, `Schnellladen (Bogen)` und `Schnellladen (Armbrust)` |
| Anzeige | `Abwehr des beschleunigten Nahkampfangriffs: Automatische Finte +2` |

### 4.5b Armatrutz

**Datei:** `lib/rules/derived/armatrutz_rules.dart`

Der Armatrutz (Liber Cantiones S. 28) legt dem Ziel eine rein magische
Ruestung auf.

| Wert | Berechnung |
|---|---|
| `armatrutzRsBonus` | erzauberter RS aus `ActiveSpellEffectDetail.amount`; `0`, wenn der Effekt aus oder seine Wirkungsdauer abgelaufen ist |
| `rsTotal` | getragener RS + `armatrutzRsBonus` |
| Behinderung | unveraendert — die magische Ruestung erzeugt bewusst keine BE |
| AsP-Kosten | `max(4, RS² − ZfP*/2)`, halbe ZfP* abgerundet (`computeArmatrutzAspCost`) |

Die AsP-Kosten sind ein reiner Anzeigehinweis in der Eingabemaske; abgezogen
wird nichts automatisch, weil Zeitpunkt und Erfolg des Zaubers am Spieltisch
entschieden werden.

### 4.5c Wirkungsdauer aktiver Zaubereffekte

**Dateien:** `lib/domain/spell_duration.dart`,
`lib/rules/derived/spell_duration_rules.dart`,
`lib/rules/derived/active_spell_rules.dart`

Jeder aktive Zaubereffekt (`importantActiveSpellEffects`) kann eine optionale
Wirkungsdauer tragen. `SpellDuration` haelt Gesamtdauer, Restdauer und
Zeiteinheit (`Aktionen`, `Kampfrunden`, `Spielrunden`, `Minuten`, `Stunden`,
`Tage`, `permanent`) getrennt, damit am Spieltisch heruntergezaehlt werden
kann, ohne die Ausgangsdauer zu verlieren.

- Einheiten werden **nicht** ineinander umgerechnet: Eine Spielrunde geht nur
  ausserhalb des Kampfes sinnvoll in Kampfrunden auf.
- Der Countdown ist manuell (`advanceSpellDuration`, `resetSpellDuration`);
  es laeuft keine Uhr mit.
- Abgelaufene Effekte werden **nicht** automatisch deaktiviert, sondern nur
  als abgelaufen angezeigt (`expiredActiveSpellEffects`). Ausnahme ist der
  Armatrutz: Sein RS-Bonus faellt bei abgelaufener Wirkungsdauer weg, weil ein
  stillschweigend weiterlaufender Ruestungsbonus die Kampfwerte verfaelschen
  wuerde.
- Persistiert wird in `HeroState.activeSpellEffects.effectDetails`; aeltere
  Staende ohne dieses Feld bleiben lesbar.

### 4.6 Waffe, Fernkampf-AT, Schaden und Kampfmeisterschaften

**Dateien:** `lib/rules/derived/combat_rules.dart`,
`lib/rules/derived/fernkampf_rules.dart`,
`lib/rules/derived/fernkampf_ladezeit_rules.dart`,
`lib/rules/derived/combat_mastery_rules.dart`,
`lib/rules/derived/maneuver_rules.dart`,
`lib/rules/derived/two_weapon_combat_rules.dart`

```
tpKk = truncate((KK − kkBase) / kkThreshold)   # Kraftbonus auf TP
tpExpression = "NW6" oder "NW6±M"
```

**Fernkampf-Formel:**

```
at = fkBasis
   + talentAt
   + wmAt
   + atEbePart
   + spezialisierung
   + projectileAtMod
   + manualAtMod
```

Dabei gilt:
- `spezialisierung = +2`, wenn eine passende Fernkampf-Spezialisierung auf den
  aktuellen Waffentyp greift.
- `eBE` geht bei Fernkampf voll auf `AT`, nicht nur mit dem halben
  Nahkampf-AT-Anteil.
- Die aktive Distanzstufe beeinflusst nur `TP`.
- Das aktive Geschoss beeinflusst `TP`, `INI` und `AT`.
- `reloadTime` wird fuer Boegen und Armbrueste ueber
  `lib/rules/derived/fernkampf_ladezeit_rules.dart` als effektive Ladezeit
  berechnet und als `1 Aktion` / `N Aktionen` angezeigt.
- Beide Hände liefern `computeRangedReloadTime` die effektive Rüstungs-BE nach
  Rüstungsgewöhnung (`beKampf`, keine talentbezogene eBE). Schnellladen wirkt
  bis BE 4; bei BE 5 ist auch die durch Axxeleratus verliehene Wirkung inaktiv.
  Der zusätzliche Axxeleratus-Kombinationsbonus setzt eine wirksame besessene
  Schnellladen-SF voraus. Schnellziehen bleibt von dieser Ladegrenze unabhängig.
- `Schnellladen (Bogen)` verkuerzt die Ladezeit um `1`; bei bereits besessener
  SF reduziert Axxeleratus die Ladezeit um einen weiteren Punkt.
- `Schnellladen (Armbrust)` setzt die Ladezeit auf `3/4` der Basis-
  Ladezeit, echt gerundet (4 → 3, 8 → 6, 5 → 4); bei bereits besessener SF reduziert Axxeleratus
  anschliessend um einen weiteren Punkt.
- Gefecht-Ladehandlungen verwenden dieselbe aktuelle effektive Vorschau
  einschließlich Waffenmeister. Bezahlte reguläre Aktionen bleiben erhalten;
  Restdauer ist `max(0, aktuelle Ladezeit - bezahlt)`. Der vollständig bezahlte
  Abschluss verlangt keine weitere Marke. Ladung ist flüchtig pro Waffen-ID;
  Waffen-/Geschossprofiländerungen machen den Ladestand unbekannt und verlangen
  erneute konkrete Bestätigung oder Vorbereitung. Eine frische Bestätigung im
  Schussdialog gilt nur für das aktuelle Profil; passend bekannte Entladung
  kann nicht übergangen werden.
- Der vorbereitete Schuss bindet den ursprünglichen Auftrag einschließlich
  Waffe, Geschoss, Zielkontakt und Ansagen. Die abschließende Prüfung und Probe
  verwenden aktuelle DK und Sitzungskontext; ein Probeabbruch erhält diese
  aktuellen Werte und den bezahlten ursprünglichen Auftrag. Auch Vorbereitung
  mit einer PA-Marke erhält den Sitzungskontext.
- Gebundener FK-Schaden ersetzt in beiden Händen ausschließlich den bereits
  enthaltenen TP-Anteil des Vorschau-Distanzbands durch das numerisch aufgelöste
  Band der tatsächlichen Schussentfernung. Ansagebonus und übrige Vorschauanteile
  wirken einmal. Bei unbekanntem Band klassifiziert der Ergebnisbinder Schaden
  als manuell und gibt keinen automatischen Schadensrequest aus.
- `maneuver_rules.dart` normalisiert Manoever-Namen und UI-Texte auf stabile
  IDs, damit Kampfmeisterschaften dieselben Referenzen wie Katalog und UI
  nutzen koennen.
- `two_weapon_combat_rules.dart` leitet die Mali der falschen Hand
  (`AT/PA -9`, `-6`, `-3` oder `0`) sowie die verfuegbaren
  beidhÃ¤ndigen Aktionsoptionen fuer zweite Waffe, Parierwaffe und
  `Doppelangriff` ab.
- `combat_mastery_rules.dart` bewertet Punktbudget und Voraussetzungen,
  prueft die Anwendbarkeit fuer Hauptwaffe, Schild oder Parierwaffe und leitet
  automatisch wirksame Modifikatoren fuer die Kampfvorschau ab.
- `unarmed_style_rules.dart` wertet aktive waffenlose Kampfstile aus dem
  Katalog aus, schaltet deren Manoever frei und rechnet feste Stilboni auf
  `Raufen`/`Ringen` mit einem gemeinsamen Limit von `+2 AT` und `+2 PA` ein.

**Spezialisierungs-Boni:**

| Art | AT-Bonus | PA-Bonus |
|---|---|---|
| Nahkampf | +1 | +1 |
| Fernkampf | +2 | — |

**Schildhand/Parierwaffe PA-Boni:**

| Modus | Bedingung | PA-Bonus |
|---|---|---|
| Linkhand | immer | `basePaMod + 1` |
| Schild + Schildkampf II | — | `basePaMod + 5` |
| Schild + Schildkampf I | — | `basePaMod + 3` |
| Parierwaffe + PW II | — | `basePaMod + 2` |
| Parierwaffe + PW I | — | `basePaMod − 1` |

`CombatPreviewStats` liefert für Nahkampf weiterhin `AT`/`PA`; bei
Fernkampfwaffen enthält derselbe Snapshot einen gemeinsamen `AT`, die aktive
Distanzbezeichnung, Ladezeit sowie den selektierten Geschossnamen,
Geschossbestand und dessen Beschreibung. Zusaetzlich enthaelt der Snapshot
die automatisch eingerechneten Kampfmeisterschafts-Modifikatoren, anwendbare
Meisterschaften, strukturierte Manoever-Erleichterungen fuer die UI sowie
feste Boni aktiver waffenloser Kampfstile. Fuer Waffenmeisterschaften enthaelt
der Snapshot explizite AT-/PA-/INI-/TP/KK-/Ladezeit-Anteile, strukturierte
Manoever-Erleichterungen und freigeschaltete Zusatz-Manoever fuer die UI; im
Kampf-Preview wird die aktive Waffenmeisterschaft selbst nur kompakt markiert.
Distanz- und Geschoss-Chips werden dort nur angezeigt, wenn in Haupt- oder
Nebenhand eine Fernkampfwaffe gehalten wird.
Fuer beidhÃ¤ndigen Nahkampf enthaelt der Snapshot ausserdem einen strukturierten
Aktions-Block mit Regelhinweisen, Quellen der Zusatzaktionen und den
kontextbezogenen Zielwerten fuer `Doppelangriff`, Zusatzangriffe und
Zusatzparaden.
Ein TP/KK-Wert von `0/0` wird dabei als bewusste Deaktivierung behandelt; in
diesem Fall entfallen TP/KK- und INI/GE-Berechnungen fuer die Waffe.

### 4.7 Modifier-Parser

**Datei:** `lib/rules/derived/modifier_parser.dart`

Parst Freitext-Felder (`rasseModText`, …) und die frei wirkenden Vor-/Nachteil-
Fragmente (Abschnitt 4.11) in strukturierte Modifikatoren. Katalogisierte
Vor-/Nachteile wirken mit Katalog ueber ihre Katalog-ID, nicht ueber diesen
Parser.

**Syntax:** `CODE+N` oder `CODE−N` (beliebige Groß-/Kleinschreibung)

**Unterstützte Codes:**

| Codes | Zielwert |
|---|---|
| MU, MUT | Eigenschaft Mut |
| KL, KLUGHEIT | Eigenschaft Klugheit |
| INN, IN, INTUITION | Eigenschaft Intuition |
| CH, CHARISMA | Eigenschaft Charisma |
| FF, FINGERFERTIGKEIT | Eigenschaft Fingerfertigkeit |
| GE, GEWANDTHEIT | Eigenschaft Gewandtheit |
| KO, KONSTITUTION | Eigenschaft Konstitution |
| KK, KÖRPERKRAFT | Eigenschaft Körperkraft |
| LEP, LE | Lebenspunkte-Modifikator |
| AU | Ausdauer-Modifikator |
| ASP, AE | Astralpunkte-Modifikator |
| KAP | Karmapunkte-Modifikator |
| MR | Magieresistenz-Modifikator |
| INI | Initiative-Modifikator |
| GS | Geschwindigkeit-Modifikator |
| AUSWEICHEN, AW | Ausweichen-Modifikator |

**Named Tokens:** `Flink` → `hasFlinkFromVorteile = true`;
`Behäbig`/`Behaebig` → `hasBehaebigFromNachteile = true`

**Standard-Vor-/Nachteile:** `lib/rules/derived/standard_stat_modifier_rules.dart`
erkennt in `vorteileText` und `nachteileText` benannte Ressourcenregeln wie
`Hohe Lebenskraft 3`, `Ausdauernd +4`, `Astralmacht: 5`,
`Hohe Magieresistenz (2)`, `Kurzatmig 2`,
`Niedrige Astralenergie 3` und `Niedrige Magieresistenz 1`. Die Zahl ist immer
der direkte Wirkungspunktwert, nicht der GP-Betrag. LeP, Au und AsP werden bei
6 Punkten gekappt, MR bei 3 Punkten. Ein bekannter Name ohne Zahl erzeugt
keinen Effekt und bleibt als unbekanntes Fragment sichtbar.

Trenner: Zeilenumbrüche, Kommas, Semikolons. Nicht erkannte Fragmente landen in
`unknownFragments` (→ `HeroSheet.unknownModifierFragments` für UI-Hinweis).
Beim Speichern werden katalogbekannte Vor-/Nachteil-Fragmente herausgefiltert,
damit normale Auswahlen wie `Flink` oder `Astralmacht 3` nicht als
Parser-Warnung erscheinen. Freie Alttexte bleiben sichtbar, wenn sie keiner
bekannten Katalogauswahl entsprechen.

**Performance:** LRU-Cache mit 512 Einträgen für häufig wiederholte Texte.

### 4.8 AP & Level

**Datei:** `lib/rules/derived/ap_level_rules.dart`

```
level         = floor(sqrt(apSpent / 50 + 0.25) + 0.5)
apAvailable   = max(0, apTotal − apSpent)
```

**Steigerungsrunden und manuelle Korrekturen (September 2026)**

Die Kategorie **Eigenschaften** ergänzt einen Basiswertvergleich vom Beginn
der Runde zur gültigen Vorschau. Der optionale `previewBuilder` des
`showSteigerungsDialog` erhält den normalisierten Zielwert und zeigt dort
zusätzlich die Wirkung der gerade gewählten Eigenschaftserhöhung.
`advancement_impact_rules.dart` berechnet die Vergleiche, während
`advancement_attribute_rules.dart` die effektive Zielwertübertragung mit dem
Replay teilt. `hero_stat_inputs.dart` wird auch vom `heroComputedProvider`
verwendet: Inventar, permanente und temporäre Modifikatoren sowie Wunden
fließen dadurch identisch in die Basiswertsummen ein. Beide Vergleichsseiten
verwenden denselben Laufzeitzustand. AsP/KaP folgen der Ressourcenfreischaltung.

Die Dialogliste enthält bereits aktivierte Talente, Kampftalente und Zauber
am bisherigen Limit nur dann, wenn ihr neues Maximum über dem aktuellen Wert
liegt und keine andere regeltechnische Sperre verbleibt. Die bestehenden
Optionsregeln bestimmen die Grenzen einschließlich Begabung und epischer
Sonderfälle. Feste Sprach-/Schriftgrenzen ändern sich nicht. Die Auskunft prüft
keine AP-Verfügbarkeit und erzeugt keine Folgeeinträge oder Persistenzänderungen.

Der Workspace bietet **Steigern** unabhängig von **Bearbeiten** an. Die normalen
Bearbeitungsansichten ändern Werte und Einträge manuell ohne automatische
AP-Buchung. Die eigene Steigerungsoberfläche unter `ui/screens/advancement/`
verwendet die bestehenden Kosten- und Erwerbsdialoge für geplante Änderungen.

`AdvancementSessionController` hält je Held eine feste Basis, den Katalog dieser
Runde und eine Liste von `HeroAdvancementEntry`. Das Regel-Replay unter
`rules/derived/advancement*.dart` baut daraus eine Vorschau einschließlich AP/SE
auf. Der normale Heldenprovider bleibt bis zur Übernahme unverändert.
Entfernen ist nur für Einträge der laufenden Runde erlaubt. Nach jedem Entfernen
wird die Liste erneut geprüft: ungültige Folgeeinträge bleiben mit Begründung
sichtbar und sperren die Übernahme, statt unbemerkt falsch gebucht zu werden.

**Änderungen übernehmen** schreibt den resultierenden Helden mit AP, SE und
`advancementHistory` gemeinsam. Historieneinträge tragen Sitzungs-ID, Zeitpunkt,
Ziel, vorherigen/neuen Wert und Kosten. Frühere Runden sind fest; Bestandshelden
erhalten keine rückwirkend erfundene Historie. Ein leeres Historienfeld wird bei
der JSON-Ausgabe ausgelassen, damit bestehende Sync-Hashes gleich bleiben. Die
Helden-Serialisierung übernimmt Import/Export und Sync.

Die Buchung übernimmt der Ablauf `SteigerungsrundeUebernehmen`
(`lib/ablaeufe/steigerungsrunde_uebernehmen.dart`, ARCH-05); der Controller hält
nur Planung und Sitzungszustand. Vor dem Schreiben wird die Sitzungsbasis mit dem
aktuellen Repository verglichen. `HeroActions.saveHero(expectedContentHash: ...)`
prüft nochmals nach der asynchronen Normalisierung, unmittelbar vor dem Schreiben.
Bei Konflikten oder Speicherfehlern bleibt die Runde erhalten. Die Anzeige nicht
passender Sonderfertigkeiten speichert derselbe Ablauf
(`speichereSfAnzeige`): eingereiht hinter andere Bogenvorgänge, ohne
Normalisierung und bei offener Runde nur auf unveränderter Basis. Die AP- und History-Ansicht erscheint auf breiten Geräten im Inspektor
und mobil im **Detailpanel**. Das Verlassen einer geänderten Runde bietet
Weiterplanen, Verwerfen und bei gültigen Einträgen Übernehmen an.

**Aktive Einträge und Erwerbsblatt (September 2026)**

Der Katalog einer Runde zeigt nur, was der Held **auf dem Bogen führt**.
Maßgeblich ist der Schlüssel in `talents`, `spells`, `sprachen` bzw. `schriften`
— nicht der Wert. Ein eingeblendeter Eintrag mit Wert `null` ist damit
vorhanden; offen sind nur noch seine Aktivierungskosten. `AdvancementOption`
trägt das als `isOwned` für **alle** Arten, nicht mehr nur für
Sonderfertigkeiten:

| `isOwned` | `currentValue` | Bedeutung | Ort | Aktion |
|---|---|---|---|---|
| `false` | `-1` | nicht auf dem Bogen | Erwerbsblatt | Aktivieren |
| `true` | `-1` | eingeblendet, noch nicht aktiviert | Hauptliste | Aktivieren |
| `true` | `>= 0` | aktiviert | Hauptliste | Steigern |

Eigenschaften und Grundwerte besitzt jeder Held; sie sind immer `isOwned` und
erscheinen nie im Erwerbsblatt.

`AdvancementScope` (`rules/derived/advancement_scope_rules.dart`) steuert den
Umfang: `active`, `inactive` oder `all` (Vorgabe). `buildAdvancementOptions`
prüft den Umfang **vor** dem Auflösen, damit ein eingeschränkter Aufruf die
teure Regelauswertung gar nicht erst anstößt; die UI filtert nie selbst über
rund 800 Einträge. `resolveAdvancementOption` behält dagegen seine
uneingeschränkte Semantik — Replay und Auswirkungsvorschau müssen jedes Ziel
auflösen können, ob aktiv oder nicht.

Bei Sonderfertigkeiten zählt zum aktiven Umfang außerdem, was daraus unmittelbar
folgt: die nächste Stufe jeder Kette, von der mindestens eine Stufe erworben ist
(`naechsteKettenstufe`), sowie weitere Varianten mehrfach wählbarer Einträge.
Eine unangetastete Kette gehört zum inaktiven Umfang. Der Fähigkeitenbaum der
Kategorie Sonderfertigkeiten verwendet jedoch `all` und zeigt auch solche
Neuerwerbe direkt an. Der Bestand wird alias-fähig über
`istEintragErworben` und für Kampf-SF über `isCombatSpecialAbilityActive`
ermittelt; mehrfach wählbare Einträge zählen über ihre Varianten, weil ein Held
nur `Geländekunde (Wüste)` führt und nie den Basisnamen.
`unavailableReason == 'Bereits erworben'` bleibt die Sperre, auf die sich
`_validateEntry` verlässt; nur die Karte stellt sie für erworbene Einträge als
Bestandsnachweis („Erworben“, ohne Knopf) statt als Warnung dar. Wer den
Sperrgrund umbaut, muss beide Seiten anfassen.

Der Fähigkeitenbaum (`rules/derived/advancement_skill_tree.dart`) bildet
Sonderfertigkeiten und Manöver samt UND-/ODER-Voraussetzungen ab. Vorstufen aus
Stufenketten werden auch bei der Erwerbsprüfung berücksichtigt. Die Oberfläche
in `advancement_skill_tree_view.dart` und `skill_tree_branch.dart` zeigt Status,
Kategoriefilter, Suche und Erwerbsdetails; Vormerken nutzt die bestehende Sitzung.
`advancement_maneuver_rules.dart` bestimmt Kosten und Voraussetzungen für
`AdvancementKind.maneuver`, gegebenenfalls pro aktivem Kampftalent mit der ID
`manöverId::talentId`. Übernahme ergänzt `activeManeuvers`; der Besitz umfasst
über `learnedManeuverIds` auch Freischaltungen erworbener Kampf-Sonderfertigkeiten.

Der Baum-Detaildialog ergänzt die Erwerbskarte durch `advancement_ability_details.dart`:
Beschreibung, Langtext, Originalvoraussetzungen, Verbreitung, Varianten samt
Kosten, Kampfboni, freigeschaltete Manöver und Quellen sind bei vorhandenen
Katalogangaben zugänglich. Der adaptive Dialog scrollt lange Inhalte.
Geschützte Texte werden über die bestehende Katalogfreischaltung aufgelöst;
ohne Passwort erscheint der Sperrhinweis. Technische Importmetadaten werden
nicht als Regelinformation ausgegeben.

Das Erwerbsblatt (`ui/screens/advancement/advancement_activation_sheet.dart`)
listet den `inactive`-Umfang einer Kategorie mit Suche, Artfiltern und dem
standardmäßig aktiven Schalter „Nur erwerbbare“. Es **schließt sich selbst** und
gibt das gewählte Ziel zurück; geplant wird erst danach beim Aufrufer über
denselben `_plan`-Pfad wie die Hauptliste. Damit liegt der Planungsdialog nie
über einem Blatt derselben Root-Navigator-Ebene, und die Sitzung wird weiterhin
nur an einer Stelle verändert. Aktivieren und Steigern sind ein Schritt: Der
Steigerungsdialog öffnet mit `aktuellerWert = -1` und freiem Zielwert, die
Kosten des Schritts `-1 → 0` sind die Aktivierungskosten
(`LearnCost.initialStepCost`). Weil eine aktiv-gefilterte Liste sonst lernbare
Ziele verstecken würde, blendet die Hauptliste bei nicht leerem Suchtext eine
Brücke ins Erwerbsblatt ein.

Rituale und Liturgien haben kein `AdvancementKind` und keine Katalogunterstützung;
sie liegen außerhalb des Steigerungsmodus und fehlen in beiden Umfängen. Das ist
keine Lücke der Aktivfilterung.

`AdvancementContext` bündelt Held und Katalog für einen Optionsaufbau und hält
`permanentAttributes`, `ownedAbilityNames` und `requirementContext` als
`late final`. Ohne diese Bündelung baute jede der rund 280 SF-Optionen den
vollständigen Voraussetzungskontext neu auf (ID→Name-Karten über alle Talente
und Zauber plus AT/PA/FK/INI), und jede der rund 800 Optionen liefe erneut durch
`parseModifierTextsForHero`. `resolveAdvancementOptionIn` nimmt den Kontext
entgegen; die Auswirkungsvorschau legt je einen Kontext für beide
Vergleichsstände außerhalb ihrer Schleife an. `advancementOptionsProvider`
(`state/advancement_providers.dart`) memoisiert die Liste je Umfang an der
Sitzung, damit ein Tastenanschlag in der Suche keinen Katalogaufbau auslöst.

**Historischer Hintergrund: AP-Abzug im Bearbeitungsmodus vor der Trennung**

Die folgende Beschreibung dokumentiert die frühere Draft-Delta-Lösung und deren
Fehlerursache; neue Steigerungsaktionen verwenden ausschließlich Sitzungen:

Bestätigte Erwerbs-Dialoge (Sonderfertigkeiten, Manöver, Spezialisierungen)
dürfen ihre AP-Kosten **nicht** direkt in das Feld `_latestHero` eines Tabs
schreiben. Talente-, Magie- und Kampf-Tab lesen den Helden in `build()`
unconditional aus `heroByIdProvider` und überschreiben `_latestHero` bei jedem
Rebuild — und ein Rebuild passiert unmittelbar nach dem Erwerb, weil
`_markFieldChanged()` den Dirty-Zustand umlegt. Der Erwerb landete dann in der
Liste, der AP-Abzug ging verloren.

Stattdessen summiert jeder Tab die bestätigten Kosten in einem
`_draftApSpentDelta` (wie die anderen `_draftXxx`-Felder), das erst beim
Speichern auf den dann aktuellen `hero.apSpent` addiert und danach
zurückgesetzt wird; `_syncDraftFromHero` setzt es beim Verwerfen ebenfalls auf
`0`. Erwerbs-Dialoge im selben Bearbeitungsvorgang bekommen ihre verfügbaren AP
über `_verfuegbareApImDraft(hero)`, also abzüglich des noch nicht gespeicherten
Deltas.

Sofort speichernde Aktionen (Steigerungs-Dialoge) sind davon nicht betroffen:
sie sind nur bei `isEditing && !isDirty` erreichbar, es kann also kein Delta
offen sein.

### 4.9 Erwerbsvoraussetzungen und Stufenketten

**Dateien:** `lib/catalog/special_ability_requirement.dart`,
`lib/catalog/special_ability_entry.dart`,
`lib/rules/derived/requirement_evaluation_rules.dart`,
`lib/rules/derived/hero_requirement_context.dart`,
`lib/rules/derived/special_ability_chain_rules.dart`,
`lib/rules/derived/combat_special_ability_state.dart`,
`lib/rules/derived/tradition_rules.dart`

Katalogeinträge tragen neben dem Freitext `voraussetzungen` optional den
maschinenlesbaren Block `voraussetzungen_struktur`. Beide stehen bewusst
nebeneinander: Der Freitext bleibt die Regelquelle und wird unverändert
angezeigt, der Strukturblock erlaubt zusätzlich die Prüfung gegen den Helden.
Einträge ohne Strukturblock — etwa aus Hausregel-Paketen — verhalten sich wie
zuvor.

Gepflegt ist der Block für magische, allgemeine, Kampf- und karmale
Sonderfertigkeiten sowie Manöver. Nicht modellierte karmale Voraussetzungen
(Liturgiekenntnis/LkW, Gottheit, Entrückungsstufe) bleiben `hinweis` zur
manuellen Prüfung; Eigenschaften und SF-Abhängigkeiten sind strukturiert prüfbar.

Getragen wird beides — Voraussetzungen wie Ketten — von der schmalen
Schnittstelle `SpecialAbilityEntry`, die `SpecialAbilityDef` (allgemein,
magisch, karmal), `CombatSpecialAbilityDef` und `ManeuverDef` implementieren. Damit
teilen sich die Katalogfamilien die Voraussetzungsprüfung und Erwerbsdarstellung, ohne dass
ihre übrigen Felder (Varianten hier, Manöver-Freischaltungen dort)
zusammengelegt werden müssten.

**Schema einer Bedingung:**

```jsonc
"voraussetzungen_struktur": [
  { "art": "eigenschaft", "code": "MU", "min": 15 },
  { "art": "sonderfertigkeit", "name": "Eiserner Wille", "stufe": 1 },
  { "art": "oder", "bedingungen": [
      { "art": "eigenschaft", "code": "KL", "min": 20 },
      { "art": "eigenschaft", "code": "IN", "min": 20 }
  ]}
]
```

| `art` | Felder | Bedeutung |
|---|---|---|
| `eigenschaft` | `code`, `min` | Mindestwert einer Eigenschaft |
| `leiteigenschaft` | `min` | Mindestwert der Leiteigenschaft der Tradition |
| `sonderfertigkeit` | `name`, `stufe?` | Andere SF, optional ab Kettenstufe |
| `zauber` | `name`, `min` | Mindest-ZfW |
| `talent` | `name`, `min` | Mindest-TaW |
| `ritualkenntnis` | `name?`, `min?` | Ritualkenntnis, optional mit RkW |
| `tradition` | `namen[]` | Eine von mehreren Traditionen |
| `merkmalskenntnis` | `name?` | Merkmal; ohne Namen genügt irgendeines |
| `vorteil` | `name` | Erforderlicher Vorteil |
| `nachteil` | `name` | Nachteil, den der Held haben **muss** |
| `nachteil_verboten` | `name` | Nachteil, den der Held nicht haben darf |
| `rasse` | `namen[]` | Eine von mehreren Rassen |
| `rasse_verboten` | `namen[]` | Rasse, die der Held nicht sein darf |
| `basiswert` | `code`, `min` | Abgeleiteter Kampfwert: `AT`, `PA`, `FK`, `INI` |
| `manoever` | `name` | Erlerntes Manöver aus `manoever.json` |
| `waffenmeister` | `name?` | Waffenmeisterschaft; ohne Namen genügt irgendeine |
| `spruchzauberer` | – | Mindestens eine Repräsentation |
| `oder` / `und` | `bedingungen[]` | Verknüpfung; `und` nur als Oder-Zweig |
| `hinweis` | `text` | Nicht prüfbarer Regeltext |

`manoever` ist eine eigene Art, weil Manöver in `manoever.json` stehen und
keine Sonderfertigkeiten sind — `Klingenwand` oder `Sturmangriff` würden über
`sonderfertigkeit` nie gefunden. `waffenmeister` ebenso: Waffenmeisterschaften
liegen in `combatConfig.waffenmeisterschaften` und tauchen gar nicht unter den
SF-Namen auf. Geprüft wird gegen das Kampftalent **und** die freie
Gattungsangabe `weaponType` — nur so bleibt „Waffenmeister (Schild)" erfüllbar,
denn für Schilde gibt es kein eigenes Kampftalent.

`hinweis` ist der Auffangtyp und zählt nie als unerfüllt — Regeltexte wie
„sechs Monate Kontemplation" bleiben sichtbar, ohne etwas zu blockieren.
Unbekannte Arten werden beim Laden zu `RequirementArt.unbekannt` und ebenfalls
wie ein Hinweis behandelt.

**Katalogtests** decken die fehleranfällige Stelle ab: Ein Tippfehler in einem
referenzierten Namen sieht im JSON richtig aus, findet aber nie sein Ziel und
fiele sonst erst im Betrieb als stillschweigend unerfüllte Bedingung auf. Die
Tests unter `test/catalog/` (`magic_`, `general_`, `combat_…_catalog_test.dart`
plus der gemeinsame Helfer `catalog_reference_names.dart`) lösen deshalb jede
Referenz gegen ihren Bezugskatalog auf: Talente gegen `talente.json` und
`waffentalente.json`, Manöver gegen `manoever.json`, Vor-/Nachteile und Zauber
gegen ihre Dateien.

**Auswertung:** `buildHeroRequirementContext(hero, catalog: …, mods: …)`
sammelt Eigenschaften, erworbene Sonderfertigkeiten, Zauber- und Talentwerte
(der Katalog löst dafür IDs in Klarnamen auf), Ritualkenntnisse, Traditionen,
Merkmale, Vor-/Nachteile, Rasse, die Kampf-Basiswerte, erlernte Manöver und
Waffenmeisterschaften. `evaluateRequirements` liefert daraus je Bedingung einen
`RequirementCheckResult` mit Soll- und Ist-Text. Ein nicht erfüllter Punkt
**sperrt den Erwerb nicht**: Die UI zeigt die Checkliste und verlangt eine
bewusste Bestätigung („Trotzdem erwerben — Meisterentscheid"), damit Hausregeln
möglich bleiben.

In die Basiswerte fließen nur dauerhafte Modifikatoren ein (`persistentMods`
plus benannte Stat-Mods). Temporäre Zaubereffekte wie Attributo oder
Axxeleratus bleiben außen vor — ein laufender Zauber darf keinen dauerhaften
Erwerb rechtfertigen.

Welche Kampf-SF ein Held besitzt, beantwortet
`isCombatSpecialAbilityActive(config, id)`. Das ist nötig, weil ein Teil der
Kampf-SF nicht unter `activeCombatSpecialAbilityIds` steht, sondern in eigenen
Feldern (`ausweichenI`, `kampfreflexe`, `globalArmorTrainingLevel`) — ohne
diese Auflösung erschiene `Ausweichen II` selbst dann gesperrt, wenn
`Ausweichen I` längst aktiv ist.

**Stufenketten:** Aufeinander aufbauende Sonderfertigkeiten teilen sich eine
`kette` mit gemeinsamer `id` und aufsteigender `stufe`. Jede Stufe bleibt ein
eigener Katalogeintrag, weil die Regelwerke je Stufe eigene AP-Kosten und
Voraussetzungen vergeben. `alias_namen` hält frühere Schreibweisen fest, damit
Helden mit einem alten Sammeleintrag (`Eiserner Wille I / II`) weiterhin als
Besitzer der ersten Stufe erkannt werden.

Im Kampfkatalog sind das `ausweichen` (I–III), `ruestungsgewoehnung` (I–IV),
`schildkampf`, `parierwaffen` und `beidhaendiger_kampf` (je I–II). Der
Kampfregeln-Tab rendert seine Gruppen einzeln; eine Kette, deren Stufen in
verschiedenen Gruppen landen, würde dort zerfallen. `Rüstungsgewöhnung IV` ist
episch, trägt aber `kampfTyp: allgemein` und bleibt damit bei den Stufen I–III
— ein Test in `combat_special_ability_catalog_test.dart` hält das fest.

**Bekannte Regelwerks-Lücke:** *Zweihandmeister* und die *Fortgeschrittene
Monsterparade* verlangen die SF `Zweihändiger Kampf III`, für die es weder
unter den Kampf-SF noch unter den Manövern einen Katalogeintrag gibt. Solange
er fehlt, bleibt die Forderung ein sichtbarer `hinweis` statt einer falschen
Absage.

**Traditionen und Leiteigenschaft:** `tradition_rules.dart` enthält die Tabelle
aus *Wege der Zauberei* S. 19 (Klugheit bzw. Intuition je Tradition). Die
Traditionen eines Helden sind die Vereinigung aus `representationen` und den
Namen seiner Ritualkategorien — Derwische, Zibiljas, Zaubertänzer und Schamanen
haben laut Regelwerk gar keine Repräsentation und wären sonst von ihren eigenen
Traditionsritualen ausgesperrt. Trägt eine Repräsentation mehrere Traditionen
(nur die geodische: Herr der Erde → KL, Diener Sumus → IN), hält
`HeroSheet.repraesentationsTraditionen` die getroffene Wahl fest.

---

### 4.10 Auswahllisten und Eigenschaftswirkung bei Vor-/Nachteilen

**Dateien:** `lib/catalog/hero_trait_def.dart`,
`lib/catalog/hero_trait_choices.dart`, `lib/catalog/hero_trait_text.dart`,
`lib/rules/derived/attribute_trait_rules.dart`,
`lib/rules/derived/modifier_fragment_text.dart`,
`lib/rules/derived/attribute_start_rules.dart`

**Katalogschema.** Ein Vor-/Nachteil mit `{choice}` im `selectionTemplate`
traegt vier optionale Felder:

| Feld | Bedeutung |
|---|---|
| `choiceLabel` | Beschriftung des Auswahlfelds (`Sinn`, `Eigenschaft`, `Geltungsbereich`). Leer = `Spezialisierung` |
| `choices` | Feste Auswahlliste, Reihenfolge bleibt erhalten |
| `choiceSource` | Katalogabgeleitete Liste, siehe unten |
| `choiceFreeText` | Ob zusaetzlich freie Eingabe erlaubt ist (Default `true`) |

`resolveTraitChoices(trait, catalog)` fuehrt beides zusammen: feste `choices`
zuerst, danach die aufgeloeste Quelle alphabetisch, dedupliziert. Bekannte
Quellen stehen in `kKnownTraitChoiceSources`: `eigenschaften`, `talente`,
`talente_handwerk`, `talente_kampf_koerper`, `talente_sonstige`,
`talentgruppen`, `talentgruppen_kampf_koerper`, `talentgruppen_sonstige`,
`zauber`, `rituale`, `merkmale`, `schlechte_eigenschaften`, `sprachen`,
`schriften`.

Zwei Quellen sind nicht offensichtlich: `rituale` flacht die
Variantengruppen der Kategorie `Traditionsrituale` ab (Einzelrituale haben
keinen eigenen Katalog), und `schlechte_eigenschaften` liest die Nachteile
mit Marker `SE` — Platzhalter-Eintraege wie `Angst vor [...]` bleiben
draussen. `test/catalog/trait_choice_catalog_test.dart` loest jede Quelle
gegen den echten Katalog auf; ein Tippfehler faellt sonst erst im Betrieb
auf, und dort nur als leeres Dropdown.

**Speicherformat.** Strukturiert in `HeroSheet.vorteilEintraege` /
`nachteilEintraege`, die Texte sind deren Projektion (Abschnitt 4.11).
`parseTraitFragmentParts` ist die Umkehrung von
`buildHeroTraitSelectionText` und liefert Auswahl **und** Wert. Eine
Klammergruppe, die nur `{choice}` enthaelt, ist beim Zurueckparsen optional
und wird beim Bauen entfernt, wenn die Auswahl leer bleibt — sonst haette
das erweiterte Template `Guter Ruf {value} ({choice})` Bestandsfragmente wie
`Guter Ruf 4` unlesbar gemacht. `mergeHeroTraitFragment` fasst einen zweiten
Erwerb derselben Auswahl zum summierten Wert zusammen, statt ihn wie
`serializeHeroTraitFragments` still zu verwerfen.

**Herausragende Eigenschaft.** Der einzige Vor-/Nachteil mit einer
Eigenschaft als Wirkungsziel (WdH S. 253). Fragmentform
`<Name> <Eigenschaft> [<Wert>]`, geparst von
`parseAttributeTraitFragment`. Der Modifikator landet in **zwei**
Akkumulatoren von `parseModifierTexts`:

- `attributeMods` — wirkt wie ein `KK+2`-Fragment auf den aktuellen Wert.
- `startAttributeMods` — hebt zusaetzlich den Startwert und damit ueber
  `ceil(start * 1.5)` das Maximum.

Freie `CODE+N`-Fragmente aus Vor-/Nachteilen fliessen **nicht** in
`startAttributeMods`: die beschreiben laufende Effekte, keine
Generierungswerte. Rasse, Kultur und Profession dagegen schon
(`contributesToStartAttributes`).

Die Eintragskonvention ist damit: **die Eigenschaft ohne den Bonus
eintragen**, die App rechnet ihn oben drauf. Buchbeispiel Thorwaler mit
Rohstart KK 14, `rasseModText: 'KK+1'` und `Herausragende Eigenschaft KK 2`
ergibt Startwert 17, aktuellen Wert 17 und Maximum 26.

**Startwerte haben genau einen Einstiegspunkt.**
`computeHeroEffectiveStartAttributes(hero)` und
`computeHeroAttributeMaximums(hero)` binden die Basis fest an
`rawStartAttributes`. Das ist kein Stilentscheid: `startAttributes` traegt
bereits das Ergebnis dieser Rechnung, und der Steigerungsdialog hat es
frueher ein zweites Mal modifiziert — Herkunftsmods wurden doppelt addiert
und der Dialog erlaubte einen Steigerungsschritt zu viel.

**Steigerungsdialog auf Effektivebene.** `hero.attributes` ist die Rohspalte,
Startwert und Maximum liegen eine Ebene darueber. `_startAttributeDelta`
holt genau die Modifikatoren, die auch das Maximum speisen (Herkunft plus
Herausragende Eigenschaft), rechnet sie fuer den Dialog auf und beim
Speichern wieder ab. Benannte `attributeModifiers` und freie Textmods
bleiben draussen — das sind situative Boni, keine erkaufte Progression.

**Bestandshelden.** `pendingAttributeTraitNotices(hero)` meldet die neu
wirksamen Boni, solange `hero.schemaVersion < 28`. Bewusst **kein** stiller
Wertumbau: ob der Punkt schon im eingetragenen Wert steckt, weiss nur der
Nutzer. Der Hinweis steht in der Uebersicht und verschwindet erst nach
ausdruecklicher Quittierung („Verstanden – Werte geprueft"), die
`schemaVersion` auf 28 hebt.

### 4.11 Strukturierte Vor- und Nachteile (ARCH-02)

**Dateien:** `lib/domain/hero_merkmal.dart`,
`lib/catalog/hero_trait_effect.dart`,
`lib/rules/derived/hero_merkmal_zuordnung_rules.dart`,
`lib/rules/derived/hero_merkmal_wirkung_rules.dart`,
`lib/ui/screens/hero_overview/hero_overview_traits_section.dart`,
`lib/ui/screens/hero_overview/hero_overview_trait_dialogs.dart`

**Modell.** `HeroMerkmal` traegt `katalogId` (leer = freier Eintrag), `wert`,
`auswahl`, `text` (sein Fragment in der Projektion), `kandidatenIds`
(mehrdeutiger Alttext) und `zuordnung` (`katalog`, `migration`, `frei`), dazu
wie jedes verschachtelte Modell `unbekannteFelder`/`unbekannteEnumWerte`.

**Die Liste fuehrt.** Ist `vorteilEintraege` belegt, gilt sie;
`vorteileText` ist ihre Projektion (`projiziereMerkmalText`). Die
veroeffentlichte App kennt nur den Text. Aendert eine aeltere Version ihn,
erkennt `gleicheMerkmaleAb` die Abweichung (Fragmentmengen nach
`splitHeroTraitText`, Trennzeichen und Reihenfolge zaehlen nicht). Die Liste
bleibt dann wirksam, nichts wird still uebernommen oder verworfen. Die
Uebersicht zeigt die Abweichung und bietet „Geaenderten Text uebernehmen“
(`uebernimmMerkmalText`, bestehende Zuordnungen bleiben) oder „Liste
behalten“ an. Bis dahin ist das Bearbeiten gesperrt, und `saveHero` laesst
Liste und Text unveraendert. Verwirft eine aeltere Version die Liste ganz,
ist der Held wieder ein Bestandsheld und wird neu migriert.

**Migration.** Bestandshelden laden unveraendert (Hash-Pins bleiben), die
Regeln migrieren zur Laufzeit. Erst `saveHero` schreibt die Liste
(`merkmaleZumSpeichern`), und nur mit geladenem Katalog; gewartet wird darauf
nicht. `zerlegeMerkmalText` fuegt durch Komma getrennte Teile wieder
zusammen, wenn sie gemeinsam ein Template mit Komma treffen (`Adlig, Adliges
Erbe`). `ordneMerkmalZu` vergleicht ohne Gross-/Kleinschreibung, erlaubt ein
fehlendes abschliessendes `{value}` und roemische Stufen und beachtet feste
Auswahllisten. Doppelpunkte gelten wie im Modifikator-Parser als Trenner
(`Herausragende Eigenschaft: Gewandtheit: 1`), und eine ausgeschriebene
Eigenschaft wird als Kuerzel gespeichert (`GE`). Ein Template ohne
Platzhalter schlaegt eines mit. Teilen sich mehrere Eintraege ein Template
(`Begabung für {choice}` gibt es fuenfmal), gewinnen die, deren aufgeloeste
Auswahlliste (`resolveTraitChoices`, gemerkt von `MerkmalKatalog.von`) die
Auswahl fuehrt: „Begabung für Abrichten“ ist dann das Talent, „Begabung für
Objekt“ das Merkmal. Ohne diese Bestaetigung wird nicht geraten: Der Eintrag
bleibt frei, nennt seine Kandidaten und laesst sich in der Uebersicht
zuordnen. Bereits gespeicherte Kandidaten bleiben unangetastet. Die
Migration ist deterministisch und ein Fixpunkt.

**Wirkung.** `werteMerkmaleAus(hero, catalog:)` loest je Held und Katalog
einmal auf (gemerkt per `Expando`). Katalogisierte Eintraege wirken ueber
die `wirkungen` ihres Katalogeintrags, gefunden ueber die Katalog-ID. Freie
Eintraege und solche mit unbekannter ID laufen als `freieVorteile`/
`freieNachteile` durch den bisherigen Textparser. Jedes Fragment nimmt genau
einen der beiden Wege. Umgestellt sind `parseModifierTextsForHero`,
Wundschwellenstufen (`merkmalBonus`), Rast (`collectRestAbilities`),
Ressourcenaktivierung, Quellenaufschluesselung, Startwerte/Maxima und
Erwerbsvoraussetzungen (aktueller Katalogname **und** gespeicherter Text).
Ohne Katalog rechnen alle Regeln ueber den Text der Liste. Fuer jeden
unveraendert benannten Katalogeintrag ergibt das dasselbe; der
Aequivalenztest in `test/rules/hero_merkmal_rules_test.dart` prueft jeden
wirkenden Eintrag ueber alle Werte und Auswahlen. Katalogabhaengig ist nur
die Umbenennungsfestigkeit. Damit kein Aufrufer den Katalog vergisst,
verlangen die Einstiegsfunktionen (`parseModifierTextsForHero`,
`computeEffectiveAttributes`, `computeHeroResourceActivation`,
`collectRestAbilities`, Startwerte/Maxima, `computeModifierSourceBreakdown`,
`computeHeroStatInputs`, `applyAdvancementAttributeValue`)
`required RulesCatalog? catalog`; `null` waehlt bewusst den Textweg und
steht in `lib/` nirgends. Option und Replay einer Steigerung muessen
denselben Katalog verwenden, sonst weicht das Startwert-Delta ab.
Die Sichtbarkeit des Magie-Tabs liest den Katalog ueber
`laufenderRegelkatalog` (`workspace_tab_spec.dart`), das das Katalogladen
nicht selbst anstoesst.

**Bearbeitung.** Die Uebersicht haelt einen Entwurf (`null`, solange
unveraendert). Katalogdialog und Wertedialog erzeugen bzw. aendern Eintraege
mit Katalogbezug; `fuegeMerkmalHinzu` summiert gleiche Auswahl desselben
Eintrags. Ein getippter Text wird per `ordneMerkmalZu` zugeordnet.

**UI2-Merkmalsblatt.** `lib/ui2/merkmale/karto_merkmalsblatt.dart` schreibt
ohne Entwurf direkt: `HeroActions.updateHero` (frisch, je Held eingereiht)
mit `aendereMerkmale` (eine
Merkmalsart, Ausgangsliste ist die wirksame, bei Bestandshelden also die
Laufzeitmigration) bzw. `loeseMerkmalAbweichung`. `aendereMerkmale` wirft bei
offener Abweichung, damit kein Schreibweg sie nebenbei aufloest. Geaendert
wird ein Eintrag ueber Gleichheit im frisch geladenen Stand; fehlt er
inzwischen, meldet das Blatt einen Fehler statt zu raten. Die Karten baut
`beschreibeMerkmal` (`hero_merkmal_anzeige_rules.dart`); Wirkungstexte nutzen
`merkmalBasiswertBetrag`, `merkmalEigenschaftBetrag` und `merkmalRastStufe`
aus `hero_merkmal_wirkung_rules.dart` wie die Rechnung selbst.

**Begabung und Unfaehigkeit.** Die 18 Begabungs- und Unfaehigkeitseintraege
tragen die Wirkungsart `lernspalte` (`betrag` +1 = eine Spalte guenstiger,
-1 = teurer; Ziele `talent`, `talentgruppe`, `nahkampf`, `fernkampf`,
`sprachen`, `sprachgruppe`, `zauber`, `merkmal`, `ritual`).
`werteMerkmaleAus` sammelt sie als `MerkmalWirkungen.lernspalten`;
`ermittleBegabungen(hero, catalog:)` (`hero_begabung_rules.dart`) liefert je
Ziel einen `LernspaltenBefund`. Abgeleitet wird zur Laufzeit, am Ziel wird
nichts gespeichert; das Haekchen `gifted` bleibt daneben und wirkt wieder,
wenn der Vorteil entfernt ist.
- Talent-, Gruppen-, Kampfart- und Zauber-Begabung wirken wie das Haekchen:
  zusammen hoechstens eine Spalte guenstiger, Maximum +5 statt +3.
- Merkmals-Begabungen zaehlen je passendem Merkmal eines Zaubers eine
  weitere Spalte (Vergleich wie Merkmalskenntnis, exakter Name aus
  `parseSpellTraits`); Merkmals-Unfaehigkeiten spiegelbildlich.
- Uebrige Unfaehigkeiten verteuern zusammen eine Spalte, das Maximum bleibt.
  Verteuert wird zuerst (bis `H`), dann verbilligt (bis `A*`).
- Sprachen/Schriften verschieben die Spalte der Steigerungsoption.
- Eine Ritual-Begabung verbilligt die eigene Ritualkenntnis der Kategorie,
  die das Ritual fuehrt oder deren Name der Traditionsritual-SF mit diesem
  Ritual entspricht (Untergrenze `A`); das Ritual traegt eine Marke.
Verbraucher: `AdvancementContext.begabungen` (einmal je Optionsaufbau),
`CatalogRuleResolver.resolveTalentComplexity` (`unfaehigkeitsSchritte`),
Talente-, Kampf- und Magie-Tab samt ihren Katalogvorschauen und dem
Repraesentationsdialog (dort zaehlt nur der Befund, nicht das Haekchen, weil
das Ziel noch nicht auf dem Bogen steht). Abgeleitete Begabung zeigt
`BegabungHaekchen` (`lib/ui/widgets/begabung_haekchen.dart`) als gesetztes,
gesperrtes Haekchen mit Quelle; `LernspaltenMarke` erklaert jede
verschobene Spalte per Tooltip. Der Textweg kennt
keine Lernspalten: freie und mehrdeutige Texte wirken nicht, und der
Aequivalenztest nimmt `lernspalte` bewusst aus.

## 5. Zustandsverwaltung (State Layer)

### 5.1 Provider-Übersicht

**Hauptdateien:** `lib/state/hero_providers.dart`, `lib/state/hero_base_providers.dart`,
`lib/state/catalog_providers.dart`

| Provider | Typ | Zweck |
|---|---|---|
| `heroRepositoryProvider` | `Provider<HeroRepository>` | Repository (beim Start überschrieben) |
| `heroTransferCodecProvider` | `Provider<HeroTransferCodec>` | JSON-Codec für Im-/Export |
| `heroTransferFileGatewayProvider` | `Provider<HeroTransferFileGateway>` | Plattform-I/O |
| `selectedHeroIdProvider` | `NotifierProvider<String?>` | Aktuell gewählte Held-ID |
| `heroIndexProvider` | `StreamProvider<HeroIndexSnapshot>` | Alle Helden reaktiv |
| `heroListProvider` | `StreamProvider<List<HeroSheet>>` | Sortierte Heldenliste |
| `heroByIdProvider(id)` | `Provider.family<HeroSheet?>` | O(1) Lookup per ID |
| `heroStateProvider(id)` | `StreamProvider.family<HeroState>` | Laufzeitzustand |
| `heroComputedProvider(id)` | `Provider.family<AsyncValue<HeroComputedSnapshot>>` | Alle abgeleiteten Werte |
| `effectiveAttributesProvider(id)` | `Provider.family<AsyncValue<Attributes>>` | Effektive Eigenschaften |
| `derivedStatsProvider(id)` | `Provider.family<AsyncValue<DerivedStats>>` | Abgeleitete Werte |
| `combatPreviewProvider(id)` | `Provider.family<AsyncValue<CombatPreviewStats>>` | Kampfvorschau |
| `heroActionsProvider` | `Provider<HeroActions>` | Schreiboperationen |
| `rastAbschliessenProvider` | `Provider<RastAbschliessen>` | Ablauf „Rast abschließen“ auf dem aktiven Repository (`lib/state/ablauf_providers.dart`) |
| `catalogLoaderProvider` | `Provider<CatalogLoader>` | Katalog-Lader |
| `customCatalogRepositoryProvider` | `Provider<CustomCatalogRepository>` | Datei-I/O fuer synchronisierbare Custom-Kataloge |
| `baseCatalogSourceDataProvider` | `FutureProvider<CatalogSourceData>` | Roh-Sektionen aus Assets (mit `enc:`-Praefixen) |
| `decryptedCatalogSourceDataProvider` | `FutureProvider<CatalogSourceData>` | Bulk-entschluesselte Quelle (Pre-Stage vor Runtime, siehe 5.3) |
| `catalogRuntimeDataProvider` | `FutureProvider<CatalogRuntimeData>` | Basis + Custom + Fehlerzustand |
| `catalogAdminSnapshotProvider` | `FutureProvider<CatalogAdminSnapshot>` | Settings-Katalogverwaltung |
| `rulesCatalogProvider` | `FutureProvider<RulesCatalog>` | Geladener Katalog |
| `talentBeOverrideProvider(id)` | `NotifierProvider.family<int?>` | Manuelle BE-Überschreibung |

`HeroesHomeScreen` waermt `rulesCatalogProvider.future` einmal nach dem ersten
Frame mit geladener Heldenliste vor. Beim Oeffnen eines Helden wartet der Screen
auf diesen Future und zeigt bei Bedarf einen nicht schliessbaren
Vorbereitungsdialog; der Workspace behaelt sein eigenes Prewarming als Fallback
fuer Direktnavigation und Sonderfaelle.

### 5.3 Bulk-Decrypt geschuetzter Kataloginhalte

**Datei:** `lib/catalog/catalog_decrypt_runner.dart`

Geschuetzte Felder in Katalog-Assets sind mit `enc:`-Praefix gespeichert
(Format-Marker: `enc:` v1, `enc:2:` v2, `enc:3:` v3 — siehe
`lib/catalog/catalog_crypto.dart`). Damit der Magie-Tab und alle weiteren
Konsumenten nicht pro Anzeige PBKDF2/AES anwerfen, sitzt zwischen
`baseCatalogSourceDataProvider` und `catalogRuntimeDataProvider` der neue
`decryptedCatalogSourceDataProvider`:

- Watcht den selektiven `catalogContentPasswordProvider`. Ohne Passwort wird
  die Quelle unveraendert durchgereicht; geschuetzte Felder bleiben mit
  `enc:`-Praefix bestehen und die UI zeigt einen Locked-Hinweis. Andere
  Einstellungen wie gespeicherte Spaltenbreiten invalidieren die
  Katalog-Pipeline nicht.
- Mit Passwort ruft er `decryptAllCatalogValues` auf. Der Runner zaehlt die
  `enc:`-Werte: ab 64 wird der Bulk-Decrypt via `compute()` auf einen Web
  Worker / Isolate ausgelagert, sonst synchron im aufrufenden Thread.
- v3-Werte nutzen den globalen Salt aus `manifest.catalog_salt_v3` — eine
  einzige PBKDF2-Ableitung pro Passwort, danach AES-GCM pro Wert (<1 ms).
  v2/v1-Werte bleiben rueckwaertskompatibel und laufen ueber den
  langsameren Per-Wert-Pfad bis zur Migration der Assets.
- Passwoerter werden vor PBKDF2 NFC-normalisiert (`_passwordBytes` in
  `catalog_crypto.dart` via `package:unorm_dart`). Damit erzeugen `ü` als
  precomposed (U+00FC) und als `u`+Combining-Diaeresis (NFD) denselben
  Schluessel — sonst wuerde dasselbe Passwort je nach Eingabequelle
  (Tastatur vs Copy/Paste, macOS-Dateisystem vs Windows-Tastatur)
  unterschiedliche Schluessel ergeben. Das Python-Tool spiegelt die
  Normalisierung in `_password_bytes`.
- Bei List-Feldern (z.B. `variants` in `magie.json`) verschluesselt das Tool
  die Liste als JSON-encoded String. Beim Bulk-Decrypt erkennt
  `_maybeDecodeJsonStructure` JSON-Arrays/Objects (Schnellcheck auf erstes
  Zeichen `[`/`{`) und liefert sie als `List<dynamic>`/`Map` zurueck,
  spiegelbildlich zum Encrypt — `SpellDef.fromJson` sieht damit weiterhin
  eine echte Liste unter `variants`.

`ProtectedContentCache` in `lib/ui/screens/shared/protected_content_helpers.dart`
sieht nach diesem Schritt nur noch Klartext-Werte und greift seinen
Pass-through-Branch — der Cache bleibt als Schutz fuer den Locked-Pfad und
fuer noch nicht migrierte Assets erhalten.

Re-Encryption / Migration der Asset-Dateien erfolgt mit
`tool/encrypt_catalog_fields.py --format v3 --migrate --password "..."` (siehe
Datei-Header).

### 5.2 `HeroComputedSnapshot` — Berechnungspipeline

**Datei:** `lib/state/hero_computed_snapshot.dart`

```
heroComputedProvider(heroId):
  1. heroByIdProvider(heroId)     → HeroSheet
  2. heroStateProvider(heroId)    → HeroState
  3. rulesCatalogProvider         → RulesCatalog (async)
  ─────────────────────────────────────────────────────
  4. parseModifierTextsForHero()  → ModifierParseResult
     (vorteileText, nachteileText, rasseModText, …)
  5. applyAttributeModifiers()    → Attributes (effektiv)
     (startAttributes + persistentMods + tempAttributeMods)
  6. computeDerivedStatsFromInputs() → DerivedStats
  7. computeCombatPreviewStats()  → CombatPreviewStats
  ─────────────────────────────────────────────────────
  → HeroComputedSnapshot (unveränderlich, alle Werte in einem Pass)
```

Die Schritte 4–7 liegen als reine Funktion `buildHeroComputedSnapshot`
(`hero`, `state`, `catalog`, `epicAdvantagesActive`) in derselben Datei. Der
Provider beobachtet nur die Eingaben und ruft sie auf; Tests rechnen damit
dieselben Werte ohne `ProviderContainer` (z. B. die Regelwerte der
Bestandshelden unter `test/rules/`).

`HeroComputedSnapshot`-Felder:

| Feld | Typ |
|---|---|
| `hero` | `HeroSheet` |
| `state` | `HeroState` |
| `modifierParse` | `ModifierParseResult` |
| `effectiveStartAttributes` | `Attributes` |
| `attributeMaximums` | `Attributes` |
| `effectiveAttributes` | `Attributes` |
| `derivedStats` | `DerivedStats` |
| `combatPreviewStats` | `CombatPreviewStats` |

### 5.3 `HeroActions` — Schreibpfad

**Datei:** `lib/state/hero_actions.dart`

| Methode | Beschreibung |
|---|---|
| `createHero({name, rawStartAttributes})` | Neuen Helden mit Name, Roh-Startwerten, vordefinierten Standard-Talenten, festem Meta-Talent `Kraeutersuchen` und leerem State anlegen |
| `saveHero(HeroSheet)` | AP normalisieren, Level neu berechnen, Modifier parsen, Ritualkategorien normalisieren und persistieren |
| `saveHeroState(id, HeroState)` | Laufzeitzustand persistieren |
| `deleteHero(id)` | Held und State löschen, Auswahl aktualisieren |
| `buildExportJson(id)` | `HeroTransferBundle` (Held + State + Zeitstempel) als JSON |
| `parseImportJson(rawJson)` | JSON parsen und als `HeroTransferBundle` validieren |
| `importHeroBundle(bundle, resolution)` | Importieren mit Konfliktlösung |

**`ImportConflictResolution`:**
- `overwriteExisting` — vorhandenen Helden überschreiben
- `createNewHero` — neue UUID vergeben, als neuen Helden anlegen

**Normalisierung in `saveHero()`:**
- AP auf Minimum 0 begrenzen
- `level` aus `apSpent` neu berechnen
- `apAvailable = apTotal − apSpent`
- Modifier-Fragmente parsen und in `unknownModifierFragments` speichern
- Ritualkategorien, Zusatzfelder und Ritualwerte bereinigen und synchronisieren

### 5.4 Reaktivität

```
HiveHeroRepository
  _heroesBox (Hive BoxEvent)
        │
        ▼
  _handleHeroBoxEvent() → _heroIndex aktualisieren
        │
        ▼
  _heroIndexController.add(snapshot)   (Broadcast Stream)
        │
        ▼
  heroIndexProvider (StreamProvider)
        │
        ▼
  heroListProvider, heroByIdProvider, heroComputedProvider, …
        │
        ▼
  UI rebuild (ConsumerWidget .watch())
```

---

## 6. Persistenz (Data Layer)

### 6.1 `HiveHeroRepository`

Seit 2026-03-13 nutzt das Repository einen expliziten Heldenspeicherpfad
statt einer globalen Hive-Initialisierung ueber den Dokumente-Ordner. Der
Standardpfad liegt unter dem app-spezifischen Support-Ordner in
`.../Helden`; auf Windows ist das effektiv z. B.
`.../AppData/Roaming/de.adamski/DSA Heldenverwaltung/Helden`, auf
macOS und Linux analog unter dem jeweiligen `Application Support`-Pfad.
macOS und Linux kann optional ein benutzerdefinierter Ordner verwendet werden.

### 6.1a `HiveSettingsRepository` und Speicherpfade

- App-Einstellungen liegen getrennt von Heldendaten in einem lokalen
  Einstellungsordner `.../Einstellungen` unter demselben app-spezifischen
  Support-Ordner.
- `AppSettings` enthaelt optional `heroStoragePath` fuer einen
  benutzerdefinierten Heldenspeicher auf Windows, macOS und Linux.
- Auf Web werden beide Pfade als logische `Browser-Speicher/...`-Pfade
  beschrieben; Hive persistiert dort browserlokal statt in nativen Ordnern.
- Ein ungueltiger benutzerdefinierter Heldenspeicherpfad fuehrt zu einem
  sichtbaren Fehlerzustand; es gibt keinen stillen Rueckfall auf den
  Standardordner.

**Datei:** `lib/data/hive_hero_repository.dart`

| Element | Details |
|---|---|
| Hive-Box Helden | `heroes_v1` — speichert `HeroSheet.toJson()` |
| Hive-Box States | `hero_states_v1` — speichert `HeroState.toJson()` |
| In-Memory-Index | `Map<String, HeroSheet>` für O(1)-Lookup |
| Stream | `StreamController<Map<String, HeroSheet>>` (Broadcast) |

**Lifecycle:**
1. `HiveHeroRepository.create()` (async Factory)
2. Hive initialisieren, Boxen öffnen
3. `_seedHeroIndex()` — alle Helden in Cache laden
4. Box-Events abonnieren (`_handleHeroBoxEvent`)
5. `close()` — Subscriptions beenden, Boxen schließen

### 6.2 Import/Export

**Codec** (`lib/data/hero_transfer_codec.dart`):
- `encode(bundle)` → JSON-String (2-Space-Einrückung)
- `decode(rawJson)` → `HeroTransferBundle` (wirft `FormatException` bei Fehler)

Beim Export wird die minimale benoetigte Menge referenzierter
Custom-Katalogeintraege optional in `HeroTransferBundle.catalogEntries`
eingebettet. Beim Import werden diese Dateien zuerst in den aktiven
Heldenspeicher geschrieben, damit anschliessend gespeicherte Heldenreferenzen
sofort aufloesbar sind.

**Gateway** (`lib/data/hero_transfer_file_gateway.dart`):

Plattform-Dispatch über bedingte Imports (`_stub.dart` / `_io.dart` / `_web.dart`):

| Implementierung | Plattform | Import-Verhalten | Export-Verhalten |
|---|---|---|---|
| `IoHeroTransferFileGateway` | Android, iOS, macOS, Windows, Linux | `FilePicker` öffnen | Desktop: Speichern-Dialog; Mobile: `Share.shareXFiles()` |
| `WebHeroTransferFileGateway` | Web | `FilePicker` öffnen | Blob erstellen + Download-Link auslösen |
| Stub | Unbekannt | `UnsupportedError` | `UnsupportedError` |

**Export-Ergebnis** (`HeroTransferExportResult`):
`canceled` | `savedToFile` | `downloaded` | `shared`

### 6.3 Seed-Helden beim App-Start

**Datei:** `lib/data/startup_hero_importer.dart`

`StartupHeroImporter.importFromAssets()`:
1. Alle `.json`-Dateien unter `assets/heroes/` aus dem Asset-Manifest ermitteln
2. Jede Datei als `HeroTransferBundle` oder rohen `HeroSheet` parsen
3. Überspringen, wenn Held mit dieser ID bereits im Repository vorhanden
4. Sonst: Held + State (oder leeren State) speichern

---

## 7. UI-Schicht (Überblick)

### Hauptbildschirme

| Datei | Klasse | Beschreibung |
|---|---|---|
| `heroes_home_screen.dart` | `HeroesHomeScreen` | Heldenliste; Import/Export/Löschen |
| `hero_workspace_screen.dart` | `HeroWorkspaceScreen` | Dynamischer Workspace-Host fuer einen Helden |
| `hero_overview_tab.dart` | `HeroOverviewTab` | Uebersicht-Tab fuer Eigenschaften, AP, Ressourcen, katalogbasierte Vorteile/Nachteile und Biografie |
| `hero_talents_tab.dart` | `HeroTalentsTab` | Talente, strukturierte Talent-Sonderfertigkeiten und Meta-Talente |
| `hero_combat_tab.dart` | `HeroCombatTab` | Kampftechniken, Waffen, Kampf (Nah- oder Fernkampf), SF, Manöver und Kampfmeisterschaften |
| `hero_magic_tab.dart` | `HeroMagicTab` | Zauber, Ritualkategorien/Rituale, Repräsentationen, magische SF und globale Leiteigenschaft |
| `hero_inventory_tab.dart` | `HeroInventoryTab` | Direkte Inventartabelle mit AppBar-Aktion, Split-Editor und Sofortspeicherung |
| `hero_notes_tab.dart` | `HeroNotesTab` | Untertabs fuer Chroniken, Kontakte und Abenteuer mit Chip-Workspace, Popups und gefuehrtem Abenteuer-Abschluss |

### Responsive Layout

| Breakpoint | Layout |
|---|---|
| < 1280 dp | **Classic**: Eigenschaften-Header + horizontale TabBar + Inhalt |
| ≥ 1280 dp | **Helden-Deck**: Linkes Nav-Panel (240 px, einklappbar auf Toggle-Leiste) + zentraler Inhalt + rechte Detailleiste (300 px, einklappbar auf Toggle-Leiste) |

### Edit-Zyklus

```
Held laden → Draft-State erzeugen
      │
      ▼
Nutzer bearbeitet Felder (Draft wird dirty)
      │
      ├── Tab wechseln / zurück → Guard-Dialog (Verwerfen oder Speichern)
      │
      └── Speichern → HeroActions.saveHero() → Repository → Stream → UI-Rebuild
```

Die meisten Tabs verwalten ihren Draft-State lokal (z. B. `_draftTalents`,
`_draftCombatConfig`) und synchronisieren beim Laden/Speichern mit dem Repository.
Der Inventar-Tab ist die Ausnahme: Inventaritems und Dukaten werden dort direkt
pro Aktion gespeichert und nutzen keinen globalen Edit-Modus.
Der Dukatenstand bleibt ein Freitextfeld, kann aber im Inventar ueber
Muenztasten fuer Dukaten, Silbertaler und Kreuzer angepasst werden. Die
Umrechnung und Normalisierung liegt in `lib/rules/derived/currency_rules.dart`,
damit Widget- und Abenteuerlogik dieselbe Kreuzer-Praezision nutzen.

---

## 8. Entwicklungshinweise

### Test-Strategie

| Art | Datei | Zweck |
|---|---|---|
| Widget-Test | `test/ui/performance/ui_rebuild_guardrails_test.dart` | Prüft: kein exzessiver Rebuild bei Einzelfeld-Edits |
| LOC-Budget | `tool/check_screen_loc_budget.py --max-lines 700` | Screen-Dateien max. 700 Zeilen |

```bash
# Alle Unit- und Widget-Tests
flutter test

# Einzelner Guardrail-Test
flutter test test/ui/performance/ui_rebuild_guardrails_test.dart

# Windows-Artefakt fuer AV-/Signaturpruefung dokumentieren
pwsh -File tool/audit_windows_artifact.ps1 `
  -ArtifactPath build\windows\x64\runner\Release\flutter_application_1.exe `
  -AsJson

```

Für echte Frame-Messungen wird kein dedizierter Integration-Test mehr
mitgeführt. Bei Bedarf erfolgt Profiling ad hoc über Flutter DevTools auf
einem Zielgerät im Profile-Modus.

### Serialisierungskompatibilität

- `fromJson()` ist in **allen** Domain-Modellen lenient: jedes Feld verwendet `?? Standardwert`.
- Die aktuelle `schemaVersion` fuer `HeroSheet` ist **28**, fuer `HeroState` **6**.
- **28** markiert keine Formataenderung, sondern die Quittierung der geaenderten Auswertung von `Herausragende Eigenschaft` (Abschnitt 4.10).
- Beim Hinzufügen neuer Felder: immer einen Standardwert in `fromJson()` angeben.
- `HeroTransferBundle.transferSchemaVersion` = 3 wird **strikt** validiert.

### Dateinamen & Stil

| Konvention | Wert |
|---|---|
| Dateinamen | `snake_case.dart` |
| Anführungszeichen | single quotes (Linter: `prefer_single_quotes`) |
| Print-Statements | Verboten (`avoid_print` aktiv) |
| Modelle | Unveränderlich (`final`, `const`, `copyWith`) |
| Provider-Lesezugriff | `.watch()` in Build-Methoden; `.read()` nur in Callbacks |
| Screen-Größenlimit | 700 Zeilen pro Root-Screen-/Tab-Datei |

### Git-Workflow

- **Branches:** `task/<YYYYMMDD-HHMMSS>-<kurzes-Thema>` (nie direkt auf `main`/`master`)
- **Commit-Format:** `<bereich>: <konkrete Änderung>` (Deutsch)
  - Beispiel: `kampf: Waffenslots auf editierbare Tabelle umstellen`
- **Vor jedem Commit:** `flutter analyze` und `flutter test` ausführen; bei Fehler nicht committen
- **Verbotene Befehle:** `git reset --hard`, `git push --force`, `git clean -fd`,
  `git checkout -- <path>`, destruktive Dateilöschungen

### Katalog-Pflege

```bash
# Katalog aus Excel-Quellen neu erzeugen
python tool/convert_excel_to_catalog.py

# Monolithischen Katalog in Split-JSON aufteilen
python tool/split_house_rules_catalog.py

# Unbekannte Dart-Dateien melden
python tool/report_unreferenced_dart.py
```

Excel-Quelldateien (`*.xlsx`) im Repo-Root sind die **Upstream-Quelle**; JSON-Dateien unter
`assets/catalogs/house_rules_v1/` **nie manuell bearbeiten**.

Synchronisierbare Benutzererweiterungen liegen stattdessen im aktiven
Heldenspeicher unter `custom_catalogs/<version>/<sektion>/<id>.json` und werden
ueber die Settings-Katalogverwaltung bearbeitet.

### Windows-Antivirus- und Release-Pruefung

- `docs/windows_antivirus_audit.md` dokumentiert den statischen Audit fuer
  Windows-Desktop und Laufzeitcode.
- `tool/audit_windows_artifact.ps1` sammelt fuer ein gebautes EXE- oder
  MSIX-Artefakt Hash, Versionsinfos, Authenticode-Status und optional einen
  lokalen Defender-Scan.
- Diese Pruefung ergaenzt den Quellcode-Audit, ersetzt ihn aber nicht.

### Update 2026-08-08: Epische Haupteigenschaften und Steigern auf Tablets

- **Haupteigenschaften steigern zum Normalpreis.** `applyEpicApSurcharge`
  und `computeEpicApSurchargeDelta`
  (`lib/rules/derived/epic_ap_cost_rules.dart`) kennen jetzt den Parameter
  `isMainAttribute`. Ist er gesetzt, entfaellt der 25-%-Aufschlag aus
  Kap. 2.2 — die beiden gewaehlten Haupteigenschaften sind laut Kap. 2.1
  davon ausgenommen. Ob eine Eigenschaft betroffen ist, entscheidet das neue
  Praedikat `isEpicMainAttribute`
  (`lib/rules/derived/epic_main_attribute_rules.dart`), das bewusst
  unabhaengig von Hausregel-Schaltern und `isEpisch` arbeitet.
- `showSteigerungsDialog` reicht das ueber `istHaupteigenschaft` durch;
  gesetzt wird es nur in `_steigeEigenschaft`
  (`hero_overview_raise_actions.dart`). Talente und Zauber behalten den
  Aufschlag. Der Dialog zeigt statt der Aufschlagszeile den Hinweis
  „Haupteigenschaft — kein epischer Aufschlag".
- **Epischer Status ist korrigierbar.** `EpicActivationDialog` hat einen
  Edit-Modus (`isEdit`, `initialMaxBonus`, `initialMainAttributes`,
  `initialPolicy`). `_editEpicStatus`
  (`hero_overview_epic_section.dart`) schreibt daraus ausschliesslich
  `epicAttributeMaxBonus`, `epicMainAttributes` und
  `epicActivationPolicy`; `isEpisch`, `epicStartAp` und
  `epicUnactivatedTalentIds` bleiben unangetastet, damit Epos-Level und
  AU-Deckelung stabil bleiben. Einstieg ist das Stern-Symbol der Sektion
  „AP und Level" (`overview-action-epic-edit`). Es gibt weiterhin keinen
  Weg, den epischen Status zu entfernen. `HeroSheet` bleibt bei
  `schemaVersion` 26 — es kamen keine Felder hinzu.
- Fehlen einem epischen Helden die Haupteigenschaften, weist die Sektion
  „Epische Vorteile und Nachteile" mit einem eigenen Hinweis darauf hin.
- **Steigern auf iPad-Breiten.** Unterhalb der Spalten-Mindestbreite
  (Talent-Tabelle im Edit-Modus rund 1010 px) rendert
  `ResponsiveAdaptiveTable` Karten; dort fehlte bisher jeder Weg zum
  Steigerungsdialog. Talent- und Kampftalent-Karten haben jetzt einen
  Steigern-Button, und `_TalentDetailDialog` eine Steigern-Aktion
  (`talent-detail-raise-<id>`), die das Sheet schliesst und
  `_steigereTalent` aufruft. Blockiert der Dirty-Gate, erklaert ein
  Tooltip den Grund.
- Die Touch-Ziele der Steigern-Buttons folgen jetzt
  `adaptiveMinTouchTarget` (`lib/ui/config/platform_adaptive.dart`), auf
  Apple-Plattformen also den 44 pt der HIG statt bisher 32 dp.
- **Ansicht umschaltbar.** `AppSettings.tabellenAnsicht`
  (`enum TabellenAnsicht { automatisch, tabelle, karten }`, Default
  `automatisch`) ueberstimmt die Breiten-Automatik von
  `ResponsiveAdaptiveTable` ueber dessen Parameter `ansicht`. Das Widget
  bleibt Riverpod-frei; den Wert liefern die Tabs, die ihn in ihrer
  `build`-Methode aus `tabellenAnsichtProvider` lesen und in einem Feld
  ablegen (die Tabellen entstehen in verschachtelten Buildern, wo
  `ref.watch` nicht erlaubt ist). Bei erzwungener Tabelle greift die
  vorhandene horizontale `SingleChildScrollView`. Bedienbar im Kopf des
  Talente-Tabs (`talents-view-mode-toggle`) und unter
  `Einstellungen > Darstellung`; die Einstellung gilt app-weit und damit
  auch fuer die Eigenschafts- und Basiswert-Tabellen der Uebersicht.

### Update 2026-09-05: Persistente Breiten für Haupttabellen

- `AdaptiveTableColumnSpec` kennzeichnet verstellbare Spalten über stabile
  `columnId`, `resizable` und `resizeMaxWidth`. Die adaptive Breitenauflösung
  läuft zuerst; anschließend ersetzt ein gültiger Nutzerwert nur seine eigene
  Spalte und lässt alle Nachbarspalten unverändert.
- `PersistedTableColumnLayout` hält Drag-Werte zunächst tabellen-ID-weit lokal
  und speichert erst beim Loslassen. `FlexibleTable`,
  `ResponsiveAdaptiveTable` und die aktive Zauber-`DataTable` verwenden den
  gemeinsamen 24-px-Headergriff; Kartenansichten ignorieren Bindung und Griffe.
- `AppSettings.tableColumnWidths` serialisiert die geräteweiten Profile als
  `{tableId: {columnId: width}}`. Aktiv sind `magic.activeSpells`,
  `talents.meta`, `talents.general`, `talents.combat`, `combat.talents`,
  `combat.weapons`, `combat.armor`, `combat.offhand` und `inventory.items`;
  Katalog-, Übersichts-, Begleiter- und Sync-Tabellen bleiben unverändert.
- Selektive Provider für Katalogpasswort und deaktivierte Hausregel-Pakete
  verhindern, dass das Persistieren einer Breite den Katalog oder den gesamten
  Zaubertab neu aufbaut.
- `PersistedTableColumnLayout` liest die gespeicherten Breiten über den
  selektiven `tableColumnWidthsProvider(tableId)`. `AppSettings.tableColumnWidths`
  wird bei jedem Save komplett neu aufgebaut, deshalb vergleicht der Provider
  den Inhalt und nicht die Map-Instanz — sonst baut jede gespeicherte Breite
  auch alle übrigen sichtbaren Tabellen neu auf.

### Update 2026-08-08: Haupteigenschafts-Boni teilweise verdrahtet

- **Boni-Katalog mit Umsetzungsgrad.** Die frühere flache Map
  `epicMainAttributeBonusDescriptions` ist ersetzt durch
  `const List<EpicMainAttributeBonus> epicMainAttributeBonuses`
  (`lib/rules/derived/epic_main_attribute_rules.dart`). Jeder Einzelbonus aus
  Kap. 2.1 trägt ein `EpicBonusUmsetzung`:
  `automatisch` (die App rechnet ihn ein), `hinweis` (die App blendet ihn an
  der passenden Stelle ein) oder `manuell` (noch nicht unterstützt).
  Zugriffe: `activeEpicMainAttributeBonuses` (ersetzt
  `activeEpicMainAttributeHints`), `epicMainAttributeBonusesFor` und
  `epicMainAttributeBonusSummary` für Tooltips.
- **Von rund 18 Einzelboni sind 2 gerechnet und 1 eingeblendet.** Der Rest
  bleibt bewusst manuell, weil die zugehörigen Regelbereiche in dieser App gar
  nicht modelliert sind — siehe die Aufstellung unten.
- **KK: eBE bei KK-Talenten halbiert.** `computeTalentEbe`
  (`ruestung_be_rules.dart`) kennt `reductionMultiplier`;
  `computeMetaTalentEbe` reicht ihn durch. Ob er greift, entscheidet
  `epicTalentEbeMultiplier` anhand von `talentProbeUsesAttribute`, das die
  Probenkette aus `TalentDef.attributes` über `parseAttributeCode` prüft.
  Verdrahtet in Talent-Tabelle und -Karten, Talent-Detail-Sheet und
  Proben-Schnellsuche. **Rundung:** die Behinderung wird abgerundet, also
  zugunsten des Helden — gleiche Richtung wie `computeAtEbePart`.
- **KO: Unterdrücken von Wunden halbiert.** Laut „Epische Stufen“ S. 4
  sind „die Erschwernis und die resultierende Erschöpfung durch das
  Unterdrücken von Wunden halbiert“, nicht die Probenabzüge (bis ARCH-05 (6)
  halbierte die App fälschlich eine pauschale Proben-Erschwernis).
  `computeHeroWundEffekte` (`hero_stat_inputs.dart`) setzt
  `WundEffekte.unterdrueckungHalbiert`; `computeSbUnterdrueckungErschwernis
  (halbiert: true)` teilt 4n bzw. +8/+12 ohne Rest. Die Erschöpfung (1W6 nach
  dem Kampf) erscheint als Hinweis. Snapshot und Unterdrückungsdialog nutzen
  dieselbe Funktion.
- **IN: Fintenhinweis.** Der Bonus wirkt auf die Probe des *Gegners* und ist
  deshalb kein Heldenwert. Er folgt dem Muster von
  `buildAxxeleratusDefenseHint` (`magic_rules.dart`):
  `buildEpicFinteDefenseHint` füllt das neue Feld
  `CombatPreviewStats.epicFinteDefenseHint`, das
  `combat_preview_subtab.dart` neben dem Axxeleratus-Hinweis einblendet.
  `computeCombatPreviewStats` hat dafür den optionalen Parameter
  `epicAdvantagesRuleActive` (Default `true`); den echten Wert übergeben
  `hero_combat_tab.dart` und `hero_providers.dart`.
- Alle drei Effekte sind über das Hausregel-Paket `epic_rules_v1.advantages`
  (`isHouseRuleActiveProvider`) geschaltet — dieselbe Regel, die schon die
  Bonus-Anzeige steuert.
- **Weiterhin nicht unterstützt** (in der UI als „manuell" ausgewiesen), weil
  der jeweilige Regelbereich nicht modelliert ist:
  KK Tragkraft × 1,5 (es gibt keine Tragkraftberechnung für Helden;
  `tragkraft` existiert nur als Freitextfeld auf `HeroCompanion`),
  MU MR +7 gegen angstauslösende Zauber (MR ist ein einzelner Kennwert,
  „angstauslösend" ist nicht kategorisiert),
  KO Gift ×0,5 und Krankheit ×0,7 (kein Gift-/Krankheitsmodell),
  FF Handwerksprodukte ×1,1 (kein Herstellungs- oder Produktwertmodell),
  GE gezieltes Ausweichen ⅓ und Passierschlag-Immunität
  (`ausweichen_rules.dart` kennt nur den Endwert),
  sowie die übrigen Textboni aus Kap. 2.1.
- **UI-Kennzeichnung.** Die Sektion „Epische Vorteile und Nachteile"
  (`hero_overview_epic_section.dart`) und der ⓘ-Dialog der Eigenschaften-
  Tabelle (`hero_overview_stats_section.dart`) markieren jeden nicht
  gerechneten Bonus mit „manuell" bzw. „Hinweis in der Kampfvorschau";
  gerechnete Boni bleiben unmarkiert.

### Update 2026-03-07: Begabung & Lernkomplexitaet

- `HeroSpellEntry` enthaelt jetzt zusaetzlich ein `gifted`-Flag fuer
  zauberspezifische Begabung.
- Die gemeinsame Lernkomplexitaets-Skala lautet
  `A* < A < B < C < D < E < F < G < H`.
- `lib/rules/derived/learning_rules.dart` kapselt die gemeinsame Logik fuer
  Lernkomplexitaet und Talentobergrenzen.
- Kampftalente nutzen fuer `max TaW` fest `GE/KK` (Nahkampf) bzw. `FF/KK`
  (Fernkampf); `IN` wird dabei nicht beruecksichtigt.
- Zauber addieren Hauszauber, passende Merkmalskenntnis und Begabung jeweils
  als eigene Reduktionsstufe; die Untergrenze ist `A*`.
- Seit ARCH-02 kommen Begabung und Unfaehigkeit auch aus Vor-/Nachteilen
  (Abschnitt 4.11, `hero_begabung_rules.dart`).

### Update 2026-03-08: Zauber-Repraesentation und Verbreitung

- `HeroSpellEntry` speichert jetzt zusaetzlich `learnedRepresentation` und
  `learnedTradition`, damit die konkret gelernte Zauber-Repraesentation pro
  Zauber eindeutig bleibt.
- `magic_rules.dart` modelliert Availability nicht mehr als eine einzige
  "beste" Zahl, sondern als Liste von `SpellAvailabilityEntry`.
- Ein Eintrag wie `Dru(Elf)2` bedeutet: Haupttradition `Dru`, gelernte
  Repraesentation `Elf`, Verbreitung `2`.
- Der Magie-Katalog zeigt alle Availability-Eintraege an; beim Aktivieren eines
  Zaubers wird bei mehreren Optionen eine Repraesentation ausgewaehlt.
- Fremdrepraesentation erhoeht die Lernkomplexitaet eines Zaubers um `+2`
  Stufen, bevor Hauszauber, Merkmalskenntnis und Begabung angewendet werden.
- Der Zauberdetaildialog zeigt zusaetzlich Merkmale und einen abgeleiteten
  Hinweis, ob Magieresistenz in die Probe einbezogen werden soll.

#### Repraesentations-fremdes Lernen

- Magiebegabte (Helden mit mindestens einer Repraesentation) duerfen auch
  Zauber aktivieren, deren Verfuegbarkeitsliste keinen Eintrag fuer ihre
  Tradition enthaelt (DSA-Regel "Zauber einer fremden Repraesentation
  lernen", WdZ S. 75).
- Im Katalog (`magic_spell_catalog_table.dart`) markiert ein `+2 K`-Chip
  solche Zauber.
- `allLearningOptionsForHero` (`magic_rules.dart`) liefert beim Aktivieren
  die Gesamtliste aller Lern-Optionen: regulaere Availability-Eintraege
  plus synthetische `(Herkunft, Helden-Repr)`-Paare fuer fremde Herkuenfte.
  Sobald die Liste mehr als einen Eintrag hat, oeffnet sich der bestehende
  `_SpellRepresentationDialog` und der Held waehlt sowohl Herkunfts-
  Tradition als auch Traeger-Repraesentation.
- Persistiert wird ohne neue Felder: `HeroSpellEntry.learnedRepresentation`
  enthaelt die Helden-Repr., `learnedTradition` die Herkunfts-Tradition
  des Zaubers. Die Bedingung `learnedTradition != learnedRepresentation`
  wird durch `isForeignLearnedRepresentation` (`magic_rules.dart`) erkannt
  und triggert in `magic_active_spells_table.dart` denselben `+2`-
  Komplexitaets-Aufschlag wie regulaere Fremdrepr.-Eintraege.

### Update 2026-03-08: Rohstart, Startwerte und Eigenschaftsmaximum

- `HeroSheet` speichert jetzt sowohl `rawStartAttributes` als auch `startAttributes`.
- `rawStartAttributes` sind die beim Anlegen eingegebenen Rohwerte.
- `startAttributes` werden nur aus `rawStartAttributes` plus Rasse-, Kultur- und Professions-Attributmods abgeleitet.
- `HeroComputedSnapshot` enthaelt zusaetzlich `effectiveStartAttributes` und `attributeMaximums`.
- Neue Helden werden ueber `createHero({name, rawStartAttributes})` angelegt.
- Beim Anlegen werden Standard-Talente sowie das feste Meta-Talent `Kraeutersuchen` (`MU/IN/FF` aus `Sinnesschaerfe`, `Wildnisleben`, `Pflanzenkunde`) direkt in `HeroSheet` gespeichert.
- Das Eigenschaftsmaximum ist ein Anzeigewert und wird als `ceil(start * 1.5)` berechnet.

### Update 2026-03-08: Zauberrituale

- `HeroSheet` speichert jetzt zusaetzlich `ritualCategories`.
- Neue Ritualmodelle liegen in `lib/domain/hero_rituals.dart`.
- `lib/rules/derived/ritual_rules.dart` normalisiert Ritualkategorien,
  Zusatzfelder und talentbasierte Anzeigen.
- Der Magie-Tab hat jetzt einen eigenen Ritual-Sub-Tab fuer Kategorien,
  Ritualkenntnisse, Zusatzfelder und einzelne Rituale.
- Eigenstaendige Ritualkenntnisse bleiben heldenspezifisch und werden nicht in
  den regulaeren Talente-Tab gespiegelt.

### Update 2026-03-08: Notizen und Verbindungen

- `HeroSheet` speichert jetzt zusaetzlich `notes` und `connections`.
- `HeroNoteEntry` kapselt freie Notizen mit klickbarem Titel und Langtext.
- `HeroConnectionEntry` speichert Name, Ort, Sozialstatus, Loyalitaet und Beschreibung.
- `HeroNotesTab` teilt den Workspace-Bereich in die Untertabs `Notizen` und
  `Verbindungen`.

### Update 2026-04-02: Chroniken, Kontakte und Abenteuer

- `HeroSheet` nutzt jetzt `schemaVersion` **22** und speichert zusaetzlich
  `adventures`, `attributeSePool` und `statSePool`.
- `HeroAdventureEntry` modelliert eine manuell sortierte Abenteuer-Etappe mit
  AP-Belohnung, festen SE-Zielen, eigenem Notizblock und `rewardsApplied`.
- `HeroConnectionEntry` enthaelt jetzt `adventureId`, damit Kontakte optional
  einem Abenteuer zugeordnet werden koennen.
- `lib/rules/derived/adventure_rewards_rules.dart` kapselt Anwenden,
  Ruecknahme und Referenzbereinigung fuer Abenteuer-Belohnungen.
- `HeroNotesTab` gliedert den Bereich jetzt in `Chroniken`, `Kontakte` und
  `Abenteuer`; der bestehende Reisebericht bleibt fachlich und technisch
  separat.
- `hero_overview_raise_actions.dart` uebergibt Abenteuer-SE fuer
  Eigenschaften und Grundwerte an den gemeinsamen Steigerungsdialog und zieht
  verbrauchte SE aus den persistierten Pools ab.

### Update 2026-04-04: Abenteuer-Workspace mit Chip-Uebersicht

- `HeroAdventureEntry` wurde um `status`, `people`, `startWorldDate`,
  `startAventurianDate`, `endWorldDate`, `endAventurianDate` und
  `currentAventurianDate` erweitert; fehlende Werte aus Altbestaenden laden
  tolerant mit Default `current` beziehungsweise leeren Strukturen.
- `HeroAdventurePersonEntry` modelliert abenteuerspezifische Personen
  getrennt von globalen Kontakten.
- `HeroAdventureDateValue` kapselt strukturierte weltliche und aventurische
  Datumsangaben fuer Abenteuer. Die Monatsauswahl kommt aus dem kanonischen
  Kalender in `lib/domain/aventurian_date.dart` (siehe Abschnitt „Aventurischer
  Kalender und aktuelles Alter").
- Der Abenteuer-Tab zeigt Abenteuer jetzt als nach Status gruppierte
  `ChoiceChip`-Uebersicht; standardmaessig wird das erste `Aktuell`-
  Abenteuer, sonst der erste Eintrag geoeffnet.
- Abenteuer, Notizen und Personen werden ueber adaptive Popups angelegt oder
  bearbeitet; im Detailbereich bleiben Titel und Zusammenfassung inline
  editierbar, waehrend Notizen und Personen als einklappbare Chips erscheinen.

### Update 2026-04-05: Gefuehrter Abenteuer-Abschluss

- `HeroSheet` nutzt jetzt `schemaVersion` **23**.
- `HeroAdventureEntry` speichert mit `dukatenReward` und `lootRewards`
  persistierte Abschlussdaten; `HeroAdventureLootEntry` bildet die manuell
  erfasste Beute fuer die spaetere Inventaruebernahme ab.
- `InventoryItemSource` enthaelt jetzt den Ursprung `abenteuer`, damit
  Abschluss-Gegenstaende im Inventar sichtbar bleiben, aber nicht als
  kampfverknuepfte Eintraege behandelt werden.
- `adventure_rewards_rules.dart` wendet AP, feste SE, Dukaten und
  Abenteuer-Beute atomar an, prueft Ruecknahmen gegen verbrauchte SE,
  fehlende Gegenstaende und ungueltige Dukatenstaende und setzt dabei den
  Abenteuerstatus konsistent zwischen `Aktuell` und `Abgeschlossen`.
- `currency_rules.dart` normalisiert Dukaten-, Silbertaler-, Heller- und
  Kreuzerwerte auf Kreuzer und formatiert sie wieder als kompakten
  Dukatenwert fuer Persistenz und UI.
- Der Abenteuer-Workspace beendet aktuelle Abenteuer ueber einen
  `Abschliessen`-Dialog mit Enddaten, Dukaten-Eingabe, Reward-Zusammenfassung
  und detailierter Gegenstandserfassung; das weltliche Enddatum ist mit dem
  heutigen Datum vorbelegt.

### Update 2026-03-15: Gefuehrte AP-Steigerungen

- `HeroTalentEntry.talentValue` ist nullable; `null` bedeutet sichtbares,
  aber noch nicht aktiviertes Talent.
- `lib/domain/learn/learn_rules.dart` kapselt Mapping von
  Lernkomplexitaeten, AP-Kosten pro Schritt, SE-Verbrauch sowie
  Lehrmeister- und Dukatenberechnung.
- `lib/ui/widgets/steigerungs_dialog.dart` ist der gemeinsame Dialog fuer
  Talent-, Zauber-, Eigenschafts- und Grundwertsteigerungen inklusive
  manueller Komplexitaetskorrektur fuer seltene Sonderfaelle.
- Die Tabs `hero_talents_tab.dart`, `hero_magic_tab.dart` und
  `hero_overview_tab.dart` zeigen Raise-Aktionen nur im Edit-Modus ohne
  ungespeicherte Draft-Aenderungen, um Konflikte mit lokalen Entwuerfen zu
  vermeiden.

### Update 2026-03-19: Gemeinsame Wuerfel-Engine

- `lib/domain/probe_engine.dart` definiert mit `ProbeType`,
  `ResolvedProbeRequest`, `ProbeRollInput`, `ProbeResult` und
  `AutomaticOutcome` den gemeinsamen Vertrag fuer alle Probearten.
- `lib/rules/derived/probe_engine_rules.dart` kapselt die komplette
  Regellogik als pure Funktionen inklusive RNG-Abstraktion fuer
  deterministische Tests.
- Eigenschaftsproben werten `1W20` gegen den modifizierten Eigenschaftswert
  aus; `1` ist immer Erfolg, `20` immer Misserfolg.
- Talent- und Zauberproben werten `3W20` gegen drei Zielwerte aus und
  kompensieren Ueberschreitungen aus dem modifizierten Pool. Ein negativer
  Restpool wird vorab als Malus auf alle drei Eigenschaften umgelegt.
- Ab zwei gewuerfelten `20ern` gilt eine Talent- oder Zauberprobe als
  automatisches Misslingen; ab zwei `1ern` als automatischer Erfolg mit
  Spezieller Erfahrung.
- Kampfproben fuer `AT`, `PA` und `Ausweichen` nutzen in v1 bewusst nur die
  normale `<=`-Pruefung ohne Krit-/Patzer-Sonderlogik.
- Initiativ- und Schadenswuerfe werden als Summenprobe ausgewertet; bei
  Aufmerksamkeit liefert die Kampfvorschau einen festen Initiativwurf statt
  eines digitalen Wurfangebots.
- `CombatPreviewStats` enthaelt dafuer zusaetzlich rohe Wuerfel-
  Spezifikationen fuer Initiative und Schaden.
- `lib/ui/screens/shared/probe_request_factory.dart` baut die UI-Requests
  aus Heldendaten, Talent-/Zauberkontext und Kampfvorschau.
- `lib/ui/screens/shared/probe_dialog.dart` ist der gemeinsame Dialog fuer
  digitales Wuerfeln und manuelle Eingabe. Er wird ueber Wuerfel-Symbole im
  Uebersichts-, Talente-, Magie- und Kampf-Tab geoeffnet.
- Wurfergebnisse werden im pro Held persistierten `HeroState.diceLog`
  protokolliert. `showLoggedProbeDialog` ist der zentrale UI-Einstieg fuer
  normale Proben; Trefferzonen-, Kopfwunden-INI- und Rast-/Regenerationswuerfe
  erzeugen neutrale `DiceLogEntry`-Eintraege ohne Erfolgs-/Misslingensstatus.

### Update 2026-03-19: Rast und strukturierte Regeneration

- `lib/domain/talent_special_ability.dart` fuehrt `TalentSpecialAbility`
  als strukturiertes Modell fuer Talent-Sonderfertigkeiten ein.
- `HeroSheet.talentSpecialAbilities` speichert diese Sonderfertigkeiten jetzt
  als Liste; alte Freitextdaten werden beim Laden automatisch migriert.
- `HeroSheet.magicLeadAttribute` speichert die globale Leiteigenschaft fuer
  magische Regeneration.
- `HeroState` fuehrt `erschoepfung` und `ueberanstrengung` als persistierte
  Laufzeitwerte ein.
- `lib/rules/derived/rest_rules.dart` kapselt Ausruhen, Schlafphase,
  Bettruhe, Umweltmodifikatoren sowie den Zustandsabbau gemaess der
  Rastregeln.
- Fuer laengere Abwesenheiten bietet der Rast-Dialog zusaetzlich einen
  `Fullrestore`, der alle Vitalwerte maximiert und den kompletten
  Wundzustand zuruecksetzt.
- Im breiten Workspace-Inspector sitzen `Erschoepfung` und
  `Ueberanstrengung` jetzt direkt in den editierbaren Vitalwerten.
- Das Lagerfeuer-Symbol sitzt oben rechts in derselben Vitalwerte-Karte und
  oeffnet `rest_dialog.dart` mit Vorschau und Sammeluebernahme.

### Update 2026-09-29: Rast als Anwendungsablauf (ARCH-05)

- `lib/rules/derived/rest_outcome_rules.dart` rechnet das Rastergebnis rein:
  `RestActivity` (kurze Rast, Schlaf, Bettruhe, nur ausruhen) bestimmt über
  `RestActivityRules` Ausdauer, Zustandsabbau (Tempo, Stunden) und die Zahl
  der Regenerationsphasen; `isRestProbeSuccessful` wertet die W20-Proben;
  `computeRestOutcome` bildet Ausdauer, Zustandsabbau und bis zu zwei
  Phasen samt Begrenzung auf das Maximum nach; `applyRestOutcome` ersetzt
  genau LeP, Au, AsP, Überanstrengung und Erschöpfung. Würfe tragen einen
  `RestRollSlot`; `applicableRestRollSlots` nennt die geltenden in
  Protokollreihenfolge. Ein negatives Maximum gilt als 0.
- `lib/ablaeufe/rast_abschliessen.dart` (`RastAbschliessen`) lädt den
  Zustand frisch, rechnet auf den gespeicherten Werten, hängt das
  Würfelprotokoll (`rast_protokoll.dart`) an und stempelt Protokoll und
  `lastModified` mit demselben Zeitpunkt. `vollstaendigeErholung` wendet
  `buildFullRestoreState` auf den frischen Zustand an. Zwischenzeitlich
  gespeicherte Wunden, Effekte und Protokolleinträge bleiben erhalten.
- `RestPanel` (`rest_dialog.dart`, Teildateien unter `workspace/rest/`)
  sammelt nur Eingaben. Ein Speicherfehler erscheint im Panel
  (`rest-dialog-save-error`), der Dialog bleibt offen; während des
  Speicherns sind Übernehmen und Fullrestore gesperrt.
- Grenze: Maxima und KO/IN-Zielwerte stammen aus `heroComputedProvider`,
  der Fullrestore liest sie erst nach der Bestätigung. Eine zwischenzeitliche
  Änderung von `tempMods` fließt erst mit dem nächsten Aufbau ein.

### Update 2026-09-29: Laufzeitzustand frisch schreiben (ARCH-05)

- `aendereGespeichertenZustand` (`lib/ablaeufe/zustand_schreiben.dart`)
  reiht Änderungen je Speicher und Held ein. Die Warteschlange liegt in einem
  `Expando` am Repository-Objekt; jede Änderung lädt erst, wenn die vorige
  gespeichert oder gescheitert ist. `HeroActions.updateHeroState` delegiert
  darauf und liefert den gespeicherten Zustand.
- `aendereZustandMitMeldung` (`lib/ui/screens/shared/zustand_aendern.dart`)
  ist der UI-Einstieg für Laufzeitwerte: frisch laden, nur die eigenen
  Felder ersetzen, Fehler „… nicht gespeichert“ im Fehlerbereich (siehe
  unten). Ihn nutzen
  Ressourcen-Stepper, Inspector-Vitals und -Magie, Belastung, Zaubereffekte,
  Wunden und die UI2-Ressourcenbrücke. `persistDiceLogEntries` hängt über
  `updateHeroState` an; `showLoggedProbeDialog` meldet Fehler des nicht
  abgewarteten Protokollierens als Snackbar.
- Wunden: `aendereWundZustand`, `schalteWundUnterdrueckung` und
  `fuegeWundeHinzu` (`lib/ui/screens/workspace/wund_zustand_speichern.dart`)
  ersetzen die drei fast gleichen Wege aus Detaildialog, Inspector-Sektion und
  Inspector-Karte. Sie zählen vom gespeicherten Wundzustand; der
  Unterdrückungsdialog sieht den tatsächlich gespeicherten Stand.
- Zaubereffekte: `lib/rules/derived/active_spell_state_rules.dart`
  (`schalteZaubereffekt`, `aktiviereAttributo`, `aktiviereArmatrutz`,
  `setzeZaubereffektDauer`, `zaehleZaubereffektDauer`) ändert nur den
  jeweiligen Effekt; beim Ausschalten des Attributo fallen seine Boni in
  `tempAttributeMods` weg.
- Bedienung zählt vom gespeicherten Wert: Ressourcenknöpfe melden eine
  `RessourcenAenderung` (`lib/rules/derived/ressourcen_aenderung_rules.dart`,
  Schritt mit Grenzen nur in Schrittrichtung oder Setzen), Belastung, Wunden
  und Restdauer zählen ebenso. So zählt jeder schnelle Klick.
- Fehler erscheinen im nächsten `ZustandFehlerBereich` an der
  `ZustandFehlerAnzeige` (Stepper, UI2-Ressourcenblatt, Zaubereffekt- und
  Wundendialog, Inspector-Tabs Vitals und Magie, UI2-Zustandsblock); ohne
  Bereich als Snackbar.
- Konto-Sync: `SyncingHeroRepository.saveHeroState` endet nach dem lokalen
  Speichern. `GebuendelteLaeufe` (`lib/data/sync/gebuendelte_laeufe.dart`)
  lädt je Held höchstens einen Stand gleichzeitig hoch, immer den neuesten;
  Anstöße während eines Uploads ergeben genau einen Folgelauf. Online-Stände,
  die währenddessen eintreffen, stellt das Repository zurück und bewertet
  sie danach (`nachLauf`). `syncNow` wartet auf laufende Uploads und lädt
  über dieselbe Bündelung hoch. Auf Uploads warten: `warteAufUebertragungen`.

### Update 2026-09-29: Schaden erhalten als Anwendungsablauf (ARCH-05)

- `lib/rules/derived/schaden_rules.dart` rechnet rein:
  `berechneSchadenspunkte` (TP − RS, nie negativ), `echteSchadenspunkte`
  (bei TP(A) die Hälfte, kaufmännisch), `schlageWundenVor` (je echt
  überschrittene Wundschwellenstufe eine Wunde, 0 bis 3; ein
  Angriffsmodifikator wie „Armbrustbolzen −2“ oder „TP(A) +2“ verschiebt alle
  drei Stufen),
  `freieWundplaetze`, `schadensZusatzwuerfe` (aus der Standard-
  Trefferzonentabelle: Kopf 2W6 INI-Malus, Brust/Bauch 1W6 SP je neuer
  Wunde, beim Erreichen der dritten Kopfwunde 2W6 SP) und `wendeSchadenAn`.
  Die Wundzahl ist nur ein **Vorschlag**, die Entscheidung trifft der
  Nutzer; die Stufen kommen aus `HeroComputedSnapshot.wundschwellenStufen`
  (mit Eisern/Glasknochen).
- `wendeSchadenAn`: senkt LeP um die echten SP plus Zusatzschaden ohne
  Untergrenze und trägt Wunden bis zur vollen Zone ein (der INI-Wurf zählt
  zur ersten Kopfwunde, der Rest verfällt und wird gemeldet). Bei Ausdauer
  (`SchadensArt.ausdauer`, TP(A)) sinken zusätzlich die AuP um die SP(A),
  höchstens bis 0, ohne Überlauf auf LeP; die echten SP sind die Hälfte der
  SP(A) und können Wunden schlagen (WdS S. 57 f.). Der Dialog belegt dafür
  den Angriffsmodifikator mit +2 vor.
- Wundschwellen (`wund_rules.dart`): drei Stufen 0,5 / 1 / 1,5 KO,
  kaufmännisch gerundet, Eisern/Glasknochen ±2 auf alle (WdS S. 58).
  `computeWundschwelle` (Inspector „WS n“) ist genau die erste Stufe.
  Eine vierte Stufe bei 2 KO gab es früher; das Regelwerk kennt sie nicht.
  Alle Annahmen sind per dsa-rules-MCP validiert, Belege in
  `docs/architecture_roadmap.md` (ARCH-05, Teilstand 4).
- `TrefferzonenZusatzwurf.wirkung` (`TrefferzonenZusatzwirkung`) sagt, ob ein
  Zusatzwurf Schaden oder den Kopf-INI-Malus liefert.
- `lib/ablaeufe/schaden_erhalten.dart` (`SchadenErhalten`, Provider
  `schadenErhaltenProvider`) bucht über `aendereGespeichertenZustand` auf den
  frischen Zustand und hängt einen Protokolleintrag an
  (`schaden_protokoll.dart`, Titel „Schaden erhalten“, `ProbeType.damage`,
  Unterzeile etwa `TP 14 − RS 3 = 11 SP · Brust · WS −2 · 1 Wunde · +4 SP
  Zusatz`, bei TP(A) `TP(A) 8 − RS 1 = 7 SP(A) · 4 SP auf LeP`, `total` =
  LeP-Verlust). Kein neuer Aufzählungswert, damit ältere
  Versionen den Eintrag lesen.
- Dialog: `showSchadenDialog` / `SchadenPanel`
  (`lib/ui/screens/workspace/schaden/`) mit TP, vorbelegtem RS
  (`combatPreviewStats.rsTotal`), Zone per Auswahl oder W20, Angriffsmodifikator,
  Vorschlag samt Schwellen, änderbarer Wundzahl, Zusatzwürfen und Vorschau.
  Fehler im Panel, Sperre während des Speicherns. Nach neuen Wunden folgt
  `bieteWundUnterdrueckungAn`: Alle Wunden eines Angriffs werden nur
  gemeinsam unterdrückt (eine Abfrage, ein Speichervorgang, Erschwernis
  über `computeSbUnterdrueckungErschwernis(neueWunden: n)`). Einstiege: Knopf im
  Inspector-Vitals-Tab und die UI2-Schnellaktion über
  `KartoBestandsAdapter.schadenErhalten`.
- Keine Rücknahme: korrigiert wird von Hand anhand des Protokolleintrags;
  eine echte Rücknahme gehört zu ARCH-06.

### Update 2026-09-30: Zonenwunden nach WdS (ARCH-05)

- **Kombiniertes System.** Die Hausregel „Erweiterung und Überarbeitung des
  Regelwerks“ (S. 3) lässt Wunden nach Gesamt- **und** Zonensystem wirken.
  `lib/rules/derived/wund_zonen_rules.dart` hält beides als Daten:
  `kWundAllgemein` (AT/PA/FK/INI-Basis/GE −2, GS −1, WdS S. 58) und
  `wundZonenWirkung` (WdS S. 108 f.: Kopf INI-Basis −2 und MU/KL/IN −2;
  Brust = Rücken AT/PA −1, KO/KK −1; Bauch zusätzlich INI-Basis und GS −1;
  Arm AT/PA −2 armgebunden, KK/FF −2; Bein AT/PA/INI-Basis −2, GS −1,
  GE −2), dazu `dritteWundeFolge` und `dritteWundeMachtKampfunfaehig`
  (nur Kopf, Brust, Rücken, Bauch). Eine pauschale Proben-Erschwernis gibt
  es nicht mehr (keine Quelle).
- **`WundEffekte`** (`wund_rules.dart`): `atMalus`/`paMalus`/`fkMalus`/
  `iniBasisMalus`/`gsMalus` gehen über `wundEffekteToStatModifiers` in die
  Basiswerte; `schwertarmAtPaMalus`/`schildarmAtPaMalus` rechnet die
  Kampfvorschau je Waffe an (`CombatPreviewStats.schwertarmWundMalus`,
  Nebenhand und `computeOffhandModifierSnapshot(schildarmWundMalus:)`; nicht
  bei Fernkampf, eine Parierwaffe hat keine eigene PA);
  `eigenschaftsVerluste` gelten nur für Proben; `aktuellerIniMalus` (Kopf-2W6)
  ist Hinweis. `computeHeroWundEffekte` liest Linkshänder
  (`ModifierParseResult.hasLinkshaenderFromVorteile`) und epische KO.
- **Probenwerte.** `HeroComputedSnapshot.probenEigenschaften` =
  `wendeWundVerlusteAn(effectiveAttributes, wundEffekte)`. Eigenschafts-,
  Talent-, Zauber- und SB-Proben würfeln dagegen (Schnellsuche, Talent- und
  Magie-Tab, Inspector, UI2-Brücke, Kopfleiste, Übersicht, Wundendialoge);
  `buildTalentProbeRequest` kennt statt `wundMalus` nur noch
  `initialSituationalModifier` (SB-Erschwernis). Spielflächen markieren den
  Abzug („Wunden −2“), die Verwaltungstabellen zeigen weiter effektive Werte.
- **GS** sinkt durch Wunden nie unter 1: `computeDerivedStatsFromInputs`
  rechnet die GS-Kette mit und ohne Wundanteil, `begrenzeWundGs` entscheidet.
- **Trefferzonen:** `resolveTrefferzone(linkshaender:)` spiegelt die Armzone,
  das Label bleibt die Armrolle; der Schadensdialog reicht den Schalter durch.
- Belege, Entscheidungen und Restrisiken: `docs/architecture_roadmap.md`
  (ARCH-05, Teilstand 6).

### Update 2026-09-29: Bogen-Sofortaktionen frisch schreiben (ARCH-05)

- Warteschlange: `ReihenfolgeJeHeld` (`lib/ablaeufe/reihenfolge_je_held.dart`)
  ist der gemeinsame Baustein: Vorgänge je Speicher und Held nacheinander,
  per `Expando` am Repository. Zustand und Bogen haben je eine eigene
  Instanz, weil sie getrennt gespeichert werden.
- `aendereGespeichertenHelden` (`lib/ablaeufe/held_schreiben.dart`) lädt den
  Bogen frisch, wendet die Änderung an und speichert über die injizierte
  Normalisierung (`BogenSpeichern`). Gibt die Änderung dasselbe Objekt
  zurück, wird nichts gespeichert. `reiheBogenvorgangEin` reiht beliebige
  Bogenvorgänge ein.
- `HeroActions.saveHero` läuft ebenfalls durch diese Warteschlange und liefert
  den normalisierten, gespeicherten Helden; der eigentliche Rumpf ist
  `_speichereNormalisiert`. So landet ein Editorentwurf nie zwischen Laden und
  Schreiben einer frischen Änderung, und die Hash-Prüfung der
  Steigerungsrunde sieht jede eingereihte Änderung. `updateHero` delegiert an
  `aendereGespeichertenHelden` und liefert den gespeicherten Helden. Eine
  Änderung darf selbst nie `saveHero`/`updateHero` aufrufen, sie wartete auf
  sich selbst.
- UI-Einstieg: `aendereHeldMitMeldung` (`lib/ui/screens/shared/zustand_aendern.dart`)
  neben `aendereZustandMitMeldung`, mit demselben Fehlerweg
  (`ZustandFehlerBereich`, sonst Snackbar; `StateError` ohne „Bad state:“).
  Bei offener Steigerungsrunde schreibt er nicht, sondern meldet
  `kBogenWaehrendPlanungGesperrt`.
- Regeln (alle ändern nur ihre Felder, rechnen vom gespeicherten Stand):
  `modifikator_aenderung_rules.dart` (`Dauermodifikator`,
  `mitDauermodifikator` mit `RessourcenAenderung`, `mitBenanntenStatModifikatoren`,
  `mitBenanntenEigenschaftsModifikatoren`), `mitApSchritt`
  (`ap_level_rules.dart`), `mitRessourcenSchaltern` (nur umgestellte
  Schalter, `resource_activation_rules.dart`), `quittiereEigenschaftsHinweis`
  (senkt nie eine neuere Schemaversion, `attribute_start_rules.dart`),
  `epic_status_rules.dart` (`aktiviereEpischenStatus` mit Start-AP und
  offenen Talenten des gespeicherten Helden, nie doppelt;
  `korrigiereEpischenStatus`), `inventar_aenderung_rules.dart`
  (`ohneInventarEintrag` findet den Eintrag über seinen Inhalt statt die
  Position und lässt die Kampfkonfiguration unberührt, `mitDukaten`,
  `mitDukatenSchritt`), `schliesseAbenteuerAb`/`oeffneAbenteuerWieder`
  (`adventure_rewards_rules.dart`, nie doppelt gebucht, Notizen des
  gespeicherten Abenteuers bleiben), `steigereBegleiter` samt
  `BegleiterSteigerungsziel` (`companion_steigerung_rules.dart`, prüft den
  Ausgangsstand) und `begleiter_aenderung_rules.dart`
  (`bucheBegleiterSteigerung`, `mitVertrautenmagieAmBegleiter`,
  `mitBegleiterStartwerten`).
- Umgestellte Sofortaktionen: Inspector-Statuswerte (Schritt vom
  gespeicherten Wert; bei offener Planung gesperrt mit Hinweis, BE bleibt),
  Wundschwellen-Zahnrad im Wundendialog (bei Planung gesperrt),
  Übersicht (Ressourcenschalter, AP addieren, Grundwert- und
  Eigenschaftsmodifikatoren, Epik, Hinweisquittung), Inventar (Löschen,
  Dukaten; Münzknöpfe melden `onSchritt`), Abenteuer abschließen und
  wiedereröffnen, Vertrauten-Steigerung. Der Ressourcendialog zeigt Fehler im
  Blatt und bleibt offen.
- Snapshots blieben hier noch die Editorentwürfe (Übersicht, Talente,
  Magie, Begleiter, Notizen, Reisebericht), eingereiht. Das
  Kampf-Sofortspeichern, der Inventareditor und die Editorentwürfe schreiben
  seit den folgenden Updates frisch.

### Update 2026-09-30: Kampf-Tab frisch schreiben (ARCH-05)

- Im Lesemodus speichert der Kampf-Tab jede Bedienung sofort: Waffen- und
  Nebenhandwahl, Entfernung, Geschosswahl und -bestand (Kampfwerte),
  Editorergebnis, Entfernen, Talent und BF (Waffen) sowie Rüstungs- und
  Nebenhandteile. Alle laufen über den einen Einstieg `_aendereKampf`
  (`hero_combat/combat_state_helpers.dart`). Im Bearbeitungsmodus ändert er
  nur den Entwurf, gespeichert wird wie bisher mit „Speichern“. Im Lesemodus
  ruft er `aendereHeldMitMeldung` mit `mitKampfAenderung`; die Slotprüfung
  (`_validateWeaponSlotsForConfig`) läuft dabei auf dem frischen Ergebnis und
  meldet sich als `StateError`. Die Einstiege je Bedienelement liegen in
  `hero_combat/combat_sofort_aenderungen.dart`.
- Regeln: `lib/rules/derived/kampf_aenderung_rules.dart` (`mitAktiverWaffe`,
  `aendereWaffe`, `mitEntfernung`, `mitGeschossWahl`, `mitGeschossSchritt`,
  `mitNeuerWaffe`, `ersetzeWaffe`, `ohneWaffe`, `mitNebenhand`,
  `mitRuestungsteil`, `ohneRuestungsteil`, `mitNebenhandTeil`,
  `ohneNebenhandTeil`). Slots werden über ihre stabile ID gefunden. Ohne ID
  zählt der Inhalt ohne IDs, die angezeigte Position hilft nur dabei. Ein
  Editorergebnis auf einen inzwischen geänderten Slot wird abgewiesen.
  Geschossschritte zählen vom gespeicherten Bestand (0 bis
  `kGeschossHoechstbestand`). Beim Entfernen rücken aktive Waffe und
  Nebenhand (`weaponIndex`/`equipmentIndex`) nach; vorher verlor die
  Nebenhand ihre Waffe oder zeigte auf das falsche Teil.
- Die Sektionen melden den **angezeigten** Slot: `WeaponSaveCallback` mit
  `ausgang` (liefert `bool`, der breite Editor bleibt bei Fehlern offen),
  `WeaponRemoveCallback`, `WeaponSlotUpdater` mit `angezeigt`, dazu
  `onPieceSaved`/`onPieceRemoved` (Rüstung) und
  `onEntrySaved`/`onEntryRemoved` (Nebenhand) statt ganzer Listen.
- Die Anzeige folgt dem gespeicherten Wert, der Entwurf wird im Lesemodus
  nicht vorab gesetzt. Scheitert eine Änderung, steigt `_steuerRevision`
  und baut Kampfwerte, Waffen und Rüstung neu auf; Auswahlfelder zeigen dann
  wieder den gespeicherten Stand.
- Vorschau: `kampfvorschau` (`hero_combat/combat_helpers.dart`) reicht
  Modifikatoren, effektive Eigenschaften, Basiswerte und Wunden aus
  `heroComputedProvider` an `computeCombatPreviewStats` durch. Kampfwerte,
  Waffentabelle und Waffeneditor rechnen damit dieselben Werte wie Inspector
  und Spielansicht; vorher fehlten dort die Wunden.
- Prüfung: `test/rules/kampf_aenderung_rules_test.dart`,
  `test/ui/combat/kampf_frisch_schreiben_test.dart` (mit
  `BogenTestRepository`) und `test/ui/combat/kampfvorschau_wunden_test.dart`.

### Update 2026-10-05: Inventareditor frisch schreiben (ARCH-05)

- Anlegen und Bearbeiten im Inventareditor (schmal als eigene Seite, breit als
  Seitenpanel) schreiben frisch über `aendereHeldImEditor`
  (`lib/ui/screens/shared/zustand_aendern.dart`). Der Einstieg prüft wie
  `aendereHeldMitMeldung` die offene Steigerungsrunde, fängt Fehler aber
  nicht: `InventoryItemEditor` zeigt sie selbst und bleibt offen.
  `aendereHeldMitMeldung` nutzt denselben Einstieg.
- Regeln in `inventar_aenderung_rules.dart`: `mitNeuemInventarEintrag` hängt
  an den gespeicherten Stand an und lässt den Kampf unberührt.
  `mitGeaendertemInventarEintrag` findet den Gegenstand, mit dem der Editor
  geöffnet wurde, über seinen Inhalt; wurde er inzwischen geändert oder
  entfernt, gibt es einen `StateError`. Ein verknüpfter Eintrag gibt seine
  Markierungen (magisch, geweiht) an seinen Slot weiter; eine im Editor
  geänderte Geschossmenge geht nur an das eigene Geschoss
  (`slotRef ?? sourceRef`). Vorher schrieb der Tab alle Geschossmengen des
  beim Rendern erfassten Inventars zurück und setzte so Bestände aus dem
  Kampf-Tab zurück.
- Der Tab merkt sich den geöffneten Gegenstand (`_bearbeiteterEintrag`) statt
  nur seiner Position. Verschiebt ein anderer Weg die Liste, bleibt der
  breite Editor bei seinem Gegenstand. Nach dem Speichern wird die Auswahl im
  gespeicherten Helden über den Inhalt bestimmt (neue Einträge von hinten,
  verknüpfte notfalls über `slotRef`).
- Instanz-IDs (ARCH-03): `saveHero` vergibt fehlenden Einträgen eine ID.
  Trägt der gesuchte Eintrag keine, zählt sie bei der Inhaltssuche
  (`findeGleichenInventarEintrag`, `findeLetztenGleichenInventarEintrag`)
  auch bei den Kandidaten nicht; ein bearbeiteter Eintrag behält seine
  gespeicherte ID.
- Prüfung: `test/rules/inventar_aenderung_rules_test.dart`,
  `test/ui/inventory/inventar_frisch_schreiben_test.dart` (mit
  `BogenTestRepository`, schmal und breit) und die Planungssperre in
  `test/ui/shared/held_frisch_schreiben_test.dart`.

### Update 2026-10-05: Editorentwürfe frisch speichern (ARCH-05)

- Alle sieben Editorentwürfe der Verwaltung (Übersicht, Talente, Magie,
  Begleiter, Notizen, Reisebericht, Kampf-Editor) speichern über
  `speichereEditorEntwurf` (`lib/ui/screens/shared/editor_entwurf_speichern.dart`):
  frisch über `aendereHeldImEditor`, eingereiht und bei offener Planung
  gesperrt.
- Jeder Tab merkt sich in `_entwurfBasis` den Helden, aus dem er seinen
  Entwurf gefüllt hat, und baut den Entwurf beim Speichern auf dieser Basis.
  `uebernimmEditorEntwurf` (`lib/rules/derived/editor_entwurf_rules.dart`)
  gleicht Basis, Entwurf und frisch geladenen Helden je oberstem
  JSON-Schlüssel ab:
  - Im Entwurf Unverändertes nimmt den gespeicherten Wert.
  - Nur im Entwurf Geändertes gewinnt.
  - `apTotal` und `apSpent` sind Zähler, die Differenz des Entwurfs wird
    addiert.
  - `level`, `apAvailable` und `unknownModifierFragments` rechnet
    `saveHero` neu.

  Ohne fremde Änderung seit der Basis wird der Entwurf unverändert
  gespeichert (bisheriges Verhalten). Sonst entsteht der Held über JSON;
  neue Kampf-Slots bekommen vorher eine UUID.
- Beidseitig verschieden geänderte Schlüssel ergeben `EditorEntwurfKonflikt`.
  Der Dialog bietet „Weiter bearbeiten“ (nichts gespeichert) oder „Meine
  Fassung speichern“ (erneuter frischer Abgleich, der Entwurf gewinnt nur in
  den bestätigten Schlüsseln). Nicht erzwingbar ist ein Konflikt, der eine
  Buchung zurücknähme: Abenteuer, deren Status oder `rewardsApplied` sich
  seit der Basis geändert hat, und geänderte angewendete
  Reisebericht-Belohnungen.
- Der Reisebericht bucht über `bucheReiseberichtEntwurf` auf den
  gespeicherten Helden (AP, SE, Boni als Zu- und Abschlag) und nie doppelt.
  Grundlage ist `berechneReiseberichtBuchung` (`reisebericht_rules.dart`).
  Alle buchbaren Posten des Katalogs haben eine ID, einen Inhalt und eine
  Bedingung. Neu gebucht wird, was im Entwurf erfüllt und nicht angewendet
  ist. Zurückgenommen wird, was gebucht war und im Entwurf nicht mehr
  erfüllt ist: Enthaken, gelöschte offene Einträge, dadurch unterschrittene
  Schwellen, Gruppen- und Meta-Boni. Ein geänderter Inhalt wird umgebucht.
  Altdaten (angewendet, aber schon vorher nicht erfüllt) bleiben. Vor einer
  Rücknahme fragt der Tab nach (`reiseberichtBuchungsaenderung`).
- Die Übersicht schreibt nur noch den Bogen. Ihre nie angezeigten
  LeP-/AuP-/AsP-/KaP-Felder setzten bisher den Laufzeitzustand vom
  Bearbeitungsbeginn zurück und machten negative LeP zu 0.
- Notizen übernehmen unberührte Listen (dieselben Einträge wie in der Basis)
  ungefiltert, damit die Bereinigung keine fremde Änderung überschreibt.
- Nach einer Vertrauten-Steigerung werden Entwurf und Basis aus dem
  gespeicherten Helden neu gefüllt.
- Prüfung: `test/rules/editor_entwurf_rules_test.dart`,
  `test/ui/shared/editor_entwurf_speichern_test.dart` und
  `test/ui/shared/editor_entwurf_frisch_test.dart` (alle sieben Tabs mit
  `BogenTestRepository`).

### Update 2026-08-23: Aventurischer Kalender und aktuelles Alter

**Kalender (`lib/domain/aventurian_date.dart`)**

- `aventurianMonths` ist die kanonische Monatsfolge: zwoelf Goettermonate zu je
  30 Tagen (Praios, Rondra, Efferd, Travia, Boron, Hesinde, Firun, Tsa, **Phex**,
  Peraine, Ingerimm, Rahja), danach die fuenf Namenlosen Tage — zusammen 365
  Tage (Geographia Aventurica, Immerwaehrender Kalender S. 253).
- Vorher fuehrte der Abenteuer-Tab eine eigene Liste **ohne Phex**. Diese Liste
  ist entfallen; `hero_adventure_dialogs.dart` delegiert an den geteilten
  Kalender. Bestandsdaten brauchen keine Migration: Monate sind Schluessel, es
  kam nur eine Option hinzu.
- `AventurianDate` haelt Tag, Monat und Jahr als `String`, weil die
  Eingabefelder Freitext zulassen und Teilangaben gueltig sind.
  `normalizeAventurianMonth`, `aventurianMonthLabel`, `aventurianMonthIndex` und
  `formatAventurianDate` (`12. Praios 1027 BF`) ergaenzen den Typ.

**Altersregel (`lib/rules/derived/aventurian_age_rules.dart`)**

- `aventurianDayOfYear` liefert `Monatsindex * 30 + Tag`; die Namenlosen Tage
  landen dadurch auf 361 bis 365.
- `parseAventurianYear` liest die erste ganze Zahl, damit `1027 BF` funktioniert.
- `resolveCurrentAdventureDate` bestimmt den Stichtag: laufende Abenteuer in
  Listenreihenfolge (`currentAventurianDate` vor `startAventurianDate`), sonst
  das zuletzt abgeschlossene (`endAventurianDate` → `currentAventurianDate` →
  `startAventurianDate`).
- `computeAventurianAge` zaehlt volle Jahre und zieht einen im laufenden Jahr
  noch ausstehenden Geburtstag ab. Fehlt Tag oder Monat, bleibt es bei der
  Jahresdifferenz; ein negatives Ergebnis liefert `null`.

**Modell und UI**

- `HeroAppearance.geburtsdatum` ist der Bezugspunkt. Es wird in `toJson` **nur
  bei belegtem Wert** geschrieben: Die Appearance-Map landet flach im
  Helden-JSON und geht in `heroContentHash` ein — ein bedingungslos emittiertes
  Feld wuerde jeden Bestandshelden veraendern und beim naechsten Speichern eine
  Sync-Konfliktwelle ausloesen.
- Die Heldenuebersicht zeigt neben dem manuellen `Alter` die beiden Felder
  `Geburtsdatum` (im Lesemodus formatiert, im Bearbeitungsmodus Tag /
  Monats-Dropdown / Jahr) und das schreibgeschuetzte `Alter (aktuell)`. Der
  Geburtsmonat liegt als Entwurfsfeld `_draftGeburtsmonat` im Tab-State, weil
  ein Dropdown sich nicht als `TextEditingController` puffern laesst.

### Update 2026-09-09: Kein App-Neuaufbau beim Speichern einer Spaltenbreite

Symptom: Im Web lud die App nach jeder verstellten Spaltenbreite im Talente-Tab
sichtbar neu (Ladeindikator statt Tabelle). Ursache war nicht die Katalogkette,
sondern der `ProviderScope` darüber.

- `AppStartupGate` hört auf `settingsRepository.watch()`. Der Listener rief bei
  **jeder** Einstellungsänderung `setState` auf, obwohl nur
  `AppSettings.heroStoragePath` das Gate betrifft. Er vergleicht jetzt den Pfad
  und baut sonst nichts neu auf.
- `_buildScope` erzeugte bei jedem Rebuild frische
  `CustomCatalogRepository`- und `HouseRulePackRepository`-Instanzen für
  `overrideWithValue`. Ohne Wertgleichheit gilt eine neue Instanz als geänderter
  Override: Riverpod benachrichtigt die Abhängigen, `houseRulePackCatalogProvider`
  und `catalogRuntimeDataProvider` laufen erneut, und jeder Tab, der auf
  `rulesCatalogProvider` wartet, fällt zurück in den Ladezustand. Beide
  Repositories haben deshalb jetzt `==`/`hashCode` über `heroStoragePath`, und
  das Bootstrap-Ergebnis hält je eine stabile Instanz.
- Regressionstest: `test/state/catalog_settings_dependencies_test.dart`
  (»rebuilding the app scope keeps the resolved catalog«) baut einen
  `ProviderScope` mit denselben Overrides neu auf und prüft, dass der aufgelöste
  Katalog identisch bleibt.
- `heroStorageLocationProvider` liest den Pfad ebenfalls selektiv, damit eine
  gespeicherte Breite die Speicherort-Karte in den Einstellungen nicht in den
  Ladezustand schickt.

---

*Erzeugt am 2026-03-04 — Bezieht sich auf Codestand `claude/create-technical-documentation-Eawbf`*

