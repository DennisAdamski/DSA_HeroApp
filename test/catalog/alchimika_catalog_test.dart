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
      // Schutz gegen versehentlich kopierte Buchabsätze. Verschlüsselte
      // Texte (Harte Regel 13) prüft `geschuetzte_langtexte_test.dart`;
      // ihre Länge sagt über den Klartext nichts Genaues.
      int laenge(Object? wert) {
        final text = '${wert ?? ''}';
        return text.startsWith('enc:') ? 0 : text.length;
      }

      for (final mittel in roh) {
        expect(laenge(mittel['wirkung']), lessThan(260));
        for (final q in (mittel['qualitaeten'] as List).cast<Map>()) {
          expect(
            laenge(q['wirkung']),
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

    test('Zustände auf Zeit nennen Namen und Dauer vollständig', () {
      const einheiten = {'spielrunden', 'stunden', 'tage'};
      var gesehen = 0;
      for (final mittel in roh) {
        for (final q in (mittel['qualitaeten'] as List).cast<Map>()) {
          for (final z in ((q['zustaende'] as List?) ?? const []).cast<Map>()) {
            gesehen++;
            final grund = '${mittel['id']} ${q['stufe']}: $z';
            expect('${z['name']}', isNotEmpty, reason: grund);
            if (z['dauer'] == null) {
              // Gewürfelte oder offene Dauer: kein Wert, auch keine Einheit.
              expect(z['einheit'], isNull, reason: grund);
              continue;
            }
            expect(z['dauer'] as int, greaterThan(0), reason: grund);
            expect(einheiten, contains(z['einheit']), reason: grund);
          }
        }
      }
      expect(gesehen, greaterThan(0));
    });

    test('Mittel ohne Stufen tragen höchstens einen LeP-Wurf', () {
      for (final mittel in roh) {
        final wurf = mittel['lepWurf'];
        if (wurf == null) {
          continue;
        }
        expect(
          (mittel['qualitaeten'] as List),
          isEmpty,
          reason: '${mittel['id']}: lepWurf nur ohne Stufen',
        );
        expect(_wurf.hasMatch('$wurf'), isTrue, reason: '${mittel['id']}');
      }
    });

    test(
      'Wandlungselixiere, Zaubertrank, Heilkräuter und Verbände sind da',
      () {
        final nachId = {for (final m in roh) m['id']: m};
        const mutandica = [
          'alch_hauch_der_jugend',
          'alch_ifirnstrunk',
          'alch_levitationselixier',
          'alch_unsichtbarkeitselixier',
          'alch_unverwundbarkeitselixier',
          'alch_rethonikum',
          'alch_purpurwasser',
          'alch_verwandlungselixier',
        ];
        for (final id in mutandica) {
          expect(nachId[id]?['gruppe'], 'Mutandica', reason: id);
          final stufen = (nachId[id]!['qualitaeten'] as List).cast<Map>();
          expect(stufen, hasLength(6), reason: id);
          expect(
            stufen.every((q) => (q['zustaende'] as List).isNotEmpty),
            isTrue,
            reason: id,
          );
        }
        final zaubertrank = (nachId['alch_zaubertrank']!['qualitaeten'] as List)
            .cast<Map>();
        expect(zaubertrank.map((q) => q['aspWurf']), [
          '1W6',
          '2W6',
          '3W6',
          '3W6+6',
          '5W6+6',
          '2W20+5',
        ]);
        expect(nachId['alch_rote_pfeilbluete']!['lepWurf'], '3W6+2');
        expect(nachId['alch_wirselkraut_salbe']!['lepWurf'], '1W6+4');
        for (final id in const [
          'alch_wundverband',
          'alch_wundverband_mastix',
          'alch_finagebast',
        ]) {
          expect(nachId[id]?['art'], 'verband', reason: id);
        }
      },
    );

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
