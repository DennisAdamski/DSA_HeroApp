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
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_routen_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_reiseroute.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../test_support/fake_repository.dart';
import '../shell/karto_test_support.dart';

// Reisewege im Reiseroute-Blatt gegen einen Fake-Client: berechnen,
// anzeigen und die Anreise einer Etappe wählen.

const String _gareth = '80558060-4299-54aa-b520-814b10819885';
const String _perricum = '194cd8ed-9aff-57af-b658-ff353ac883a7';

const List<HeroReiseStation> _stationen = <HeroReiseStation>[
  HeroReiseStation(
    id: 's1',
    ort: 'Gareth',
    ortId: _gareth,
    kartenX: 551.625,
    kartenY: 532.969,
    datum: HeroAdventureDateValue(day: '1', month: 'boron', year: '1043'),
  ),
  HeroReiseStation(
    id: 's2',
    ort: 'Perricum',
    ortId: _perricum,
    kartenX: 631.281,
    kartenY: 507.328,
    datum: HeroAdventureDateValue(day: '5', month: 'boron', year: '1043'),
  ),
];

const Map<String, Object?> _antwort = <String, Object?>{
  'vertrag': 1,
  'gefunden': true,
  'meilen': 341.45,
  'reisestunden': 68.39,
  'reisetage': 5.78,
  'etappen': <Object?>[
    <String, Object?>{'art': 'Strasse', 'meilen': 4.8},
    <String, Object?>{'art': 'Flussweg', 'meilen': 334.3},
  ],
  'linie': <Object?>[
    <Object?>[551.6, 532.9],
    <Object?>[600, 520],
    <Object?>[631.2, 507.3],
  ],
  'hinweise': <Object?>[],
};

Finder _k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  late FakeRepository repo;
  late List<Uri> anfragen;

  Future<void> zeige(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    anfragen = <Uri>[];
    final client = AvesmapsClient(
      httpClient: MockClient((request) async {
        anfragen.add(request.url);
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
    repo = FakeRepository(
      heroes: <HeroSheet>[testHero().copyWith(reiseStationen: _stationen)],
      states: <String, HeroState>{'rondra': const HeroState.empty()},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ortKatalogProvider.overrideWith((ref) async => const OrtKatalog()),
        avesmapsOrteProvider.overrideWith((ref) async => const <AvesmapsOrt>[]),
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: const Scaffold(body: KartoReiserouteBlatt(heroId: 'rondra')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int routenAnfragen() =>
      anfragen.where((u) => u.path.endsWith('/route')).length;

  testWidgets('berechnet Reisewege erst auf Knopfdruck', (tester) async {
    await zeige(tester);
    expect(routenAnfragen(), 0);
    expect(find.text('+4 Tage · 251 Meilen Luftlinie'), findsOneWidget);

    await tester.tap(_k('karto-reise-wege-berechnen'));
    await tester.pumpAndSettle();

    expect(routenAnfragen(), 1);
    expect(find.text('+4 Tage · 341 Meilen · 5¾ Reisetage'), findsOneWidget);
    expect(_k('karto-reise-wege-berechnen'), findsNothing);
  });

  testWidgets('der Reisewegdialog speichert die Anreise an der Station', (
    tester,
  ) async {
    await zeige(tester);
    await tester.tap(_k('karto-reise-wege-berechnen'));
    await tester.pumpAndSettle();

    await tester.tap(_k('karto-reise-weg-s2'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(_k('karto-reiseweg-ergebnis')).data,
      '341 Meilen · 5¾ Reisetage · Fluss, Straße',
    );

    // Nur über Land: noch nicht berechnet, also kein Ergebnis.
    await tester.tap(_k('karto-reiseweg-weg-fluss'));
    await tester.tap(_k('karto-reiseweg-weg-see'));
    await tester.pumpAndSettle();
    expect(_k('karto-reiseweg-ergebnis'), findsNothing);
    expect(_k('karto-reiseweg-berechnen'), findsOneWidget);
    await tester.tap(_k('karto-reiseweg-berechnen'));
    await tester.pumpAndSettle();
    expect(anfragen.last.queryParameters['wege'], 'land');

    await tester.tap(_k('karto-reiseweg-uebernehmen'));
    await tester.pumpAndSettle();

    final station = (await repo.loadHeroById('rondra'))!.reiseStationen
        .firstWhere((s) => s.id == 's2');
    expect(station.anreise?.wege, <String>['land']);
    expect(station.anreise?.optimierung, '');
    // Die erste Station bleibt ohne Anreise.
    final erste = (await repo.loadHeroById('rondra'))!.reiseStationen.first;
    expect(erste.anreise, isNull);
  });

  testWidgets('die Vorgabe entfernt eine gewählte Anreise wieder', (
    tester,
  ) async {
    await zeige(tester);
    await repo.saveHero(
      (await repo.loadHeroById('rondra'))!.copyWith(
        reiseStationen: <HeroReiseStation>[
          _stationen.first,
          _stationen.last.copyWith(
            anreise: const HeroReiseAnreise(wege: <String>['land']),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_k('karto-reise-weg-s2'));
    await tester.pumpAndSettle();
    await tester.tap(_k('karto-reiseweg-variante-Schnellster Weg'));
    await tester.pumpAndSettle();
    await tester.tap(_k('karto-reiseweg-uebernehmen'));
    await tester.pumpAndSettle();
    final station = (await repo.loadHeroById('rondra'))!.reiseStationen.last;
    expect(station.anreise, isNull);
    expect(station.toJson().containsKey('anreise'), isFalse);
  });
}
