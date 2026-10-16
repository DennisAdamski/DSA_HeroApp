import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';

void main() {
  const hero = HeroSheet(
    id: 'group-hero',
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
    apTotal: 2000,
    apAvailable: 2000,
  );

  const gruppenKatalog = RulesCatalog(
    version: 'test',
    source: 'test',
    weapons: [],
    spells: [],
    talents: [
      TalentDef(
        id: 'climb',
        name: 'Klettern',
        group: 'Körperliche Talente',
        steigerung: 'B',
        attributes: ['MU', 'GE', 'KK'],
      ),
      TalentDef(
        id: 'law',
        name: 'Rechtskunde',
        group: 'Wissenstalente',
        steigerung: 'B',
        attributes: ['KL', 'KL', 'IN'],
      ),
      TalentDef(
        id: 'cook',
        name: 'Kochen',
        group: 'Handwerkliche Talente',
        steigerung: 'B',
        attributes: ['KL', 'IN', 'FF'],
      ),
    ],
  );
  final gruppenHeld = hero.copyWith(
    talents: {
      'climb': const HeroTalentEntry(talentValue: 7),
      'law': const HeroTalentEntry(talentValue: 3),
      'cook': const HeroTalentEntry(talentValue: 3),
    },
  );

  Future<ProviderContainer> openTalents(
    WidgetTester tester, {
    Size size = const Size(1024, 900),
    HeroSheet? selectedHero,
    RulesCatalog selectedCatalog = gruppenKatalog,
  }) async {
    final held = selectedHero ?? gruppenHeld;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(heroes: [held]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(advancementSessionProvider(hero.id).notifier)
        .start(hero: held, catalog: selectedCatalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AdvancementCatalog(heroId: 'group-hero')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Talente'));
    await tester.pumpAndSettle();
    return container;
  }

  Finder kopf(String gruppe) =>
      find.byKey(ValueKey('advancement-group-header-$gruppe'));
  Finder sprung(String gruppe) =>
      find.byKey(ValueKey('advancement-group-jump-$gruppe'));
  Finder namensfeld() =>
      find.byKey(const ValueKey('advancement-specialization-name'));

  testWidgets('Talente stehen in Gruppen mit Sprungleiste', (tester) async {
    await openTalents(tester);
    for (final name in ['koerper', 'wissen', 'handwerk']) {
      expect(kopf(name), findsOneWidget);
      expect(sprung(name), findsOneWidget);
    }
    // Gruppen ohne Einträge erscheinen weder als Kopf noch in der Leiste.
    expect(kopf('natur'), findsNothing);
    expect(sprung('natur'), findsNothing);
    expect(
      find.byKey(const ValueKey('advancement-group-stripe-climb')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gruppenkopf klappt die Gruppe ein, die Leiste wieder auf', (
    tester,
  ) async {
    await openTalents(tester);
    await tester.tap(kopf('wissen'));
    await tester.pumpAndSettle();
    expect(find.text('Rechtskunde'), findsNothing);
    expect(find.text('Klettern'), findsOneWidget);
    await tester.tap(sprung('wissen'));
    await tester.pumpAndSettle();
    expect(find.text('Rechtskunde'), findsOneWidget);
  });

  testWidgets('Sprungleiste scrollt zur gewählten Gruppe', (tester) async {
    // Genug Körper-Talente, dass Handwerk zunächst unterhalb des Sichtbereichs liegt.
    final koerper = [for (var i = 0; i < 8; i++) 'koerper$i'];
    await openTalents(
      tester,
      size: const Size(420, 640),
      selectedHero: hero.copyWith(
        talents: {
          for (final id in koerper) id: const HeroTalentEntry(talentValue: 3),
          'cook': const HeroTalentEntry(talentValue: 3),
        },
      ),
      selectedCatalog: RulesCatalog(
        version: 'test',
        source: 'test',
        weapons: const [],
        spells: const [],
        talents: [
          for (final id in koerper)
            TalentDef(
              id: id,
              name: 'Körper $id',
              group: 'Körperliche Talente',
              steigerung: 'B',
              attributes: const ['MU', 'GE', 'KK'],
            ),
          const TalentDef(
            id: 'cook',
            name: 'Kochen',
            group: 'Handwerkliche Talente',
            steigerung: 'B',
            attributes: ['KL', 'IN', 'FF'],
          ),
        ],
      ),
    );
    final vorher = tester.getTopLeft(kopf('handwerk'));
    await tester.ensureVisible(sprung('handwerk'));
    await tester.pumpAndSettle();
    await tester.tap(sprung('handwerk'));
    await tester.pumpAndSettle();
    final nachher = tester.getTopLeft(kopf('handwerk'));
    expect(nachher.dy, lessThan(vorher.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dialog bietet Empfehlungen aus dem Regelwerk an', (
    tester,
  ) async {
    final container = await openTalents(tester);
    await tester.tap(
      find.byKey(const ValueKey('advancement-specialize-climb')),
    );
    await tester.pumpAndSettle();
    for (final name in [
      'Bergsteigen',
      'Eisklettern',
      'Freiklettern',
      'Seilklettern',
    ]) {
      expect(
        find.byKey(ValueKey('advancement-specialization-option-$name')),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.byKey(
        const ValueKey('advancement-specialization-option-Eisklettern'),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(namensfeld()).controller?.text,
      'Eisklettern',
    );
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = container.read(advancementSessionProvider(hero.id))!;
    expect(session.entries.single.options['specialization'], 'Eisklettern');
  });

  testWidgets('bereits gelernte Empfehlungen lassen sich nicht erneut wählen', (
    tester,
  ) async {
    await openTalents(
      tester,
      selectedHero: gruppenHeld.copyWith(
        talents: {
          ...gruppenHeld.talents,
          'climb': const HeroTalentEntry(
            talentValue: 14,
            combatSpecializations: ['Freiklettern'],
          ),
        },
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('advancement-specialize-climb')),
    );
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.byKey(
        const ValueKey('advancement-specialization-option-Freiklettern'),
      ),
    );
    expect(chip.onSelected, isNull);
    final frei = tester.widget<ChoiceChip>(
      find.byKey(
        const ValueKey('advancement-specialization-option-Bergsteigen'),
      ),
    );
    expect(frei.onSelected, isNotNull);
  });

  testWidgets('Talent ohne Spezialisierungen im Regelwerk erklärt das', (
    tester,
  ) async {
    await openTalents(
      tester,
      selectedHero: hero.copyWith(
        talents: {'ski': const HeroTalentEntry(talentValue: 7)},
      ),
      selectedCatalog: const RulesCatalog(
        version: 'test',
        source: 'test',
        weapons: [],
        spells: [],
        talents: [
          TalentDef(
            id: 'ski',
            name: 'Skifahren',
            group: 'Körperliche Talente',
            steigerung: 'B',
            attributes: ['GE', 'GE', 'KO'],
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('advancement-specialize-ski')));
    await tester.pumpAndSettle();
    expect(find.textContaining('keine'), findsWidgets);
    expect(find.textContaining('Absprache mit dem Meister'), findsOneWidget);
    expect(namensfeld(), findsOneWidget);
  });

  testWidgets('Kulturtalente schlagen Kulturen beim Tippen vor', (
    tester,
  ) async {
    await openTalents(
      tester,
      selectedHero: hero.copyWith(
        talents: {'saga': const HeroTalentEntry(talentValue: 7)},
      ),
      selectedCatalog: const RulesCatalog(
        version: 'test',
        source: 'test',
        weapons: [],
        spells: [],
        talents: [
          TalentDef(
            id: 'saga',
            name: 'Sagen / Legenden',
            group: 'Wissenstalente',
            steigerung: 'B',
            attributes: ['KL', 'IN', 'CH'],
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('advancement-specialize-saga')));
    await tester.pumpAndSettle();
    await tester.enterText(namensfeld(), 'Thor');
    await tester.pumpAndSettle();
    expect(find.text('Thorwal'), findsOneWidget);
    await tester.tap(find.text('Thorwal'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(namensfeld()).controller?.text, 'Thorwal');
  });
}
