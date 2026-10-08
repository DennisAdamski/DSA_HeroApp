import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/magic_special_ability.dart';
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
  HeroSheet hexe(
    HeroCompanion vertrauter, {
    bool bindungSf = true,
    bool keinVertrauter = false,
  }) => HeroSheet(
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
    magicSpecialAbilities: <MagicSpecialAbility>[
      if (bindungSf) const MagicSpecialAbility(name: 'Vertrautenbindung'),
    ],
    nachteilEintraege: <HeroMerkmal>[
      if (keinVertrauter)
        const HeroMerkmal(
          katalogId: 'dis_kein_vertrauter',
          text: 'Kein Vertrauter',
        ),
    ],
  );

  const mira = HeroCompanion(
    id: 'mira',
    name: 'Mira',
    typ: BegleiterTyp.vertrauter,
  );

  Future<(FakeRepository, WorkspaceTabEditActions)> pumpTab(
    WidgetTester tester,
    HeroCompanion begleiter, {
    bool bindungSf = true,
    bool keinVertrauter = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        hexe(begleiter, bindungSf: bindungSf, keinVertrauter: keinVertrauter),
      ],
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

  testWidgets('Machtvoller Vertrauter: Vorlage, eigener Name, freie Werte', (
    tester,
  ) async {
    final (repo, _) = await pumpTab(tester, mira);

    await tippe(tester, 'vertrauten-binden');
    await tester.tap(find.text('Machtvoller Vertrauter'));
    await _pumpOhneUeberlauf(tester);
    await tester.enterText(
      find.byKey(const ValueKey<String>('vertrauten-machtvoll-name')),
      'Luchs',
    );
    for (var i = 0; i < 6; i++) {
      final kk = find.byTooltip('KK (Vorlage 2) erhöhen');
      await tester.ensureVisible(kk);
      await tester.tap(kk);
      await tester.pump();
    }
    for (var i = 0; i < 2; i++) {
      final kl = find.byTooltip('KL · AP (Vorlage 4) erhöhen');
      await tester.ensureVisible(kl);
      await tester.tap(kl);
      await tester.pump();
    }
    // 120 AP + 2 Punkte KL über der Vorlage; KK ist frei.
    expect(find.text('Binden (124 AP)'), findsOneWidget);
    await tippe(tester, 'vertrauten-bindung-bestaetigen');

    final stand = (await repo.loadHeroById('demo'))!;
    final v = stand.companions.single;
    expect(stand.apSpent, 624);
    expect(v.gattung, 'Luchs');
    expect((v.kl, v.kk), (6, 8));
    expect(v.vertrautenBindung!.machtvoll, isTrue);
    expect(v.vertrautenBindung!.artId, 'vart_katze');
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

  testWidgets('fehlende Voraussetzungen: Binden nur per Meisterentscheid', (
    tester,
  ) async {
    final (repo, _) = await pumpTab(
      tester,
      mira,
      bindungSf: false,
      keinVertrauter: true,
    );

    await tippe(tester, 'vertrauten-binden');
    expect(
      find.text('Die Sonderfertigkeit Vertrautenbindung fehlt.'),
      findsOneWidget,
    );
    expect(
      find.text('Die Hexe hat den Nachteil „Kein Vertrauter“.'),
      findsOneWidget,
    );
    final binden = find.byKey(
      const ValueKey<String>('vertrauten-bindung-bestaetigen'),
    );
    expect(tester.widget<FilledButton>(binden).onPressed, isNull);

    await tippe(tester, 'vertrauten-bindung-meisterentscheid');
    expect(find.text('Trotzdem binden (80 AP)'), findsOneWidget);
    await tippe(tester, 'vertrauten-bindung-bestaetigen');

    final stand = (await repo.loadHeroById('demo'))!;
    expect(stand.apSpent, 580);
    expect(stand.companions.single.vertrautenBindung!.artId, 'vart_katze');
  });

  testWidgets('ohne Hinweise bleibt der Dialog unverändert', (tester) async {
    await pumpTab(tester, mira);
    await tippe(tester, 'vertrauten-binden');
    expect(
      find.byKey(const ValueKey<String>('vertrauten-bindung-hinweise')),
      findsNothing,
    );
    expect(find.text('Binden (80 AP)'), findsOneWidget);
  });

  testWidgets(
    'Aurapanzer: 125 AP des Vertrauten, AE 20 oder Meisterentscheid',
    (tester) async {
      final (repo, _) = await pumpTab(
        tester,
        mira.copyWith(
          maxAsp: 20,
          apGesamt: 300,
          vertrautenBindung: const VertrautenBindung(artId: 'vart_katze'),
        ),
      );

      await tippe(tester, 'vertrauten-aurapanzer');
      await tippe(tester, 'vertrauten-aurapanzer-bestaetigen');

      final v = (await repo.loadHeroById('demo'))!.companions.single;
      expect(v.apAusgegeben, 125);
      expect(v.sonderfertigkeiten.single.katalogId, 'magsf_aurapanzer');
      expect(
        find.byKey(const ValueKey<String>('vertrauten-aurapanzer')),
        findsNothing,
      );
    },
  );

  testWidgets('Aurapanzer bei AE 19 nur per Meisterentscheid', (tester) async {
    final (repo, _) = await pumpTab(
      tester,
      mira.copyWith(
        maxAsp: 19,
        apGesamt: 300,
        vertrautenBindung: const VertrautenBindung(artId: 'vart_katze'),
      ),
    );

    await tippe(tester, 'vertrauten-aurapanzer');
    expect(find.text('AE 19, nötig sind 20.'), findsOneWidget);
    final erwerben = find.byKey(
      const ValueKey<String>('vertrauten-aurapanzer-bestaetigen'),
    );
    expect(tester.widget<FilledButton>(erwerben).onPressed, isNull);
    await tippe(tester, 'vertrauten-aurapanzer-meister');
    await tippe(tester, 'vertrauten-aurapanzer-bestaetigen');

    final v = (await repo.loadHeroById('demo'))!.companions.single;
    expect(v.apAusgegeben, 125);
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
