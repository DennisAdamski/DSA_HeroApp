import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/kraeuter_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';

import '../../test_support/fake_repository.dart';

import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_kachel.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Wildnis-Kachel (Kräuter suchen, Wege des Entdeckers S. 113 f.): Landschaft,
// Jahreszeit, Geländekunde und Ortskenntnis kommen aus dem Helden, die Probe
// läuft über die Gefechtsbrücke, die Ausbeute rechnet die Regelfunktion.

const String _id = 'rondra';

/// Reichsforst als Regenwald-Region: ergibt genau einen Landschaftsvorschlag.
final OrtKatalog _orte = OrtKatalog(
  orte: <OrtEintrag>[
    OrtEintrag(name: 'Regenwald', art: OrtArt.region, unterart: 'Regenwald'),
    OrtEintrag(name: 'Reichsforst', art: OrtArt.region, unterart: 'Wald'),
  ],
);

/// Ein Kraut im Dschungel: Suchschwierigkeit 1 + 2 = 3.
const KraeuterKatalog _kraeuter = KraeuterKatalog(
  kraeuter: <KrautEintrag>[
    KrautEintrag(
      name: 'Donf',
      bestimmung: 1,
      wirkung: 'fiebersenkend',
      erntezeit: 'ganzjährig',
      beschreibung: 'Sumpfpflanze mit violetter Blüte.',
      quelle: 'Zoo Botanica Aventurica S. 234',
      vorkommen: <KrautVorkommen>[
        KrautVorkommen(
          landschaft: Kraeuterlandschaft.dschungel,
          haeufigkeit: Kraeuterhaeufigkeit.haeufig,
        ),
      ],
    ),
  ],
);

/// Sechs Kräuter im Dschungel, damit die Vorschau gekürzt wird.
final KraeuterKatalog _vieleKraeuter = KraeuterKatalog(
  kraeuter: <KrautEintrag>[
    ..._kraeuter.kraeuter,
    for (final name in <String>['Arganstrauch', 'Boronie', 'Finage', 'Kukura'])
      KrautEintrag(
        name: name,
        bestimmung: 4,
        beschreibungGesperrt: true,
        vorkommen: const <KrautVorkommen>[
          KrautVorkommen(
            landschaft: Kraeuterlandschaft.dschungel,
            haeufigkeit: Kraeuterhaeufigkeit.selten,
          ),
        ],
      ),
    const KrautEintrag(
      name: 'Quinya',
      bestimmung: 6,
      vorkommen: <KrautVorkommen>[
        KrautVorkommen(
          landschaft: Kraeuterlandschaft.dschungel,
          haeufigkeit: Kraeuterhaeufigkeit.gelegentlich,
        ),
      ],
    ),
  ],
);

HeroAdventureEntry _abenteuer(String monat) => HeroAdventureEntry(
  id: 'a',
  title: 'Der lange Weg',
  currentAventurianDate: HeroAdventureDateValue(
    day: '5',
    month: monat,
    year: '1043',
  ),
);

HeroSheet _held({
  List<String> sonderfertigkeiten = const <String>[],
  String? monat = 'praios',
}) => testHero(_id).copyWith(
  talents: const <String, HeroTalentEntry>{
    'tal_sinnesschaerfe': HeroTalentEntry(talentValue: 10),
    'tal_wildnisleben': HeroTalentEntry(talentValue: 8),
    'tal_pflanzenkunde': HeroTalentEntry(talentValue: 9),
  },
  talentSpecialAbilities: <TalentSpecialAbility>[
    for (final name in sonderfertigkeiten) TalentSpecialAbility(name: name),
  ],
  adventures: <HeroAdventureEntry>[if (monat != null) _abenteuer(monat)],
);

