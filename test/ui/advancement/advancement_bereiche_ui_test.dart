import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
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
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
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
        child: const MaterialApp(
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
    final setup = await open(tester);
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
