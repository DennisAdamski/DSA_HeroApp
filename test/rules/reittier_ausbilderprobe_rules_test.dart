import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbilderprobe_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui2/shell/karto_test_support.dart';

const abrichten = TalentDef(
  id: 'tal_abrichten',
  name: 'Abrichten',
  group: 'Natur',
  steigerung: 'B',
  attributes: ['Mut', 'Intuition', 'Charisma'],
  be: '-',
);
const tierkunde = TalentDef(
  id: 'tal_tierkunde',
  name: 'Tierkunde',
  group: 'Wissen',
  steigerung: 'B',
  attributes: ['Mut', 'Klugheit', 'Intuition'],
  be: '-',
);

HeroComputedSnapshot _snapshot() => buildHeroComputedSnapshot(
  hero: testHero().copyWith(
    talents: const {'tal_abrichten': HeroTalentEntry(talentValue: 9)},
  ),
  state: const HeroState.empty(),
  catalog: const RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [abrichten, tierkunde],
    spells: [],
    weapons: [],
  ),
  epicAdvantagesActive: false,
);

void main() {
  test('die Erschwernis belegt den Probendialog als Malus vor', () {
    final aufbau = ausbilderprobeFuer(
      snapshot: _snapshot(),
      talente: const [abrichten, tierkunde],
      talentId: 'tal_abrichten',
      talentName: 'Abrichten',
      erschwernis: 5,
      epicAdvantagesActive: false,
    );

    expect(aufbau.hinweis, isNull);
    expect(aufbau.request!.basePool, 9);
    expect(aufbau.request!.initialSituationalModifier, -5);
    expect(aufbau.request!.title, 'Talentprobe: Abrichten');
  });

  test('ohne gefuehrtes Talent oder Katalogeintrag gibt es einen Hinweis', () {
    final ohneTalent = ausbilderprobeFuer(
      snapshot: _snapshot(),
      talente: const [abrichten, tierkunde],
      talentId: 'tal_tierkunde',
      talentName: 'Tierkunde',
      erschwernis: 3,
      epicAdvantagesActive: false,
    );
    final ohneKatalog = ausbilderprobeFuer(
      snapshot: _snapshot(),
      talente: const [],
      talentId: 'tal_reiten',
      talentName: 'Reiten',
      erschwernis: 0,
      epicAdvantagesActive: false,
    );

    expect(ohneTalent.request, isNull);
    expect(ohneTalent.hinweis, contains('führt Tierkunde nicht'));
    expect(ohneKatalog.hinweis, contains('nicht im Katalog'));
  });
}
