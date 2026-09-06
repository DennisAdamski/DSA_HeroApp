import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';

void main() {
  const hero = HeroSheet(
    id: 'catalog-hero',
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
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    spells: [],
    weapons: [],
  );

  Future<({ProviderContainer container, FakeRepository repo})> openCatalog(
    WidgetTester tester, {
    Size size = const Size(1024, 900),
    HeroSheet selectedHero = hero,
    RulesCatalog selectedCatalog = catalog,
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
        .start(hero: selectedHero, catalog: selectedCatalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AdvancementCatalog(heroId: 'catalog-hero')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, repo: repo);
  }

  testWidgets('Vormerken ändert nur die Vorschau und zeigt Geplant', (
    tester,
  ) async {
    final setup = await openCatalog(tester);
    expect(find.text('Basiswerte'), findsOneWidget);
    expect(find.text('Vor der Runde → Geplant'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('advancement-plan-attribute-mu')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aktuelle Planung → Mit dieser Erhöhung'), findsOneWidget);
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();

    final session = setup.container.read(advancementSessionProvider(hero.id))!;
    expect(session.entries, hasLength(1));
    expect(session.preview.attributes.mu, 13);
    expect(session.preview.apAvailable, lessThan(hero.apAvailable));
    expect((await setup.repo.loadHeroById(hero.id))!.attributes.mu, 12);
    expect(find.text('Geplant'), findsOneWidget);
    expect(find.text('Au 20 → 21 (+1)'), findsOneWidget);
    setup.container
        .read(advancementSessionProvider(hero.id).notifier)
        .remove(session.entries.single.id);
    await tester.pumpAndSettle();
    expect(find.text('Au 20 → 20'), findsOneWidget);
    expect(find.text('Geplant'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Zielwert aktualisiert Grenzen live; Abbrechen behält die Runde',
    (tester) async {
      const talentCatalog = RulesCatalog(
        version: 'test',
        source: 'test',
        weapons: [],
        spells: [],
        talents: [
          TalentDef(
            id: 'climb',
            name: 'Klettern',
            group: 'Körper',
            steigerung: 'B',
            attributes: ['MU', 'GE', 'KK'],
          ),
        ],
      );
      final setup = await openCatalog(
        tester,
        selectedHero: hero.copyWith(
          talents: {'climb': const HeroTalentEntry(talentValue: 15)},
        ),
        selectedCatalog: talentCatalog,
      );
      await tester.tap(
        find.byKey(const ValueKey('advancement-plan-attribute-mu')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Talent: Klettern · Wert 15 · Maximum 15 → 16'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Wert steigern'));
      await tester.pumpAndSettle();
      expect(
        find.text('Talent: Klettern · Wert 15 · Maximum 15 → 17'),
        findsOneWidget,
      );
      expect(find.text('AT-Basis 7 → 8 (+1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Wert senken'));
      await tester.tap(find.byTooltip('Wert senken'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('advancement-unlocked-talent-climb')),
        findsNothing,
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      final session = setup.container.read(
        advancementSessionProvider(hero.id),
      )!;
      expect(session.entries, isEmpty);
      expect(session.preview.apAvailable, hero.apAvailable);
      expect((await setup.repo.loadHeroById(hero.id))!.attributes.mu, 12);
      expect(find.text('AT-Basis 7 → 7'), findsOneWidget);
    },
  );

  testWidgets('Basiswerte folgen Ressourcenfreischaltung', (tester) async {
    await openCatalog(tester);
    expect(find.byKey(const ValueKey('advancement-impact-AsP')), findsNothing);
    expect(find.byKey(const ValueKey('advancement-impact-KaP')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await openCatalog(
      tester,
      selectedHero: hero.copyWith(
        resourceActivationConfig: const HeroResourceActivationConfig(
          magicEnabledOverride: true,
          divineEnabledOverride: true,
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('advancement-impact-AsP')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-impact-KaP')),
      findsOneWidget,
    );
  });

  testWidgets('Kleine Displays scrollen Basiswerte und Dialog vollständig', (
    tester,
  ) async {
    await openCatalog(tester, size: const Size(320, 568));
    final plan = find.byKey(const ValueKey('advancement-plan-attribute-mu'));
    final listScroll = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(plan, 150, scrollable: listScroll);
    await tester.tap(plan);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Durch diese Erhöhung weiter steigerbar'),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    final last = find.byKey(const ValueKey('advancement-plan-boughtStat-mr'));
    await tester.scrollUntilVisible(last, 300, scrollable: listScroll);
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kategorien und Suche bleiben auf schmalen Geräten erreichbar', (
    tester,
  ) async {
    await openCatalog(tester, size: const Size(390, 844));
    await tester.enterText(
      find.byKey(const ValueKey('advancement-search')),
      'Mut',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('advancement-plan-attribute-mu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('advancement-plan-attribute-kl')),
      findsNothing,
    );

    await tester.tap(find.text('Zauber'));
    await tester.pumpAndSettle();
    expect(find.text('Keine passenden Einträge.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Zauberaktivierung verlangt die Repräsentation und bleibt geplant',
    (tester) async {
      const spellCatalog = RulesCatalog(
        version: 'test',
        source: 'test',
        talents: [],
        weapons: [],
        spells: [
          SpellDef(
            id: 'spell',
            name: 'Flim Flam',
            tradition: 'Mag',
            steigerung: 'A',
            attributes: ['MU', 'KL', 'IN'],
            availability: 'Mag6, Elf3',
          ),
        ],
      );
      final setup = await openCatalog(
        tester,
        selectedHero: hero.copyWith(representationen: ['Mag']),
        selectedCatalog: spellCatalog,
      );
      await tester.tap(find.text('Zauber'));
      await tester.pumpAndSettle();
      // Ein noch nicht gefuehrter Zauber ist nur ueber das Erwerbsblatt
      // erreichbar; die Hauptliste zeigt ausschliesslich aktive Eintraege.
      expect(
        find.byKey(const ValueKey('advancement-plan-spell-spell')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-spells')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('advancement-plan-spell-spell')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Zauber-Repräsentation wählen'), findsOneWidget);
      expect(find.text('Vormerken'), findsNothing);
      await tester.tap(find.text('Mag 6'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vormerken'));
      await tester.pumpAndSettle();
      final session = setup.container.read(
        advancementSessionProvider(hero.id),
      )!;
      expect(session.entries.single.options['learnedRepresentation'], 'Mag');
      expect(session.preview.spells['spell']!.learnedRepresentation, 'Mag');
      expect((await setup.repo.loadHeroById(hero.id))!.spells, isEmpty);
      // Der aktivierte Zauber steht nun in der Hauptliste und ist steigerbar.
      expect(
        find.byKey(const ValueKey('advancement-plan-spell-spell')),
        findsOneWidget,
      );
      expect(find.text('Steigern'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Offene Voraussetzungen benötigen einen dokumentierten Meisterentscheid',
    (tester) async {
      const abilityCatalog = RulesCatalog(
        version: 'test',
        source: 'test',
        talents: [],
        weapons: [],
        spells: [],
        generalSpecialAbilities: [
          SpecialAbilityDef(
            id: 'ability',
            name: 'Stufe II',
            kosten: '100 AP',
            voraussetzungenStruktur: [
              SpecialAbilityRequirement(
                art: RequirementArt.sonderfertigkeit,
                name: 'Stufe I',
              ),
            ],
          ),
        ],
      );
      final setup = await openCatalog(tester, selectedCatalog: abilityCatalog);
      await tester.tap(find.text('Sonderfertigkeiten'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('advancement-activate-abilities')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('advancement-plan-generalAbility-ability')),
      );
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Vormerken');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('erwerb-meisterentscheid')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vormerken'));
      await tester.pumpAndSettle();
      final session = setup.container.read(
        advancementSessionProvider(hero.id),
      )!;
      expect(session.entries.single.options['meisterentscheid'], 'true');
      expect(session.entries.single.apCost, 100);
      expect(
        (await setup.repo.loadHeroById(hero.id))!.talentSpecialAbilities,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Varianten verwenden den gewählten Preis und Namen', (
    tester,
  ) async {
    const variantCatalog = RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [],
      weapons: [],
      spells: [],
      generalSpecialAbilities: [
        SpecialAbilityDef(
          id: 'terrain',
          name: 'Geländekunde',
          kosten: '150 AP',
          mehrfachwaehlbar: true,
          variantenFreitext: false,
          variantenGruppen: [
            SpecialAbilityVariantGroup(
              label: 'Wüste',
              ap: 75,
              varianten: ['Wüste'],
            ),
          ],
        ),
      ],
    );
    final setup = await openCatalog(tester, selectedCatalog: variantCatalog);
    await tester.tap(find.text('Sonderfertigkeiten'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advancement-activate-abilities')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('advancement-plan-generalAbility-terrain')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sf-variant-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wüste').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = setup.container.read(advancementSessionProvider(hero.id))!;
    expect(session.entries.single.options['variant'], 'Wüste');
    expect(session.entries.single.apCost, 75);
    expect(
      session.preview.talentSpecialAbilities.single.name,
      'Geländekunde (Wüste)',
    );
    // Mehrfach waehlbare SF bleiben in der Hauptliste handlungsfaehig.
    expect(
      find.byKey(const ValueKey('advancement-plan-generalAbility-terrain')),
      findsOneWidget,
    );
    expect(find.text('Weitere Auswahl'), findsOneWidget);
    expect(find.text('1× erworben'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
