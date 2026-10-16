import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_stapel_rules.dart';

// Artefakte sind Einzelstücke: sie lassen sich weder teilen noch mit einem
// gleichnamigen Gegenstand zusammenführen.

const _matrix = HeroInventoryEntry(
  gegenstand: 'Armschiene',
  anzahl: '2',
  menge: 2,
  isMagisch: true,
  instanzId: 'a',
  artefaktDaten: ArtefaktDaten(),
);

void main() {
  test('ein Artefakt lässt sich nicht teilen', () {
    expect(stapelTeilbar(_matrix), isFalse);
    expect(stapelTeilbar(_matrix.copyWith(artefaktDaten: null)), isTrue);
  });

  test('ein Artefakt lässt sich nicht zusammenführen', () {
    final gleich = _matrix.copyWith(instanzId: 'b');

    expect(
      zusammenfuehrenGesperrt(_matrix, gleich),
      'Artefakte sind Einzelstücke.',
    );
    expect(
      zusammenfuehrenGesperrt(
        _matrix.copyWith(artefaktDaten: null),
        gleich.copyWith(artefaktDaten: null),
      ),
      isNull,
    );
  });
}
