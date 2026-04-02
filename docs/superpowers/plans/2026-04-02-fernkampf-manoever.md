# Fernkampf-Manöver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sechs Fernkampf-KSF als echte Manöver in `manoever.json` überführen, Scharfschütze/Meisterschütze per-Talent aktivierbar machen, Schnellladen-Booleans vollständig migrieren.

**Architecture:** `ManeuverDef` erhält drei optionale Felder (`nurFuerTalente`, `mussSeperatErlerntWerden`, `giltFuerTalentTyp`). Per-Talent-Aktivierungen werden als Composite-ID `"man_x::tal_y"` in der bestehenden `activeManeuvers: List<String>` gespeichert. Die Fernkampf-Sektion in der UI zeigt sich nur, wenn ein FK-Talent als Haupthand aktiv ist.

**Tech Stack:** Dart, Flutter, JSON-Katalog, flutter_test

---

## Dateiübersicht

| Datei | Änderungsart |
|-------|-------------|
| `lib/catalog/maneuver_def.dart` | 3 neue Felder, fromJson/toJson |
| `assets/catalogs/house_rules_v1/manoever.json` | 6 neue Einträge hinzufügen |
| `assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json` | 6 Einträge entfernen |
| `lib/domain/combat_config/combat_special_rules.dart` | 2 Booleans entfernen, fromJson-Migration |
| `lib/rules/derived/fernkampf_ladezeit_rules.dart` | isOwned-Quelle wechseln |
| `lib/ui/screens/hero_combat/combat_special_rules_helpers.dart` | 2 IDs aus Hardcoded-Set |
| `lib/ui/screens/hero_combat/combat_rules_subtab.dart` | Schnellladen-Cards entfernen, FK-Sektion |
| `test/domain/combat_special_rules_test.dart` | Neue Testdatei |
| `test/rules/combat_rules_test.dart` | Schnellladen-Boolean → activeManeuvers |
| `test/ui/combat/hero_combat_tab_test.dart` | Schnellladen-Keys ersetzen |

---

## Task 1: ManeuverDef erweitern

**Files:**
- Modify: `lib/catalog/maneuver_def.dart`

- [ ] **Schritt 1: Drei neue optionale Felder zu `ManeuverDef` hinzufügen**

Ersetze die gesamte Klasse in `lib/catalog/maneuver_def.dart`:

```dart
import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Definition eines Kampfmanoeuvers aus dem Regelkatalog.
///
/// Manoever koennen Waffen ([WeaponDef.possibleManeuvers]) zugeordnet sein.
/// [erschwernis] enthaelt den Erschwernis-Wert als Freitext (z. B. '-4' oder '+0').
/// Fernkampf-Manoever mit [mussSeperatErlerntWerden] werden pro aktivem FK-Talent
/// einzeln aktiviert; die gespeicherte ID lautet dann '<id>::<talentId>'.
class ManeuverDef {
  const ManeuverDef({
    required this.id,
    required this.name,
    this.gruppe = '',
    this.typ = '',
    this.erschwernis = '',
    this.seite = '',
    this.erklarung = '',
    this.erklarungLang = '',
    this.voraussetzungen = '',
    this.verbreitung = '',
    this.kosten = '',
    this.nurFuerTalente = const <String>[],
    this.mussSeperatErlerntWerden = false,
    this.giltFuerTalentTyp = '',
  });

  final String id;
  final String name;
  final String gruppe;
  final String typ;
  final String erschwernis;
  final String seite;
  final String erklarung;
  final String erklarungLang;
  final String voraussetzungen;
  final String verbreitung;
  final String kosten;

  /// Schraenkt Sichtbarkeit auf bestimmte Talent-IDs ein.
  /// Leer = gilt fuer alle Talente des [giltFuerTalentTyp].
  final List<String> nurFuerTalente;

  /// Wenn true: muss fuer jedes FK-Talent separat aktiviert werden.
  /// Gespeicherte ID: '<id>::<talentId>'.
  final bool mussSeperatErlerntWerden;

  /// Talenttyp-Filter fuer [mussSeperatErlerntWerden] (z. B. 'fernkampf').
  final String giltFuerTalentTyp;

  factory ManeuverDef.fromJson(Map<String, dynamic> json) {
    return ManeuverDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      gruppe: readCatalogString(json, 'gruppe', fallback: ''),
      typ: readCatalogString(json, 'typ', fallback: ''),
      erschwernis: readCatalogString(json, 'erschwernis', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      erklarung: readCatalogString(json, 'erklarung', fallback: ''),
      erklarungLang: readCatalogString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: readCatalogString(
        json,
        'voraussetzungen',
        fallback: '',
      ),
      verbreitung: readCatalogString(json, 'verbreitung', fallback: ''),
      kosten: readCatalogString(json, 'kosten', fallback: ''),
      nurFuerTalente: readCatalogStringList(json, 'nur_fuer_talente'),
      mussSeperatErlerntWerden: readCatalogBool(
        json,
        'muss_separat_erlernt_werden',
        fallback: false,
      ),
      giltFuerTalentTyp: readCatalogString(
        json,
        'gilt_fuer_talent_typ',
        fallback: '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gruppe': gruppe,
      'typ': typ,
      'erschwernis': erschwernis,
      'seite': seite,
      'erklarung': erklarung,
      'erklarung_lang': erklarungLang,
      'voraussetzungen': voraussetzungen,
      'verbreitung': verbreitung,
      'kosten': kosten,
      if (nurFuerTalente.isNotEmpty) 'nur_fuer_talente': nurFuerTalente,
      if (mussSeperatErlerntWerden) 'muss_separat_erlernt_werden': true,
      if (giltFuerTalentTyp.isNotEmpty) 'gilt_fuer_talent_typ': giltFuerTalentTyp,
    };
  }
}
```

