import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_katalog_abgleich_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_rules.dart';

const _schwertDef = WeaponDef(
  id: 'wpn_schwert',
  name: 'Schwert',
  type: 'Nahkampf',
  combatSkill: 'Schwerter',
  tp: '1W6+4',
  tpkk: '12/3',
);

const _bogenDef = WeaponDef(
  id: 'wpn_langbogen',
  name: 'Langbogen',
  type: 'Fernkampf',
  combatSkill: 'Bogen',
  tp: '1W6+6',
  tpkk: '-',
);

// Katalog nur mit den Waffen [waffen].
RulesCatalog _katalog(List<WeaponDef> waffen) {
  return RulesCatalog(
    version: 'test',
    source: 'test',
    talents: const [],
    spells: const [],
    weapons: waffen,
  );
}

final _standardKatalog = _katalog(const [_schwertDef, _bogenDef]);

const _meisterlich = MainWeaponSlot(
  name: 'Meisterschwert',
  weaponType: 'Schwert',
  kkBase: 11,
  kkThreshold: 2,
);

List<WaffenKatalogAbweichung> _pruefe(
  List<MainWeaponSlot> waffen, {
  RulesCatalog? katalog,
}) {
  return pruefeWaffenGegenKatalog(
    waffen: waffen,
    catalog: katalog ?? _standardKatalog,
  );
}

