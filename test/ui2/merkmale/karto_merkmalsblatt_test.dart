import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmalsblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
  advantages: [
    HeroTraitDef(
      id: 'adv_flink',
      name: 'Flink',
      traitType: 'advantage',
      selectionTemplate: 'Flink',
      wirkungen: [
        HeroTraitEffect(art: HeroTraitEffectArt.schalter, ziel: 'flink'),
      ],
    ),
    HeroTraitDef(
      id: 'adv_hohe_lebenskraft',
      name: 'Hohe Lebenskraft',
      traitType: 'advantage',
      valueKind: 'points',
      minValue: 1,
      maxValue: 6,
      unit: 'LeP',
      selectionTemplate: 'Hohe Lebenskraft {value}',
      wirkungen: [
        HeroTraitEffect(art: HeroTraitEffectArt.basiswert, ziel: 'lep', max: 6),
      ],
    ),
    HeroTraitDef(
      id: 'adv_herausragender_sinn',
      name: 'Herausragender Sinn',
      traitType: 'advantage',
      valueKind: 'choice',
      selectionTemplate: 'Herausragender Sinn {choice}',
      choiceLabel: 'Sinn',
      choices: ['Gehör', 'Sicht'],
      choiceFreeText: false,
    ),
    HeroTraitDef(
      id: 'adv_begabung_talent',
      name: 'Begabung für Talent',
      traitType: 'advantage',
      valueKind: 'choice',
      selectionTemplate: 'Begabung für {choice}',
    ),
    HeroTraitDef(
      id: 'adv_begabung_zauber',
      name: 'Begabung für Zauber',
      traitType: 'advantage',
      valueKind: 'choice',
      selectionTemplate: 'Begabung für {choice}',
    ),
  ],
  disadvantages: [
    HeroTraitDef(
      id: 'dis_goldgier',
      name: 'Goldgier',
      traitType: 'disadvantage',
      valueKind: 'points',
      minValue: 1,
      unit: 'Punkt',
      selectionTemplate: 'Goldgier {value}',
    ),
  ],
);

HeroSheet _held({
  String vorteileText = '',
  String nachteileText = '',
  List<HeroMerkmal> vorteile = const [],
}) => testHero().copyWith(
  vorteileText: vorteileText,
  nachteileText: nachteileText,
  vorteilEintraege: vorteile,
);

/// Repository, dessen Speichern fehlschlägt.
class _SpeicherfehlerRepository extends FakeRepository {
  _SpeicherfehlerRepository(HeroSheet held) : super(heroes: [held]);

  @override
  Future<void> saveHero(HeroSheet hero) async {
    throw StateError('Speicher voll');
  }
}

