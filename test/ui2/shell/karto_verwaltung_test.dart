import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

void main() {
  const catalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    spells: [],
    weapons: [],
  );
  const adapter = KartoBestandsAdapterImpl();

  HeroSheet hero({bool magic = true}) => HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: const Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
    resourceActivationConfig: HeroResourceActivationConfig(
      magicEnabledOverride: magic,
    ),
  );

  Future<void> pumpManagement(
    WidgetTester tester, {
    required HeroSheet hero,
    double width = 1200,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(
            FakeRepository(heroes: <HeroSheet>[hero]),
          ),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: adapter.verwaltung(
              heroId: hero.id,
              korrekturenGesperrt: false,
              onVerlassenRegistriert: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses canonical categories and their registered actions', (
    tester,
  ) async {
    await pumpManagement(tester, hero: hero());

    const categories = <(String, String, String?)>[
      ('Übersicht', 'Vitalwerte, Statuswerte und aktive Effekte', 'Bearbeiten'),
      ('Talente', 'Talentwerte und Spezialisierungen', 'Bearbeiten'),
      (
        'Kampf',
        'Kampftechniken, Nahkampf, Sonderfertigkeiten, Manöver',
        'Bearbeiten',
      ),
      ('Magie', 'Katalogansicht für Zauber', 'Bearbeiten'),
      ('Inventar', 'Ausrüstung und Gegenstände', '+ Gegenstand'),
      (
        'Chroniken, Kontakte & Abenteuer',
        'Chroniken, Kontakte, Abenteuer und soziale Verbindungen',
        'Bearbeiten',
      ),
      ('Reisebericht', 'Abenteuererfahrungen und Meilensteine', 'Bearbeiten'),
      ('Begleiter', 'Vertraute und Begleiter des Helden', 'Bearbeiten'),
      ('Gruppe', 'Gruppenmitglieder und Einladungen', null),
    ];
    for (final category in categories) {
      final tab = find.widgetWithText(Tab, category.$1);
      expect(tab, findsOneWidget);
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(
        find.byKey(const ValueKey<String>('management-active-title')),
      );
      final helper = tester.widget<Text>(
        find.byKey(const ValueKey<String>('management-active-helper')),
      );
      expect(title.data, category.$1);
      expect(helper.data, category.$2);
      if (category.$3 != null) {
        final actionText = find.text(category.$3!);
        final actionTooltip = find.byTooltip(category.$3!);
        expect(
          actionText.evaluate().isNotEmpty ||
              actionTooltip.evaluate().isNotEmpty,
          isTrue,
          reason: '${category.$1} must expose ${category.$3}',
        );
      } else {
        expect(find.text('Bearbeiten'), findsNothing);
        expect(find.byTooltip('Bearbeiten'), findsNothing);
      }
    }

    final management = find.byType(WorkspaceManagementBody);
    final compat = Theme.of(tester.element(management)).extension<CodexTheme>();
    expect(compat?.parchment, kartoHell.blatt);
    expect(compat?.showDecoration, isFalse);
  });

  testWidgets('keeps magic conditional on the canonical visibility rule', (
    tester,
  ) async {
    await pumpManagement(tester, hero: hero(magic: false));

    expect(find.widgetWithText(Tab, 'Magie'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(8));
  });

  testWidgets(
    'keeps title, helper and actions usable at 320 dp and scale two',
    (tester) async {
      await pumpManagement(tester, hero: hero(), width: 320, textScale: 2);

      expect(
        find.byKey(const ValueKey<String>('management-active-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('management-active-helper')),
        findsOneWidget,
      );
      expect(find.byTooltip('Bearbeiten'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('applies the compatibility theme to adapter dialogs', (
    tester,
  ) async {
    final repository = FakeRepository(heroes: <HeroSheet>[hero()]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repository),
          rulesCatalogProvider.overrideWith((ref) async => catalog),
        ],
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: _DialogLauncher(adapter: adapter),
        ),
      ),
    );

    await tester.tap(find.text('Rast öffnen'));
    await tester.pumpAndSettle();

    final dialog = find.byKey(const ValueKey<String>('rest-dialog'));
    expect(dialog, findsOneWidget);
    final compat = Theme.of(tester.element(dialog)).extension<CodexTheme>();
    expect(compat?.panel, kartoHell.feld);
    expect(compat?.showDecoration, isFalse);
  });
}

class _DialogLauncher extends StatelessWidget {
  const _DialogLauncher({required this.adapter});

  final KartoBestandsAdapter adapter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => adapter.rast(context: context, heroId: 'demo'),
          child: const Text('Rast öffnen'),
        ),
      ),
    );
  }
}
