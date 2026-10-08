import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Vertrautenaktionen am Spieltisch (V2): der manuelle Ablauf aus
/// `docs/vertraute_plan.md` als Widget-Tests.
void main() {
  const mira = HeroCompanion(
    id: 'mira',
    name: 'Mira',
    typ: BegleiterTyp.vertrauter,
    maxLep: 24,
    startLep: 24,
    maxAsp: 10,
    startAsp: 10,
    maxAup: 40,
    startAup: 40,
    mu: 8,
    kl: 5,
    inn: 6,
    ch: 9,
    loyalitaet: 15,
    vertrautenBindung: VertrautenBindung(artId: 'vart_katze'),
  );

  HeroSheet hexe() => HeroSheet(
    id: 'demo',
    name: 'Hexe',
    level: 1,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 14,
      ch: 13,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    companions: <HeroCompanion>[
      mira.copyWith(
        ritualCategories: [
          kVertrautenmagiePresetCategory.copyWith(
            rituals: [
              kVertrautenmagiePresetCategory.rituals.firstWhere(
                (r) => r.name == 'Tiersinne',
              ),
            ],
          ),
        ],
      ),
    ],
  );

  const start = HeroState(
    currentLep: 30,
    currentAsp: 20,
    currentKap: 0,
    currentAu: 30,
  );

  const katalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: <TalentDef>[],
    spells: <SpellDef>[],
    weapons: <WeaponDef>[],
  );

  FakeRepository repoMit([HeroState zustand = start]) => FakeRepository(
    heroes: <HeroSheet>[hexe()],
    states: <String, HeroState>{'demo': zustand},
  );

  List<Override> overrides(FakeRepository repo) => [
    heroRepositoryProvider.overrideWithValue(repo),
    rulesCatalogProvider.overrideWith((ref) async => katalog),
    appSettingsProvider.overrideWith(
      (ref) => Stream<AppSettings>.value(const AppSettings()),
    ),
  ];

  void breit(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpTab(WidgetTester tester, FakeRepository repo) async {
    breit(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(repo),
        child: MaterialApp(
          home: Scaffold(
            body: HeroBegleiterTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (WorkspaceTabEditActions _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tippe(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await _pumpOhneUeberlauf(tester);
  }

  testWidgets('1. Der Vertraute verliert 5 LeP; Voll holt ihn zurück', (
    tester,
  ) async {
    final repo = repoMit();
    await pumpTab(tester, repo);

    expect(find.text('24 / 24'), findsOneWidget);
    await tippe(tester, 'begleiter-lep-minus-5');
    expect(find.text('19 / 24'), findsOneWidget);
    final z = (await repo.loadHeroState('demo'))!;
    expect(z.begleiterZustaende['mira']!.currentLep, 19);
    expect(z.currentLep, 30, reason: 'der Held bleibt unberührt');

    await tippe(tester, 'begleiter-lep-voll');
    expect((await repo.loadHeroState('demo'))!.begleiterZustaende, isEmpty);
  });

  testWidgets('2. Eine Regenerationsphase mit Körperkontakt (Rast)', (
    tester,
  ) async {
    final repo = repoMit(
      start.withBegleiterZustand(
        'mira',
        const BegleiterZustand(currentLep: 10, currentAsp: 2),
      ),
    );
    breit(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(repo),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RestPanel(heroId: 'demo')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Schlaf'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rest-vertraute')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('rest-vertrauter-kontakt-mira')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-dialog-apply')));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    // ⌈24/10⌉ = 3 LeP plus 1 durch den Körperkontakt, ⌈10/10⌉ = 1 AsP.
    expect(z.begleiterZustaende['mira']!.currentLep, 14);
    expect(z.begleiterZustaende['mira']!.currentAsp, 3);
  });

  testWidgets('2b. Ein abgewählter Vertrauter regeneriert nicht', (
    tester,
  ) async {
    final repo = repoMit(
      start.withBegleiterZustand(
        'mira',
        const BegleiterZustand(currentLep: 10),
      ),
    );
    breit(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(repo),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: RestPanel(heroId: 'demo')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Schlaf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-vertrauter-mira')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-dialog-apply')));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.begleiterZustaende['mira']!.currentLep, 10);
  });

  testWidgets('3. Die Vereinigung kostet beide 1W6 AsP', (tester) async {
    final repo = repoMit();
    await pumpTab(tester, repo);

    await tippe(tester, 'vertrauten-vereinigung');
    await tester.enterText(
      find.byKey(const ValueKey('vertrauten-vereinigung-hexe')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vertrauten-vereinigung-tier')),
      '2',
    );
    await tester.pump();
    await tippe(tester, 'vertrauten-vereinigung-bestaetigen');

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.currentAsp, 16);
    expect(z.begleiterZustaende['mira']!.currentAsp, 8);
    expect(z.diceLog.map((e) => e.title), [
      'Vereinigung: Hexe',
      'Vereinigung: Mira',
    ]);
    expect(find.text('8 / 10'), findsOneWidget);
  });

  testWidgets('4. Tiersinne mit Kontakt gewürfelt, die AsP sinken', (
    tester,
  ) async {
    final repo = repoMit();
    await pumpTab(tester, repo);

    await tippe(tester, 'vertrauten-zauber-wuerfeln');
    await tippe(tester, 'vertrauten-wurf-0');
    await tippe(tester, 'vertrauten-zauber-wuerfeln-los');

    // Probe mit den Eigenschaften der Hexe (KL 12, IN 14) und RK 3.
    expect(find.textContaining('Vertrautenzauber: Tiersinne'), findsOneWidget);
    expect(find.text('KL: 12'), findsWidgets);
    expect(find.text('IN: 14'), findsWidgets);
    expect(find.text('Pool: 3'), findsOneWidget, reason: 'RK 3');
    await tester.tap(find.text('Würfeln').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schließen'));
    await _pumpOhneUeberlauf(tester);

    // Vorbelegt: 3 AsP Grundkosten, ohne Spielrunden.
    final feld = tester.widget<TextField>(
      find.byKey(const ValueKey('vertrauten-zauber-asp')),
    );
    expect(feld.controller!.text, '3');
    await tippe(tester, 'vertrauten-zauber-asp-bestaetigen');

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.begleiterZustaende['mira']!.currentAsp, 7);
    expect(z.currentAsp, 20, reason: 'die Hexe zahlt die AsP nicht');
    expect(
      z.diceLog.map((e) => e.title),
      contains('Vertrautenzauber: Tiersinne'),
    );
  });

  testWidgets('4b. Allein: Eigenschaften des Vertrauten, 15 erleichtert', (
    tester,
  ) async {
    final repo = repoMit();
    await pumpTab(tester, repo);

    await tippe(tester, 'vertrauten-zauber-wuerfeln');
    await tippe(tester, 'vertrauten-zauber-kontakt');
    await tippe(tester, 'vertrauten-wurf-0');
    await tippe(tester, 'vertrauten-zauber-wuerfeln-los');

    expect(find.text('KL: 5'), findsWidgets);
    expect(find.text('IN: 6'), findsWidgets);
    final modifikator = find.widgetWithText(TextField, '15');
    expect(modifikator, findsOneWidget);
  });

  testWidgets('Treffen versäumt: −1 LeP und −1 LO in zwei Buchungen', (
    tester,
  ) async {
    final repo = repoMit();
    await pumpTab(tester, repo);

    await tippe(tester, 'vertrauten-versaeumt');
    await tippe(tester, 'vertrauten-versaeumt-bestaetigen');

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.begleiterZustaende['mira']!.currentLep, 23);
    final c = (await repo.loadHeroById('demo'))!.companions.single;
    expect(c.loyalitaet, 14);
  });

  testWidgets('Ein Reittier zeigt LeP/AuP, aber keine Vertrautenaktionen', (
    tester,
  ) async {
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        HeroSheet(
          id: 'demo',
          name: 'Reiter',
          level: 1,
          attributes: hexe().attributes,
          companions: const <HeroCompanion>[
            HeroCompanion(
              id: 'rosse',
              name: 'Rosse',
              typ: BegleiterTyp.reittier,
              maxLep: 60,
              startLep: 60,
              maxAup: 80,
              startAup: 80,
            ),
          ],
        ),
      ],
      states: <String, HeroState>{'demo': start},
    );
    await pumpTab(tester, repo);

    expect(
      find.byKey(const ValueKey('begleiter-laufwerte-rosse')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('vertrauten-spiel')), findsNothing);
    await tippe(tester, 'begleiter-aup-minus-5');
    expect(
      (await repo.loadHeroState('demo'))!
          .begleiterZustaende['rosse']!
          .currentAup,
      75,
    );
  });
}

// Einige Bestandsansichten laufen im Test-Layout über (siehe
// `vertrauten_bindung_test.dart`); das hat mit den Buchungen nichts zu tun.
Future<void> _pumpOhneUeberlauf(WidgetTester tester) async {
  await tester.pumpAndSettle();
  Object? fehler;
  do {
    fehler = tester.takeException();
    if (fehler != null && !'$fehler'.contains('A RenderFlex overflowed')) {
      throw fehler;
    }
  } while (fehler != null);
}
