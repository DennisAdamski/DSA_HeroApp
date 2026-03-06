import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
          variants: <String>[
            'Blitzgeschwind (+7). Mehr Tempo.',
            'Koboldisch. Nur Sprache.',
          ],
        ),
      ],
      weapons: <WeaponDef>[],
    );
  }

  Future<void> openMagicTab(
    WidgetTester tester,
    FakeRepository repo,
    RulesCatalog catalog,
  ) async {
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
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
  }

  testWidgets(
    'variants column and dialog use catalog variants instead of hero specializations',
    (tester) async {
      final repo = FakeRepository(
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

      await openMagicTab(tester, repo, buildCatalog());

      expect(find.text('Varianten'), findsOneWidget);
      expect(find.text('Heldeneintrag'), findsNothing);

      final horizontalScrollView = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScrollView, findsOneWidget);

      await tester.drag(horizontalScrollView, const Offset(-1600, 0));
      await tester.pumpAndSettle();

      final variantPreview = find.textContaining('Blitzgeschwind (+7)');
      expect(variantPreview, findsOneWidget);

      await tester.tap(variantPreview);
      await tester.pumpAndSettle();

      expect(find.text('Koboldisch. Nur Sprache.'), findsOneWidget);
      expect(find.text('Heldeneintrag'), findsNothing);
      expect(find.text('Schließen'), findsOneWidget);
    },
  );
}
