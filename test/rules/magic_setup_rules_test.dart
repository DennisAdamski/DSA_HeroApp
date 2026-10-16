import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_setup_rules.dart';

void main() {
  const hero = HeroSheet(
    id: 'h',
    name: 'Magier',
    level: 1,
    attributes: Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    apSpent: 100,
  );

  test('enthaltene Kenntnisse kosten keine AP und werden nicht dupliziert', () {
    const choice = MagicSetupChoice(
      traditionId: 'gildenmagier',
      includeRepresentation: true,
      includeRitualKnowledge: true,
      startValue: 7,
    );
    final first = applyMagicSetup(hero, choice);
    final second = applyMagicSetup(first, choice);
    expect(second.representationen, ['Mag']);
    expect(second.ritualKnowledge['gildenmagier']!.value, 7);
    expect(second.apSpent, 100);
  });

  test('zwei Gruppen verwenden nach ausdrücklicher Auswahl denselben RkW', () {
    final legacy = hero.copyWith(
      ritualCategories: const [
        HeroRitualCategory(
          id: 'staff',
          name: 'Stabzauber',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          ownKnowledge: HeroRitualKnowledge(name: 'Stabzauber', value: 8),
        ),
        HeroRitualCategory(
          id: 'orb',
          name: 'Kugelzauber',
          knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
          ownKnowledge: HeroRitualKnowledge(name: 'Kugelzauber', value: 5),
        ),
      ],
    );
    final result = applyMagicSetup(
      legacy,
      const MagicSetupChoice(
        traditionId: 'gildenmagier',
        includeRepresentation: false,
        includeRitualKnowledge: true,
        sourceCategoryId: 'staff',
        categoryIds: ['staff', 'orb'],
      ),
    );
    expect(result.ritualKnowledge['gildenmagier']!.value, 8);
    expect(result.ritualCategories.map((c) => c.id), ['staff', 'orb']);
    expect(
      result.ritualCategories.every(
        (c) => c.knowledgeMode == HeroRitualKnowledgeMode.traditionKnowledge,
      ),
      isTrue,
    );
    expect(
      result.ritualCategories.last.ownKnowledge!.value,
      5,
      reason: 'Altwert bleibt als Archiv erhalten und wird nicht ausgewertet',
    );
  });

  test(
    'bestehende gemeinsame Kenntnis bleibt bei erneuter Einrichtung erhalten',
    () {
      final known = hero.copyWith(
        ritualKnowledge: const {
          'gildenmagier': HeroRitualKnowledge(name: 'Gildenmagie', value: 11),
        },
      );
      final result = applyMagicSetup(
        known,
        const MagicSetupChoice(
          traditionId: 'gildenmagier',
          includeRepresentation: true,
          includeRitualKnowledge: true,
        ),
      );
      expect(result.ritualKnowledge['gildenmagier']!.value, 11);
    },
  );

  test('Elfen erhalten keine erfundene Ritualkenntnis', () {
    expect(
      () => applyMagicSetup(
        hero,
        const MagicSetupChoice(
          traditionId: 'elf',
          includeRepresentation: true,
          includeRitualKnowledge: true,
        ),
      ),
      throwsStateError,
    );
  });

  test('fehlende Zuordnungsquelle verwirft keine Bestandswerte', () {
    expect(
      () => applyMagicSetup(
        hero,
        const MagicSetupChoice(
          traditionId: 'gildenmagier',
          includeRepresentation: false,
          includeRitualKnowledge: true,
          sourceCategoryId: 'missing',
        ),
      ),
      throwsStateError,
    );
  });
}
