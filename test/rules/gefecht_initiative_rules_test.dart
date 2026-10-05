import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_initiative.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_initiative_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

void main() {
  const w = Gefechtswerte(iniBasis: 10, at: 15, pa: 14, ausweichen: 12, be: 0);
  test(
    'Reserve bezahlt einmal, überlebt Runde und verhindert weitere AT/PA',
    () {
      const s = Gefechtszustand(iniWurf: 6, dk: 'N');
      final reserve = reserviereGefechtsaktion(s, w);
      expect(reserve.angriffeVerbraucht, 1);
      expect(reserve.reserveIni, 16);
      expect(() => reserviereGefechtsaktion(reserve, w), throwsStateError);
      expect(
        pruefeGefechtsaktion(reserve, w, Gefechtsaktion.parade).status,
        Gefechtsfreigabe.gesperrt,
      );
      final runde = naechsteGefechtsrunde(reserve);
      expect(runde.reserveIni, 16);
      final bereit = runde.copyWith(reserveBereit: true);
      final p = pruefeGefechtsaktion(bereit, w, Gefechtsaktion.angriff);
      final nach = verbraucheGefechtsaktion(bereit, w, p, erfolg: true);
      expect(nach.reserveIni, isNull);
      expect(nach.angriffeVerbraucht, 0);
      expect(nach.regulaereAttacke, isTrue);
      expect(verwerfeGefechtsreserve(reserve).angriffeVerbraucht, 1);
    },
  );
  test('Regulärer Zeitpunkt kommt vor Umwandlung gleicher Phase', () {
    final liste = sortiereGefechtszeitpunkte([
      const Gefechtszeitpunkt(
        id: 'a:2',
        teilnehmerId: 'a',
        name: 'A',
        ini: 6,
        ursprungsIni: 14,
        umgewandelt: true,
      ),
      const Gefechtszeitpunkt(
        id: 'b:1',
        teilnehmerId: 'b',
        name: 'B',
        ini: 6,
        ursprungsIni: 6,
      ),
    ]);
    expect(liste.first.id, 'b:1');
  });
  test('INI-8 unter Null hat keinen zweiten Zeitpunkt', () {
    const s = Gefechtszustand(
      iniWurf: 6,
      umwandlung: Gefechtsumwandlung.zweiteAttacke,
    );
    expect(gefechtsHeldenzeitpunkte('h', 'Held', s, 7).length, 1);
    expect(gefechtsHeldenzeitpunkte('h', 'Held', s, 8).last.ini, 0);
  });
  test('Verzögerte Konkurrenz nutzt ursprüngliche INI und Gleichstand bleibt sichtbar', () {
    final liste = sortiereGefechtszeitpunkte([
      const Gefechtszeitpunkt(
        id: 'b',
        teilnehmerId: 'b',
        name: 'B',
        ini: 5,
        ursprungsIni: 12,
        reserve: true,
      ),
      const Gefechtszeitpunkt(
        id: 'a',
        teilnehmerId: 'a',
        name: 'A',
        ini: 5,
        ursprungsIni: 16,
        reserve: true,
      ),
    ]);
    expect(liste.first.id, 'a');
    expect(gefechtsZeitgleich(liste.first, liste.first), isTrue);
  });
}
