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
| Sprache | Dart ^3.10.4 |
| Framework | Flutter (Material 3) |
| Zustandsverwaltung | flutter_riverpod ^2.6.1 |
| Lokale Datenbank | hive ^2.2.3, hive_flutter ^1.1.0 |
| Datei-I/O | file_picker ^8.1.4, path_provider ^2.1.5 |
| Teilen | share_plus ^10.1.2 |
| IDs | uuid ^4.5.1 |
| Linting | flutter_lints ^6.0.0 |
| Tests | flutter_test, integration_test |

### Schichtenarchitektur

```
UI (flutter_riverpod ConsumerWidgets)
        │  .watch() / .read()
        ▼
State Layer (Riverpod Providers — lib/state/)
        │  liest/schreibt
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
State Layer verbindet beides reaktiv über Riverpod.

### App-Start (`lib/main.dart`)

Seit 2026-03-13 laeuft der Start in zwei Stufen: Zuerst wird ein lokaler
Einstellungsordner fuer `HiveSettingsRepository` vorbereitet. Danach loest
`AppStartupGate` den effektiven Heldenspeicherpfad auf, initialisiert
`HiveHeroRepository` mit diesem Ordner und fuehrt anschliessend den
Seed-Import aus. Auf Web wird statt eines nativen Ordners ein logischer
`Browser-Speicher`-Pfad verwendet, damit der Start ohne `path_provider`
funktioniert.

```
main()
  1. Flutter-Binding initialisieren
  2. HiveHeroRepository.create() (async — öffnet Hive-Boxen)
  3. StartupHeroImporter.importFromAssets() (Seed-Helden laden)
  4. ProviderScope mit Repository-Override starten
  5. DsaApp (Material 3, Seed-Color #2A5A73, Font Merriweather)
```

### App-weites Tablet-Layout

Seit 2026-04-12 nutzt die UI ein gemeinsames Layoutmodell für breite
Oberflächen:

- `lib/ui/config/app_layout.dart` klassifiziert Fenster in `compact`,
  `tabletPortrait`, `tabletLandscape` und `desktopWide`.
- `lib/ui/widgets/codex_split_view.dart` kapselt wiederverwendbare
  Split-Layouts für Master-Detail-Ansichten.
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

**Datei:** `lib/domain/hero_sheet.dart` | **Schema-Version:** 23

`HeroSheet` enthält alle dauerhaft gespeicherten Heldendaten. Laufzeitwerte
(aktuelle LeP etc.) werden separat in `HeroState` gespeichert.

#### Felder

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | `String` | Eindeutige UUID; bleibt über Exporte stabil |
| `schemaVersion` | `int` (= 23) | Format-Version fuer Migrationskompatibilitaet |
| `name` | `String` | Anzeigename des Helden |
| `level` | `int` | Stufe (wird aus `apSpent` berechnet) |
| `rawStartAttributes` | `Attributes` | Beim Anlegen erfasste Roh-Startwerte vor R/K/P-Modifikatoren |
| `attributes` | `Attributes` | Aktuelle Eigenschaftswerte (8 Werte) |
| `startAttributes` | `Attributes` | Effektive Starteigenschaften nach Rasse/Kultur/Profession |
| `persistentMods` | `StatModifiers` | Dauerhafte Modifikatoren (aus Vor-/Nachteilen) |
| `bought` | `BoughtStats` | Gekaufte Ressourcenerhöhungen |
| `combatConfig` | `CombatConfig` | Gesamte Kampfkonfiguration |
| `combatConfig.waffenmeisterschaften` | `List<WaffenmeisterConfig>` | Waffenmeister-Baukasten mit Waffenart, Boni und Voraussetzungen |
| `talents` | `Map<String, HeroTalentEntry>` | Alle Talente (Schlüssel: Talent-ID) |
| `metaTalents` | `List<HeroMetaTalent>` | Heldenspezifische Meta-Talente mit Komponenten, Eigenschaften und BE-Regel |
| `hiddenTalentIds` | `List<String>` | IDs ausgeblendeter Talente |
| `talentSpecialAbilities` | `List<TalentSpecialAbility>` | Strukturierte Talent-Sonderfertigkeiten (Name + optionale Notiz), Legacy-Strings werden tolerant migriert |
| `spells` | `Map<String, HeroSpellEntry>` | Aktivierte oder gelernte Zauber des Helden |
| `ritualCategories` | `List<HeroRitualCategory>` | Heldenspezifische Ritualkategorien mit Ritualkenntnis oder Talentbezug |
| `magicLeadAttribute` | `String` | Globale Leiteigenschaft für magische Regeneration (`MU` bis `KK`) |
| `rasse` / `rasseModText` | `String` | Rasse und Rassenmodifikator-Text |
| `kultur` / `kulturModText` | `String` | Kultur und Kulturmodifikator-Text |
| `profession` / `professionModText` | `String` | Profession und Professions-Mod-Text |
| `geschlecht`, `alter`, `groesse`, `gewicht` | `String` | Körperdaten |
| `haarfarbe`, `augenfarbe`, `aussehen` | `String` | Äußere Erscheinung |
| `stand`, `titel` | `String` | Sozialer Stand und Titel |
| `familieHerkunftHintergrund` | `String` | Familiengeschichte/Herkunft |
| `sozialstatus` | `int` | Numerischer Sozialstatus |
| `vorteileText` / `nachteileText` | `String` | Freitext Vor-/Nachteile (wird geparsed) |
| `apTotal` | `int` | Gesamte Abenteuerpunkte |
| `apSpent` | `int` | Ausgegebene Abenteuerpunkte |
| `apAvailable` | `int` | Verfügbare AP (= apTotal − apSpent) |
| `dukaten` | `String` | Geldmenge (Freitext) |
| `resourceActivationConfig` | `HeroResourceActivationConfig` | Nullable Auto-/Override-Schalter fuer Magie und goettliche Ressourcen |
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

In `HeroSheet` werden `persistentMods` (aus geparsten Vor-/Nachteilen, dauerhaft) und in
`HeroState` `tempMods` (temporär, z. B. durch Zauber) unterschieden.

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
| `anzahl` | Menge |
| `amKoerper` | Am Körper getragen? |
| `woDann` | Aufbewahrungsort |
| `gruppe` | Gruppe/Kategorie |
| `beschreibung` | Beschreibung |
| `itemType` | Typisierte Inventarkategorie (`ausruestung`, `verbrauchsgegenstand`, `wertvolles`, `sonstiges`) |
| `source` | Herkunft des Eintrags (`manuell`, Kampf-Sync oder `abenteuer`) |
| `sourceRef` | Stabile Referenz fuer synchronisierte oder abenteuerbezogene Eintraege |
| `istAusgeruestet` | Steuert, ob Modifier des Eintrags aktiv wirken |
| `modifiers` | Typisierte Inventar-Modifikatoren |
| `gewichtGramm` | Numerisches Gewicht in Gramm |
| `wertSilber` | Numerischer Wert in Silbertalern |
| `herkunft` | Fundort, Quelle oder Haendler |
| `isMagisch` / `magischDescription` | Magische Markierung und Beschreibung |
| `isGeweiht` / `geweihtDescription` | Geweihte Markierung und Beschreibung |
| `traegerTyp` / `traegerId` | Zuordnung zum Helden oder zu einem Begleiter |

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
| `metadata` | `Map<String, dynamic>` | Weitere Metadaten |

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

`Mod` = Summe aus `persistentMods` + `tempMods` für den jeweiligen Wert.

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
| `rsTotal` | Summe `rs` aller aktiven `ArmorPiece` |
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
- `Schnellladen (Bogen)` verkuerzt die Ladezeit um `1`; bei bereits besessener
  SF reduziert Axxeleratus die Ladezeit um einen weiteren Punkt.
- `Schnellladen (Armbrust)` reduziert die Ladezeit um `3/4` der Basis-
  Ladezeit, echt gerundet; bei bereits besessener SF reduziert Axxeleratus
  anschliessend um einen weiteren Punkt.
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

Parst Freitext-Felder (`vorteileText`, `nachteileText`, `rasseModText`, …) in strukturierte
Modifikatoren.

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

Trenner: Zeilenumbrüche, Kommas, Semikolons. Nicht erkannte Fragmente landen in
`unknownFragments` (→ `HeroSheet.unknownModifierFragments` für UI-Hinweis).

**Performance:** LRU-Cache mit 512 Einträgen für häufig wiederholte Texte.

### 4.8 AP & Level

**Datei:** `lib/rules/derived/ap_level_rules.dart`

```
level         = floor(sqrt(apSpent / 50 + 0.25) + 0.5)
apAvailable   = max(0, apTotal − apSpent)
```

---

## 5. Zustandsverwaltung (State Layer)

### 5.1 Provider-Übersicht

**Hauptdateien:** `lib/state/hero_providers.dart`, `lib/state/hero_base_providers.dart`,
`lib/state/catalog_providers.dart`

| Provider | Typ | Zweck |
|---|---|---|
| `heroRepositoryProvider` | `Provider<HeroRepository>` | Repository (beim Start überschrieben) |
| `heroTransferCodecProvider` | `Provider<HeroTransferCodec>` | JSON-Codec für Im-/Export |
| `heroTransferFileGatewayProvider` | `Provider<HeroTransferFileGateway>` | Plattform-I/O |
| `selectedHeroIdProvider` | `StateProvider<String?>` | Aktuell gewählte Held-ID |
| `heroIndexProvider` | `StreamProvider<HeroIndexSnapshot>` | Alle Helden reaktiv |
| `heroListProvider` | `StreamProvider<List<HeroSheet>>` | Sortierte Heldenliste |
| `heroByIdProvider(id)` | `Provider.family<HeroSheet?>` | O(1) Lookup per ID |
| `heroStateProvider(id)` | `StreamProvider.family<HeroState>` | Laufzeitzustand |
| `heroComputedProvider(id)` | `Provider.family<AsyncValue<HeroComputedSnapshot>>` | Alle abgeleiteten Werte |
| `effectiveAttributesProvider(id)` | `Provider.family<AsyncValue<Attributes>>` | Effektive Eigenschaften |
| `derivedStatsProvider(id)` | `Provider.family<AsyncValue<DerivedStats>>` | Abgeleitete Werte |
| `combatPreviewProvider(id)` | `Provider.family<AsyncValue<CombatPreviewStats>>` | Kampfvorschau |
| `heroActionsProvider` | `Provider<HeroActions>` | Schreiboperationen |
| `catalogLoaderProvider` | `Provider<CatalogLoader>` | Katalog-Lader |
| `customCatalogRepositoryProvider` | `Provider<CustomCatalogRepository>` | Datei-I/O fuer synchronisierbare Custom-Kataloge |
| `baseCatalogSourceDataProvider` | `FutureProvider<CatalogSourceData>` | Roh-Sektionen aus Assets (mit `enc:`-Praefixen) |
| `decryptedCatalogSourceDataProvider` | `FutureProvider<CatalogSourceData>` | Bulk-entschluesselte Quelle (Pre-Stage vor Runtime, siehe 5.3) |
| `catalogRuntimeDataProvider` | `FutureProvider<CatalogRuntimeData>` | Basis + Custom + Fehlerzustand |
| `catalogAdminSnapshotProvider` | `FutureProvider<CatalogAdminSnapshot>` | Settings-Katalogverwaltung |
| `rulesCatalogProvider` | `FutureProvider<RulesCatalog>` | Geladener Katalog |
| `talentBeOverrideProvider(id)` | `StateProvider.family<bool?>` | Manuelle BE-Überschreibung |
| `talentsVisibilityModeProvider(id)` | `StateProvider.family<bool>` | Verborgene Talente zeigen |
| `combatTalentsVisibilityModeProvider(id)` | `StateProvider.family<bool>` | Kampftalente einblenden |

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

- Watcht `appSettingsProvider.catalogContentPassword`. Ohne Passwort wird
  die Quelle unveraendert durchgereicht; geschuetzte Felder bleiben mit
  `enc:`-Praefix bestehen und die UI zeigt einen Locked-Hinweis.
- Mit Passwort ruft er `decryptAllCatalogValues` auf. Der Runner zaehlt die
  `enc:`-Werte: ab 64 wird der Bulk-Decrypt via `compute()` auf einen Web
  Worker / Isolate ausgelagert, sonst synchron im aufrufenden Thread.
- v3-Werte nutzen den globalen Salt aus `manifest.catalog_salt_v3` — eine
  einzige PBKDF2-Ableitung pro Passwort, danach AES-GCM pro Wert (<1 ms).
  v2/v1-Werte bleiben rueckwaertskompatibel und laufen ueber den
  langsameren Per-Wert-Pfad bis zur Migration der Assets.

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
| `hero_overview_tab.dart` | `HeroOverviewTab` | Uebersicht-Tab fuer Eigenschaften, AP, Ressourcen, Biografie |
| `hero_talents_tab.dart` | `HeroTalentsTab` | Talente, strukturierte Talent-Sonderfertigkeiten und Meta-Talente |
| `hero_combat_tab.dart` | `HeroCombatTab` | Kampftechniken, Waffen, Kampf (Nah- oder Fernkampf), SF, Manöver und Kampfmeisterschaften |
| `hero_magic_tab.dart` | `HeroMagicTab` | Zauber, Ritualkategorien/Rituale, Repräsentationen, magische SF und globale Leiteigenschaft |
| `hero_inventory_tab.dart` | `HeroInventoryTab` | Direkte Inventartabelle mit AppBar-Aktion, Split-Editor und Sofortspeicherung |
| `hero_notes_tab.dart` | `HeroNotesTab` | Untertabs fuer Chroniken, Kontakte und Abenteuer mit Chip-Workspace, Popups und gefuehrtem Abenteuer-Abschluss |
| `hero_detail_screen.dart` | `HeroDetailScreen` | Legacy-Platzhalter (nicht eingebunden) |

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
- Die aktuelle `schemaVersion` fuer `HeroSheet` ist **23**, fuer `HeroState` **5**.
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
  Datumsangaben fuer Abenteuer.
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

---

*Erzeugt am 2026-03-04 — Bezieht sich auf Codestand `claude/create-technical-documentation-Eawbf`*

