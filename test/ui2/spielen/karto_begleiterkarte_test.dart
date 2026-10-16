import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

/// Abschnitt „Begleiter“ der Spielansicht (V2): laufende Werte aus dem einen
/// Snapshot, Bedienung als Änderung über die Bestandsbrücke.
void main() {
  const mira = HeroCompanion(
    id: 'mira',
    name: 'Mira',
    typ: BegleiterTyp.vertrauter,
    maxLep: 24,
    startLep: 24,
    maxAsp: 10,
    startAsp: 10,
    vertrautenBindung: VertrautenBindung(artId: 'vart_katze'),
  );
  const rosse = HeroCompanion(
    id: 'rosse',
    name: 'Rosse',
    typ: BegleiterTyp.reittier,
    maxLep: 60,
    startLep: 60,
    maxAup: 80,
    startAup: 80,
  );

  Future<TestBestand> zeige(
    WidgetTester tester, {
    required List<HeroCompanion> begleiter,
    Map<String, BegleiterZustand> werte = const {},
    double breite = 390,
  }) async {
    final held = testHero('hexe', 'Hexe').copyWith(companions: begleiter);
    final bestand = TestBestand();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: [held],
      states: {
        'hexe': const HeroState(
          currentLep: 30,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 30,
        ).copyWith(begleiterZustaende: werte),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: 'hexe',
              bestand: bestand,
              aktion: (auftrag) => auftrag(),
              vorHeldenbearbeitung: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bestand;
  }

  Finder wert(String begleiter, String pool) =>
      find.byKey(ValueKey<String>('karto-begleiter-$begleiter-$pool-wert'));

  testWidgets('ohne Begleiter entfällt der Abschnitt', (tester) async {
    await zeige(tester, begleiter: const []);
    expect(find.text('Begleiter'), findsNothing);
  });

  testWidgets('zeigt gespeicherte und volle Werte je Begleiter', (
    tester,
  ) async {
    await zeige(
      tester,
      begleiter: const [mira, rosse],
      werte: const {'mira': BegleiterZustand(currentLep: 17)},
    );

    expect(find.text('Begleiter'), findsOneWidget);
    expect(wert('mira', 'lep'), findsOneWidget);
    expect(find.text('17 / 24'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget, reason: 'AsP sind voll');
    expect(find.text('60 / 60'), findsOneWidget);
    expect(find.text('80 / 80'), findsOneWidget);
    expect(wert('rosse', 'asp'), findsNothing, reason: 'kein AsP-Maximum');
  });

  testWidgets('der Abschnitt steht nach „Zustand“ und vor dem Protokoll', (
    tester,
  ) async {
    await zeige(tester, begleiter: const [mira]);

    final zustandY = tester.getTopLeft(find.text('Zustand hexe')).dy;
    final begleiterY = tester.getTopLeft(find.text('Begleiter')).dy;
    final protokollY = tester.getTopLeft(find.text('Würfelprotokoll')).dy;
    expect(begleiterY, greaterThan(zustandY));
    expect(protokollY, greaterThan(begleiterY));
  });

  testWidgets('die Knöpfe melden Schritte, nie fertige Werte', (tester) async {
    final bestand = await zeige(tester, begleiter: const [mira]);

    await tester.tap(
      find.byKey(const ValueKey('karto-begleiter-mira-lep-minus-5')),
    );
    await tester.tap(
      find.byKey(const ValueKey('karto-begleiter-mira-asp-plus-1')),
    );
    await tester.pumpAndSettle();

    expect(bestand.aufrufe, [
      'begleiter:hexe:mira:lep:schritt-5',
      'begleiter:hexe:mira:asp:schritt1',
    ]);
  });

  testWidgets('Vertrautenaktionen gibt es nur für gebundene Vertraute', (
    tester,
  ) async {
    final bestand = await zeige(tester, begleiter: const [mira, rosse]);

    expect(
      find.byKey(const ValueKey('karto-begleiter-rosse-aktionen')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('karto-begleiter-mira-aktionen')),
    );
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['vertrautenAktionen:hexe:mira']);
  });

  testWidgets('breit steht der Abschnitt in der Seitenspalte', (tester) async {
    await zeige(tester, begleiter: const [mira], breite: 1400);
    expect(find.text('Begleiter'), findsOneWidget);
    final begleiter = tester.getTopLeft(find.text('Begleiter')).dx;
    final protokoll = tester.getTopLeft(find.text('Würfelprotokoll')).dx;
    expect(begleiter, greaterThan(protokoll));
  });
}
