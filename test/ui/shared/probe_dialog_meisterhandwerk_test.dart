import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meisterhandwerk_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

final _request = ResolvedProbeRequest(
  type: ProbeType.talent,
  title: 'Talentprobe: Singen',
  subtitle: 'IN / CH / KO',
  ruleHint: '',
  diceSpec: DiceSpec(count: 3, sides: 20),
  targets: <ProbeTargetValue>[
    ProbeTargetValue(label: 'IN', value: 12),
    ProbeTargetValue(label: 'CH', value: 12),
    ProbeTargetValue(label: 'KO', value: 12),
  ],
  basePool: 7,
  poolHerleitung: Herleitung(
    bezeichnung: 'TaW*',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: kTalentTawSchritt,
        betrag: 7,
        art: HerleitungsArt.zukauf,
      ),
    ],
  ),
);

const _angebot = MeisterhandwerkAngebot(
  talent: 'Singen',
  taw: 7,
  verfuegbareAsp: 10,
  quelle: 'Meisterhandwerk Singen',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _manuell(WidgetTester tester, List<int> wuerfe) async {
  await tester.tap(find.text('Manuell'));
  await tester.pumpAndSettle();
  for (var i = 0; i < wuerfe.length; i++) {
    await tester.enterText(
      find.byKey(ValueKey<String>('probe-dialog-die-$i')),
      '${wuerfe[i]}',
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _tippe(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ohne Angebot erscheint kein Meisterhandwerk', (tester) async {
    await tester.pumpWidget(_wrap(ProbeDialog(request: _request)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-meisterhandwerk')),
      findsNothing,
    );
  });

  testWidgets('Vorabeinsatz erhöht den Pool und wird beim Auswerten gebucht', (
    tester,
  ) async {
    final buchungen = <MeisterhandwerkBuchung>[];
    final ergebnisse = <ProbeResult>[];
    await tester.pumpWidget(
      _wrap(
        ProbeDialog(
          request: _request,
          meisterhandwerk: _angebot,
          onResolved: ergebnisse.add,
          onMeisterhandwerk: buchungen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pool: 7'), findsOneWidget);
    final plus = find.byKey(
      const ValueKey<String>('probe-dialog-mh-vorab-plus'),
    );
    await _tippe(tester, plus);
    await _tippe(tester, plus);
    expect(find.text('Pool: 11'), findsOneWidget);
    await _tippe(tester, plus);
    await _tippe(tester, plus);
    expect(find.text('Pool: 13'), findsOneWidget, reason: 'höchstens 3 AsP');

    await _manuell(tester, <int>[15, 15, 15]);
    expect(buchungen, isEmpty, reason: 'gebucht wird erst beim Auswerten');
    await _tippe(tester, find.text('Auswerten'));

    expect(ergebnisse.single.compensationPoolStart, 13);
    expect(ergebnisse.single.remainingPool, 4);
    expect(buchungen.single.asp, 3);
    expect(buchungen.single.beschreibung, '3 AsP vorab (+6 TaW)');
  });

  testWidgets('rettet eine ausgewertete misslungene Probe', (tester) async {
    final buchungen = <MeisterhandwerkBuchung>[];
    await tester.pumpWidget(
      _wrap(
        ProbeDialog(
          request: _request,
          meisterhandwerk: _angebot,
          onMeisterhandwerk: buchungen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _manuell(tester, <int>[16, 17, 10]);
    final retten = find.byKey(const ValueKey<String>('probe-dialog-mh-retten'));
    expect(retten, findsNothing, reason: 'erst nach dem Auswerten');

    await _tippe(tester, find.text('Auswerten'));
    expect(find.text('Misslungen'), findsOneWidget);
    expect(find.text('Mit 2 AsP retten'), findsOneWidget);

    await _tippe(tester, retten);

    expect(find.text('Erfolg'), findsOneWidget);
    expect(find.text('Verbleibender Pool: 0'), findsOneWidget);
    expect(
      find.text('Meisterhandwerk eingesetzt: 2 AsP: Probe gerettet'),
      findsOneWidget,
    );
    expect(retten, findsNothing);
    expect(buchungen.single.asp, 2);
  });

  testWidgets('verbessert eine gelungene Probe mit Erschöpfung', (
    tester,
  ) async {
    final buchungen = <MeisterhandwerkBuchung>[];
    await tester.pumpWidget(
      _wrap(
        ProbeDialog(
          request: _request,
          meisterhandwerk: _angebot,
          onMeisterhandwerk: buchungen.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Überschreitung 5 bei Pool 7: TaP* 2.
    await _manuell(tester, <int>[17, 10, 10]);
    await _tippe(tester, find.text('Auswerten'));
    expect(find.text('TaP* +1: 1 AsP'), findsOneWidget);

    final plus = find.byKey(
      const ValueKey<String>('probe-dialog-mh-punkte-plus'),
    );
    await _tippe(tester, plus);
    await _tippe(tester, plus);
    expect(find.text('TaP* +3: 4 AsP, 1 Erschöpfung'), findsOneWidget);

    await _tippe(
      tester,
      find.byKey(const ValueKey<String>('probe-dialog-mh-verbessern')),
    );

    expect(find.text('Verbleibender Pool: 5'), findsOneWidget);
    expect(buchungen.single.asp, 4);
    expect(buchungen.single.erschoepfung, 1);
  });
}
