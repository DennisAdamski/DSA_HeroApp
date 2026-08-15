import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_constants.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';

void main() {
  group('Traditionstabelle (Wege der Zauberei S. 19)', () {
    test('verwendet Klugheit fuer die KL-Traditionen', () {
      for (final name in <String>[
        'Alchimist',
        'Borbaradianer',
        'Druide',
        'Geode (Herr der Erde)',
        'Gildenmagier',
        'Scharlatan',
        'Zibilja',
      ]) {
        expect(
          traditionByName(name)?.leiteigenschaft,
          'KL',
          reason: '$name sollte die Klugheit als Leiteigenschaft haben',
        );
      }
    });

    test('verwendet Intuition fuer die IN-Traditionen', () {
      for (final name in <String>[
        'Achaz-Kristallomant',
        'Derwisch',
        'Durro-Dûn',
        'Elf',
        'Ferkina-Besessener',
        'Geode (Diener Sumus)',
        'Hexe',
        'Schamane',
        'Schelm',
        'Zaubertänzer',
      ]) {
        expect(
          traditionByName(name)?.leiteigenschaft,
          'IN',
          reason: '$name sollte die Intuition als Leiteigenschaft haben',
        );
      }
    });

    test('deckt alle neun Repraesentationskuerzel ab', () {
      for (final kuerzel in kRepresentationen) {
        expect(
          traditionenFuerRepraesentation(kuerzel),
          isNotEmpty,
          reason: 'Zu $kuerzel fehlt eine Tradition',
        );
      }
    });

    test('erkennt Traditionen ueber Alias-Schreibweisen', () {
      expect(traditionByName('Gildenmagie')?.id, 'gildenmagier');
      expect(traditionByName('gildenmagisch')?.id, 'gildenmagier');
      expect(traditionByName('Kristallomantie')?.id, 'achaz_kristallomant');
      expect(traditionByName('Hexen')?.id, 'hexe');
    });

    test('kennt Traditionen ohne Repraesentation', () {
      for (final name in <String>[
        'Derwisch',
        'Zibilja',
        'Zaubertänzer',
        'Schamane',
        'Durro-Dûn',
        'Alchimist',
      ]) {
        expect(traditionByName(name)?.repraesentation, isEmpty);
      }
    });

    test('liefert fuer unbekannte Namen null', () {
      expect(traditionByName('Kartoffelmagier'), isNull);
      expect(traditionByName(''), isNull);
    });
  });

  group('Geoden-Aufspaltung', () {
    test('das Kuerzel Geo traegt zwei Traditionen', () {
      final traditionen = traditionenFuerRepraesentation('Geo');

      expect(traditionen.map((t) => t.id), <String>[
        'geode_herr_der_erde',
        'geode_diener_sumus',
      ]);
      expect(traditionen.first.leiteigenschaft, 'KL');
      expect(traditionen.last.leiteigenschaft, 'IN');
    });

    test('braucht eine Wahl, andere Repraesentationen nicht', () {
      expect(repraesentationBrauchtTraditionswahl('Geo'), isTrue);
      expect(repraesentationBrauchtTraditionswahl('Mag'), isFalse);
    });
  });

  group('resolveHeroTraditionen', () {
    test('leitet Traditionen aus Repraesentationen ab', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Mag', 'Hex'],
      );

      expect(
        traditionen.map((t) => t.id).toSet(),
        <String>{'gildenmagier', 'hexe'},
      );
    });

    test('leitet Traditionen aus Ritualkenntnissen ab', () {
      final traditionen = resolveHeroTraditionen(
        ritualkenntnisse: const <String>['Ritualkenntnis Derwisch'],
      );

      expect(traditionen.map((t) => t.id), <String>['derwisch']);
    });

    test('vereinigt beide Quellen ohne Duplikate', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Mag'],
        ritualkenntnisse: const <String>['Gildenmagie', 'Zibilja'],
      );

      expect(
        traditionen.map((t) => t.id).toSet(),
        <String>{'gildenmagier', 'zibilja'},
      );
      expect(traditionen, hasLength(2));
    });

    test('respektiert die gewaehlte Geoden-Tradition', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Geo'],
        gewaehlteTraditionen: const <String, String>{
          'Geo': 'geode_diener_sumus',
        },
      );

      expect(traditionen.map((t) => t.id), <String>['geode_diener_sumus']);
    });

    test('liefert ohne Wahl beide Geoden-Traditionen', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Geo'],
      );

      expect(traditionen, hasLength(2));
    });

    test('eine unspezifische Ritualkenntnis kippt die Wahl nicht', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Geo'],
        gewaehlteTraditionen: const <String, String>{
          'Geo': 'geode_diener_sumus',
        },
        ritualkenntnisse: const <String>['Geode'],
      );

      expect(traditionen.map((t) => t.id), <String>['geode_diener_sumus']);
    });

    test('ohne Wahl fuehrt eine Ritualkenntnis beide Auspraegungen', () {
      final traditionen = resolveHeroTraditionen(
        ritualkenntnisse: const <String>['Ritualkenntnis Geode'],
      );

      expect(traditionen, hasLength(2));
    });
  });

  group('leiteigenschaftenFuer', () {
    test('sammelt die Leiteigenschaften der Traditionen', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Mag', 'Elf'],
      );

      expect(leiteigenschaftenFuer(traditionen), <String>{'KL', 'IN'});
    });

    test('ein Override schlaegt die Traditionen', () {
      final traditionen = resolveHeroTraditionen(
        repraesentationen: const <String>['Mag'],
      );

      expect(
        leiteigenschaftenFuer(traditionen, override: 'CH'),
        <String>{'CH'},
      );
    });

    test('ohne Tradition und ohne Override bleibt die Menge leer', () {
      expect(leiteigenschaftenFuer(const <TraditionDef>[]), isEmpty);
    });
  });
}