- [ ] **Schritt 2: `flutter analyze` ausführen — kein Fehler erwartet**

```bash
flutter analyze
```

- [ ] **Schritt 3: Commit**

```bash
git add lib/catalog/maneuver_def.dart
git commit -m "catalog: ManeuverDef um nurFuerTalente, mussSeperatErlerntWerden, giltFuerTalentTyp erweitern"
```

---

## Task 2: Katalog-Daten aktualisieren

**Files:**
- Modify: `assets/catalogs/house_rules_v1/manoever.json`
- Modify: `assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json`

- [ ] **Schritt 1: 6 neue Einträge ans Ende der JSON-Array in `manoever.json` einfügen**

Füge diese 6 Objekte als letzte Einträge im JSON-Array ein (vor der schließenden `]`). Achte auf korrektes Komma nach dem vorletzten Eintrag.

```json
,
{
    "id": "man_berittener_schuetze",
    "name": "Berittener Schütze",
    "gruppe": "fernkampf",
    "typ": "",
    "erschwernis": "",
    "seite": "95",
    "erklarung": "Halbiert Fernkampfaufschläge vom Reittier und erleichtert das Spannen im Sattel.",
    "erklarung_lang": "Berittene Schützen erleiden beim Schießen oder Werfen vom sich bewegenden Reittier aus nur die Hälfte der üblichen Aufschläge. Außerdem können sie ihre Waffen im Sattel genauso schnell spannen wie am Boden und müssen vor dem Schuss keine Reiten-Probe ablegen.",
    "voraussetzungen": "TaW Reiten 7; kann nur bei Fernkampffertigkeiten eingesetzt werden, deren TaW 7 oder mehr beträgt",
    "verbreitung": "4, in allen Reiterkulturen, bei entsprechenden Militäreinheiten",
    "kosten": "200 AP"
},
{
    "id": "man_eisenhagel",
    "name": "Eisenhagel",
    "gruppe": "fernkampf",
    "typ": "",
    "erschwernis": "",
    "seite": "95",
    "erklarung": "Erlaubt das gleichzeitige Werfen mehrerer Wurfscheiben, Wurfsterne oder ähnlicher Geschosse.",
    "erklarung_lang": "Ein Spezialist mit Eisenhagel kann mehrere geeignete Wurfgeschosse gleichzeitig werfen. Die Fernkampf-Probe ist dabei um das Doppelte der verwendeten Geschosse erschwert, höchstens jedoch für fünf Geschosse. Zusätzliche Ziele erschweren die Probe weiter, und die Trefferpunkte jedes einzelnen Geschosses werden separat ermittelt.",
    "voraussetzungen": "FF 12; TaW Wurfmesser 10; Spezialisierung auf Wurfringe, Wurfscheiben oder Wurfsterne und Verwendung derselben",
    "verbreitung": "2, üblicherweise bei eher zwielichtigen Elementen",
    "kosten": "150 AP",
    "nur_fuer_talente": ["tal_wurfmesser"]
},
{
    "id": "man_schnellladen_bogen",
    "name": "Schnellladen (Bogen)",
    "gruppe": "fernkampf",
    "typ": "",
    "erschwernis": "",
    "seite": "95",
    "erklarung": "Reduziert die Ladezeit aller Bögen um 1 Aktion, mindestens auf 1 Aktion.",
    "erklarung_lang": "Durch Drill oder langjährige Praxis bringt der Held Pfeil und Bogen schneller in Schussbereitschaft. Die Ladezeit aller Bögen sinkt für ihn um 1 Aktion, jedoch nie unter 1 Aktion. Schnellladen funktioniert nur bei einer effektiven BE von höchstens 4.",
    "voraussetzungen": "FF 12, KK 12; TaW Bogen 7; muss für das Talent Bogen separat erlernt werden",
    "verbreitung": "5, bei professionellen Fernkampf-Einheiten",
    "kosten": "200 AP",
    "nur_fuer_talente": ["tal_bogen"]
},
{
    "id": "man_schnellladen_armbrust",
    "name": "Schnellladen (Armbrust)",
    "gruppe": "fernkampf",
    "typ": "",
    "erschwernis": "",
    "seite": "95",
    "erklarung": "Senkt die Ladezeit von Armbrüsten auf drei Viertel des Tabellenwerts.",
    "erklarung_lang": "Der Held beherrscht das Spannen und Nachladen von Armbrüsten besonders effizient. Für ihn beträgt die Ladezeit nur noch drei Viertel des angegebenen Tabellenwerts. Schnellladen funktioniert nur bei einer effektiven BE von höchstens 4.",
    "voraussetzungen": "FF 12, KK 12; TaW Armbrust 7; muss für das Talent Armbrust separat erlernt werden",
    "verbreitung": "5, bei professionellen Fernkampf-Einheiten",
    "kosten": "200 AP",
    "nur_fuer_talente": ["tal_armbrust"]
},
{
    "id": "man_scharfschuetze",
    "name": "Scharfschütze",
    "gruppe": "fernkampf",
    "typ": "",
    "erschwernis": "",
    "seite": "95",
    "erklarung": "Verbessert Schnellschüsse, Ansagen und gezieltes Zielen mit einer bestimmten Fernwaffe.",
    "erklarung_lang": "Ein Scharfschütze erleidet bei Schnellschüssen nur noch einen Aufschlag von 1 statt 2 Punkten. Bei Fernkampfangriffen mit Ansage darf er die volle Ansage zu seinen Trefferpunkten addieren, braucht zum Zielen aber zwei Aktionen weniger, mindestens jedoch eine zusätzliche Aktion. Auch beim gezielten Schuss mit Trefferzonen halbiert sich sein Zeitaufwand, und beim Zielen reduziert bereits eine Aktion die Erschwernis um einen Punkt.",
    "voraussetzungen": "TaW der entsprechenden Fernwaffe 7; muss für jedes mögliche Fernkampftalent separat erlernt werden",
    "verbreitung": "5, bei vielen Jägern und einigen professionellen Fernwaffen-Kämpfern",
    "kosten": "je 300 AP",
    "muss_separat_erlernt_werden": true,
    "gilt_fuer_talent_typ": "fernkampf"
},
{
    "id": "man_meisterschuetze",
    "name": "Meisterschütze",
    "gruppe": "fernkampf",
    "typ": "",
    "erschwernis": "",
    "seite": "95",
    "erklarung": "Entfernt den Schnellschussaufschlag und steigert Ansagen und Zielschüsse weiter.",
    "erklarung_lang": "Ein Meisterschütze ignoriert den Aufschlag für Schnellschüsse vollständig. Bei Ansagen darf er bis in Höhe seines Fernkampfwerts ansagen und die volle Ansage auf die Trefferpunkte addieren; dafür braucht er nur eine zusätzliche Aktion. Trefferzonenaufschläge halbiert er, benötigt ebenfalls nur eine Zusatzaktion und ignoriert außerdem Zuschläge durch Seitenwind oder Steilschüsse. Wie beim Scharfschützen reduziert bereits eine Aktion Zielen die Erschwernis um einen Punkt.",
    "voraussetzungen": "TaW der entsprechenden Schusswaffe 15; SF Scharfschütze; muss für jedes mögliche Fernkampftalent separat erlernt werden",
    "verbreitung": "2, bei einzelnen Scharfschützen und Jägern",
    "kosten": "300 AP",
    "muss_separat_erlernt_werden": true,
    "gilt_fuer_talent_typ": "fernkampf"
}
```