void main() {
  late FakeRepository repo;

  Future<void> zeige(
    WidgetTester tester, {
    required HeroSheet held,
    bool planOffen = false,
    FakeRepository? repository,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = repository ?? FakeRepository(heroes: [held]);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => _katalog),
      ],
    );
    addTearDown(container.dispose);
    if (planOffen) {
      container
          .read(advancementSessionProvider('rondra').notifier)
          .start(hero: held, catalog: _katalog);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    zeigeMerkmalsblatt(context: context, heroId: 'rondra'),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
  }

  Finder key(String name) => find.byKey(ValueKey<String>(name));

  Future<HeroSheet> gespeichert() async => (await repo.loadHeroById('rondra'))!;

  Future<void> tippe(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Karten zeigen Art, Katalogname, Stufe, Wirkung und Herkunft', (
    tester,
  ) async {
    await zeige(
      tester,
      held: _held(
        vorteileText: 'Hohe Lebenskraft 3',
        vorteile: const [
          HeroMerkmal(
            katalogId: 'adv_hohe_lebenskraft',
            text: 'Hohe Lebenskraft 3',
            wert: 3,
          ),
        ],
      ),
    );

    expect(find.text('Vor- und Nachteile'), findsOneWidget);
    expect(find.text('Hohe Lebenskraft'), findsOneWidget);
    expect(find.text('Stufe 3'), findsOneWidget);
    expect(find.text('LeP +3'), findsOneWidget);
    expect(find.text('Aus dem Katalog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hinzufügen per Katalog speichert ID, Wert und Projektion', (
    tester,
  ) async {
    await zeige(tester, held: _held());

    await tippe(tester, key('karto-merkmal-neu-vorteile'));
    await tester.tap(key('karto-merkmal-katalog-adv_hohe_lebenskraft'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-merkmal-wert'), '9');
    await tester.tap(key('karto-merkmal-uebernehmen'));
    await tester.pumpAndSettle();

    final held = await gespeichert();
    final eintrag = held.vorteilEintraege.single;
    expect(eintrag.katalogId, 'adv_hohe_lebenskraft');
    expect(eintrag.wert, 6, reason: 'auf maxValue gekappt');
    expect(held.vorteileText, 'Hohe Lebenskraft 6');
    expect(find.text('LeP +6'), findsOneWidget);
  });

  testWidgets('Auswahl ohne freie Eingabe kommt aus der Liste', (tester) async {
    await zeige(tester, held: _held());

    await tippe(tester, key('karto-merkmal-neu-vorteile'));
    await tester.tap(key('karto-merkmal-katalog-adv_herausragender_sinn'));
    await tester.pumpAndSettle();
    expect(key('karto-merkmal-auswahl-frei'), findsNothing);
    await tester.tap(key('karto-merkmal-auswahl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sicht').last);
    await tester.pumpAndSettle();
    await tester.tap(key('karto-merkmal-uebernehmen'));
    await tester.pumpAndSettle();

    final eintrag = (await gespeichert()).vorteilEintraege.single;
    expect(eintrag.katalogId, 'adv_herausragender_sinn');
    expect(eintrag.auswahl, 'Sicht');
    expect(eintrag.text, 'Herausragender Sinn Sicht');
  });

  testWidgets('Ändern behält die Katalog-ID, Entfernen löscht', (tester) async {
    await zeige(
      tester,
      held: _held(
        vorteileText: 'Hohe Lebenskraft 2, Flink',
        vorteile: const [
          HeroMerkmal(
            katalogId: 'adv_hohe_lebenskraft',
            text: 'Hohe Lebenskraft 2',
            wert: 2,
            unbekannteFelder: {'zukunft': 1},
          ),
          HeroMerkmal(katalogId: 'adv_flink', text: 'Flink'),
        ],
      ),
    );

    await tippe(tester, key('karto-merkmal-vorteile-0'));
    await tester.tap(key('karto-merkmal-aktion-aendern'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(key('karto-merkmal-wert')).controller!.text,
      '2',
    );
    await tester.enterText(key('karto-merkmal-wert'), '4');
    await tester.tap(key('karto-merkmal-uebernehmen'));
    await tester.pumpAndSettle();

    var held = await gespeichert();
    expect(held.vorteilEintraege.first.katalogId, 'adv_hohe_lebenskraft');
    expect(held.vorteilEintraege.first.wert, 4);
    expect(held.vorteilEintraege.first.unbekannteFelder, {'zukunft': 1});
    expect(held.vorteileText, 'Hohe Lebenskraft 4; Flink');

    await tippe(tester, key('karto-merkmal-vorteile-1'));
    await tester.tap(key('karto-merkmal-aktion-entfernen'));
    await tester.pumpAndSettle();
    await tester.tap(key('karto-merkmal-entfernen-bestaetigen'));
    await tester.pumpAndSettle();

    held = await gespeichert();
    expect(held.vorteilEintraege.map((e) => e.katalogId), [
      'adv_hohe_lebenskraft',
    ]);
    expect(held.vorteileText, 'Hohe Lebenskraft 4');
  });

  testWidgets('ein freier Eintrag bleibt frei', (tester) async {
    await zeige(tester, held: _held());

    await tippe(tester, key('karto-merkmal-neu-nachteile'));
    await tester.tap(key('karto-merkmal-frei'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-merkmal-text'), 'Sammelt Knöpfe');
    await tester.tap(key('karto-merkmal-text-uebernehmen'));
    await tester.pumpAndSettle();

    final eintrag = (await gespeichert()).nachteilEintraege.single;
    expect(eintrag.istKatalogisiert, isFalse);
    expect(eintrag.zuordnung, HeroMerkmalZuordnung.frei);
    expect(find.text('Freier Eintrag'), findsOneWidget);
  });

  testWidgets('ein Bestandsheld wird beim ersten Ändern strukturiert', (
    tester,
  ) async {
    await zeige(
      tester,
      held: _held(vorteileText: 'Flink, LEP+2', nachteileText: 'Goldgier 6'),
    );

    await tippe(tester, key('karto-merkmal-neu-vorteile'));
    await tester.tap(key('karto-merkmal-katalog-adv_hohe_lebenskraft'));
    await tester.pumpAndSettle();
    await tester.tap(key('karto-merkmal-uebernehmen'));
    await tester.pumpAndSettle();

    final held = await gespeichert();
    expect(held.vorteilEintraege.map((e) => e.katalogId), [
      'adv_flink',
      '',
      'adv_hohe_lebenskraft',
    ]);
    expect(held.vorteileText, 'Flink; LEP+2; Hohe Lebenskraft 1');
    // Das Speichern migriert auch die andere Art (saveHero), ohne ihren
    // Inhalt zu ändern.
    expect(held.nachteilEintraege.single.katalogId, 'dis_goldgier');
    expect(held.nachteileText, 'Goldgier 6');
  });

  testWidgets('ein mehrdeutiger Eintrag lässt sich zuordnen', (tester) async {
    await zeige(
      tester,
      held: _held(
        vorteileText: 'Begabung für Schwerter',
        vorteile: const [
          HeroMerkmal(
            text: 'Begabung für Schwerter',
            kandidatenIds: ['adv_begabung_talent', 'adv_begabung_zauber'],
            zuordnung: HeroMerkmalZuordnung.migration,
          ),
        ],
      ),
    );
    expect(find.text('Zuordnung prüfen'), findsOneWidget);

    await tippe(tester, key('karto-merkmal-vorteile-0'));
    await tester.tap(key('karto-merkmal-aktion-zuordnen'));
    await tester.pumpAndSettle();
    await tester.tap(key('karto-merkmal-kandidat-adv_begabung_talent'));
    await tester.pumpAndSettle();

    final eintrag = (await gespeichert()).vorteilEintraege.single;
    expect(eintrag.katalogId, 'adv_begabung_talent');
    expect(eintrag.auswahl, 'Schwerter');
    expect(eintrag.kandidatenIds, isEmpty);
  });

  group('Abweichung durch eine ältere App-Version', () {
    HeroSheet abweichend() => _held(
      vorteileText: 'Flink, Hohe Lebenskraft 2',
      vorteile: const [HeroMerkmal(katalogId: 'adv_flink', text: 'Flink')],
    );

    testWidgets('ist sichtbar und sperrt das Anlegen', (tester) async {
      await zeige(tester, held: abweichend());

      expect(key('karto-merkmal-abweichung-vorteile'), findsOneWidget);
      expect(find.text('Neu im Text: Hohe Lebenskraft 2'), findsOneWidget);
      expect(key('karto-merkmal-neu-vorteile'), findsNothing);
      expect(key('karto-merkmal-neu-nachteile'), findsOneWidget);
    });

    testWidgets('Text übernehmen ordnet den geänderten Text zu', (
      tester,
    ) async {
      await zeige(tester, held: abweichend());
      await tippe(tester, key('karto-merkmal-text-vorteile'));

      final held = await gespeichert();
      expect(held.vorteilEintraege.map((e) => e.katalogId), [
        'adv_flink',
        'adv_hohe_lebenskraft',
      ]);
      expect(key('karto-merkmal-abweichung-vorteile'), findsNothing);
    });

    testWidgets('Liste behalten schreibt den Text neu', (tester) async {
      await zeige(tester, held: abweichend());
      await tippe(tester, key('karto-merkmal-liste-vorteile'));

      final held = await gespeichert();
      expect(held.vorteilEintraege.single.katalogId, 'adv_flink');
      expect(held.vorteileText, 'Flink');
    });
  });

  testWidgets('bei offener Planung schreibgeschützt', (tester) async {
    await zeige(
      tester,
      held: _held(
        vorteileText: 'Flink',
        vorteile: const [HeroMerkmal(katalogId: 'adv_flink', text: 'Flink')],
      ),
      planOffen: true,
    );

    expect(key('karto-merkmal-gesperrt'), findsOneWidget);
    expect(key('karto-merkmal-neu-vorteile'), findsNothing);
    await tester.tap(key('karto-merkmal-vorteile-0'));
    await tester.pumpAndSettle();
    expect(key('karto-merkmal-aktion-entfernen'), findsNothing);
  });

  testWidgets('ein Speicherfehler erscheint im Blatt', (tester) async {
    final held = _held();
    await zeige(
      tester,
      held: held,
      repository: _SpeicherfehlerRepository(held),
    );

    await tippe(tester, key('karto-merkmal-neu-vorteile'));
    await tester.tap(key('karto-merkmal-katalog-adv_flink'));
    await tester.pumpAndSettle();

    expect(key('karto-merkmal-fehler'), findsOneWidget);
    expect(find.textContaining('Speicher voll'), findsOneWidget);
  });
}
