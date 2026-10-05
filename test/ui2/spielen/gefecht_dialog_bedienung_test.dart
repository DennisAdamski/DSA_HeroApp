import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_gefechts_bruecke.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_dialogabschnitte.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_zahlfeld.dart';

Widget _rahmen(Widget kind) => MaterialApp(
  home: Scaffold(body: Material(child: kind)),
);

void main() {
  testWidgets('Zahlfeld ändert per −/+ und hält die Untergrenze', (
    tester,
  ) async {
    final c = TextEditingController(text: '0');
    addTearDown(c.dispose);
    var meldungen = 0;
    await tester.pumpWidget(
      _rahmen(
        StatefulBuilder(
          builder: (context, setState) => GefechtZahlfeld(
            controller: c,
            label: 'Finte',
            minimum: 0,
            onChanged: () => setState(() => meldungen++),
          ),
        ),
      ),
    );
    final minus = find.byTooltip('Finte verringern');
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: minus, matching: find.byType(IconButton)),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Finte erhöhen'));
    await tester.tap(find.byTooltip('Finte erhöhen'));
    await tester.pump();
    expect(c.text, '2');
    await tester.tap(minus);
    await tester.pump();
    expect(c.text, '1');
    expect(meldungen, 3);
    // Ungültiger Text zählt für die Knöpfe als 0.
    c.text = 'x';
    await tester.pump();
    await tester.tap(find.byTooltip('Finte erhöhen'));
    await tester.pump();
    expect(c.text, '1');
  });

  testWidgets('Bestätigte Entscheidungen bleiben sichtbar und rücknehmbar', (
    tester,
  ) async {
    final bestaetigt = <String>{};
    await tester.pumpWidget(
      _rahmen(
        StatefulBuilder(
          builder: (context, setState) => GefechtEntscheidungen(
            offen: [
              for (final e in ['Anlauf geklärt'])
                if (!bestaetigt.contains(e)) e,
            ],
            bestaetigt: bestaetigt,
            onChanged: (e, v) => setState(() {
              v ? bestaetigt.add(e) : bestaetigt.remove(e);
            }),
          ),
        ),
      ),
    );
    final kachel = find.widgetWithText(CheckboxListTile, 'Anlauf geklärt');
    expect(tester.widget<CheckboxListTile>(kachel).value, isFalse);
    await tester.tap(kachel);
    await tester.pump();
    expect(bestaetigt, {'Anlauf geklärt'});
    expect(tester.widget<CheckboxListTile>(kachel).value, isTrue);
    await tester.tap(kachel);
    await tester.pump();
    expect(bestaetigt, isEmpty);
  });

  testWidgets('Herleitung bleibt eingeklappt erreichbar', (tester) async {
    await tester.pumpWidget(
      _rahmen(const GefechtBerechnung(zeilen: ['Distanzklasse: +6', ''])),
    );
    expect(find.text('Distanzklasse: +6'), findsNothing);
    await tester.tap(find.text('Berechnung und Regeltext'));
    await tester.pumpAndSettle();
    expect(find.text('Distanzklasse: +6'), findsOneWidget);
  });

  test('Gefechtsdialoge legen den Modifikator für AT/PA/Talente fest', () {
    expect(
      kGefechtsprobenMitFestemModifikator,
      containsAll([
        ProbeType.combatAttack,
        ProbeType.combatParry,
        ProbeType.dodge,
        ProbeType.spell,
        ProbeType.talent,
      ]),
    );
    expect(
      kGefechtsprobenMitFestemModifikator,
      isNot(contains(ProbeType.damage)),
    );
    expect(
      kGefechtsprobenMitFestemModifikator,
      isNot(contains(ProbeType.attribute)),
    );
  });

  testWidgets(
    'Gesperrter Modifikator zeigt den Gefechtswert schreibgeschützt',
    (tester) async {
      const request = ResolvedProbeRequest(
        type: ProbeType.talent,
        title: 'Selbstbeherrschung',
        subtitle: '',
        ruleHint: '',
        diceSpec: DiceSpec(count: 3, sides: 20),
        targets: [
          ProbeTargetValue(label: 'MU', value: 12),
          ProbeTargetValue(label: 'KO', value: 12),
          ProbeTargetValue(label: 'KK', value: 12),
        ],
        basePool: 5,
        initialSituationalModifier: -3,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProbeDialog(
              request: request,
              singleResolution: true,
              modifikatorGesperrt: true,
            ),
          ),
        ),
      );
      final feld = tester.widget<TextField>(
        find.byKey(const ValueKey('probe-dialog-modifier')),
      );
      expect(feld.enabled, isFalse);
      expect(feld.controller!.text, '-3');
      expect(find.text('Im Gefecht festgelegt.'), findsOneWidget);
    },
  );
}
