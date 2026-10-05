import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_instanz_rules.dart';

void main() {
  test('Altdaten ohne ID schreiben kein Feld, mit ID Roundtrip', () {
    final alt = const HeroInventoryEntry(gegenstand: 'Seil').toJson();
    expect(alt.containsKey('instanzId'), isFalse);
    expect(alt.containsKey('menge'), isFalse);
    final neu = const HeroInventoryEntry(
      gegenstand: 'Pfeile',
      instanzId: 'a',
      menge: 10,
    );
    final geladen = HeroInventoryEntry.fromJson(neu.toJson());
    expect(geladen.instanzId, 'a');
    expect(geladen.menge, 10);
    expect(geladen.copyWith(menge: null).menge, isNull);
  });

  test(
    'gleichnamige Einträge bekommen verschiedene IDs, vorhandene bleiben',
    () {
      var n = 0;
      final liste = [
        const HeroInventoryEntry(gegenstand: 'Dolch', instanzId: 'x'),
        const HeroInventoryEntry(gegenstand: 'Dolch'),
        const HeroInventoryEntry(gegenstand: 'Dolch', instanzId: 'x'),
      ];
      final ergebnis = vergibInstanzIds(liste, neueId: () => 'id${n++}');
      expect(ergebnis.map((e) => e.instanzId), ['x', 'id0', 'id1']);
    },
  );

  test('ohne Änderung kommt dieselbe Liste zurück', () {
    final liste = [const HeroInventoryEntry(instanzId: 'a')];
    expect(
      identical(vergibInstanzIds(liste, neueId: () => 'z'), liste),
      isTrue,
    );
  });
}
