import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_klingen.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_klingen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_klingen.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_patzer.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_patzer_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import '../shell/karto_test_support.dart';
import '../../test_support/bogen_test_repository.dart';

void main() {
  for (final parade in [false, true]) {
    testWidgets(
      'Geteilte Probe wendet Meisterparade und Ansagefolgemalus nur zuerst an '
      '(PA=$parade)',
      (tester) async {
        final f = await _start(tester, parade: parade);
        f.container
            .read(gefechtProvider('rondra').notifier)
            .setzen(
              f.zustand.copyWith(meisterparadeBonus: 3, ansageFolgemalus: 5),
            );
        f.adapter.wuerfe.add([1]);
        await tester.tap(find.text('Teilprobe').first);
        await tester.pumpAndSettle();
        expect(
          f.adapter.anfragen.single.initialSituationalModifier,
          parade ? -5 : -2,
        );
        expect(f.zustand.meisterparadeBonus, 0);
        expect(f.zustand.ansageFolgemalus, 0);
        f.adapter.wuerfe.add([1]);
        await tester.tap(find.text('Teilprobe').first);
        await tester.pumpAndSettle();
        expect(
          f.adapter.anfragen.last.initialSituationalModifier,
          parade ? -1 : 0,
        );
      },
    );
  }

  test('Klingenbeginn neutralisiert vorherige DK/Finte; Schild verbietet Klingensturm', () {
    const weapon = MainWeaponSlot(
      id: 'w1',
      name: 'Schwert',
      distanceClass: 'N',
    );
    const aktiv = CombatSpecialRules(
      activeManeuvers: ['man_klingenwand', 'man_klingensturm'],
    );
    const c = CombatConfig(weapons: [weapon], specialRules: aktiv);
    HeroComputedSnapshot snap(CombatConfig config) => buildHeroComputedSnapshot(
      hero: testHero().copyWith(combatConfig: config),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    const wand = ManeuverDef(
      id: 'man_klingenwand',
      name: 'Klingenwand',
      typ: 'Abwehraktion',
    );
    const sturm = ManeuverDef(
      id: 'man_klingensturm',
      name: 'Klingensturm',
      typ: 'Angriffsaktion',
    );
    const wahl = GefechtsKampfmittelwahl(
      GefechtsKampfmittelArt.hauptwaffe,
      'w1',
    );
    final ohneAlt = pruefeGefechtsKlingenbeginn(
      const Gefechtszustand(iniWurf: 6, dk: 'N'),
      snap(c),
      testCatalog,
      wand,
      kampfmittel: wahl,
    );
    final mitAlt = pruefeGefechtsKlingenbeginn(
      const Gefechtszustand(
        iniWurf: 6,
        dk: 'S',
        kontext: Gefechtskontext(finte: 7),
      ),
      snap(c),
      testCatalog,
      wand,
      kampfmittel: wahl,
    );
    expect(mitAlt.zielwert, ohneAlt.zielwert);
    final schild = c.copyWith(
      offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
      offhandEquipment: const [
        OffhandEquipmentEntry(
          id: 's',
          name: 'Schild',
          type: OffhandEquipmentType.shield,
        ),
      ],
    );
    final gesperrt = pruefeGefechtsKlingenbeginn(
      const Gefechtszustand(iniWurf: 6, dk: 'N'),
      snap(schild),
      testCatalog,
      sturm,
      kampfmittel: wahl,
    );
    expect(gesperrt.ausfuehrbar, false);
    expect(gesperrt.sperrgruende.any((g) => g.contains('Schildführung')), true);
  });

  for (final kontrollErfolg in [true, false]) {
    testWidgets(
      'Tatsächlicher Klingensturm-20 besitzt Patzerkontrolle; bestätigt=$kontrollErfolg',
      (tester) async {
        final f = await _start(tester, mitPatzerkarte: true);
        f.adapter.wuerfe.add([20]);
        await tester.tap(find.text('Teilprobe').first);
        await tester.pumpAndSettle();
        final p = f.container.read(gefechtPatzerProvider('rondra')).patzer;
        expect(p, isNotNull);
        expect(p!.original.success, false);
        expect(f.zustand.angriffsergebnisse, isEmpty);
        f.adapter.wuerfe.add([kontrollErfolg ? 1 : 20]);
        await tester.ensureVisible(find.text('Patzer-Kontrollwurf'));
        await tester.tap(find.text('Patzer-Kontrollwurf'));
        await tester.pumpAndSettle();
        expect(f.fehler, isEmpty);
        if (kontrollErfolg) {
          expect(f.zustand.klingen, isNotNull);
          expect(f.zustand.paradenVerbraucht, 0);
        } else {
          expect(f.zustand.klingen, isNull);
          expect(f.zustand.paradenVerbraucht, 2);
          expect(
            f.container.read(gefechtPatzerProvider('rondra')).verloreneRunde,
            1,
          );
        }
      },
    );
  }
  for (final parade in [false, true]) {
    testWidgets(
      'Geteilte ${parade ? "PA" : "AT"}: Abbruch kostenlos, erster Wurf zahlt '
      'einmal, zweiter/Doppelcallback erhalten Budget',
      (tester) async {
        final f = await _start(tester, parade: parade);
        f.adapter.wuerfe.add(null);
        await tester.tap(find.text('Teilprobe').first);
        await tester.pumpAndSettle();
        expect(f.zustand.angriffeVerbraucht, 0);
        expect(f.zustand.paradenVerbraucht, 0);
        expect(f.zustand.klingen!.bezahlt, false);
        f.adapter.wuerfe.add([1]);
        await tester.tap(find.text('Teilprobe').first);
        await tester.pumpAndSettle();
        expect(f.fehler, isEmpty);
        expect(
          parade ? f.zustand.paradenVerbraucht : f.zustand.angriffeVerbraucht,
          1,
        );
        expect(f.zustand.klingen!.bezahlt, true);
        expect(f.zustand.klingen!.teile.first.ergebnis, isNotNull);
        f.adapter.wuerfe.add([1]);
        await tester.tap(find.text('Teilprobe').first);
        await tester.pumpAndSettle();
        expect(f.fehler, isEmpty);
        expect(
          parade ? f.zustand.paradenVerbraucht : f.zustand.angriffeVerbraucht,
          1,
        );
        expect(f.zustand.klingen!.teile.every((t) => t.ergebnis != null), true);
        expect(f.adapter.anfragen.length, 3);
        if (!parade) {
          expect(f.zustand.angriffsergebnisse.length, 2);
          expect(f.zustand.angriffsergebnisse.map((e) => e.gegnerId), [
            'g1',
            'g2',
          ]);
        } else {
          expect(f.adapter.anfragen[1].initialSituationalModifier, -3);
          expect(f.adapter.anfragen[2].initialSituationalModifier, -1);
          expect(f.zustand.angriffsergebnisse, isEmpty);
        }
        await tester.tap(find.text('Ablauf beenden · keine Erstattung'));
        await tester.pumpAndSettle();
        expect(f.zustand.klingen, isNull);
        expect(
          parade ? f.zustand.paradenVerbraucht : f.zustand.angriffeVerbraucht,
          1,
        );
      },
    );
  }

  testWidgets(
    'Aufteilung vor dem ersten Wurf abbrechen erhält beide regulären Marken',
    (tester) async {
      final f = await _start(tester);
      await tester.tap(find.text('Aufteilung abbrechen'));
      await tester.pumpAndSettle();
      expect(f.zustand.klingen, isNull);
      expect(f.zustand.angriffeVerbraucht, 0);
      expect(f.zustand.paradenVerbraucht, 0);
      expect(f.adapter.anfragen, isEmpty);
    },
  );

  testWidgets(
    'Probenadapter mit Ergebnis-Rückgabe ohne Callback bucht einmal',
    (tester) async {
      final f = await _start(tester);
      f.adapter.nurRueckgabe = true;
      f.adapter.wuerfe.add([1]);
      await tester.tap(find.text('Teilprobe').first);
      await tester.pumpAndSettle();
      expect(f.zustand.angriffeVerbraucht, 1);
      expect(f.zustand.klingen!.teile.first.ergebnis, isNotNull);
    },
  );

  testWidgets(
    'Klingensturm bleibt innerhalb derselben Gruppenphase vollständig ausführbar',
    (tester) async {
      final f = await _start(tester, gruppe: true);
      f.adapter.wuerfe.add([1]);
      await tester.tap(find.text('Teilprobe').first);
      await tester.pumpAndSettle();
      f.adapter.wuerfe.add([1]);
      await tester.tap(find.text('Teilprobe').first);
      await tester.pumpAndSettle();
      expect(f.fehler, isEmpty);
      expect(f.zustand.klingen!.teile.every((t) => t.ergebnis != null), true);
      expect(f.zustand.angriffeVerbraucht, 1);
    },
  );

  test('Klingenwand endet beim Rundenwechsel, bezahlt und unbezahlt', () {
    for (final bezahlt in [false, true]) {
      final s = Gefechtszustand(
        iniWurf: 6,
        klingen: _stand('x', parade: true, bezahlt: bezahlt),
      );
      expect(naechsteGefechtsrunde(s).klingen, isNull);
    }
  });

  test(
    'Klingenfortsetzung weist geändertes Waffenprofil und Folgeprobe zuerst ab',
    () {
      const w = Gefechtswerte(
        iniBasis: 15,
        at: 12,
        pa: 10,
        ausweichen: 9,
        waffenDk: 'N',
        waffe: MainWeaponSlot(id: 'w1', name: 'Schwert', distanceClass: 'N'),
      );
      final s = Gefechtszustand(
        iniWurf: 6,
        klingen: _stand(gefechtsKlingenprofilKey(w)),
      );
      expect(() => pruefeGefechtsKlingenfortsetzung(s, w, 0), returnsNormally);
      expect(() => pruefeGefechtsKlingenfortsetzung(s, w, 1), throwsStateError);
      const frisch = Gefechtswerte(
        iniBasis: 15,
        at: 12,
        pa: 10,
        ausweichen: 9,
        waffenDk: 'N',
        waffe: MainWeaponSlot(
          id: 'w1',
          name: 'Schwert',
          distanceClass: 'N',
          breakFactor: 7,
        ),
      );
      expect(
        () => pruefeGefechtsKlingenfortsetzung(s, frisch, 0),
        throwsStateError,
      );
    },
  );

  test(
    'Alle verschiedenen Gegner brauchen ideale Waffen-DK und passenden Pool',
    () {
      const w = Gefechtswerte(
        iniBasis: 15,
        at: 12,
        pa: 10,
        ausweichen: 9,
        waffenDk: 'N',
      );
      expect(
        () => pruefeGefechtsKlingenteile(
          const [
            GefechtsKlingenteil(gegnerId: 'g1', dk: 'N', zielwert: 8),
            GefechtsKlingenteil(gegnerId: 'g2', dk: 'S', zielwert: 8),
          ],
          w,
          parade: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => pruefeGefechtsKlingenteile(
          const [
            GefechtsKlingenteil(gegnerId: 'g1', dk: 'N', zielwert: 8),
            GefechtsKlingenteil(gegnerId: 'g1', dk: 'N', zielwert: 8),
          ],
          w,
          parade: false,
        ),
        throwsArgumentError,
      );
      expect(
        () => gefechtsKlingenwerte(15, kampfgespuer: true, verteilung: [5, 14]),
        throwsArgumentError,
      );
      expect(
        () =>
            gefechtsKlingenwerte(15, kampfgespuer: true, verteilung: [10, 10]),
        throwsArgumentError,
      );
    },
  );
}

GefechtsKlingenstand _stand(
  String key, {
  bool parade = false,
  bool bezahlt = false,
}) => GefechtsKlingenstand(
  id: 'k',
  parade: parade,
  bezahlt: bezahlt,
  kampfmittel: const GefechtsKampfmittelwahl(
    GefechtsKampfmittelArt.hauptwaffe,
    'w1',
  ),
  profilKey: key,
  teile: const [
    GefechtsKlingenteil(gegnerId: 'g1', dk: 'N', zielwert: 9, finte: 3),
    GefechtsKlingenteil(gegnerId: 'g2', dk: 'N', zielwert: 9, finte: 1),
  ],
  basisPruefung: Gefechtspruefung(
    aktion: parade ? Gefechtsaktion.parade : Gefechtsaktion.angriff,
    status: Gefechtsfreigabe.bereit,
    gruende: const [],
    zielwert: 14,
    angriffe: parade ? 0 : 1,
    paraden: parade ? 1 : 0,
  ),
  schaden: const DiceSpec(count: 1, sides: 6, modifier: 4),
);

class _Fixture {
  _Fixture(this.container, this.adapter);
  final ProviderContainer container;
  final _Adapter adapter;
  final List<Object> fehler = [];
  Gefechtszustand get zustand => container.read(gefechtProvider('rondra'))!;
}

Future<_Fixture> _start(
  WidgetTester tester, {
  bool parade = false,
  bool gruppe = false,
  bool mitPatzerkarte = false,
}) async {
  const config = CombatConfig(
    weapons: [MainWeaponSlot(id: 'w1', name: 'Schwert', distanceClass: 'N')],
  );
  final repo = BogenTestRepository(
    heroes: [testHero().copyWith(combatConfig: config)],
    states: {'rondra': const HeroState.empty()},
  );
  final c = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(c.dispose);
  final f = _Fixture(c, _Adapter());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (ctx, ref, _) {
              ref.watch(heroComputedProvider('rondra'));
              final karte = GefechtKlingenkarte(
                heroId: 'rondra',
                bestand: () => f.adapter,
                gesperrt: false,
                onAktion: (a) async {
                  try {
                    await a();
                  } catch (e) {
                    f.fehler.add(e);
                  }
                },
              );
              if (!mitPatzerkarte) return karte;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    karte,
                    GefechtPatzer(
                      heroId: 'rondra',
                      bestand: () => f.adapter,
                      gesperrt: false,
                      onAktion: (a) async {
                        try {
                          await a();
                        } catch (e) {
                          f.fehler.add(e);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final ctl = c.read(gefechtProvider('rondra').notifier);
  ctl.beginnen(6, dk: 'N');
  final snap = c.read(heroComputedProvider('rondra')).asData!.value;
  final w = gefechtswerteFuer(
    snap,
    katalog: testCatalog,
    kampfmittel: const GefechtsKampfmittelwahl(
      GefechtsKampfmittelArt.hauptwaffe,
      'w1',
    ),
  );
  ctl.setzen(
    f.zustand.copyWith(
      klingen: _stand(gefechtsKlingenprofilKey(w), parade: parade),
    ),
  );
  final g = c.read(gefechtBegegnungProvider.notifier);
  g.speichern(
    const Gefechtsgegner(id: 'g1', name: 'Ork', lep: 30, rs: 2, ini: 1),
  );
  g.speichern(
    const Gefechtsgegner(id: 'g2', name: 'Goblin', lep: 20, rs: 1, ini: 1),
  );
  if (gruppe) {
    c
        .read(gefechtInitiativeProvider.notifier)
        .hinzufuegen('rondra', zeitpunktVorbei: false);
  }
  await tester.pumpAndSettle();
  return f;
}

class _Adapter implements KartoGefechtsAdapter {
  final List<List<int>?> wuerfe = [];
  final List<ResolvedProbeRequest> anfragen = [];
  bool nurRueckgabe = false;
  @override
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  }) async {
    anfragen.add(request);
    final w = wuerfe.removeAt(0);
    if (w == null) return null;
    final r = evaluateProbe(
      request,
      ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: w,
        situationalModifier: request.initialSituationalModifier,
        specializationApplied: false,
      ),
    );
    if (!nurRueckgabe) {
      onResolved?.call(r);
      onResolved?.call(r);
    }
    return r;
  }

  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) async => true;
}
