import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_magic_knowledge_rules.dart';
import 'package:dsa_heldenverwaltung/ui_shared/magic_knowledge_advancement_dialog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/waffenmeister_editor_screen.dart';

const _hero = HeroSheet(
  id: 'bereiche-ui',
  name: 'Held',
  level: 1,
  attributes: Attributes(
    mu: 14,
    kl: 14,
    inn: 14,
    ch: 12,
    ff: 13,
    ge: 16,
    ko: 14,
    kk: 16,
  ),
  apTotal: 5000,
  apAvailable: 5000,
);

const _catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  spells: [],
  weapons: [],
  talents: [
    TalentDef(
      id: 'tal_schwerter',
      name: 'Schwerter',
      group: 'Kampftalent',
      type: 'nahkampf',
      steigerung: 'E',
      attributes: [],
      weaponCategory: 'Langschwert, Säbel',
    ),
  ],
  advantages: [
    HeroTraitDef(
      id: 'adv_eisern',
      name: 'Eisern',
      traitType: 'advantage',
      costText: '7 GP',
      selectionTemplate: 'Eisern',
    ),
  ],
  disadvantages: [
    HeroTraitDef(
      id: 'dis_goldgier',
      name: 'Goldgier',
      traitType: 'disadvantage',
      costText: 'je -1 GP pro Punkt',
      valueKind: 'points',
      minValue: 1,
      unit: 'Punkt',
      selectionTemplate: 'Goldgier {value}',
      markers: ['SE'],
    ),
  ],
  karmalSpecialAbilities: [
    SpecialAbilityDef(
      id: 'epfad_praios',
      name: 'Pfad der Erleuchteten – Praios',
      gruppe: 'karmal',
      kosten: '200 AP',
      voraussetzungenStruktur: [
        SpecialAbilityRequirement(
          art: RequirementArt.gottheit,
          namen: ['Praios'],
        ),
      ],
    ),
    SpecialAbilityDef(
      id: 'epfad_rondra',
      name: 'Pfad der Erleuchteten – Rondra',
      gruppe: 'karmal',
      kosten: '200 AP',
      voraussetzungenStruktur: [
        SpecialAbilityRequirement(
          art: RequirementArt.gottheit,
          namen: ['Rondra'],
        ),
      ],
    ),
  ],
);

