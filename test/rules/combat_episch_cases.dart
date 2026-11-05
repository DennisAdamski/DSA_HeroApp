part of 'combat_rules_test.dart';

void _combatEpisch() {
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
