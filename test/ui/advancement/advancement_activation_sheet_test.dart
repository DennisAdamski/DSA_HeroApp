import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_activation_sheet.dart';

// Wechselt in einen Arbeitsbereich und dort in einen Abschnitt.
Future<void> zuAbschnitt(
  WidgetTester tester,
  String bereich,
  String abschnitt,
) async {
  await tester.tap(find.byKey(ValueKey('advancement-bereich-$bereich')));
  await tester.pumpAndSettle();
  final chip = find.byKey(ValueKey('advancement-abschnitt-$abschnitt'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

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
        traits: 'Illusion, Umwelt',
      ),
      SpellDef(
        id: 'foreign',
        name: 'Elfenlied',
        tradition: 'Elf',
        steigerung: 'A',
        attributes: ['MU', 'KL', 'IN'],
        availability: 'Elf3',
        traits: 'Heilung',
      ),
      SpellDef(
        id: 'mixed',
        name: 'Zweiklang',
        tradition: 'Mag',
        steigerung: 'A',
        attributes: ['MU', 'KL', 'IN'],
        availability: 'Mag2, Elf6',
        traits: 'Illusion',
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
    double textScale = 1,
    bool standaloneSpellSheet = false,
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
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: standaloneSpellSheet
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showAdvancementActivationSheet(
                        context: context,
                        heroId: hero.id,
                        title: 'Zauber lernen',
                        kinds: const [AdvancementKind.spell],
                      ),
                      child: const Text('Öffnen'),
                    ),
                  )
                : const AdvancementCatalog(heroId: 'sheet-hero'),
          ),
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
    await zuAbschnitt(tester, 'magie', 'zauber');
    expect(
      find.byKey(const ValueKey('advancement-empty-zauber')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-spell-spell')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('advancement-activate-zauber')));
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

  testWidgets('Erwerbsblätter trennen Talente, Kampftalente und Sprachen', (
    tester,
  ) async {
    await openCatalog(tester);
    await zuAbschnitt(tester, 'talente', 'talente');
    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-talente')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-climb')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-sword')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-language-lang')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('advancement-activate-close')));
    await tester.pumpAndSettle();

    await zuAbschnitt(tester, 'talente', 'sprachen');
    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-sprachen')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-language-lang')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-talent-climb')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('advancement-activate-close')));
    await tester.pumpAndSettle();

    await zuAbschnitt(tester, 'kampf', 'kampftalente');
    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-kampftalente')),
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

  testWidgets(
    'Repräsentationsfilter schaltet zwischen eigenen und allen Zaubern',
    (tester) async {
      await openCatalog(
        tester,
        selectedHero: hero.copyWith(representationen: ['Mag']),
      );
      await zuAbschnitt(tester, 'magie', 'zauber');
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-zauber')),
      );
      await tester.pumpAndSettle();
      final own = find.byKey(const ValueKey('advancement-plan-spell-spell'));
      final foreign = find.byKey(
        const ValueKey('advancement-plan-spell-foreign'),
      );
      expect(own, findsOneWidget);
      expect(foreign, findsNothing);

      final toggle = find.byKey(
        const ValueKey('advancement-activate-only-available'),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(own, findsOneWidget);
      expect(foreign, findsOneWidget);
      expect(tester.widget<OutlinedButton>(foreign).onPressed, isNotNull);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(foreign, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Zauberfilter kombinieren Merkmal, Verbreitung und Repräsentation',
    (tester) async {
      await openCatalog(
        tester,
        selectedHero: hero.copyWith(representationen: ['Mag']),
      );
      await zuAbschnitt(tester, 'magie', 'zauber');
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-zauber')),
      );
      await tester.pumpAndSettle();
      final traitFilter = find.byKey(
        const ValueKey('advancement-activate-spell-trait'),
      );
      final spreadFilter = find.byKey(
        const ValueKey('advancement-activate-spell-spread'),
      );
      await tester.tap(traitFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Illusion').last);
      await tester.pumpAndSettle();
      await tester.tap(spreadFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ab 6').last);
      await tester.pumpAndSettle();
      final own = find.byKey(const ValueKey('advancement-plan-spell-spell'));
      final mixed = find.byKey(const ValueKey('advancement-plan-spell-mixed'));
      expect(own, findsOneWidget);
      expect(mixed, findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-only-available')),
      );
      await tester.pumpAndSettle();
      expect(mixed, findsOneWidget);
      expect(
        find.byKey(const ValueKey('advancement-plan-spell-foreign')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('advancement-activate-search')),
        'Zweiklang',
      );
      await tester.pumpAndSettle();
      expect(own, findsNothing);
      expect(mixed, findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('advancement-activate-search')),
        '',
      );
      await tester.tap(traitFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alle Merkmale').last);
      await tester.pumpAndSettle();
      await tester.tap(spreadFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alle Verbreitungen').last);
      await tester.pumpAndSettle();
      expect(own, findsOneWidget);
      expect(mixed, findsOneWidget);
      expect(
        find.byKey(const ValueKey('advancement-plan-spell-foreign')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Repräsentationsfilter blendet Zauber ohne Repräsentation aus', (
    tester,
  ) async {
    // Ohne jede Repräsentation ist kein Zauber erlernbar; eine fremde
    // Repräsentation genügt sonst immer und wäre kein Sperrfall. Der
    // Magiebereich erscheint dann nur mit „Unpassende anzeigen“.
    await openCatalog(
      tester,
      selectedHero: hero.copyWith(showInapplicableSpecialAbilities: true),
    );
    await zuAbschnitt(tester, 'magie', 'zauber');
    await tester.tap(find.byKey(const ValueKey('advancement-activate-zauber')));
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

  testWidgets('Skilltree zeigt erworbene und alle folgenden Kettenstufen', (
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
    await zuAbschnitt(tester, 'talente', 'allgemeineSf');
    await tester.tap(
      find.byKey(const ValueKey('advancement-group-header-allgemeinPraxis')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('skill-node-generalAbility:will1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-generalAbility-will1')),
      findsNothing,
    );
    final next = find.byKey(const ValueKey('skill-node-generalAbility:will2'));
    expect(next, findsOneWidget);
    expect(
      find.byKey(const ValueKey('skill-node-generalAbility:will3')),
      findsOneWidget,
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
    await zuAbschnitt(tester, 'talente', 'talente');
    await tester.enterText(
      find.byKey(const ValueKey('advancement-search')),
      'Schwimmen',
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine passenden Einträge.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-hint-talente')),
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

  testWidgets('Zauberfilter bleiben mit doppelter Schrift bedienbar', (
    tester,
  ) async {
    await openCatalog(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      standaloneSpellSheet: true,
      selectedHero: hero.copyWith(representationen: ['Mag']),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final spread = find.byKey(
      const ValueKey('advancement-activate-spell-spread'),
    );
    await Scrollable.ensureVisible(tester.element(spread), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(spread);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ab 6').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('advancement-activate-close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-activate-search')),
      findsNothing,
    );
  });

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    testWidgets('Zauberfilter bleiben auf ${size.width.toInt()} px bedienbar', (
      tester,
    ) async {
      await openCatalog(
        tester,
        size: size,
        selectedHero: hero.copyWith(representationen: ['Mag']),
      );
      await zuAbschnitt(tester, 'magie', 'zauber');
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-zauber')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final spread = find.byKey(
        const ValueKey('advancement-activate-spell-spread'),
      );
      await tester.ensureVisible(spread);
      await tester.tap(spread);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ab 6').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('advancement-plan-spell-mixed')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('advancement-plan-spell-spell')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Erwerbsblatt bleibt auf ${size.width.toInt()} px bedienbar', (
      tester,
    ) async {
      await openCatalog(tester, size: size);
      await zuAbschnitt(tester, 'talente', 'talente');
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-talente')),
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
