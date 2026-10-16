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

    test('Eigenschaftswirkungen nennen Kürzel, Zahl und Dauer vollständig', () {
      const kuerzel = {'MU', 'KL', 'IN', 'CH', 'FF', 'GE', 'KO', 'KK'};
      const einheiten = {'spielrunden', 'stunden', 'tage'};
      for (final mittel in roh) {
        for (final q in (mittel['qualitaeten'] as List).cast<Map>()) {
          for (final e
              in ((q['eigenschaften'] as List?) ?? const []).cast<Map>()) {
            final grund = '${mittel['id']} ${q['stufe']}: $e';
            expect(kuerzel, contains(e['eigenschaft']), reason: grund);
            expect(e['wert'], isA<int>(), reason: grund);
            expect(e['wert'], isNot(0), reason: grund);
            expect(e['dauer'], isA<int>(), reason: grund);
            expect(e['dauer'] as int, greaterThan(0), reason: grund);
            expect(einheiten, contains(e['einheit']), reason: grund);
          }
        }
      }
    });

    test('die acht Elixiere der Tugenden führen je Stufe eine Eigenschaft', () {
      const erwartet = {
        'alch_mutelixier': 'MU',
        'alch_klugheitselixier': 'KL',
        'alch_intuitionselixier': 'IN',
        'alch_charismaelixier': 'CH',
        'alch_fingerfertigkeitselixier': 'FF',
        'alch_gewandtheitselixier': 'GE',
        'alch_konstitutionselixier': 'KO',
        'alch_kraftelixier': 'KK',
      };
      for (final eintrag in erwartet.entries) {
        final mittel = roh.firstWhere((m) => m['id'] == eintrag.key);
        expect(mittel['gruppe'], 'Virtutica', reason: eintrag.key);
        final stufen = (mittel['qualitaeten'] as List).cast<Map>();
        expect(stufen, hasLength(6), reason: eintrag.key);
        for (final q in stufen) {
          final eigenschaften = (q['eigenschaften'] as List).cast<Map>();
          expect(
            eigenschaften.first['eigenschaft'],
            eintrag.value,
            reason: '${eintrag.key} ${q['stufe']}',
          );
          expect(
            eigenschaften.first['wert'] as int,
            greaterThan(0),
            reason: '${eintrag.key} ${q['stufe']}',
          );
        }
        // B bis D folgen dem festen Schema: Punkte = Spielrunden (2, 3, 7).
        for (final entry in {'B': 2, 'C': 3, 'D': 7}.entries) {
          final q = stufen.firstWhere((s) => s['stufe'] == entry.key);
          final e = ((q['eigenschaften'] as List).first as Map);
          expect(e['wert'], entry.value, reason: '${eintrag.key} ${entry.key}');
          expect(e['dauer'], entry.value);
          expect(e['einheit'], 'spielrunden');
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
