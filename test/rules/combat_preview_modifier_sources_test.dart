import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

// Regression zu Befund ARCH-07-B7: Die Kampfvorschau rechnete AT, PA und RS
// mit einer eigenen, kleineren Modifikatorsumme als die Basiswerte.
void main() {
  const attribute = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );
  const leererZustand = HeroState(
    currentLep: 20,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 20,
  );

  ({DerivedStats basis, CombatPreviewStats kampf}) rechne(
    HeroSheet held, {
    StatModifiers inventar = const StatModifiers(),
    StatModifiers wunden = const StatModifiers(),
  }) {
    final parsed = parseModifierTextsForHero(held, catalog: null);
    final basis = computeDerivedStatsFromInputs(
      sheet: held,
      state: leererZustand,
      parsedModifiers: parsed,
      effectiveAttributes: held.attributes,
      inventoryStatMods: inventar,
      wundStatMods: wunden,
    );
    final kampf = computeCombatPreviewStats(
      held,
      leererZustand,
      parsedModifiers: parsed,
      effectiveAttributes: held.attributes,
      derivedStats: basis,
    );
    return (basis: basis, kampf: kampf);
  }

  const held = HeroSheet(
    id: 'h',
    name: 'Test',
    level: 1,
    attributes: attribute,
  );

  test('Basiswerte tragen ihre Modifikatorsumme mit', () {
    final ergebnis = rechne(
      held.copyWith(persistentMods: const StatModifiers(at: 1)),
      inventar: const StatModifiers(at: 2),
      wunden: const StatModifiers(at: -4),
    );

    expect(ergebnis.basis.modifiers.at, 1 + 2 - 4);
  });

  test('Wund-, Inventar- und benannte Modifikatoren wirken auf AT, PA und '
      'RS der Kampfvorschau', () {
    final ohne = rechne(held);
    final mit = rechne(
      held.copyWith(
        statModifiers: <String, List<HeroTalentModifier>>{
          'at': <HeroTalentModifier>[
            HeroTalentModifier(modifier: 1, description: 'Segen'),
          ],
          'rs': <HeroTalentModifier>[
            HeroTalentModifier(modifier: 1, description: 'Amulett'),
          ],
        },
      ),
      inventar: const StatModifiers(pa: 2, rs: 1),
      wunden: const StatModifiers(at: -2, pa: -2),
    );

    expect(mit.kampf.at - ohne.kampf.at, 1 - 2);
    expect(mit.kampf.pa - ohne.kampf.pa, 2 - 2);
    expect(mit.kampf.rsTotal - ohne.kampf.rsTotal, 1 + 1);
    expect(mit.basis.atBase - ohne.basis.atBase, mit.kampf.at - ohne.kampf.at);
  });
}
