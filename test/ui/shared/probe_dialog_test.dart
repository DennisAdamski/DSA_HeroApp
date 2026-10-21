import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';

const _kAttrRequest = ResolvedProbeRequest(
  type: ProbeType.attribute,
  title: 'Eigenschaftsprobe: Mut',
  subtitle: 'MU',
  ruleHint: 'rule',
  diceSpec: DiceSpec(count: 1, sides: 20),
  targets: <ProbeTargetValue>[ProbeTargetValue(label: 'MU', value: 14)],
);

const _kDamageRequest = ResolvedProbeRequest(
  type: ProbeType.damage,
  title: 'Schadenswurf',
  subtitle: '1W6+4',
  ruleHint: 'rule',
  diceSpec: DiceSpec(count: 1, sides: 6, modifier: 4),
  targets: <ProbeTargetValue>[],
);

ResolvedProbeRequest _talentMitSpez() => const ResolvedProbeRequest(
  type: ProbeType.talent,
  title: 'Talentprobe: Athletik',
  subtitle: 'MU / GE / KK',
  ruleHint: '',
  diceSpec: DiceSpec(count: 3, sides: 20),
  targets: <ProbeTargetValue>[
    ProbeTargetValue(label: 'MU', value: 14),
    ProbeTargetValue(label: 'GE', value: 12),
    ProbeTargetValue(label: 'KK', value: 13),
  ],
  basePool: 7,
  specializationBonus: 2,
  spezialisierungen: <String>['Klettern', 'Springen'],
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _rollMainProbe(WidgetTester tester) async {
  await tester.tap(find.text('Würfeln').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

Future<void> _rollTrefferzone(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Trefferzone würfeln'));
  await tester.tap(find.text('Trefferzone würfeln'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dialog opens in idle state - kein Ergebnis vor dem Würfeln', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    expect(find.text('Eigenschaftsprobe: Mut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('probe-dialog-result-headline')),
      findsNothing,
    );
  });

  testWidgets('Ergebnis erscheint nach Klick auf Würfeln', (tester) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    await _rollMainProbe(tester);

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-result-headline')),
      findsOneWidget,
    );
  });

  testWidgets('manueller Modus wertet eingegebene Würfelwerte aus', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-0')),
      '20',
    );
    await tester.pumpAndSettle();

    expect(find.text('Misslungen'), findsOneWidget);
  });

  testWidgets('Der bedingte Poolschritt ist ein Schalter, anfangs aus', (
    tester,
  ) async {
    final request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Talentprobe: Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: const DiceSpec(count: 3, sides: 20),
      targets: const <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 14),
        ProbeTargetValue(label: 'GE', value: 12),
        ProbeTargetValue(label: 'KK', value: 13),
      ],
      basePool: 7,
      poolHerleitung: Herleitung(
        bezeichnung: 'TaW*',
        schritte: const <HerleitungsSchritt>[
          HerleitungsSchritt(
            bezeichnung: 'TaW',
            betrag: 7,
            art: HerleitungsArt.zukauf,
          ),
        ],
      ),
      bedingterPoolSchritt: const HerleitungsSchritt(
        bezeichnung: 'Axxeleratus (Sprint/Sprung)',
        betrag: 7,
        art: HerleitungsArt.zauber,
        formel: 'Athletik-TaW 7 verdoppelt',
        bedingung: 'nur Sprints und Sprünge',
      ),
    );

    await tester.pumpWidget(_wrap(ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    final schalter = find.byKey(
      const ValueKey<String>('probe-dialog-bedingter-pool'),
    );
    expect(schalter, findsOneWidget);
    expect(find.text('Axxeleratus (Sprint/Sprung) (+7)'), findsOneWidget);
    expect(find.text('Pool: 7'), findsOneWidget);

    await tester.ensureVisible(schalter);
    await tester.tap(schalter);
    await tester.pumpAndSettle();

    expect(find.text('Pool: 14'), findsOneWidget);

    await tester.ensureVisible(schalter);
    await tester.tap(schalter);
    await tester.pumpAndSettle();

    expect(find.text('Pool: 7'), findsOneWidget);
  });

  testWidgets('Ohne bedingten Poolschritt gibt es keinen Schalter', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-bedingter-pool')),
      findsNothing,
    );
  });

  testWidgets('Talentproben zeigen den Spezialisierungs-Toggle', (
    tester,
  ) async {
    const request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Talentprobe: Athletik',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 14),
        ProbeTargetValue(label: 'GE', value: 12),
        ProbeTargetValue(label: 'KK', value: 13),
      ],
      basePool: 7,
      specializationBonus: 2,
    );

    await tester.pumpWidget(_wrap(const ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-specialization')),
      findsOneWidget,
    );
  });

  testWidgets('Die TaW*-Herleitung lässt sich im Dialog aufklappen', (
    tester,
  ) async {
    final request = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Talentprobe: Klettern',
      subtitle: 'MU / GE / KK',
      ruleHint: 'rule',
      diceSpec: const DiceSpec(count: 3, sides: 20),
      targets: const <ProbeTargetValue>[
        ProbeTargetValue(label: 'MU', value: 14),
        ProbeTargetValue(label: 'GE', value: 12),
        ProbeTargetValue(label: 'KK', value: 13),
      ],
      basePool: 7,
      poolHerleitung: Herleitung(
        bezeichnung: 'TaW*',
        schritte: const <HerleitungsSchritt>[
          HerleitungsSchritt(
            bezeichnung: 'TaW',
            betrag: 9,
            art: HerleitungsArt.zukauf,
          ),
          HerleitungsSchritt(
            bezeichnung: 'eBE',
            betrag: -2,
            art: HerleitungsArt.modifikator,
            quelle: 'Rüstung',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(ProbeDialog(request: request)));
    await tester.pumpAndSettle();

    const tile = ValueKey<String>('probe-dialog-pool-herleitung');
    expect(find.byKey(tile), findsOneWidget);
    expect(find.text('eBE'), findsNothing);

    await tester.tap(find.text('TaW* herleiten'));
    await tester.pumpAndSettle();

    expect(find.text('eBE'), findsOneWidget);
    expect(find.text('Rüstung'), findsOneWidget);
    final wert = tester.widget<Text>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('probe-dialog-pool-herleitung-wert'),
        ),
        matching: find.text('7'),
      ),
    );
    expect(wert.data, '7');
  });

  testWidgets('Spezialisierung wird gewählt und erhöht den Pool um 2', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(ProbeDialog(request: _talentMitSpez())));
    await tester.pumpAndSettle();

    expect(find.text('Pool: 7'), findsOneWidget);
    expect(find.text('MU: 14 | GE: 12 | KK: 13'), findsOneWidget);
    expect(find.text('Spezialisierung (+2 auf TaW)'), findsOneWidget);

    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-0')),
      '19',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-1')),
      '12',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-2')),
      '13',
    );
    await tester.pumpAndSettle();
    // 5 Überschreitung bei MU, Pool 7: Rest 2.
    expect(find.text('Verbleibender Pool: 2'), findsOneWidget);

    await tester.tap(find.text('Klettern'));
    await tester.pumpAndSettle();
    expect(find.text('Verbleibender Pool: 4'), findsOneWidget);

    await tester.tap(find.byKey(
      const ValueKey<String>('probe-dialog-specialization-keine'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Verbleibender Pool: 2'), findsOneWidget);
  });

  testWidgets('Manuelle Würfel tragen den Eigenschaftsnamen', (tester) async {
    await tester.pumpWidget(_wrap(ProbeDialog(request: _talentMitSpez())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();

    expect(find.text('MU (14)'), findsOneWidget);
    expect(find.text('GE (12)'), findsOneWidget);
    expect(find.text('KK (13)'), findsOneWidget);
  });

  testWidgets('Alle Würfe unter dem Ziel zeigen den knappsten Abstand', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(ProbeDialog(request: _talentMitSpez())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    for (final (i, wert) in [10, 12, 5].indexed) {
      await tester.enterText(
        find.byKey(ValueKey<String>('probe-dialog-die-$i')),
        '$wert',
      );
    }
    await tester.pumpAndSettle();

    expect(
      find.text('Knappster Wurf: GE, Abstand zum Zielwert 0'),
      findsOneWidget,
    );
  });

  testWidgets('Modifikator lässt sich mit + und − ändern', (tester) async {
    final fired = <ProbeResult>[];
    await tester.pumpWidget(
      _wrap(ProbeDialog(request: _kAttrRequest, onResolved: fired.add)),
    );
    await tester.pumpAndSettle();

    String modifikator() => tester
        .widget<TextField>(
          find.byKey(const ValueKey<String>('probe-dialog-modifier')),
        )
        .controller!
        .text;

    expect(modifikator(), '0');
    await tester.tap(
      find.byKey(const ValueKey<String>('probe-dialog-modifier-minus')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('probe-dialog-modifier-minus')),
    );
    await tester.pumpAndSettle();
    expect(modifikator(), '-2');
    await tester.tap(
      find.byKey(const ValueKey<String>('probe-dialog-modifier-plus')),
    );
    await tester.pumpAndSettle();
    expect(modifikator(), '-1');
    expect(fired, isEmpty);
  });

  testWidgets('Zauberdetails klappen Wirkung und Varianten auf', (
    tester,
  ) async {
    final request = _talentMitSpez().copyWith();
    final zauber = ResolvedProbeRequest(
      type: ProbeType.spell,
      title: 'Zauberprobe: Test',
      subtitle: 'KL / IN / CH',
      ruleHint: '',
      diceSpec: const DiceSpec(count: 3, sides: 20),
      targets: request.targets,
      basePool: 5,
      kontext: const ProbeKontext(
        wirkung: 'Der Zauber wirkt.',
        variantenRoh: <String>['Mehr Reichweite'],
        kosten: '7 AsP',
        zauberdauer: '2 Aktionen',
      ),
    );
    await tester.pumpWidget(_wrap(ProbeDialog(request: zauber)));
    await tester.pumpAndSettle();

    expect(find.text('Kosten: 7 AsP · Dauer: 2 Aktionen'), findsOneWidget);
    expect(find.text('Der Zauber wirkt.'), findsNothing);

    await tester.tap(find.text('Zauberdetails'));
    await tester.pumpAndSettle();

    expect(find.text('Der Zauber wirkt.'), findsOneWidget);
    expect(find.text('• Mehr Reichweite'), findsOneWidget);
  });

  testWidgets('Ohne Herleitung gibt es keinen Herleitungsblock', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProbeDialog(request: _kAttrRequest)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('probe-dialog-pool-herleitung')),
      findsNothing,
    );
  });

  testWidgets('onResolved feuert nach digitalem Wurf genau einmal', (
    tester,
  ) async {
    final fired = <ProbeResult>[];

    await tester.pumpWidget(
      _wrap(ProbeDialog(request: _kAttrRequest, onResolved: fired.add)),
    );
    await tester.pumpAndSettle();

    await _rollMainProbe(tester);

    expect(fired, hasLength(1));
    expect(fired.single.request.type, ProbeType.attribute);
  });

  testWidgets(
    'onResolved feuert nicht, wenn nur der Modifikator geändert wird',
    (tester) async {
      final fired = <ProbeResult>[];

      await tester.pumpWidget(
        _wrap(ProbeDialog(request: _kAttrRequest, onResolved: fired.add)),
      );
      await tester.pumpAndSettle();

      await _rollMainProbe(tester);
      expect(fired, hasLength(1));

      await tester.enterText(
        find.byKey(const ValueKey<String>('probe-dialog-modifier')),
        '-2',
      );
      await tester.pumpAndSettle();

      expect(
        fired,
        hasLength(1),
        reason: 'live refresh darf den Logeintrag nicht erneut auslösen',
      );
    },
  );

  testWidgets('onResolved feuert im manuellen Modus nach Auswerten', (
    tester,
  ) async {
    final fired = <ProbeResult>[];

    await tester.pumpWidget(
      _wrap(ProbeDialog(request: _kAttrRequest, onResolved: fired.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-0')),
      '7',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auswerten'));
    await tester.pumpAndSettle();

    expect(fired, hasLength(1));
    expect(fired.single.input.mode, ProbeRollMode.manual);
  });

  testWidgets(
    'Schadenswurf zeigt Trefferzonen-Stepper und keinen gezielten Schlag mehr',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProbeDialog(
            request: _kDamageRequest,
            rollTrefferzone: _rollBrust,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _rollMainProbe(tester);
      await _rollTrefferzone(tester);

      expect(find.text('Brust'), findsOneWidget);
      expect(find.textContaining('Gezielter Schlag'), findsNothing);
      expect(find.text('Wunden durch Treffer'), findsOneWidget);
      expect(find.text('1W6 würfeln'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.arrow_drop_up));
      await tester.tap(find.byIcon(Icons.arrow_drop_up));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('trefferzonen-wunden-value')),
        findsOneWidget,
      );
      expect(find.text('2W6 würfeln'), findsOneWidget);
    },
  );

  testWidgets('onDiceLogEntry feuert fuer Trefferzone und Zusatzwurf', (
    tester,
  ) async {
    final fired = <DiceLogEntry>[];

    await tester.pumpWidget(
      _wrap(
        ProbeDialog(
          request: _kDamageRequest,
          rollTrefferzone: _rollBrust,
          onDiceLogEntry: fired.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _rollMainProbe(tester);
    await _rollTrefferzone(tester);

    expect(fired, hasLength(1));
    expect(fired.single.title, 'Trefferzone');
    expect(fired.single.isNeutral, isTrue);

    await tester.ensureVisible(find.text('1W6 würfeln'));
    await tester.tap(find.text('1W6 würfeln'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(fired, hasLength(2));
    expect(fired.last.title, 'Extraschaden');
    expect(fired.last.isNeutral, isTrue);
  });
}

int _rollBrust() => 15;
