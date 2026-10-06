import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_klingen.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirkabschluss.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_schnellleiste.dart';

import '../../test_support/bogen_test_repository.dart';
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Regressionstests des unabhängigen Reviews der Gefechts-Vervollständigung
// (Befunde R1–R10, docs/gefecht_implementation.md).

const _trank = HeroInventoryEntry(
  gegenstand: 'Heiltrank',
  anzahl: '2',
  itemType: InventoryItemType.verbrauchsgegenstand,
  woGetragen: 'Gürteltasche',
);

HeroSheet _held({List<HeroInventoryEntry>? inventar, List<HeroCompanion>? b}) =>
    testHero().copyWith(
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
      inventoryEntries: inventar ?? const [_trank],
      companions: b ?? const [],
    );

// Ansicht mit fester Breite, frischem Repository und kontrollierbarer Brücke.
Future<(ProviderContainer, BogenTestRepository)> _ansicht(
  WidgetTester tester, {
  HeroSheet? held,
  GefechtsTestBestand? bestand,
  Size groesse = const Size(1200, 1800),
}) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = held ?? _held();
  const zustand = HeroState(
    currentLep: 30,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 30,
  );
  final repo = BogenTestRepository(heroes: [h], states: {'rondra': zustand});
  final snapshot = buildHeroComputedSnapshot(
    hero: h,
    state: zustand,
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  final container = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snapshot)),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(container.dispose);
  container.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(
          heroId: 'rondra',
          bestand: bestand ?? GefechtsTestBestand(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, repo);
}

Future<void> _tippe(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

// Setzt eine offene, nicht abgeschlossene Handlung in die Sitzung.
void _handlung(ProviderContainer c, {int verbleibend = 3}) {
  final ctl = c.read(gefechtProvider('rondra').notifier);
  ctl.setzen(
    c
        .read(gefechtProvider('rondra'))!
        .copyWith(
          handlung: Gefechtshandlung(
            titel: 'Talenteinsatz',
            verbleibend: verbleibend,
          ),
        ),
  );
}

// Würfelt W20 normal, bricht aber jeden W6-Wurf ab.
class _OhneW6 extends GefechtsTestBestand {
  @override
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  }) async {
    if (request.diceSpec.sides == 6) {
      anfragen.add(request);
      return null;
    }
    return super.gefechtsProbe(
      context: context,
      ref: ref,
      heroId: heroId,
      request: request,
      onResolved: onResolved,
    );
  }
}

