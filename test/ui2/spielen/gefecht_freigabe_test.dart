import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_manoeverliste.dart';

import '../shell/karto_test_support.dart';

void main() {
  testWidgets('Manöverliste bietet kombinierbare Kategorien und Statusfilter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GefechtManoeverliste(
            manoever: const [
              ManeuverDef(id: 'a', name: 'Angriff', typ: 'Attacke'),
            ],
            knopf: (m) => Text(m.name),
          ),
        ),
      ),
    );
    expect(find.text('Nur erlernte'), findsOneWidget);
    expect(find.text('Ohne bekannte Sperre'), findsOneWidget);
    expect(find.text('Sonstige'), findsOneWidget);
  });
  testWidgets(
    'Kategorie und beide Statusfilter begrenzen sichtbare Manöver gemeinsam',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GefechtManoeverliste(
              manoever: const [
                ManeuverDef(id: 'a', name: 'Erlernt frei', typ: 'Parade'),
                ManeuverDef(id: 'b', name: 'Erlernt gesperrt', typ: 'Parade'),
                ManeuverDef(id: 'c', name: 'Ungelernt frei', typ: 'Parade'),
                ManeuverDef(id: 'd', name: 'Angriff frei', typ: 'Attacke'),
              ],
              erlernt: (m) => m.id != 'c',
              gesperrt: (m) => m.id == 'b',
              knopf: (m) => Text(m.name),
            ),
          ),
        ),
      );
      expect(find.text('Angriff frei'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Verteidigung'));
      await tester.pumpAndSettle();
      expect(find.text('Angriff frei'), findsNothing);
      expect(find.text('Ungelernt frei'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Nur erlernte'));
      await tester.pumpAndSettle();
      expect(find.text('Ungelernt frei'), findsNothing);
      expect(find.text('Erlernt gesperrt'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Ohne bekannte Sperre'));
      await tester.pumpAndSettle();
      expect(find.text('Erlernt gesperrt'), findsNothing);
      expect(find.text('Erlernt frei'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Alle'));
      await tester.pumpAndSettle();
      expect(find.text('Angriff frei'), findsOneWidget);
      expect(find.text('Ungelernt frei'), findsNothing);
      expect(find.text('Erlernt gesperrt'), findsNothing);
    },
  );
  final snapshot = buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
    ),
    state: const HeroState.empty(),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  for (final verboten in [null, true]) {
    testWidgets('Nahkampf-PA ohne allgemeine Paradefrage, Verbot $verboten', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GefechtAktionsdialog(
              zustand: Gefechtszustand(
                iniWurf: 6,
                dk: 'N',
                kontext: Gefechtskontext(
                  angriffsart: Gefechtsangriffsart.nahkampf,
                  finte: 0,
                  paradeVerboten: verboten,
                ),
              ),
              werte: snapshot,
              katalog: testCatalog,
              aktion: Gefechtsaktion.parade,
              titel: 'Parieren',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Parade erlaubt?'), findsNothing);
      expect(find.text('Angriff gegen mich'), findsOneWidget);
      expect(find.text('Gegnerische Finte (0 erlaubt)'), findsOneWidget);
      final starten = tester.widget<FilledButton>(
        find.byKey(const ValueKey('gefecht-auftrag-starten')),
      );
      expect(starten.onPressed != null, verboten != true);
      if (verboten == true) {
        expect(
          find.textContaining('Dieser Angriff kann nicht pariert werden.'),
          findsWidgets,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Gegnerische Finte (0 erlaubt)'),
          '2',
        );
        await tester.pumpAndSettle();
        final nachAenderung = tester.widget<FilledButton>(
          find.byKey(const ValueKey('gefecht-auftrag-starten')),
        );
        expect(nachAenderung.onPressed, isNull);
      }
    });
  }
  Future<void> dialog(
    WidgetTester tester, {
    ManeuverDef? m,
    String? dk = 'N',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GefechtAktionsdialog(
            zustand: Gefechtszustand(iniWurf: 6, dk: dk),
            werte: snapshot,
            katalog: testCatalog,
            aktion: Gefechtsaktion.angriff,
            titel: 'Angreifen',
            manoever: m,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Vollständiger Angriff benötigt keinen pauschalen Pflichthaken', (
    tester,
  ) async {
    await dialog(tester);
    expect(
      find.byKey(const ValueKey('gefecht-kontext-bestaetigen')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('gefecht-auftrag-starten')),
          )
          .onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'Freie Zusatzwerte beginnen trotz festem Katalogzuschlag bei null',
    (tester) async {
      await dialog(
        tester,
        m: const ManeuverDef(
          id: 'test',
          name: 'Test',
          typ: 'Attacke',
          erschwernis: '+4',
        ),
      );
      final zahlen = tester.widgetList<TextField>(find.byType(TextField));
      expect(zahlen.first.controller!.text, '0');
      expect(find.text('Fester Manöverzuschlag: +4'), findsOneWidget);
    },
  );
  testWidgets(
    'Fehlende Distanz wird beim Ausführen erklärt und Namen sind vollständig',
    (tester) async {
      await dialog(tester, dk: null);
      expect(
        find.byKey(const ValueKey('gefecht-ausfuehrung-gruende')),
        findsOneWidget,
      );
      final dropdown = find.byType(DropdownButtonFormField<String>);
      final texte = tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: dropdown,
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .map((item) => (item.child as Text).data)
          .toList();
      expect(texte, ['Handgemenge', 'Nahkampf', 'Stangenwaffen', 'Piken']);
    },
  );
}
