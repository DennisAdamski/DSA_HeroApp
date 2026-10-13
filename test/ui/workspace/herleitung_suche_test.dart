import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/herleitung_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/herleitung_suche_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';

// Die Berechnungsschritte aller erklärbaren Werte sind über ein (i) in der
// Werkzeugleiste erreichbar und durchsuchbar (ARCH-04).

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 3,
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
);

const _zustand = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
  activeSpellEffects: ActiveSpellEffectsState(
    activeEffectIds: <String>[activeSpellEffectAxxeleratus],
  ),
);

List<Override> _overrides() => [
  heroRepositoryProvider.overrideWithValue(
    FakeRepository(heroes: [_held], states: {'demo': _zustand}),
  ),
  rulesCatalogProvider.overrideWith((ref) async => _katalog),
  debugModusProvider.overrideWith((ref) => false),
];

void _grosseAnsicht(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _eintrag(String id) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('herleitung-eintrag-$id-'),
);

void main() {
  testWidgets('Dialog listet Werte und filtert nach Schritten', (tester) async {
    _grosseAnsicht(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(
          home: Scaffold(body: HerleitungsSucheDialog(heroId: 'demo')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eigenschaften'), findsOneWidget);
    expect(_eintrag('eigenschaft-mu'), findsOneWidget);
    expect(_eintrag('basiswert-lep'), findsOneWidget);
    // Ohne Suche bleiben die Einträge zugeklappt.
    expect(find.byType(HerleitungsSchritte), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('herleitung-suche-feld')),
      'axxeleratus',
    );
    await tester.pumpAndSettle();

    expect(_eintrag('eigenschaft-mu'), findsNothing);
    // Treffer stehen offen und zeigen ihre Schritte.
    expect(find.byType(HerleitungsSchritte), findsWidgets);

    // Mehrere Begriffe grenzen weiter ein.
    await tester.enterText(
      find.byKey(const ValueKey<String>('herleitung-suche-feld')),
      'ausweichen axxeleratus',
    );
    await tester.pumpAndSettle();
    expect(_eintrag('kampf-ausweichen'), findsOneWidget);
    expect(_eintrag('kampf-at'), findsNothing);
    expect(find.text('Axxeleratus PA'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey<String>('herleitung-suche-feld')),
      'gibtesnicht',
    );
    await tester.pumpAndSettle();
    expect(find.text('Kein Wert gefunden.'), findsOneWidget);
  });

  testWidgets('(i) im Heldenbogen öffnet die Berechnungsschritte', (
    tester,
  ) async {
    _grosseAnsicht(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(home: HeroWorkspaceScreen(heroId: 'demo')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-herleitung-suche')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HerleitungsSucheDialog), findsOneWidget);
    expect(_eintrag('basiswert-lep'), findsOneWidget);
  });

  testWidgets('(i) in der Verwaltung öffnet die Berechnungsschritte', (
    tester,
  ) async {
    _grosseAnsicht(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          home: Scaffold(
            body: WorkspaceManagementBody(
              heroId: 'demo',
              korrekturenGesperrt: false,
              onVerlassenRegistriert: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('management-herleitung-suche')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HerleitungsSucheDialog), findsOneWidget);
  });
}
