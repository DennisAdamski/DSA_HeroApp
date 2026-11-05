import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_wuerfelprotokoll.dart';

import '../../ui2/shell/karto_test_support.dart';

/// Die Protokoll-Kachel der Spielansicht zeigt in einer weiten Kachel mehr
/// Würfe als Tabelle (SPIEL-07); sonst bleibt es bei den Karten.
void main() {
  const adapter = KartoBestandsAdapterImpl();

  List<DiceLogEntry> wuerfe(int anzahl) => [
    for (var i = 0; i < anzahl; i++)
      DiceLogEntry(
        timestamp: DateTime.utc(2026, 9, 20, 20, i),
        type: i.isEven ? ProbeType.talent : ProbeType.attribute,
        title: 'Wurf $i',
        subtitle: 'MU/KL/GE',
        success: i % 3 != 0,
        diceValues: i.isEven ? const [5, 8, 12] : const [9],
        targetValue: 12,
        zielwerte: i.isEven ? const [12, 13, 14] : const <int>[],
        restpunkte: i.isEven ? 3 : null,
      ),
  ];

  Future<void> zeige(
    WidgetTester tester, {
    required int anzahl,
    KartoKachelGroesse? groesse,
    double breite = 900,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: [testHero()],
      states: {
        'rondra': const HeroState.empty().copyWith(diceLog: wuerfe(anzahl)),
      },
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  final werte = ref
                      .watch(heroComputedProvider('rondra'))
                      .asData
                      ?.value;
                  if (werte == null) return const CircularProgressIndicator();
                  final kachel = KartoProtokollAbschnitt(
                    heroId: 'rondra',
                    werte: werte,
                    bestand: adapter,
                  );
                  return groesse == null
                      ? kachel
                      : KartoKachelSteuerung(
                          kennung: 'protokoll',
                          groesse: groesse,
                          child: kachel,
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final kopf = find.byKey(const ValueKey('dice-log-tabellenkopf'));
  Finder zeilen() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('dice-log-zeile-'),
  );

  testWidgets('weit zeigt acht Würfe als Tabelle mit Kopfzeile', (
    tester,
  ) async {
    await zeige(tester, anzahl: 12, groesse: KartoKachelGroesse.weit);
    expect(kopf, findsOneWidget);
    expect(zeilen(), findsNWidgets(kProtokollWeit));
    // Die neuesten stehen oben.
    expect(find.text('Wurf 11'), findsOneWidget);
    expect(find.text('Wurf 4'), findsOneWidget);
    expect(find.text('Wurf 3'), findsNothing);
    expect(find.text('Alle anzeigen (12)'), findsOneWidget);
    // Die Spalten tragen Würfe, Ziele und Restpunkte.
    expect(find.text('5 · 8 · 12'), findsWidgets);
    expect(find.text('12/13/14'), findsWidgets);
    expect(find.text('TaP*: 3'), findsWidgets);
  });

  testWidgets('bis acht Würfe gibt es in der weiten Stufe nichts zu öffnen', (
    tester,
  ) async {
    await zeige(tester, anzahl: 8, groesse: KartoKachelGroesse.weit);
    expect(zeilen(), findsNWidgets(8));
    expect(
      find.byKey(const ValueKey<String>('karto-spiel-protokoll-alle')),
      findsNothing,
    );
  });

  testWidgets('kompakt, normal und ohne Kachel bleiben bei fünf Karten', (
    tester,
  ) async {
    for (final groesse in [
      null,
      KartoKachelGroesse.kompakt,
      KartoKachelGroesse.normal,
    ]) {
      await zeige(tester, anzahl: 12, groesse: groesse);
      expect(kopf, findsNothing, reason: '$groesse');
      expect(zeilen(), findsNothing, reason: '$groesse');
      expect(find.text('Wurf 11'), findsOneWidget, reason: '$groesse');
      expect(find.text('Wurf 7'), findsOneWidget, reason: '$groesse');
      expect(find.text('Wurf 6'), findsNothing, reason: '$groesse');
      expect(find.text('Alle anzeigen (12)'), findsOneWidget);
    }
  });

  testWidgets('zu schmal oder mit großer Schrift fallen die Karten zurück', (
    tester,
  ) async {
    await zeige(
      tester,
      anzahl: 12,
      groesse: KartoKachelGroesse.weit,
      breite: 500,
    );
    expect(kopf, findsNothing);
    expect(find.text('Wurf 11'), findsOneWidget);
    // Die Grenze der Stufe gilt trotzdem.
    expect(find.text('Wurf 4'), findsOneWidget);

    await zeige(
      tester,
      anzahl: 12,
      groesse: KartoKachelGroesse.weit,
      skalierung: 2,
    );
    expect(kopf, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('Tabelle ohne Überlauf bei $breite dp', (tester) async {
      await zeige(
        tester,
        anzahl: 12,
        groesse: KartoKachelGroesse.weit,
        breite: breite,
      );
      expect(kopf, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