- [ ] **Schritt 2: 6 Einträge aus `kampf_sonderfertigkeiten.json` entfernen**

Entferne die JSON-Objekte mit diesen IDs vollständig (inklusive des vorangehenden Kommas):
- `ksf_berittener_schuetze`
- `ksf_eisenhagel`
- `ksf_scharfschuetze`
- `ksf_meisterschuetze`
- `ksf_schnellladen_bogen`
- `ksf_schnellladen_armbrust`

Stelle sicher, dass die JSON-Syntax korrekt bleibt (keine doppelten Kommas, kein Komma nach dem letzten Eintrag).

- [ ] **Schritt 3: `flutter analyze` ausführen**

```bash
flutter analyze
```

Erwartung: kein Fehler.

- [ ] **Schritt 4: `flutter test` ausführen**

```bash
flutter test
```

Erwartung: alle Tests grün (Katalogdaten werden in Tests nicht direkt geladen — keine Brüche erwartet).

- [ ] **Schritt 5: Commit**

```bash
git add assets/catalogs/house_rules_v1/manoever.json \
        assets/catalogs/house_rules_v1/kampf_sonderfertigkeiten.json
git commit -m "catalog: Fernkampf-SF als Manöver (Scharfschütze/Meisterschütze per Talent, Schnellladen, Berittener Schütze, Eisenhagel)"
```

---

## Task 3: CombatSpecialRules migrieren

**Files:**
- Create: `test/domain/combat_special_rules_test.dart`
- Modify: `lib/domain/combat_config/combat_special_rules.dart`
- Modify: `test/rules/combat_rules_test.dart`
- Modify: `test/ui/combat/hero_combat_tab_test.dart`

- [ ] **Schritt 1: Neue Testdatei erstellen**

Erstelle `test/domain/combat_special_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';

void main() {
  group('CombatSpecialRules.fromJson Migration', () {
    test('migriert schnellladenBogen-Boolean zu activeManeuvers', () {
      final json = <String, dynamic>{
        'schnellladenBogen': true,
        'schnellladenArmbrust': false,
        'activeManeuvers': <dynamic>[],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(rules.activeManeuvers, contains('man_schnellladen_bogen'));
      expect(
        rules.activeManeuvers,
        isNot(contains('man_schnellladen_armbrust')),
      );
    });

    test('migriert schnellladenArmbrust-Boolean zu activeManeuvers', () {
      final json = <String, dynamic>{
        'schnellladenBogen': false,
        'schnellladenArmbrust': true,
        'activeManeuvers': <dynamic>[],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(
        rules.activeManeuvers,
        isNot(contains('man_schnellladen_bogen')),
      );
      expect(rules.activeManeuvers, contains('man_schnellladen_armbrust'));
    });

    test('dupliziert man_schnellladen_bogen nicht wenn bereits vorhanden', () {
      final json = <String, dynamic>{
        'schnellladenBogen': true,
        'activeManeuvers': <dynamic>['man_schnellladen_bogen'],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(
        rules.activeManeuvers
            .where((e) => e == 'man_schnellladen_bogen')
            .length,
        1,
      );
    });

    test('keine Migration wenn beide Booleans false', () {
      final json = <String, dynamic>{
        'schnellladenBogen': false,
        'schnellladenArmbrust': false,
        'activeManeuvers': <dynamic>['man_ausfall'],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(rules.activeManeuvers, equals(['man_ausfall']));
    });

    test('Fehlende Legacy-Felder ergeben keine Migration', () {
      final json = <String, dynamic>{
        'activeManeuvers': <dynamic>['man_ausfall'],
      };
      final rules = CombatSpecialRules.fromJson(json);
      expect(rules.activeManeuvers, equals(['man_ausfall']));
    });
  });
}
```

