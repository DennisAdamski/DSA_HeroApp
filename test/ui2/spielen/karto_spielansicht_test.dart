import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

import '../shell/karto_test_support.dart';

/// Weltlicher Held: weder Magie noch göttliche Ressourcen aktiviert.
HeroSheet weltlich() => testHero('praiodan', 'Praiodan');

/// Magischer Held über den ausdrücklichen Aktivierungs-Override.
HeroSheet magisch() => testHero('liora', 'Liora').copyWith(
  resourceActivationConfig: const HeroResourceActivationConfig(
    magicEnabledOverride: true,
  ),
);

/// Geweihter Held über den ausdrücklichen Aktivierungs-Override.
HeroSheet geweiht() => testHero('tsaiane', 'Tsaiane').copyWith(
  resourceActivationConfig: const HeroResourceActivationConfig(
    divineEnabledOverride: true,
  ),
);

/// Held mit den übergebenen Abenteuern.
HeroSheet mitAbenteuern(List<HeroAdventureEntry> abenteuer) =>
    weltlich().copyWith(adventures: abenteuer);

const _nebel = HeroAdventureEntry(
  id: 'nebel',
  title: 'Die Spuren im Nebel',
  summary: 'Die Gruppe folgt der Spur des Nebelreiters.',
  startAventurianDate: HeroAdventureDateValue(
    day: '1',
    month: 'phex',
    year: '1043',
  ),
  currentAventurianDate: HeroAdventureDateValue(
    day: '12',
    month: 'phex',
    year: '1043',
  ),
);

