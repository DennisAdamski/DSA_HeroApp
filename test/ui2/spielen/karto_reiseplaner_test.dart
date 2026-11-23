import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_repository.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_routen_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/standort/karto_standort_kachel.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../test_support/fake_repository.dart';
import '../shell/karto_test_support.dart';

// Reiseplaner und laufende Reise: Weg berechnen, Plan nach Regelwerk,
// Ankommen oder Aufbrechen, Angekommen. Das Netz ersetzt ein MockClient,
// den Zustand ein mitschreibender Setzer.

const String _gareth = '80558060-4299-54aa-b520-814b10819885';
const String _perricum = '194cd8ed-9aff-57af-b658-ff353ac883a7';

final OrtKatalog _wiki = OrtKatalog(
  orte: <OrtEintrag>[
    OrtEintrag(name: 'Gareth', art: OrtArt.siedlung),
    OrtEintrag(name: 'Perricum', art: OrtArt.siedlung),
  ],
);

const List<AvesmapsOrt> _avesmaps = <AvesmapsOrt>[
  AvesmapsOrt(id: _gareth, name: 'Gareth', x: 551.625, y: 532.969),
  AvesmapsOrt(id: _perricum, name: 'Perricum', x: 631.281, y: 507.328),
];

// 120 Meilen Reichsstraße und 24 Meilen Weg: zu Fuß 120 ÷ 33 + 24 ÷ 24 =
// 4,6 Tage, also 5 ganze Tage.
const Map<String, Object?> _antwort = <String, Object?>{
  'vertrag': 1,
  'gefunden': true,
  'meilen': 144,
  'reisestunden': 40,
  'reisetage': 5,
  'etappen': <Object?>[
    <String, Object?>{'art': 'Reichsstrasse', 'meilen': 120},
    <String, Object?>{'art': 'Weg', 'meilen': 24},
  ],
  'linie': <Object?>[
    <Object?>[551.6, 532.9],
    <Object?>[631.2, 507.3],
  ],
  'hinweise': <Object?>[],
};

Finder _k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

class _Aufbau {
  _Aufbau(this.repo, this.container);

  final FakeRepository repo;
  final ProviderContainer container;
  final List<({HeroUnterwegs? unterwegs, String? standort})> zustand =
      <({HeroUnterwegs? unterwegs, String? standort})>[];

  Future<bool> setze({
    required HeroUnterwegs? unterwegs,
    String? standort,
    String standortOrtId = '',
  }) {
    zustand.add((unterwegs: unterwegs, standort: standort));
    ortIds.add(standortOrtId);
    return Future<bool>.value(true);
  }

  /// Verweise der geschriebenen Standorte, parallel zu [zustand].
  final List<String> ortIds = <String>[];

  Future<HeroSheet> held() async => (await repo.loadHeroById('rondra'))!;
}

