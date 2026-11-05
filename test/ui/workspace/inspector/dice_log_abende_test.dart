import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/dice_log_abende.dart';

DiceLogEntry _wurf(DateTime zeit, [String titel = 'Wurf']) => DiceLogEntry(
  timestamp: zeit.toUtc(),
  type: ProbeType.attribute,
  title: titel,
  subtitle: '',
  success: true,
  diceValues: const [9],
);

void main() {
  group('gruppiereNachSpielabend', () {
    test('ein leeres Protokoll hat keine Abende', () {
      expect(gruppiereNachSpielabend(const <DiceLogEntry>[]), isEmpty);
    });

    test('Würfe ohne lange Pause bilden einen Abend', () {
      final abende = gruppiereNachSpielabend([
        _wurf(DateTime.utc(2026, 10, 22, 19, 0)),
        _wurf(DateTime.utc(2026, 10, 22, 20, 30)),
        _wurf(DateTime.utc(2026, 10, 22, 23, 59)),
      ]);
      expect(abende, hasLength(1));
      expect(abende.single.eintraege, hasLength(3));
    });

    test('ein Abend über Mitternacht bleibt zusammen', () {
      final abende = gruppiereNachSpielabend([
        _wurf(DateTime.utc(2026, 10, 22, 22, 0)),
        _wurf(DateTime.utc(2026, 10, 23, 1, 30)),
      ]);
      expect(abende, hasLength(1));
    });

    test('mehr als sechs Stunden Pause beginnen einen neuen Abend', () {
      final abende = gruppiereNachSpielabend([
        _wurf(DateTime.utc(2026, 10, 15, 19, 0), 'alt-1'),
        _wurf(DateTime.utc(2026, 10, 15, 21, 0), 'alt-2'),
        _wurf(DateTime.utc(2026, 10, 22, 19, 0), 'neu-1'),
      ]);
      expect(abende, hasLength(2));
      expect(abende.first.eintraege.map((e) => e.title), ['alt-1', 'alt-2']);
      expect(abende.last.eintraege.map((e) => e.title), ['neu-1']);
    });

    test('genau sechs Stunden trennen noch nicht', () {
      final abende = gruppiereNachSpielabend([
        _wurf(DateTime.utc(2026, 10, 22, 12, 0)),
        _wurf(DateTime.utc(2026, 10, 22, 18, 0)),
      ]);
      expect(abende, hasLength(1));
    });

    test('die Pause lässt sich wählen', () {
      final abende = gruppiereNachSpielabend([
        _wurf(DateTime.utc(2026, 10, 22, 12, 0)),
        _wurf(DateTime.utc(2026, 10, 22, 14, 0)),
      ], pause: const Duration(hours: 1));
      expect(abende, hasLength(2));
    });

    test('ein unsortiertes Protokoll wird nach Zeit geordnet', () {
      final abende = gruppiereNachSpielabend([
        _wurf(DateTime.utc(2026, 10, 22, 19, 5), 'zweiter'),
        _wurf(DateTime.utc(2026, 10, 15, 19, 0), 'alter'),
        _wurf(DateTime.utc(2026, 10, 22, 19, 0), 'erster'),
      ]);
      expect(abende, hasLength(2));
      expect(abende.first.eintraege.single.title, 'alter');
      expect(abende.last.eintraege.map((e) => e.title), ['erster', 'zweiter']);
    });

    test('gleiche Zeitstempel behalten die Eingabereihenfolge', () {
      final zeit = DateTime.utc(2026, 10, 22, 19, 0);
      final abende = gruppiereNachSpielabend([
        _wurf(zeit, 'a'),
        _wurf(zeit, 'b'),
        _wurf(zeit, 'c'),
      ]);
      expect(abende.single.eintraege.map((e) => e.title), ['a', 'b', 'c']);
    });

    test('die Eingabe bleibt unverändert', () {
      final eingabe = [
        _wurf(DateTime.utc(2026, 10, 22, 19, 5), 'b'),
        _wurf(DateTime.utc(2026, 10, 22, 19, 0), 'a'),
      ];
      gruppiereNachSpielabend(eingabe);
      expect(eingabe.map((e) => e.title), ['b', 'a']);
    });

    test('der Beginn ist der erste Wurf in Ortszeit', () {
      final erster = DateTime.utc(2026, 10, 22, 19, 0);
      final abend = gruppiereNachSpielabend([
        _wurf(erster),
        _wurf(DateTime.utc(2026, 10, 22, 20, 0)),
      ]).single;
      expect(abend.beginn, erster.toLocal());
    });
  });

  group('diceLogAbendUeberschrift', () {
    final jetzt = DateTime(2026, 10, 23, 8, 30);

    test('heute und gestern', () {
      expect(
        diceLogAbendUeberschrift(DateTime(2026, 10, 23, 0, 5), jetzt),
        'Heute',
      );
      expect(
        diceLogAbendUeberschrift(DateTime(2026, 10, 22, 21, 0), jetzt),
        'Gestern',
      );
    });

    test('früher mit Wochentag und Datum', () {
      // 16.10.2026 war ein Freitag.
      expect(
        diceLogAbendUeberschrift(DateTime(2026, 10, 16, 19, 0), jetzt),
        'Fr, 16.10.2026',
      );
      expect(
        diceLogAbendUeberschrift(DateTime(2026, 1, 3, 19, 0), jetzt),
        'Sa, 03.01.2026',
      );
    });

    test('über die Monatsgrenze hinweg ist gestern gestern', () {
      expect(
        diceLogAbendUeberschrift(
          DateTime(2026, 9, 30, 20, 0),
          DateTime(2026, 10, 1, 10, 0),
        ),
        'Gestern',
      );
    });

    test('Zeitumstellung verschiebt den Tagesabstand nicht', () {
      // Die Uhren werden in Mitteleuropa am 25.10.2026 zurückgestellt: der Tag
      // hat 25 Stunden, gestern bleibt gestern.
      expect(
        diceLogAbendUeberschrift(
          DateTime(2026, 10, 24, 20, 0),
          DateTime(2026, 10, 25, 23, 0),
        ),
        'Gestern',
      );
    });
  });
}
