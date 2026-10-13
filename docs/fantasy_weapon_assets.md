# Fantasy-Waffensymbole v1

29 transparente Gruppensymbole im Stil des [Fantasy-Sets](fantasy_assets.md):
Messing, Elfenbein und Petrol mit mittelalterlichen Gravuren. Erstellt mit dem
integrierten ImageGen-Werkzeug. Für die Oberfläche vorbereitet und in Flutter
registriert.

## Übersicht

[Gesamtvorschau](fantasy_weapon_assets_preview.html) lokal im Browser öffnen.
Sie zeigt alle Motive auf hellem Pergament und dunklem Grund sowie mit 48 und
64 CSS-Pixeln. Originaldateien liegen unter `assets/ui/fantasy_weapons_v1/`.

| Gruppe | Datei | Katalogwert |
| --- | --- | --- |
| Nahkampf | `melee.png` | `Nahkampf` |
| Fernkampf | `ranged.png` | `Fernkampf` |
| Anderthalbhänder | `hand_and_a_half.png` | `Anderthalbhänder` |
| Dolche | `daggers.png` | `Dolche` |
| Fechtwaffen | `fencing.png` | `Fechtwaffen` |
| Hiebwaffen | `impact.png` | `Hiebwaffen` |
| Infanteriewaffen | `polearms.png` | `Infanteriewaffen` |
| Kettenstäbe | `chain_staves.png` | `Kettenstäbe` |
| Kettenwaffen | `chain_weapons.png` | `Kettenwaffen` |
| Lanzenreiten | `lances.png` | `Lanzenreiten` |
| Raufen | `brawling.png` | `Raufen` |
| Ringen | `wrestling.png` | `Ringen` |
| Säbel | `sabres.png` | `Säbel` |
| Schwerter | `swords.png` | `Schwerter` |
| Speere | `spears.png` | `Speere` |
| Stäbe | `staves.png` | `Stäbe` |
| Zweihandflegel | `two_hand_flails.png` | `Zweihandflegel` |
| Zweihand-Hiebwaffen | `two_hand_impact.png` | `Zweihand_Hiebwaffen` |
| Zweihandschwerter und -säbel | `two_hand_swords.png` | `Zweihandschwerter_Säbel` |
| Armbrust | `crossbows.png` | `Armbrust` |
| Belagerungswaffen | `siege.png` | `Belagerungswaffen` |
| Blasrohr | `blowpipes.png` | `Blasrohr` |
| Bogen | `bows.png` | `Bogen` |
| Diskus | `discs.png` | `Diskus` |
| Peitsche | `whips.png` | `Peitsche` |
| Schleuder | `slings.png` | `Schleuder` |
| Wurfbeile | `throwing_axes.png` | `Wurfbeile` |
| Wurfmesser | `throwing_knives.png` | `Wurfmesser` |
| Wurfspeere | `javelins.png` | `Wurfspeere` |

Die beiden übergeordneten Symbole stehen für `type`. Die übrigen 27 Motive
decken die `combatSkill`-Gruppen aus `waffen.json` und die Einträge aus
`waffentalente.json` ab. Raufen und Ringen sind unbewaffnete Gruppen und
erhalten Faust- bzw. Griffmotive. Die Peitsche folgt in der Zuordnung der
vorhandenen Kataloggruppe Fernkampf.

Die Abbildungen stehen für eine Gruppe und deren typische Bauform. Individuelle
Waffenvarianten, Schilde und Parierwaffen bilden keine zusätzlichen Gruppen
dieses Satzes.

## Zuordnung und Einbindung

`assets/ui/fantasy_weapons_v1/manifest.json` ist ebenfalls ein Flutter-Asset.
Jeder Eintrag enthält `id`, `label`, `path`, `kind` und `catalogValue`.
Gruppensymbole tragen zusätzlich die stabile Talent-ID `catalogId` und die
Katalog-Waffenart `weaponType`. Bei der Auswahl `kind` zusammen mit
`catalogValue` verwenden; bei Talentlisten kann `catalogId` genutzt werden.
Die Sammeltexte in `weaponCategory` sind keine geeigneten Zuordnungsschlüssel.
Die Katalogdateien selbst werden nicht verändert.

```dart
Image.asset(
  'assets/ui/fantasy_weapons_v1/crossbows.png',
  width: 64,
  height: 64,
  fit: BoxFit.contain,
  semanticLabel: 'Armbrust',
)
```

48–64 logische Pixel sind für die Gruppensymbole vorgesehen. Lange Waffen
liegen diagonal, damit ihre Bauform sichtbar bleibt. Die PNGs ohne `color`
anzeigen. Wenn neben dem Motiv bereits eine gleichbedeutende Beschriftung steht,
`excludeFromSemantics: true` nutzen, um doppelte Screenreader-Ansagen zu vermeiden.

Die Bilder sind eigenständige UI-Motive; Zuordnung und Abbildung enthalten keine
neuen Spielregeln. Produktive Widgets verwenden weiterhin ihre bisherigen
Symbole, bis der Satz gezielt eingebunden wird.

## Herkunft und Prüfung

[Generierungsprompts](fantasy_weapon_assets_prompts.json) dokumentieren die
vollständigen Prompts je Datei. Die transparenten Original-PNGs bleiben erhalten.

`test/ui/fantasy_weapon_assets_test.dart` prüft die vollständige und eindeutige
Katalogzuordnung, das Bundling sowie die Dekodierung und Transparenz aller
29 Motive. Erweiterungen des Katalogs erfordern eine entsprechende Ergänzung
des Manifestes und gegebenenfalls neue Motive.