void main() {
  testWidgets('R1: gleichnamige Begleiter und Gegenstände stürzen nicht ab', (
    tester,
  ) async {
    await _ansicht(
      tester,
      held: _held(
        inventar: const [
          _trank,
          HeroInventoryEntry(
            gegenstand: 'Heiltrank',
            anzahl: '1',
            itemType: InventoryItemType.verbrauchsgegenstand,
            woGetragen: 'Rucksack',
          ),
        ],
        b: const [
          HeroCompanion(id: 'p1', name: 'Pferd'),
          HeroCompanion(id: 'p2', name: 'Pferd'),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Pferd'), findsNWidgets(2));
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    expect(tester.takeException(), isNull);
    expect(find.text('Heiltrank'), findsNWidgets(2));
  });

  testWidgets('R2: gesperrte Benutzung würfelt keine FF-Probe', (tester) async {
    final bestand = GefechtsTestBestand();
    final (c, _) = await _ansicht(tester, bestand: bestand);
    _handlung(c);
    await tester.pumpAndSettle();
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    await _tippe(tester, find.widgetWithText(TextButton, 'Benutzen'));
    await _tippe(tester, find.text('FF-Probe würfeln (halbiert die Zeit)'));
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-gegenstand-starten')),
    );
    expect(bestand.anfragen, isEmpty);
    expect(find.byKey(const ValueKey('gefecht-fehler')), findsOneWidget);
    expect(c.read(gefechtProvider('rondra'))!.handlung?.titel, 'Talenteinsatz');
  });

  testWidgets('R3a: doppelter gemeinsamer Rundenwechsel zählt einmal', (
    tester,
  ) async {
    final (c, _) = await _ansicht(tester);
    c
        .read(gefechtInitiativeProvider.notifier)
        .hinzufuegen('rondra', zeitpunktVorbei: false);
    await tester.pumpAndSettle();
    final knopf = find.text('Gemeinsame nächste Runde');
    await tester.ensureVisible(knopf);
    await tester.pumpAndSettle();
    await tester.tap(knopf);
    await tester.tap(knopf, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(c.read(gefechtProvider('rondra'))!.runde, 2);
    expect(c.read(gefechtInitiativeProvider).runde, 2);
  });

  testWidgets(
    'R3b (nicht reproduzierbar, Absicherung): Doppeltipp bucht einmal',
    (tester) async {
      final (c, _) = await _ansicht(tester);
      c
          .read(gefechtBegegnungProvider.notifier)
          .speichern(
            const Gefechtsgegner(id: 'g', name: 'Ork', lep: 20, rs: 3, ini: 12),
          );
      await tester.pumpAndSettle();
      final knopf = find.text('Treffer übernehmen');
      await tester.ensureVisible(knopf);
      await tester.pumpAndSettle();
      await tester.tap(knopf);
      await tester.tap(knopf, warnIfMissed: false);
      await tester.pumpAndSettle();
      while (find.text('Treffer bestätigt').evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextFormField).last, '8');
        await tester.tap(find.text('Treffer bestätigt').last);
        await tester.pumpAndSettle();
      }
      expect(c.read(gefechtBegegnungProvider).gegner['g']!.lep, 15);
    },
  );

  testWidgets('R3c: Fehler der Initiativkarte erscheinen im Gefechtshinweis', (
    tester,
  ) async {
    final (c, _) = await _ansicht(tester);
    c
        .read(gefechtInitiativeProvider.notifier)
        .hinzufuegen('rondra', zeitpunktVorbei: false);
    _handlung(c, verbleibend: 0);
    await tester.pumpAndSettle();
    await _tippe(tester, find.text('Gemeinsame nächste Runde'));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const ValueKey('gefecht-fehler')), findsOneWidget);
    expect(c.read(gefechtProvider('rondra'))!.runde, 1);
  });

  testWidgets('R4: Gefechtshinweis zeigt den fachlichen Grund ohne Präfix', (
    tester,
  ) async {
    final (c, _) = await _ansicht(tester);
    _handlung(c);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gefecht-fehler')), findsOneWidget);
    expect(
      find.textContaining('Laufende Handlung zuerst abschließen'),
      findsOneWidget,
    );
    expect(find.textContaining('Bad state'), findsNothing);
  });

  testWidgets('R9: Schnellleiste zeigt Zielwert nur bei bereiter Aktion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GefechtSchnellleiste(
            aktionen: [
              GefechtSchnellaktion(
                titel: 'Attacke',
                symbol: Icons.sports_martial_arts,
                onPressed: () {},
                pruefung: const Gefechtspruefung(
                  aktion: Gefechtsaktion.angriff,
                  status: Gefechtsfreigabe.pruefen,
                  gruende: ['DK fehlt'],
                  fehlendeAngaben: ['DK fehlt'],
                  zielwert: 14,
                ),
              ),
              GefechtSchnellaktion(
                titel: 'Parade',
                symbol: Icons.shield_outlined,
                onPressed: () {},
                pruefung: const Gefechtspruefung(
                  aktion: Gefechtsaktion.parade,
                  status: Gefechtsfreigabe.bereit,
                  gruende: [],
                  zielwert: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('14'), findsNothing);
    expect(find.text('Angabe fehlt'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('R10: abgebrochener Sturz-W6 bucht nichts', (tester) async {
    final bestand = _OhneW6()..w20Wert = 20;
    final (c, repo) = await _ansicht(tester, bestand: bestand);
    await _tippe(tester, find.byKey(const ValueKey('gefecht-aktionswahl')));
    await _tippe(
      tester,
      find.byKey(const ValueKey('gefecht-aktion-zuBodenWerfen')),
    );
    final s = c.read(gefechtProvider('rondra'))!;
    expect(bestand.anfragen.any((r) => r.diceSpec.sides == 6), isTrue);
    expect(s.freieVerbraucht, 0);
    expect(s.haltung, Gefechtshaltung.stehend);
    expect((await repo.loadHeroState('rondra'))!.currentAu, 30);
  });

  // R5/R6: Aufteilung mit Vorgaben und dem einzigen Ort für die Erschwernis.
  for (final wand in [false, true]) {
    testWidgets('R5/R6: Klingen-Aufteilung vorbelegt, Erschwernis (PA=$wand)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const config = CombatConfig(
        weapons: [
          MainWeaponSlot(id: 'w1', name: 'Schwert', distanceClass: 'N'),
        ],
        specialRules: CombatSpecialRules(
          activeManeuvers: ['man_klingenwand', 'man_klingensturm'],
        ),
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
      final bestand = GefechtsTestBestand();
      late BuildContext kontext;
      late WidgetRef referenz;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (ctx, ref, _) {
                  kontext = ctx;
                  referenz = ref;
                  ref.watch(heroComputedProvider('rondra'));
                  return GefechtKlingenkarte(
                    heroId: 'rondra',
                    bestand: () => bestand,
                    gesperrt: false,
                    onAktion: (a) => a(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final g = c.read(gefechtBegegnungProvider.notifier);
      const ork = Gefechtsgegner(id: 'g1', name: 'Ork', lep: 30, rs: 2, ini: 1);
      const goblin = Gefechtsgegner(
        id: 'g2',
        name: 'Goblin',
        lep: 20,
        rs: 1,
        ini: 1,
      );
      g.speichern(ork);
      g.speichern(goblin);
      final ctl = c.read(gefechtProvider('rondra').notifier);
      ctl.beginnen(6, dk: 'N');
      // Das aktuelle Ziel steht in der Aufteilung zuerst.
      ctl.setzen(
        waehleGefechtsgegner(
          c.read(gefechtProvider('rondra'))!,
          goblin,
          startDk: 'N',
        ),
      );
      final snap = c.read(heroComputedProvider('rondra')).asData!.value;
      final beginn = zeigeGefechtsKlingenbeginn(
        context: kontext,
        ref: referenz,
        heroId: 'rondra',
        katalog: testCatalog,
        manoever: ManeuverDef(
          id: wand ? 'man_klingenwand' : 'man_klingensturm',
          name: wand ? 'Klingenwand' : 'Klingensturm',
          typ: wand ? 'Abwehraktion' : 'Angriffsaktion',
        ),
        snapshot: snap,
        kampfmittel: const GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.hauptwaffe,
          'w1',
        ),
      );
      await tester.pumpAndSettle();
      final feld = find.byKey(const ValueKey('gefecht-klingen-erschwernis'));
      expect(feld, findsOneWidget);
      await tester.enterText(feld, '3');
      await tester.pump();
      await tester.tap(find.text('Aufteilung bestätigen'));
      await tester.pumpAndSettle();
      // Ohne Vorgaben bliebe der Dialog mit Fehlermeldung offen.
      expect(find.text('Aufteilung bestätigen'), findsNothing);
      await beginn;
      final stand = c.read(gefechtProvider('rondra'))!.klingen;
      expect(stand, isNotNull);
      expect(stand!.teile.map((t) => t.gegnerId), ['g2', 'g1']);
      expect(stand.teile.every((t) => t.dk == 'N'), isTrue);
      await tester.tap(find.text('Teilprobe').first);
      await tester.pumpAndSettle();
      expect(bestand.anfragen.last.initialSituationalModifier, -3);
    });
  }

  testWidgets('R11: Abschlusskosten-Fehler erscheint im Kostenblatt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = BogenTestRepository(
      heroes: [testHero()],
      states: {
        'rondra': const HeroState(
          currentLep: 20,
          currentAsp: 20,
          currentKap: 0,
          currentAu: 30,
        ),
      },
    );
    final c = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(c.dispose);
    late BuildContext kontext;
    late WidgetRef referenz;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) {
                kontext = ctx;
                referenz = ref;
                ref.watch(heroComputedProvider('rondra'));
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    const probe = ResolvedProbeRequest(
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
    final ctl = c.read(gefechtProvider('rondra').notifier);
    ctl.beginnen(6);
    ctl.setzen(
      c
          .read(gefechtProvider('rondra'))!
          .copyWith(
            handlung: Gefechtshandlung(
              titel: 'Testzauber',
              verbleibend: 0,
              art: Gefechtshandlungsart.zauber,
              ergebnis: evaluateProbe(
                probe,
                const ProbeRollInput(
                  mode: ProbeRollMode.manual,
                  diceValues: [10, 10, 10],
                  situationalModifier: 0,
                  specializationApplied: false,
                ),
              ),
              wirken: const GefechtsWirkprofil(
                probe: probe,
                dauer: 1,
                kosten: 5,
                karmal: false,
              ),
            ),
          ),
    );
    zeigeGefechtsWirkabschluss(
      context: kontext,
      ref: referenz,
      heroId: 'rondra',
      bestand: GefechtsTestBestand(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kosten jetzt übernehmen'));
    await tester.pumpAndSettle();
    // Zwischenzeitlich verbraucht ein anderer Weg die Astralenergie.
    final frisch = (await repo.loadHeroState('rondra'))!;
    await repo.saveHeroState('rondra', frisch.copyWith(currentAsp: 2));
    await tester.tap(find.text('Abschlusskosten übernehmen'));
    await tester.pumpAndSettle();
    final blatt = find
        .ancestor(
          of: find.text('Abschlusskosten übernehmen'),
          matching: find.byType(ZustandFehlerBereich),
        )
        .first;
    expect(
      find.descendant(
        of: blatt,
        matching: find.byKey(kZustandFehlerSchluessel),
      ),
      findsOneWidget,
    );
    expect((await repo.loadHeroState('rondra'))!.currentAsp, 2);
  });
}
