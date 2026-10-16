import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/hexalogie_katalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';

import '../test_support/real_catalog.dart';

/// Gleicht die Hexalogie-Tabelle (WdZ S. 384 ff.) mit dem echten Katalog ab.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  test(
    'alle Mitglieder stehen im Katalog und gehören zu genau einer Hexalogie',
    () {
      final ids = {for (final s in katalog.catalog.spells) s.id};
      final gesehen = <String>{};
      for (final hexalogie in kHexalogien) {
        expect(hexalogie.zauberIds.length, greaterThanOrEqualTo(2));
        for (final id in hexalogie.zauberIds) {
          expect(ids, contains(id), reason: '${hexalogie.name}: $id');
          expect(gesehen.add(id), isTrue, reason: 'doppelt: $id');
        }
      }
    },
  );

  test('jedes Mitglied trägt genau ein Element, keines kommt doppelt vor', () {
    final spells = {for (final s in katalog.catalog.spells) s.id: s};
    for (final hexalogie in kHexalogien) {
      final elemente = <Magieelement>{};
      for (final id in hexalogie.zauberIds) {
        final element = einzigesElement(parseSpellTraits(spells[id]!.traits));
        expect(element, isNotNull, reason: id);
        expect(
          elemente.add(element!),
          isTrue,
          reason: '${hexalogie.name}: $id',
        );
      }
    }
  });

  test('hexalogieFuerZauber findet Mitglieder und nur diese', () {
    expect(
      hexalogieFuerZauber('spell_ignifaxius')?.name,
      'Elementare Geschosse',
    );
    expect(hexalogieFuerZauber('spell_armatrutz'), isNull);
  });

  test('Merkmale werden zu Elementen aufgelöst', () {
    expect(elementAusMerkmal('Elementar (Erz)'), Magieelement.erz);
    expect(elementAusMerkmal(' elementar (eis) '), Magieelement.eis);
    expect(elementAusMerkmal('Elementar (allgemein)'), isNull);
    expect(elementAusMerkmal('Schaden'), isNull);
    expect(einzigesElement(['Elementar (Luft)', 'Elementar (Wasser)']), isNull);
  });
}
