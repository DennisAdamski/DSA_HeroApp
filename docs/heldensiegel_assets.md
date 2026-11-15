# Bildsiegel v1

Die 20 freigegebenen Bildsiegel sind einzeln mit dem integrierten
Imagegen-Werkzeug erzeugte, transparente PNGs. Sie folgen den vom Nutzer
freigegebenen Reliefvorlagen. Die Dateien sind Originalentwürfe für die App,
keine als offiziell ausgewiesenen Kulturwappen.

## Umfang und Zuordnung

| Datei unter `assets/ui/heldensiegel_v1/` | Zuordnung | Motiv |
| --- | --- | --- |
| `thorwaler.png` | Kultur Thorwal / Thorwaler | Schiff, Wellen, Walflosse |
| `norbarden.png` | Kultur Norbarden / Norbardensippe | Reisewagen, Rad, Gepäck |
| `novadis.png` | Kultur Novadi / Novadis | Pferdekopf, Dünen, Sonne |
| `mittelreicher.png` | Kultur Mittelreich | Löwe, Stadttor |
| `horasier.png` | Kultur Horasreich / Horasier | Rapier, Feder, Lorbeer |
| `tulamiden.png` | Kultur Tulamiden / Mhanadistan | Palastbogen, Öllampe, Palmzweig |
| `nivesen.png` | Kultur Nivesen | Wolf, Schnee, Nadelbäume |
| `bornlaender.png` | Kultur Bornland | Bär, Tannenzweig, Tor |
| `maraskaner.png` | Kultur Maraskan | Geschwungene Klinge, Farn |
| `alanfaner.png` | Kultur Al’Anfa | Rabe, Palmzweig |
| `andergaster.png` | Kultur Andergast | Eichenblatt, Eicheln, Axt |
| `nostrier.png` | Kultur Nostria | Fisch, Wellen |
| `neutral.png` | Fehlende oder unbekannte Rasse | Kompass, Reisepergament |
| `mensch.png` | Menschen ohne unterstützte eindeutige Kultur | Allgemeines heraldisches Relief |
| `elf.png` | Elfen | Elfenprofil, Blattrahmen |
| `halbelf.png` | Halbelfen ohne unterstützte eindeutige Kultur | Halbelfenprofil, gemischte Fassung |
| `zwerg.png` | Zwerge | Bartrelief in Stein und Bronze |
| `achaz.png` | Grundmotiv Achaz / Echsenwesen | Echsenprofil, Bronze, Kristalle |
| `ork.png` | Orks | Dunkles Orkrelief mit Hauern |
| `goblin.png` | Goblins | Rötliches Goblinrelief |

`KartoSiegelProfil.ausAngaben` liest die vorhandene Rassen- und Kulturangabe.
Bei menschlichen, halbelfischen und neutralen Grundmotiven entscheidet die
explizit eingetragene unterstützte Kultur. Nur bei leerem Kulturfeld darf
eine alte Rassenangabe wie „Thorwaler“ das Kulturbild liefern. Eine explizite
unbekannte Kultur wird dabei nicht durch vermutete Herkunft ersetzt.
Mehrdeutige Kulturangaben liefern kein zufällig gewähltes Bild. Achaz und
andere nichtmenschliche Grundmotive behalten ihr Speziesmotiv.

Es gibt zwölf Kulturbilder und acht vollständige Grundmotive. Unbekannte oder
mehrdeutige Kulturen zeigen das allgemeine Bild der erfassten Spezies;
unbekannte oder mehrdeutige Spezies erhalten das neutrale Kompassbild.
„Mittelländer“ als Rasse wird ohne Kulturangabe nicht zu „Mittelreich“ umgedeutet.
Die Kulturdefinitionen bündeln Dateikennung, Tooltip und explizite Aliase in
`KartoSiegelKultur`; neue Motive benötigen keine zusätzlichen Widgets.
Es gibt keinen neuen Speicherweg und keine Änderung an Heldendaten oder Regeln.
Magie und Karma kommen weiterhin ausschließlich aus dem berechneten Snapshot.

## Darstellung

- `KartoHeldensiegel` verwendet `Image.asset` ohne Farbtönung mit
  `BoxFit.contain`, echter Alpha-Transparenz und einem Vektorrückfall bei Fehlern.
- Die Dekodiergröße folgt Anzeigegröße und Pixeldichte, maximal 512 Pixel.
  Die hochauflösenden Originale bleiben als Assetquelle erhalten.
- Astrale und karmale Zusatzzeichen bleiben getrennte Flutter-Zeichenebenen.
- Der bestehende endliche Auftritt bleibt über Animationen, dekorative Effekte
  und Systemreduktion abschaltbar. Es gibt keine animierten Bilddateien.
- Der Spieltisch-Kopf reserviert 48 dp, Porträtplakette und Magiekopf 40 dp.
  Jeweils 8 dp davon gehören zum Lichtsaum. Das Heldenporträt wird nicht ersetzt.

## Vorschau und Prüfung

[Echte Flutter-Einbauvorschau](screenshots/heldensiegel-bilder/erste-vier.png)
mit den vier Bildern, Headern, 32/40/48-Pixel-Anzeigen und dunkler Porträtfläche.

[Vollständige Flutter-Übersicht](screenshots/heldensiegel-bilder/alle-siegel.png)
zeigt alle 20 Bildsiegel, jeweils zusätzlich mit 40 Pixeln auf hellem und dunklem Grund.

```powershell
flutter test --no-pub test/ui2/widgets/karto_siegel_assets_test.dart test/ui2/theme/karto_heldensiegel_profil_test.dart
flutter test --no-pub test/ui2/widgets/karto_siegel_assets_visual_test.dart --dart-define=SIEGEL_ASSET_PREVIEW_DIR=docs/screenshots/heldensiegel-bilder
flutter test --no-pub test/ui2/widgets/karto_siegel_katalog_visual_test.dart --dart-define=SIEGEL_ASSET_PREVIEW_DIR=docs/screenshots/heldensiegel-bilder
```

Die Assettests prüfen Flutter-Bündelung, PNG-Dekodierung, Größe, sichtbaren
Inhalt und echte transparente Pixel. Die Zuordnungstests decken Kulturvorrang,
Altdaten, Halbelfen, Achaz und unbekannte oder mehrdeutige Angaben ab.
