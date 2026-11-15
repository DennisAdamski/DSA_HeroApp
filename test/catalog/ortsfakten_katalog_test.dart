import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/ortsfakten_loader.dart';

void main() {
  group('parseOrtsfakten', () {
    test('liest Fakten und Bauwerke, übergeht Unlesbares', () {
      final katalog = parseOrtsfakten(<String, Object?>{
        'stand': '2026-11-13',
        'siedlungen': <String, Object?>{
          'Punin': <String, Object?>{
            'einwohner': 27500,
            'einwohnerText': ' 27500 (1040 BF) ',
            'oberhaupt': 'Ratsmeister',
            'verkehrswege': <Object?>['Yaquir', '', 3, 'Reichsstraße 2'],
            'unbekannt': true,
          },
          'Leer': <String, Object?>{},
          'Kaputt': 'kein Objekt',
          'Minus': <String, Object?>{'einwohner': -5},
        },
        'bauwerke': <Object?>[
          <String, Object?>{
            'name': 'Phex-Tempel in Punin',
            'ort': 'Punin',
            'art': 'Tempel',
            'zugehoerigkeit': 'Phex-Kirche',
          },
          <String, Object?>{'name': 'Ohne Ort'},
          'kaputt',
        ],
      });
      expect(katalog.stand, '2026-11-13');
      expect(katalog.siedlungen.keys, <String>['Punin']);
      final punin = katalog.siedlungen['Punin']!;
      expect(punin.einwohner, 27500);
      expect(punin.einwohnerText, '27500 (1040 BF)');
      expect(punin.verkehrswege, <String>['Yaquir', 'Reichsstraße 2']);
      expect(katalog.bauwerke['Punin']!.single.zugehoerigkeit, 'Phex-Kirche');
    });

    test(
      'ungültige Wurzel und fehlendes Asset ergeben einen leeren Katalog',
      () async {
        expect(parseOrtsfakten('x').siedlungen, isEmpty);
        final katalog = await ladeOrtsfakten(
          lader: (_) async => throw StateError('fehlt'),
        );
        expect(katalog.bauwerke, isEmpty);
      },
    );
  });

  group('Asset ortsfakten.json', () {
    final roh = jsonDecode(File(ortsfaktenAssetPfad).readAsStringSync());
    final katalog = parseOrtsfakten(roh);
    final orte = parseOrte(jsonDecode(File(ortAssetPfad).readAsStringSync()));
    final seiten = <String>{
      for (final o in orte.orte) o.seite.isNotEmpty ? o.seite : o.name,
    };

    test('ist lesbar, datiert und umfangreich', () {
      expect(katalog.stand, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(katalog.siedlungen.length, greaterThan(1000));
      expect(
        katalog.bauwerke.values.fold<int>(0, (n, l) => n + l.length),
        greaterThan(1000),
      );
    });

    test('Gareth und Punin tragen Einwohner, Oberhaupt und Tempel', () {
      expect(katalog.siedlungen['Gareth']!.einwohner, greaterThan(100000));
      expect(katalog.siedlungen['Gareth']!.oberhaupt, isNotEmpty);
      expect(katalog.siedlungen['Punin']!.einwohner, greaterThan(10000));
      expect(
        katalog.bauwerke['Punin']!.where((b) => b.art == 'Tempel'),
        isNotEmpty,
      );
    });

    test('fast alle Schlüssel sind Seiten des Ortsverzeichnisses', () {
      final fremd = katalog.siedlungen.keys.where((k) => !seiten.contains(k));
      // Wenige Abweichungen entstehen, wenn ein Name zugleich Region ist.
      expect(fremd.length, lessThan(katalog.siedlungen.length ~/ 50));
    });

    test('keine Beschreibungstexte: Angaben bleiben kurz', () {
      for (final f in katalog.siedlungen.values) {
        expect(f.einwohnerText.length, lessThanOrEqualTo(200));
        expect(f.oberhaupt.length, lessThanOrEqualTo(160));
      }
      for (final liste in katalog.bauwerke.values) {
        for (final b in liste) {
          expect(b.zugehoerigkeit.length, lessThanOrEqualTo(80));
        }
      }
    });
  });
}
