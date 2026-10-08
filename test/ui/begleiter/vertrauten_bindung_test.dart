import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Vertrautenbindung im Begleiter-Tab: der manuelle Ablauf aus
/// `docs/vertraute_plan.md` (binden, AP vergeben, steigern, Zauber lernen)
/// als Sofortbuchungen auf den gespeicherten Helden.
void main() {
  HeroSheet hexe(HeroCompanion vertrauter) => HeroSheet(
    id: 'demo',
    name: 'Hexe',
    level: 1,
    apTotal: 1000,
    apSpent: 500,
    apAvailable: 500,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    companions: <HeroCompanion>[vertrauter],
  );

  const mira = HeroCompanion(
    id: 'mira',
    name: 'Mira',
    typ: BegleiterTyp.vertrauter,
  );

  Future<(FakeRepository, WorkspaceTabEditActions)> pumpTab(
    WidgetTester tester,
    HeroCompanion begleiter,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: <HeroSheet>[hexe(begleiter)],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith(
            (ref) async => const RulesCatalog(
              version: 'test',
              source: 'test',
              talents: <TalentDef>[],
              spells: <SpellDef>[],
              weapons: <WeaponDef>[],
            ),
          ),
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroBegleiterTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registered) => actions = registered,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repo, actions!);
  }

  Future<void> tippe(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await _pumpOhneUeberlauf(tester);
  }

  Future<void> apEingeben(WidgetTester tester, String ap) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('vertrauten-ap-feld')),
      ap,
    );
    await tester.pump();
    await tippe(tester, 'vertrauten-ap-bestaetigen');
  }

  testWidgets('binden, AP vergeben, steigern und Zauber lernen', (
    tester,
  ) async {
    final (repo, actions) = await pumpTab(tester, mira);
    Future<HeroSheet> held() async => (await repo.loadHeroById('demo'))!;

    // 1. Binden: Katze ohne Zusatzpunkte, 80 AP der Hexe.
    await tippe(tester, 'vertrauten-binden');
    expect(find.text('Binden (80 AP)'), findsOneWidget);
    await tippe(tester, 'vertrauten-bindung-bestaetigen');
    var stand = await held();
    var v = stand.companions.single;
    expect(stand.apSpent, 580);
    expect(v.vertrautenBindung!.artId, 'vart_katze');
    expect(v.mu, 7);
    expect(v.loyalitaet, 15);

    // 2. AP vergeben: Anteil einrichten mit Nachtrag, dann übertragen.
    await tippe(tester, 'vertrauten-anteil-einrichten');
    await apEingeben(tester, '100');
    await tippe(tester, 'vertrauten-ap-uebertragen');
    await apEingeben(tester, '50');
    stand = await held();
    v = stand.companions.single;
    expect(stand.apSpent, 630);
    expect(v.apGesamt, 150);
    expect(v.loyalitaet, 16);
    expect(v.vertrautenBindung!.abenteuerApErfasst, 0);

    // 3. Einen Wert steigern: MU 7 → 8 (F, direkt).
    await actions.startEdit();
    await _pumpOhneUeberlauf(tester);
    final mu = find.byTooltip('MU steigern').first;
    await tester.ensureVisible(mu);
    await tester.tap(mu);
    await _pumpOhneUeberlauf(tester);
    await tester.tap(find.byTooltip('Wert steigern'));
    await _pumpOhneUeberlauf(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.trending_up),
      ),
    );
    await _pumpOhneUeberlauf(tester);
    v = (await held()).companions.single;
    expect(v.steigerungen['mu'], 1);
    final nachSteigerung = v.apAusgegeben!;
    expect(nachSteigerung, greaterThan(0));
    await actions.cancel();
    await _pumpOhneUeberlauf(tester);

    // 4. Einen Vertrautenzauber lernen: Tiersinne für 15 AP des Vertrauten.
    await tippe(tester, 'vertrauten-zauber-lernen');
    await tippe(tester, 'vertrauten-vzaub_tiersinne');
    await tippe(tester, 'vertrauten-zauber-bestaetigen');
    stand = await held();
    v = stand.companions.single;
    expect(stand.apSpent, 630, reason: 'die Hexe zahlt keine Zauber');
    expect(v.apAusgegeben, nachSteigerung + 15);
    expect(
      v.ritualCategories.single.rituals.map((r) => r.name),
      containsAll(<String>['Zwiegespräch', 'Tiersinne']),
    );
  });

  testWidgets('Bestandsvertraute werden ohne Buchung erfasst', (tester) async {
    final (repo, _) = await pumpTab(
      tester,
      mira.copyWith(mu: 9, steigerungen: const {'ini': 2}, ini: 10),
    );

    expect(
      find.textContaining('INI: Nach WdZ S. 125 nicht steigerbar'),
      findsOneWidget,
    );
    await tippe(tester, 'vertrauten-erfassen');
    await tippe(tester, 'vertrauten-erfassen-bestaetigen');

    final stand = (await repo.loadHeroById('demo'))!;
    final v = stand.companions.single;
    expect(stand.apSpent, 500);
    expect(v.mu, 9);
    expect(v.steigerungen, {'ini': 2});
    expect(v.vertrautenBindung!.bindungskosten, isNull);
    expect(find.text('Bindung ohne Buchung'), findsOneWidget);
  });

  testWidgets('Ausbildung: das Kampftier steht nicht zur Wahl', (tester) async {
    final (repo, _) = await pumpTab(
      tester,
      mira.copyWith(
        kl: 5,
        apGesamt: 500,
        vertrautenBindung: const VertrautenBindung(artId: 'vart_hund'),
      ),
    );

    await tippe(tester, 'vertrauten-ausbildung');
    expect(
      find.byKey(
        const ValueKey<String>('vertrauten-ausbildung-vausb_kampftier'),
      ),
      findsNothing,
    );
    await tippe(tester, 'vertrauten-ausbildung-vfert_komm');
    await tippe(tester, 'vertrauten-ausbildung-bestaetigen');

    final v = (await repo.loadHeroById('demo'))!.companions.single;
    expect(v.apAusgegeben, 10);
    expect(v.vertrautenBindung!.ausbildungen.single.katalogId, 'vfert_komm');
  });
}

// Einige Bestandsansichten laufen im Test-Layout über (siehe
// `begleiter_angriff_test.dart`); das hat mit den Buchungen nichts zu tun.
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
