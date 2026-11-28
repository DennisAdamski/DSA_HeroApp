import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_weapon_profile.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/weapon_combat_type.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Konfiguriert eine einzelne Hauptwaffenposition des Helden.
///
/// Unveraenderlich; Aktualisierungen erfolgen ueber [copyWith].
/// Serialisierung ist abwaertskompatibel (Schema v5).
/// Die Wuerfelseiten sind im aktuellen Hausregel-Fluss fest auf W6 gesetzt.
class MainWeaponSlot {
  const MainWeaponSlot({
    this.id = '',
    this.inventarInstanzId = '',
    this.name = '',
    this.talentId = '',
    this.combatType = WeaponCombatType.melee,
    this.weaponType = '',
    this.distanceClass = '',
    this.kkBase = 0,
    this.kkThreshold = 1,
    this.kkBaseMod = 0,
    this.kkThresholdMod = 0,
    this.katalogAbgleichAkzeptiert = '',
    this.breakFactor = 0,
    this.breakFactorMod = 0,
    this.tpDiceCount = 1,
    this.tpDiceSides = 6,
    this.tpFlat = 0,
    this.wmAt = 0,
    this.wmPa = 0,
    this.iniMod = 0,
    this.tpFlatMod = 0,
    this.wmAtMod = 0,
    this.wmPaMod = 0,
    this.iniModMod = 0,
    this.beTalentMod = 0,
    this.isOneHanded = true,
    this.isArtifact = false,
    this.artifactDescription = '',
    this.isGeweiht = false,
    this.geweihtDescription = '',
    this.rangedProfile = const RangedWeaponProfile(),
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Stabile Kennung des Slots innerhalb der Kampfkonfiguration.
  ///
  /// Verknuepft den Slot mit seinem Inventareintrag, unabhaengig vom Namen
  /// (siehe `CombatConfig.withStableIds`). Leer bei neu angelegten Slots,
  /// bis sie gespeichert werden.
  final String id;

  /// Instanz-ID des Inventareintrags, der dieses Exemplar ist (ARCH-03).
  ///
  /// Verweis Slot → Instanz; leer, bis `HeroActions.saveHero` ihn aus dem
  /// verknuepften Eintrag setzt (`bindeSlotsAnInstanzen`). Abgeleitet, nie
  /// von der Bedienung geschrieben; nur geschrieben, wenn belegt.
  final String inventarInstanzId;

  /// Anzeigename der Waffe.
  final String name;

  /// ID des zugeordneten Kampftalents.
  final String talentId;

  /// Gibt an, ob die Waffe im Kampf als Nah- oder Fernkampfwaffe verwendet wird.
  final WeaponCombatType combatType;

  /// Waffenart (z. B. 'Schwert', 'Axt').
  final String weaponType;

  /// Entfernungsklasse der Waffe.
  final String distanceClass;

  /// KK-Basis der unveraenderten Waffe (Grundwert aus der Waffentabelle).
  ///
  /// Grundlage fuer TP/KK und INI/GE. Verbesserungen der Waffe stehen in
  /// [kkBaseMod], Waffenmeister-Boni kommen aus der Kampfmeisterschaft.
  final int kkBase;

  /// KK-Schwelle der unveraenderten Waffe (Grundwert aus der Waffentabelle).
  ///
  /// Grundlage fuer TP/KK und INI/GE; Verbesserungen stehen in
  /// [kkThresholdMod].
  final int kkThreshold;

  /// Veraenderung der KK-Basis durch die Waffe selbst, z. B. `-1` fuer eine
  /// meisterlich geschmiedete Klinge.
  ///
  /// Wirkt nur auf TP/KK; INI/GE rechnet weiter mit [kkBase]. Wird nur
  /// geschrieben, wenn belegt.
  final int kkBaseMod;

  /// Veraenderung der KK-Schwelle durch die Waffe selbst, z. B. `-1` fuer
  /// eine meisterlich geschmiedete Klinge.
  ///
  /// Wirkt nur auf TP/KK; INI/GE rechnet weiter mit [kkThreshold]. Wird nur
  /// geschrieben, wenn belegt.
  final int kkThresholdMod;

  /// Bestätigte Abweichung der Grundwerte (TP/KK, TP, INI, AT, PA, BF) vom
  /// Katalog.
  ///
  /// Hält fest, welche Kombination aus Waffe und Katalogwaffe der Nutzer als
  /// gewollt akzeptiert hat (Schlüssel aus `waffen_katalog_abgleich_rules`).
  /// Ändern sich Waffe oder Katalog, passt der Schlüssel nicht mehr und die
  /// Prüfung meldet die Abweichung erneut. Leer, solange nichts akzeptiert
  /// ist; nur geschrieben, wenn belegt.
  final String katalogAbgleichAkzeptiert;

  /// Grund-Bruchfaktor der Waffe (Waffentabelle, samt Abnutzung im Spiel).
  ///
  /// Der wirksame BF ist [breakFactor] + [breakFactorMod].
  final int breakFactor;

  /// Veraenderung des Bruchfaktors durch die Waffe selbst, z. B. `-1` fuer
  /// eine meisterlich geschmiedete Klinge. Nur geschrieben, wenn belegt.
  final int breakFactorMod;

  /// Anzahl der TP-Wuerfel.
  final int tpDiceCount;

  /// Wuerfelseiten (im Hausregel-Fluss immer 6).
  final int tpDiceSides;

  /// Flacher TP-Bonus (ohne Wuerfel) der unveraenderten Waffe.
  final int tpFlat;

  /// Waffenmodifikator auf Attacke der unveraenderten Waffe.
  final int wmAt;

  /// Waffenmodifikator auf Parade der unveraenderten Waffe.
  final int wmPa;

  /// Initiativmodifikator der unveraenderten Waffe.
  final int iniMod;

  /// Verbesserung des TP-Zuschlags durch die Waffe selbst (z. B. `+1`).
  /// Nur geschrieben, wenn belegt.
  final int tpFlatMod;

  /// Verbesserung des AT-Waffenmodifikators durch die Waffe selbst.
  /// Nur geschrieben, wenn belegt.
  final int wmAtMod;

  /// Verbesserung des PA-Waffenmodifikators durch die Waffe selbst.
  /// Nur geschrieben, wenn belegt.
  final int wmPaMod;

  /// Verbesserung des Initiativmodifikators durch die Waffe selbst.
  /// Nur geschrieben, wenn belegt.
  final int iniModMod;

  /// BE-Modifikator fuer Talentproben mit dieser Waffe.
  final int beTalentMod;

  /// Gibt an, ob die Waffe einhaendig gefuehrt wird.
  final bool isOneHanded;

  /// Kennzeichnet die Waffe als Artefakt.
  final bool isArtifact;

  /// Freitext-Beschreibung fuer das Artefakt.
  final String artifactDescription;

  /// Kennzeichnet die Waffe als geweiht.
  final bool isGeweiht;

  /// Freitext-Beschreibung fuer den geweihten Gegenstand.
  final String geweihtDescription;

  /// Zusatzprofil fuer Fernkampfwaffen.
  final RangedWeaponProfile rangedProfile;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzaehlungswerte einer neueren App-Version (JSON-Schluessel
  /// -> Rohwert). Die Felder tragen den Ersatzwert, mit dem Regeln rechnen;
  /// geschrieben wird der Rohwert, bis jemand das Feld auf einen anderen Wert
  /// setzt (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich des
  /// Altschluessels `wmFk`, der beim Laden in [wmAt] aufgeht und deshalb
  /// nicht als unbekannt zurueckgeschrieben werden darf.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'inventarInstanzId',
    'name',
    'talentId',
    'combatType',
    'weaponType',
    'distanceClass',
    'kkBase',
    'kkThreshold',
    'kkBaseMod',
    'kkThresholdMod',
    'katalogAbgleichAkzeptiert',
    'breakFactor',
    'breakFactorMod',
    'tpDiceCount',
    'tpDiceSides',
    'tpFlat',
    'wmAt',
    'wmFk',
    'wmPa',
    'iniMod',
    'tpFlatMod',
    'wmAtMod',
    'wmPaMod',
    'iniModMod',
    'beTalentMod',
    'isOneHanded',
    'isArtifact',
    'artifactDescription',
    'isGeweiht',
    'geweihtDescription',
    'rangedProfile',
  };

  /// Gibt an, ob es sich um eine Fernkampfwaffe handelt.
  bool get isRanged => combatType == WeaponCombatType.ranged;

  /// Ob die Geschosse dieses Slots samt ihren Inventareintraegen gelten.
  ///
  /// Fuer Fernkampfwaffen und fuer eine Kampfart einer neueren App-Version:
  /// Regeln rechnen dort mit dem Ersatz Nahkampf, Verweise und Abgleich
  /// behalten die Geschosse aber, sonst gingen deren Inventardaten verloren
  /// (Befund ARCH-07-B13).
  bool get fuehrtGeschosse =>
      isRanged || unbekannteEnumWerte.containsKey('combatType');

  /// Gibt eine Kopie mit selektiv ueberschriebenen Feldern zurueck.
  ///
  /// Hinweis: [tpDiceSides] ist immer 6 und wird ignoriert.
  MainWeaponSlot copyWith({
    String? id,
    String? inventarInstanzId,
    String? name,
    String? talentId,
    WeaponCombatType? combatType,
    String? weaponType,
    String? distanceClass,
    int? kkBase,
    int? kkThreshold,
    int? kkBaseMod,
    int? kkThresholdMod,
    String? katalogAbgleichAkzeptiert,
    int? breakFactor,
    int? breakFactorMod,
    int? tpDiceCount,
    int? tpDiceSides,
    int? tpFlat,
    int? wmAt,
    int? wmPa,
    int? iniMod,
    int? tpFlatMod,
    int? wmAtMod,
    int? wmPaMod,
    int? iniModMod,
    int? beTalentMod,
    bool? isOneHanded,
    bool? isArtifact,
    String? artifactDescription,
    bool? isGeweiht,
    String? geweihtDescription,
    RangedWeaponProfile? rangedProfile,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    return MainWeaponSlot(
      id: id ?? this.id,
      inventarInstanzId: inventarInstanzId ?? this.inventarInstanzId,
      name: name ?? this.name,
      talentId: talentId ?? this.talentId,
      combatType: combatType ?? this.combatType,
      weaponType: weaponType ?? this.weaponType,
      distanceClass: distanceClass ?? this.distanceClass,
      kkBase: kkBase ?? this.kkBase,
      kkThreshold: kkThreshold ?? this.kkThreshold,
      kkBaseMod: kkBaseMod ?? this.kkBaseMod,
      kkThresholdMod: kkThresholdMod ?? this.kkThresholdMod,
      katalogAbgleichAkzeptiert:
          katalogAbgleichAkzeptiert ?? this.katalogAbgleichAkzeptiert,
      breakFactor: breakFactor ?? this.breakFactor,
      breakFactorMod: breakFactorMod ?? this.breakFactorMod,
      tpDiceCount: tpDiceCount ?? this.tpDiceCount,
      // W6 ist im aktuellen Hausregel-Waffenfluss fest.
      tpDiceSides: 6,
      tpFlat: tpFlat ?? this.tpFlat,
      wmAt: wmAt ?? this.wmAt,
      wmPa: wmPa ?? this.wmPa,
      iniMod: iniMod ?? this.iniMod,
      tpFlatMod: tpFlatMod ?? this.tpFlatMod,
      wmAtMod: wmAtMod ?? this.wmAtMod,
      wmPaMod: wmPaMod ?? this.wmPaMod,
      iniModMod: iniModMod ?? this.iniModMod,
      beTalentMod: beTalentMod ?? this.beTalentMod,
      isOneHanded: isOneHanded ?? this.isOneHanded,
      isArtifact: isArtifact ?? this.isArtifact,
      artifactDescription: artifactDescription ?? this.artifactDescription,
      isGeweiht: isGeweiht ?? this.isGeweiht,
      geweihtDescription: geweihtDescription ?? this.geweihtDescription,
      rangedProfile: rangedProfile ?? this.rangedProfile,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'combatType': combatType != null && combatType != this.combatType,
          }),
    );
  }

  /// Serialisiert den Slot zu einem JSON-kompatiblen Map.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        if (id.isNotEmpty) 'id': id,
        if (inventarInstanzId.isNotEmpty)
          'inventarInstanzId': inventarInstanzId,
        'name': name,
        'talentId': talentId,
        'combatType': weaponCombatTypeToJson(combatType),
        'weaponType': weaponType,
        'distanceClass': distanceClass,
        'kkBase': kkBase,
        'kkThreshold': kkThreshold,
        // Nur bei Belegung, damit Bestandshelden ihren Inhalts-Hash behalten.
        if (kkBaseMod != 0) 'kkBaseMod': kkBaseMod,
        if (kkThresholdMod != 0) 'kkThresholdMod': kkThresholdMod,
        if (katalogAbgleichAkzeptiert.isNotEmpty)
          'katalogAbgleichAkzeptiert': katalogAbgleichAkzeptiert,
        'breakFactor': breakFactor,
        if (breakFactorMod != 0) 'breakFactorMod': breakFactorMod,
        'tpDiceCount': tpDiceCount,
        // Als W6 persistiert fuer Schema-Kompatibilitaet.
        'tpDiceSides': 6,
        'tpFlat': tpFlat,
        'wmAt': wmAt,
        'wmPa': wmPa,
        'iniMod': iniMod,
        if (tpFlatMod != 0) 'tpFlatMod': tpFlatMod,
        if (wmAtMod != 0) 'wmAtMod': wmAtMod,
        if (wmPaMod != 0) 'wmPaMod': wmPaMod,
        if (iniModMod != 0) 'iniModMod': iniModMod,
        'beTalentMod': beTalentMod,
        'isOneHanded': isOneHanded,
        'isArtifact': isArtifact,
        'artifactDescription': artifactDescription,
        'isGeweiht': isGeweiht,
        'geweihtDescription': geweihtDescription,
        'rangedProfile': rangedProfile.toJson(),
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Deserialisiert einen [MainWeaponSlot] aus einem JSON-Map.
  ///
  /// Tolerant bei fehlenden Feldern (Standardwerte werden gesetzt).
  static MainWeaponSlot fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    int getInt(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    String getString(String key) => (json[key] as String?) ?? '';
    Map<String, dynamic> getMap(String key) {
      final raw = json[key];
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.cast<String, dynamic>();
      }
      return const <String, dynamic>{};
    }

    final combatType = leseEnumWert(
      json['combatType'],
      'combatType',
      erkenne: weaponCombatTypeErkennen,
      ersatz: WeaponCombatType.melee,
      unbekannt: enumRoh,
    );
    final hasWmAt = json.containsKey('wmAt') && json['wmAt'] != null;
    return MainWeaponSlot(
      id: (json['id'] as String?) ?? '',
      inventarInstanzId: getString('inventarInstanzId'),
      name: getString('name'),
      talentId: getString('talentId'),
      combatType: combatType,
      weaponType: getString('weaponType'),
      distanceClass: getString('distanceClass'),
      kkBase: getInt('kkBase', 0),
      kkThreshold: getInt('kkThreshold', 1),
      kkBaseMod: getInt('kkBaseMod', 0),
      kkThresholdMod: getInt('kkThresholdMod', 0),
      katalogAbgleichAkzeptiert: getString('katalogAbgleichAkzeptiert'),
      breakFactor: getInt('breakFactor', 0),
      breakFactorMod: getInt('breakFactorMod', 0),
      tpDiceCount: getInt('tpDiceCount', 1),
      tpDiceSides: 6,
      tpFlat: getInt('tpFlat', 0),
      wmAt: hasWmAt
          ? getInt('wmAt', 0)
          : getInt(
              'wmFk',
              combatType == WeaponCombatType.ranged ? 0 : getInt('wmAt', 0),
            ),
      wmPa: getInt('wmPa', 0),
      iniMod: getInt('iniMod', 0),
      tpFlatMod: getInt('tpFlatMod', 0),
      wmAtMod: getInt('wmAtMod', 0),
      wmPaMod: getInt('wmPaMod', 0),
      iniModMod: getInt('iniModMod', 0),
      beTalentMod: getInt('beTalentMod', 0),
      isOneHanded: (json['isOneHanded'] as bool?) ?? true,
      isArtifact: (json['isArtifact'] as bool?) ?? false,
      artifactDescription: getString('artifactDescription'),
      isGeweiht: (json['isGeweiht'] as bool?) ?? false,
      geweihtDescription: getString('geweihtDescription'),
      rangedProfile: RangedWeaponProfile.fromJson(getMap('rangedProfile')),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }
}
