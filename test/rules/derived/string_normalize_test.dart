import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

void main() {
  group('suchFaltung (REV-08)', () {
    test('Umlaut, Umschreibung und Grundbuchstabe fallen zusammen', () {
      expect(suchFaltung('Betäubung'), 'betaubung');
      expect(suchFaltung('Betaeubung'), 'betaubung');
      expect(suchFaltung('Betaubung'), 'betaubung');
      expect(suchFaltung('Größe'), suchFaltung('groesse'));
      expect(suchFaltung('Übung'), suchFaltung('uebung'));
    });

    test('schneidet Randleerzeichen ab und lässt innere stehen', () {
      expect(suchFaltung('  Alte Brücke '), 'alte brucke');
    });
  });

  group('vergleichsSchluessel (REV-30)', () {
    test('Umlaute werden zu Digraphen, Sonderzeichen zu einem Leerzeichen', () {
      expect(vergleichsSchluessel('Geländekunde (Wald)'), 'gelaendekunde wald');
      expect(vergleichsSchluessel('  Große  Stärke! '), 'grosse staerke');
    });

    test('Umlaut und Umschreibung führen zum selben Schlüssel', () {
      expect(
        vergleichsSchluessel('Geländekunde'),
        vergleichsSchluessel('Gelaendekunde'),
      );
    });
  });

  group('normalizeCombatToken', () {
    test('entfernt alles außer Buchstaben und Ziffern', () {
      expect(normalizeCombatToken(' Schwerter / Säbel '), 'schwertersaebel');
    });
  });

  group('containsNamedToken', () {
    test('findet Token unabhängig von Umlauten und Schreibweise', () {
      expect(containsNamedToken('Behäbig, Eisern', {'behabig'}), isTrue);
      expect(containsNamedToken('BEHÄBIG', {'behabig'}), isTrue);
      expect(containsNamedToken('Eisern; Flink', {'flink'}), isTrue);
    });

    test('ganze Token, keine Teilstücke', () {
      expect(containsNamedToken('Eiserner Wille', {'eisern'}), isFalse);
    });
  });
}
