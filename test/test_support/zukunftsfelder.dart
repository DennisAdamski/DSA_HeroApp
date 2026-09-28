import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Ein Held im heutigen Format und derselbe Held, wie ihn eine gedachte
/// neuere App-Version mit zusaetzlichen verschachtelten Feldern schreibt.
///
/// [basis] ist die Fixture samt Beispielinhalten an den Stellen, die sie
/// selbst nicht belegt (siehe [mitZukunftsfeldern]); [json] traegt zusaetzlich
/// an jeder verschachtelten Ebene ein Feld `zukunftsfeld`. [pfade] nennt genau
/// diese Stellen im Format von `jsonUnterschiede`.
typedef Zukunftsheld = ({
  Map<String, dynamic> basis,
  Map<String, dynamic> json,
  List<String> pfade,
});

/// Name des Feldes, das die gedachte neuere Version schreibt.
const String zukunftsfeld = 'zukunftsfeld';

/// Baut aus dem Helden-JSON [heldJson] einen [Zukunftsheld].
///
/// Erwartet den Aufbau von f01: eine nicht gewaehlte Fernkampfwaffe an
/// Position 1 mit Geschoss, ein Ruestungsstueck, ein Nebenhand-Teil, einen
/// manuellen und einen mit dieser Waffe verknuepften Inventareintrag. Die
/// gewaehlte Waffe bleibt unberuehrt, weil `mainWeapon` nur sie spiegelt.
///
/// Was f01 nicht belegt, ergaenzt die Basis im heutigen Format: einen
/// Inventar-Modifikator am manuellen Eintrag und eine Waffenmeisterschaft mit
/// Bonus.
Zukunftsheld mitZukunftsfeldern(Map<String, dynamic> heldJson) {
  final basis = _tiefeKopie(heldJson);
  final pfade = <String>[..._ausruestung(basis), ..._kampfEinstellungen(basis)];
  return _mitFeldern(basis, pfade);
}

/// Pfade der zehn Ausruestungsmodelle (Teilstand ARCH-03 vom 28.09.2026).
List<String> _ausruestung(Map<String, dynamic> basis) {
  final eintraege = basis['inventoryEntries'] as List<dynamic>;
  final manuell = eintraege.indexWhere(
    (entry) => (entry as Map)['source'] == 'manuell',
  );
  _pruefe(manuell >= 0, 'manueller Inventareintrag');
  (eintraege[manuell] as Map)['modifiers'] = <Object?>[
    <String, dynamic>{
      'kind': 'stat',
      'targetId': 'gs',
      'wert': 1,
      'beschreibung': 'Leichtes Gepäck',
    },
  ];

  final kampf = basis['combatConfig'] as Map<String, dynamic>;
  _pruefe(kampf['selectedWeaponIndex'] != 1, 'Waffe 1 nicht gewählt');
  final waffen = kampf['weapons'] as List<dynamic>;
  _pruefe(waffen.length > 1, 'zweite Waffe');
  final waffe = waffen[1] as Map<String, dynamic>;
  final profil = waffe['rangedProfile'] as Map<String, dynamic>;
  _pruefe((profil['projectiles'] as List).isNotEmpty, 'Geschoss an Waffe 1');
  final ruestung = kampf['armor'] as Map<String, dynamic>;
  _pruefe((ruestung['pieces'] as List).isNotEmpty, 'Rüstungsstück');
  _pruefe((kampf['offhandEquipment'] as List).isNotEmpty, 'Nebenhand-Teil');
  final waffenVerweis = 'w:${waffe['name']}';
  final verknuepft = eintraege.indexWhere(
    (entry) => (entry as Map)['sourceRef'] == waffenVerweis,
  );
  _pruefe(verknuepft >= 0, 'Inventareintrag zu Waffe 1');

  return <String>[
    'combatConfig',
    'combatConfig/weapons/1',
    'combatConfig/weapons/1/rangedProfile',
    'combatConfig/weapons/1/rangedProfile/distanceBands/0',
    'combatConfig/weapons/1/rangedProfile/projectiles/0',
    'combatConfig/armor',
    'combatConfig/armor/pieces/0',
    'combatConfig/offhandEquipment/0',
    'inventoryEntries/$manuell',
    'inventoryEntries/$manuell/modifiers/0',
    'inventoryEntries/$verknuepft',
  ];
}

