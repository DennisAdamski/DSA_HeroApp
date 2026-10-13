# Fantasy-Assets v1

Ein zusammengehöriger Satz für die DSA-Heldenverwaltung: mittelalterliche
Buchillustrationen und Gravuren in Messing, Elfenbein und Petrol, passend zu
Codex und Kartograph. Erstellt mit dem integrierten ImageGen-Werkzeug.

## Dateien und Vorschau

Ergänzung: [29 Waffengruppen-Symbole](fantasy_weapon_assets.md) mit eigener
Vorschau und eindeutiger Katalogzuordnung.

[Gesamtvorschau auf hellen und dunklen Flächen](fantasy_assets_preview.html).
Die Vorschau lokal im Browser öffnen; sie lädt ausschließlich die PNGs aus
dem Repository. Sie zeigt die Symbole zusätzlich in 32 und 48 CSS-Pixeln.

| Verwendung | Asset-Pfad |
| --- | --- |
| Held | `assets/ui/fantasy_v1/hero.png` |
| Kampf | `assets/ui/fantasy_v1/combat.png` |
| Talente | `assets/ui/fantasy_v1/talents.png` |
| Magie | `assets/ui/fantasy_v1/magic.png` |
| Liturgien | `assets/ui/fantasy_v1/liturgies.png` |
| Inventar | `assets/ui/fantasy_v1/inventory.png` |
| Begleiter | `assets/ui/fantasy_v1/companion.png` |
| Abenteuer | `assets/ui/fantasy_v1/adventure.png` |
| Notizen | `assets/ui/fantasy_v1/notes.png` |
| Steigerung | `assets/ui/fantasy_v1/advancement.png` |
| Lebensenergie | `assets/ui/fantasy_v1/vitality.png` |
| Würfel | `assets/ui/fantasy_v1/dice.png` |
| Heldenwappen | `assets/ui/fantasy_v1/hero_crest.png` |
| Kapitelornament | `assets/ui/fantasy_v1/chapter_ornament.png` |
| Abenteuerbuch | `assets/ui/fantasy_v1/adventure_book.png` |

Alle PNGs haben einen transparenten Hintergrund. Die Originalauflösung bleibt
erhalten. Die Symbole eignen sich für Abschnittsüberschriften und größere
Navigationsflächen; bevorzugt 48–64 logische Pixel nutzen. Für sehr kleine
Bedienelemente sind die vorhandenen Material-Symbole weiterhin geeigneter.
Die drei dekorativen Motive sind für Header und Leerzustände ab etwa 160 Pixeln
vorgesehen. Das Kapitelornament ist horizontal innerhalb einer transparenten
Bildfläche angelegt; beim Einbinden dessen transparenten Außenraum beachten.

## Flutter-Einbindung

Der Ordner ist bereits in `pubspec.yaml` registriert. Beispiel für ein
beschriftetes Symbol:

```dart
Image.asset(
  'assets/ui/fantasy_v1/magic.png',
  width: 48,
  height: 48,
  fit: BoxFit.contain,
  semanticLabel: 'Magie',
)
```

Dekorative Motive ohne eigene Bedeutung erhalten
`excludeFromSemantics: true`, damit Screenreader sie nicht zusätzlich vorlesen.
Wenn eine benachbarte Beschriftung das Symbol bereits erklärt, gilt das auch
für dieses Symbol. Die mehrfarbigen PNGs ohne `color` anzeigen; eine Tönung
würde die Gravurfarben ersetzen.

Dekorationen in Codex an `CodexTheme.showDecoration` binden; für Kartograph
die vorhandene Dekorationssteuerung der jeweiligen Ansicht berücksichtigen.
Bei ausgeschalteter Dekoration müssen Beschriftungen und Bedienung vollständig
erhalten bleiben.

## Herkunft und Erweiterung

`fantasy_assets_prompts.json` enthält die vollständigen Generierungsprompts
je Datei. Die Motive enthalten keine offizielle DSA-Ikonografie und stellen
keine regeltechnischen Zuordnungen zu konkreten Gottheiten oder Traditionen dar.
Neue Motive als eigene Dateien ergänzen; verwendete Bestandsassets nicht
überschreiben.

Die Registrierung und PNG-Dekodierung aller 15 Assets einschließlich Alpha-Kanal
prüft `test/ui/fantasy_assets_test.dart`. Die sichtbare Oberfläche verwendet
weiterhin ihre bisherigen Motive; dieser Satz steht für die spätere Einbindung
bereit.
