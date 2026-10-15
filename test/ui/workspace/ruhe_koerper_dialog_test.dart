import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/heilung/ruhe_koerper_dialog.dart';

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

const _leererKatalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

HeroState _zustand({Map<WundZone, int>? wunden}) {
  return HeroState(
    currentLep: 2,
    currentAsp: 3,
    currentKap: 0,
    currentAu: 20,
    erschoepfung: 20,
    ueberanstrengung: 6,
  ).copyWith(wpiZustand: WundZustand(wundenProZone: wunden ?? const {}));
}

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  late int uebernommen;

  Future<FakeRepository> zeigePanel(WidgetTester tester, HeroState z) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    uebernommen = 0;
    final repo = FakeRepository(heroes: [_held], states: {'demo': z});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RuheKoerperPanel(
                heroId: 'demo',
                onUebernommen: () => uebernommen++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('Vorschau und Buchung von LeP, Überanstrengung und Erschöpfung', (
    tester,
  ) async {
    final repo = await zeigePanel(tester, _zustand());
    expect(
      tester.widget<FilledButton>(_key('ruhe-uebernehmen')).onPressed,
      isNull,
    );

    await tester.enterText(_key('ruhe-zfp'), '8');
    await tester.enterText(_key('ruhe-stunden'), '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('LeP 2 → 8'), findsOneWidget);
    expect(find.textContaining('Überanstrengung 6 → 0'), findsOneWidget);
    expect(find.textContaining('Erschöpfung 20 → 0'), findsOneWidget);

    await tester.tap(_key('ruhe-uebernehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.currentLep, 8);
    expect(z.ueberanstrengung, 0);
    expect(z.erschoepfung, 0);
    expect(z.buchungen, hasLength(1));
    expect(uebernommen, 1);
  });

  testWidgets('Stunden über ZfP* sperren das Übernehmen', (tester) async {
    await zeigePanel(tester, _zustand());
    await tester.enterText(_key('ruhe-zfp'), '4');
    await tester.enterText(_key('ruhe-stunden'), '5');
    await tester.pumpAndSettle();

    expect(_key('ruhe-fehler'), findsWidgets);
    expect(
      tester.widget<FilledButton>(_key('ruhe-uebernehmen')).onPressed,
      isNull,
    );
  });

  testWidgets('Wunden lassen sich je 6 Stunden zonenweise schließen', (
    tester,
  ) async {
    final repo = await zeigePanel(
      tester,
      _zustand(wunden: {WundZone.brust: 2, WundZone.kopf: 1}),
    );
    await tester.enterText(_key('ruhe-zfp'), '12');
    await tester.enterText(_key('ruhe-stunden'), '12');
    await tester.pumpAndSettle();

    await tester.tap(_key('ruhe-wunden-plus-brust'));
    await tester.tap(_key('ruhe-wunden-plus-kopf'));
    await tester.pumpAndSettle();
    // Mehr als 2 Wunden bei 12 Stunden gibt es nicht.
    expect(
      tester.widget<IconButton>(_key('ruhe-wunden-plus-brust')).onPressed,
      isNull,
    );

    await tester.tap(_key('ruhe-uebernehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.wpiZustand.wundenInZone(WundZone.brust), 1);
    expect(z.wpiZustand.wundenInZone(WundZone.kopf), 0);
  });
}
