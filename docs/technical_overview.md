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
Seed-Import aus.

```
main()
  1. Flutter-Binding initialisieren
  2. HiveHeroRepository.create() (async — öffnet Hive-Boxen)
  3. StartupHeroImporter.importFromAssets() (Seed-Helden laden)
  4. ProviderScope mit Repository-Override starten
  5. DsaApp (Material 3, Seed-Color #2A5A73, Font Merriweather)
```

---

## 2. Datenmodelle (Domain Layer)

Alle Domain-Modelle sind **unveränderlich** (immutable): `final`-Felder,
`const`-Konstruktoren, `copyWith()` für Updates, `toJson()`/`fromJson()` für
Serialisierung. Das `fromJson()` ist immer **lenient** (tolerant gegenüber fehlenden
Feldern; `?? Standardwert` für jedes Feld).

### 2.1 `HeroSheet` — Persistierte Heldendaten

**Datei:** `lib/domain/hero_sheet.dart` | **Schema-Version:** 15

`HeroSheet` enthält alle dauerhaft gespeicherten Heldendaten. Laufzeitwerte
(aktuelle LeP etc.) werden separat in `HeroState` gespeichert.

#### Felder

| Feld | Typ | Bedeutung |
|---|---|---|
| `id` | `String` | Eindeutige UUID; bleibt über Exporte stabil |
| `schemaVersion` | `int` (= 15) | Format-Version für Migrationskompatibilität |
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
| `talentSpecialAbilities` | `String` | Freitexte für Sonderfertigkeiten |
| `spells` | `Map<String, HeroSpellEntry>` | Aktivierte oder gelernte Zauber des Helden |
| `ritualCategories` | `List<HeroRitualCategory>` | Heldenspezifische Ritualkategorien mit Ritualkenntnis oder Talentbezug |
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
| `inventoryEntries` | `List<HeroInventoryEntry>` | Ausrüstung/Inventar |
| `notes` | `List<HeroNoteEntry>` | Freie Notizen mit Titel und Beschreibung |
| `connections` | `List<HeroConnectionEntry>` | Kontakte/Verbindungen mit Ort, Sozialstatus, Loyalität und Beschreibung |
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

**Datei:** `lib/domain/hero_state.dart` | **Schema-Version:** 2

Enthält ausschließlich zur Laufzeit veränderliche Werte. Wird separat von `HeroSheet`
persistiert (eigene Hive-Box `hero_states_v1`).

| Feld | Typ | Bedeutung |
|---|---|---|
| `schemaVersion` | `int` (= 2) | Format-Version |
| `currentLep` | `int` | Aktuelle Lebenspunkte |
| `currentAsp` | `int` | Aktuelle Astralpunkte |
| `currentKap` | `int` | Aktuelle Karmapunkte |
| `currentAu` | `int` | Aktueller Ausdauerwert |
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
| `kkBase` | `int` | KK-Basis für TP-Bonus-Berechnung |
| `kkThreshold` | `int` | KK-Schwelle für TP-Schritte |
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
| `activeCombatSpecialAbilityIds` | `List<String>` — Aktiv geschaltete katalogbasierte Kampf-Sonderfertigkeiten |
| `gladiatorStyleTalent` | `String` | Talentwahl fuer den Gladiatorenstil (`raufen` oder `ringen`) |
| `activeManeuvers` | `List<String>` — Manuell aktivierte Manöver-IDs |

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

Repräsentiert einen Inventargegenstand (alle Felder `String`, Standard `''`):

| Feld | Bedeutung |
|---|---|
| `gegenstand` | Gegenstandsname |
| `woGetragen` | Wo getragen |
| `typ` | Typ/Kategorie |
| `welchesAbenteuer` | In welchem Abenteuer erworben |
| `gewicht` | Gewicht |
| `wert` | Wert |
| `artefakt` | Artefakt-Kennzeichnung |
| `anzahl` | Menge |
| `amKoerper` | Am Körper getragen? |
| `woDann` | Aufbewahrungsort |
| `gruppe` | Gruppe/Kategorie |
| `beschreibung` | Beschreibung |

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
| `transferSchemaVersion` (const) | `1` | Export-Formatversion (strict) |
| `exportedAt` | `DateTime` (UTC) | Exportzeitpunkt |
| `hero` | `HeroSheet` | Persistierte Heldendaten |
| `state` | `HeroState` | Laufzeitzustand zum Exportzeitpunkt |

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
| `reloadTime` | Feste Ladezeit von Fernkampfwaffen |
| `rangedDistanceBands` | Optionale Vorlage für die 5 Distanzstufen einer Fernkampfwaffe |
| `rangedProjectiles` | Optionale Geschoss-Vorlagen |
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
| `active` | Im App verfügbar? |

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

