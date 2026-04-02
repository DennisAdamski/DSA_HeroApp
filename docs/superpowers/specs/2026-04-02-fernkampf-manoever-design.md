# Design: Fernkampf-Manöver

**Datum:** 2026-04-02  
**Branch:** task/2026-03-31-kampf-sf-katalog  
**Status:** Genehmigt

---

## Ziel

Sechs Fernkampf-Sonderfertigkeiten aus `kampf_sonderfertigkeiten.json` werden als echte Manöver in `manoever.json` überführt. Scharfschütze und Meisterschütze unterstützen eine Per-Talent-Aktivierung: in der UI erscheint ein Toggle je aktiv geführtem Fernkampftalent. Andere Fernkampf-Manöver werden nur angezeigt, wenn die passende Waffe in der Haupthand aktiv ist.

---

## Entscheidungen

| Frage | Entscheidung |
|-------|-------------|
| Welche Fernkampf-Talente für Scharfschütze/Meisterschütze? | Alle 10 Fernkampftalente |
| Schnellladen-Migration | Vollständige Migration: Booleans → `activeManeuvers` |
| UI-Gruppierung | Eigener Bereich „Fernkampf-Manöver" |
| Wann per-Talent-Manöver sichtbar? | Nur wenn das entsprechende Talent in der aktiven Haupthand geführt wird |

---

## 1. Katalog-Änderungen

### 1.1 `kampf_sonderfertigkeiten.json` — 6 Einträge entfernen

- `ksf_berittener_schuetze`
- `ksf_eisenhagel`
- `ksf_scharfschuetze`
- `ksf_meisterschuetze`
- `ksf_schnellladen_bogen`
- `ksf_schnellladen_armbrust`

### 1.2 `manoever.json` — 6 neue Einträge

Alle mit `"gruppe": "fernkampf"`. Neue optionale Felder:

| JSON-Feld | Typ | Bedeutung |
|-----------|-----|-----------|
| `nur_fuer_talente` | `List<String>` | Leer = alle FK-Talente; sonst nur sichtbar wenn aktive Hauptwaffe das Talent nutzt |
| `muss_separat_erlernt_werden` | `bool` | Per-Talent-Toggle via Composite-ID |
| `gilt_fuer_talent_typ` | `String` | `"fernkampf"` — filtert Talente für `mussSeperatErlerntWerden` |

**Neue Einträge:**

| ID | Name | `nur_fuer_talente` | `muss_separat_erlernt_werden` |
|----|------|--------------------|-------------------------------|
| `man_berittener_schuetze` | Berittener Schütze | `[]` | `false` |
| `man_eisenhagel` | Eisenhagel | `["tal_wurfmesser"]` | `false` |
| `man_schnellladen_bogen` | Schnellladen (Bogen) | `["tal_bogen"]` | `false` |
| `man_schnellladen_armbrust` | Schnellladen (Armbrust) | `["tal_armbrust"]` | `false` |
| `man_scharfschuetze` | Scharfschütze | `[]` | `true`, `gilt_fuer_talent_typ: "fernkampf"` |
| `man_meisterschuetze` | Meisterschütze | `[]` | `true`, `gilt_fuer_talent_typ: "fernkampf"` |

Alle Einträge übernehmen `beschreibung`, `erklarung_lang`, `voraussetzungen`, `verbreitung`, `kosten` aus den bestehenden KSF-Einträgen. `erschwernis` und `typ` werden auf `""` gesetzt, da diese Fernkampf-SF keine klassische Erschwernis haben.

---

## 2. Domain-Modell-Änderungen

### 2.1 `lib/catalog/maneuver_def.dart`

Drei neue optionale Felder hinzufügen:

```dart
final List<String> nurFuerTalente;      // Leer = keine Einschränkung
final bool mussSeperatErlerntWerden;    // Per-Talent-Toggle
final String giltFuerTalentTyp;         // "fernkampf" | "" 
```