void main() {
  Future<ProviderContainer> zeige(
    WidgetTester tester, {
    required HeroSheet held,
    FakeRepository? repository,
    Map<String, HeroState>? zustaende,
    TestBestand? bestand,
    double breite = 390,
    double skalierung = 1,
    Brightness helligkeit = Brightness.light,
    Future<bool> Function()? vorAbenteuer,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(
          repository ?? FakeRepository(heroes: [held], states: zustaende),
        ),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: helligkeit,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: KartoSpielansicht(
              heroId: held.id,
              bestand: bestand ?? TestBestand(),
              aktion: (auftrag) => auftrag(),
              vorAbenteuerbearbeitung: vorAbenteuer ?? () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder ressource(KartoRessource art) =>
      find.byKey(ValueKey<String>('karto-ressource-${art.name}'));

  testWidgets('weltlicher Held zeigt nur LeP und AuP', (tester) async {
    await zeige(tester, held: weltlich());
    expect(ressource(KartoRessource.lebensenergie), findsOneWidget);
    expect(ressource(KartoRessource.ausdauer), findsOneWidget);
    expect(ressource(KartoRessource.astralenergie), findsNothing);
    expect(ressource(KartoRessource.karma), findsNothing);
    expect(find.text('Astralpunkte'), findsNothing);
  });

  testWidgets('magischer Held zeigt zusätzlich AsP, aber kein KaP', (
    tester,
  ) async {
    await zeige(tester, held: magisch());
    expect(ressource(KartoRessource.astralenergie), findsOneWidget);
    expect(ressource(KartoRessource.karma), findsNothing);
  });

  testWidgets('geweihter Held zeigt zusätzlich KaP, aber kein AsP', (
    tester,
  ) async {
    await zeige(tester, held: geweiht());
    expect(ressource(KartoRessource.karma), findsOneWidget);
    expect(ressource(KartoRessource.astralenergie), findsNothing);
  });

  testWidgets('Bearbeiten reicht genau die angetippte Ressource weiter', (
    tester,
  ) async {
    final bestand = TestBestand();
    await zeige(tester, held: magisch(), bestand: bestand);
    await tester.tap(find.byTooltip('Astralpunkte ändern'));
    await tester.pumpAndSettle();
    expect(bestand.aufrufe, ['ressource:liora:astralenergie']);
  });

  testWidgets('gelöschter Held führt in einen erklärten Zustand', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [weltlich()]);
    await zeige(tester, held: weltlich(), repository: repo);
    await repo.deleteHero('praiodan');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Spielwerte konnten nicht geladen werden'),
      findsOneWidget,
    );
    expect(find.text('Wiederholen'), findsOneWidget);
  });

  testWidgets('Ladefehler bietet einen Rückweg statt einer leeren Fläche', (
    tester,
  ) async {
    await zeige(
      tester,
      held: weltlich(),
      repository: _LesefehlerRepository(weltlich()),
    );
    expect(
      find.textContaining('Spielwerte konnten nicht geladen werden'),
      findsOneWidget,
    );
  });

  testWidgets('gespeicherter Zustand erscheint unverkürzt in der Anzeige', (
    tester,
  ) async {
    await zeige(
      tester,
      held: weltlich(),
      zustaende: {'praiodan': const HeroState.empty().copyWith(currentLep: -3)},
    );
    expect(find.textContaining('-3 /'), findsOneWidget);
  });

  testWidgets('Ressourcenänderung im Repository schlägt in der Anzeige durch', (
    tester,
  ) async {
    final repo = FakeRepository(heroes: [weltlich()]);
    await zeige(tester, held: weltlich(), repository: repo);
    final vorher = await repo.loadHeroState('praiodan');
    await repo.saveHeroState(
      'praiodan',
      (vorher ?? const HeroState.empty()).copyWith(currentLep: 7),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('7 /'), findsOneWidget);
  });

  group('laufendes Abenteuer im Seitenkopf', () {
    testWidgets('das Abenteuer trägt den Titel, die Ansicht den Kontext', (
      tester,
    ) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1024);
      final titel = tester.widget<Text>(find.text('Die Spuren im Nebel'));
      final theme = Theme.of(tester.element(find.text('Die Spuren im Nebel')));
      expect(titel.style!.fontSize, theme.textTheme.titelGross.fontSize);
      expect(find.text('Am Spieltisch'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Am Spieltisch')).dy,
        lessThan(tester.getTopLeft(find.text('Die Spuren im Nebel')).dy),
      );
      expect(find.text('12. Phex 1043 BF'), findsOneWidget);
      expect(
        find.text('Die Gruppe folgt der Spur des Nebelreiters.'),
        findsOneWidget,
      );
    });

    testWidgets('ohne aktuellen Stand gilt das Startdatum', (tester) async {
      await zeige(
        tester,
        held: mitAbenteuern([
          _nebel.copyWith(
            currentAventurianDate: const HeroAdventureDateValue(),
          ),
        ]),
      );
      expect(find.text('1. Phex 1043 BF'), findsOneWidget);
    });

    testWidgets('Abenteuer öffnen prüft zuerst die Verwaltung', (tester) async {
      var geprueft = 0;
      await zeige(
        tester,
        held: mitAbenteuern([_nebel]),
        breite: 1024,
        vorAbenteuer: () async {
          geprueft++;
          return false;
        },
      );
      await tester.tap(find.byKey(const ValueKey('karto-spiel-abenteuer')));
      await tester.pumpAndSettle();
      expect(geprueft, 1);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Abenteuer öffnen zeigt das Abenteuerblatt', (tester) async {
      await zeige(tester, held: mitAbenteuern([_nebel]), breite: 1024);
      await tester.tap(find.byKey(const ValueKey('karto-spiel-abenteuer')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Notizen'), findsOneWidget);
    });

    testWidgets('abgeschlossene Abenteuer bleiben aus dem Kopf', (
      tester,
    ) async {
      await zeige(
        tester,
        held: mitAbenteuern([
          _nebel.copyWith(status: HeroAdventureStatus.completed),
        ]),
      );
      final theme = Theme.of(tester.element(find.text('Am Spieltisch')));
      expect(
        tester.widget<Text>(find.text('Am Spieltisch')).style!.fontSize,
        theme.textTheme.titel.fontSize,
      );
      expect(find.text('Die Spuren im Nebel'), findsNothing);
      expect(find.textContaining('Phex'), findsNothing);
      expect(find.byKey(const ValueKey('karto-spiel-abenteuer')), findsNothing);
    });
  });

  for (final breite in [320.0, 390.0, 744.0, 1024.0, 1440.0]) {
    testWidgets('Spielansicht bei $breite dp ohne Überlauf', (tester) async {
      // Mit Abenteuerkopf: Titel, Datum und Zusammenfassung sind die
      // laengsten Zeilen der Ansicht.
      await zeige(
        tester,
        held: magisch().copyWith(adventures: const [_nebel]),
        breite: breite,
        skalierung: 2,
      );
      expect(ressource(KartoRessource.lebensenergie), findsOneWidget);
      expect(find.text('Ressourcen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dunkle Palette rendert dieselbe Anordnung', (tester) async {
    await zeige(
      tester,
      held: geweiht(),
      breite: 1440,
      helligkeit: Brightness.dark,
    );
    expect(ressource(KartoRessource.karma), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Repository, dessen Zustandsstrom fehlschlägt.
class _LesefehlerRepository extends FakeRepository {
  _LesefehlerRepository(HeroSheet held) : super(heroes: [held]);

  @override
  Stream<HeroState> watchHeroState(String heroId) =>
      Stream<HeroState>.error(StateError('Lesefehler'));
}