- [ ] **Schritt 2: Test ausführen — muss FEHLSCHLAGEN (Felder existieren noch)**

```bash
flutter test test/domain/combat_special_rules_test.dart
```

Erwartung: Kompilierfehler oder Laufzeitfehler, weil `schnellladenBogen`-Feld noch existiert und die Testlogik noch nicht implementiert ist.

- [ ] **Schritt 3: `combat_special_rules.dart` aktualisieren**

Ersetze den Inhalt von `lib/domain/combat_config/combat_special_rules.dart`:

```dart
/// Haelt die Aktivierungszustaende aller Kampfsonderfertigkeiten und Manoever.
///
/// Alle boolean-Felder sind standardmaessig `false`.
/// Aktive Manoever werden als deduplizierte, leerzeichen-bereinigte String-Liste
/// in [activeManeuvers] gespeichert. Per-Talent-Manoever verwenden das Format
/// '<maneuverId>::<talentId>' (z. B. 'man_scharfschuetze::tal_bogen').
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
class CombatSpecialRules {
  const CombatSpecialRules({
    this.kampfreflexe = false,
    this.kampfgespuer = false,
    this.schnellziehen = false,
    this.ausweichenI = false,
    this.ausweichenII = false,
    this.ausweichenIII = false,
    this.schildkampfI = false,
    this.schildkampfII = false,
    this.parierwaffenI = false,
    this.parierwaffenII = false,
    this.linkhandActive = false,
    this.flink = false,
    this.behaebig = false,
    this.axxeleratusActive = false,
    this.klingentaenzer = false,
    this.aufmerksamkeit = false,
    this.activeCombatSpecialAbilityIds = const <String>[],
    this.gladiatorStyleTalent = '',
    this.activeManeuvers = const <String>[],
  });

  /// Sonderfertigkeit Kampfreflexe aktiv.
  final bool kampfreflexe;

  /// Sonderfertigkeit Kampfgespuer aktiv.
  final bool kampfgespuer;

  /// Sonderfertigkeit Schnellziehen aktiv.
  final bool schnellziehen;

  /// Ausweichen I aktiv.
  final bool ausweichenI;

  /// Ausweichen II aktiv.
  final bool ausweichenII;

  /// Ausweichen III aktiv.
  final bool ausweichenIII;

  /// Schildkampf I aktiv.
  final bool schildkampfI;

  /// Schildkampf II aktiv.
  final bool schildkampfII;

  /// Parierwaffen I aktiv.
  final bool parierwaffenI;

  /// Parierwaffen II aktiv.
  final bool parierwaffenII;

  /// Linkhand-Modus aktiv.
  final bool linkhandActive;

  /// Vorteil Flink aktiv.
  final bool flink;

  /// Nachteil Behäebig aktiv.
  final bool behaebig;

  /// Axxeleratus-Zauber aktiv.
  final bool axxeleratusActive;

  /// Klingentaenzer: wirft 2W6 statt 1W6 auf Initiative.
  final bool klingentaenzer;

  /// Aufmerksamkeit: ersetzt 1W6/2W6-Anzeige durch +6/+12 in der Uebersicht.
  final bool aufmerksamkeit;

  /// Aktiv geschaltete katalogbasierte Kampf-Sonderfertigkeiten.
  final List<String> activeCombatSpecialAbilityIds;

  /// Talentwahl fuer den Gladiatorenstil ('raufen' oder 'ringen').
  final String gladiatorStyleTalent;

  /// Liste der aktuell aktiven Manoever-IDs (dedupliziert, kein Leerstring).
  /// Per-Talent-Manoever: '<maneuverId>::<talentId>'.
  final List<String> activeManeuvers;

  CombatSpecialRules copyWith({
    bool? kampfreflexe,
    bool? kampfgespuer,
    bool? schnellziehen,
    bool? ausweichenI,
    bool? ausweichenII,
    bool? ausweichenIII,
    bool? schildkampfI,
    bool? schildkampfII,
    bool? parierwaffenI,
    bool? parierwaffenII,
    bool? linkhandActive,
    bool? flink,
    bool? behaebig,
    bool? axxeleratusActive,
    bool? klingentaenzer,
    bool? aufmerksamkeit,
    List<String>? activeCombatSpecialAbilityIds,
    String? gladiatorStyleTalent,
    List<String>? activeManeuvers,
  }) {
    return CombatSpecialRules(
      kampfreflexe: kampfreflexe ?? this.kampfreflexe,
      kampfgespuer: kampfgespuer ?? this.kampfgespuer,
      schnellziehen: schnellziehen ?? this.schnellziehen,
      ausweichenI: ausweichenI ?? this.ausweichenI,
      ausweichenII: ausweichenII ?? this.ausweichenII,
      ausweichenIII: ausweichenIII ?? this.ausweichenIII,
      schildkampfI: schildkampfI ?? this.schildkampfI,
      schildkampfII: schildkampfII ?? this.schildkampfII,
      parierwaffenI: parierwaffenI ?? this.parierwaffenI,
      parierwaffenII: parierwaffenII ?? this.parierwaffenII,
      linkhandActive: linkhandActive ?? this.linkhandActive,
      flink: flink ?? this.flink,
      behaebig: behaebig ?? this.behaebig,
      axxeleratusActive: axxeleratusActive ?? this.axxeleratusActive,
      klingentaenzer: klingentaenzer ?? this.klingentaenzer,
      aufmerksamkeit: aufmerksamkeit ?? this.aufmerksamkeit,
      activeCombatSpecialAbilityIds: _normalizeStringList(
        activeCombatSpecialAbilityIds ?? this.activeCombatSpecialAbilityIds,
      ),
      gladiatorStyleTalent: (gladiatorStyleTalent ?? this.gladiatorStyleTalent)
          .trim(),
      activeManeuvers: _normalizeStringList(
        activeManeuvers ?? this.activeManeuvers,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kampfreflexe': kampfreflexe,
      'kampfgespuer': kampfgespuer,
      'schnellziehen': schnellziehen,
      'ausweichenI': ausweichenI,
      'ausweichenII': ausweichenII,
      'ausweichenIII': ausweichenIII,
      'schildkampfI': schildkampfI,
      'schildkampfII': schildkampfII,
      'parierwaffenI': parierwaffenI,
      'parierwaffenII': parierwaffenII,
      'linkhandActive': linkhandActive,
      'flink': flink,
      'behaebig': behaebig,
      'axxeleratusActive': axxeleratusActive,
      'klingentaenzer': klingentaenzer,
      'aufmerksamkeit': aufmerksamkeit,
      'activeCombatSpecialAbilityIds': _normalizeStringList(
        activeCombatSpecialAbilityIds,
      ),
      'gladiatorStyleTalent': gladiatorStyleTalent.trim(),
      'activeManeuvers': _normalizeStringList(activeManeuvers),
    };
  }

  /// Deserialisiert [CombatSpecialRules] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern. Migriert Legacy-Booleans:
  /// `schnellladenBogen: true` → 'man_schnellladen_bogen' in [activeManeuvers].
  /// `schnellladenArmbrust: true` → 'man_schnellladen_armbrust' in [activeManeuvers].
  static CombatSpecialRules fromJson(Map<String, dynamic> json) {
    bool getBool(String key) => (json[key] as bool?) ?? false;

    // Legacy-Migration: Schnellladen-Booleans → activeManeuvers
    final rawManeuvers = List<dynamic>.from(
      (json['activeManeuvers'] as List?) ?? const <dynamic>[],
    );
    if (getBool('schnellladenBogen')) {
      rawManeuvers.add('man_schnellladen_bogen');
    }
    if (getBool('schnellladenArmbrust')) {
      rawManeuvers.add('man_schnellladen_armbrust');
    }

    return CombatSpecialRules(
      kampfreflexe: getBool('kampfreflexe'),
      kampfgespuer: getBool('kampfgespuer'),
      schnellziehen: getBool('schnellziehen'),
      ausweichenI: getBool('ausweichenI'),
      ausweichenII: getBool('ausweichenII'),
      ausweichenIII: getBool('ausweichenIII'),
      schildkampfI: getBool('schildkampfI'),
      schildkampfII: getBool('schildkampfII'),
      parierwaffenI: getBool('parierwaffenI'),
      parierwaffenII: getBool('parierwaffenII'),
      linkhandActive: getBool('linkhandActive'),
      flink: getBool('flink'),
      behaebig: getBool('behaebig'),
      axxeleratusActive: getBool('axxeleratusActive'),
      klingentaenzer: getBool('klingentaenzer'),
      aufmerksamkeit: getBool('aufmerksamkeit'),
      activeCombatSpecialAbilityIds: _normalizeStringList(
        (json['activeCombatSpecialAbilityIds'] as List?) ?? const <dynamic>[],
      ),
      gladiatorStyleTalent:
          (json['gladiatorStyleTalent'] as String?)?.trim() ?? '',
      activeManeuvers: _normalizeStringList(rawManeuvers),
    );
  }
}

/// Bereinigt und dedupliziert eine Liste von Manoever-IDs.
List<String> _normalizeStringList(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final text = value.toString().trim();
    if (text.isEmpty || seen.contains(text)) {
      continue;
    }
    seen.add(text);
    normalized.add(text);
  }
  return List<String>.unmodifiable(normalized);
}
```

