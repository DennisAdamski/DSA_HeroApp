import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

void main() {
  group('buildRulesMatchExpression', () {
    test('liefert leeren Ausdruck fuer leere Eingabe', () {
      expect(buildRulesMatchExpression(''), isEmpty);
      expect(buildRulesMatchExpression('   '), isEmpty);
    });

    test('quotet Einzeltoken und haengt Praefix-Stern an', () {
      expect(buildRulesMatchExpression('Ausweichen'), '"Ausweichen" *');
    });

    test('verknuepft mehrere Tokens mit implizitem UND', () {
      expect(
        buildRulesMatchExpression('Ausweichen Behinderung'),
        '"Ausweichen" "Behinderung" *',
      );
    });

    test('entfernt Anfuehrungszeichen aus der Nutzereingabe', () {
      expect(
        buildRulesMatchExpression('"Binden" Parade'),
        '"Binden" "Parade" *',
      );
    });

    test('ignoriert Mehrfach-Leerzeichen zwischen Tokens', () {
      expect(
        buildRulesMatchExpression('  Wunden   Kopf  '),
        '"Wunden" "Kopf" *',
      );
    });
  });

  group('RulesSourceCategory.fromId', () {
    test('loest bekannte IDs auf', () {
      expect(
        RulesSourceCategory.fromId('hausregeln'),
        RulesSourceCategory.hausregeln,
      );
      expect(
        RulesSourceCategory.fromId('regelbuecher'),
        RulesSourceCategory.regelbuecher,
      );
    });

    test('liefert null fuer unbekannte IDs', () {
      expect(RulesSourceCategory.fromId('unbekannt'), isNull);
    });
  });
}