Defaults im Konstruktor: `nurFuerTalente = const []`, `mussSeperatErlerntWerden = false`, `giltFuerTalentTyp = ""`.

In `fromJson`: `readCatalogString` / `readCatalogBool` / `readCatalogStringList` mit entsprechenden Snake-Case-Schlüsseln.

### 2.2 `lib/domain/combat_config/combat_special_rules.dart`

**Entfernen:**
- `final bool schnellladenBogen;`
- `final bool schnellladenArmbrust;`
- Entsprechende Parameter in Konstruktor, `copyWith`, `toJson`

**Migration in `fromJson`:**  
Beim Laden alter Heldendaten: falls das alte JSON-Feld `schnellladenBogen` den Wert `true` enthält und `"man_schnellladen_bogen"` noch nicht in `activeManeuvers` steht, wird es dort hinzugefügt. Analog für `schnellladenArmbrust`.

```dart
// Migrationslogik (pseudocode in fromJson)
final legacySchnellladenBogen = getBool('schnellladenBogen');
final legacySchnellladenArmbrust = getBool('schnellladenArmbrust');
final maneuvers = readStringList('activeManeuvers');

if (legacySchnellladenBogen && !maneuvers.contains('man_schnellladen_bogen')) {
  maneuvers.add('man_schnellladen_bogen');
}
if (legacySchnellladenArmbrust && !maneuvers.contains('man_schnellladen_armbrust')) {
  maneuvers.add('man_schnellladen_armbrust');
}
```

Kein `schemaVersion`-Bump erforderlich — die Migration ist vollständig durch `fromJson` abgedeckt.

### 2.3 Composite-ID-Format für per-Talent-Aktivierungen

Per-Talent-Aktivierungen werden in `activeManeuvers: List<String>` als zusammengesetzte IDs gespeichert:

```
"<maneuverId>::<talentId>"
```

Beispiele:
```
"man_scharfschuetze::tal_bogen"
"man_scharfschuetze::tal_armbrust"
"man_meisterschuetze::tal_bogen"
```

Ein neuer Hilfs-Record (oder statische Methode) `ManeuverActivationId` in `maneuver_def.dart` oder einem eigenen Helper:

```dart
({String maneuverId, String? talentId}) parseManeuverActivationId(String id) {
  final parts = id.split('::');
  return (maneuverId: parts[0], talentId: parts.length > 1 ? parts[1] : null);
}
```

Normale Manöver (ohne `mussSeperatErlerntWerden`) nutzen weiterhin einfache IDs ohne `::`.

---

## 3. Regellogik-Änderungen

### 3.1 `lib/rules/derived/fernkampf_ladezeit_rules.dart`

`schnellladenBogen`- und `schnellladenArmbrust`-Status werden nicht mehr aus Booleans, sondern aus `activeManeuvers` abgeleitet:

```dart
// Vorher
isOwned: specialRules.schnellladenBogen

// Nachher
isOwned: specialRules.activeManeuvers.contains('man_schnellladen_bogen')
```

`RangedReloadTimeResult` und `CombatSpecialAbilityStatus` bleiben unverändert — nur die Datenquelle für `isOwned` wechselt.

---

## 4. UI-Änderungen

### 4.1 `lib/ui/screens/hero_combat/combat_special_rules_helpers.dart`

Aus `_hardcodedCatalogCombatSpecialAbilityIds` entfernen:
- `'ksf_schnellladen_bogen'`
- `'ksf_schnellladen_armbrust'`

### 4.2 `lib/ui/screens/hero_combat/combat_rules_subtab.dart`

**Entfernen:** Die zwei `_specialAbilityCard`-Blöcke für „Schnellladen (Bogen)" und „Schnellladen (Armbrust)" in `_buildSpecialRulesSection` (aktuell ca. Zeilen 127–154).

**Hinzufügen:** Dritter Bereich „Fernkampf-Manöver" in `_buildManeuversSection`, implementiert durch eine neue Funktion `_buildFernkampfManeuverSection`.