- [ ] **Schritt 4: Neue Tests ausführen — müssen GRÜN sein**

```bash
flutter test test/domain/combat_special_rules_test.dart
```

- [ ] **Schritt 5: Bestehende Tests in `combat_rules_test.dart` anpassen**

Suche in `test/rules/combat_rules_test.dart` nach allen Vorkommen von `schnellladenBogen` und `schnellladenArmbrust`. Es gibt drei Stellen:

**Vorkommen 1** (ca. Zeile 587): `CombatSpecialRules(schnellladenBogen: true)` → ersetze durch:
```dart
CombatSpecialRules(activeManeuvers: ['man_schnellladen_bogen'])
```

**Vorkommen 2** (ca. Zeile 638): `CombatSpecialRules(schnellladenArmbrust: true)` → ersetze durch:
```dart
CombatSpecialRules(activeManeuvers: ['man_schnellladen_armbrust'])
```

**Vorkommen 3** (ca. Zeile 689): `CombatSpecialRules(schnellladenBogen: true)` → ersetze durch:
```dart
CombatSpecialRules(activeManeuvers: ['man_schnellladen_bogen'])
```

- [ ] **Schritt 6: `combat_rules_test.dart` ausführen**

```bash
flutter test test/rules/combat_rules_test.dart
```