// Wechselt in einen Arbeitsbereich und dort in einen Abschnitt.
Future<void> zuAbschnitt(
  WidgetTester tester,
  String bereich,
  String abschnitt,
) async {
  await tester.tap(find.byKey(ValueKey('advancement-bereich-$bereich')));
  await tester.pumpAndSettle();
  final chip = find.byKey(ValueKey('advancement-abschnitt-$abschnitt'));
  if (chip.evaluate().isEmpty) return;
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  Future<({ProviderContainer container, FakeRepository repo})> open(
    WidgetTester tester, {
    HeroSheet hero = _hero,
    Size size = const Size(1200, 1000),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = FakeRepository(heroes: [hero]);
    final container = ProviderContainer(
      overrides: [heroRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container
        .read(advancementSessionProvider(hero.id).notifier)
        .start(hero: hero, catalog: _catalog);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: AdvancementCatalog(heroId: 'bereiche-ui')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container: container, repo: repo);
  }

  AdvancementSession sitzung(ProviderContainer container) =>
      container.read(advancementSessionProvider(_hero.id))!;

  testWidgets('Grundlagen planen einen nachträglichen Vorteil', (tester) async {
    // Eisern setzt beim Nachkauf KO 15 voraus (Hausregel, Abschnitt 4).
    final setup = await open(
      tester,
      hero: _hero.copyWith(attributes: _hero.attributes.copyWith(ko: 15)),
    );
    await zuAbschnitt(tester, 'grundlagen', 'vorteile');
    await tester.tap(
      find.byKey(const ValueKey('advancement-plan-advantage-adv_eisern')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = sitzung(setup.container);
    expect(session.entries.single.apCost, 350);
    expect(session.preview.vorteileText, 'Eisern');
    expect((await setup.repo.loadHeroById(_hero.id))!.vorteileText, isEmpty);
    expect(find.text('Geplant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Grundlagen senken eine Schlechte Eigenschaft', (tester) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(
        nachteilEintraege: const [
          HeroMerkmal(katalogId: 'dis_goldgier', text: 'Goldgier 6', wert: 6),
        ],
        nachteileText: 'Goldgier 6',
      ),
    );
    await zuAbschnitt(tester, 'grundlagen', 'nachteile');
    await tester.tap(
      find.byKey(const ValueKey('advancement-plan-disadvantage-Goldgier 6')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kosten: 50 AP'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('advancement-nachteil-weiter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = sitzung(setup.container);
    expect(session.entries.single.apCost, 50);
    expect(session.preview.nachteileText, 'Goldgier 5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Magie hat getrennte Kenntnisse mit Headeraktionen', (
    tester,
  ) async {
    await open(tester, hero: _hero.copyWith(representationen: const ['Mag']));
    await zuAbschnitt(tester, 'magie', 'repraesentationen');
    expect(find.text('+ Repräsentation'), findsOneWidget);
    expect(find.text('Repräsentationen'), findsOneWidget);
    await zuAbschnitt(tester, 'magie', 'ritualkenntnisse');
    expect(find.text('+ Ritualkenntnis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Kostenfreie Kenntniserfassung liefert nur einen Planungsbefehl',
    (tester) async {
      final setup = await open(
        tester,
        hero: _hero.copyWith(representationen: const ['Mag']),
      );
      final session = sitzung(setup.container);
      final option = resolveMagicKnowledge(
        AdvancementContext(hero: session.preview, catalog: session.catalog),
        AdvancementKind.representation,
        'Elf',
        const {'traditionId': 'elf'},
      )!;
      final future = showMagicKnowledgeAdvancementDialog(
        context: tester.element(find.byType(AdvancementCatalog)),
        session: session,
        option: option,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neu erlernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bei Erschaffung enthalten').last);
      await tester.pumpAndSettle();
      expect(find.text('Kosten: 0 AP'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Vormerken'),
      );
      expect(confirm.onPressed, isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vollzauberer').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Vormerken'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Vormerken'));
      await tester.pumpAndSettle();
      final entry = await future;
      expect(entry!.options['source'], 'creation');
      expect(entry.apCost, 0);
      expect(sitzung(setup.container).entries, isEmpty);
      expect((await setup.repo.loadHeroById(_hero.id))!.representationen, [
        'Mag',
      ]);
      setup.container
          .read(advancementSessionProvider(_hero.id).notifier)
          .add(entry);
      await tester.pumpAndSettle();
      expect(sitzung(setup.container).preview.representationen, ['Mag', 'Elf']);
      expect((await setup.repo.loadHeroById(_hero.id))!.representationen, [
        'Mag',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Abbruch der Ritualkenntniserfassung lässt die Sitzung unverändert',
    (tester) async {
      final setup = await open(
        tester,
        hero: _hero.copyWith(representationen: const ['Mag']),
      );
      final session = sitzung(setup.container);
      final option = resolveMagicKnowledge(
        AdvancementContext(hero: session.preview, catalog: session.catalog),
        AdvancementKind.ritualKnowledge,
        'gildenmagier',
        const {},
      )!;
      final future = showMagicKnowledgeAdvancementDialog(
        context: tester.element(find.byType(AdvancementCatalog)),
        session: session,
        option: option,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lehrmeister vorhanden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(await future, isNull);
      expect(sitzung(setup.container).entries, isEmpty);
      expect(sitzung(setup.container).preview.ritualKnowledge, isEmpty);
      expect(
        (await setup.repo.loadHeroById(_hero.id))!.ritualKnowledge,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Kenntnisdialog bleibt schmal mit großer Schrift bedienbar', (
    tester,
  ) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(representationen: const ['Mag']),
      size: const Size(390, 844),
      textScale: 2,
    );
    final session = sitzung(setup.container);
    final option = resolveMagicKnowledge(
      AdvancementContext(hero: session.preview, catalog: session.catalog),
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      const {},
    )!;
    final future = showMagicKnowledgeAdvancementDialog(
      context: tester.element(find.byType(AdvancementCatalog)),
      session: session,
      option: option,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('Geoden wählen die Tradition vor der kostenfreien Erfassung', (
    tester,
  ) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(representationen: const ['Mag']),
    );
    final session = sitzung(setup.container);
    final option = resolveMagicKnowledge(
      AdvancementContext(hero: session.preview, catalog: session.catalog),
      AdvancementKind.representation,
      'Geo',
      const {'source': 'creation'},
    )!;
    final future = showMagicKnowledgeAdvancementDialog(
      context: tester.element(find.byType(AdvancementCatalog)),
      session: session,
      option: option,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('magic-knowledge-tradition')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geode (Diener Sumus)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vollzauberer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final entry = (await future)!;
    expect(entry.options['traditionId'], 'geode_diener_sumus');
    setup.container
        .read(advancementSessionProvider(_hero.id).notifier)
        .add(entry);
    expect(
      sitzung(setup.container).preview.repraesentationsTraditionen['Geo'],
      'geode_diener_sumus',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bezahlter Einrichtungsweg sperrt kostenfreie Quellen', (
    tester,
  ) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(representationen: const ['Mag']),
    );
    final session = sitzung(setup.container);
    final option = resolveMagicKnowledge(
      AdvancementContext(hero: session.preview, catalog: session.catalog),
      AdvancementKind.ritualKnowledge,
      'gildenmagier',
      const {'source': 'acquisition'},
    )!;
    final future = showMagicKnowledgeAdvancementDialog(
      context: tester.element(find.byType(AdvancementCatalog)),
      session: session,
      option: option,
      lockSource: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Bei Erschaffung enthalten'), findsNothing);
    expect(find.text('Erwerbsgrund: Neu erlernen'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('Einrichtungsweg behält die außen gewählte Geodentradition', (
    tester,
  ) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(representationen: const ['Mag']),
    );
    final session = sitzung(setup.container);
    final option = resolveMagicKnowledge(
      AdvancementContext(hero: session.preview, catalog: session.catalog),
      AdvancementKind.representation,
      'Geo',
      const {'source': 'creation', 'traditionId': 'geode_herr_der_erde'},
    )!;
    final future = showMagicKnowledgeAdvancementDialog(
      context: tester.element(find.byType(AdvancementCatalog)),
      session: session,
      option: option,
      lockTradition: true,
    );
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('magic-knowledge-tradition')),
    );
    expect(dropdown.onChanged, isNull);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('Magie bietet Merkmalskenntnisse an', (tester) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(representationen: const ['Mag']),
    );
    await zuAbschnitt(tester, 'magie', 'merkmalskenntnisse');
    final heilung = find.byKey(
      const ValueKey('advancement-plan-merkmal-Heilung'),
    );
    await tester.ensureVisible(heilung);
    await tester.tap(heilung);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = sitzung(setup.container);
    expect(session.entries.single.apCost, 100);
    expect(session.preview.merkmalskenntnisse, ['Heilung']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kampftalente planen den Waffenmeister im Editor', (
    tester,
  ) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(
        talents: const {
          'tal_schwerter': HeroTalentEntry(
            talentValue: 18,
            combatSpecializations: ['Langschwert'],
          ),
        },
      ),
    );
    await zuAbschnitt(tester, 'kampf', 'kampftalente');
    await tester.tap(
      find.byKey(const ValueKey('advancement-waffenmeister-tal_schwerter')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WaffenmeisterEditorScreen), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Waffenart'),
      'Langschwert',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    // 2.500 AP in Kampf-SF fehlen: Vormerken nur mit Meisterentscheid.
    await tester.tap(find.byKey(const ValueKey('erwerb-meisterentscheid')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vormerken'));
    await tester.pumpAndSettle();
    final session = sitzung(setup.container);
    expect(session.entries.single.apCost, 400);
    expect(
      session.preview.combatConfig.waffenmeisterschaften.single.weaponType,
      'Langschwert',
    );
    expect(find.text('Waffenmeister: Langschwert'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Karma filtert Pfade nach der gewählten Gottheit', (
    tester,
  ) async {
    final setup = await open(
      tester,
      hero: _hero.copyWith(
        resourceActivationConfig: const HeroResourceActivationConfig(
          divineEnabledOverride: true,
        ),
      ),
    );
    await zuAbschnitt(tester, 'karma', 'karmaSf');
    final kopf = find.byKey(
      const ValueKey('advancement-group-header-karmaGrundlagen'),
    );
    await tester.tap(kopf);
    await tester.pumpAndSettle();
    final praios = find.byKey(
      const ValueKey('skill-node-karmalAbility:epfad_praios'),
    );
    final rondra = find.byKey(
      const ValueKey('skill-node-karmalAbility:epfad_rondra'),
    );
    expect(praios, findsOneWidget);
    expect(rondra, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('advancement-gottheit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Praios').last);
    await tester.pumpAndSettle();
    expect((await setup.repo.loadHeroById(_hero.id))!.gottheit, 'Praios');
    expect(praios, findsOneWidget);
    expect(rondra, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
