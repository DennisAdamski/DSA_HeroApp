import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_calendar_rules.dart';

AventurianDate _d(String tag, String monat, String jahr) =>
    AventurianDate(day: tag, month: monat, year: jahr);

void main() {
  group('naechsterAventurischerTag', () {
    test('zaehlt innerhalb eines Monats weiter', () {
      final weiter = naechsterAventurischerTag(_d('12', 'phex', '1043'))!;
      expect([weiter.day, weiter.month, weiter.year], ['13', 'phex', '1043']);
    });

    test('rollt nach dem 30. in den naechsten Goettermonat', () {
      final weiter = naechsterAventurischerTag(_d('30', 'tsa', '1043'))!;
      // Phex steht zwischen Tsa und Peraine.
      expect([weiter.day, weiter.month, weiter.year], ['1', 'phex', '1043']);
    });

    test('rollt nach Rahja in die Namenlosen Tage', () {
      final weiter = naechsterAventurischerTag(_d('30', 'rahja', '1043'))!;
      expect([weiter.day, weiter.month], ['1', 'namenlose_tage']);
      expect(weiter.year, '1043');
    });

    test('rollt nach den Namenlosen Tagen ins neue Jahr', () {
      final weiter = naechsterAventurischerTag(
        _d('5', 'namenlose_tage', '1043'),
      )!;
      expect([weiter.day, weiter.month, weiter.year], ['1', 'praios', '1044']);
    });

    test('erhaelt die Jahresschreibweise', () {
      final weiter = naechsterAventurischerTag(
        _d('5', 'namenlose_tage', '1043 BF'),
      )!;
      expect(weiter.year, '1044 BF');
    });

    test('nimmt Anzeigenamen und ungetrimmte Teile an', () {
      final weiter = naechsterAventurischerTag(
        AventurianDate.fromParts(' 29 ', 'Praios', ' 1000 '),
      )!;
      expect([weiter.day, weiter.month, weiter.year], ['30', 'praios', '1000']);
    });

    test('ist ohne lesbares Datum null', () {
      expect(naechsterAventurischerTag(_d('', 'praios', '1043')), isNull);
      expect(naechsterAventurischerTag(_d('1', '', '1043')), isNull);
      expect(naechsterAventurischerTag(_d('1', 'praios', '')), isNull);
      expect(naechsterAventurischerTag(_d('1', 'praios', 'BF')), isNull);
      // Tag ausserhalb des Monats: nichts raten.
      expect(naechsterAventurischerTag(_d('31', 'praios', '1043')), isNull);
      expect(
        naechsterAventurischerTag(_d('6', 'namenlose_tage', '1043')),
        isNull,
      );
    });

    test('behaelt unbekannte Felder', () {
      const datum = AventurianDate(
        day: '1',
        month: 'praios',
        year: '1043',
        unbekannteFelder: {'zukunft': 1},
      );
      expect(naechsterAventurischerTag(datum)!.unbekannteFelder, {
        'zukunft': 1,
      });
    });
  });

  group('addAventurianDays', () {
    test('ein ganzes Jahr bringt dasselbe Datum im Folgejahr', () {
      final weiter = addAventurianDays(
        _d('7', 'efferd', '1043'),
        aventurianDaysPerYear,
      )!;
      expect([weiter.day, weiter.month, weiter.year], ['7', 'efferd', '1044']);
    });

    test('rechnet auch rueckwaerts ueber die Jahresgrenze', () {
      final zurueck = addAventurianDays(_d('1', 'praios', '1043'), -1)!;
      expect(
        [zurueck.day, zurueck.month, zurueck.year],
        ['5', 'namenlose_tage', '1042'],
      );
    });
  });

  group('aventurianTagUndMonat (REV-14)', () {
    test('ist das Gegenstück zu aventurianDayOfYear', () {
      for (final nummer in [1, 30, 31, 360, 361, 365]) {
        final (:tag, :monat) = aventurianTagUndMonat(nummer);
        expect(
          aventurianDayOfYear(
            AventurianDate(day: '$tag', month: monat.value, year: '1040'),
          ),
          nummer,
        );
      }
      expect(aventurianTagUndMonat(31).monat.value, 'rondra');
      expect(aventurianTagUndMonat(365).tag, 5);
    });
  });
}