void main() {
  group('pruefeWaffenGegenKatalog', () {
    test('meldet eingetragene Verbesserung im Grundwert', () {
      final befunde = _pruefe(const [_meisterlich]);
      expect(befunde, hasLength(1));
      final befund = befunde.single;
      expect(befund.slotIndex, 0);
      expect(befund.katalogName, 'Schwert');
      expect(befund.katalog, (basis: 12, schwelle: 3));
      expect(befund.eingetragen, (basis: 11, schwelle: 2));
      expect(
        befund.meldung,
        'Meisterschwert: TP/KK 11/2 weicht vom Katalog „Schwert“ (12/3) ab. '
        'INI/GE rechnet mit dem Grundwert der Waffe.',
      );
      expect(befund.vorschlag, 'Grundwert 12/3, Verbesserung −1/−1');
    });

    test('schweigt bei passenden Grundwerten', () {
      const passend = MainWeaponSlot(
        name: 'Schwert',
        weaponType: 'Schwert',
        kkBase: 12,
        kkThreshold: 3,
        kkBaseMod: -1,
        kkThresholdMod: -1,
      );
      expect(_pruefe(const [passend]), isEmpty);
    });

    test('nutzt den Namen, wenn die Waffenart fehlt', () {
      const ohneArt = MainWeaponSlot(
        name: 'schwert',
        kkBase: 13,
        kkThreshold: 3,
      );
      expect(_pruefe(const [ohneArt]).single.katalogName, 'Schwert');
    });

    test('schweigt ohne Katalogtreffer, bei 0/0 und ohne Katalog', () {
      const eigene = MainWeaponSlot(
        name: 'Familienklinge',
        weaponType: 'Familienklinge',
        kkBase: 11,
        kkThreshold: 2,
      );
      const deaktiviert = MainWeaponSlot(
        name: 'Schwert',
        weaponType: 'Schwert',
        kkBase: 0,
        kkThreshold: 0,
      );
      expect(_pruefe(const [eigene, deaktiviert]), isEmpty);
      expect(
        pruefeWaffenGegenKatalog(waffen: const [_meisterlich], catalog: null),
        isEmpty,
      );
    });

    test('schweigt, wenn die Katalog-TP/KK nicht lesbar ist', () {
      const bogen = MainWeaponSlot(
        name: 'Langbogen',
        weaponType: 'Langbogen',
        combatType: WeaponCombatType.ranged,
        kkBase: 10,
        kkThreshold: 3,
      );
      expect(_pruefe(const [bogen]), isEmpty);
    });

    test('vergleicht nur mit Katalogwaffen desselben Kampftyps', () {
      const fernSchwert = MainWeaponSlot(
        name: 'Schwert',
        weaponType: 'Schwert',
        combatType: WeaponCombatType.ranged,
        kkBase: 11,
        kkThreshold: 2,
      );
      expect(_pruefe(const [fernSchwert]), isEmpty);
    });

    test('genügt einem von mehreren gleichnamigen Katalogeinträgen', () {
      const variante = WeaponDef(
        id: 'wpn_schwert_variante',
        name: 'Schwert',
        type: 'Nahkampf',
        combatSkill: 'Schwerter',
        tp: '1W6+4',
        tpkk: '11/2',
      );
      final katalog = _katalog(const [_schwertDef, variante]);
      expect(_pruefe(const [_meisterlich], katalog: katalog), isEmpty);
    });

    test('meldet die Position in der Waffenliste', () {
      const passend = MainWeaponSlot(
        name: 'Schwert',
        weaponType: 'Schwert',
        kkBase: 12,
        kkThreshold: 3,
      );
      final befunde = _pruefe(const [passend, _meisterlich]);
      expect(befunde.single.slotIndex, 1);
    });
  });

  group('uebernimmKatalogAbweichungAlsModifikation', () {
    test('verschiebt den Unterschied in die Verbesserung', () {
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        _meisterlich,
        katalog: (basis: 12, schwelle: 3),
      );
      expect(neu.kkBase, 12);
      expect(neu.kkThreshold, 3);
      expect(neu.kkBaseMod, -1);
      expect(neu.kkThresholdMod, -1);
      expect(computeWirksameTpKk(slot: neu), (basis: 11, schwelle: 2));
      expect(_pruefe([neu]), isEmpty);
    });

    test('rechnet eine vorhandene Verbesserung mit', () {
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        _meisterlich.copyWith(kkBaseMod: -1),
        katalog: (basis: 12, schwelle: 3),
      );
      expect(neu.kkBaseMod, -2);
      expect(neu.kkThresholdMod, -1);
      expect(computeWirksameTpKk(slot: neu), (basis: 10, schwelle: 2));
    });

    test('hebt eine frühere Bestätigung auf', () {
      final akzeptiert = akzeptiereKatalogAbweichung(
        _meisterlich,
        katalogName: 'Schwert',
        katalog: (basis: 12, schwelle: 3),
      );
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        akzeptiert,
        katalog: (basis: 12, schwelle: 3),
      );
      expect(neu.katalogTpKkAkzeptiert, isEmpty);
    });
  });

  group('akzeptiereKatalogAbweichung', () {
    final akzeptiert = akzeptiereKatalogAbweichung(
      _meisterlich,
      katalogName: 'Schwert',
      katalog: (basis: 12, schwelle: 3),
    );

    test('lässt die Werte und schweigt danach', () {
      expect(akzeptiert.kkBase, 11);
      expect(akzeptiert.kkThreshold, 2);
      expect(akzeptiert.katalogTpKkAkzeptiert, '11/2|Schwert 12/3');
      expect(_pruefe([akzeptiert]), isEmpty);
    });

    test('meldet erneut, wenn sich die Waffe ändert', () {
      final geaendert = akzeptiert.copyWith(kkBase: 10);
      expect(_pruefe([geaendert]), hasLength(1));
    });

    test('meldet erneut, wenn sich der Katalog ändert', () {
      const neuerKatalogwert = WeaponDef(
        id: 'wpn_schwert',
        name: 'Schwert',
        type: 'Nahkampf',
        combatSkill: 'Schwerter',
        tp: '1W6+4',
        tpkk: '13/3',
      );
      final katalog = _katalog(const [neuerKatalogwert]);
      expect(_pruefe([akzeptiert], katalog: katalog), hasLength(1));
    });

    test('wird nur bei Belegung gespeichert und übersteht den Umlauf', () {
      expect(
        _meisterlich.toJson().containsKey('katalogTpKkAkzeptiert'),
        isFalse,
      );
      final geladen = MainWeaponSlot.fromJson(akzeptiert.toJson());
      expect(geladen.katalogTpKkAkzeptiert, '11/2|Schwert 12/3');
      expect(geladen.unbekannteFelder, isEmpty);
    });
  });

  test('leseKatalogTpKk liest Basis und Schwelle', () {
    expect(leseKatalogTpKk('12/3'), (basis: 12, schwelle: 3));
    expect(leseKatalogTpKk(' 14 / 4 '), (basis: 14, schwelle: 4));
    expect(leseKatalogTpKk('-'), isNull);
  });
}