Future<_Aufbau> _zeige(
  WidgetTester tester, {
  HeroUnterwegs? unterwegs,
  List<HeroCompanion> begleiter = const <HeroCompanion>[],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final client = AvesmapsClient(
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/route')) {
        return http.Response.bytes(
          utf8.encode(jsonEncode(_antwort)),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    }),
  );
  final repo = FakeRepository(
    heroes: <HeroSheet>[
      testHero().copyWith(
        companions: begleiter,
        adventures: <HeroAdventureEntry>[
          const HeroAdventureEntry(
            id: 'a1',
            title: 'Fahrt nach Perricum',
            currentAventurianDate: HeroAdventureDateValue(
              day: '1',
              month: 'boron',
              year: '1043',
            ),
          ),
        ],
      ),
    ],
    states: <String, HeroState>{
      'rondra': const HeroState.empty().copyWith(
        standort: 'Gareth',
        unterwegs: unterwegs,
      ),
    },
  );
  final container = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ortKatalogProvider.overrideWith((ref) async => _wiki),
      avesmapsOrteProvider.overrideWith((ref) async => _avesmaps),
      avesmapsClientProvider.overrideWithValue(client),
      avesmapsRoutenRepositoryProvider.overrideWith(
        (ref) async => AvesmapsRoutenRepository(
          client: client,
          speicher: FluechtigerAvesmapsRoutenSpeicher(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  final aufbau = _Aufbau(repo, container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                // Wie die Spielansicht: der Snapshot des Helden lebt mit.
                ref.watch(heroComputedProvider('rondra'));
                final zustand = ref
                    .watch(heroStateProvider('rondra'))
                    .asData
                    ?.value;
                return KartoKachelSteuerung(
                  kennung: 'standort',
                  groesse: KartoKachelGroesse.fuerBreite(860),
                  dicht: false,
                  child: KartoStandortKachel(
                    standort: zustand?.standort ?? 'Gareth',
                    heroId: 'rondra',
                    unterwegs: unterwegs,
                    onSpeichern: (_) async {},
                    onReiseZustand: aufbau.setze,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return aufbau;
}

Future<void> _planeBisWeg(WidgetTester tester) async {
  await tester.tap(_k('karto-standort-kachel-reise-planen'));
  await tester.pumpAndSettle();
  expect(_k('karto-reiseplan-von'), findsOneWidget);
  await tester.enterText(_k('karto-reiseplan-nach'), 'Perricum');
  await tester.pumpAndSettle();
  await tester.tap(_k('karto-reiseplan-berechnen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Plan nach Regelwerk, Ankommen schreibt zwei Stationen', (
    tester,
  ) async {
    final aufbau = await _zeige(tester);
    await _planeBisWeg(tester);

    expect(
      find.text('144 Meilen · 4,6 Tage · Plan 5 Tage'),
      findsOneWidget,
      reason: '120 ÷ (30 × 1,1) + 24 ÷ (30 × 0,8)',
    );
    expect(
      find.text('Reichsstraße 120 Meilen ÷ (30 × 1,1) = 3,6 Tage'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('karto-reiseplan-ankunft-tag')),
          )
          .controller!
          .text,
      '6',
    );

    await tester.tap(_k('karto-reiseplan-ankommen'));
    await tester.pumpAndSettle();

    final held = await aufbau.held();
    final sortiert = sortiereReiseStationen(held.reiseStationen);
    expect(sortiert.map((s) => s.ort), <String>['Gareth', 'Perricum']);
    expect(sortiert.first.ortId, _gareth);
    expect(sortiert.last.ortId, _perricum);
    expect(sortiert.last.datum.day, '6');
    expect(sortiert.last.anreise!.geplanteTage, closeTo(4.64, .01));
    expect(sortiert.last.anreise!.mittel, kReiseMittelFuss);
    expect(held.adventures.single.currentAventurianDate.day, '6');
    expect(aufbau.zustand.single.standort, 'Perricum');
    expect(aufbau.zustand.single.unterwegs, isNull);
    // Der neue Standort trägt den Verweis des Ziels.
    expect(aufbau.ortIds.single, _perricum);
  });

  testWidgets('Reittier, Eile und Wetter verändern den Plan', (tester) async {
    await _zeige(
      tester,
      begleiter: const <HeroCompanion>[
        HeroCompanion(id: 'r', name: 'Sturmwind', typ: BegleiterTyp.reittier),
      ],
    );
    await _planeBisWeg(tester);
    // Beritten: 120 ÷ 44 + 24 ÷ 32 = 3,5 Tage.
    expect(find.text('144 Meilen · 3,5 Tage · Plan 4 Tage'), findsOneWidget);

    await tester.tap(_k('karto-reiseplan-eil'));
    await tester.pumpAndSettle();
    // Eilritt: 120 ÷ 66 + 24 ÷ 48 = 2,3 Tage.
    expect(find.text('144 Meilen · 2,3 Tage · Plan 3 Tage'), findsOneWidget);

    await tester.tap(_k('karto-reiseplan-wetter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dauerregen oder Sturm (×0,7)').last);
    await tester.pumpAndSettle();
    // Kein Eilritt bei Sturm: 120 ÷ (40 × 1,1 × 0,7) + 24 ÷ (40 × 0,8 × 0,7).
    expect(find.text('144 Meilen · 5,0 Tage · Plan 5 Tage'), findsOneWidget);
    expect(find.textContaining('vereitelt'), findsOneWidget);
  });

  testWidgets('Aufbrechen legt die Ausgangsstation an und ist unterwegs', (
    tester,
  ) async {
    final aufbau = await _zeige(tester);
    await _planeBisWeg(tester);
    await tester.tap(_k('karto-reiseplan-aufbrechen'));
    await tester.pumpAndSettle();

    final held = await aufbau.held();
    expect(held.reiseStationen.map((s) => s.ort), <String>['Gareth']);
    expect(held.adventures.single.currentAventurianDate.day, '1');
    final u = aufbau.zustand.single.unterwegs!;
    expect(u.ziel, 'Perricum');
    expect(u.zielOrtId, _perricum);
    expect(u.vonOrt, 'Gareth');
    expect(u.adventureId, 'a1');
    expect(u.anreise.abreise.day, '1');
    expect(u.anreise.geplanteTage, closeTo(4.64, .01));
    expect(aufbau.zustand.single.standort, isNull);
  });

  testWidgets('unterwegs: Reisetag, Angekommen schreibt die Ankunft', (
    tester,
  ) async {
    final aufbau = await _zeige(
      tester,
      unterwegs: const HeroUnterwegs(
        ziel: 'Perricum',
        zielOrtId: _perricum,
        zielKartenX: 631.281,
        zielKartenY: 507.328,
        vonOrt: 'Gareth',
        vonOrtId: _gareth,
        vonKartenX: 551.625,
        vonKartenY: 532.969,
        adventureId: 'a1',
        anreise: HeroReiseAnreise(
          abreise: HeroAdventureDateValue(
            day: '29',
            month: 'travia',
            year: '1043',
          ),
          geplanteTage: 4.64,
          meilen: 144,
        ),
      ),
    );
    expect(_k('karto-standort-kachel-reise-planen'), findsNothing);
    expect(find.text('Unterwegs nach Perricum'), findsOneWidget);
    expect(find.text('Tag 3 von 5'), findsOneWidget);

    await tester.tap(_k('karto-standort-kachel-angekommen'));
    await tester.pumpAndSettle();
    await tester.tap(_k('karto-reise-ankunft-ok'));
    await tester.pumpAndSettle();

    final held = await aufbau.held();
    final sortiert = sortiereReiseStationen(held.reiseStationen);
    expect(sortiert.map((s) => s.ort), <String>['Gareth', 'Perricum']);
    expect(sortiert.first.datum.day, '29');
    expect(sortiert.last.datum.day, '1');
    expect(sortiert.last.anreise!.geplanteTage, 4.64);
    expect(
      reisePlanVergleichText(reiseEtappen(held.reiseStationen).last),
      'Plan 5 Tage · 3 Tage kürzer',
    );
    expect(aufbau.zustand.single.standort, 'Perricum');
    expect(aufbau.zustand.single.unterwegs, isNull);
    expect(aufbau.ortIds.single, _perricum);
  });
}
