import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_begleiterkarte.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelraster.dart';
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
    SpielkachelBreite? kachel,
    double skalierung = 1,
  }) async {
    final held = testHero('hexe', 'Hexe').copyWith(
      companions: begleiter,
      spielansicht: kachel == null
          ? null
          : HeroSpielansicht(
              kacheln: [HeroSpielkachel(id: 'begleiter', breite: kachel)],
            ),
    );
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
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

  testWidgets('breit steht der Abschnitt im Raster neben anderen Kacheln, '
      'vor dem Protokoll', (tester) async {
    await zeige(tester, begleiter: const [mira], breite: 1400);
    expect(find.text('Begleiter'), findsOneWidget);
    final begleiter = tester.getTopLeft(find.text('Begleiter'));
    final protokoll = tester.getTopLeft(find.text('Würfelprotokoll'));
    final ressourcen = tester.getTopLeft(find.text('Ressourcen').first);
    // Eine schmale Kachel steht nicht in der ersten Spalte unter allem,
    // sondern rechts davon; die Standardreihenfolge hält sie vor dem Protokoll.
    expect(begleiter.dx, greaterThan(ressourcen.dx + kRasterEinheitMin));
    expect(begleiter.dy, lessThan(protokoll.dy));
  });

  group('weite Kachel (SPIEL-07)', () {
    const wolf = HeroCompanion(
      id: 'wolf',
      name: 'Wolf',
      typ: BegleiterTyp.sonstigerBegleiter,
      maxLep: 30,
      startLep: 30,
      geschwindigkeiten: [HeroCompanionSpeed(art: 'Boden', wert: 9)],
      angriffe: [
        HeroCompanionAttack(
          id: 'a1',
          name: 'Biss',
          dk: 'H',
          at: 12,
          pa: 8,
          tp: '1W6+2',
        ),
      ],
    );

    Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));
    String text(WidgetTester tester, String schluessel) =>
        tester.widget<Text>(k(schluessel)).data!;

    testWidgets('weit zeigt die Kampfwerte aus dem Kampfprofil', (
      tester,
    ) async {
      await zeige(
        tester,
        begleiter: const [wolf],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      final p = begleiterKampfprofil(wolf);
      expect(
        text(tester, 'karto-begleiter-wolf-kampfwerte'),
        [
          if (p.ini != null) 'INI ${p.ini}',
          'RS ${p.rs}',
          'BE ${p.be}',
          if (p.mr != null) 'MR ${p.mr}',
          ...p.geschwindigkeiten,
        ].join(' \u00b7 '),
      );
      expect(
        text(tester, 'karto-begleiter-wolf-kampfwerte'),
        contains('Boden 9'),
      );
      final angriff = text(tester, 'karto-begleiter-wolf-angriff-0');
      expect(angriff, contains('Biss'));
      expect(angriff, contains('AT ${p.angriffe.first.at}'));
      expect(angriff, contains('PA ${p.angriffe.first.pa}'));
      expect(angriff, contains('TP 1W6+2'));
      expect(angriff, contains('DK H'));
    });

    testWidgets('standardmäßig schmal zeigt sie keine Kampfwerte', (
      tester,
    ) async {
      for (final breite in [390.0, 1280.0, 1920.0]) {
        await zeige(tester, begleiter: const [wolf], breite: breite);
        expect(
          k('karto-begleiter-wolf-kampf'),
          findsNothing,
          reason: '$breite',
        );
        expect(wert('wolf', 'lep'), findsOneWidget);
      }
    });

    testWidgets('mittel bei 1440 dp ist weit', (tester) async {
      await zeige(
        tester,
        begleiter: const [wolf],
        breite: 1440,
        kachel: SpielkachelBreite.mittel,
      );
      expect(k('karto-begleiter-wolf-kampf'), findsOneWidget);
    });

    testWidgets('eine breite Karte stellt Werte und Kampfwerte nebeneinander', (
      tester,
    ) async {
      await zeige(
        tester,
        begleiter: const [wolf],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      final lep = tester.getRect(wert('wolf', 'lep'));
      final kampf = tester.getRect(k('karto-begleiter-wolf-kampf'));
      expect(kampf.left, greaterThan(lep.right));
    });

    testWidgets('mehrere Begleiter stehen nebeneinander', (tester) async {
      await zeige(
        tester,
        begleiter: const [mira, wolf],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      final a = tester.getRect(k('karto-begleiter-mira'));
      final b = tester.getRect(k('karto-begleiter-wolf'));
      expect(b.left, greaterThanOrEqualTo(a.right));
      expect(b.top, a.top);
      // Jede Karte ist breit genug für ihre Werte.
      expect(
        a.width,
        greaterThanOrEqualTo(KartoBegleiterAbschnitt.kartenbreiteMin),
      );
    });

    testWidgets('schmale Karten stapeln Werte und Kampfwerte', (tester) async {
      await zeige(
        tester,
        begleiter: const [mira, wolf],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      final lep = tester.getRect(wert('wolf', 'lep'));
      final kampf = tester.getRect(k('karto-begleiter-wolf-kampf'));
      expect(kampf.top, greaterThanOrEqualTo(lep.bottom));
    });

    testWidgets('ohne Angriffe zeigt der Block nur die Kopfzeile', (
      tester,
    ) async {
      await zeige(
        tester,
        begleiter: const [rosse],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      expect(k('karto-begleiter-rosse-kampfwerte'), findsOneWidget);
      expect(k('karto-begleiter-rosse-angriff-0'), findsNothing);
    });

    testWidgets('Bedienung der Werte bleibt in der weiten Kachel', (
      tester,
    ) async {
      final bestand = await zeige(
        tester,
        begleiter: const [mira],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      await tester.tap(
        find.byKey(const ValueKey('karto-begleiter-mira-lep-plus-1')),
      );
      await tester.pump();
      expect(bestand.aufrufe, ['begleiter:hexe:mira:lep:schritt1']);
    });

    testWidgets('der Vergrößern-Dialog zeigt die Kampfwerte', (tester) async {
      await zeige(tester, begleiter: const [wolf], breite: 1280);
      expect(k('karto-begleiter-wolf-kampf'), findsNothing);
      await tester.tap(k('karto-kachel-begleiter-vergroessern'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-begleiter-popup'),
          matching: k('karto-begleiter-wolf-kampf'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Anordnen: die Vorschau zeigt die Kampfwerte', (tester) async {
      await zeige(
        tester,
        begleiter: const [wolf],
        breite: 1280,
        kachel: SpielkachelBreite.mittel,
      );
      await tester.tap(k('karto-spiel-anordnen'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-kachel-begleiter-vorschau'),
          matching: k('karto-begleiter-wolf-kampf'),
        ),
        findsOneWidget,
      );
    });

    for (final breite in [744.0, 1024.0, 1440.0, 1920.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('bei $breite dp, Schrift $skalierung, ohne Überlauf, auch '
            'im Anordnen', (tester) async {
          await zeige(
            tester,
            begleiter: const [mira, wolf, rosse],
            breite: breite,
            kachel: SpielkachelBreite.mittel,
            skalierung: skalierung,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(k('karto-spiel-anordnen'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
