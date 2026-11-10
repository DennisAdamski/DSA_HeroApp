import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';

void main() {
  group('parseOrte', () {
    test('liest Einträge samt Stand', () {
      final katalog = parseOrte(<String, Object?>{
        'stand': '2026-11-10',
        'orte': <Object?>[
          <String, Object?>{
            'name': 'Havena',
            'art': 'siedlung',
            'region': 'Albernia: Muhrsape',
            'seite': 'Havena (Siedlung)',
          },
          <String, Object?>{
            'name': 'Dunkelwald',
            'art': 'region',
            'unterart': 'Wald',
          },
        ],
      });

      expect(katalog.stand, '2026-11-10');
      expect(katalog.verworfen, isEmpty);
      expect(katalog.orte.map((o) => o.name), <String>['Havena', 'Dunkelwald']);
      expect(katalog.orte.first.art, OrtArt.siedlung);
      expect(katalog.orte.first.seite, 'Havena (Siedlung)');
      expect(katalog.orte.first.untertitel, 'Siedlung · Albernia: Muhrsape');
      expect(katalog.orte.last.untertitel, 'Wald');
      expect(katalog.orte.first.hatKartenlink, isTrue);
      expect(katalog.orte.last.hatKartenlink, isFalse);
    });

    test('verwirft unvollständige Einträge mit Grund', () {
      final katalog = parseOrte(<String, Object?>{
        'orte': <Object?>[
          'Text',
          <String, Object?>{'name': '', 'art': 'siedlung'},
          <String, Object?>{'name': 'X', 'art': 'unbekannt'},
          <String, Object?>{'name': 'Gareth', 'art': 'siedlung'},
        ],
      });

      expect(katalog.orte.map((o) => o.name), <String>['Gareth']);
      expect(katalog.verworfen, hasLength(3));
    });

    test('ungültige Wurzel ergibt einen leeren Katalog', () {
      expect(parseOrte(null).orte, isEmpty);
      expect(parseOrte(<Object?>[]).orte, isEmpty);
      expect(parseOrte(<String, Object?>{'orte': 3}).orte, isEmpty);
    });
  });

  group('ladeOrte', () {
    test('fehlendes Asset ergibt einen leeren Katalog', () async {
      final katalog = await ladeOrte(
        lader: (_) async => throw StateError('fehlt'),
      );
      expect(katalog.orte, isEmpty);
    });

    test('kaputtes JSON ergibt einen leeren Katalog', () async {
      final katalog = await ladeOrte(lader: (_) async => '{nicht json');
      expect(katalog.orte, isEmpty);
    });
  });

  group('Asset orte.json', () {
    late OrtKatalog katalog;

    setUpAll(() async {
      katalog = await ladeOrte(lader: (pfad) => File(pfad).readAsString());
    });

    test('ist lesbar und ohne verworfene Einträge', () {
      expect(katalog.verworfen, isEmpty);
      expect(katalog.stand, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('enthält Siedlungen und Regionen in Menge', () {
      int zahl(OrtArt art) => katalog.orte.where((o) => o.art == art).length;
      expect(zahl(OrtArt.siedlung), greaterThan(1000));
      expect(zahl(OrtArt.region), greaterThan(500));
    });

    test('kennt bekannte Orte unter ihrem einfachen Namen', () {
      bool siedlung(String name) =>
          katalog.orte.any((o) => o.name == name && o.art == OrtArt.siedlung);
      expect(siedlung('Gareth'), isTrue);
      expect(siedlung('Havena'), isTrue);
      expect(siedlung('Thorwal'), isTrue);
    });

    test('enthält keine Klammerzusätze im Namen und keine Duplikate', () {
      expect(katalog.orte.any((o) => o.name.endsWith(')')), isFalse);
      final schluessel = katalog.orte.map((o) => '${o.name}|${o.art.name}');
      expect(schluessel.toSet().length, katalog.orte.length);
    });
  });
}