Erwartung: alle Tests GRÜN (die Ladezeit-Logik liest noch `specialRules.schnellladenBogen` — das wird in Task 4 gefixt; bis dahin schlagen die Ladezeit-Tests fehl → diese Abhängigkeit beachten, ggf. erst nach Task 4 committen).

- [ ] **Schritt 7: Widget-Test in `hero_combat_tab_test.dart` anpassen**

Suche nach dem Test der die Keys `combat-special-rule-schnellladen-bogen` und `combat-special-rule-schnellladen-armbrust` verwendet (ca. Zeile 686-703).

Die zwei `setSwitchByKey`-Aufrufe entfernen (diese UI-Karten existieren nicht mehr):
```dart
// ENTFERNEN:
await setSwitchByKey(
  tester,
  keyName: 'combat-special-rule-schnellladen-bogen',
  value: true,
);
await setSwitchByKey(
  tester,
  keyName: 'combat-special-rule-schnellladen-armbrust',
  value: true,
);
```

Den Held in diesem Test so einrichten, dass er `man_schnellladen_bogen` und `man_schnellladen_armbrust` bereits in `activeManeuvers` hat (direkte Vorinitialisierung statt UI-Toggle, da die FK-Sektion eine FK-Hauptwaffe voraussetzt):

```dart
// Im buildHero-Aufruf für diesen Test:
combatConfig: const CombatConfig(
  specialRules: CombatSpecialRules(
    schnellziehen: true,
    activeManeuvers: ['man_schnellladen_bogen', 'man_schnellladen_armbrust'],
  ),
),
```

Und die Erwartungen anpassen:
```dart
// VORHER:
expect(hero.combatConfig.specialRules.schnellladenBogen, isTrue);
expect(hero.combatConfig.specialRules.schnellladenArmbrust, isTrue);

// NACHHER:
expect(
  hero.combatConfig.specialRules.activeManeuvers,
  contains('man_schnellladen_bogen'),
);
expect(
  hero.combatConfig.specialRules.activeManeuvers,
  contains('man_schnellladen_armbrust'),
);
```

Hinweis: `schnellziehen` bleibt als UI-Toggle testbar, da es weiterhin ein hardcoded Boolean ist.

- [ ] **Schritt 8: Alle Tests ausführen — Ladezeit-Tests werden noch ROTEN (OK)**

```bash
flutter test
```

Erwartung: `combat_special_rules_test.dart` grün. Ladezeit-bezogene Tests in `combat_rules_test.dart` können noch rot sein — das wird in Task 4 gefixt.

---

## Task 4: Regellogik aktualisieren

**Files:**
- Modify: `lib/rules/derived/fernkampf_ladezeit_rules.dart`

- [ ] **Schritt 1: `isOwned`-Quelle in `fernkampf_ladezeit_rules.dart` auf `activeManeuvers` umstellen**

In `computeRangedReloadTime` (ab Zeile 75), ersetze die drei Stellen die `specialRules.schnellladenBogen` / `specialRules.schnellladenArmbrust` lesen:

Ersetze den Block (Zeilen 75–100):
```dart
  final schnellladenBogen = CombatSpecialAbilityStatus(
    isOwned: specialRules.schnellladenBogen,
    isActive: specialRules.schnellladenBogen || axxeleratusActive,
    isTemporary: axxeleratusActive && !specialRules.schnellladenBogen,
  );
  final schnellladenArmbrust = CombatSpecialAbilityStatus(
    isOwned: specialRules.schnellladenArmbrust,
    isActive: specialRules.schnellladenArmbrust || axxeleratusActive,
    isTemporary: axxeleratusActive && !specialRules.schnellladenArmbrust,
  );

  var effectiveReloadTime = switch (weaponKind) {
    _RangedReloadKind.bogen => _computeBogenReloadTime(
      baseReloadTime: baseReloadTime,
      hasOwnedAbility: specialRules.schnellladenBogen,
      hasActiveAbility: schnellladenBogen.isActive,
      axxeleratusActive: axxeleratusActive,
    ),
    _RangedReloadKind.armbrust => _computeArmbrustReloadTime(
      baseReloadTime: baseReloadTime,
      hasOwnedAbility: specialRules.schnellladenArmbrust,
      hasActiveAbility: schnellladenArmbrust.isActive,
      axxeleratusActive: axxeleratusActive,
    ),
    _RangedReloadKind.none => clampNonNegative(baseReloadTime),
  };
```

