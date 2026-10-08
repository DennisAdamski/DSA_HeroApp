import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/begleiter_zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_belastung_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/resource_stepper_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

// Snapshot-Schreibwege des Laufzeitzustands (ARCH-05, Befund 1 im
// Schreibpfad-Inventar): Jede Bedienung muss auf dem gespeicherten Stand
// arbeiten. Ein anderer Schreibweg speichert nach dem Aufbau der Oberfläche
// (`_Repository.fremdeAenderung`); seine Felder müssen danach noch stehen.

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

/// Stand, den die Oberfläche beim Aufbau sieht.
const _angezeigt = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 18,
);

const _leererKatalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

/// Wurf, den ein anderer Schreibweg nach dem Aufbau protokolliert hat.
final _fremderWurf = _wurf('Fremder Wurf');

DiceLogEntry _wurf(String titel) => DiceLogEntry(
  timestamp: DateTime.utc(2026, 9, 29),
  type: ProbeType.attribute,
  title: titel,
  subtitle: 'MU 12',
  success: true,
  diceValues: const <int>[3],
);

/// Die Zwischenänderung: ein Wurf, KaP und eine Bauchwunde.
HeroState _fremd(HeroState zustand) => zustand
    .copyWith(
      currentKap: 9,
      wpiZustand: zustand.wpiZustand.mitWundeHinzu(WundZone.bauch),
    )
    .withAppendedDiceLogEntries(<DiceLogEntry>[_fremderWurf]);

/// Prüft, dass die Zwischenänderung nicht überschrieben wurde.
void _expectFremdesErhalten(HeroState gespeichert, {int bauchwunden = 1}) {
  expect(gespeichert.currentKap, 9);
  expect(gespeichert.wpiZustand.wundenInZone(WundZone.bauch), bauchwunden);
  expect(
    gespeichert.diceLog.map((eintrag) => eintrag.title),
    contains('Fremder Wurf'),
  );
}

