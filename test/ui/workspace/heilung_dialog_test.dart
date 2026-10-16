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
import 'package:dsa_heldenverwaltung/ui/screens/workspace/heilung/heilung_dialog.dart';

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

HeroState _zustand({int lep = 10, int asp = 20, Map<WundZone, int>? wunden}) {
  return HeroState(
    currentLep: lep,
    currentAsp: asp,
    currentKap: 0,
    currentAu: 20,
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
              child: HeilungPanel(
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

  testWidgets(
    'Balsam: Vorschau, Übernehmen bucht LeP ohne AsP bei Fremdquelle',
    (tester) async {
      final repo = await zeigePanel(tester, _zustand(lep: 2));
      expect(
        tester.widget<FilledButton>(_key('heilung-uebernehmen')).onPressed,
        isNull,
      );

      await tester.enterText(_key('heilung-zfw'), '9');
      await tester.enterText(_key('heilung-asp'), '10');
      await tester.pumpAndSettle();
      expect(find.textContaining('LeP 2 → 12'), findsOneWidget);

      await tester.tap(_key('heilung-uebernehmen'));
      await tester.pumpAndSettle();

      final z = (await repo.loadHeroState('demo'))!;
      expect(z.currentLep, 12);
      expect(z.currentAsp, 20);
      expect(z.buchungen, hasLength(1));
      expect(uebernommen, 1);
    },
  );

  testWidgets('Selbstwirkung zieht die AsP des Helden ab', (tester) async {
    final repo = await zeigePanel(tester, _zustand());
    await tester.enterText(_key('heilung-zfw'), '9');
    await tester.enterText(_key('heilung-asp'), '10');
    await tester.tap(_key('heilung-selbst'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AsP 20 → 10'), findsOneWidget);

    await tester.tap(_key('heilung-uebernehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.currentAsp, 10);
  });

  testWidgets('angesagte Wundheilung schlägt Wunden vor und schließt sie', (
    tester,
  ) async {
    final repo = await zeigePanel(
      tester,
      _zustand(lep: 2, wunden: {WundZone.brust: 3}),
    );
    await tester.enterText(_key('heilung-zfw'), '9');
    await tester.enterText(_key('heilung-asp'), '15');
    await tester.tap(_key('heilung-wundheilung'));
    await tester.pumpAndSettle();

    // 15 LeP → 2 Wunden (je 7).
    expect(tester.widget<Text>(_key('heilung-wunden')).data, '2');
    await tester.tap(_key('heilung-wunden-minus'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(_key('heilung-wunden')).data, '1');
    await tester.tap(_key('heilung-uebernehmen'));
    await tester.pumpAndSettle();

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.wpiZustand.wundenInZone(WundZone.brust), 2);
    expect(z.currentLep, 17);
  });

  testWidgets('Hexenspeichel verlangt gerade AsP bei Wunden', (tester) async {
    await zeigePanel(tester, _zustand());
    await tester.tap(find.text('Hexenspeichel'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('heilung-zfw'), '10');
    await tester.enterText(_key('heilung-asp'), '7');
    await tester.pumpAndSettle();

    expect(find.textContaining('Rundung'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('heilung-uebernehmen')).onPressed,
      isNull,
    );

    await tester.tap(find.text('Krankheit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LeP 10 → 17'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('heilung-uebernehmen')).onPressed,
      isNotNull,
    );
  });

  testWidgets('ohne eingetragene Wunden meldet die Wundheilung das', (
    tester,
  ) async {
    await zeigePanel(tester, _zustand());
    await tester.tap(_key('heilung-wundheilung'));
    await tester.pumpAndSettle();

    expect(_key('heilung-keine-wunden'), findsOneWidget);
  });

  testWidgets(
    'Lach dich gesund: nur ZfP*, kein Selbstzauber, Buchung ohne AsP',
    (tester) async {
      final repo = await zeigePanel(tester, _zustand(lep: 2));
      await tester.tap(find.text('Lach dich gesund'));
      await tester.pumpAndSettle();

      expect(_key('heilung-selbst'), findsNothing);
      expect(_key('heilung-asp'), findsNothing);
      await tester.enterText(_key('heilung-zfp'), '6');
      await tester.pumpAndSettle();
      expect(find.textContaining('LeP 2 → 8'), findsOneWidget);

      await tester.tap(_key('heilung-uebernehmen'));
      await tester.pumpAndSettle();

      final z = (await repo.loadHeroState('demo'))!;
      expect(z.currentLep, 8);
      expect(z.currentAsp, 20);
      expect(z.diceLog.single.subtitle, contains('ZfP* 6'));
    },
  );
}
