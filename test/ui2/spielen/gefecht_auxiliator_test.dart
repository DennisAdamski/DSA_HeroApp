import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_wirken.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Auxiliator im Gefecht: Nach der echten Zauberprobe bietet der Abschluss des
// Zaubers den ausgerüsteten Zaubertalisman an, der zu diesem Zauber passt. Der
// Standardweg der Zauberprobe bleibt unverändert; der Talisman bucht nur die
// zusätzlichen 1W3 AsP, denn die Zauberkosten bucht der Abschluss.

const _probe = ResolvedProbeRequest(
  type: ProbeType.spell,
  title: 'Ignifaxius',
  subtitle: '',
  ruleHint: '',
  diceSpec: DiceSpec(count: 3, sides: 20),
  basePool: 8,
  targets: [
    ProbeTargetValue(label: 'KL', value: 14),
    ProbeTargetValue(label: 'IN', value: 12),
    ProbeTargetValue(label: 'FF', value: 13),
  ],
);

const _ring = HeroInventoryEntry(
  gegenstand: 'Mondsilberring',
  isMagisch: true,
  istAusgeruestet: true,
  instanzId: 'i-1',
  artefaktDaten: ArtefaktDaten(
    art: ArtefaktArt.zaubertalisman,
    zauber: <ArtefaktZauber>[
      ArtefaktZauber(
        spellId: 'spell_ignifaxius',
        name: 'Ignifaxius',
        repraesentation: 'Mag',
        zfpStern: 5,
        kostenAsp: 9,
      ),
    ],
  ),
);

const _profil = GefechtsWirkprofil(
  probe: _probe,
  dauer: 1,
  kosten: 9,
  karmal: false,
  repraesentation: 'Mag',
  identitaet: 'zauber::spell_ignifaxius',
);

Future<(ProviderContainer, FakeRepository, BuildContext, WidgetRef)> _aufbau(
  WidgetTester tester, {
  List<HeroInventoryEntry> inventar = const [_ring],
}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = FakeRepository(
    heroes: [testHero().copyWith(inventoryEntries: inventar)],
    states: {
      'rondra': const HeroState(
        currentLep: 20,
        currentAsp: 20,
        currentKap: 0,
        currentAu: 30,
      ),
    },
  );
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
  return (container, repo, context, ref);
}

Finder _schluessel(String name) => find.byKey(ValueKey<String>(name));

void main() {
  testWidgets('der Abschluss bietet den passenden Zaubertalisman an', (
    tester,
  ) async {
    final (container, repo, context, ref) = await _aufbau(tester);
    final bestand = GefechtsTestBestand();

    unawaited(
      starteGefechtsWirken(
        context: context,
        ref: ref,
        heroId: 'rondra',
        bestand: bestand,
        art: Gefechtshandlungsart.zauber,
        profil: _profil,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ignifaxius · Abschluss'), findsOneWidget);
    expect(find.text('Auxiliator einsetzen · Mondsilberring'), findsOneWidget);
    expect(bestand.anfragen.length, 1, reason: 'nur die eine Zauberprobe');

    await tester.tap(_schluessel('gefecht-auxiliator-0'));
    await tester.pumpAndSettle();

    // Die Probe liefert 8 ZfP*; der Dialog übernimmt sie samt Zauber und
    // Repräsentation und bucht die Zauberkosten nicht selbst.
    expect(find.text('Mondsilberring – Auxiliator einsetzen'), findsOneWidget);
    expect(_schluessel('auxiliator-kosten-hinweis'), findsOneWidget);
    expect(find.text('Bonus: 5 ZfP* · Gesamt: 13 ZfP*'), findsOneWidget);

    await tester.tap(_schluessel('auxiliator-von-hand'));
    await tester.pumpAndSettle();
    await tester.enterText(_schluessel('auxiliator-w3'), '2');
    await tester.enterText(_schluessel('auxiliator-w20'), '4');
    await tester.tap(_schluessel('auxiliator-bestaetigen'));
    await tester.pumpAndSettle();

    expect(find.text('ZfP* 8 + 5 = 13'), findsOneWidget);
    expect(find.text('2 AsP abgezogen.'), findsOneWidget);
    final zustand = (await repo.loadHeroState('rondra'))!;
    expect(zustand.currentAsp, 18, reason: 'nur die 1W3, keine Zauberkosten');
    expect(zustand.diceLog.single.title, 'Auxiliator: Mondsilberring');
    // Der Gefechtszustand bleibt unberührt: Handlung und Abschluss laufen weiter.
    expect(container.read(gefechtProvider('rondra'))!.handlung, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kein passender Talisman, kein Knopf', (tester) async {
    final (_, _, context, ref) = await _aufbau(
      tester,
      inventar: [
        // Nicht ausgerüstet, beschädigt, falscher Zauber, Matrixgeber.
        _ring.copyWith(istAusgeruestet: false),
        _ring.copyWith(
          artefaktDaten: _ring.artefaktDaten!.copyWith(defekt: true),
        ),
        _ring.copyWith(
          artefaktDaten: _ring.artefaktDaten!.copyWith(
            zauber: const [ArtefaktZauber(spellId: 'spell_balsam', name: 'B')],
          ),
        ),
        _ring.copyWith(
          artefaktDaten: _ring.artefaktDaten!.copyWith(
            art: ArtefaktArt.matrixgeber,
          ),
        ),
      ],
    );

    unawaited(
      starteGefechtsWirken(
        context: context,
        ref: ref,
        heroId: 'rondra',
        bestand: GefechtsTestBestand(),
        art: Gefechtshandlungsart.zauber,
        profil: _profil,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ignifaxius · Abschluss'), findsOneWidget);
    expect(_schluessel('gefecht-auxiliator-0'), findsNothing);
  });

  testWidgets('ein anderer Zauber bekommt keinen Talisman angeboten', (
    tester,
  ) async {
    final (_, _, context, ref) = await _aufbau(tester);

    unawaited(
      starteGefechtsWirken(
        context: context,
        ref: ref,
        heroId: 'rondra',
        bestand: GefechtsTestBestand(),
        art: Gefechtshandlungsart.zauber,
        profil: const GefechtsWirkprofil(
          probe: _probe,
          dauer: 1,
          kosten: 9,
          karmal: false,
          identitaet: 'zauber::spell_balsam',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_schluessel('gefecht-auxiliator-0'), findsNothing);
  });
}
