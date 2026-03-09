import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

class _OpenedMagicTab {
  const _OpenedMagicTab({required this.repo, required this.actions});

  final FakeRepository repo;
  final WorkspaceTabEditActions actions;
}

void main() {
  HeroSheet buildHero({
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    List<HeroRitualCategory> ritualCategories = const <HeroRitualCategory>[],
    List<String> representationen = const <String>['Mag', 'Dru', 'Elf'],
  }) {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 1,
      attributes: Attributes(
        mu: 14,
        kl: 12,
        inn: 13,
        ch: 11,
        ff: 10,
        ge: 12,
        ko: 14,
        kk: 13,
      ),
      merkmalskenntnisse: <String>['Kraft'],
      representationen: representationen,
      talents: talents,
      ritualCategories: ritualCategories,
      spells: <String, HeroSpellEntry>{
        'spell_axxeleratus': HeroSpellEntry(
          spellValue: 8,
          learnedRepresentation: 'Mag',
          learnedTradition: 'Mag',
          specializations: <String>['Heldeneintrag'],
        ),
      },
    );
  }

  RulesCatalog buildCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[
        TalentDef(
          id: 'tal_singen',
          name: 'Singen',
          group: 'Koerper',
          steigerung: 'B',
          attributes: <String>['Mut', 'Charisma', 'Charisma'],
        ),
        TalentDef(
          id: 'tal_musizieren',
          name: 'Musizieren',
          group: 'Koerper',
          steigerung: 'B',
          attributes: <String>['Klugheit', 'Charisma', 'Fingerfertigkeit'],
        ),
      ],
      spells: <SpellDef>[
        SpellDef(
          id: 'spell_axxeleratus',
          name: 'Axxeleratus Blitzgeschwind',
          tradition: 'Elf',
          steigerung: 'C',
          attributes: <String>['Klugheit', 'Gewandheit', 'Konstitution'],
          availability: 'Mag3, Elf2, Dru(Elf)2',
          traits: 'Kraft',
          aspCost: '7 AsP',
          targetObject: 'Einzelperson, freiwillig',
          range: '7 Schritt',
          duration: 'ZfP* Spielrunden',
          castingTime: '2 Aktionen',
          wirkung: 'Beschleunigt das Ziel deutlich.',
          modifications: 'Zauberdauer, Reichweite',
          source: 'Liber Cantiones S. 36',
          variants: <String>[
            'Blitzgeschwind (+7). Mehr Tempo.',
            'Koboldisch. Nur Sprache.',
          ],
        ),
        SpellDef(
          id: 'spell_adlerschwinge',
          name: 'Adlerschwinge Wolfsgestalt',
          tradition: 'Elf',
          steigerung: 'D',
          attributes: <String>['Mut', 'Intuition', 'Gewandheit'],
          availability: 'Elf6, Dru(Elf)2',
          traits: 'Form',
        ),
      ],
      weapons: <WeaponDef>[],
    );
  }

  Future<_OpenedMagicTab> openMagicTab(
    WidgetTester tester, {
    FakeRepository? repo,
    RulesCatalog? catalog,
  }) async {
    final effectiveRepo =
        repo ??
        FakeRepository(
          heroes: <HeroSheet>[buildHero()],
          states: <String, HeroState>{
            'demo': const HeroState(
              currentLep: 10,
              currentAsp: 10,
              currentKap: 0,
              currentAu: 10,
            ),
          },
        );
    final effectiveCatalog = catalog ?? buildCatalog();
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(effectiveRepo),
          rulesCatalogProvider.overrideWith((ref) async => effectiveCatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroMagicTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registered) {
                actions = registered;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(actions, isNotNull);
    return _OpenedMagicTab(repo: effectiveRepo, actions: actions!);
  }

  testWidgets('magic tab exposes rituals sub tab', (tester) async {
    await openMagicTab(tester);

    expect(find.text('Rituale'), findsOneWidget);
  });

  testWidgets(
    'detail dialog is read-only outside edit mode and uses catalog variants',
    (tester) async {
      await openMagicTab(tester);

      await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('magic-spell-details-dialog')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Heldeneintrag'), findsNothing);
      expect(find.text('Koboldisch. Nur Sprache.'), findsOneWidget);
      expect(find.text('Liber Cantiones S. 36'), findsOneWidget);
    },
  );

  testWidgets('spell catalog shows all availability entries', (tester) async {
    final opened = await openMagicTab(tester);

    await opened.actions.startEdit();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
    await tester.pumpAndSettle();

    expect(find.text('Mag 3; Elf 2; Dru -> Elf 2'), findsOneWidget);
    expect(find.text('Elf 6; Dru -> Elf 2'), findsOneWidget);
  });

  testWidgets(
    'activating spell with multiple representations stores selected entry',
    (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero(
            representationen: const <String>['Dru', 'Elf'],
          ).copyWith(spells: const <String, HeroSpellEntry>{}),
        ],
        states: <String, HeroState>{
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );
      final opened = await openMagicTab(tester, repo: repo);

      await opened.actions.startEdit();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-catalog-toggle-spell_adlerschwinge',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('magic-spell-representation-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-representation-option-Dru->Elf',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-spell-representation-save')),
      );
      await tester.pumpAndSettle();

      await opened.actions.save();
      await tester.pumpAndSettle();

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_adlerschwinge'];
      expect(entry?.learnedRepresentation, 'Elf');
      expect(entry?.learnedTradition, 'Dru');
    },
  );

  testWidgets(
    'edit mode stores heldenspezifische text overrides on the active spell',
    (tester) async {
      final opened = await openMagicTab(tester);

      await opened.actions.startEdit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-spell-details-wirkung-field')),
        'Eigene korrigierte Wirkung.',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('magic-spell-details-variant-field-0'),
        ),
        'Eigene Variante.',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-spell-details-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Eigene korrigierte Wirkung.'), findsOneWidget);

      await opened.actions.save();
      await tester.pumpAndSettle();

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_axxeleratus'];
      expect(entry, isNotNull);
      expect(entry?.textOverrides?.wirkung, 'Eigene korrigierte Wirkung.');
      expect(entry?.textOverrides?.variants, <String>[
        'Eigene Variante.',
        'Koboldisch. Nur Sprache.',
      ]);
    },
  );

  testWidgets('ritual detail dialog is read-only outside edit mode', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        buildHero(
          ritualCategories: <HeroRitualCategory>[
            HeroRitualCategory(
              id: 'ritual_cat_1',
              name: 'Flueche',
              knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
              ownKnowledge: const HeroRitualKnowledge(
                name: 'Flueche',
                value: 3,
                learningComplexity: 'E',
              ),
              rituals: const <HeroRitualEntry>[
                HeroRitualEntry(
                  name: 'Hexenfluch',
                  wirkung: 'Verhaengt Unheil.',
                  kosten: '7 AsP',
                  wirkungsdauer: '7 Tage',
                  merkmale: 'Einfluss',
                ),
              ],
            ),
          ],
        ),
      ],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    await openMagicTab(tester, repo: repo);

    await tester.tap(find.text('Rituale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hexenfluch'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('magic-ritual-entry-dialog')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Verhaengt Unheil.'), findsOneWidget);
  });

  testWidgets(
    'edit mode creates own knowledge ritual category with default taw and selected complexity',
    (tester) async {
      final opened = await openMagicTab(tester);

      await opened.actions.startEdit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rituale'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-rituals-add-category')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-category-name-field')),
        'Flueche',
      );
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-complexity-field'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('F').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flueche'), findsOneWidget);
      expect(find.textContaining('Kompl. F'), findsOneWidget);

      await opened.actions.save();
      await tester.pumpAndSettle();

      final savedHero = await opened.repo.loadHeroById('demo');
      final category = savedHero?.ritualCategories.single;
      expect(category?.name, 'Flueche');
      expect(category?.ownKnowledge?.value, 3);
      expect(category?.ownKnowledge?.learningComplexity, 'F');
    },
  );

  testWidgets(
    'edit mode creates talent based ritual category and shows taw from linked talents',
    (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero(
            talents: const <String, HeroTalentEntry>{
              'tal_singen': HeroTalentEntry(talentValue: 7),
              'tal_musizieren': HeroTalentEntry(talentValue: 9),
            },
          ),
        ],
        states: <String, HeroState>{
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );
      final opened = await openMagicTab(tester, repo: repo);

      await opened.actions.startEdit();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rituale'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-rituals-add-category')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-category-name-field')),
        'Elfenlieder',
      );
      await tester.tap(find.text('Talent'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-talent-tal_singen'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-talent-tal_musizieren'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Singen: TaW 7'), findsOneWidget);
      expect(find.text('Musizieren: TaW 9'), findsOneWidget);

      await opened.actions.save();
      await tester.pumpAndSettle();

      final savedHero = await opened.repo.loadHeroById('demo');
      expect(savedHero?.ritualCategories.single.derivedTalentIds, <String>[
        'tal_singen',
        'tal_musizieren',
      ]);
    },
  );

  testWidgets(
    'edit mode creates ritual with dynamic text and attribute fields',
    (tester) async {
      final opened = await openMagicTab(tester);

      await opened.actions.startEdit();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rituale'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-rituals-add-category')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-category-name-field')),
        'Flueche',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-add-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-field-label-0'),
        ),
        'Ausloeser',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-add-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-field-label-1'),
        ),
        'Probe',
      );
      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-field-type-1'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-field-type-1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 Eigenschaften').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-save')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-add-ritual-0')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-entry-name-field')),
        'Hexenfluch',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-entry-wirkung-field')),
        'Verhaengt Unheil.',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-entry-kosten-field')),
        '7 AsP',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('magic-ritual-entry-wirkungsdauer-field'),
        ),
        '7 Tage',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-entry-merkmale-field')),
        'Einfluss',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-text-0')),
        'Bei Vollmond',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('MU').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CH').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-2')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('IN').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-save')),
      );
      await tester.pumpAndSettle();

      await opened.actions.save();
      await tester.pumpAndSettle();

      final savedHero = await opened.repo.loadHeroById('demo');
      final ritual = savedHero?.ritualCategories.single.rituals.single;
      expect(ritual?.name, 'Hexenfluch');
      expect(ritual?.wirkung, 'Verhaengt Unheil.');
      expect(ritual?.additionalFieldValues.first.textValue, 'Bei Vollmond');
      expect(ritual?.additionalFieldValues.last.attributeCodes, <String>[
        'MU',
        'CH',
        'IN',
      ]);
    },
  );

  testWidgets(
    'gifted spells stack with house spell and traits for complexity',
    (tester) async {
      final opened = await openMagicTab(tester);

      expect(find.text('B'), findsOneWidget);

      await opened.actions.startEdit();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spells-gifted-spell_axxeleratus'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spells-hauszauber-spell_axxeleratus'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A*'), findsOneWidget);

      await opened.actions.save();
      await tester.pumpAndSettle();

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_axxeleratus'];
      expect(entry?.gifted, isTrue);
      expect(entry?.hauszauber, isTrue);
    },
  );

  testWidgets('detail dialog scales near full screen on compact layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(540, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openMagicTab(tester);

    await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
    await tester.pumpAndSettle();

    final dialogSize = tester.getSize(
      find.byKey(const ValueKey<String>('magic-spell-details-dialog')),
    );
    expect(dialogSize.width, greaterThan(500));
    expect(dialogSize.height, greaterThan(560));
  });

  testWidgets(
    'active spell effects popup opens in magic tab and persists toggles without edit mode',
    (tester) async {
      final opened = await openMagicTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-active-spells-open')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('active-spell-effects-dialog')),
        findsOneWidget,
      );
      expect(find.text('Axxeleratus'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'active-spell-toggle-effect_spell_axxeleratus',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = await opened.repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.activeSpellEffects, isA<ActiveSpellEffectsState>());
      expect(state.activeSpellEffects.activeEffectIds, <String>[
        activeSpellEffectAxxeleratus,
      ]);
    },
  );
}