durch:
```dart
  final ownsBogen = specialRules.activeManeuvers.contains(
    'man_schnellladen_bogen',
  );
  final ownsArmbrust = specialRules.activeManeuvers.contains(
    'man_schnellladen_armbrust',
  );
  final schnellladenBogen = CombatSpecialAbilityStatus(
    isOwned: ownsBogen,
    isActive: ownsBogen || axxeleratusActive,
    isTemporary: axxeleratusActive && !ownsBogen,
  );
  final schnellladenArmbrust = CombatSpecialAbilityStatus(
    isOwned: ownsArmbrust,
    isActive: ownsArmbrust || axxeleratusActive,
    isTemporary: axxeleratusActive && !ownsArmbrust,
  );

  var effectiveReloadTime = switch (weaponKind) {
    _RangedReloadKind.bogen => _computeBogenReloadTime(
      baseReloadTime: baseReloadTime,
      hasOwnedAbility: ownsBogen,
      hasActiveAbility: schnellladenBogen.isActive,
      axxeleratusActive: axxeleratusActive,
    ),
    _RangedReloadKind.armbrust => _computeArmbrustReloadTime(
      baseReloadTime: baseReloadTime,
      hasOwnedAbility: ownsArmbrust,
      hasActiveAbility: schnellladenArmbrust.isActive,
      axxeleratusActive: axxeleratusActive,
    ),
    _RangedReloadKind.none => clampNonNegative(baseReloadTime),
  };
```

- [ ] **Schritt 2: Alle Tests ausführen — jetzt alles GRÜN**

```bash
flutter test
```

Erwartung: alle Tests grün (inklusive Ladezeit-Tests, die jetzt `activeManeuvers` korrekt auswerten).

- [ ] **Schritt 3: Commit**

```bash
git add lib/domain/combat_config/combat_special_rules.dart \
        lib/rules/derived/fernkampf_ladezeit_rules.dart \
        test/domain/combat_special_rules_test.dart \
        test/rules/combat_rules_test.dart \
        test/ui/combat/hero_combat_tab_test.dart
git commit -m "combat: Schnellladen-Boolean zu activeManeuvers migrieren, Ladezeit-Regellogik anpassen"
```

---

## Task 5: UI bereinigen — Hardcoded-Set und Schnellladen-Cards

**Files:**
- Modify: `lib/ui/screens/hero_combat/combat_special_rules_helpers.dart`
- Modify: `lib/ui/screens/hero_combat/combat_rules_subtab.dart`

- [ ] **Schritt 1: 2 IDs aus `_hardcodedCatalogCombatSpecialAbilityIds` entfernen**

In `lib/ui/screens/hero_combat/combat_special_rules_helpers.dart`, entferne aus dem Set:
```dart
  'ksf_schnellladen_bogen',
  'ksf_schnellladen_armbrust',
```
Das Set sollte danach nur noch 18 Einträge haben.

- [ ] **Schritt 2: Schnellladen-Karten aus `_buildSpecialRulesSection` entfernen**

In `lib/ui/screens/hero_combat/combat_rules_subtab.dart`, entferne die beiden `_specialAbilityCard`-Blöcke (Zeilen 127–154):

```dart
        _specialAbilityCard(
          title: 'Schnellladen (Bogen)',
          value: rules.schnellladenBogen,
          isEditing: isEditing,
          isActive: rules.schnellladenBogen || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellladenBogen,
          keyName: 'combat-special-rule-schnellladen-bogen',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellladenBogen: value),
            );
            _markFieldChanged();
          },
        ),
        _specialAbilityCard(
          title: 'Schnellladen (Armbrust)',
          value: rules.schnellladenArmbrust,
          isEditing: isEditing,
          isActive: rules.schnellladenArmbrust || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellladenArmbrust,
          keyName: 'combat-special-rule-schnellladen-armbrust',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellladenArmbrust: value),
            );
            _markFieldChanged();
          },
        ),
```

- [ ] **Schritt 3: `flutter analyze` ausführen**

```bash
flutter analyze
```

- [ ] **Schritt 4: `flutter test` ausführen**

```bash
flutter test
```

- [ ] **Schritt 5: Commit**

```bash
git add lib/ui/screens/hero_combat/combat_special_rules_helpers.dart \
        lib/ui/screens/hero_combat/combat_rules_subtab.dart
git commit -m "combat: Schnellladen-SF aus Hardcoded-Set und UI-Sonderfertigkeiten entfernen"
```

---

## Task 6: Fernkampf-Manöver-Sektion implementieren

**Files:**
- Modify: `lib/ui/screens/hero_combat/combat_rules_subtab.dart`

- [ ] **Schritt 1: `_buildFernkampfManeuverCards` ans Ende von `combat_rules_subtab.dart` einfügen**

Füge die neue Methode **innerhalb der `_CombatRulesSubtab`-Extension** direkt nach `_buildManeuverGroupCards` ein (vor der schließenden `}` der Extension):

