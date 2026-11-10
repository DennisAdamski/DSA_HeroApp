import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/kraeuter_loader.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';

void main() {
  group('parseKraeuter', () {
    test('liest Einträge samt Stand und Vorkommen', () {
      final katalog = parseKraeuter(<String, Object?>{
        'stand': '2026-11-11',
        'kraeuter': <Object?>[
          <String, Object?>{
            'name': 'Donf',
            'bestimmung': 6,
            'wirkung': 'fiebersenkend',
            'vorkommen': <Object?>[
              <String, Object?>{
                'landschaft': 'dschungel',
                'haeufigkeit': 'selten',
                'hinweis': 'nur an Seeufern',
              },
              <String, Object?>{
                'landschaft': 'dschungel',
                'haeufigkeit': 'sehrSelten',
              },
            ],
          },
        ],
      });

      expect(katalog.stand, '2026-11-11');
      expect(katalog.verworfen, isEmpty);
      final donf = katalog.kraeuter.single;
      expect(donf.name, 'Donf');
      expect(donf.bestimmung, 6);
      expect(donf.wirkung, 'fiebersenkend');
      expect(donf.vorkommen, hasLength(2));
      expect(donf.vorkommen.first.landschaft, Kraeuterlandschaft.dschungel);
      expect(donf.vorkommen.first.haeufigkeit, Kraeuterhaeufigkeit.selten);
      expect(donf.vorkommen.first.hinweis, 'nur an Seeufern');
      expect(donf.vorkommen.last.hinweis, '');
    });

    test('liest Erntezeit, Erntemonate und Grundmenge', () {
      final katalog = parseKraeuter(<String, Object?>{
        'kraeuter': <Object?>[
          <String, Object?>{
            'name': 'Spät',
            'bestimmung': 4,
            'erntezeit': 'Hesinde bis Firun',
            'erntemonate': <Object?>['hesinde', 'Firun', 'kein Monat'],
            'grundmenge': '2W6 Blätter',
            'vorkommen': <Object?>[
              <String, Object?>{
                'landschaft': 'tundra',
                'haeufigkeit': 'haeufig',
              },
            ],
          },
          <String, Object?>{
            'name': 'Immer',
            'bestimmung': 4,
            'vorkommen': <Object?>[
              <String, Object?>{
                'landschaft': 'tundra',
                'haeufigkeit': 'haeufig',
              },
            ],
          },
        ],
      });
      final spaet = katalog.kraeuter.first;
      expect(spaet.erntezeit, 'Hesinde bis Firun');
      expect(spaet.erntemonate, <String>['hesinde', 'firun']);
      expect(spaet.grundmenge, '2W6 Blätter');
      expect(katalog.kraeuter.last.erntemonate, isEmpty);
      expect(katalog.kraeuter.last.grundmenge, '');
    });

    test('verwirft unvollständige Einträge mit Grund', () {
      final katalog = parseKraeuter(<String, Object?>{
        'kraeuter': <Object?>[
          'Text',
          <String, Object?>{'name': '', 'bestimmung': 1},
          <String, Object?>{'name': 'A', 'bestimmung': 'x'},
          <String, Object?>{'name': 'B', 'bestimmung': 1},
          <String, Object?>{
            'name': 'C',
            'bestimmung': 1,
            'vorkommen': <Object?>[
              <String, Object?>{
                'landschaft': 'nirgends',
                'haeufigkeit': 'selten',
              },
            ],
          },
          <String, Object?>{
            'name': 'Gut',
            'bestimmung': -2,
            'vorkommen': <Object?>[
              <String, Object?>{
                'landschaft': 'tundra',
                'haeufigkeit': 'haeufig',
              },
            ],
          },
        ],
      });

      expect(katalog.kraeuter.map((k) => k.name), <String>['Gut']);
      expect(katalog.kraeuter.single.bestimmung, -2);
      expect(katalog.verworfen, hasLength(5));
    });

    test('ungültige Wurzel ergibt einen leeren Katalog', () {
      expect(parseKraeuter(null).kraeuter, isEmpty);
      expect(parseKraeuter(<Object?>[]).kraeuter, isEmpty);
      expect(parseKraeuter(<String, Object?>{'kraeuter': 3}).kraeuter, isEmpty);
    });
  });

  group('ladeKraeuter', () {
    test('fehlendes Asset ergibt einen leeren Katalog', () async {
      final katalog = await ladeKraeuter(
        lader: (_) async => throw StateError('fehlt'),
      );
      expect(katalog.kraeuter, isEmpty);
    });

    test('kaputtes JSON ergibt einen leeren Katalog', () async {
      final katalog = await ladeKraeuter(lader: (_) async => '{nicht json');
      expect(katalog.kraeuter, isEmpty);
    });
  });

  group('Asset kraeuter.json', () {
    late KraeuterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeKraeuter(lader: (pfad) => File(pfad).readAsString());
    });

    KrautEintrag kraut(String name) =>
        katalog.kraeuter.firstWhere((k) => k.name == name);

    test('ist lesbar und ohne verworfene Einträge', () {
      expect(katalog.verworfen, isEmpty);
      expect(katalog.stand, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(katalog.kraeuter, hasLength(47));
    });

    test('Namen sind eindeutig, jedes Kraut kommt irgendwo vor', () {
      final namen = katalog.kraeuter.map((k) => k.name).toList();
      expect(namen.toSet(), hasLength(namen.length));
      expect(katalog.kraeuter.every((k) => k.vorkommen.isNotEmpty), isTrue);
    });

    test('jede Landschaft hat Einträge', () {
      for (final landschaft in Kraeuterlandschaft.values) {
        expect(
          katalog.kraeuter.any(
            (k) => k.vorkommen.any((v) => v.landschaft == landschaft),
          ),
          isTrue,
          reason: landschaft.bezeichnung,
        );
      }
    });

    test('jedes Kraut hat Erntezeit und Grundmenge (Zoo Botanica)', () {
      for (final kraut in katalog.kraeuter) {
        expect(kraut.erntezeit, isNotEmpty, reason: kraut.name);
        expect(kraut.grundmenge, isNotEmpty, reason: kraut.name);
      }
    });

    test('Erntemonate: Jahreswechsel, ganzjährig und Winterausschluss', () {
      final zwoelfblatt = kraut('Zwölfblatt');
      expect(zwoelfblatt.erntezeit, 'Hesinde bis Praios');
      expect(zwoelfblatt.erntemonate.toSet(), <String>{
        'hesinde',
        'firun',
        'tsa',
        'phex',
        'peraine',
        'ingerimm',
        'rahja',
        'namenlose_tage',
        'praios',
      });
      expect(zwoelfblatt.grundmenge, '12 Stängel pro Pflanze');

      expect(kraut('Alraune').erntemonate, isEmpty);
      expect(kraut('Tigermohn').erntemonate, <String>['travia']);

      final wirsel = kraut('Wirselkraut').erntemonate;
      expect(wirsel, hasLength(10));
      expect(wirsel.contains('firun') || wirsel.contains('tsa'), isFalse);
      expect(wirsel.contains('phex'), isFalse);
    });

    test('Erntemonate sind gültige, eindeutige Kalendermonate', () {
      for (final kraut in katalog.kraeuter) {
        expect(
          kraut.erntemonate.toSet(),
          hasLength(kraut.erntemonate.length),
          reason: kraut.name,
        );
        for (final monat in kraut.erntemonate) {
          expect(
            aventurianMonths.any((m) => m.value == monat),
            isTrue,
            reason: '${kraut.name}: $monat',
          );
        }
      }
    });

    test('Stichproben stimmen mit WdE S. 114–118 überein', () {
      final wirsel = kraut('Wirselkraut');
      expect(wirsel.bestimmung, 5);
      expect(
        wirsel.vorkommen
            .where((v) => v.landschaft == Kraeuterlandschaft.tundra)
            .single
            .haeufigkeit,
        Kraeuterhaeufigkeit.haeufig,
      );
      expect(
        wirsel.vorkommen
            .where((v) => v.landschaft == Kraeuterlandschaft.savanneSteppe)
            .single
            .haeufigkeit,
        Kraeuterhaeufigkeit.haeufig,
      );

      final satuarien = kraut('Satuariensbusch');
      expect(satuarien.bestimmung, -2);

      final donf = kraut('Donf');
      expect(
        donf.vorkommen.where(
          (v) => v.landschaft == Kraeuterlandschaft.dschungel,
        ),
        hasLength(2),
        reason: 'Seeufer (selten) und Flussufer (sehr selten)',
      );

      final thonnys = kraut('Thonnys');
      expect(thonnys.bestimmung, 12);
      expect(thonnys.bestimmungHinweis, contains('Blüte'));

      final hochgebirge = katalog.kraeuter
          .where(
            (k) => k.vorkommen.any(
              (v) => v.landschaft == Kraeuterlandschaft.hochgebirge,
            ),
          )
          .map((k) => k.name)
          .toSet();
      expect(hochgebirge, <String>{
        'Atan-Kiefer',
        'Atmon',
        'Blutblatt',
        'Olginwurz',
        'Bleichmohn',
        'Talaschin',
      });
    });
  });
}