void main() {
  /// Baut [kind] mit dem Test-Repository auf.
  Future<void> zeige(WidgetTester tester, _Repository repo, Widget kind) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
        ],
        child: MaterialApp(home: Scaffold(body: kind)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Knopf, der beim Tippen [aktion] mit Kontext und Ref ausführt.
  Widget knopf(void Function(BuildContext context, WidgetRef ref) aktion) {
    return Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () => aktion(context, ref),
        child: const Text('los'),
      ),
    );
  }

  group('Würfelprotokoll', () {
    testWidgets('zwei nicht abgewartete Würfe bleiben beide erhalten', (
      tester,
    ) async {
      final repo = _Repository();
      await zeige(
        tester,
        repo,
        knopf((context, ref) {
          unawaited(
            persistDiceLogEntry(ref: ref, heroId: 'demo', entry: _wurf('A')),
          );
          unawaited(
            persistDiceLogEntry(ref: ref, heroId: 'demo', entry: _wurf('B')),
          );
        }),
      );
      repo.fremdeAenderung = _fremd;

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      final gespeichert = (await repo.loadHeroState('demo'))!;
      expect(gespeichert.diceLog.map((eintrag) => eintrag.title), [
        'Fremder Wurf',
        'A',
        'B',
      ]);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('ein Speicherfehler erscheint als Snackbar', (tester) async {
      final repo = _Repository()..schreibFehler = true;
      await zeige(
        tester,
        repo,
        knopf((context, ref) {
          showLoggedProbeDialog(
            context: context,
            ref: ref,
            heroId: 'demo',
            request: const ResolvedProbeRequest(
              type: ProbeType.attribute,
              title: 'Eigenschaftsprobe: Mut',
              subtitle: 'MU',
              ruleHint: 'rule',
              diceSpec: DiceSpec(count: 1, sides: 20),
              targets: <ProbeTargetValue>[
                ProbeTargetValue(label: 'MU', value: 14),
              ],
            ),
          );
        }),
      );

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Würfeln').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Würfelprotokoll nicht gespeichert'),
        findsOneWidget,
      );
    });
  });

  group('Ressourcen-Stepper', () {
    Widget stepperKnopf() => knopf(
      (context, ref) => showResourceStepperDialog(
        context: context,
        heroId: 'demo',
        resource: ResourceType.lep,
      ),
    );

    testWidgets('ersetzt nur LeP im gespeicherten Zustand', (tester) async {
      final repo = _Repository();
      await zeige(tester, repo, stepperKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      repo.fremdeAenderung = _fremd;

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      final gespeichert = (await repo.loadHeroState('demo'))!;
      expect(gespeichert.currentLep, 19);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('fünf schnelle Klicks zählen alle', (tester) async {
      final repo = _Repository();
      await zeige(tester, repo, stepperKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      // Alle Klicks, bevor die Anzeige den ersten Stand zeigt.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.remove));
      }
      await tester.pumpAndSettle();

      expect((await repo.loadHeroState('demo'))!.currentLep, 15);
    });

    testWidgets('ein Speicherfehler erscheint im Blatt und verschwindet '
        'nach dem nächsten Erfolg', (tester) async {
      final repo = _Repository();
      await zeige(tester, repo, stepperKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      repo.schreibFehler = true;

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      final meldung = find.byKey(kZustandFehlerSchluessel);
      expect(
        find.descendant(of: find.byType(Dialog), matching: meldung),
        findsOneWidget,
      );
      expect(find.textContaining('LeP nicht gespeichert'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect((await repo.loadHeroState('demo'))!.currentLep, 20);

      repo.schreibFehler = false;
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(meldung, findsNothing);
      expect((await repo.loadHeroState('demo'))!.currentLep, 19);
    });
  });

  group('Ressourcenblatt (UI2)', () {
    Widget blattKnopf() => knopf(
      (context, ref) => zeigeRessourcenBlatt(
        context: context,
        heroId: 'demo',
        ressource: KartoRessource.lebensenergie,
      ),
    );

    testWidgets('schnelle Klicks zählen alle, auch unter 0', (tester) async {
      final repo = _Repository(zustand: _angezeigt.copyWith(currentLep: 2));
      await zeige(tester, repo, blattKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      repo.fremdeAenderung = _fremd;

      final minusFuenf = find.byKey(const ValueKey('vital-block-minus-5'));
      await tester.tap(minusFuenf);
      await tester.tap(minusFuenf);
      await tester.tap(minusFuenf);
      await tester.pumpAndSettle();

      final gespeichert = (await repo.loadHeroState('demo'))!;
      // 2 − 15 endet an der Untergrenze −10.
      expect(gespeichert.currentLep, kVitalFloor);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('ein Speicherfehler erscheint im Blatt', (tester) async {
      final repo = _Repository()..schreibFehler = true;
      await zeige(tester, repo, blattKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('vital-block-minus-1')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byKey(kZustandFehlerSchluessel),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('Belastung zählt vom gespeicherten Wert, auch zweimal schnell', (
    tester,
  ) async {
    final repo = _Repository();
    await zeige(
      tester,
      repo,
      const InspectorBelastungSection(heroId: 'demo', heroState: _angezeigt),
    );
    await tester.tap(find.text('Belastung'));
    await tester.pumpAndSettle();
    repo.fremdeAenderung = _fremd;

    // Beide Klicks, bevor die Oberfläche den ersten Stand sieht.
    await tester.tap(find.byTooltip('Erschöpfung erhöhen'));
    await tester.tap(find.byTooltip('Erschöpfung erhöhen'));
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    expect(gespeichert.erschoepfung, 2);
    _expectFremdesErhalten(gespeichert);
  });

  group('Zaubereffekte', () {
    Widget dialogKnopf() => knopf(
      (context, ref) =>
          showActiveSpellEffectsDialog(context: context, heroId: 'demo'),
    );

    testWidgets('Umschalten erhält Zwischenänderungen', (tester) async {
      final repo = _Repository();
      await zeige(tester, repo, dialogKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      repo.fremdeAenderung = _fremd;

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'active-spell-toggle-$activeSpellEffectAxxeleratus',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gespeichert = (await repo.loadHeroState('demo'))!;
      expect(
        gespeichert.activeSpellEffects.isActive(activeSpellEffectAxxeleratus),
        isTrue,
      );
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('Herunterzählen geht von der gespeicherten Restdauer aus', (
      tester,
    ) async {
      final effekte = const ActiveSpellEffectsState()
          .withToggled(activeSpellEffectArmatrutz, true)
          .withDetail(
            activeSpellEffectArmatrutz,
            ActiveSpellEffectDetail(
              amount: 3,
              duration: SpellDuration(
                amount: 4,
                unit: SpellDurationUnit.kampfrunden,
              ),
            ),
          );
      final repo = _Repository(
        zustand: _angezeigt.copyWith(activeSpellEffects: effekte),
      );
      await zeige(tester, repo, dialogKnopf());
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      final zaehlen = find.byKey(
        const ValueKey<String>(
          'active-spell-duration-advance-$activeSpellEffectArmatrutz',
        ),
      );

      // Ein anderer Schreibweg hat seit dem Öffnen schon einmal gezählt.
      repo.fremdeAenderung = (zustand) => zaehleZaubereffektDauer(
        zustand,
        activeSpellEffectArmatrutz,
        zuruecksetzen: false,
      );

      await tester.tap(zaehlen);
      await tester.pumpAndSettle();

      final gespeichert = (await repo.loadHeroState('demo'))!;
      final detail = gespeichert.activeSpellEffects.detailFor(
        activeSpellEffectArmatrutz,
      );
      expect(detail.duration?.remaining, 2);
      expect(detail.amount, 3);
    });
  });

  testWidgets('Zaubereffekt: ein Speicherfehler erscheint im Dialog', (
    tester,
  ) async {
    final repo = _Repository()..schreibFehler = true;
    await zeige(
      tester,
      repo,
      knopf(
        (context, ref) =>
            showActiveSpellEffectsDialog(context: context, heroId: 'demo'),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'active-spell-toggle-$activeSpellEffectAxxeleratus',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(kZustandFehlerSchluessel),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Zaubereffekt nicht gespeichert'),
      findsOneWidget,
    );
  });

  testWidgets('Wunde hinzufügen zählt vom gespeicherten Wundzustand', (
    tester,
  ) async {
    final repo = _Repository();
    await zeige(
      tester,
      repo,
      knopf(
        (context, ref) =>
            showWundenDetailDialog(context: context, heroId: 'demo'),
      ),
    );
    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();
    repo.fremdeAenderung = _fremd;

    // Reihenfolge der Zonen wie `WundZone.values`: Bauch ist die dritte.
    await tester.tap(find.byTooltip('Wunde hinzufügen').at(2));
    await tester.pumpAndSettle();
    expect(find.text('Wunde unterdrücken?'), findsOneWidget);
    await tester.tap(find.text('Nein'));
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!;
    _expectFremdesErhalten(gespeichert, bauchwunden: 2);
    expect(gespeichert.currentLep, 20);
  });

  group('Begleiter-Ressourcen (V2)', () {
    const mira = HeroCompanion(
      id: 'mira',
      maxLep: 20,
      maxAsp: 10,
      maxAup: 30,
      startLep: 20,
      startAsp: 10,
      startAup: 30,
    );

    Widget begleiterKnopf(int schritt, {int klicks = 1}) =>
        knopf((context, ref) {
          for (var i = 0; i < klicks; i++) {
            unawaited(
              aendereBegleiterPool(
                context: context,
                ref: ref,
                heroId: 'demo',
                begleiter: mira,
                pool: BegleiterPool.lep,
                aenderung: begleiterPoolSchritt(BegleiterPool.lep, 20, schritt),
              ),
            );
          }
        });

    testWidgets('ersetzt nur den Wert des Begleiters, Fremdes bleibt', (
      tester,
    ) async {
      final repo = _Repository();
      await zeige(tester, repo, begleiterKnopf(-5));
      repo.fremdeAenderung = (z) => _fremd(z)
          .withBegleiterZustand('rondo', const BegleiterZustand(currentLep: 2))
          .withBegleiterZustand('mira', const BegleiterZustand(currentAsp: 4));

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      final gespeichert = (await repo.loadHeroState('demo'))!;
      expect(gespeichert.begleiterZustaende['mira']!.currentLep, 15);
      expect(gespeichert.begleiterZustaende['mira']!.currentAsp, 4);
      expect(gespeichert.begleiterZustaende['rondo']!.currentLep, 2);
      _expectFremdesErhalten(gespeichert);
      expect(gespeichert.currentLep, 20, reason: 'der Held bleibt unberührt');
    });

    testWidgets('fünf schnelle Klicks zählen alle', (tester) async {
      final repo = _Repository();
      await zeige(tester, repo, begleiterKnopf(-1, klicks: 5));

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      expect(
        (await repo.loadHeroState('demo'))!
            .begleiterZustaende['mira']!
            .currentLep,
        15,
      );
    });

    testWidgets('ein Speicherfehler erscheint und der Wert bleibt', (
      tester,
    ) async {
      final repo = _Repository()..schreibFehler = true;
      await zeige(tester, repo, begleiterKnopf(-1));

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      expect(find.textContaining('LeP nicht gespeichert'), findsOneWidget);
      expect((await repo.loadHeroState('demo'))!.begleiterZustaende, isEmpty);

      repo.schreibFehler = false;
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();

      expect(
        (await repo.loadHeroState('demo'))!
            .begleiterZustaende['mira']!
            .currentLep,
        19,
      );
    });
  });
}

/// Test-Repository mit Zwischenänderung und schaltbarem Schreibfehler.
class _Repository extends FakeRepository {
  _Repository({HeroState zustand = _angezeigt})
    : super(
        heroes: <HeroSheet>[_held],
        states: <String, HeroState>{'demo': zustand},
      );

  /// Änderung eines anderen Schreibwegs, die die Oberfläche nicht gesehen
  /// hat: Das nächste Laden liefert sie mit, das nächste Speichern macht sie
  /// dauerhaft.
  HeroState Function(HeroState zustand)? fremdeAenderung;

  /// Lässt jedes Speichern des Zustands scheitern.
  bool schreibFehler = false;

  @override
  Future<HeroState?> loadHeroState(String heroId) async {
    final gespeichert = await super.loadHeroState(heroId);
    final fremd = fremdeAenderung;
    if (gespeichert == null || fremd == null) {
      return gespeichert;
    }
    return fremd(gespeichert);
  }

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    if (schreibFehler) {
      throw StateError('Speicher voll');
    }
    fremdeAenderung = null;
    await super.saveHeroState(heroId, state);
  }
}
