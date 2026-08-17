import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_text_overrides.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

class _OpenedMagicTab {
  const _OpenedMagicTab({required this.repo, required this.actions});

  final FakeRepository repo;
  final WorkspaceTabEditActions actions;
}

bool _isKnownMagicTableOverflow(Object exception) {
  final text = exception.toString();
  return text.contains('A RenderFlex overflowed by 21 pixels');
}

Future<void> _pumpAndSettleIgnoringKnownOverflow(WidgetTester tester) async {
  await tester.pumpAndSettle();
  Object? exception;
  do {
    exception = tester.takeException();
    if (exception != null && !_isKnownMagicTableOverflow(exception)) {
      throw exception;
    }
  } while (exception != null);
}

void main() {
  HeroSheet buildHero({
    Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
    List<HeroRitualCategory> ritualCategories = const <HeroRitualCategory>[],
    List<String> representationen = const <String>['Mag', 'Dru', 'Elf'],
    List<MagicSpecialAbility> magicSpecialAbilities =
        const <MagicSpecialAbility>[],
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
      magicSpecialAbilities: magicSpecialAbilities,
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

  RulesCatalog buildCatalog({
    String axxeleratusWirkung = 'Beschleunigt das Ziel deutlich.',
    List<String> axxeleratusVariants = const <String>[
      'Blitzgeschwind (+7). Mehr Tempo.',
      'Koboldisch. Nur Sprache.',
    ],
    String? axxeleratusRawVariantsEncrypted,
    List<SpecialAbilityDef> magicSpecialAbilities = const <SpecialAbilityDef>[],
  }) {
    return RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: const <TalentDef>[
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
          wirkung: axxeleratusWirkung,
          modifications: 'Zauberdauer, Reichweite',
          source: 'Liber Cantiones S. 36',
          variants: axxeleratusVariants,
          rawVariantsEncrypted: axxeleratusRawVariantsEncrypted,
        ),
        const SpellDef(
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
      magicSpecialAbilities: magicSpecialAbilities,
    );
  }

  Future<_OpenedMagicTab> openMagicTab(
    WidgetTester tester, {
    FakeRepository? repo,
    RulesCatalog? catalog,
    AppSettings appSettings = const AppSettings(),
    Size size = const Size(1600, 1200),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(appSettings),
          ),
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
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    expect(actions, isNotNull);
    return _OpenedMagicTab(repo: effectiveRepo, actions: actions!);
  }

  testWidgets('magic tab exposes rituals sub tab', (tester) async {
    await openMagicTab(tester);

    expect(find.text('Rituale'), findsOneWidget);
  });

  testWidgets(
    'zauberbereich ist keine ExpansionTile und zeigt beschrifteten Add-Button',
    (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero().copyWith(spells: const <String, HeroSpellEntry>{}),
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

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('+ Zauber'), findsOneWidget);
      expect(find.text('Kategorie'), findsNothing);
      expect(
        find.text('Aktiviere hier Zauber für diesen Helden.'),
        findsOneWidget,
      );
      expect(find.text('Keine Zauber aktiviert.'), findsOneWidget);
    },
  );

  testWidgets(
    'magische Sonderfertigkeiten nutzen feste Sektion und speichern Beschreibung',
    (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero(
            magicSpecialAbilities: const <MagicSpecialAbility>[
              MagicSpecialAbility(
                name: 'Kraftlinienmagie',
                beschreibung: 'Stufe II',
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
      final opened = await openMagicTab(tester, repo: repo);

      await tester.tap(find.text('Repr. & SF'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Kraftlinienmagie'), findsOneWidget);
      expect(find.text('Stufe II'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('magic-sf-add')));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Sonderfertigkeit hinzufügen'), findsOneWidget);
      expect(find.text('Beschreibung'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Matrixverständnis',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Beschreibung'),
        'Erleichtert Analyse magischer Strukturen.',
      );
      await tester.tap(find.text('Speichern'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      // Neuanlage fragt jetzt die AP-Kosten via Erwerb-Dialog ab.
      await tester.enterText(
        find.widgetWithText(TextField, 'AP-Kosten'),
        '0',
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('Erwerben'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final savedHero = await opened.repo.loadHeroById('demo');
      expect(savedHero?.magicSpecialAbilities, hasLength(2));
      expect(savedHero?.magicSpecialAbilities.last.name, 'Matrixverständnis');
      expect(
        savedHero?.magicSpecialAbilities.last.beschreibung,
        'Erleichtert Analyse magischer Strukturen.',
      );
    },
  );

  testWidgets(
    'special ability catalog picker adds magische SF and increases apSpent',
    (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[buildHero().copyWith(apAvailable: 500)],
        states: <String, HeroState>{
          'demo': const HeroState(
            currentLep: 10,
            currentAsp: 10,
            currentKap: 0,
            currentAu: 10,
          ),
        },
      );
      final catalog = buildCatalog(
        magicSpecialAbilities: const <SpecialAbilityDef>[
          SpecialAbilityDef(
            id: 'magsf_konzentrationsstaerke',
            name: 'Konzentrationsstärke',
            gruppe: 'magisch',
            kategorie: 'Zauberkontrolle',
            beschreibung: 'Erleichtert Proben zur Konzentration.',
            kosten: '100 AP',
          ),
        ],
      );
      final opened = await openMagicTab(tester, repo: repo, catalog: catalog);

      await tester.tap(find.text('Repr. & SF'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-sf-add-from-catalog')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Magische Sonderfertigkeiten'), findsOneWidget);
      expect(find.text('Konzentrationsstärke'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Katalog: 100 AP'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Erwerben'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(find.text('Fertig'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final savedHero = await opened.repo.loadHeroById('demo');
      expect(savedHero?.magicSpecialAbilities.map((a) => a.name), [
        'Konzentrationsstärke',
      ]);
      expect(savedHero?.apSpent, 100);
    },
  );

  testWidgets('Merkmalskenntnis-Chip verrechnet die Klassifikationskosten', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: <HeroSheet>[buildHero().copyWith(apAvailable: 1000)],
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
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.text('Repr. & SF'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    // Limbus ist Klassifikation III -> 300 AP.
    await tester.tap(find.widgetWithText(FilterChip, 'Limbus'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    expect(find.text('Merkmalskenntnis Limbus erwerben'), findsOneWidget);
    expect(find.textContaining('Klassifikation 3: 300 AP'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Erwerben'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await opened.actions.save();
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    final savedHero = await opened.repo.loadHeroById('demo');
    expect(savedHero?.merkmalskenntnisse, contains('Limbus'));
    expect(savedHero?.apSpent, 300);
  });

  testWidgets('abgebrochener Merkmalskenntnis-Erwerb laesst den Chip aus', (
    tester,
  ) async {
    final opened = await openMagicTab(tester);

    await opened.actions.startEdit();
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.text('Repr. & SF'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Limbus'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await opened.actions.save();
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    final savedHero = await opened.repo.loadHeroById('demo');
    expect(savedHero?.merkmalskenntnisse, isNot(contains('Limbus')));
    expect(savedHero?.apSpent, 0);
  });

  testWidgets('Repraesentations-Chip schlaegt den Vollzauberer-Preis vor', (
    tester,
  ) async {
    // Held hat bereits drei Repraesentationen -> die vierte hat keinen
    // Regelpreis mehr, also faellt der Vorschlag auf 0 und der Hinweis warnt.
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        buildHero(representationen: const <String>['Mag']),
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
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.text('Repr. & SF'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('magic-representation-Dru')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    expect(find.text('Repräsentation Druide (Dru) erwerben'), findsOneWidget);
    expect(
      find.textContaining('2. Repräsentation: Vollzauberer 2000 AP'),
      findsOneWidget,
    );
    expect(find.textContaining('Halbzauberer 3000 AP'), findsOneWidget);
  });

  testWidgets('Zauberspezialisierung verlangt den noetigen ZfW', (
    tester,
  ) async {
    // Der Fixture-Zauber hat ZfW 8 und bereits eine Spezialisierung; fuer die
    // zweite waeren ZfW 14 noetig.
    final opened = await openMagicTab(tester);

    await opened.actions.startEdit();
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('spell-specialization-add')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-specialization-add')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    expect(
      find.text('Für eine weitere Spezialisierung wird ZfW 14 benötigt.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('spell-specialization-name')),
        findsNothing);
  });

  testWidgets('Zauberspezialisierung wird gespeichert und kostet AP', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        buildHero().copyWith(
          apAvailable: 1000,
          spells: const <String, HeroSpellEntry>{
            'spell_axxeleratus': HeroSpellEntry(
              spellValue: 8,
              learnedRepresentation: 'Mag',
              learnedTradition: 'Mag',
            ),
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
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('spell-specialization-add')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-specialization-add')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-specialization-name')),
      'Reichweite',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    // Zauber der Kategorie C, erste Spezialisierung: 20 * 3 * 1 = 60 AP.
    expect(find.text('Spezialisierung: Reichweite erwerben'), findsOneWidget);
    expect(find.textContaining('ZfW ≥ 7 nötig'), findsOneWidget);
    expect(find.widgetWithText(TextField, '60'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Erwerben'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await opened.actions.save();
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    final savedHero = await opened.repo.loadHeroById('demo');
    expect(
      savedHero?.spells['spell_axxeleratus']?.specializations,
      <String>['Reichweite'],
    );
    // Ohne Lehrmeister verdoppeln sich die Kosten (Wege des Schwerts S. 17),
    // genau wie bei der Talentspezialisierung: 60 AP -> 120 AP.
    expect(savedHero?.apSpent, 120);
  });

  testWidgets('magic tab stores global lead attribute', (tester) async {
    final opened = await openMagicTab(tester);

    await opened.actions.startEdit();
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.text('Repr. & SF'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('magic-lead-attribute-field')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.text('KL').last);
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    await opened.actions.save();
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    final savedHero = await opened.repo.loadHeroById('demo');
    expect(savedHero?.magicLeadAttribute, 'KL');
  });

  testWidgets(
    'detail dialog is read-only outside edit mode and uses catalog variants',
    (tester) async {
      await openMagicTab(tester);

      await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(
        find.byKey(const ValueKey<String>('magic-spell-details-dialog')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      // Die Spezialisierung des Helden steht in der Tabellenspalte "Spez.",
      // nicht im Detaildialog.
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('magic-spell-details-dialog'),
          ),
          matching: find.text('Heldeneintrag'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('magic-spell-details-traits')),
          matching: find.text('Kraft'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('magic-spell-details-magic-resistance'),
          ),
          matching: find.text('Nein, Ziel gilt als freiwillig'),
        ),
        findsOneWidget,
      );
      expect(find.text('Koboldisch. Nur Sprache.'), findsOneWidget);
      expect(find.text('Liber Cantiones S. 36'), findsOneWidget);
    },
  );

  testWidgets(
    'active spell table defers encrypted content until details dialog',
    (tester) async {
      const password = 'katalog-passwort';
      final catalog = buildCatalog(
        axxeleratusWirkung: encryptCatalogValue('Geheime Wirkung.', password),
        axxeleratusVariants: const <String>[],
        axxeleratusRawVariantsEncrypted: encryptCatalogList(const <String>[
          'Geheime Variante.',
        ], password),
      );

      await openMagicTab(
        tester,
        catalog: catalog,
        appSettings: const AppSettings(catalogContentPassword: password),
      );

      expect(find.text('Geheime Wirkung.'), findsNothing);
      expect(find.text('Geheime Variante.'), findsNothing);
      expect(find.text('Details öffnen'), findsWidgets);

      await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Geheime Wirkung.'), findsOneWidget);
      expect(find.text('Geheime Variante.'), findsOneWidget);
    },
  );

  testWidgets('active spell table keeps heldenspezifische overrides visible', (
    tester,
  ) async {
    const password = 'katalog-passwort';
    final catalog = buildCatalog(
      axxeleratusWirkung: encryptCatalogValue('Geheime Wirkung.', password),
      axxeleratusVariants: const <String>[],
      axxeleratusRawVariantsEncrypted: encryptCatalogList(const <String>[
        'Geheime Variante.',
      ], password),
    );
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        buildHero().copyWith(
          spells: const <String, HeroSpellEntry>{
            'spell_axxeleratus': HeroSpellEntry(
              spellValue: 8,
              learnedRepresentation: 'Mag',
              learnedTradition: 'Mag',
              textOverrides: HeroSpellTextOverrides(
                wirkung: 'Eigene Wirkung.',
                variants: <String>['Eigene Variante.'],
              ),
            ),
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

    await openMagicTab(
      tester,
      repo: repo,
      catalog: catalog,
      appSettings: const AppSettings(catalogContentPassword: password),
    );

    expect(find.text('Eigene Wirkung.'), findsOneWidget);
    expect(find.text('1x Eigene Variante.'), findsOneWidget);
    expect(find.text('Geheime Wirkung.'), findsNothing);
    expect(find.text('Geheime Variante.'), findsNothing);
  });

  testWidgets('active spell row opens shared probe dialog via dice icon', (
    tester,
  ) async {
    await openMagicTab(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('magic-spells-roll-spell_axxeleratus')),
    );
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    expect(
      find.text('Zauberprobe: Axxeleratus Blitzgeschwind'),
      findsOneWidget,
    );
  });

  testWidgets('spell catalog shows all availability entries', (tester) async {
    final opened = await openMagicTab(tester);

    await opened.actions.startEdit();
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-catalog-toggle-spell_adlerschwinge',
          ),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(
        find.byKey(const ValueKey<String>('magic-spell-representation-dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Dru->Elf'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-spell-representation-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_adlerschwinge'];
      expect(entry?.learnedRepresentation, 'Elf');
      expect(entry?.learnedTradition, 'Dru');
    },
  );

  testWidgets(
    'representation dialog shows Merkmale and reduced Lernkomplexität',
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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-catalog-toggle-spell_axxeleratus',
          ),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(
        find.byKey(const ValueKey<String>('magic-spell-representation-dialog')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('magic-spell-representation-merkmale'),
          ),
          matching: find.text('Kraft'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-representation-lernkomplexitaet',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Lernkomplexität: B'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Basis C'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'activating spell with no matching representation lists foreign options',
    (tester) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero(
            representationen: const <String>['Mag'],
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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spell-catalog-filter-all'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-catalog-toggle-spell_adlerschwinge',
          ),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-dialog'),
        ),
        findsOneWidget,
      );
      // Beide Herkunftstraditionen (Elf und Dru) werden synthetisch
      // angeboten, mit der Mag-Repr. des Helden als Träger.
      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Elf->Mag'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Dru->Mag'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Elf->Mag'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-spell-representation-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_adlerschwinge'];
      expect(entry?.learnedRepresentation, 'Mag');
      expect(entry?.learnedTradition, 'Elf');
    },
  );

  testWidgets(
    'regular spell with foreign options also opens dialog',
    (tester) async {
      // Held mit nur Mag-Repr. Zauber 'spell_axxeleratus' hat Verfügbarkeit
      // 'Mag3, Elf2, Dru(Elf)2': Mag3 ist regulär, der Rest fremd.
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero(
            representationen: const <String>['Mag'],
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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.byKey(const ValueKey<String>('magic-spells-add')));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'magic-spell-catalog-toggle-spell_axxeleratus',
          ),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      // Dialog erscheint auch dann, wenn nur ein regulärer Eintrag passt,
      // weil zusätzlich fremde Optionen wählbar sind.
      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-dialog'),
        ),
        findsOneWidget,
      );
      // Regulärer Eintrag Mag3 wird angezeigt.
      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Mag->Mag'),
        ),
        findsOneWidget,
      );
      // Synthetische fremde Einträge für Elf- und Dru-Herkunft.
      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Elf->Mag'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Dru->Mag'),
        ),
        findsOneWidget,
      );

      // Held entscheidet sich für fremde Herkunft Elf.
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spell-representation-option-Elf->Mag'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-spell-representation-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_axxeleratus'];
      expect(entry?.learnedRepresentation, 'Mag');
      expect(entry?.learnedTradition, 'Elf');
    },
  );

  testWidgets(
    'edit mode stores heldenspezifische text overrides on the active spell',
    (tester) async {
      final opened = await openMagicTab(tester);

      await opened.actions.startEdit();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Eigene korrigierte Wirkung.'), findsOneWidget);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
    await _pumpAndSettleIgnoringKnownOverflow(tester);
    await tester.tap(find.text('Hexenfluch'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

    expect(
      find.byKey(const ValueKey<String>('magic-ritual-entry-dialog')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Verhaengt Unheil.'), findsOneWidget);
  });

  testWidgets(
    'ritualkategorien lassen sich auch außerhalb des Edit-Modus hinzufügen',
    (tester) async {
      final opened = await openMagicTab(tester);

      await tester.tap(find.text('Rituale'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      expect(
        find.widgetWithText(FilledButton, '+ Ritualkategorie'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-rituals-add-category')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('F').last);
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Flueche'), findsOneWidget);
      expect(find.textContaining('Kompl. F'), findsOneWidget);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('Rituale'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-rituals-add-category')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-category-name-field')),
        'Elfenlieder',
      );
      await tester.tap(find.text('Talent'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-talent-tal_singen'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-talent-tal_musizieren'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('Singen: TaW 7'), findsOneWidget);
      expect(find.text('Musizieren: TaW 9'), findsOneWidget);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('Rituale'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-rituals-add-category')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('magic-ritual-category-name-field')),
        'Flueche',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-add-field')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('magic-ritual-category-field-label-0'),
        ),
        'Ausloeser',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-add-field')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('3 Eigenschaften').last);
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-category-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-add-ritual-0')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('MU').last);
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-1')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('CH').last);
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-2')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-extra-attr-1-2')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(find.text('IN').last);
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('magic-ritual-entry-save')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spells-gifted-spell_axxeleratus'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('magic-spells-hauszauber-spell_axxeleratus'),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(find.text('A*'), findsOneWidget);

      await opened.actions.save();
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final savedHero = await opened.repo.loadHeroById('demo');
      final entry = savedHero?.spells['spell_axxeleratus'];
      expect(entry?.gifted, isTrue);
      expect(entry?.hauszauber, isTrue);
    },
  );

  testWidgets('detail dialog scales near full screen on compact layouts', (
    tester,
  ) async {
    await openMagicTab(tester, size: const Size(540, 640));

    await tester.tap(find.text('Axxeleratus Blitzgeschwind'));
    await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);

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
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      final state = await opened.repo.loadHeroState('demo');
      expect(state, isNotNull);
      expect(state!.activeSpellEffects, isA<ActiveSpellEffectsState>());
      expect(state.activeSpellEffects.activeEffectIds, <String>[
        activeSpellEffectAxxeleratus,
      ]);
    },
  );

  group('Stufenketten und Voraussetzungen', () {
    // Zwei Stufen einer Kette plus eine Sonderfertigkeit, die auf Stufe I
    // aufbaut — dieselbe Konstellation wie Eiserner Wille / Gedankenschutz
    // im echten Katalog.
    const willeI = SpecialAbilityDef(
      id: 'magsf_eiserner_wille_i',
      name: 'Eiserner Wille I',
      gruppe: 'magisch',
      kategorie: 'Geistestechnik',
      kosten: '200 AP',
      kette: SpecialAbilityChainRef(
        id: 'eiserner_wille',
        stufe: 1,
        label: 'Eiserner Wille',
      ),
      voraussetzungenStruktur: <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'MU',
          min: 13,
        ),
      ],
    );
    const willeII = SpecialAbilityDef(
      id: 'magsf_eiserner_wille_ii',
      name: 'Eiserner Wille II',
      gruppe: 'magisch',
      kategorie: 'Geistestechnik',
      kosten: '300 AP',
      kette: SpecialAbilityChainRef(id: 'eiserner_wille', stufe: 2),
      voraussetzungenStruktur: <SpecialAbilityRequirement>[
        SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 1,
        ),
      ],
    );
    const gedankenschutz = SpecialAbilityDef(
      id: 'magsf_gedankenschutz',
      name: 'Gedankenschutz',
      gruppe: 'magisch',
      kategorie: 'Geistestechnik',
      kosten: '250 AP',
      voraussetzungenStruktur: <SpecialAbilityRequirement>[
        // Der Fixture-Held hat MU 14 und IN 13 — die SF fehlt ihm also nur.
        SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'IN',
          min: 13,
        ),
        SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 1,
        ),
      ],
    );

    Future<_OpenedMagicTab> openPicker(
      WidgetTester tester, {
      List<MagicSpecialAbility> vorhanden = const <MagicSpecialAbility>[],
    }) async {
      final repo = FakeRepository(
        heroes: <HeroSheet>[
          buildHero(
            magicSpecialAbilities: vorhanden,
          ).copyWith(apAvailable: 1000),
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
      final opened = await openMagicTab(
        tester,
        repo: repo,
        catalog: buildCatalog(
          magicSpecialAbilities: const <SpecialAbilityDef>[
            willeI,
            willeII,
            gedankenschutz,
          ],
        ),
      );
      await tester.tap(find.text('Repr. & SF'));
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('magic-sf-add-from-catalog')),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);
      return opened;
    }

    testWidgets('die Kette erscheint als eine Karte statt als Einzel-Chips', (
      tester,
    ) async {
      await openPicker(tester);

      expect(
        find.byKey(const ValueKey<String>('sf-chain-eiserner_wille')),
        findsOneWidget,
      );
      expect(find.text('Eiserner Wille'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('sf-chain-acquire-magsf_eiserner_wille_i'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nach Stufe I bietet die Karte Stufe II an', (tester) async {
      await openPicker(
        tester,
        vorhanden: const <MagicSpecialAbility>[
          MagicSpecialAbility(name: 'Eiserner Wille I'),
        ],
      );

      expect(find.text('Stufe I von II'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('sf-chain-acquire-magsf_eiserner_wille_ii'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('eine gesperrte SF nennt die Zahl der offenen Punkte', (
      tester,
    ) async {
      await openPicker(tester);

      expect(find.text('1 Voraussetzung offen'), findsOneWidget);
    });

    testWidgets(
      'der Erwerbsdialog verlangt bei offenen Punkten den Meisterentscheid',
      (tester) async {
        final opened = await openPicker(tester);

        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text('Gedankenschutz'),
              matching: find.byType(Container),
            ),
            matching: find.byType(Switch),
          ),
        );
        await _pumpAndSettleIgnoringKnownOverflow(tester);

        expect(
          find.byKey(const ValueKey<String>('erwerb-voraussetzungen')),
          findsOneWidget,
        );
        expect(find.text('Eine Voraussetzung ist nicht erfüllt.'), findsOneWidget);

        final erwerben = find.widgetWithText(FilledButton, 'Erwerben');
        expect(
          tester.widget<FilledButton>(erwerben).onPressed,
          isNull,
          reason: 'ohne Meisterentscheid darf nicht erworben werden',
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('erwerb-meisterentscheid')),
        );
        await _pumpAndSettleIgnoringKnownOverflow(tester);
        await tester.tap(erwerben);
        await _pumpAndSettleIgnoringKnownOverflow(tester);
        await tester.tap(find.text('Fertig'));
        await _pumpAndSettleIgnoringKnownOverflow(tester);
        await opened.actions.save();
        await _pumpAndSettleIgnoringKnownOverflow(tester);

        final savedHero = await opened.repo.loadHeroById('demo');
        expect(savedHero?.magicSpecialAbilities.map((a) => a.name), [
          'Gedankenschutz',
        ]);
        expect(savedHero?.apSpent, 250);
      },
    );

    testWidgets('erfuellte Voraussetzungen brauchen keinen Meisterentscheid', (
      tester,
    ) async {
      await openPicker(
        tester,
        vorhanden: const <MagicSpecialAbility>[
          MagicSpecialAbility(name: 'Eiserner Wille I'),
        ],
      );

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Gedankenschutz'),
            matching: find.byType(Container),
          ),
          matching: find.byType(Switch),
        ),
      );
      await _pumpAndSettleIgnoringKnownOverflow(tester);

      expect(
        find.byKey(const ValueKey<String>('erwerb-meisterentscheid')),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Erwerben'))
            .onPressed,
        isNotNull,
      );
    });
  });
}
