part of 'combat_rules_test.dart';

void _combatEpisch() {
  group('Waffen-Großmeister (Säbel), Epische Stufen S. 18', () {
    const gm = CombatSpecialRules(
      activeCombatSpecialAbilityIds: <String>['esf_grossmeister_saebel'],
    );
    test('übrige Säbel: GE/INI 0/-1 und Pool aus dem GE/INI-Bonus', () {
      const amazonensaebel = MainWeaponSlot(
        talentId: 'tal_saebel',
        name: 'Amazonensäbel',
        weaponType: 'Amazonensäbel',
        kkBase: 11,
        kkThreshold: 4,
      );
      final ohne = preview(
        heroWithAttributes(
          ge: 21,
          combatConfig: const CombatConfig(mainWeapon: amazonensaebel),
        ),
      );
      final mit = preview(
        heroWithAttributes(
          ge: 21,
          combatConfig: const CombatConfig(
            mainWeapon: amazonensaebel,
            specialRules: gm,
          ),
        ),
      );
      expect(ohne.iniGe, 2);
      // Beispiel der Hausregel: GE 21, Amazonensäbel 15/2 → +3 INI, 3 Punkte.
      expect(mit.geThreshold, 2);
      expect(mit.iniGe, 3);
      expect(mit.meisterschaft.grossmeisterName, 'Waffen-Großmeister (Säbel)');
      expect(mit.meisterschaft.poolPunkte, 3);
      expect(
        mit.meisterschaft.grossmeisterWirkungen,
        contains('GE/INI 15/2 statt 15/3: INI +3'),
      );
    });

    test('Schalter GE statt KK verschiebt den TP/KK-Zuschlag auf GE', () {
      const amazonensaebel = MainWeaponSlot(
        talentId: 'tal_saebel',
        name: 'Amazonensäbel',
        weaponType: 'Amazonensäbel',
        kkBase: 11,
        kkThreshold: 4,
      );
      CombatPreviewStats mit({required bool schalter}) => preview(
        heroWithAttributes(
          ge: 21,
          kk: 12,
          combatConfig: CombatConfig(
            mainWeapon: amazonensaebel,
            specialRules: gm.copyWith(grossmeisterGeStattKk: schalter),
          ),
        ),
      );
      final aus = mit(schalter: false);
      final an = mit(schalter: true);
      expect(aus.tpKk, 0); // (12 − 11) / 4
      expect(an.tpKk, 2); // (21 − 11) / 4
      expect(an.tpCalc - aus.tpCalc, 2);
      expect(an.meisterschaft.geStattKkAktiv, isTrue);
      expect(aus.meisterschaft.tpKkMitGe, 2);
      expect(
        an.herleitungen!.tpZuschlag.schritte
            .firstWhere((s) => s.bezeichnung == 'TP/KK')
            .formel,
        startsWith('(GE 21'),
      );
    });

    test('Schalter ohne Großmeister bleibt wirkungslos', () {
      final sheet = heroWithAttributes(
        ge: 21,
        combatConfig: const CombatConfig(
          mainWeapon: MainWeaponSlot(
            talentId: 'tal_saebel',
            name: 'Säbel',
            weaponType: 'Säbel',
            kkBase: 12,
            kkThreshold: 4,
          ),
          specialRules: CombatSpecialRules(grossmeisterGeStattKk: true),
        ),
      );
      expect(preview(sheet).tpKk, 0);
      expect(preview(sheet).meisterschaft.sichtbar, isFalse);
    });

    test('wuchtartige Säbel: TP/KK +1/-1, Hammerschlag und Schildspalter', () {
      const khunchomer = MainWeaponSlot(
        talentId: 'tal_saebel',
        name: 'Khunchomer',
        weaponType: 'Khunchomer',
        kkBase: 12,
        kkThreshold: 4,
      );
      final mit = preview(
        heroWithAttributes(
          kk: 22,
          combatConfig: const CombatConfig(
            mainWeapon: khunchomer,
            specialRules: gm,
          ),
        ),
      );
      expect(mit.tpKk, 3); // (22 − 13) / 3 statt (22 − 12) / 4 = 2
      expect(
        mit.waffenmeisterAdditionalManeuvers,
        containsAll(<String>['man_hammerschlag', 'man_schildspalter']),
      );
      expect(mit.waffenmeisterName, isEmpty);
    });
  });

  group('epicFinteDefenseHint', () {
    test('erscheint bei epischer IN-Haupteigenschaft', () {
      final sheet = hero().copyWith(
        isEpisch: true,
        epicMainAttributes: const Attributes.zero().copyWith(inn: 1),
      );
      expect(
        preview(sheet).epicFinteDefenseHint,
        contains('Finten gegen dich sind um 2 erschwert'),
      );
    });

    test('leer ohne IN-Haupteigenschaft', () {
      final sheet = hero().copyWith(
        isEpisch: true,
        epicMainAttributes: const Attributes.zero().copyWith(kk: 1),
      );
      expect(preview(sheet).epicFinteDefenseHint, isEmpty);
    });

    test('leer bei abgeschaltetem Hausregel-Paket', () {
      final sheet = hero().copyWith(
        isEpisch: true,
        epicMainAttributes: const Attributes.zero().copyWith(inn: 1),
      );
      expect(
        computeCombatPreviewStats(
          sheet,
          state,
          epicAdvantagesRuleActive: false,
        ).epicFinteDefenseHint,
        isEmpty,
      );
    });
  });
}
