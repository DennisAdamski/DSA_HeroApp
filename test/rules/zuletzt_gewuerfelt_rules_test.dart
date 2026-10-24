import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zuletzt_gewuerfelt_rules.dart';

DiceLogEntry _eintrag(
  String titel, {
  ProbeType typ = ProbeType.talent,
  int minute = 0,
  bool neutral = false,
  String? buchungId,
}) => DiceLogEntry(
  timestamp: DateTime.utc(2026, 10, 24, 20, minute),
  type: typ,
  title: titel,
  subtitle: '',
  success: true,
  diceValues: const [5],
  isNeutral: neutral,
  buchungId: buchungId,
);

void main() {
  group('probeEintragIstWiederholbar', () {
    test('erkennt die Proben der Probensuche', () {
      expect(
        probeEintragIstWiederholbar(_eintrag('Talentprobe: Klettern')),
        isTrue,
      );
      expect(
        probeEintragIstWiederholbar(
          _eintrag('Eigenschaftsprobe: MU', typ: ProbeType.attribute),
        ),
        isTrue,
      );
      expect(
        probeEintragIstWiederholbar(
          _eintrag('Schnellprobe: AT', typ: ProbeType.combatAttack),
        ),
        isTrue,
      );
    });

    test('lehnt Schaden, Summenwürfe, Buchungen und fremde Titel ab', () {
      expect(
        probeEintragIstWiederholbar(_eintrag('Schaden', typ: ProbeType.damage)),
        isFalse,
      );
      expect(
        probeEintragIstWiederholbar(_eintrag('Talentprobe: X', neutral: true)),
        isFalse,
      );
      expect(
        probeEintragIstWiederholbar(
          _eintrag('Talentprobe: X', buchungId: 'b1'),
        ),
        isFalse,
      );
      expect(probeEintragIstWiederholbar(_eintrag('Klettern')), isFalse);
    });
  });

  test('probenKurzname entfernt das Titelpräfix', () {
    expect(probenKurzname(_eintrag('Talentprobe: Klettern')), 'Klettern');
    expect(
      probenKurzname(_eintrag('Schnellprobe: PA', typ: ProbeType.combatParry)),
      'PA',
    );
    expect(probenKurzname(_eintrag('Unbekannt')), 'Unbekannt');
  });

  group('zuletztGewuerfelteProben', () {
    test('liefert die neueste Probe zuerst und jede Probe nur einmal', () {
      final ergebnis = zuletztGewuerfelteProben([
        _eintrag('Talentprobe: Klettern', minute: 1),
        _eintrag('Talentprobe: Schleichen', minute: 2),
        _eintrag('Talentprobe: Klettern', minute: 3),
      ]);
      expect(ergebnis.map(probenKurzname), ['Klettern', 'Schleichen']);
      expect(ergebnis.first.timestamp.minute, 3);
    });

    test('überspringt Nicht-Wiederholbares, ohne die Zahl zu kürzen', () {
      final ergebnis = zuletztGewuerfelteProben([
        _eintrag('Talentprobe: Klettern', minute: 1),
        _eintrag('Schaden', typ: ProbeType.damage, minute: 2),
        _eintrag('Wurf', typ: ProbeType.genericRoll, minute: 3, neutral: true),
      ]);
      expect(ergebnis.map(probenKurzname), ['Klettern']);
    });

    test('begrenzt auf die gewünschte Zahl', () {
      final protokoll = [
        for (var i = 0; i < 10; i++) _eintrag('Talentprobe: T$i', minute: i),
      ];
      expect(
        zuletztGewuerfelteProben(protokoll),
        hasLength(kZuletztGewuerfeltMax),
      );
      expect(
        zuletztGewuerfelteProben(protokoll, hoechstens: 2).map(probenKurzname),
        ['T9', 'T8'],
      );
    });

    test('ordnet nach Zeitstempel, nicht nach Listenposition', () {
      final ergebnis = zuletztGewuerfelteProben([
        _eintrag('Talentprobe: Neu', minute: 9),
        _eintrag('Talentprobe: Alt', minute: 1),
      ]);
      expect(ergebnis.map(probenKurzname), ['Neu', 'Alt']);
    });

    test('lässt die Eingabe unverändert und liefert unveränderbar', () {
      final protokoll = [
        _eintrag('Talentprobe: B', minute: 2),
        _eintrag('Talentprobe: A', minute: 1),
      ];
      final ergebnis = zuletztGewuerfelteProben(protokoll);
      expect(protokoll.map(probenKurzname), ['B', 'A']);
      expect(() => ergebnis.add(protokoll.first), throwsUnsupportedError);
    });

    test('leeres Protokoll ergibt eine leere Liste', () {
      expect(zuletztGewuerfelteProben(const []), isEmpty);
    });
  });
}
