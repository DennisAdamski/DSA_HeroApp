import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rest_dialog.dart';

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
  currentLep: 5,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 2,
  erschoepfung: 3,
  wpiZustand: WundZustand(wundenProZone: <WundZone, int>{WundZone.kopf: 1}),
);

const _leererKatalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

final _apply = find.byKey(const ValueKey<String>('rest-dialog-apply'));
final _fullRestore = find.byKey(
  const ValueKey<String>('rest-dialog-full-restore'),
);
final _fehler = find.byKey(const ValueKey<String>('rest-dialog-save-error'));

void main() {
  late int angewendet;

  /// Zeigt das Rast-Panel eingebettet und liefert den Provider-Container.
  Future<ProviderContainer> zeigePanel(
    WidgetTester tester,
    FakeRepository repo,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    angewendet = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RestPanel(heroId: 'demo', onApplied: () => angewendet++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RestPanel)));
  }

  /// Wählt „Nur ausruhen“ und trägt Ausdauerwurf und KO-Probe von Hand ein.
  Future<void> ausruhenEintragen(WidgetTester tester) async {
    await tester.tap(find.text('Nur ausruhen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell').at(0));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('rest-au-roll-manual')),
      '9',
    );
    await tester.tap(find.text('Manuell').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('rest-au-ko-manual')),
      '1',
    );
    await tester.pump();
  }

  testWidgets('Übernehmen schreibt Rastwerte und Protokoll', (tester) async {
    final repo = FakeRepository(heroes: [_held], states: {'demo': _zustand});
    final container = await zeigePanel(tester, repo);
    final maxAu = container
        .read(heroComputedProvider('demo'))
        .valueOrNull!
        .derivedStats
        .maxAu;

    await ausruhenEintragen(tester);
    await tester.tap(_apply);
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.currentAu, (2 + 15).clamp(0, maxAu));
    expect(gespeichert.currentLep, 5);
    expect(gespeichert.erschoepfung, 3);
    expect(gespeichert.wpiZustand.wundenInZone(WundZone.kopf), 1);
    expect(gespeichert.diceLog.map((eintrag) => eintrag.subtitle), [
      '3W6 manuell',
      'Zielwert 12, manuell',
    ]);
    expect(angewendet, 1);
    expect(_fehler, findsNothing);
  });

  testWidgets('ein Speicherfehler erscheint im Panel', (tester) async {
    final repo = _Repository(fehler: true);
    await zeigePanel(tester, repo);

    await ausruhenEintragen(tester);
    await tester.tap(_apply);
    await tester.pumpAndSettle();

    expect(_fehler, findsOneWidget);
    expect(
      find.text('Rast konnte nicht gespeichert werden: Schreibfehler'),
      findsOneWidget,
    );
    expect(angewendet, 0);
    expect(tester.widget<FilledButton>(_apply).onPressed, isNotNull);
  });

  testWidgets('während des Speicherns sind beide Aktionen gesperrt', (
    tester,
  ) async {
    final repo = _Repository(sperre: Completer<void>());
    await zeigePanel(tester, repo);

    await ausruhenEintragen(tester);
    await tester.tap(_apply);
    await tester.pump();

    expect(tester.widget<FilledButton>(_apply).onPressed, isNull);
    expect(tester.widget<IconButton>(_fullRestore).onPressed, isNull);
    await tester.tap(_apply, warnIfMissed: false);
    await tester.pump();
    expect(repo.schreibversuche, 1);

    repo.sperre!.complete();
    await tester.pumpAndSettle();
    expect(repo.schreibversuche, 1);
    expect(angewendet, 1);
    expect(tester.widget<FilledButton>(_apply).onPressed, isNotNull);
  });

  testWidgets('Fullrestore setzt Maxima nach Bestätigung', (tester) async {
    final repo = _Repository();
    final container = await zeigePanel(tester, repo);
    final werte = container
        .read(heroComputedProvider('demo'))
        .valueOrNull!
        .derivedStats;

    await tester.tap(_fullRestore);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repo.schreibversuche, 0);

    await tester.tap(_fullRestore);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anwenden'));
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(repo.schreibversuche, 1);
    expect(gespeichert.currentLep, werte.maxLep);
    expect(gespeichert.currentAu, werte.maxAu);
    expect(gespeichert.erschoepfung, 0);
    expect(gespeichert.wpiZustand.gesamtWunden, 0);
    expect(angewendet, 1);
  });

  testWidgets('ein Fehler beim Fullrestore erscheint im Panel', (tester) async {
    final repo = _Repository(fehler: true);
    await zeigePanel(tester, repo);

    await tester.tap(_fullRestore);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anwenden'));
    await tester.pumpAndSettle();

    expect(_fehler, findsOneWidget);
    expect(angewendet, 0);
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