/// Pfade der Kampfeinstellungen neben der Ausruestung.
List<String> _kampfEinstellungen(Map<String, dynamic> basis) {
  final kampf = basis['combatConfig'] as Map<String, dynamic>;
  _pruefe(kampf['offhandAssignment'] is Map, 'Nebenhand-Auswahl');
  _pruefe(kampf['specialRules'] is Map, 'Kampf-Sonderfertigkeiten');
  _pruefe(kampf['manualMods'] is Map, 'manuelle Kampfmodifikatoren');
  _pruefe(
    (kampf['waffenmeisterschaften'] as List).isEmpty,
    'keine Waffenmeisterschaft',
  );
  kampf['waffenmeisterschaften'] = <Object?>[
    const WaffenmeisterConfig(
      talentId: 'tal_schwerter',
      weaponType: 'Langschwert',
      bonuses: <WaffenmeisterBonus>[
        WaffenmeisterBonus(type: WaffenmeisterBonusType.iniBonus, value: 1),
      ],
    ).toJson(),
  ];
  return const <String>[
    'combatConfig/offhandAssignment',
    'combatConfig/specialRules',
    'combatConfig/manualMods',
    'combatConfig/waffenmeisterschaften/0',
    'combatConfig/waffenmeisterschaften/0/bonuses/0',
  ];
}

/// Bearbeitet in [held] je Modell an einem Zukunftspfad ein bekanntes Feld,
/// wie es die Editoren tun: per `copyWith` auf der vorhandenen Instanz.
///
/// Ergaenzt die Ausruestungsaenderungen der Ablauftests um die uebrigen
/// Modelle. Die Aenderungen sind so gewaehlt, dass kein Regelabgleich sie
/// wieder zuruecknimmt.
HeroSheet bearbeiteVerschachtelteModelle(HeroSheet held) {
  final kampf = held.combatConfig;
  final meister = kampf.waffenmeisterschaften.single;
  return held.copyWith(
    combatConfig: kampf.copyWith(
      offhandAssignment: kampf.offhandAssignment.copyWith(
        weaponIndex: -1,
        equipmentIndex: 0,
      ),
      specialRules: kampf.specialRules.copyWith(flink: true),
      manualMods: kampf.manualMods.copyWith(iniWurf: 4),
      waffenmeisterschaften: <WaffenmeisterConfig>[
        meister.copyWith(
          styleName: 'Garether Schule',
          bonuses: <WaffenmeisterBonus>[
            meister.bonuses.single.copyWith(value: 2),
          ],
        ),
      ],
    ),
  );
}

// Setzt an jedem Pfad ein Zukunftsfeld und liefert den fertigen Helden.
Zukunftsheld _mitFeldern(Map<String, dynamic> basis, List<String> pfade) {
  final json = _tiefeKopie(basis);
  for (final pfad in pfade) {
    final ziel = wertAn(json, pfad);
    _pruefe(ziel is Map, 'Objekt an $pfad');
    (ziel as Map)[zukunftsfeld] = <String, dynamic>{
      'ebene': pfad,
      'liste': <Object?>[1, 'zwei', null],
    };
  }
  return (
    basis: basis,
    json: json,
    pfade: <String>[for (final pfad in pfade) '$pfad/$zukunftsfeld'],
  );
}

/// Liefert den Wert an [pfad] (`a/0/b`) in [json] oder `null`.
Object? wertAn(Object? json, String pfad) {
  Object? aktuell = json;
  for (final segment in pfad.split('/')) {
    if (aktuell is Map) {
      aktuell = aktuell[segment];
    } else if (aktuell is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= aktuell.length) return null;
      aktuell = aktuell[index];
    } else {
      return null;
    }
  }
  return aktuell;
}

// Tiefe Kopie ueber JSON, damit Tests die Fixture nicht veraendern.
Map<String, dynamic> _tiefeKopie(Map<String, dynamic> json) {
  return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
}

// Bricht mit klarer Meldung ab, wenn die Fixture nicht passt.
void _pruefe(bool bedingung, String erwartet) {
  if (!bedingung) {
    throw StateError('Fixture passt nicht zu mitZukunftsfeldern: $erwartet');
  }
}
