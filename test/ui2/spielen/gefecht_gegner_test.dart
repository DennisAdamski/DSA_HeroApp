import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_angriffsergebnis.dart';

import 'gefecht_test_support.dart';

void main() {
  testWidgets('Besondere Treffer übertragen nur ausdrücklich bestätigte SP', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final ctl = c.read(gefechtProvider('h').notifier);
    ctl.beginnen(6);
    const e = Gefechtsangriffsergebnis(
      auftragId: 'hammerschlag',
      kampfmittel: GefechtsKampfmittelwahl(
        GefechtsKampfmittelArt.hauptwaffe,
        'w',
      ),
      waffenname: 'Schwert',
      schaden: DiceSpec(count: 1, sides: 6),
      abwehrmalus: 0,
      tpBonus: 0,
      gegnerId: 'a',
      manoeverId: 'man_hammerschlag',
      gewuerfelteTp: 6,
      hinweis: 'Gesamte TP verdreifachen; besondere Folgen klären.',
    );
    ctl.setzen(c.read(gefechtProvider('h'))!.copyWith(angriffsergebnisse: [e]));
    c
        .read(gefechtBegegnungProvider.notifier)
        .speichern(
          const Gefechtsgegner(id: 'a', name: 'Ork', lep: 20, rs: 2, ini: 12),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  for (final hit
                      in ref.watch(gefechtProvider('h'))!.angriffsergebnisse)
                    GefechtAngriffsergebnisAnzeige(
                      ergebnis: hit,
                      heroId: 'h',
                      bestand: GefechtsTestBestand(),
                      gesperrt: false,
                      onAktion: (a) => a(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final normal = find.widgetWithText(
      FilledButton,
      'Nicht abgewehrt · Treffer übernehmen',
    );
    expect(tester.widget<FilledButton>(normal).onPressed, isNull);
    await tester.tap(find.text('Besondere Folgen klären · SP übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 20);
    expect(c.read(gefechtProvider('h'))!.angriffsergebnisse, hasLength(1));
    await tester.tap(find.text('Besondere Folgen klären · SP übernehmen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '16');
    await tester.tap(find.text('Nicht abgewehrt · SP bestätigt'));
    await tester.pumpAndSettle();
    expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 4);
    expect(c.read(gefechtProvider('h'))!.angriffsergebnisse, isEmpty);
  });
  testWidgets(
    'Schadenswurf bleibt am ursprünglichen Ziel und wird nur einmal übernommen',
    (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ctl = c.read(gefechtProvider('h').notifier);
      ctl.beginnen(6);
      const e = Gefechtsangriffsergebnis(
        auftragId: 'treffer',
        kampfmittel: GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.hauptwaffe,
          'w',
        ),
        waffenname: 'Schwert',
        schaden: DiceSpec(count: 1, sides: 6),
        abwehrmalus: 0,
        tpBonus: 0,
        gegnerId: 'a',
      );
      ctl.setzen(
        c.read(gefechtProvider('h'))!.copyWith(angriffsergebnisse: [e]),
      );
      final gegner = c.read(gefechtBegegnungProvider.notifier);
      gegner.speichern(
        const Gefechtsgegner(id: 'a', name: 'Ork', lep: 20, rs: 2, ini: 12),
      );
      gegner.speichern(
        const Gefechtsgegner(id: 'b', name: 'Ork', lep: 30, rs: 3, ini: 15),
      );
      final bestand = GefechtsTestBestand()..doppelt = true;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final s = ref.watch(gefechtProvider('h'))!;
                  return Column(
                    children: [
                      for (final treffer in s.angriffsergebnisse)
                        GefechtAngriffsergebnisAnzeige(
                          ergebnis: treffer,
                          heroId: 'h',
                          bestand: bestand,
                          gesperrt: false,
                          onAktion: (a) => a(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('gefecht-angriffsschaden')));
      await tester.pumpAndSettle();
      expect(c.read(gefechtProvider('h'))!.angriffsergebnis!.gewuerfelteTp, 6);
      expect(
        find.byKey(const ValueKey('gefecht-angriffsschaden')),
        findsNothing,
      );
      expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 20);
      await tester.tap(find.text('Nicht abgewehrt · Treffer übernehmen'));
      await tester.pump();
      expect(c.read(gefechtBegegnungProvider).gegner['a']!.lep, 16);
      expect(c.read(gefechtBegegnungProvider).gegner['b']!.lep, 30);
      expect(c.read(gefechtProvider('h'))!.angriffsergebnisse, isEmpty);
      expect(bestand.anfragen.length, 1);
    },
  );
  testWidgets('Mehrere gleichnamige Gegner: Auswahl und flüchtiger Treffer', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(gefechtProvider('h').notifier).beginnen(6, dk: 'N');
    final c = container.read(gefechtBegegnungProvider.notifier);
    for (final id in ['a', 'b']) {
      c.speichern(Gefechtsgegner(id: id, name: 'Ork', lep: 20, rs: 3, ini: 12));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GefechtGegnerkarte(
                heroId: 'h',
                waffenDk: 'N',
                fernkampf: false,
                gesperrt: false,
                onAktion: _direkt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('gegner-ziel-b')));
    await tester.pump();
    expect(container.read(gefechtProvider('h'))!.kontext.gegnerId, 'b');
    await tester.tap(find.text('Treffer übernehmen').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '8');
    await tester.tap(find.text('Treffer bestätigt'));
    await tester.pumpAndSettle();
    expect(container.read(gefechtBegegnungProvider).gegner['b']!.lep, 15);
    expect(container.read(gefechtBegegnungProvider).gegner['a']!.lep, 20);
    final frisch = ProviderContainer();
    addTearDown(frisch.dispose);
    expect(frisch.read(gefechtBegegnungProvider).gegner, isEmpty);
  });

  testWidgets('Gegnerdialog verlangt Werte, Abbruch erhält Begegnung', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GefechtGegnerkarte(
              heroId: 'h',
              waffenDk: 'N',
              fernkampf: false,
              gesperrt: false,
              onAktion: _direkt,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('+ Gegner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Übernehmen'));
    await tester.pump();
    expect(find.text('Name eingeben.'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LeP 20'), findsNothing);
  });
}

// Führt Kartenaktionen ohne Ansicht direkt aus.
Future<void> _direkt(Future<void> Function() aktion) => aktion();
