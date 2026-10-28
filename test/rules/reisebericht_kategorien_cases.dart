part of 'reisebericht_rules_test.dart';

void _reiseberichtKategorien() {
  group('reiseberichtKategorien', () {
    test('hat 6 Kategorien', () {
      expect(reiseberichtKategorien.length, 6);
    });

    test('enthalt alle erwarteten Schluessel', () {
      expect(reiseberichtKategorien, contains('kampferfahrungen'));
      expect(reiseberichtKategorien, contains('koerperliche_erprobungen'));
      expect(reiseberichtKategorien, contains('gesellschaftliche_erfahrungen'));
      expect(reiseberichtKategorien, contains('naturerfahrungen'));
      expect(reiseberichtKategorien, contains('spirituelle_erfahrungen'));
      expect(reiseberichtKategorien, contains('magische_erfahrungen'));
    });
  });
}
