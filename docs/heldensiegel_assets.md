# Bildsiegel v1

Die ersten vier freigegebenen Siegel sind einzeln mit dem integrierten
Imagegen-Werkzeug erzeugte, transparente PNGs. Sie folgen den vom Nutzer
freigegebenen Reliefvorlagen. Die Dateien sind Originalentwürfe für die App,
keine als offiziell ausgewiesenen Kulturwappen.

## Umfang und Zuordnung

| Datei unter `assets/ui/heldensiegel_v1/` | Zuordnung | Motiv |
| --- | --- | --- |
| `thorwaler.png` | Kultur Thorwal / Thorwaler | Schiff, Wellen, Walflosse |
| `norbarden.png` | Kultur Norbarden / Norbardensippe | Reisewagen, Rad, Gepäck |
| `novadis.png` | Kultur Novadi / Novadis | Pferdekopf, Dünen, Sonne |
| `achaz.png` | Grundmotiv Achaz / Echsenwesen | Echsenprofil, Bronze, Kristalle |

`KartoSiegelProfil.ausAngaben` liest die vorhandene Rassen- und Kulturangabe.
Bei menschlichen, halbelfischen und neutralen Grundmotiven entscheidet die
explizit eingetragene unterstützte Kultur. Nur bei leerem Kulturfeld darf
eine alte Rassenangabe wie „Thorwaler“ das Kulturbild liefern. Eine explizite
unbekannte Kultur wird dabei nicht durch vermutete Herkunft ersetzt.
Mehrdeutige Kulturangaben liefern kein zufällig gewähltes Bild. Achaz und
andere nichtmenschliche Grundmotive behalten ihr Speziesmotiv.

Die übrigen Kulturen und Spezies nutzen vorerst den bestehenden Vektorrückfall.
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

```powershell
flutter test --no-pub test/ui2/widgets/karto_siegel_assets_test.dart test/ui2/theme/karto_heldensiegel_profil_test.dart
flutter test --no-pub test/ui2/widgets/karto_siegel_assets_visual_test.dart --dart-define=SIEGEL_ASSET_PREVIEW_DIR=docs/screenshots/heldensiegel-bilder
```

Die Assettests prüfen Flutter-Bündelung, PNG-Dekodierung, Größe, sichtbaren
Inhalt und echte transparente Pixel. Die Zuordnungstests decken Kulturvorrang,
Altdaten, Halbelfen, Achaz und unbekannte oder mehrdeutige Angaben ab.
