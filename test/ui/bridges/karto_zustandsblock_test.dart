import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifikator_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';

import '../../ui2/shell/karto_test_support.dart';

/// Der Zustandsblock der Spielansicht stellt in einer weiten Kachel zwei
/// Spalten nebeneinander (SPIEL-07): links Belastung über Wunden, beide
/// aufgeklappt, rechts die Statuswerte. Sonst steht alles in einer Spalte,
/// die Statuswerte als flaches Raster. Die Spielansicht lässt die Belastung
/// weg (`mitBelastung: false`), weil „Dabei“ sie führt.
void main() {
  final held = testHero('demo', 'Rondra');
  const start = HeroState(
    currentLep: 20,
    currentAsp: 0,
    currentKap: 3,
    currentAu: 18,
  );

  Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));

  Future<FakeRepository> zeige(
    WidgetTester tester, {
    required double breite,
    KartoKachelGroesse? groesse = KartoKachelGroesse.weit,
    double skalierung = 1,
    HeroState zustand = start,
    bool mitBelastung = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite + 40, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(heroes: [held], states: {'demo': zustand});
    final werte = buildHeroComputedSnapshot(
      hero: held,
      state: zustand,
      catalog: null,
      epicAdvantagesActive: false,
    );
    final block = KartoZustandsblock(
      heroId: 'demo',
      werte: werte,
      mitBelastung: mitBelastung,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Wie in der Spielansicht beobachtet der Baum den Helden.
                ref.watch(heroByIdProvider('demo'));
                return SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: breite,
                      child: groesse == null
                          ? block
                          : KartoKachelSteuerung(
                              kennung: 'zustand',
                              groesse: groesse,
                              child: block,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('weit und breit genug: zwei Spalten', () {
    testWidgets('Statuswerte stehen rechts neben Belastung und Wunden', (
      tester,
    ) async {
      await zeige(tester, breite: 700);
      final links = tester.getRect(k('karto-zustand-links'));
      final rechts = tester.getRect(k('karto-zustand-rechts'));
      expect(rechts.left, greaterThanOrEqualTo(links.right));
      expect(
        find.descendant(
          of: k('karto-zustand-rechts'),
          matching: find.text('Statuswerte'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: k('karto-zustand-rechts'),
          matching: k('workspace-status-row-AT'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Belastung und Wunden sind von Anfang an aufgeklappt', (
      tester,
    ) async {
      await zeige(tester, breite: 700);
      expect(k('workspace-vital-row-erschoepfung'), findsOneWidget);
      expect(k('workspace-vital-row-ueberanstrengung'), findsOneWidget);
      expect(find.byTooltip('Wunde hinzufügen'), findsNWidgets(8));
      // Beides liegt in der linken Spalte.
      expect(
        find.descendant(
          of: k('karto-zustand-links'),
          matching: find.byTooltip('Wunde hinzufügen'),
        ),
        findsNWidgets(8),
      );
    });

    testWidgets('neben den anderen Abschnitten steht keine Trennlinie', (
      tester,
    ) async {
      await zeige(tester, breite: 700);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('der Nutzer kann die aufgeklappten Abschnitte einklappen', (
      tester,
    ) async {
      await zeige(tester, breite: 700);
      await tester.tap(find.text('Wunden'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Wunde hinzufügen'), findsNothing);
      expect(k('workspace-vital-row-erschoepfung'), findsOneWidget);
    });
  });

  group('sonst eine Spalte wie bisher', () {
    Future<void> pruefeEineSpalte(WidgetTester tester) async {
      expect(k('karto-zustand-links'), findsNothing);
      expect(k('karto-zustand-rechts'), findsNothing);
      // Eingeklappt: weder Zonenzeilen noch Belastungszeilen.
      expect(find.byTooltip('Wunde hinzufügen'), findsNothing);
      expect(k('workspace-vital-row-erschoepfung'), findsNothing);
      // Die Statuswerte stehen darunter, mit ihrer Trennlinie, als Raster.
      expect(find.text('Statuswerte'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(k('workspace-status-kachel-AT'), findsOneWidget);
      expect(k('workspace-status-row-AT'), findsNothing);
      final belastung = tester.getTopLeft(find.text('Belastung'));
      final statuswerte = tester.getTopLeft(find.text('Statuswerte'));
      expect(statuswerte.dy, greaterThan(belastung.dy));
      expect(statuswerte.dx, belastung.dx);
    }

    testWidgets('weit, aber zu schmal für zwei Spalten', (tester) async {
      await zeige(tester, breite: KartoZustandsblock.zweiSpaltenAb - 1);
      await pruefeEineSpalte(tester);
    });

    for (final groesse in [
      KartoKachelGroesse.kompakt,
      KartoKachelGroesse.normal,
    ]) {
      testWidgets('${groesse.name} bleibt eine Spalte, auch breit', (
        tester,
      ) async {
        await zeige(tester, breite: 900, groesse: groesse);
        await pruefeEineSpalte(tester);
      });
    }

    testWidgets('außerhalb einer Kachel bleibt es eine Spalte', (tester) async {
      await zeige(tester, breite: 900, groesse: null);
      await pruefeEineSpalte(tester);
    });

    testWidgets('genau an der Schwelle sind es zwei Spalten', (tester) async {
      await zeige(tester, breite: KartoZustandsblock.zweiSpaltenAb);
      expect(k('karto-zustand-links'), findsOneWidget);
    });
  });

  group('ohne Belastung (Spielansicht)', () {
    testWidgets('eine Spalte: nur Wunden und Statuswerte', (tester) async {
      await zeige(tester, breite: 300, mitBelastung: false);
      expect(find.text('Belastung'), findsNothing);
      expect(find.text('Wunden'), findsOneWidget);
      expect(k('workspace-status-kachel-BE'), findsOneWidget);
    });

    testWidgets('zwei Spalten: links nur die Wunden', (tester) async {
      await zeige(tester, breite: 700, mitBelastung: false);
      expect(find.text('Belastung'), findsNothing);
      expect(k('workspace-vital-row-erschoepfung'), findsNothing);
      expect(
        find.descendant(
          of: k('karto-zustand-links'),
          matching: find.text('Wunden'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Statuswert-Raster', () {
    testWidgets('vier Spalten in einer schmalen Kachel, zwei Reihen', (
      tester,
    ) async {
      await zeige(
        tester,
        breite: 270,
        groesse: KartoKachelGroesse.kompakt,
        mitBelastung: false,
      );
      final ini = tester.getRect(k('workspace-status-kachel-Ini'));
      final pa = tester.getRect(k('workspace-status-kachel-PA'));
      final at = tester.getRect(k('workspace-status-kachel-AT'));
      final be = tester.getRect(k('workspace-status-kachel-BE'));
      expect(pa.top, ini.top);
      expect(at.top, greaterThan(ini.bottom));
      expect(be.top, at.top);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tipp öffnet das Blatt, Schritte schreiben frisch', (
      tester,
    ) async {
      final repo = await zeige(
        tester,
        breite: 300,
        groesse: KartoKachelGroesse.kompakt,
        mitBelastung: false,
      );
      await tester.tap(k('workspace-status-kachel-AT'));
      await tester.pumpAndSettle();
      expect(k('workspace-status-blatt-AT'), findsOneWidget);

      // Das Blatt bleibt für mehrere Schritte offen.
      await tester.tap(find.byTooltip('AT erhöhen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('AT erhöhen'));
      await tester.pumpAndSettle();
      final danach = (await repo.loadHeroById('demo'))!;
      expect(
        dauermodifikatorWert(danach.persistentMods, Dauermodifikator.at),
        2,
      );

      await tester.tap(k('workspace-status-blatt-schliessen'));
      await tester.pumpAndSettle();
      expect(k('workspace-status-blatt-AT'), findsNothing);
    });

    testWidgets('MR ist nur Anzeige und öffnet nichts', (tester) async {
      await zeige(
        tester,
        breite: 300,
        groesse: KartoKachelGroesse.kompakt,
        mitBelastung: false,
      );
      await tester.tap(k('workspace-status-kachel-MR'));
      await tester.pumpAndSettle();
      expect(k('workspace-status-blatt-MR'), findsNothing);
    });

    for (final breite in [240.0, 300.0]) {
      testWidgets('bei $breite dp und Schrift 2.0 ohne Überlauf', (
        tester,
      ) async {
        await zeige(
          tester,
          breite: breite,
          groesse: KartoKachelGroesse.kompakt,
          skalierung: 2,
          mitBelastung: false,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Schreiben in der Zweispaltenform', () {
    testWidgets('zwei Änderungen zählen vom gespeicherten Stand', (
      tester,
    ) async {
      final repo = await zeige(tester, breite: 700);
      // Bauchwunde (Zone 2; die Kopfwunde würfelt zuerst die INI).
      await tester.tap(find.byTooltip('Wunde hinzufügen').at(2));
      await tester.pumpAndSettle();
      // Nach einer Wunde fragt die App, ob sie unterdrückt werden soll.
      await tester.tap(find.text('Nein'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Erschöpfung erhöhen'));
      await tester.pumpAndSettle();

      final danach = (await repo.loadHeroState('demo'))!;
      expect(danach.wpiZustand.wundenInZone(WundZone.bauch), 1);
      expect(danach.erschoepfung, 1);
      // Alles andere bleibt, wie es gespeichert war.
      expect(danach.currentLep, 20);
      expect(danach.currentAu, 18);
      expect(danach.currentKap, 3);
    });

    testWidgets('ein Statuswert schreibt über den Helden', (tester) async {
      final repo = await zeige(tester, breite: 700);
      final vorher = (await repo.loadHeroById('demo'))!;
      expect(
        dauermodifikatorWert(vorher.persistentMods, Dauermodifikator.at),
        0,
      );
      await tester.tap(find.byTooltip('AT erhöhen'));
      await tester.pumpAndSettle();
      final danach = (await repo.loadHeroById('demo'))!;
      expect(
        dauermodifikatorWert(danach.persistentMods, Dauermodifikator.at),
        1,
      );
    });
  });

  group('Platz', () {
    for (final breite in [624.0, 700.0, 900.0, 1400.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('bei $breite dp und Schrift $skalierung ohne Überlauf', (
          tester,
        ) async {
          await zeige(tester, breite: breite, skalierung: skalierung);
          expect(tester.takeException(), isNull);
          expect(k('karto-zustand-links'), findsOneWidget);
        });
      }
    }

    testWidgets('mit Wunden und Belastung bei 700 dp ohne Überlauf', (
      tester,
    ) async {
      await zeige(
        tester,
        breite: 700,
        zustand: start.copyWith(
          erschoepfung: 3,
          ueberanstrengung: 2,
          wpiZustand: const WundZustand(
            wundenProZone: {WundZone.rechterArm: 2, WundZone.bauch: 3},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
