import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_base_providers.dart';
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
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = FakeRepository(heroes: [held ?? _held()]);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
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
    expect(yasmina.dx, greaterThan(alrik.dx));
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
}