/// Ein Jäger mit Kurzbogen und Scharfschütze (Bogen): Pirschjagd-TaW
/// (8 + 6 + 7 + 5 + 9) / 5 = 7.
HeroSheet _jaeger() => _held().copyWith(
  talents: const <String, HeroTalentEntry>{
    'tal_wildnisleben': HeroTalentEntry(talentValue: 8),
    'tal_tierkunde': HeroTalentEntry(talentValue: 6),
    'tal_faehrtensuchen': HeroTalentEntry(talentValue: 7),
    'tal_schleichen': HeroTalentEntry(talentValue: 5),
    'tal_bogen': HeroTalentEntry(talentValue: 9),
  },
  combatConfig: const CombatConfig(
    weapons: <MainWeaponSlot>[
      MainWeaponSlot(
        id: 'w1',
        name: 'Kurzbogen',
        talentId: 'tal_bogen',
        combatType: WeaponCombatType.ranged,
      ),
    ],
    specialRules: CombatSpecialRules(
      activeManeuvers: <String>['man_scharfschuetze::tal_bogen'],
    ),
  ),
);

/// Ein Jäger wie [_jaeger], dessen Kurzbogen 12 Jagdpfeile führt.
HeroSheet _jaegerMitPfeilen() {
  final jaeger = _jaeger();
  final bogen = jaeger.combatConfig.weapons.single;
  return jaeger.copyWith(
    combatConfig: jaeger.combatConfig.copyWith(
      weapons: <MainWeaponSlot>[
        bogen.copyWith(
          rangedProfile: bogen.rangedProfile.copyWith(
            projectiles: const <RangedProjectile>[
              RangedProjectile(id: 'p1', name: 'Jagdpfeile', count: 12),
            ],
            selectedProjectileIndex: 0,
          ),
        ),
      ],
    ),
  );
}

/// Würfel mit festen Ergebnissen in der angegebenen Reihenfolge.
class _FesteWuerfel implements DiceRoller {
  _FesteWuerfel(this.werte);

  final List<int> werte;
  var _naechster = 0;

  @override
  int rollDie(int sides) => werte[_naechster++];
}

/// Gefechtsbrücke, die Ausrüstungsänderungen wie die App schreibt.
class _AusruestungsBestand extends GefechtsTestBestand {
  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) => const KartoBestandsAdapterImpl().gefechtsAusruestung(
    context: context,
    ref: ref,
    heroId: heroId,
    aenderung: aenderung,
  );
}

