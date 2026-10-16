import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/talent_nutzung_katalog.dart';

import '../test_support/real_catalog.dart';

/// Prüft die Nutzungstabelle (WdS S. 16 f., 18–40) gegen den echten Katalog.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  test(
    'jedes Nicht-Kampf-Talent des Katalogs hat eine Regel und umgekehrt',
    () {
      final ids = {
        for (final t in katalog.catalog.talents)
          if (t.group != 'Kampftalent') t.id,
      };
      expect(kTalentNutzung.keys.toSet(), ids);
    },
  );

  test(
    'Ersatztalente existieren, sind keine Selbstverweise und doppeln nicht',
    () {
      final ids = {for (final t in katalog.catalog.talents) t.id};
      kTalentNutzung.forEach((id, nutzung) {
        final gesehen = <String>{};
        for (final e in nutzung.ersatz) {
          expect(ids, contains(e.talentId), reason: '$id → ${e.talentId}');
          expect(e.talentId, isNot(id), reason: id);
          // Dasselbe Ersatztalent darf mit verschiedenen Bedingungen mehrfach
          // stehen (etwa Fesseln/Entfesseln); Paar aus ID und Bedingung ist eindeutig.
          expect(
            gesehen.add('${e.talentId}|${e.bedingung}'),
            isTrue,
            reason: '$id → ${e.talentId}',
          );
        }
      });
    },
  );

  test(
    'Richtzuschläge liegen zwischen 5 und 15, fehlende nennt der Meister',
    () {
      kTalentNutzung.forEach((id, nutzung) {
        for (final e in nutzung.ersatz) {
          final z = e.zuschlag;
          if (z == null) {
            expect(e.bedingung, isNotNull, reason: '$id → ${e.talentId}');
          } else {
            expect(z, inInclusiveRange(5, 15), reason: '$id → ${e.talentId}');
          }
        }
      });
    },
  );

  test(
    'die Basis-Talente entsprechen der Liste in Wege des Schwerts S. 17',
    () {
      const basis = <String>{
        'Athletik',
        'Klettern',
        'Körperbeherrschung',
        'Schleichen',
        'Schwimmen',
        'Selbstbeherrschung',
        'Sich Verstecken',
        'Singen',
        'Sinnesschärfe',
        'Tanzen',
        'Zechen',
        'Menschenkenntnis',
        'Überreden',
        'Fährtensuchen',
        'Orientierung',
        'Wildnisleben',
        'Götter / Kulte',
        'Rechnen',
        'Sagen / Legenden',
        'Heilkunde Wunden',
        'Holzbearbeitung',
        'Kochen',
        'Lederarbeiten',
        'Malen / Zeichnen',
        'Schneidern',
      };
      String norm(String s) =>
          s.replaceAll(' ', '').replaceAll('/', '').toLowerCase();
      final erwartet = basis.map(norm).toSet();
      final tatsaechlich = {
        for (final t in katalog.catalog.talents)
          if (kTalentNutzung[t.id]?.basis ?? false) norm(t.name),
      };
      expect(tatsaechlich, erwartet);
    },
  );

  test('Gaben sind weder Basis noch haben sie Ersatz', () {
    for (final t in katalog.catalog.talents.where((t) => t.group == 'Gabe')) {
      final nutzung = kTalentNutzung[t.id]!;
      expect(nutzung.basis, isFalse, reason: t.name);
      expect(nutzung.ersatz, isEmpty, reason: t.name);
    }
  });

  test('Stichproben aus dem Buch', () {
    TalentNutzungDef n(String id) => talentNutzungFuer(id)!;
    expect(n('tal_klettern').ersatz.map((e) => (e.talentId, e.zuschlag)), [
      ('tal_akrobatik', 5),
      ('tal_athletik', 5),
      ('tal_koerperbeherrschung', 10),
    ]);
    expect(n('tal_reiten').basis, isFalse);
    expect(n('tal_reiten').ersatz.first.talentId, 'tal_koerperbeherrschung');
    expect(talentNutzungFuer('tal_gibt_es_nicht'), isNull);
  });
}
