import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_dialogabschnitte.dart';

import '../../rules/gefecht_meisterparade_rules_test.dart' as mp;
import 'gefecht_test_support.dart';

Widget _rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: Material(child: kind)),
);

void main() {
  testWidgets('GefechtBerechnung zeigt Herleitungen vor dem Regeltext', (
    tester,
  ) async {
    final erschwernis = Herleitung(
      bezeichnung: 'Erschwernis',
      schritte: const [
        HerleitungsSchritt(
          bezeichnung: 'Nach Bewegen',
          betrag: 4,
          art: HerleitungsArt.modifikator,
          formel: 'WdS S. 55',
        ),
      ],
    );
    await tester.pumpWidget(
      _rahmen(
        GefechtBerechnung(
          herleitungen: [erschwernis],
          zeilen: const ['Regeltext'],
        ),
      ),
    );
    expect(find.text('Nach Bewegen'), findsNothing);
    await tester.tap(find.text('Berechnung und Regeltext'));
    await tester.pumpAndSettle();
    expect(find.text('Nach Bewegen'), findsOneWidget);
    expect(find.text('WdS S. 55'), findsOneWidget);
    expect(find.text('+4'), findsWidgets);
    expect(find.text('Regeltext'), findsOneWidget);
    // Die Herleitung steht über dem Regeltext.
    expect(
      tester.getTopLeft(find.text('Nach Bewegen')).dy,
      lessThan(tester.getTopLeft(find.text('Regeltext')).dy),
    );
  });

  testWidgets('Aktionsdialog: Zielwert und Erschwernis als Herleitung', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const katalog = RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [],
      spells: [],
      weapons: [],
      maneuvers: [],
    );
    final container = ProviderContainer(
      overrides: [
        heroComputedProvider('rondra')
            .overrideWith((ref) => AsyncData(mp.mpSnapshot())),
        rulesCatalogProvider.overrideWith((ref) async => katalog),
      ],
    );
    addTearDown(container.dispose);
    final ctl = container.read(gefechtProvider('rondra').notifier)..beginnen(6);
    ctl.setzen(
      container
          .read(gefechtProvider('rondra'))!
          .copyWith(
            dk: 'N',
            kontext: const Gefechtskontext(
              angriffsart: Gefechtsangriffsart.nahkampf,
              finte: 0,
              schildWmWirksam: true,
              situationsZuschlag: 0,
            ),
          ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GefechtAnsicht(
            heroId: 'rondra',
            bestand: GefechtsTestBestand()..w20Wert = 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final angreifen = find.text('Angreifen').first;
    await tester.ensureVisible(angreifen);
    await tester.tap(angreifen);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gefecht-finte')), '2');
    await tester.pump();
    final berechnung = find.text('Berechnung und Regeltext');
    await tester.ensureVisible(berechnung);
    await tester.tap(berechnung);
    await tester.pumpAndSettle();

    final zielwert = find.byKey(const ValueKey('gefecht-herleitung-Zielwert'));
    final erschwernis = find.byKey(
      const ValueKey('gefecht-herleitung-Erschwernis'),
    );
    expect(zielwert, findsOneWidget);
    expect(erschwernis, findsOneWidget);
    expect(
      find.descendant(of: erschwernis, matching: find.text('Finte')),
      findsOneWidget,
    );
    // Das Ergebnis der Zielwert-Herleitung steht auch auf dem Knopf.
    final knopf =
        tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('gefecht-auftrag-starten')),
                )
                .child
            as Text;
    final wert = knopf.data!.replaceFirst('Würfeln · ', '');
    expect(
      find.descendant(of: zielwert, matching: find.text(wert)),
      findsWidgets,
    );
  });
}
