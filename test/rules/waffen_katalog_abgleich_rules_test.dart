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
  breakFactor: '1',
);

const _bogenDef = WeaponDef(
  id: 'wpn_langbogen',
  name: 'Langbogen',
  type: 'Fernkampf',
  combatSkill: 'Bogen',
  tp: '1W6+6*',
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
final _schwertWerte = WaffenKatalogWerte.aus(_schwertDef);

// Schwert, wie es im Katalog steht.
const _schwert = MainWeaponSlot(
  name: 'Schwert',
  weaponType: 'Schwert',
  kkBase: 12,
  kkThreshold: 3,
  tpFlat: 4,
  breakFactor: 1,
);

// Bestandswaffe, deren Verbesserung (TP/KK −1/−1) im Grundwert steckt.
final _meisterlich = _schwert.copyWith(
  name: 'Meisterschwert',
  kkBase: 11,
  kkThreshold: 2,
);

// Bestandswaffe mit Verbesserungen in allen Grundwerten.
final _vollVerbessert = _schwert.copyWith(
  name: 'Prunkschwert',
  kkBase: 11,
  kkThreshold: 2,
  tpFlat: 5,
  iniMod: 1,
  wmAt: 1,
  wmPa: 1,
  breakFactor: 0,
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
  group('pruefeWaffenGegenKatalog: TP/KK', () {
    test('meldet eingetragene Verbesserung im Grundwert', () {
      final befunde = _pruefe([_meisterlich]);
      expect(befunde, hasLength(1));
      final befund = befunde.single;
      expect(befund.slotIndex, 0);
      expect(befund.katalogName, 'Schwert');
      expect(befund.katalog.tpKk, (basis: 12, schwelle: 3));
      expect(befund.betrifftTpKk, isTrue);
      expect(
        befund.meldung,
        'Meisterschwert weicht vom Katalog „Schwert“ ab: TP/KK 11/2 statt '
        '12/3. INI/GE rechnet mit dem Grundwert der Waffe.',
      );
      expect(befund.vorschlag, 'Verbesserung TP/KK −1/−1');
    });

    test(
      'schweigt bei passenden Grundwerten mit eingetragener Verbesserung',
      () {
        final passend = _schwert.copyWith(
          kkBaseMod: -1,
          kkThresholdMod: -1,
          tpFlatMod: 1,
          iniModMod: 1,
          wmAtMod: 1,
          wmPaMod: 1,
          breakFactorMod: -1,
        );
        expect(_pruefe([passend]), isEmpty);
      },
    );

    test('nutzt den Namen, wenn die Waffenart fehlt', () {
      final ohneArt = _schwert.copyWith(
        name: 'schwert',
        weaponType: '',
        kkBase: 13,
      );
      expect(_pruefe([ohneArt]).single.katalogName, 'Schwert');
    });

    test('schweigt ohne Katalogtreffer, bei 0/0 und ohne Katalog', () {
      final eigene = _meisterlich.copyWith(
        name: 'Familienklinge',
        weaponType: 'Familienklinge',
      );
      final deaktiviert = _schwert.copyWith(kkBase: 0, kkThreshold: 0);
      expect(_pruefe([eigene, deaktiviert]), isEmpty);
      expect(
        pruefeWaffenGegenKatalog(waffen: [_meisterlich], catalog: null),
        isEmpty,
      );
    });

    test('vergleicht nur mit Katalogwaffen desselben Kampftyps', () {
      final fernSchwert = _meisterlich.copyWith(
        combatType: WeaponCombatType.ranged,
      );
      expect(_pruefe([fernSchwert]), isEmpty);
    });

    test('genügt einem von mehreren gleichnamigen Katalogeinträgen', () {
      const variante = WeaponDef(
        id: 'wpn_schwert_variante',
        name: 'Schwert',
        type: 'Nahkampf',
        combatSkill: 'Schwerter',
        tp: '1W6+4',
        tpkk: '11/2',
        breakFactor: '1',
      );
      final katalog = _katalog(const [_schwertDef, variante]);
      expect(_pruefe([_meisterlich], katalog: katalog), isEmpty);
    });

    test('meldet die Position in der Waffenliste', () {
      final befunde = _pruefe([_schwert, _meisterlich]);
      expect(befunde.single.slotIndex, 1);
    });
  });

  group('pruefeWaffenGegenKatalog: TP, INI, AT, PA, BF', () {
    test('meldet alle abweichenden Grundwerte in fester Reihenfolge', () {
      final befund = _pruefe([_vollVerbessert]).single;
      expect(befund.abweichungen.map((a) => a.art), <WaffenGrundwertArt>[
        WaffenGrundwertArt.tpKk,
        WaffenGrundwertArt.tp,
        WaffenGrundwertArt.ini,
        WaffenGrundwertArt.at,
        WaffenGrundwertArt.pa,
        WaffenGrundwertArt.bf,
      ]);
      expect(
        befund.meldung,
        'Prunkschwert weicht vom Katalog „Schwert“ ab: TP/KK 11/2 statt 12/3, '
        'TP 1W6+5 statt 1W6+4, INI +1 statt ±0, AT +1 statt ±0, '
        'PA +1 statt ±0, BF 0 statt 1. INI/GE rechnet mit dem Grundwert der '
        'Waffe.',
      );
      expect(
        befund.vorschlag,
        'Verbesserung TP/KK −1/−1, TP +1, INI +1, AT +1, PA +1, BF −1',
      );
    });

    test('ohne TP/KK-Abweichung entfällt der INI/GE-Hinweis', () {
      final befund = _pruefe([_schwert.copyWith(tpFlat: 5)]).single;
      expect(befund.betrifftTpKk, isFalse);
      expect(
        befund.meldung,
        'Schwert weicht vom Katalog „Schwert“ ab: TP 1W6+5 statt 1W6+4.',
      );
    });

    test('vergleicht TP nur bei gleicher Würfelzahl', () {
      final zweiWuerfel = _schwert.copyWith(tpDiceCount: 2, tpFlat: 1);
      expect(_pruefe([zweiWuerfel]), isEmpty);
    });

    test('ein BF über dem Katalog ist Abnutzung, kein Befund', () {
      expect(_pruefe([_schwert.copyWith(breakFactor: 4)]), isEmpty);
      final befund = _pruefe([_schwert.copyWith(breakFactor: 0)])
          .single
          .abweichungen
          .single;
      expect(befund.art, WaffenGrundwertArt.bf);
      expect(befund.beschreibung, 'BF 0 statt 1');
    });

    test('ohne lesbaren Katalog-BF wird BF nicht verglichen', () {
      const ohneBf = WeaponDef(
        id: 'wpn_schwert',
        name: 'Schwert',
        type: 'Nahkampf',
        combatSkill: 'Schwerter',
        tp: '1W6+4',
        tpkk: '12/3',
      );
      final katalog = _katalog(const [ohneBf]);
      expect(
        _pruefe([_schwert.copyWith(breakFactor: 0)], katalog: katalog),
        isEmpty,
      );
    });

    test('Fernkampf: TP und AT ja, PA und TP/KK nicht', () {
      const bogen = MainWeaponSlot(
        name: 'Langbogen',
        weaponType: 'Langbogen',
        combatType: WeaponCombatType.ranged,
        kkBase: 10,
        kkThreshold: 3,
        tpFlat: 6,
        wmPa: 2,
      );
      expect(_pruefe(const [bogen]), isEmpty);
      final befund = _pruefe([bogen.copyWith(tpFlat: 7, wmAt: 1)]).single;
      expect(befund.abweichungen.map((a) => a.art), <WaffenGrundwertArt>[
        WaffenGrundwertArt.tp,
        WaffenGrundwertArt.at,
      ]);
    });

    test('wählt unter gleichnamigen Einträgen den mit den wenigsten '
        'Abweichungen', () {
      const zweihaendig = WeaponDef(
        id: 'wpn_schwert_zh',
        name: 'Schwert',
        type: 'Nahkampf',
        combatSkill: 'Zweihandschwerter',
        tp: '1W6+5',
        tpkk: '12/3',
        paMod: -1,
        breakFactor: '1',
      );
      final katalog = _katalog(const [_schwertDef, zweihaendig]);
      final befund = _pruefe([
        _schwert.copyWith(tpFlat: 5, wmPa: -1, wmAt: 1),
      ], katalog: katalog).single;
      expect(befund.katalog.tp, (wuerfel: 1, zuschlag: 5));
      expect(befund.abweichungen.single.art, WaffenGrundwertArt.at);
    });
  });

  group('uebernimmKatalogAbweichungAlsModifikation', () {
    test('verschiebt den TP/KK-Unterschied in die Verbesserung', () {
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        _meisterlich,
        katalog: _schwertWerte,
      );
      expect(neu.kkBase, 12);
      expect(neu.kkThreshold, 3);
      expect(neu.kkBaseMod, -1);
      expect(neu.kkThresholdMod, -1);
      expect(computeWirksameTpKk(slot: neu), (basis: 11, schwelle: 2));
      expect(_pruefe([neu]), isEmpty);
    });

    test('verschiebt alle Unterschiede, die wirksamen Werte bleiben', () {
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        _vollVerbessert,
        katalog: _schwertWerte,
      );
      expect(neu.tpFlat, 4);
      expect(neu.tpFlatMod, 1);
      expect(neu.iniMod, 0);
      expect(neu.iniModMod, 1);
      expect(neu.wmAt, 0);
      expect(neu.wmAtMod, 1);
      expect(neu.wmPa, 0);
      expect(neu.wmPaMod, 1);
      expect(neu.breakFactor, 1);
      expect(neu.breakFactorMod, -1);
      expect(computeWirksamerBruchfaktor(neu), 0);
      expect(_pruefe([neu]), isEmpty);
    });

    test('rechnet eine vorhandene Verbesserung mit', () {
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        _meisterlich.copyWith(kkBaseMod: -1, tpFlat: 5, tpFlatMod: 1),
        katalog: _schwertWerte,
      );
      expect(neu.kkBaseMod, -2);
      expect(neu.kkThresholdMod, -1);
      expect(computeWirksameTpKk(slot: neu), (basis: 10, schwelle: 2));
      expect(neu.tpFlat, 4);
      expect(neu.tpFlatMod, 2);
    });

    test('arbeitet auf dem frisch geladenen Stand', () {
      // Zwischen Prüfung und Schreiben kam eine TP-Abweichung hinzu.
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        _meisterlich.copyWith(tpFlat: 6),
        katalog: _schwertWerte,
      );
      expect(neu.tpFlat, 4);
      expect(neu.tpFlatMod, 2);
      expect(neu.kkBase, 12);
    });

    test('hebt eine frühere Bestätigung auf', () {
      final akzeptiert = akzeptiereKatalogAbweichung(
        _meisterlich,
        katalogName: 'Schwert',
        katalog: _schwertWerte,
      );
      final neu = uebernimmKatalogAbweichungAlsModifikation(
        akzeptiert,
        katalog: _schwertWerte,
      );
      expect(neu.katalogAbgleichAkzeptiert, isEmpty);
    });
  });

  group('akzeptiereKatalogAbweichung', () {
    final akzeptiert = akzeptiereKatalogAbweichung(
      _meisterlich,
      katalogName: 'Schwert',
      katalog: _schwertWerte,
    );

    test('lässt die Werte und schweigt danach', () {
      expect(akzeptiert.kkBase, 11);
      expect(akzeptiert.kkThreshold, 2);
      expect(akzeptiert.katalogAbgleichAkzeptiert, 'Schwert|TP/KK 11/2:12/3');
      expect(_pruefe([akzeptiert]), isEmpty);
    });

    test('Schlüssel nennt alle abweichenden Grundwerte', () {
      final alle = akzeptiereKatalogAbweichung(
        _vollVerbessert,
        katalogName: 'Schwert',
        katalog: _schwertWerte,
      );
      expect(
        alle.katalogAbgleichAkzeptiert,
        'Schwert|TP/KK 11/2:12/3;TP 1W6+5:1W6+4;INI +1:±0;AT +1:±0;'
        'PA +1:±0;BF 0:1',
      );
      expect(_pruefe([alle]), isEmpty);
    });

    test('meldet erneut, wenn sich die Waffe ändert', () {
      expect(_pruefe([akzeptiert.copyWith(kkBase: 10)]), hasLength(1));
      expect(_pruefe([akzeptiert.copyWith(wmAt: 2)]), hasLength(1));
    });

    test('meldet erneut, wenn sich der Katalog ändert', () {
      const neuerKatalogwert = WeaponDef(
        id: 'wpn_schwert',
        name: 'Schwert',
        type: 'Nahkampf',
        combatSkill: 'Schwerter',
        tp: '1W6+4',
        tpkk: '13/3',
        breakFactor: '1',
      );
      final katalog = _katalog(const [neuerKatalogwert]);
      expect(_pruefe([akzeptiert], katalog: katalog), hasLength(1));
    });

    test('wird nur bei Belegung gespeichert und übersteht den Umlauf', () {
      expect(
        _meisterlich.toJson().containsKey('katalogAbgleichAkzeptiert'),
        isFalse,
      );
      final geladen = MainWeaponSlot.fromJson(akzeptiert.toJson());
      expect(geladen.katalogAbgleichAkzeptiert, 'Schwert|TP/KK 11/2:12/3');
      expect(geladen.unbekannteFelder, isEmpty);
    });
  });

  group('Katalogwerte lesen', () {
    test('leseKatalogTpKk liest Basis und Schwelle', () {
      expect(leseKatalogTpKk('12/3'), (basis: 12, schwelle: 3));
      expect(leseKatalogTpKk(' 14 / 4 '), (basis: 14, schwelle: 4));
      expect(leseKatalogTpKk('-'), isNull);
    });

    test('leseKatalogTp liest Würfel und Zuschlag samt Zusätzen', () {
      expect(leseKatalogTp('1W6+4'), (wuerfel: 1, zuschlag: 4));
      expect(leseKatalogTp('2W6+6*'), (wuerfel: 2, zuschlag: 6));
      expect(leseKatalogTp('1W6(A)*'), (wuerfel: 1, zuschlag: 0));
      expect(leseKatalogTp('1W6-1'), (wuerfel: 1, zuschlag: -1));
      expect(leseKatalogTp(''), isNull);
    });

    test('leseKatalogBruchfaktor liest nur einzelne Zahlen', () {
      expect(leseKatalogBruchfaktor('2'), 2);
      expect(leseKatalogBruchfaktor('-2'), -2);
      expect(leseKatalogBruchfaktor(''), isNull);
      expect(leseKatalogBruchfaktor('-'), isNull);
      expect(leseKatalogBruchfaktor('je nach Schild'), isNull);
    });
  });
}