```dart
  /// Rendert Fernkampf-Manöver — nur sichtbar wenn aktive Haupthand ein
  /// FK-Talent hat. Per-Talent-Manöver zeigen den Talentname im Label.
  List<Widget> _buildFernkampfManeuverCards({
    required RulesCatalog catalog,
    required CombatSpecialRules rules,
    required Set<String> activeManeuverIds,
    required bool isEditing,
    required Map<String, _ManeuverSupportStatus> supportByManeuver,
  }) {
    final activeTalentDef = _selectedCombatTalentDef(catalog);
    if (activeTalentDef == null ||
        activeTalentDef.type.toLowerCase() != 'fernkampf') {
      return const <Widget>[];
    }

    final activeTalentId = activeTalentDef.id;
    final activeTalentName = activeTalentDef.name;

    final fernkampfManeuvers = catalog.maneuvers
        .where((m) => m.gruppe == 'fernkampf')
        .where(
          (m) =>
              m.nurFuerTalente.isEmpty ||
              m.nurFuerTalente.contains(activeTalentId),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (fernkampfManeuvers.isEmpty) return const <Widget>[];

    final widgets = <Widget>[
      Text(
        'Fernkampf-Manöver',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
    ];

    for (final maneuver in fernkampfManeuvers) {
      final String toggleId;
      final String displayName;

      if (maneuver.mussSeperatErlerntWerden) {
        toggleId = '${maneuver.id}::$activeTalentId';
        displayName = '${maneuver.name} ($activeTalentName)';
      } else {
        toggleId = maneuver.id;
        displayName = maneuver.name;
      }

      final isActive = activeManeuverIds.contains(toggleId);
      final support =
          supportByManeuver[maneuver.id] ?? _ManeuverSupportStatus.unverifiable;

      widgets.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(displayName),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildManeuverMetaChips(
                          maneuverDef: maneuver,
                          isActive: isActive,
                          support: support,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Details',
                  onPressed: () => _showCombatManeuverDetailsDialog(
                    context: context,
                    maneuver: maneuver,
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
                Switch(
                  value: isActive,
                  onChanged: !isEditing
                      ? null
                      : (value) {
                          final active = List<String>.from(
                            rules.activeManeuvers,
                          );
                          if (value) {
                            active.add(toggleId);
                          } else {
                            active.removeWhere((entry) => entry == toggleId);
                          }
                          _draftCombatConfig = _draftCombatConfig.copyWith(
                            specialRules: rules.copyWith(
                              activeManeuvers: active,
                            ),
                          );
                          _markFieldChanged();
                        },
                ),
              ],
            ),
          ),
        ),
      );
    }

    widgets.add(const SizedBox(height: 12));
    return widgets;
  }
```

- [ ] **Schritt 2: `_buildFernkampfManeuverCards` in `_buildManeuversSection` integrieren**

In `_buildManeuversSection` (ca. Zeile 463), erweitere die `Column`-Kinder um den Aufruf der neuen Methode. Ersetze:

```dart
      children: [
        if (catalog.maneuvers.isEmpty)
          const Card(
            child: ListTile(title: Text('Keine Manöver im Katalog gefunden.')),
          ),
        ..._buildManeuverGroupCards(
          title: 'Bewaffnete Manöver',
          maneuvers: groupedManeuvers['bewaffnet'] ?? const <ManeuverDef>[],
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
        ..._buildManeuverGroupCards(
          title: 'Waffenlose Manöver',
          maneuvers: groupedManeuvers['waffenlos'] ?? const <ManeuverDef>[],
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
      ],
```

durch:
```dart
      children: [
        if (catalog.maneuvers.isEmpty)
          const Card(
            child: ListTile(title: Text('Keine Manöver im Katalog gefunden.')),
          ),
        ..._buildManeuverGroupCards(
          title: 'Bewaffnete Manöver',
          maneuvers: groupedManeuvers['bewaffnet'] ?? const <ManeuverDef>[],
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
        ..._buildManeuverGroupCards(
          title: 'Waffenlose Manöver',
          maneuvers: groupedManeuvers['waffenlos'] ?? const <ManeuverDef>[],
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
        ..._buildFernkampfManeuverCards(
          catalog: catalog,
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
      ],
```

- [ ] **Schritt 3: `flutter analyze` ausführen**

```bash
flutter analyze
```

Erwartung: kein Fehler.

- [ ] **Schritt 4: `flutter test` ausführen**

```bash
flutter test
```

Erwartung: alle Tests GRÜN.

- [ ] **Schritt 5: LOC-Budget prüfen**

```bash
python tool/check_screen_loc_budget.py --max-lines 700
```

Falls `combat_rules_subtab.dart` über 700 Zeilen: die neue Methode `_buildFernkampfManeuverCards` in `combat_maneuver_helpers.dart` auslagern (gleiche Extension-Gruppe, selbe `part of`-Deklaration).

- [ ] **Schritt 6: Commit**

```bash
git add lib/ui/screens/hero_combat/combat_rules_subtab.dart
git commit -m "combat: Fernkampf-Manöver-Sektion im Kampfregeln-Tab implementieren"
```

---

## Task 7: Abschluss-Verifikation

- [ ] **Schritt 1: Vollständige Analyse und Tests**

```bash
flutter analyze && flutter test
```

Erwartung: 0 Warnings, 0 Fehler, alle Tests GRÜN.

- [ ] **Schritt 2: LOC-Budget prüfen**

```bash
python tool/check_screen_loc_budget.py --max-lines 700
```

- [ ] **Schritt 3: Manuelle Smoke-Tests**

App starten (`flutter run`) und folgendes prüfen:

1. Held mit Bogen als aktiver Haupthand → Kampfregeln-Tab → Manöver-Bereich zeigt „Fernkampf-Manöver"
2. „Schnellladen (Bogen)" erscheint in der FK-Sektion (nicht mehr in Sonderfertigkeiten)
3. „Scharfschütze (Bogen)" zeigt den Talent-Namen im Label
4. Toggle aktivieren → Held speichern → `activeManeuvers` enthält `"man_scharfschuetze::tal_bogen"`
5. Waffe auf Nahkampf wechseln → FK-Sektion verschwindet
6. Held ohne Änderungen laden (alter Held mit `schnellladenBogen: true` in JSON) → `man_schnellladen_bogen` erscheint automatisch in `activeManeuvers`

- [ ] **Schritt 4: Finaler Commit (falls noch Änderungen offen)**

```bash
git add -A
git commit -m "combat: Fernkampf-Manöver vollständig implementiert"
```
