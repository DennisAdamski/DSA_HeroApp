import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_marker.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../test_support/fake_repository.dart';
import '../shell/karto_test_support.dart';

// Kachel „Zustandsmarker“ (SPIEL-03): freie Marker mit optionaler Dauer.
// Jede Änderung schreibt frisch den Laufzeitzustand und ändert nur die
// Markerliste; die Marker haben keine Regelwirkung.

const _basis = HeroState(
  currentLep: 25,
  currentAsp: 10,
  currentKap: 0,
  currentAu: 18,
  erschoepfung: 2,
  standort: 'Gareth',
);

const _furcht = ZustandsMarker(id: 'a', name: 'Furcht', rest: 3);
const _schmerz = ZustandsMarker(id: 'b', name: 'Schmerz', notiz: 'Kopfwunde');
const _betaeubt = ZustandsMarker(id: 'c', name: 'Betäubung', rest: 0);

Finder _k(String key) => find.byKey(ValueKey<String>(key));

void main() {
  Future<FakeRepository> zeige(
    WidgetTester tester, {
    List<ZustandsMarker> marker = const [],
    double breite = 390,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: [testHero('praiodan', 'Praiodan')],
      states: {'praiodan': _basis.copyWith(zustandsmarker: marker)},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
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
          builder: (context, kind) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: kind!,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: 'praiodan',
              bestand: TestBestand(),
              aktion: (auftrag) => auftrag(),
              vorHeldenbearbeitung: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.ensureVisible(ziel);
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<List<ZustandsMarker>> gespeichert(FakeRepository repo) async =>
      (await repo.loadHeroState('praiodan'))!.zustandsmarker;

  testWidgets('ohne Marker zeigt die Kachel einen Leerzustand', (tester) async {
    await zeige(tester);
    await tester.ensureVisible(find.text('Zustandsmarker'));
    expect(find.text('Zustandsmarker'), findsOneWidget);
    expect(_k('karto-marker-leer'), findsOneWidget);
    // Ohne laufende Dauer gibt es nichts weiterzuzählen.
    expect(_k('karto-marker-runde'), findsNothing);
    expect(_k('karto-marker-neu'), findsOneWidget);
  });

  testWidgets('zeigt Name, Notiz und Dauer je Marker', (tester) async {
    await zeige(tester, marker: [_furcht, _schmerz, _betaeubt]);
    await tester.ensureVisible(_k('karto-marker-a'));
    expect(find.text('Furcht'), findsOneWidget);
    expect(tester.widget<Text>(_k('karto-marker-a-dauer')).data, '3 Runden');
    expect(find.text('Kopfwunde'), findsOneWidget);
    // Ohne Dauer gibt es keine Schritte.
    expect(_k('karto-marker-b-dauer'), findsNothing);
    expect(tester.widget<Text>(_k('karto-marker-c-dauer')).data, 'abgelaufen');
  });

  testWidgets('neuer Marker: Vorschlag, Dauer, Speichern schreibt nur die '
      'Markerliste', (tester) async {
    final repo = await zeige(tester);
    await tippe(tester, _k('karto-marker-neu'));
    await tester.tap(_k('karto-marker-vorschlag-Betäubung'));
    await tester.pump();
    await tester.enterText(_k('karto-marker-dauer'), '4');
    await tester.enterText(_k('karto-marker-notiz'), 'Giftpfeil');
    await tippe(tester, _k('karto-marker-speichern'));

    final liste = await gespeichert(repo);
    expect(liste, hasLength(1));
    expect(liste.single.name, 'Betäubung');
    expect(liste.single.rest, 4);
    expect(liste.single.notiz, 'Giftpfeil');
    expect(liste.single.id, isNotEmpty);
    final zustand = (await repo.loadHeroState('praiodan'))!;
    expect(zustand.currentLep, 25);
    expect(zustand.erschoepfung, 2);
    expect(zustand.standort, 'Gareth');
    expect(find.text('Betäubung'), findsOneWidget);
    expect(
      tester.widget<Text>(_k('karto-marker-${liste.single.id}-dauer')).data,
      '4 Runden',
    );
  });

  testWidgets('Dialog prüft Name und Dauer', (tester) async {
    final repo = await zeige(tester);
    await tippe(tester, _k('karto-marker-neu'));
    await tippe(tester, _k('karto-marker-speichern'));
    expect(find.text('Bitte einen Namen eingeben.'), findsOneWidget);

    await tester.enterText(_k('karto-marker-name'), 'Furcht');
    await tester.enterText(_k('karto-marker-dauer'), 'viel');
    await tippe(tester, _k('karto-marker-speichern'));
    expect(find.textContaining('Bitte eine Zahl'), findsOneWidget);
    expect(await gespeichert(repo), isEmpty);

    await tester.enterText(_k('karto-marker-dauer'), '');
    await tippe(tester, _k('karto-marker-speichern'));
    final liste = await gespeichert(repo);
    expect(liste.single.name, 'Furcht');
    expect(liste.single.rest, isNull);
  });

  testWidgets('Dauer: schnelle Klicks zählen vom gespeicherten Wert', (
    tester,
  ) async {
    final repo = await zeige(tester, marker: [_furcht]);
    final minus = _k('karto-marker-a-minus');
    await tester.ensureVisible(minus);
    await tester.tap(minus);
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect((await gespeichert(repo)).single.rest, 1);
    expect(tester.widget<Text>(_k('karto-marker-a-dauer')).data, '1 Runde');

    await tippe(tester, _k('karto-marker-a-plus'));
    expect((await gespeichert(repo)).single.rest, 2);
  });

  testWidgets('abgelaufen: Minus gesperrt, Marker bleibt stehen', (
    tester,
  ) async {
    final repo = await zeige(tester, marker: [_betaeubt]);
    await tippe(tester, _k('karto-marker-c-minus'));
    expect((await gespeichert(repo)).single.rest, 0);
    expect(find.text('Betäubung'), findsOneWidget);
  });

  testWidgets('Nächste Runde zählt alle laufenden Marker herunter', (
    tester,
  ) async {
    final repo = await zeige(tester, marker: [_furcht, _schmerz, _betaeubt]);
    await tippe(tester, _k('karto-marker-runde'));
    final liste = await gespeichert(repo);
    expect(liste.map((m) => m.rest), [2, null, 0]);
    expect(liste.map((m) => m.id), ['a', 'b', 'c']);
    expect(tester.widget<Text>(_k('karto-marker-a-dauer')).data, '2 Runden');
  });

  testWidgets('Nächste Runde verschwindet, sobald nichts mehr läuft', (
    tester,
  ) async {
    final repo = await zeige(
      tester,
      marker: [const ZustandsMarker(id: 'x', name: 'Kurz', rest: 1)],
    );
    await tippe(tester, _k('karto-marker-runde'));
    expect((await gespeichert(repo)).single.rest, 0);
    expect(_k('karto-marker-runde'), findsNothing);
    expect(tester.widget<Text>(_k('karto-marker-x-dauer')).data, 'abgelaufen');
  });

  testWidgets('Ändern über den Namen: Name, Dauer und Notiz', (tester) async {
    final repo = await zeige(tester, marker: [_furcht, _schmerz]);
    await tippe(tester, _k('karto-marker-a-aendern'));
    expect(find.text('Marker ändern'), findsOneWidget);
    await tester.enterText(_k('karto-marker-name'), 'Angst');
    await tester.enterText(_k('karto-marker-dauer'), '');
    await tester.enterText(_k('karto-marker-notiz'), 'Geist');
    await tippe(tester, _k('karto-marker-speichern'));

    final liste = await gespeichert(repo);
    expect(liste.first.id, 'a');
    expect(liste.first.name, 'Angst');
    expect(liste.first.rest, isNull);
    expect(liste.first.notiz, 'Geist');
    expect(liste.last, _schmerz);
  });

  testWidgets('Entfernen löscht nur diesen Marker', (tester) async {
    final repo = await zeige(tester, marker: [_furcht, _schmerz]);
    await tippe(tester, _k('karto-marker-a-entfernen'));
    expect(await gespeichert(repo), [_schmerz]);
    expect(find.text('Furcht'), findsNothing);
    await tippe(tester, _k('karto-marker-b-entfernen'));
    final zustand = (await repo.loadHeroState('praiodan'))!;
    expect(zustand.zustandsmarker, isEmpty);
    expect(zustand.toJson().containsKey('zustandsmarker'), isFalse);
  });

  testWidgets('schmal mit Textfaktor 2 ohne Überlauf', (tester) async {
    await zeige(
      tester,
      marker: [_furcht, _schmerz, _betaeubt],
      breite: 360,
      skalierung: 2,
    );
    await tester.ensureVisible(_k('karto-marker-a'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('breit: die Marker stehen in zwei Spalten', (tester) async {
    await zeige(tester, marker: [_furcht, _schmerz], breite: 1600);
    await tester.ensureVisible(_k('karto-marker-a'));
    expect(tester.takeException(), isNull);
    expect(_k('karto-marker-a'), findsOneWidget);
    expect(_k('karto-marker-b'), findsOneWidget);
  });
}
