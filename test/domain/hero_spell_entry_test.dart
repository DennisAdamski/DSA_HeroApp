import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';

void main() {
  test('hero spell entry roundtrip keeps text overrides', () {
    const entry = HeroSpellEntry(
      spellValue: 7,
      modifier: 2,
      hauszauber: true,
      textOverrides: HeroSpellTextOverrides(
        aspCost: '',
        targetObject: 'Eigene Zielwahl',
        wirkung: 'Eigene Wirkung',
        variants: <String>[],
      ),
    );

    final reloaded = HeroSpellEntry.fromJson(entry.toJson());

    expect(reloaded.spellValue, 7);
    expect(reloaded.modifier, 2);
    expect(reloaded.hauszauber, isTrue);
    expect(reloaded.textOverrides?.aspCost, '');
    expect(reloaded.textOverrides?.targetObject, 'Eigene Zielwahl');
    expect(reloaded.textOverrides?.wirkung, 'Eigene Wirkung');
    expect(reloaded.textOverrides?.variants, <String>[]);
  });

  test('hero spell entry keeps null text overrides as catalog fallback', () {
    const entry = HeroSpellEntry(spellValue: 4);

    final reloaded = HeroSpellEntry.fromJson(entry.toJson());

    expect(reloaded.textOverrides, isNull);
  });
}
