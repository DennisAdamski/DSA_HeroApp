import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';

void main() {
  const hero = HeroSheet(
    id: 'sheet-hero',
    name: 'Rondra',
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
    apTotal: 5000,
    apAvailable: 5000,
  );

  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    weapons: [],
    talents: [
      TalentDef(
        id: 'climb',
        name: 'Klettern',
        group: 'Körper',
        steigerung: 'B',
        attributes: ['MU', 'GE', 'KK'],
      ),
      TalentDef(
        id: 'swim',
        name: 'Schwimmen',
        group: 'Körper',
        steigerung: 'B',
        attributes: ['MU', 'GE', 'KK'],
      ),
      TalentDef(
        id: 'sword',
        name: 'Schwerter',
        group: 'Kampftalent',
        type: 'nahkampf',
        steigerung: 'E',
        attributes: [],
      ),
    ],
    spells: [
      SpellDef(
        id: 'spell',
        name: 'Flim Flam',
        tradition: 'Mag',
        steigerung: 'A',
        attributes: ['MU', 'KL', 'IN'],
        availability: 'Mag6',
      ),
      SpellDef(
        id: 'foreign',
        name: 'Elfenlied',
        tradition: 'Elf',
        steigerung: 'A',
        attributes: ['MU', 'KL', 'IN'],
        availability: 'Elf3',
      ),
    ],
    sprachen: [
      SpracheDef(id: 'lang', name: 'Garethi', familie: 'Garethi', maxWert: 18),
    ],
    generalSpecialAbilities: [
      SpecialAbilityDef(
        id: 'will1',
        name: 'Eiserner Wille I',
        kosten: '100 AP',
        kette: SpecialAbilityChainRef(
          id: 'wille',
          stufe: 1,
          label: 'Eiserner Wille',
        ),
      ),
      SpecialAbilityDef(
        id: 'will2',
        name: 'Eiserner Wille II',
        kosten: '200 AP',
        kette: SpecialAbilityChainRef(
          id: 'wille',
          stufe: 2,
          label: 'Eiserner Wille',
        ),
      ),
      SpecialAbilityDef(
        id: 'will3',
        name: 'Eiserner Wille III',
        kosten: '300 AP',
        kette: SpecialAbilityChainRef(
          id: 'wille',
          stufe: 3,
          label: 'Eiserner Wille',
        ),
      ),
    ],
  );

  Future<({ProviderContainer container, FakeRepository repo})> openCatalog(
    WidgetTester tester, {
    Size size = const Size(1024, 900),
    HeroSheet selectedHero = hero,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = FakeRepository(heroes: [selectedHero]);
    final container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container
        .read(advancementSessionProvider(hero.id).notifier)
        .start(hero: selectedHero, catalog: catalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AdvancementCatalog(heroId: 'sheet-hero')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, repo: repo);
  }

  testWidgets('Nicht geführte Zauber erscheinen nur im Erwerbsblatt', (
    tester,
  ) async {
    await openCatalog(
      tester,
      selectedHero: hero.copyWith(representationen: ['Mag']),
    );
    await tester.tap(find.text('Zauber'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-empty-spells')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-spell-spell')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('advancement-activate-spells')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-spell-spell')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('advancement-activate-search')),
      'Elfen',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-spell-spell')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('advancement-activate-close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-activate-search')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Erwerbsblatt trennt Talente, Kampftalente und Sprachen', (
    tester,
  ) async {
    await openCatalog(tester);
    await tester.tap(find.text('Talente'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-talents')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-climb')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-language-lang')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-filter-sprachen')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-climb')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-language-lang')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-filter-kampftalente')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-sword')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-climb')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nur erwerbbare blendet gesperrte Zauber aus', (tester) async {
    // Ohne jede Repräsentation ist kein Zauber erlernbar; eine fremde
    // Repräsentation genügt sonst immer und wäre kein Sperrfall.
    await openCatalog(tester);
    await tester.tap(find.text('Zauber'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advancement-activate-spells')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-activate-empty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-only-available')),
    );
    await tester.pumpAndSettle();
    final blocked = find.byKey(const ValueKey('advancement-plan-spell-spell'));
    expect(blocked, findsOneWidget);
    expect(tester.widget<OutlinedButton>(blocked).onPressed, isNull);
    expect(find.text('Keine passende Repräsentation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hauptliste zeigt Erworbene und die nächste Kettenstufe', (
    tester,
  ) async {
    await openCatalog(
      tester,
      selectedHero: hero.copyWith(
        talentSpecialAbilities: [
          const TalentSpecialAbility(name: 'Eiserner Wille I'),
        ],
      ),
    );
    await tester.tap(find.text('Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-owned-generalAbility-will1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-generalAbility-will1')),
      findsNothing,
    );
    final next = find.byKey(
      const ValueKey('advancement-plan-generalAbility-will2'),
    );
    expect(next, findsOneWidget);
    expect(tester.widget<OutlinedButton>(next).onPressed, isNotNull);
    expect(
      find.byKey(const ValueKey('advancement-plan-generalAbility-will3')),
      findsNothing,
    );
    // Der Sperrgrund erworbener Eintraege darf nicht wie ein Fehler wirken.
    expect(find.text('Bereits erworben'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Suchbrücke öffnet das Erwerbsblatt mit dem Suchtext', (
    tester,
  ) async {
    await openCatalog(
      tester,
      selectedHero: hero.copyWith(
        talents: {'climb': const HeroTalentEntry(talentValue: 5)},
      ),
    );
    await tester.tap(find.text('Talente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('advancement-search')),
      'Schwimmen',
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine passenden Einträge.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-hint-talents')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('advancement-activate-search')),
          )
          .controller!
          .text,
      'Schwimmen',
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-swim')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    testWidgets('Erwerbsblatt bleibt auf ${size.width.toInt()} px bedienbar', (
      tester,
    ) async {
      await openCatalog(tester, size: size);
      await tester.tap(find.text('Talente'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-talents')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('advancement-activate-search')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('advancement-activate-search')),
        'Klettern',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('advancement-plan-talent-climb')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
