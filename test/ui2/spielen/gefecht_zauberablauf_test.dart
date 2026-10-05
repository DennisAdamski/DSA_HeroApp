import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirkabschluss.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_unterbrechung.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

const _probe = ResolvedProbeRequest(
  type: ProbeType.spell,
  title: 'Testzauber',
  subtitle: '',
  ruleHint: '',
  diceSpec: DiceSpec(count: 3, sides: 20),
  basePool: 8,
  targets: [
    ProbeTargetValue(label: 'MU', value: 14),
    ProbeTargetValue(label: 'KL', value: 12),
    ProbeTargetValue(label: 'IN', value: 13),
  ],
);

class _Repo extends FakeRepository {
  _Repo()
    : super(
        heroes: [testHero()],
        states: {
          'rondra': const HeroState(
            currentLep: 20,
            currentAsp: 20,
            currentKap: 15,
            currentAu: 30,
            unbekannteFelder: {'future': 42},
          ),
        },
      );
  bool fehler = false;
  @override
  Future<void> saveHeroState(String id, HeroState s) async {
    if (fehler) throw StateError('Speicherfehler');
    await super.saveHeroState(id, s);
  }
}

void main() {
  testWidgets('Liturgie-Endprobe: Abbruch klärt Kosten ohne erfundenen Wurf', (
    tester,
  ) async {
    final repo = _Repo();
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    late WidgetRef ref;
    late BuildContext context;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (c, r, _) {
                context = c;
                ref = r;
                r.watch(heroComputedProvider('rondra'));
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(gefechtProvider('rondra').notifier).beginnen(6);
    final bestand = GefechtsTestBestand();
    await starteGefechtsWirken(
      context: context,
      ref: ref,
      heroId: 'rondra',
      bestand: bestand,
      art: Gefechtshandlungsart.liturgie,
      profil: const GefechtsWirkprofil(
        probe: _probe,
        dauer: 3,
        kosten: 10,
        karmal: true,
        endprobe: true,
      ),
    );
    final abbruch = brecheGefechtsHandlungAb(
      context: context,
      ref: ref,
      heroId: 'rondra',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbruch bestätigen'));
    await tester.pumpAndSettle();
    expect(find.text('Bestätigte Unterbrechungskosten (KaP)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text('Unterbrechungsfolgen am Spieltisch geklärt'));
    await tester.pump();
    await tester.tap(find.text('Manuellen Abschluss vorbereiten'));
    await tester.pumpAndSettle();
    expect(bestand.anfragen, isEmpty);
    expect(
      container.read(gefechtProvider('rondra'))!.handlung!.ergebnis,
      isNull,
    );
    // Ohne permanente Kosten genügt der Abschlussknopf als Bestätigung.
    expect(find.text('Weitere Folgen am Spieltisch bestätigt'), findsNothing);
    await tester.tap(find.text('Kosten und Folgen übernehmen'));
    await tester.pumpAndSettle();
    await abbruch;
    expect((await repo.loadHeroState('rondra'))!.currentKap, 12);
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.handlung, isNull);
    expect(s.karmaleFehlversuche, isEmpty);
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 1);
    expect(tester.takeException(), isNull);
  });
  for (final abbruch in [false, true]) {
    testWidgets('Startprobe genau einmal; Abbruch vor Ergebnis=$abbruch', (
      tester,
    ) async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (c, r, _) {
                  context = c;
                  ref = r;
                  r.watch(heroComputedProvider('rondra'));
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ctl = container.read(gefechtProvider('rondra').notifier);
      ctl.beginnen(6);
      ctl.setzen(
        container
            .read(gefechtProvider('rondra'))!
            .copyWith(mirakelbonus: const GefechtsProbenbonus('IN', 3)),
      );
      final bestand = GefechtsTestBestand()
        ..doppelt = true
        ..abbrechen = abbruch;
      await starteGefechtsWirken(
        context: context,
        ref: ref,
        heroId: 'rondra',
        bestand: bestand,
        art: Gefechtshandlungsart.zauber,
        profil: const GefechtsWirkprofil(
          probe: _probe,
          dauer: 5,
          kosten: 5,
          karmal: false,
        ),
      );
      expect(bestand.anfragen.length, 1);
      expect(bestand.anfragen.single.targets.last.value, 16);
      expect(
        container.read(gefechtProvider('rondra'))!.mirakelbonus == null,
        !abbruch,
      );
      if (abbruch) {
        expect(container.read(gefechtProvider('rondra'))!.handlung, isNull);
        expect(
          container.read(gefechtProvider('rondra'))!.angriffeVerbraucht,
          0,
        );
      } else {
        final original = container
            .read(gefechtProvider('rondra'))!
            .handlung!
            .ergebnis;
        expect(original, isNotNull);
        expect(
          container.read(gefechtProvider('rondra'))!.handlung!.verbleibend,
          4,
        );
        await setzeGefechtsWirkenFort(
          context: context,
          ref: ref,
          heroId: 'rondra',
          bestand: bestand,
        );
        ctl.setzen(
          naechsteGefechtsrunde(container.read(gefechtProvider('rondra'))!),
        );
        await setzeGefechtsWirkenFort(
          context: context,
          ref: ref,
          heroId: 'rondra',
          bestand: bestand,
        );
        expect(bestand.anfragen.length, 1);
        expect(
          container.read(gefechtProvider('rondra'))!.handlung!.ergebnis,
          same(original),
        );
      }
      expect(container.read(gefechtProvider('rondra'))!.auftrag, isNull);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Gescheiterter Zauber endet nach halber Dauer ohne zweite Probe',
    (tester) async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (c, r, _) {
                  context = c;
                  ref = r;
                  r.watch(heroComputedProvider('rondra'));
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container.read(gefechtProvider('rondra').notifier).beginnen(6);
      final bestand = GefechtsTestBestand()
        ..w20Wert = 19
        ..doppelt = true;
      await starteGefechtsWirken(
        context: context,
        ref: ref,
        heroId: 'rondra',
        bestand: bestand,
        art: Gefechtshandlungsart.zauber,
        profil: const GefechtsWirkprofil(
          probe: _probe,
          dauer: 5,
          kosten: 5,
          karmal: false,
        ),
      );
      final h = container.read(gefechtProvider('rondra'))!.handlung!;
      expect(h.verbleibend, 2);
      expect(h.ergebnis!.success, false);
      expect(bestand.anfragen.length, 1);
    },
  );
  testWidgets(
    'Übernahme retry, frische Änderung, keine doppelte Kostenbuchung',
    (tester) async {
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(container.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (c, r, _) {
                  context = c;
                  ref = r;
                  r.watch(heroComputedProvider('rondra'));
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ctl = container.read(gefechtProvider('rondra').notifier);
      ctl.beginnen(6);
      final ergebnis = evaluateProbe(
        _probe,
        const ProbeRollInput(
          mode: ProbeRollMode.manual,
          diceValues: [10, 10, 10],
          situationalModifier: 0,
          specializationApplied: false,
        ),
      );
      ctl.setzen(
        container
            .read(gefechtProvider('rondra'))!
            .copyWith(
              handlung: Gefechtshandlung(
                titel: 'Testzauber',
                verbleibend: 0,
                art: Gefechtshandlungsart.zauber,
                ergebnis: ergebnis,
                wirken: const GefechtsWirkprofil(
                  probe: _probe,
                  dauer: 1,
                  kosten: 5,
                  karmal: false,
                ),
              ),
            ),
      );
      repo.fehler = true;
      expect(
        await uebernimmGefechtsWirkfolgen(
          context: context,
          ref: ref,
          heroId: 'rondra',
        ),
        false,
      );
      expect(
        container.read(gefechtProvider('rondra'))!.handlung!.ergebnis,
        same(ergebnis),
      );
      repo.fehler = false;
      final fremd = (await repo.loadHeroState('rondra'))!
          .copyWith(currentLep: 13, currentAsp: 18);
      await repo.saveHeroState('rondra', fremd);
      expect(
        await uebernimmGefechtsWirkfolgen(
          context: context,
          ref: ref,
          heroId: 'rondra',
          abschliessen: false,
        ),
        true,
      );
      expect((await repo.loadHeroState('rondra'))!.currentAsp, 13);
      expect(
        container.read(gefechtProvider('rondra'))!.handlung!.kostenUebernommen,
        true,
      );
      expect(
        await uebernimmGefechtsWirkfolgen(
          context: context,
          ref: ref,
          heroId: 'rondra',
        ),
        true,
      );
      expect(
        await uebernimmGefechtsWirkfolgen(
          context: context,
          ref: ref,
          heroId: 'rondra',
        ),
        false,
      );
      final neu = (await repo.loadHeroState('rondra'))!;
      expect(neu.currentAsp, 13);
      expect(neu.currentLep, 13);
      expect(neu.unbekannteFelder['future'], 42);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
