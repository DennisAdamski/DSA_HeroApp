import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuerblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../shell/karto_test_support.dart';

const _nebel = HeroAdventureEntry(
  id: 'nebel',
  title: 'Die Spuren im Nebel',
  summary: 'Die Gruppe folgt der Spur.',
  notes: [HeroNoteEntry(title: 'Wirt', description: 'Weiß mehr.')],
  people: [
    HeroAdventurePersonEntry(
      id: 'p1',
      name: 'Alrik',
      description: 'Schankwirt',
    ),
  ],
);

HeroSheet _held() => testHero().copyWith(adventures: const [_nebel]);

void main() {
  late FakeRepository repo;

  Future<void> zeige(
    WidgetTester tester, {
    bool planOffen = false,
    String abenteuerId = 'nebel',
    HeroSheet? held,
    double breite = 900,
    double skalierung = 1,
    Brightness helligkeit = Brightness.light,
    AbenteuerSortierung? sortierung,
    String? standort,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = FakeRepository(
      heroes: [held ?? _held()],
      states: standort == null
          ? null
          : {'rondra': const HeroState.empty().copyWith(standort: standort)},
    );
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        if (sortierung != null)
          abenteuerSortierungProvider.overrideWithValue(sortierung),
      ],
    );
    addTearDown(container.dispose);
    if (planOffen) {
      container
          .read(advancementSessionProvider('rondra').notifier)
          .start(hero: held ?? _held(), catalog: testCatalog);
    }
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
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => zeigeAbenteuerblatt(
                  context: context,
                  heroId: 'rondra',
                  abenteuerId: abenteuerId,
                ),
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

  Future<HeroAdventureEntry> gespeichert() async =>
      (await repo.loadHeroById('rondra'))!.adventures.single;

  Finder key(String name) => find.byKey(ValueKey<String>(name));

  Future<void> speichern(WidgetTester tester) async {
    // Die letzte Eingabe muss erst gebaut sein, sonst ist der Knopf noch aus.
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
  }

  testWidgets('zeigt Zusammenfassung, Notizen und Personen', (tester) async {
    await zeige(tester);
    expect(find.text('Die Spuren im Nebel'), findsOneWidget);
    expect(find.text('Die Gruppe folgt der Spur.'), findsOneWidget);
    expect(find.text('Weiß mehr.'), findsOneWidget);
    expect(find.text('Alrik'), findsOneWidget);
    expect(find.text('Schankwirt'), findsOneWidget);
  });

  testWidgets('eine neue Notiz wird gespeichert und erscheint sofort', (
    tester,
  ) async {
    await zeige(tester);
    await tester.tap(key('karto-abenteuer-notiz-neu'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-1'), 'Karte');
    await tester.enterText(key('karto-abenteuer-feld-2'), 'Im Keller.');
    await speichern(tester);

    final abenteuer = await gespeichert();
    expect(abenteuer.notes.map((n) => n.title), ['Wirt', 'Karte']);
    expect(find.text('Im Keller.'), findsOneWidget);
  });

  testWidgets('eine Notiz laesst sich bearbeiten und loeschen', (tester) async {
    await zeige(tester);
    await tester.tap(find.text('Weiß mehr.'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-2'), 'Weiß alles.');
    await speichern(tester);
    expect((await gespeichert()).notes.single.description, 'Weiß alles.');

    await tester.tap(find.text('Weiß alles.'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
    // Rueckfrage bestaetigen.
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect((await gespeichert()).notes, isEmpty);
    expect(find.text('Weiß alles.'), findsNothing);
    // Leer bleibt nur der freie Platz zum Anlegen.
    expect(key('karto-abenteuer-notiz-neu'), findsOneWidget);
  });

  testWidgets('Personen lassen sich anlegen und bearbeiten', (tester) async {
    await zeige(tester);
    await tester.tap(key('karto-abenteuer-person-neu'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-1'), 'Yasmina');
    await speichern(tester);

    await tester.tap(find.text('Alrik'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-2'), 'Wirt in Gareth');
    await speichern(tester);

    final personen = (await gespeichert()).people;
    expect(personen.map((p) => p.name), ['Alrik', 'Yasmina']);
    expect(personen.first.id, 'p1');
    expect(personen.first.description, 'Wirt in Gareth');
    expect(personen.last.id, isNotEmpty);
  });

  testWidgets('Datum und Zusammenfassung werden gezielt geschrieben', (
    tester,
  ) async {
    await zeige(tester);
    await tester.tap(key('karto-abenteuer-datum'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-tag'), '12');
    await tester.tap(key('karto-abenteuer-monat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phex').last);
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-jahr'), '1043');
    await speichern(tester);
    expect(find.text('12. Phex 1043 BF'), findsOneWidget);

    await tester.tap(key('karto-abenteuer-zusammenfassung'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-text'), 'Neue Spur.');
    await speichern(tester);

    final abenteuer = await gespeichert();
    expect(abenteuer.currentAventurianDate.month, 'phex');
    expect(abenteuer.summary, 'Neue Spur.');
    // Notizen und Personen bleiben unberuehrt.
    expect(abenteuer.notes.single.title, 'Wirt');
    expect(abenteuer.people.single.name, 'Alrik');
  });

  testWidgets('Bearbeiten erhält Felder einer neueren App-Version', (
    tester,
  ) async {
    const feld = <String, Object?>{'zukunftsfeld': 1};
    await zeige(
      tester,
      held: testHero().copyWith(
        adventures: [
          _nebel.copyWith(
            notes: [_nebel.notes.single.copyWith(unbekannteFelder: feld)],
            people: [_nebel.people.single.copyWith(unbekannteFelder: feld)],
            currentAventurianDate: const HeroAdventureDateValue(
              day: '1',
              month: 'praios',
              year: '1040',
              unbekannteFelder: feld,
            ),
            unbekannteFelder: feld,
          ),
        ],
      ),
    );
    await tester.tap(find.text('Weiß mehr.'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-2'), 'Weiß alles.');
    await speichern(tester);
    await tester.tap(find.text('Alrik'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-2'), 'Wirt in Gareth');
    await speichern(tester);
    await tester.tap(key('karto-abenteuer-datum'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-tag'), '12');
    await speichern(tester);

    final abenteuer = await gespeichert();
    expect(abenteuer.notes.single.description, 'Weiß alles.');
    expect(abenteuer.people.single.description, 'Wirt in Gareth');
    expect(abenteuer.currentAventurianDate.day, '12');
    expect(abenteuer.unbekannteFelder, feld);
    expect(abenteuer.notes.single.unbekannteFelder, feld);
    expect(abenteuer.people.single.unbekannteFelder, feld);
    expect(abenteuer.currentAventurianDate.unbekannteFelder, feld);
  });

  testWidgets('waehrend einer Planung ist das Blatt schreibgeschuetzt', (
    tester,
  ) async {
    await zeige(tester, planOffen: true);
    expect(key('karto-abenteuer-gesperrt'), findsOneWidget);
    expect(key('karto-abenteuer-notiz-neu'), findsNothing);
    expect(key('karto-abenteuer-person-neu'), findsNothing);
    expect(key('karto-abenteuer-datum'), findsNothing);
    await tester.tap(find.text('Alrik'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Weiß mehr.'), findsOneWidget);
  });

  testWidgets('Personen stehen im breiten Blatt nebeneinander', (tester) async {
    await zeige(tester);
    await tester.tap(key('karto-abenteuer-person-neu'));
    await tester.pumpAndSettle();
    await tester.enterText(key('karto-abenteuer-feld-1'), 'Yasmina');
    await speichern(tester);
    final alrik = tester.getTopLeft(find.text('Alrik'));
    final yasmina = tester.getTopLeft(find.text('Yasmina'));
    expect(yasmina.dy, alrik.dy);
    // „Zuletzt bearbeitet“ stellt die neue Person vor die alte.
    expect(yasmina.dx, lessThan(alrik.dx));
  });

  testWidgets('leer und gesperrt erklaert das Blatt, was fehlt', (
    tester,
  ) async {
    await zeige(
      tester,
      planOffen: true,
      held: testHero().copyWith(
        adventures: const [HeroAdventureEntry(id: 'nebel', title: 'Leer')],
      ),
    );
    expect(find.text('Noch keine Personen.'), findsOneWidget);
    expect(find.text('Noch keine Notizen.'), findsOneWidget);
  });

  for (final breite in [320.0, 390.0, 900.0]) {
    testWidgets('Abenteuerblatt bei $breite dp ohne Überlauf', (tester) async {
      await zeige(tester, breite: breite, skalierung: 2);
      expect(find.text('Alrik'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dunkle Palette rendert dasselbe Blatt', (tester) async {
    await zeige(tester, helligkeit: Brightness.dark, planOffen: true);
    expect(key('karto-abenteuer-gesperrt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ein entferntes Abenteuer fuehrt in einen erklaerten Zustand', (
    tester,
  ) async {
    await zeige(tester, abenteuerId: 'weg');
    expect(find.text('Dieses Abenteuer gibt es nicht mehr.'), findsOneWidget);
  });

  group('Ort und Datum', () {
    HeroSheet mitDatum() => testHero().copyWith(
      adventures: [
        _nebel.copyWith(
          currentAventurianDate: const HeroAdventureDateValue(
            day: '12',
            month: 'phex',
            year: '1043',
          ),
        ),
      ],
    );

    String feldText(WidgetTester tester, String name) =>
        tester.widget<TextField>(key(name)).controller!.text;

    testWidgets('eine neue Notiz bekommt Standort und Datum vorbelegt', (
      tester,
    ) async {
      await zeige(tester, held: mitDatum(), standort: 'Gareth');
      await tester.tap(key('karto-abenteuer-notiz-neu'));
      await tester.pumpAndSettle();
      expect(feldText(tester, 'karto-abenteuer-feld-ort'), 'Gareth');
      expect(
        feldText(tester, 'karto-abenteuer-feld-datum'),
        '12. Phex 1043 BF',
      );

      await tester.enterText(key('karto-abenteuer-feld-1'), 'Karte');
      await speichern(tester);

      final notiz = (await gespeichert()).notes.last;
      expect(notiz.ort, 'Gareth');
      expect(notiz.datum, '12. Phex 1043 BF');
      expect(find.text('Gareth · 12. Phex 1043 BF'), findsOneWidget);
    });

    testWidgets('die Vorbelegung lässt sich ändern oder leeren', (
      tester,
    ) async {
      await zeige(tester, held: mitDatum(), standort: 'Gareth');
      await tester.tap(key('karto-abenteuer-notiz-neu'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-1'), 'Karte');
      await tester.enterText(key('karto-abenteuer-feld-ort'), 'Havena');
      await tester.enterText(key('karto-abenteuer-feld-datum'), '');
      await speichern(tester);

      final notiz = (await gespeichert()).notes.last;
      expect(notiz.ort, 'Havena');
      expect(notiz.datum, isEmpty);
    });

    testWidgets('ohne Standort und Datum bleiben beide Felder leer', (
      tester,
    ) async {
      await zeige(tester);
      await tester.tap(key('karto-abenteuer-notiz-neu'));
      await tester.pumpAndSettle();
      expect(feldText(tester, 'karto-abenteuer-feld-ort'), isEmpty);
      expect(feldText(tester, 'karto-abenteuer-feld-datum'), isEmpty);
    });

    testWidgets('eine Person bekommt Ort und Datum ebenfalls vorbelegt', (
      tester,
    ) async {
      await zeige(tester, held: mitDatum(), standort: 'Gareth');
      await tester.tap(key('karto-abenteuer-person-neu'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-1'), 'Yasmina');
      await speichern(tester);

      final person = (await gespeichert()).people.last;
      expect(person.ort, 'Gareth');
      expect(person.datum, '12. Phex 1043 BF');
    });

    testWidgets('Bearbeiten zeigt gespeicherte Werte, nicht die Vorbelegung', (
      tester,
    ) async {
      await zeige(
        tester,
        held: testHero().copyWith(
          adventures: [
            _nebel.copyWith(
              notes: const [
                HeroNoteEntry(
                  title: 'Wirt',
                  description: 'Weiß mehr.',
                  ort: 'Punin',
                  datum: '3. Rahja 1040 BF',
                ),
              ],
            ),
          ],
        ),
        standort: 'Gareth',
      );
      await tester.tap(find.text('Weiß mehr.'));
      await tester.pumpAndSettle();
      expect(feldText(tester, 'karto-abenteuer-feld-ort'), 'Punin');
      expect(
        feldText(tester, 'karto-abenteuer-feld-datum'),
        '3. Rahja 1040 BF',
      );
    });

    testWidgets(
      'ein Bestandseintrag wird beim Öffnen nicht von selbst befüllt',
      (tester) async {
        await zeige(tester, held: mitDatum(), standort: 'Gareth');
        await tester.tap(find.text('Weiß mehr.'));
        await tester.pumpAndSettle();
        expect(feldText(tester, 'karto-abenteuer-feld-ort'), isEmpty);
        // Unverändert speichern schreibt nichts: kein Ort, kein Stempel.
        await speichern(tester);
        final notiz = (await gespeichert()).notes.single;
        expect(notiz.ort, isEmpty);
        expect(notiz.lastModified, isNull);
      },
    );

    testWidgets('Ort und Datum nachtragen stempelt und erhält Fremdfelder', (
      tester,
    ) async {
      const feld = <String, Object?>{'zukunftsfeld': 1};
      await zeige(
        tester,
        held: testHero().copyWith(
          adventures: [
            _nebel.copyWith(
              notes: [_nebel.notes.single.copyWith(unbekannteFelder: feld)],
              people: [_nebel.people.single.copyWith(unbekannteFelder: feld)],
            ),
          ],
        ),
      );
      await tester.tap(find.text('Weiß mehr.'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-ort'), 'Punin');
      await speichern(tester);
      await tester.tap(find.text('Alrik'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-datum'), '1. Praios');
      await speichern(tester);

      final abenteuer = await gespeichert();
      expect(abenteuer.notes.single.ort, 'Punin');
      expect(abenteuer.notes.single.lastModified, isNotNull);
      expect(abenteuer.notes.single.unbekannteFelder, feld);
      expect(abenteuer.people.single.datum, '1. Praios');
      expect(abenteuer.people.single.unbekannteFelder, feld);
    });

    for (final breite in [320.0, 390.0]) {
      testWidgets(
        'der Dialog läuft bei $breite dp mit Textfaktor 2 nicht über',
        (tester) async {
          await zeige(
            tester,
            held: mitDatum(),
            standort: 'Gareth',
            breite: breite,
            skalierung: 2,
          );
          // Bei großer Schrift liegt die Kachel unter dem sichtbaren Rand.
          await tester.scrollUntilVisible(
            key('karto-abenteuer-notiz-neu'),
            300,
            scrollable: find
                .descendant(
                  of: find.byType(KartoAbenteuerblatt),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(key('karto-abenteuer-notiz-neu'));
          await tester.pumpAndSettle();
          expect(key('karto-abenteuer-feld-datum'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Suche', () {
    const alt = HeroAdventureEntry(
      id: 'alt',
      title: 'Die alte Fracht',
      status: HeroAdventureStatus.completed,
      notes: [
        HeroNoteEntry(
          title: 'Wirt am Pass',
          description: 'Zoll am Pass.',
          ort: 'Punin',
        ),
      ],
    );

    HeroSheet zwei() => testHero().copyWith(adventures: const [alt, _nebel]);

    Future<void> suche(WidgetTester tester, String text) async {
      if (key('karto-abenteuer-suche').evaluate().isEmpty) {
        await tester.tap(key('karto-abenteuer-suche-knopf'));
        await tester.pumpAndSettle();
      }
      await tester.enterText(key('karto-abenteuer-suche'), text);
      await tester.pumpAndSettle();
    }

    testWidgets('durchsucht alle Abenteuer, dieses steht vorn', (tester) async {
      await zeige(tester, held: zwei());
      await suche(tester, 'wirt');

      // „Wirt“ steckt in der Notiz und in „Schankwirt“ der Person, dazu die
      // Notiz „Wirt am Pass“ im anderen Abenteuer.
      expect(find.text('3 Treffer in 2 Abenteuern'), findsOneWidget);
      expect(find.text('Dieses Abenteuer'), findsOneWidget);
      expect(find.text('Abgeschlossen'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Wirt')).dy,
        lessThan(tester.getTopLeft(find.text('Wirt am Pass')).dy),
      );
      // Die Karten des Abenteuers selbst weichen den Treffern.
      expect(find.text('Noch keine Zusammenfassung.'), findsNothing);
      expect(key('karto-abenteuer-person-neu'), findsNothing);
    });

    testWidgets('Treffer im eigenen Abenteuer lassen sich bearbeiten', (
      tester,
    ) async {
      await zeige(tester, held: zwei());
      await suche(tester, 'wirt');
      await tester.tap(find.text('Weiß mehr.'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-2'), 'Weiß alles.');
      await speichern(tester);

      final held = (await repo.loadHeroById('rondra'))!;
      final nebel = held.adventures.firstWhere((a) => a.id == 'nebel');
      final alt = held.adventures.firstWhere((a) => a.id == 'alt');
      expect(nebel.notes.single.description, 'Weiß alles.');
      // Das andere Abenteuer bleibt unberührt.
      expect(alt.notes.single.description, 'Zoll am Pass.');
    });

    testWidgets('Treffer in einem anderen Abenteuer öffnet dessen Blatt', (
      tester,
    ) async {
      await zeige(tester, held: zwei());
      await suche(tester, 'zoll');
      await tester.tap(find.text('Wirt am Pass'));
      await tester.pumpAndSettle();
      // Zwei Blätter übereinander: Titel beider Abenteuer sind vorhanden.
      expect(find.byType(BottomSheet), findsNWidgets(2));
      expect(find.text('Die alte Fracht'), findsWidgets);
    });

    testWidgets('Schließen der Suche zeigt die Karten wieder', (tester) async {
      await zeige(tester, held: zwei());
      await suche(tester, 'zoll');
      await tester.tap(key('karto-abenteuer-suche-schliessen'));
      await tester.pumpAndSettle();
      expect(key('karto-abenteuer-suche'), findsNothing);
      expect(find.text('Weiß mehr.'), findsOneWidget);
    });

    testWidgets('ohne Treffer meldet die Suche das', (tester) async {
      await zeige(tester, held: zwei());
      await suche(tester, 'drachenhort');
      expect(key('karto-abenteuer-suche-leer'), findsOneWidget);
    });

    testWidgets('während einer Planung sind eigene Treffer nur lesbar', (
      tester,
    ) async {
      await zeige(tester, held: zwei(), planOffen: true);
      await suche(tester, 'wirt');
      await tester.tap(find.text('Weiß mehr.'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    for (final breite in [320.0, 390.0]) {
      testWidgets('Suche bei $breite dp mit Textfaktor 2 ohne Überlauf', (
        tester,
      ) async {
        await zeige(tester, held: zwei(), breite: breite, skalierung: 2);
        await suche(tester, 'wirt');
        expect(find.text('Wirt am Pass'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Sortierung', () {
    HeroSheet mitZweiNotizen() => testHero().copyWith(
      adventures: [
        _nebel.copyWith(
          notes: [
            HeroNoteEntry(
              title: 'Wirt',
              description: 'Weiß mehr.',
              lastModified: DateTime.utc(2026, 1, 1),
            ),
            const HeroNoteEntry(title: 'Brücke', description: 'Eingestürzt.'),
          ],
        ),
      ],
    );

    testWidgets('zuletzt bearbeitete Notiz steht vorn', (tester) async {
      await zeige(tester, held: mitZweiNotizen(), breite: 400);
      expect(
        tester.getTopLeft(find.text('Weiß mehr.')).dy,
        lessThan(tester.getTopLeft(find.text('Eingestürzt.')).dy),
      );
      expect(key('karto-abenteuer-sortierung'), findsOneWidget);
    });

    testWidgets('Bearbeiten stempelt die Notiz, unverändert nicht', (
      tester,
    ) async {
      await zeige(tester, held: mitZweiNotizen(), breite: 400);
      await tester.tap(find.text('Eingestürzt.'));
      await tester.pumpAndSettle();
      await speichern(tester);
      expect((await gespeichert()).notes[1].lastModified, isNull);

      await tester.tap(find.text('Eingestürzt.'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-2'), 'Repariert.');
      await speichern(tester);
      final notizen = (await gespeichert()).notes;
      expect(notizen.map((n) => n.title), ['Wirt', 'Brücke']);
      expect(notizen[1].lastModified, isNotNull);
      expect(
        notizen[1].lastModified!.isAfter(notizen[0].lastModified!),
        isTrue,
      );
    });

    testWidgets('alphabetisch bearbeitet die angetippte Notiz', (tester) async {
      await zeige(
        tester,
        held: mitZweiNotizen(),
        breite: 400,
        sortierung: AbenteuerSortierung.alphabetisch,
      );
      expect(
        tester.getTopLeft(find.text('Eingestürzt.')).dy,
        lessThan(tester.getTopLeft(find.text('Weiß mehr.')).dy),
      );
      await tester.tap(find.text('Weiß mehr.'));
      await tester.pumpAndSettle();
      await tester.enterText(key('karto-abenteuer-feld-2'), 'Weiß alles.');
      await speichern(tester);
      final notizen = (await gespeichert()).notes;
      expect(notizen[0].description, 'Weiß alles.');
      expect(notizen[1].description, 'Eingestürzt.');
    });
  });
}
