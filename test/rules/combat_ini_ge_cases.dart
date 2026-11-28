part of 'combat_rules_test.dart';

/// INI/GE rechnet mit den Grundwerten der unveränderten Waffe (Hausregel
/// „Erweiterung und Überarbeitung des Regelwerks“, INI/GE = 26/7 − TP/KK).
/// Verbesserungen der Waffe und TP/KK-Verschiebungen durch Waffen- oder
/// Großmeister wirken nur auf den Schaden.
void _combatIniGe() {
  group('INI/GE aus den Grundwerten der Waffe', () {
    const schwert = MainWeaponSlot(
      name: 'Schwert',
      talentId: 'tal_schwerter',
      weaponType: 'Schwert',
      kkBase: 12,
      kkThreshold: 3,
    );
    const tpKkMeisterschaft = <WaffenmeisterConfig>[
      WaffenmeisterConfig(
        talentId: 'tal_schwerter',
        weaponType: 'Schwert',
        bonuses: <WaffenmeisterBonus>[
          WaffenmeisterBonus(type: WaffenmeisterBonusType.tpKkReduction),
        ],
      ),
    ];

    const gm = CombatSpecialRules(
      activeCombatSpecialAbilityIds: <String>['esf_grossmeister_saebel'],
    );

    // Vorschau mit GE 22 und KK 16, wahlweise mit Waffenmeisterschaft.
    CombatPreviewStats mit(
      MainWeaponSlot waffe, {
      List<WaffenmeisterConfig> waffenmeister = const <WaffenmeisterConfig>[],
    }) {
      final sheet = heroWithAttributes(
        ge: 22,
        kk: 16,
        combatConfig: CombatConfig(
          mainWeapon: waffe,
          waffenmeisterschaften: waffenmeister,
        ),
      );
      return preview(sheet);
    }

    test('unveränderte Waffe 12/3 ergibt GE/INI 14/4', () {
      final result = mit(schwert);
      expect(result.tpKk, 1); // (16 − 12) / 3
      expect(result.geBase, 14);
      expect(result.geThreshold, 4);
      expect(result.iniGe, 2); // (22 − 14) / 4
    });

    test('meisterlich geschmiedet (−1/−1) verbessert nur TP/KK', () {
      final ohne = mit(schwert);
      final result = mit(schwert.copyWith(kkBaseMod: -1, kkThresholdMod: -1));
      expect(result.tpKk, 2); // (16 − 11) / 2
      expect(result.geBase, 14);
      expect(result.geThreshold, 4);
      expect(result.iniGe, 2);
      expect(
        result.kombinierteHeldenWaffenIni,
        ohne.kombinierteHeldenWaffenIni,
      );
      final schritte = result.herleitungen!.tpZuschlag.schritte;
      final tpKkSchritt = schritte.firstWhere((s) => s.bezeichnung == 'TP/KK');
      expect(tpKkSchritt.formel, '(KK 16 − 11) / 2, ganzzahlig');
      expect(
        tpKkSchritt.bedingung,
        'Verbesserung der Waffe: Basis −1, Schwelle −1',
      );
    });

    test('Waffenmeister TP/KK −1/−1 lässt INI/GE unverändert', () {
      final result = mit(schwert, waffenmeister: tpKkMeisterschaft);
      expect(result.waffenmeisterTpKkBaseReduction, -1);
      expect(result.tpKk, 2); // (16 − 11) / 2
      expect(result.geBase, 14);
      expect(result.geThreshold, 4);
      expect(result.iniGe, 2); // nicht (22 − 15) / 5 = 1
    });

    test('Verbesserung und Waffenmeister addieren sich nur im Schaden', () {
      final result = mit(
        schwert.copyWith(kkBaseMod: -1, kkThresholdMod: -1),
        waffenmeister: tpKkMeisterschaft,
      );
      expect(result.tpKk, 6); // (16 − 10) / 1
      expect(result.geBase, 14);
      expect(result.geThreshold, 4);
      expect(result.iniGe, 2);
    });

    test('Großmeister-TP/KK (Khunchomer) lässt GE/INI unverändert', () {
      const khunchomer = MainWeaponSlot(
        talentId: 'tal_saebel',
        name: 'Khunchomer',
        weaponType: 'Khunchomer',
        kkBase: 12,
        kkThreshold: 4,
      );
      final result = preview(
        heroWithAttributes(
          ge: 22,
          kk: 22,
          combatConfig: const CombatConfig(
            mainWeapon: khunchomer,
            specialRules: gm,
          ),
        ),
      );
      expect(result.tpKk, 3); // (22 − 13) / 3
      expect(result.geBase, 14);
      expect(result.geThreshold, 3);
    });
  });

  group('MainWeaponSlot: Verbesserung der Waffe', () {
    test('wird nur bei Belegung geschrieben', () {
      const slot = MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 3);
      final json = slot.toJson();
      expect(json.containsKey('kkBaseMod'), isFalse);
      expect(json.containsKey('kkThresholdMod'), isFalse);
    });

    test('übersteht den JSON-Umlauf ohne unbekannte Felder', () {
      const slot = MainWeaponSlot(
        name: 'Schwert',
        kkBase: 12,
        kkThreshold: 3,
        kkBaseMod: -1,
        kkThresholdMod: -1,
      );
      final geladen = MainWeaponSlot.fromJson(slot.toJson());
      expect(geladen.kkBase, 12);
      expect(geladen.kkThreshold, 3);
      expect(geladen.kkBaseMod, -1);
      expect(geladen.kkThresholdMod, -1);
      expect(geladen.unbekannteFelder, isEmpty);
    });
  });
}
