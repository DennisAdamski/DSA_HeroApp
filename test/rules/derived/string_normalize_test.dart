import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_summen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';
import 'package:dsa_heldenverwaltung/rules/derived/sync_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_anzeige_rules.dart';

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

  test('wundenText nennt die Einzahl nur bei genau einer Wunde', () {
    expect(wundenText(1), '1 Wunde');
    expect(wundenText(0), '0 Wunden');
    expect(wundenText(3), '3 Wunden');
  });

  test('formatiereGewichtGramm nutzt das Dezimalkomma (REV-36)', () {
    expect(formatiereGewichtGramm(850), '850 g');
    expect(formatiereGewichtGramm(1500), '1,5 kg');
    expect(formatiereGewichtGramm(2000), '2 kg');
    expect(formatiereGewichtGramm(0), '0 g');
    expect(formatiereGewichtGramm(0, nullText: '–'), '–');
  });

  test('formatiereSyncZeitpunkt zeigt Tag und Jahr nur bei Abweichung', () {
    final jetzt = DateTime(2026, 11, 7, 18, 0);
    expect(
      formatiereSyncZeitpunkt(DateTime(2026, 11, 7, 14, 3), jetzt: jetzt),
      'um 14:03',
    );
    expect(
      formatiereSyncZeitpunkt(DateTime(2026, 11, 6, 9, 5), jetzt: jetzt),
      'am 06.11. 09:05',
    );
    expect(
      formatiereSyncZeitpunkt(DateTime(2025, 12, 31, 23, 59), jetzt: jetzt),
      'am 31.12.2025 23:59',
    );
  });

  test('Dukaten lassen sich als Dezimalzahl und in Münzen lesen', () {
    expect(parseDsaCurrencyToKreuzer('12 D 5 S'), 12500);
    expect(parseDsaCurrencyToKreuzer('12,5'), 12500);
    expect(parseDsaCurrencyToKreuzer(''), 0);
    expect(parseDsaCurrencyToKreuzer('abc'), isNull);
  });
}
