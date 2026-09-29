import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_dialog.dart';

// KO 12: Wundschwellen 6 / 12 / 18 / 24.
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

const _zustand = HeroState(
  currentLep: 30,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
);

const _leererKatalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

final _uebernehmen = _key('schaden-uebernehmen');

/// Würfel mit fest vorgegebener Folge.
class _FesteWuerfel implements DiceRoller {
  _FesteWuerfel(this._werte);

  final List<int> _werte;

  @override
  int rollDie(int sides) => _werte.removeAt(0);
}

void main() {
  late List<SchadenDialogErgebnis> uebernommen;

  Future<ProviderContainer> zeigePanel(
    WidgetTester tester,
    FakeRepository repo, {
    List<int> wuerfe = const <int>[],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    uebernommen = <SchadenDialogErgebnis>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchadenPanel(
                heroId: 'demo',
                wuerfler: _FesteWuerfel(List<int>.of(wuerfe)),
                onUebernommen: uebernommen.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SchadenPanel)));
  }

  Future<void> waehleZone(WidgetTester tester, String label) async {
    await tester.tap(_key('schaden-zone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('RS ist aus den Kampfwerten vorbelegt', (tester) async {
    final container = await zeigePanel(
      tester,
      FakeRepository(heroes: [_held], states: {'demo': _zustand}),
    );
    final rs = container
        .read(heroComputedProvider('demo'))
        .valueOrNull!
        .combatPreviewStats
        .rsTotal;

    expect(
      tester.widget<TextField>(_key('schaden-rs')).controller!.text,
      '$rs',
    );
    expect(tester.widget<FilledButton>(_uebernehmen).onPressed, isNull);
  });

  testWidgets('Vorschlag, W20-Zone und Zusatzwurf werden zusammen gebucht', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});
    // W20 16 → Brust, danach 2W6 Extraschaden 3 + 4.
    await zeigePanel(tester, repo, wuerfe: [16, 3, 4]);

    await tester.enterText(_key('schaden-tp'), '14');
    await tester.enterText(_key('schaden-rs'), '0');
    await tester.pump();
    expect(find.text('14 SP'), findsOneWidget);
    expect(
      find.text('Schwellen 6 / 12 / 18 / 24 · 14 SP → Vorschlag: 2 Wunden'),
      findsOneWidget,
    );
    expect(_key('schaden-zone-fehlt'), findsOneWidget);
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '0');

    await tester.tap(_key('schaden-w20-wuerfeln'));
    await tester.pumpAndSettle();
    expect(find.text('Brust'), findsOneWidget);
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '2');
    expect(find.text('Extraschaden (2W6)'), findsOneWidget);
    // Ohne Zusatzwurf ist die Buchung unvollständig.
    expect(tester.widget<FilledButton>(_uebernehmen).onPressed, isNull);

    await tester.tap(_key('schaden-zusatz-0-wuerfeln'));
    await tester.pump();
    expect(find.text('LeP 30 → 9'), findsOneWidget);

    await tester.tap(_uebernehmen);
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.currentLep, 9);
    expect(gespeichert.wpiZustand.wundenInZone(WundZone.brust), 2);
    expect(gespeichert.diceLog.single.title, schadenProtokollTitel);
    expect(
      gespeichert.diceLog.single.subtitle,
      'TP 14 − RS 0 = 14 SP · Brust · 2 Wunden · +7 SP Zusatz',
    );
    expect(uebernommen.single.zone, WundZone.brust);
    expect(uebernommen.single.anwendung.hinzugefuegteWunden, 2);
  });

  testWidgets('Angriffsmodifikator ändert den Vorschlag, Nutzer entscheidet', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});
    await zeigePanel(tester, repo);

    await tester.enterText(_key('schaden-tp'), '11');
    await tester.enterText(_key('schaden-rs'), '0');
    await waehleZone(tester, 'Linker Arm');
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '1');

    await tester.enterText(_key('schaden-ws-mod'), '-2');
    await tester.pump();
    expect(
      find.text('Schwellen 4 / 10 / 16 / 22 · 11 SP → Vorschlag: 2 Wunden'),
      findsOneWidget,
    );
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '2');

    await tester.tap(_key('schaden-wunden-minus'));
    await tester.pump();
    await tester.tap(_key('schaden-wunden-minus'));
    await tester.pump();
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '0');

    await tester.tap(_uebernehmen);
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.currentLep, 19);
    expect(gespeichert.wpiZustand.gesamtWunden, 0);
    expect(
      gespeichert.diceLog.single.subtitle,
      'TP 11 − RS 0 = 11 SP · Linker Arm · WS −2',
    );
  });

  testWidgets('eine volle Zone begrenzt die Wundzahl sichtbar', (tester) async {
    final repo = FakeRepository(
      heroes: [_held],
      states: {
        'demo': _zustand.copyWith(
          wpiZustand: const WundZustand(
            wundenProZone: <WundZone, int>{WundZone.linkesBein: 2},
          ),
        ),
      },
    );
    await zeigePanel(tester, repo);

    await tester.enterText(_key('schaden-tp'), '30');
    await tester.enterText(_key('schaden-rs'), '0');
    await waehleZone(tester, 'Linkes Bein');

    expect(_key('schaden-zone-voll'), findsOneWidget);
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '1');
    expect(
      tester.widget<IconButton>(_key('schaden-wunden-plus')).onPressed,
      isNull,
    );
  });

  testWidgets('Ausdauerschaden zieht nur AuP ab', (tester) async {
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});
    await zeigePanel(tester, repo);

    await tester.tap(find.text('Ausdauer (TP(A))'));
    await tester.pumpAndSettle();
    expect(_key('schaden-zone'), findsNothing);
    expect(_key('schaden-wunden'), findsNothing);

    await tester.enterText(_key('schaden-tp'), '8');
    await tester.enterText(_key('schaden-rs'), '2');
    await tester.pump();
    expect(find.text('AuP 20 → 14'), findsOneWidget);

    await tester.tap(_uebernehmen);
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.currentAu, 14);
    expect(gespeichert.currentLep, 30);
    expect(gespeichert.diceLog.single.subtitle, 'TP(A) 8 − RS 2 = 6 SP(A)');
  });

  testWidgets('ein Speicherfehler erscheint im Panel', (tester) async {
    await zeigePanel(tester, _Repository(fehler: true));

    await tester.enterText(_key('schaden-tp'), '5');
    await tester.pump();
    await tester.tap(_uebernehmen);
    await tester.pumpAndSettle();

    expect(
      find.text('Schaden konnte nicht gespeichert werden: Schreibfehler'),
      findsOneWidget,
    );
    expect(uebernommen, isEmpty);
    expect(tester.widget<FilledButton>(_uebernehmen).onPressed, isNotNull);
  });

  testWidgets('während des Speicherns ist Übernehmen gesperrt', (tester) async {
    final repo = _Repository(sperre: Completer<void>());
    await zeigePanel(tester, repo);

    await tester.enterText(_key('schaden-tp'), '5');
    await tester.pump();
    await tester.tap(_uebernehmen);
    await tester.pump();

    expect(tester.widget<FilledButton>(_uebernehmen).onPressed, isNull);
    await tester.tap(_uebernehmen, warnIfMissed: false);
    await tester.pump();

    repo.sperre!.complete();
    await tester.pumpAndSettle();
    expect(repo.schreibversuche, 1);
    expect(uebernommen, hasLength(1));
  });

  testWidgets('der Dialog schließt sich und bietet die Unterdrückung an', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showSchadenDialog(
                  context: context,
                  ref: ref,
                  heroId: 'demo',
                ),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    expect(_key('schaden-dialog'), findsOneWidget);

    await tester.enterText(_key('schaden-tp'), '10');
    await tester.enterText(_key('schaden-rs'), '0');
    await waehleZone(tester, 'Linker Arm');
    await tester.tap(_uebernehmen);
    await tester.pumpAndSettle();

    expect(_key('schaden-dialog'), findsNothing);
    expect(find.text('Wunde unterdrücken?'), findsOneWidget);
    await tester.tap(find.text('Nein'));
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.currentLep, 20);
    expect(gespeichert.wpiZustand.wundenInZone(WundZone.linkerArm), 1);
    expect(gespeichert.wpiZustand.unterdrueckteInZone(WundZone.linkerArm), 0);
  });

  testWidgets('alle Wunden eines Angriffs werden gemeinsam unterdrückt', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showSchadenDialog(
                  context: context,
                  ref: ref,
                  heroId: 'demo',
                ),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();

    // 14 SP bei KO 12: Vorschlag 2 Wunden.
    await tester.enterText(_key('schaden-tp'), '14');
    await tester.enterText(_key('schaden-rs'), '0');
    await waehleZone(tester, 'Linker Arm');
    expect(tester.widget<Text>(_key('schaden-wunden')).data, '2');
    await tester.tap(_uebernehmen);
    await tester.pumpAndSettle();

    expect(find.text('2 Wunden unterdrücken?'), findsOneWidget);
    expect(
      find.text(
        'Linker Arm — SB-Probe erschwert um 8 (2 Wunden aus einem Treffer)',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.wpiZustand.wundenInZone(WundZone.linkerArm), 2);
    expect(gespeichert.wpiZustand.unterdrueckteInZone(WundZone.linkerArm), 2);
  });
}

/// Repository mit zählbarem, optional gesperrtem oder scheiterndem
/// Zustandsschreibweg.
class _Repository extends FakeRepository {
  _Repository({this.fehler = false, this.sperre})
    : super(heroes: [_held], states: {'demo': _zustand});

  final bool fehler;
  final Completer<void>? sperre;
  int schreibversuche = 0;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    schreibversuche++;
    if (sperre != null) {
      await sperre!.future;
    }
    if (fehler) {
      throw StateError('Schreibfehler');
    }
    await super.saveHeroState(heroId, state);
  }
}
