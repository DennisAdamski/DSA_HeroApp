import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fremdwirkung_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirkabschluss.dart';

import '../shell/karto_test_support.dart';

import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_fremdwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_fremdwirkung.dart';

void main() {
  testWidgets(
    'Echte Kostenbuchung: Fehler, Retry, Kosten zuerst und Originalgegner einmal',
    (tester) async {
      final repo = _MagicRepo();
      final c = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      late WidgetRef ref;
      late BuildContext context;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (ctx, r, _) {
                  context = ctx;
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
      final original = evaluateProbe(
        const ResolvedProbeRequest(
          type: ProbeType.spell,
          title: 'Fulminictus',
          subtitle: '',
          ruleHint: '',
          diceSpec: DiceSpec(count: 3, sides: 20),
          basePool: 5,
          targets: [
            ProbeTargetValue(label: 'IN', value: 14),
            ProbeTargetValue(label: 'GE', value: 14),
            ProbeTargetValue(label: 'KO', value: 14),
          ],
        ),
        const ProbeRollInput(
          mode: ProbeRollMode.manual,
          diceValues: [10, 10, 10],
          situationalModifier: 0,
          specializationApplied: false,
        ),
      );
      const ziel = GefechtsFremdwirkung(
        zauberId: 'spell_fulminictus_donnerkeil',
        gegnerId: 'a',
        verfuegbareAsp: 20,
      );
      final wurf = gefechtsFulminictusWurf(
        ziel: ziel,
        probe: original,
        ersterW6: 3,
        zweiterW6: 4,
      );
      final ctl = c.read(gefechtProvider('rondra').notifier)..beginnen(6);
      ctl.setzen(
        c
            .read(gefechtProvider('rondra'))!
            .copyWith(
              handlung: Gefechtshandlung(
                titel: 'Fulminictus',
                verbleibend: 0,
                art: Gefechtshandlungsart.zauber,
                ergebnis: original,
                wirkungId: 'frozen',
                fremdwirkungswurf: wurf,
                wirken: GefechtsWirkprofil(
                  probe: original.request,
                  dauer: 2,
                  kosten: 0,
                  karmal: false,
                  fremdwirkung: ziel,
                ),
              ),
            ),
      );
      final foes = c.read(gefechtBegegnungProvider.notifier);
      foes.speichern(
        const Gefechtsgegner(id: 'a', name: 'A', lep: 30, rs: 99, ini: 12),
      );
      foes.speichern(
        const Gefechtsgegner(id: 'b', name: 'B', lep: 40, rs: 0, ini: 10),
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
        c.read(gefechtProvider('rondra'))!.handlung!.ergebnis,
        same(original),
      );
      expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 30);
      repo.fehler = false;
      await repo.saveHeroState(
        'rondra',
        (await repo.loadHeroState('rondra'))!
            .copyWith(currentAsp: 18, currentLep: 13),
      );
      expect(
        await uebernimmGefechtsWirkfolgen(
          context: context,
          ref: ref,
          heroId: 'rondra',
          abschliessen: false,
        ),
        true,
      );
      expect((await repo.loadHeroState('rondra'))!.currentAsp, 6);
      expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 30);
      foes.speichern(
        const Gefechtsgegner(id: 'a', name: 'A', lep: 25, rs: 100, ini: 12),
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
      expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 13);
      expect(c.read(gefechtBegegnungProvider).gegner['b']!.lep, 40);
      expect((await repo.loadHeroState('rondra'))!.currentAsp, 6);
      expect((await repo.loadHeroState('rondra'))!.currentLep, 13);
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Fremdziel verlangt konkrete Reichweite und Schutzprüfung', (
    tester,
  ) async {
    const g = Gefechtsgegner(id: 'a', name: 'Ork', lep: 30, rs: 4, ini: 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => zeigeGefechtsFremdziel(
                context: context,
                zauberId: 'spell_fulminictus_donnerkeil',
                gegner: const [g],
                verfuegbareAsp: 40,
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Ziel festhalten');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.text('Lebendes Einzelwesen in höchstens 7 Schritt'));
    await tester.tap(find.text('Kein magischer Schutz oder besondere Abwehr'));
    await tester.tap(
      find.text('Grundform ohne Varianten und Sonderfertigkeiten'),
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Fulminictus · Fremdziel'), findsNothing);
  });
  testWidgets('Schadenswurf bindet das Ergebnis und die Energie vom Start', (
    tester,
  ) async {
    final original = evaluateProbe(
      const ResolvedProbeRequest(
        type: ProbeType.spell,
        title: 'Fulminictus',
        subtitle: '',
        ruleHint: '',
        diceSpec: DiceSpec(count: 3, sides: 20),
        basePool: 5,
        targets: [
          ProbeTargetValue(label: 'IN', value: 14),
          ProbeTargetValue(label: 'GE', value: 14),
          ProbeTargetValue(label: 'KO', value: 14),
        ],
      ),
      const ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: [10, 10, 10],
        situationalModifier: 0,
        specializationApplied: false,
      ),
    );
    GefechtsFremdwirkungswurf? ergebnis;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                ergebnis = await zeigeGefechtsFremdwirkungswurf(
                  context: context,
                  ziel: const GefechtsFremdwirkung(
                    zauberId: 'spell_fulminictus_donnerkeil',
                    gegnerId: 'ursprünglich',
                    verfuegbareAsp: 7,
                  ),
                  probe: original,
                );
              },
              child: const Text('Schaden'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Schaden'));
    await tester.pumpAndSettle();
    final speichern = find.widgetWithText(
      FilledButton,
      'Schadenswurf festhalten',
    );
    expect(tester.widget<FilledButton>(speichern).onPressed, isNull);
    final dice = find.byType(DropdownButtonFormField<int>);
    await tester.tap(dice.at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6').last);
    await tester.pumpAndSettle();
    await tester.tap(dice.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6').last);
    await tester.pumpAndSettle();
    expect(
      find.text('7 direkte SP · 7 AsP. Auf die Startenergie begrenzt.'),
      findsOneWidget,
    );
    await tester.tap(speichern);
    await tester.pumpAndSettle();
    expect(ergebnis!.probe, same(original));
    expect(ergebnis!.ziel.gegnerId, 'ursprünglich');
    expect(ergebnis!.kosten, 7);
  });
}

class _MagicRepo extends FakeRepository {
  _MagicRepo()
    : super(
        heroes: [testHero()],
        states: {
          'rondra': const HeroState(
            currentLep: 20,
            currentAsp: 20,
            currentKap: 15,
            currentAu: 30,
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
