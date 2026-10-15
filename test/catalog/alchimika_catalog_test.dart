import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';

import '../test_support/real_catalog.dart';
import 'catalog_reference_names.dart';

// Würfelausdruck (`2W6+4`) oder die Wirkung „alle …“, die sich nicht als Zahl
// schreiben lässt.
final RegExp _wurf = RegExp(r'^(\d*W\d+([+-]\d+)?|alle .+)$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('alchimika.json (Rohdatei)', () {
    final roh = ladeKatalogDatei('alchimika.json');

    test('IDs sind gesetzt und eindeutig', () {
      final ids = roh.map((e) => '${e['id']}').toList();
      expect(ids.every((id) => id.startsWith('alch_')), isTrue);
      expect(ids.toSet().length, ids.length);
    });

    test('jedes Mittel nennt Buch, gedruckte Seite und Chunk als Beleg', () {
      for (final mittel in roh) {
        final beleg = mittel['beleg'] as Map<String, dynamic>;
        final reason = 'Mittel ${mittel['id']}';
        expect('${beleg['buch']}', isNotEmpty, reason: reason);
        expect('${beleg['seite']}', isNotEmpty, reason: reason);
        expect(beleg['chunkId'], isA<int>(), reason: reason);
      }
    });

    test('Qualitäten sind entweder leer oder vollständig A bis F', () {
      for (final mittel in roh) {
        final stufen = [
          for (final q in (mittel['qualitaeten'] as List))
            '${(q as Map)['stufe']}',
        ];
        expect(
          stufen.isEmpty || stufen.join() == kAlchimikaStufen.join(),
          isTrue,
          reason: 'Mittel ${mittel['id']}: $stufen',
        );
      }
    });

    test('Würfelvorschläge sind gültige Ausdrücke', () {
      for (final mittel in roh) {
        for (final q in (mittel['qualitaeten'] as List).cast<Map>()) {
          for (final feld in const ['lepWurf', 'aspWurf', 'aupWurf']) {
            final wert = q[feld];
            if (wert == null) {
              continue;
            }
            expect(
              _wurf.hasMatch('$wert'),
              isTrue,
              reason: '${mittel['id']} ${q['stufe']} $feld: $wert',
            );
          }
        }
      }
    });

    test('Wirkungstexte bleiben kurze eigene Zusammenfassungen', () {
      // Schutz gegen versehentlich kopierte Buchabsätze.
      for (final mittel in roh) {
        expect('${mittel['wirkung'] ?? ''}'.length, lessThan(260));
        for (final q in (mittel['qualitaeten'] as List).cast<Map>()) {
          expect(
            '${q['wirkung'] ?? ''}'.length,
            lessThan(260),
            reason: '${mittel['id']} ${q['stufe']}',
          );
        }
      }
    });

    test('Startliste ist vollständig vorhanden', () {
      expect(
        roh.map((e) => e['id']),
        containsAll(<String>[
          'alch_heiltrank',
          'alch_pastillen_erschoepfung',
          'alch_restorarium',
          'alch_schlaftrunk',
          'alch_antidot',
          'alch_wundpulver',
        ]),
      );
    });
  });

  group('Katalog zur Laufzeit', () {
    test(
      'RulesCatalog.alchimika enthält alle Mittel aus der Rohdatei',
      () async {
        final echt = await ladeEchtenRegelkatalog();
        final roh = ladeKatalogDatei('alchimika.json');
        expect(
          echt.catalog.alchimika.map((m) => m.id),
          roh.map((e) => e['id']),
        );
      },
    );

    test('Heiltrank trägt die belegten Werte aus Wege der Alchimie', () async {
      final echt = await ladeEchtenRegelkatalog();
      final heiltrank = echt.catalog.alchimika.firstWhere(
        (m) => m.id == 'alch_heiltrank',
      );
      expect(heiltrank.beleg.buch, contains('Wege der Alchimie'));
      expect(heiltrank.beleg.seite, '56');
      expect(heiltrank.preisSilber, 100);
      expect(heiltrank.qualitaeten.map((q) => q.lepWurf), [
        '1W6',
        '1W6+2',
        '2W6+4',
        '3W6+6',
        'alle fehlenden LeP',
        '3W6+25',
      ]);
      expect(
        heiltrank.qualitaeten.every((q) => q.lepProWunde == 7),
        isTrue,
        reason: 'Pro 7 LeP eine Wunde (WdA S. 56, Basisregelwerk S. 197)',
      );
    });
  });
}