void main() {
  Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));
  late FakeRepository repository;

  Future<void> zeige(
    WidgetTester tester, {
    required HeroSheet held,
    String standort = 'Regenwald',
    KartoBestandsAdapter? bestand,
    double breite = 480,
    double skalierung = 1,
    KraeuterKatalog kraeuter = _kraeuter,
    int asp = 30,
    DiceRoller? wuerfler,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 3200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final zustand = const HeroState.empty().copyWith(
      standort: standort,
      currentAsp: asp,
    );
    final werte = buildHeroComputedSnapshot(
      hero: held,
      state: zustand,
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    repository = FakeRepository(
      heroes: [held],
      states: <String, HeroState>{held.id: zustand},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repository),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ortKatalogProvider.overrideWith((ref) async => _orte),
        kraeuterKatalogProvider.overrideWith((ref) async => kraeuter),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: KartoKachelSteuerung(
                kennung: 'wildnis',
                groesse: KartoKachelGroesse.fuerBreite(breite - 32),
                dicht: false,
                child: KartoWildnisKachel(
                  heroId: held.id,
                  werte: werte,
                  bestand: bestand ?? TestBestand(),
                  aktion: (auftrag) => auftrag(),
                  wuerfler: wuerfler,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String zusammenfassung() =>
      (k('karto-wildnis-zusammenfassung').evaluate().single.widget as Text)
          .data!;

  String erschwernisHinweis() =>
      (k('karto-wildnis-erschwernis-hinweis').evaluate().single.widget as Text)
          .data!;

  Future<void> waehleTaetigkeit(WidgetTester tester, String id) async {
    await tester.tap(k('karto-wildnis-taetigkeit-$id'));
    await tester.pumpAndSettle();
  }

  Future<void> waehleIn(
    WidgetTester tester,
    String feld,
    String eintrag,
  ) async {
    await tester.tap(k(feld));
    await tester.pumpAndSettle();
    await tester.tap(find.text(eintrag).last);
    await tester.pumpAndSettle();
  }

  group('Weitere Tätigkeiten', () {
    testWidgets('der Umschalter nennt alle Tätigkeiten', (tester) async {
      await zeige(tester, held: _held());
      for (final id in <String>[
        'kraeutersuche',
        'nahrung',
        'pirschjagd',
        'ansitzjagd',
        'tierfallen',
        'angeln',
        'speerfischen',
      ]) {
        expect(k('karto-wildnis-taetigkeit-$id'), findsOneWidget, reason: id);
      }
    });

    testWidgets('Nahrung sammeln: MU/IN/FF, Region ohne Jahreszeit', (
      tester,
    ) async {
      await zeige(tester, held: _held(monat: null));
      // Ohne Datum verlangt die Kräutersuche eine Jahreszeit …
      expect(k('karto-wildnis-zusammenfassung'), findsNothing);
      await waehleTaetigkeit(tester, 'nahrung');
      // … Nahrung sammeln nicht: Dschungel −2.
      expect(find.text('Kein Datum im Abenteuer: bitte wählen.'), findsNothing);
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
      expect(
        erschwernisHinweis(),
        'darin Region −2; Jahreszeit nach Meisterentscheid',
      );
      expect(find.textContaining('MU 14 · IN 13 · FF 10'), findsOneWidget);
      expect(find.text('Aussichten'), findsOneWidget);
      expect(find.textContaining('Erfolgschance'), findsOneWidget);
    });

    testWidgets('Nahrung sammeln: jede Viertelstunde mehr erleichtert', (
      tester,
    ) async {
      await zeige(tester, held: _held());
      await waehleTaetigkeit(tester, 'nahrung');
      await waehleIn(tester, 'karto-wildnis-dauer-60', '1½ Stunden (−2)');
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −4');
    });

    testWidgets('Nahrung sammeln würfelt Rationen und nennt den Giftwurf', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _held(), bestand: bestand);
      await waehleTaetigkeit(tester, 'nahrung');
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      final anfrage = bestand.anfragen.single;
      expect(anfrage.title, 'Nahrung sammeln');
      expect(anfrage.subtitle, 'MU/IN/FF');
      // TaP* 9 (gedeckelt durch den TaW): 1 + 9 / 3 = 4 Rationen.
      final ergebnis = k('karto-wildnis-ergebnis');
      expect(
        find.descendant(
          of: ergebnis,
          matching: find.textContaining('4 Tagesrationen'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: ergebnis,
          matching: find.textContaining('bei 18–20'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Pirschjagd mit eigener Waffe und Scharfschütze', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _jaeger(), bestand: bestand);
      await waehleTaetigkeit(tester, 'pirschjagd');
      // Kurzbogen +2; ohne Zuschläge verfällt der Scharfschütze.
      expect(zusammenfassung(), 'TaW 7 · Erschwernis +2');
      expect(erschwernisHinweis(), contains('Kurzbogen +2'));
      expect(erschwernisHinweis(), contains('3 Punkte der Schützen-SF'));
      expect(find.textContaining('Wie am Helden: Scharfschütze'), findsWidgets);

      // Sturm +6 gleicht der Scharfschütze um 3 aus.
      await waehleIn(tester, 'karto-wildnis-option-wetter-ruhig', 'Sturm (+6)');
      expect(zusammenfassung(), 'TaW 7 · Erschwernis +5');

      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      final anfrage = bestand.anfragen.single;
      expect(anfrage.title, 'Pirschjagd');
      expect(anfrage.subtitle, 'MU/IN/GE');
      expect(anfrage.basePool, 7);
      expect(anfrage.initialSituationalModifier, -5);
      expect(
        find.descendant(
          of: k('karto-wildnis-ergebnis'),
          matching: find.textContaining('Pfeil'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Tierfallen: Geländekunde −5, in der Wüste nicht möglich', (
      tester,
    ) async {
      await zeige(tester, held: _held(), bestand: GefechtsTestBestand());
      await waehleTaetigkeit(tester, 'tierfallen');
      expect(find.text('Passend (−5)'), findsOneWidget);
      expect(find.text('Ähnlich (−3)'), findsOneWidget);
      expect(zusammenfassung(), 'TaW 0 · Erschwernis −4');

      await waehleIn(tester, 'karto-wildnis-landschaft-dschungel', 'Wüste');
      expect(zusammenfassung(), 'TaW 0 · nicht möglich');
      expect(k('karto-wildnis-sperrgrund'), findsOneWidget);
      expect(k('karto-wildnis-vorschau'), findsNothing);
      final wuerfeln = tester.widget<FilledButton>(k('karto-wildnis-wuerfeln'));
      expect(wuerfeln.onPressed, isNull);
    });

    testWidgets('die Landschaft bleibt beim Wechsel der Tätigkeit', (
      tester,
    ) async {
      await zeige(tester, held: _held(), standort: 'Reichsforst');
      await waehleIn(
        tester,
        'karto-wildnis-landschaft-',
        'Lichter Wald (Standort)',
      );
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −6');
      await waehleTaetigkeit(tester, 'nahrung');
      // Lichter Wald beim Nahrung sammeln −6.
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −6');
      await waehleTaetigkeit(tester, 'pirschjagd');
      expect(k('karto-wildnis-zusammenfassung'), findsOneWidget);
    });

    testWidgets('erbeutete Rationen lassen sich ins Inventar buchen', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _jaeger(), bestand: bestand);
      await waehleTaetigkeit(tester, 'pirschjagd');
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      // TaW 7, Erschwernis +2: 5 TaP*, also 5 Tagesrationen.
      expect(find.text('5 Tagesrationen ins Inventar'), findsOneWidget);
      await tester.tap(k('karto-wildnis-rationen-buchen'));
      await tester.pumpAndSettle();

      final eintrag = (await repository.loadHeroById(_id))!.inventoryEntries
          .singleWhere((e) => e.gegenstand == 'Wildbret (frisch)');
      expect(eintrag.menge, 5);
      expect(eintrag.herkunft, 'Pirschjagd am 5. Praios 1043 BF');
      expect(eintrag.beschreibung, contains('Sumpf, Dschungel'));
      expect(k('karto-wildnis-rationen-gebucht'), findsOneWidget);
      expect(k('karto-wildnis-rationen-buchen'), findsNothing);
    });

    testWidgets('misslungene Jagd bietet keine Rationen an', (tester) async {
      final bestand = GefechtsTestBestand()..w20Wert = 20;
      await zeige(tester, held: _jaeger(), bestand: bestand);
      await waehleTaetigkeit(tester, 'pirschjagd');
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-rationen-buchen'), findsNothing);
      // Geschossen wurde trotzdem.
      expect(k('karto-wildnis-verlust-wuerfeln'), findsOneWidget);
    });

    testWidgets('Kräutersuche bucht keine Rationen', (tester) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-rationen-buchen'), findsNothing);
      expect(k('karto-wildnis-munition'), findsNothing);
    });

    testWidgets('Geschossverlust wird gewürfelt und abgebucht', (tester) async {
      final bestand = _AusruestungsBestand()..w20Wert = 5;
      await zeige(
        tester,
        held: _jaegerMitPfeilen(),
        bestand: bestand,
        // Zwei Schüsse: 1 + 2 = 3 (verloren), 10 + 10 = 20 (bleibt).
        wuerfler: _FesteWuerfel(<int>[1, 2, 10, 10]),
      );
      await waehleTaetigkeit(tester, 'pirschjagd');
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(
        (k('karto-wildnis-munition').evaluate().single.widget as Text).data,
        'Munition: Kurzbogen · Jagdpfeile (12)',
      );
      await tester.tap(k('karto-wildnis-schuesse-plus'));
      await tester.pump();
      await tester.tap(k('karto-wildnis-verlust-wuerfeln'));
      await tester.pumpAndSettle();
      expect(
        (k('karto-wildnis-verlust').evaluate().single.widget as Text).data,
        '2W20 je Schuss: 3 · 20 (verloren bei 3–5): 1 Geschoss verloren',
      );
      expect(find.text('1 × Jagdpfeile abbuchen'), findsOneWidget);
      await tester.tap(k('karto-wildnis-verlust-buchen'));
      await tester.pumpAndSettle();

      final bogen = (await repository.loadHeroById(_id))!
          .combatConfig
          .weaponSlots
          .single;
      expect(bogen.rangedProfile.projectiles.single.count, 11);
      expect(k('karto-wildnis-verlust-gebucht'), findsOneWidget);
    });

    testWidgets('mit einer Tabellenwaffe bleibt der Bestand Handarbeit', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(
        tester,
        held: _held(),
        bestand: bestand,
        // Schleudersteine: 1W6 = 3, also 4 verloren.
        wuerfler: _FesteWuerfel(<int>[3]),
      );
      await waehleTaetigkeit(tester, 'pirschjagd');
      await waehleIn(
        tester,
        'karto-wildnis-option-waffe-tabelle:kurzbogen',
        'Schleuder (+4)',
      );
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      // Bei 1W6+1 gibt es keine Schusszahl.
      expect(k('karto-wildnis-schuesse-plus'), findsNothing);
      await tester.tap(k('karto-wildnis-verlust-wuerfeln'));
      await tester.pumpAndSettle();
      expect(
        (k('karto-wildnis-verlust').evaluate().single.widget as Text).data,
        '1W6 = 3 (+1): 4 Geschosse verloren',
      );
      expect(k('karto-wildnis-verlust-buchen'), findsNothing);
      expect(
        find.text('Waffe aus der Tabelle: Bestand bitte von Hand anpassen.'),
        findsOneWidget,
      );
    });

    for (final skalierung in [1.0, 2.0]) {
      testWidgets('Pirschjagd bei 320 dp, Schrift $skalierung, ohne Überlauf', (
        tester,
      ) async {
        final bestand = GefechtsTestBestand()..w20Wert = 5;
        await zeige(
          tester,
          held: _jaeger(),
          bestand: bestand,
          breite: 320,
          skalierung: skalierung,
        );
        await waehleTaetigkeit(tester, 'pirschjagd');
        await tester.tap(k('karto-wildnis-wuerfeln'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Vorbelegung aus dem Helden', () {
    testWidgets(
      'Standort, Datum und Sonderfertigkeiten ergeben die Erschwernis',
      (tester) async {
        await zeige(
          tester,
          held: _held(
            sonderfertigkeiten: <String>[
              'Geländekunde (Dschungelkundig)',
              'Ortskenntnis (Regenwald)',
            ],
          ),
        );
        // Dschungel im Sommer −2, Geländekunde −3, Ortskenntnis −7.
        expect(zusammenfassung(), 'TaW 9 · Erschwernis −12');
        expect(find.text('aus Geländekunde (Dschungelkundig)'), findsOneWidget);
        expect(find.text('aus Ortskenntnis (Regenwald)'), findsOneWidget);
      },
    );

    testWidgets('Eigenschaften der Probe sind KL/IN/FF', (tester) async {
      await zeige(tester, held: _held());
      expect(find.textContaining('KL 12 · IN 13 · FF 10'), findsOneWidget);
    });

    testWidgets('ohne Sonderfertigkeiten gilt nur die Landschaft', (
      tester,
    ) async {
      await zeige(tester, held: _held());
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
      expect(find.text('keine passende Sonderfertigkeit'), findsOneWidget);
      expect(
        find.text('keine Ortskenntnis für diesen Standort'),
        findsOneWidget,
      );
    });

    testWidgets('Ortskenntnis gilt nur am eigenen Standort', (tester) async {
      await zeige(
        tester,
        held: _held(sonderfertigkeiten: <String>['Ortskenntnis (Gareth)']),
      );
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
    });

    testWidgets('mehrdeutiger Standort verlangt eine Landschaftswahl', (
      tester,
    ) async {
      await zeige(tester, held: _held(), standort: 'Reichsforst');
      expect(
        find.text('Mehrere passen zum Standort: bitte wählen.'),
        findsOneWidget,
      );
      expect(k('karto-wildnis-zusammenfassung'), findsNothing);
      final wuerfeln = tester.widget<FilledButton>(k('karto-wildnis-wuerfeln'));
      expect(wuerfeln.onPressed, isNull);
    });

    testWidgets('ohne Datum im Abenteuer wählt man die Jahreszeit selbst', (
      tester,
    ) async {
      await zeige(tester, held: _held(monat: null));
      expect(
        find.text('Kein Datum im Abenteuer: bitte wählen.'),
        findsOneWidget,
      );
      expect(k('karto-wildnis-zusammenfassung'), findsNothing);
    });
  });

  group('Handeingaben', () {
    testWidgets('Geländekunde lässt sich von Hand setzen', (tester) async {
      await zeige(tester, held: _held());
      await tester.tap(k('karto-wildnis-gelaende-passend'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −5');
      expect(find.text('von Hand gesetzt'), findsOneWidget);
      await tester.tap(k('karto-wildnis-gelaende-aehnlich'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −3');
    });

    testWidgets('Ortskenntnis lässt sich von Hand schalten', (tester) async {
      await zeige(tester, held: _held());
      await tester.tap(k('karto-wildnis-ortskenntnis'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −9');
    });

    testWidgets('AsP und situative Erschwernis gehen ein', (tester) async {
      await zeige(tester, held: _held());
      for (var i = 0; i < 6; i++) {
        await tester.tap(k('karto-wildnis-asp-plus'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-asp-wert'), findsOneWidget);
      // 6 AsP senken die Erschwernis um 2.
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −4');
      await tester.tap(k('karto-wildnis-situativ-plus'));
      await tester.pumpAndSettle();
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −3');
    });

    testWidgets('ohne AsP gibt es keinen AsP-Einsatz', (tester) async {
      await zeige(tester, held: _held(), asp: 0);
      expect(k('karto-wildnis-asp-plus'), findsNothing);
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
    });

    testWidgets('der AsP-Einsatz endet bei den vorhandenen AsP', (
      tester,
    ) async {
      await zeige(tester, held: _held(), asp: 2);
      for (var i = 0; i < 5; i++) {
        await tester.tap(k('karto-wildnis-asp-plus'));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      // 2 AsP senken die Erschwernis nicht (je 3 um 1).
      expect(zusammenfassung(), 'TaW 9 · Erschwernis −2');
      expect(find.textContaining('von 2 AsP'), findsOneWidget);
    });

    testWidgets('eingesetzte AsP werden beim Würfeln abgebucht', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _held(), bestand: bestand, asp: 10);
      for (var i = 0; i < 6; i++) {
        await tester.tap(k('karto-wildnis-asp-plus'));
        await tester.pump();
      }
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(bestand.anfragen, hasLength(1));
      expect((await repository.loadHeroState(_id))!.currentAsp, 4);
    });

    testWidgets('ohne eingesetzte AsP bleiben die AsP unverändert', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _held(), bestand: bestand, asp: 10);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect((await repository.loadHeroState(_id))!.currentAsp, 10);
    });

    testWidgets('zwei Stunden steigern den TaW um die Hälfte', (tester) async {
      await zeige(tester, held: _held());
      await tester.tap(k('karto-wildnis-dauer-60'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 Stunden').last);
      await tester.pumpAndSettle();
      // TaW 9 steigt auf 13,5, kaufmännisch gerundet 14.
      expect(zusammenfassung(), 'TaW 14 · Erschwernis −2');
    });
  });

  group('Würfeln', () {
    testWidgets('ohne Gefechtsbrücke bleibt der Knopf gesperrt', (
      tester,
    ) async {
      await zeige(tester, held: _held());
      final wuerfeln = tester.widget<FilledButton>(k('karto-wildnis-wuerfeln'));
      expect(wuerfeln.onPressed, isNull);
    });

    testWidgets('die Probe geht an die Brücke und zeigt die Ausbeute', (
      tester,
    ) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(
        tester,
        held: _held(
          sonderfertigkeiten: <String>['Geländekunde (Dschungelkundig)'],
        ),
        bestand: bestand,
      );
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();

      final anfrage = bestand.anfragen.single;
      expect(anfrage.title, 'Kräuter suchen');
      expect(anfrage.subtitle, 'KL/IN/FF');
      expect(anfrage.basePool, 9);
      // Erschwernis −5 (Dschungel −2, Geländekunde −3) = +5 auf den Pool.
      expect(anfrage.initialSituationalModifier, 5);

      expect(k('karto-wildnis-ergebnis'), findsOneWidget);
      expect(find.textContaining('Gelungen'), findsOneWidget);
      expect(
        find.descendant(
          of: k('karto-wildnis-ergebnis'),
          matching: find.textContaining('Donf'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('abgebrochene Probe zeigt kein Ergebnis', (tester) async {
      final bestand = GefechtsTestBestand()..abbrechen = true;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(bestand.anfragen, hasLength(1));
      expect(k('karto-wildnis-ergebnis'), findsNothing);
    });

    testWidgets('eine neue Eingabe verwirft das Ergebnis', (tester) async {
      final bestand = GefechtsTestBestand()..w20Wert = 5;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-ergebnis'), findsOneWidget);
      await tester.tap(k('karto-wildnis-asp-plus'));
      await tester.pumpAndSettle();
      expect(k('karto-wildnis-ergebnis'), findsNothing);
    });

    testWidgets('misslungene Probe nennt keinen Fund', (tester) async {
      final bestand = GefechtsTestBestand()..w20Wert = 20;
      await zeige(tester, held: _held(), bestand: bestand);
      await tester.tap(k('karto-wildnis-wuerfeln'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Misslungen'), findsOneWidget);
      expect(
        find.descendant(
          of: k('karto-wildnis-ergebnis'),
          matching: find.textContaining('Donf'),
        ),
        findsNothing,
      );
    });
  });

  group('Kräuterangaben', () {
    Future<void> waehleGezielt(WidgetTester tester) async {
      await tester.tap(k('karto-wildnis-option-ziel-beliebig'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bestimmtes Kraut oder Heilwirkung').last);
      await tester.pumpAndSettle();
    }

    testWidgets('gezielte Suche rechnet die Suchschwierigkeit ein', (
      tester,
    ) async {
      await zeige(tester, held: _held());
      await waehleGezielt(tester);
      // Ohne bestimmte Pflanze: Dschungel −2, Pauschale +8.
      expect(zusammenfassung(), 'TaW 9 · Erschwernis +6');
      expect(
        find.textContaining(
          'Heilwirkung ohne bestimmte Pflanze: '
          'Suchschwierigkeit +8',
        ),
        findsOneWidget,
      );

      await tester.tap(k('karto-wildnis-option-kraut-'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Donf (Suchschwierigkeit 3)').last);
      await tester.pumpAndSettle();
      // Dschungel −2, Donf +3 (Bestimmung +1, häufig +2).
      expect(zusammenfassung(), 'TaW 9 · Erschwernis +1');
      expect(
        find.text(
          'darin Donf: Suchschwierigkeit +3 (Bestimmung +1, häufig +2)',
        ),
        findsOneWidget,
      );

      // Die Angaben zum gesuchten Kraut lassen sich aufklappen.
      expect(k('karto-wildnis-ziel-angaben'), findsNothing);
      await tester.tap(k('karto-wildnis-ziel'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: k('karto-wildnis-ziel-angaben'),
          matching: find.text('Sumpfpflanze mit violetter Blüte.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('beliebige Suche hat keine Kraut-Erschwernis', (tester) async {
      await zeige(tester, held: _held());
      expect(k('karto-wildnis-erschwernis-hinweis'), findsNothing);
    });

    testWidgets('die gekürzte Fundliste lässt sich ganz zeigen', (
      tester,
    ) async {
      await zeige(tester, held: _held(), kraeuter: _vieleKraeuter);
      Finder fund(String name) => find.descendant(
        of: k('karto-wildnis-vorschau'),
        matching: find.textContaining(name),
      );
      expect(find.text('Mögliche Funde (6)'), findsOneWidget);
      expect(fund('Kukura'), findsNothing);
      expect(find.text('Alle 6 anzeigen (3 weitere)'), findsOneWidget);

      await tester.tap(k('karto-wildnis-vorschau-alle'));
      await tester.pumpAndSettle();
      for (final name in <String>['Donf', 'Quinya', 'Boronie', 'Kukura']) {
        expect(fund(name), findsOneWidget, reason: name);
      }
      expect(find.text('Weniger anzeigen'), findsOneWidget);

      await tester.tap(k('karto-wildnis-vorschau-alle'));
      await tester.pumpAndSettle();
      expect(fund('Kukura'), findsNothing);
    });

    testWidgets('ein Fund zeigt Beschreibung und Zoo-Botanica-Seite', (
      tester,
    ) async {
      await zeige(tester, held: _held(), kraeuter: _vieleKraeuter);
      await tester.tap(k('karto-wildnis-fund-0'));
      await tester.pumpAndSettle();
      final angaben = k('karto-wildnis-fund-0-angaben');
      expect(
        find.descendant(
          of: angaben,
          matching: find.text('Sumpfpflanze mit violetter Blüte.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: angaben,
          matching: find.text('Wirkung: fiebersenkend'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Mehr dazu: Zoo Botanica Aventurica S. 234'),
        findsOneWidget,
      );

      // Gesperrte Beschreibung: Hinweis statt Text.
      await tester.tap(k('karto-wildnis-fund-2'));
      await tester.pumpAndSettle();
      expect(
        find.text('Beschreibung gesperrt: Katalogpasswort erforderlich.'),
        findsOneWidget,
      );

      await tester.tap(k('karto-wildnis-fund-0'));
      await tester.pumpAndSettle();
      expect(angaben, findsNothing);
    });
  });

  group('Größenstufen', () {
    for (final breite in [320.0, 480.0, 700.0, 1100.0]) {
      for (final skalierung in [1.0, 2.0]) {
        testWidgets('bei $breite dp, Schrift $skalierung, ohne Überlauf', (
          tester,
        ) async {
          final bestand = GefechtsTestBestand()..w20Wert = 5;
          await zeige(
            tester,
            held: _held(
              sonderfertigkeiten: <String>['Geländekunde (Dschungelkundig)'],
            ),
            bestand: bestand,
            breite: breite,
            skalierung: skalierung,
          );
          await tester.tap(k('karto-wildnis-wuerfeln'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('die Vorschau nennt die möglichen Funde', (tester) async {
      await zeige(tester, held: _held(), breite: 1100);
      expect(
        find.descendant(
          of: k('karto-wildnis-vorschau'),
          matching: find.textContaining('Donf'),
        ),
        findsOneWidget,
      );
    });
  });
}