**Dateipfad:** `assets/catalogs/house_rules_v1/`

```
manifest.json          ← Einstiegspunkt; enthält Dateipfade der Teilkataloge
talente.json           ← Nicht-Kampftalente (group != 'Kampftalent')
waffentalente.json     ← Kampftalente (group == 'Kampftalent')
waffen.json            ← Waffen
magie.json             ← Zaubersprüche
manoever.json          ← Manöver (optional)
kampf_sonderfertigkeiten.json ← Kampf-Sonderfertigkeiten (optional)
```

**`CatalogLoader.loadFromAsset()`** (`lib/catalog/catalog_loader.dart`):

1. `manifest.json` laden (Dateipfade, Version, Metadaten)
2. Alle Teilkataloge laden (relative Pfade auflösen)
3. **Kampf-Split validieren**: `talente.json` darf keine `'Kampftalent'`-Einträge enthalten;
   `waffentalente.json` muss ausschließlich `'Kampftalent'`-Einträge enthalten
4. **IDs validieren**: Jede Sektion muss eindeutige, nicht-leere IDs haben
5. Zusammengeführten `RulesCatalog` zurückgeben

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
| Flink (Vorteil) | +1 |
| Behäbig (Nachteil) | −1 |

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
| `TaW berechnet` | `Roh-TaW + eBE` |
| `max TaW` | bestehende Talent-Maximum-Logik ueber die drei konfigurierten Eigenschaften |

Kampftalente duerfen als Komponenten referenziert werden; dabei zaehlt nur
deren `talentValue`, nicht `AT` oder `PA`.

### 4.5 Ausweichen

**Datei:** `lib/rules/derived/ausweichen_rules.dart`

```
sfAusweichenBonus = 3×AusweichenI + 3×AusweichenII + 3×AusweichenIII + Flink − Behäbig
akrobatikBonus    = max(0, floor((AkrobatikTaW − 9) / 3))
Ausweichen        = max(0, PABasis + sfBonus + akrobatikBonus + manualMod − beKampf)
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
`lib/rules/derived/maneuver_rules.dart`

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
| `rulesCatalogProvider` | `FutureProvider<RulesCatalog>` | Geladener Katalog |
| `talentBeOverrideProvider(id)` | `StateProvider.family<bool?>` | Manuelle BE-Überschreibung |
| `talentsVisibilityModeProvider(id)` | `StateProvider.family<bool>` | Verborgene Talente zeigen |
| `combatTalentsVisibilityModeProvider(id)` | `StateProvider.family<bool>` | Kampftalente einblenden |

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
| `hero_talents_tab.dart` | `HeroTalentsTab` | Talente + Sonderfertigkeiten-Sub-Tab |
| `hero_combat_tab.dart` | `HeroCombatTab` | Kampftechniken, Waffen, Kampf (Nah- oder Fernkampf), SF, Manöver und Kampfmeisterschaften |
| `hero_magic_tab.dart` | `HeroMagicTab` | Zauber, Ritualkategorien/Rituale sowie Repräsentationen und magische SF |
| `hero_inventory_tab.dart` | `HeroInventoryTab` | 12-spaltige editierbare Inventartabelle |
| `hero_notes_tab.dart` | `HeroNotesTab` | Untertabs für freie Notizen und Verbindungen |
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

Jeder Tab verwaltet seinen Draft-State lokal (z. B. `_draftTalents`,
`_draftCombatConfig`) und synchronisiert beim Laden/Speichern mit dem Repository.

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

```

Für echte Frame-Messungen wird kein dedizierter Integration-Test mehr
mitgeführt. Bei Bedarf erfolgt Profiling ad hoc über Flutter DevTools auf
einem Zielgerät im Profile-Modus.

### Serialisierungskompatibilität

- `fromJson()` ist in **allen** Domain-Modellen lenient: jedes Feld verwendet `?? Standardwert`.
- Die aktuelle `schemaVersion` für `HeroSheet` ist **15**.
- Beim Hinzufügen neuer Felder: immer einen Standardwert in `fromJson()` angeben.
- `HeroTransferBundle.transferSchemaVersion` = 1 wird **strikt** validiert.

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
- Wurfergebnisse bleiben bewusst temporaer im Dialog und werden nicht in
  `HeroSheet` oder `HeroState` persistiert.

---

*Erzeugt am 2026-03-04 — Bezieht sich auf Codestand `claude/create-technical-documentation-Eawbf`*

