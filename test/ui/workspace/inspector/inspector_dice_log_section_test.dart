import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

DiceLogEntry _entry({
  required int hour,
  required int minute,
  required bool success,
  String title = 'Probe · KL',
  String subtitle = 'Eigenschaftsprobe ≤ 12',
  AutomaticOutcome outcome = AutomaticOutcome.none,
}) {
  return DiceLogEntry(
    timestamp: DateTime.utc(2026, 4, 30, hour, minute),
    type: ProbeType.attribute,
    title: title,
    subtitle: subtitle,
    success: success,
    diceValues: const [9],
    targetValue: 12,
    automaticOutcome: outcome,
  );
}

void main() {
  testWidgets('renders empty hint when log is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(const InspectorDiceLogSection(entries: <DiceLogEntry>[])),
    );

    expect(find.textContaining('Noch keine'), findsOneWidget);
  });

  testWidgets('renders entries with newest first', (tester) async {
    final older = _entry(
      hour: 8,
      minute: 0,
      success: true,
      title: 'Probe · KL',
    );
    final newer = _entry(
      hour: 8,
      minute: 5,
      success: false,
      title: 'Probe · IN',
    );

    await tester.pumpWidget(
      _wrap(InspectorDiceLogSection(entries: [older, newer])),
    );

    final klFinder = find.text('Probe · KL');
    final inFinder = find.text('Probe · IN');
    expect(klFinder, findsOneWidget);
    expect(inFinder, findsOneWidget);

    final klPos = tester.getTopLeft(klFinder).dy;
    final inPos = tester.getTopLeft(inFinder).dy;
    expect(inPos, lessThan(klPos), reason: 'newer entry must be above older');
  });

  testWidgets('renders GELUNGEN for success and MISSLUNGEN for failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        InspectorDiceLogSection(
          entries: [
            _entry(hour: 8, minute: 0, success: true),
            _entry(hour: 8, minute: 1, success: false),
          ],
        ),
      ),
    );

    expect(find.text('GELUNGEN'), findsOneWidget);
    expect(find.text('MISSLUNGEN'), findsOneWidget);
  });

  testWidgets('renders AUTO label on automatic success', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InspectorDiceLogSection(
          entries: [
            _entry(
              hour: 8,
              minute: 0,
              success: true,
              outcome: AutomaticOutcome.success,
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('AUTO'), findsOneWidget);
  });

  group('Spielabende (SPIEL-05)', () {
    // Mittags in UTC, damit die Ortszeit in jeder Zeitzone denselben Tag zeigt.
    final jetzt = DateTime(2026, 10, 23, 12, 0);

    DiceLogEntry wurf(DateTime utc, String titel, {ProbeType? type}) =>
        DiceLogEntry(
          timestamp: utc,
          type: type ?? ProbeType.attribute,
          title: titel,
          subtitle: '',
          success: true,
          diceValues: const [9],
          targetValue: 12,
        );

    final alt1 = wurf(DateTime.utc(2026, 10, 16, 12, 0), 'Alter Wurf 1');
    final alt2 = wurf(DateTime.utc(2026, 10, 16, 13, 0), 'Alter Wurf 2');
    final neu = wurf(DateTime.utc(2026, 10, 23, 8, 0), 'Neuer Wurf');

    testWidgets('mehrere Abende bekommen Überschriften, neueste zuerst', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: InspectorDiceLogSection(
              entries: [alt1, alt2, neu],
              jetzt: jetzt,
            ),
          ),
        ),
      );

      expect(find.text('Heute'), findsOneWidget);
      expect(find.text('Fr, 16.10.2026'), findsOneWidget);
      expect(find.text('1 Wurf'), findsOneWidget);
      expect(find.text('2 Würfe'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Heute')).dy,
        lessThan(tester.getTopLeft(find.text('Fr, 16.10.2026')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Neuer Wurf')).dy,
        lessThan(tester.getTopLeft(find.text('Alter Wurf 2')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Alter Wurf 2')).dy,
        lessThan(tester.getTopLeft(find.text('Alter Wurf 1')).dy),
      );
    });

    testWidgets('ein einziger Abend bleibt ohne Überschrift', (tester) async {
      await tester.pumpWidget(
        _wrap(InspectorDiceLogSection(entries: [alt1, alt2], jetzt: jetzt)),
      );
      expect(find.text('Fr, 16.10.2026'), findsNothing);
      expect(find.textContaining('Würfe'), findsNWidgets(2)); // je „Würfe: 9“
      expect(find.text('Alter Wurf 1'), findsOneWidget);
    });

    testWidgets('ein Filter verschluckt keine Pause und keine Überschrift', (
      tester,
    ) async {
      final kampf = wurf(
        DateTime.utc(2026, 10, 16, 12, 30),
        'Kampfwurf',
        type: ProbeType.combatAttack,
      );
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: InspectorDiceLogSection(
              entries: [alt1, kampf, neu],
              jetzt: jetzt,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('dice-log-filter-combat')));
      await tester.pumpAndSettle();

      // Nur der Kampfwurf passt; sein Abend behält die Überschrift, der
      // leere heutige Abend entfällt.
      expect(find.text('Kampfwurf'), findsOneWidget);
      expect(find.text('Fr, 16.10.2026'), findsOneWidget);
      expect(find.text('Heute'), findsNothing);
      expect(find.text('1 Wurf'), findsOneWidget);
    });

    testWidgets('ohne Treffer im Filter bleibt der Leerhinweis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(InspectorDiceLogSection(entries: [alt1, neu], jetzt: jetzt)),
      );
      await tester.tap(find.byKey(const ValueKey('dice-log-filter-spell')));
      await tester.pumpAndSettle();
      expect(find.text('Keine Würfe in dieser Kategorie.'), findsOneWidget);
    });
  });

  group('Ziele und TaP* (SPIEL-05)', () {
    DiceLogEntry probe({
      required ProbeType type,
      required bool success,
      List<int> ziele = const [13, 12, 14],
      int? rest,
    }) => DiceLogEntry(
      timestamp: DateTime.utc(2026, 10, 23, 8, 0),
      type: type,
      title: 'Probe',
      subtitle: '',
      success: success,
      diceValues: const [9, 15, 5],
      targetValue: ziele.isEmpty ? 13 : ziele.first,
      zielwerte: ziele,
      restpunkte: rest,
    );

    testWidgets('eine gelungene Talentprobe zeigt alle Ziele und TaP*', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          InspectorDiceLogSection(
            entries: [probe(type: ProbeType.talent, success: true, rest: 4)],
          ),
        ),
      );
      expect(
        find.text('Würfe: 9, 15, 5 | Ziele: 13/12/14 | TaP*: 4'),
        findsOneWidget,
      );
    });

    testWidgets('eine Zauberprobe nennt ZfP*', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InspectorDiceLogSection(
            entries: [probe(type: ProbeType.spell, success: true, rest: 0)],
          ),
        ),
      );
      expect(find.textContaining('ZfP*: 0'), findsOneWidget);
    });

    testWidgets('eine misslungene Probe zeigt keine Punkte', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InspectorDiceLogSection(
            entries: [probe(type: ProbeType.talent, success: false, rest: -2)],
          ),
        ),
      );
      expect(find.textContaining('TaP*'), findsNothing);
      expect(find.textContaining('Ziele: 13/12/14'), findsOneWidget);
    });

    testWidgets('ältere Einträge zeigen weiter nur das erste Ziel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          InspectorDiceLogSection(
            entries: [
              probe(type: ProbeType.talent, success: true, ziele: const []),
            ],
          ),
        ),
      );
      expect(find.textContaining('Ziele'), findsNothing);
      expect(find.textContaining('TaP*'), findsNothing);
    });
  });

  group('Nochmal würfeln (SPIEL-05)', () {
    DiceLogEntry eintrag(
      String titel, {
      ProbeType type = ProbeType.talent,
      bool neutral = false,
      String? buchung,
    }) => DiceLogEntry(
      timestamp: DateTime.utc(2026, 10, 23, 8, 0),
      type: type,
      title: titel,
      subtitle: '',
      success: true,
      diceValues: const [9],
      isNeutral: neutral,
      buchungId: buchung,
    );

    test('nur Proben der Probensuche lassen sich wiederholen', () {
      expect(
        diceLogEntryKannWiederholtWerden(eintrag('Talentprobe: Klettern')),
        isTrue,
      );
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Eigenschaftsprobe: MU', type: ProbeType.attribute),
        ),
        isTrue,
      );
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Zauberprobe: Fulminictus', type: ProbeType.spell),
        ),
        isTrue,
      );
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Schnellprobe: AT', type: ProbeType.combatAttack),
        ),
        isTrue,
      );
      // Gefechtsauftrag, Schaden, Rast, Summenwurf und Buchung nicht.
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Angreifen · Säbel', type: ProbeType.combatAttack),
        ),
        isFalse,
      );
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Schaden erhalten', type: ProbeType.damage, buchung: 'b1'),
        ),
        isFalse,
      );
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Talentprobe: X', neutral: true),
        ),
        isFalse,
      );
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Rast: KO-Probe', type: ProbeType.attribute),
        ),
        isFalse,
      );
      // Art und Titel müssen zusammenpassen.
      expect(
        diceLogEntryKannWiederholtWerden(
          eintrag('Zauberprobe: X', type: ProbeType.talent),
        ),
        isFalse,
      );
    });

    testWidgets('der Knopf erscheint nur an wiederholbaren Einträgen', (
      tester,
    ) async {
      final gewuerfelt = <DiceLogEntry>[];
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: InspectorDiceLogSection(
              entries: [
                eintrag('Talentprobe: Klettern'),
                DiceLogEntry(
                  timestamp: DateTime.utc(2026, 10, 23, 8, 1),
                  type: ProbeType.damage,
                  title: 'Schaden erhalten',
                  subtitle: '',
                  success: true,
                  diceValues: const [],
                  buchungId: 'b1',
                ),
              ],
              onWiederholen: (e) async => gewuerfelt.add(e),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Nochmal würfeln'), findsOneWidget);
      await tester.tap(find.byTooltip('Nochmal würfeln'));
      await tester.pumpAndSettle();
      expect(gewuerfelt.single.title, 'Talentprobe: Klettern');
    });

    testWidgets('ohne Rückruf gibt es keinen Knopf', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InspectorDiceLogSection(entries: [eintrag('Talentprobe: Klettern')]),
        ),
      );
      expect(find.byTooltip('Nochmal würfeln'), findsNothing);
    });
  });

  testWidgets('renders neutral roll entries with result details', (
    tester,
  ) async {
    final entry = DiceLogEntry(
      timestamp: DateTime.utc(2026, 4, 30, 8, 2),
      type: ProbeType.genericRoll,
      title: 'Trefferzone',
      subtitle: 'Brust',
      success: true,
      diceValues: const [15],
      total: 15,
      isNeutral: true,
    );

    await tester.pumpWidget(_wrap(InspectorDiceLogSection(entries: [entry])));

    expect(find.text('WURF'), findsOneWidget);
    expect(find.textContaining('Würfe: 15'), findsOneWidget);
    expect(find.textContaining('Gesamt: 15'), findsOneWidget);
  });

  group('knappe Fassung (hoechstens)', () {
    List<DiceLogEntry> sieben() => [
      for (var i = 0; i < 7; i++)
        _entry(hour: 8, minute: i, success: true, title: 'Wurf $i'),
    ];

    testWidgets('zeigt nur die neuesten und keine Filter', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: InspectorDiceLogSection(entries: sieben(), hoechstens: 5),
          ),
        ),
      );
      for (var i = 2; i < 7; i++) {
        expect(find.text('Wurf $i'), findsOneWidget);
      }
      expect(find.text('Wurf 0'), findsNothing);
      expect(find.text('Wurf 1'), findsNothing);
      expect(find.byKey(const ValueKey('dice-log-filter-all')), findsNothing);
    });

    testWidgets('ohne Grenze bleibt alles wie bisher', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: InspectorDiceLogSection(entries: sieben()),
          ),
        ),
      );
      for (var i = 0; i < 7; i++) {
        expect(find.text('Wurf $i'), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('dice-log-filter-all')), findsOneWidget);
    });
  });
}
