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

/// Reittier-Ausbildung im Begleiter-Tab: erfassen ueber den Editor,
/// Schritte und Pferde-SF als Sofortbuchung auf den gespeicherten Helden.
void main() {
  const feld = <String, Object?>{'zukunftsfeld': 1};

  HeroSheet held(HeroCompanion pferd) => HeroSheet(
    id: 'demo',
    name: 'Alrik',
    level: 1,
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
    companions: <HeroCompanion>[pferd],
  );

  const erprobt = ReittierAusbildung(
    ausgangsstufe: ReittierAusbildungsstufe.erprobt,
    ausgangsart: ReittierAusbildungsart.fundiert,
    unbekannteFelder: feld,
  );
  const pferd = HeroCompanion(
    id: 'falbe',
    name: 'Falbe',
    typ: BegleiterTyp.reittier,
    loyalitaet: 12,
    angriffe: <HeroCompanionAttack>[
      HeroCompanionAttack(id: 't', name: 'Tritt', at: 11, tp: '1W6+2'),
    ],
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
      heroes: <HeroSheet>[held(begleiter)],
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

  Future<HeroCompanion> gespeichert(FakeRepository repo) async =>
      (await repo.loadHeroById('demo'))!.companions.single;

  testWidgets('die Ausbildung wird im Bearbeitungsmodus erfasst', (
    tester,
  ) async {
    final (repo, actions) = await pumpTab(tester, pferd);

    expect(find.text('Reittier-Ausbildung'), findsOneWidget);
    expect(find.textContaining('Keine Ausbildung erfasst'), findsOneWidget);
    expect(find.text('+ Ausbildungsschritt'), findsNothing);

    await actions.startEdit();
    await tester.pumpAndSettle();
    final erfassen = find.byKey(
      const ValueKey<String>('begleiter-ausbildung-erfassen'),
    );
    await tester.ensureVisible(erfassen);
    await tester.tap(erfassen);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pumpAndSettle();
    await actions.save();
    await tester.pumpAndSettle();

    final ausbildung = (await gespeichert(repo)).reittierAusbildung;
    expect(ausbildung, isNotNull);
    expect(ausbildung!.ausgangsstufe, ReittierAusbildungsstufe.erprobt);
    expect(ausbildung.ausgangsart, ReittierAusbildungsart.laendlich);
  });

  testWidgets('ein Schritt nach „geschult“ wird sofort und frisch gebucht', (
    tester,
  ) async {
    final (repo, _) = await pumpTab(
      tester,
      pferd.copyWith(reittierAusbildung: erprobt),
    );
    // Eine andere Stelle aendert den Helden, nachdem der Tab ihn gerendert
    // hat; die Buchung darf diese Aenderung nicht ueberschreiben.
    final zwischen = (await repo.loadHeroById('demo'))!;
    await repo.saveHero(zwischen.copyWith(name: 'Alrik von Sturmfels'));

    final schritt = find.byKey(
      const ValueKey<String>('begleiter-ausbildungsschritt'),
    );
    await tester.ensureVisible(schritt);
    await tester.tap(schritt);
    await tester.pumpAndSettle();
    final variante = find.byKey(const ValueKey<String>('ausbildung-variante'));
    await tester.ensureVisible(variante);
    await tester.tap(variante);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leichtes Streitross (Kampfpferd)').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('ausbildungsschritt-buchen')),
    );
    await tester.pumpAndSettle();

    final heldNeu = (await repo.loadHeroById('demo'))!;
    final ausbildung = heldNeu.companions.single.reittierAusbildung!;
    expect(heldNeu.name, 'Alrik von Sturmfels');
    expect(ausbildung.schritte.single.nach, ReittierAusbildungsstufe.geschult);
    expect(ausbildung.varianteId, 'pvar_leichtes_streitross');
    expect(ausbildung.unbekannteFelder, feld);
    expect(heldNeu.companions.single.sonderfertigkeiten, hasLength(10));
    // Die Ansicht zeigt jetzt Wirkwerte: LO 12 + 3 + 1, Tritt +1.
    expect(find.text('16'), findsWidgets);
    expect(find.text('1W6+3'), findsOneWidget);
    expect(find.textContaining('Reiten −2 · im Kampf −3'), findsOneWidget);
  });

  testWidgets('eine Pferde-SF wird aus dem Katalog erlernt', (tester) async {
    final (repo, _) = await pumpTab(
      tester,
      pferd.copyWith(reittierAusbildung: erprobt),
    );

    final knopf = find.byKey(const ValueKey<String>('begleiter-pferde-sf'));
    await tester.ensureVisible(knopf);
    await tester.tap(knopf);
    await tester.pumpAndSettle();
    final hinlegen = find.byKey(
      const ValueKey<String>('pferde-sf-psf_hinlegen'),
    );
    await tester.ensureVisible(hinlegen);
    await tester.tap(hinlegen);
    await tester.pumpAndSettle();
    expect(find.text('Lernprobe: Abrichten +5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('pferde-sf-erlernen')));
    await tester.pumpAndSettle();

    final sf = (await gespeichert(repo)).sonderfertigkeiten.single;
    expect(sf.katalogId, 'psf_hinlegen');
    expect(sf.name, 'Hinlegen');
  });

  testWidgets('offene Aenderungen sperren die Sofortbuchungen', (tester) async {
    final (_, actions) = await pumpTab(
      tester,
      pferd.copyWith(reittierAusbildung: erprobt),
    );
    await actions.startEdit();
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name').first, 'X');
    await tester.pumpAndSettle();

    final schritt = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('begleiter-ausbildungsschritt')),
    );
    final sf = tester.widget<TextButton>(
      find.byKey(const ValueKey<String>('begleiter-pferde-sf')),
    );
    expect(schritt.onPressed, isNull);
    expect(sf.onPressed, isNull);
  });
}
