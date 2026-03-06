import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
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
  HeroSheet buildHero() {
    return const HeroSheet(
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
      spells: <String, HeroSpellEntry>{
        'spell_axxeleratus': HeroSpellEntry(
          spellValue: 8,
          specializations: <String>['Heldeneintrag'],
        ),
      },
    );
  }

  RulesCatalog buildCatalog() {
    return const RulesCatalog(
      version: 'test_catalog',
      source: 'test',
      talents: <TalentDef>[],
      spells: <SpellDef>[
        SpellDef(
          id: 'spell_axxeleratus',
          name: 'Axxeleratus Blitzgeschwind',
          tradition: 'Elf',
          steigerung: 'C',
          attributes: <String>['Klugheit', 'Gewandheit', 'Konstitution'],
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
}