### 4.3 Neue Funktion `_buildFernkampfManeuverSection`

**Sichtbarkeit der Sektion:**  
Die gesamte Sektion „Fernkampf-Manöver" wird nur gerendert, wenn die aktive Haupthand eine Fernkampfwaffe ist. Die `waffentalentId` der aktiven Hauptwaffe ist aus dem `HeroComputedSnapshot` / `CombatPreviewStats` zu lesen (während der Implementierung prüfen ob dieses Feld bereits vorhanden ist; ggf. dort hinzufügen).

**Rendering pro Manöver (`gruppe == "fernkampf"`):**

```
Für jedes ManeuverDef mit gruppe == "fernkampf":
  1. Bestimme aktives FK-Talent-ID aus Hauptwaffe
  
  2. Wenn nurFuerTalente nicht leer:
       Zeige nur, wenn aktives Talent in nurFuerTalente → sonst ausblenden
  
  3. Wenn mussSeperatErlerntWerden == true:
       Label: "{manöver.name} ({talentName})"
       Toggle-ID: "{manöver.id}::{aktivesTalentId}"
       Aktiv: activeManeuvers.contains("{manöver.id}::{aktivesTalentId}")
  
  4. Sonst:
       Normal-Toggle wie bewaffnete/waffenlose Manöver
       Toggle-ID: manöver.id
```

**Darstellung:**  
Gleiche Card-Struktur wie `_buildManeuverGroupCards` (Name, Chip für Erschwernis/Typ, Info-Button, Switch).

---

## 5. Verhalten alter Heldendaten

| Altes Feld | Migration |
|------------|-----------|
| `schnellladenBogen: true` | → `activeManeuvers` += `"man_schnellladen_bogen"` |
| `schnellladenArmbrust: true` | → `activeManeuvers` += `"man_schnellladen_armbrust"` |
| `activeCombatSpecialAbilityIds` enthält `ksf_berittener_schuetze` | Stille Ignorierung — ID nicht mehr im Katalog |
| `activeCombatSpecialAbilityIds` enthält `ksf_eisenhagel` | Stille Ignorierung |
| `activeCombatSpecialAbilityIds` enthält `ksf_scharfschuetze` | Stille Ignorierung — Held muss per-Talent neu aktivieren |
| `activeCombatSpecialAbilityIds` enthält `ksf_meisterschuetze` | Stille Ignorierung |

---

## 6. Betroffene Dateien

| Datei | Art der Änderung |
|-------|-----------------|
| `assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json` | 6 Einträge entfernen |
| `assets/catalogs/house_rules_v1/manoever.json` | 6 neue Einträge hinzufügen |
| `lib/catalog/maneuver_def.dart` | 3 neue optionale Felder |
| `lib/domain/combat_config/combat_special_rules.dart` | 2 Booleans entfernen, `fromJson`-Migration |
| `lib/rules/derived/fernkampf_ladezeit_rules.dart` | `isOwned`-Quelle wechseln |
| `lib/ui/screens/hero_combat/combat_special_rules_helpers.dart` | 2 IDs aus Hardcoded-Set entfernen |
| `lib/ui/screens/hero_combat/combat_rules_subtab.dart` | Schnellladen-Toggles entfernen, FK-Sektion hinzufügen |

---

## 7. Risiken und offene Punkte

1. **`waffentalentId` im Snapshot:** Prüfen ob `CombatPreviewStats` oder `HeroComputedSnapshot` die Talent-ID der aktiven Hauptwaffe bereits exponiert. Falls nicht, muss das Feld dort ergänzt werden.
2. **Alte `ksf_scharfschuetze`/`ksf_meisterschuetze`-Aktivierungen** gehen verloren (keine Zuordnung zu einem Talent möglich). Das ist akzeptabel — der Held wählt die Talente neu.
3. **Tests:** Bestehende Tests für `fernkampf_ladezeit_rules.dart` und `combat_special_rules.dart` müssen angepasst werden.
