import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

void main() {
  test('SK II zweite Parade setzt erste Schildparade voraus', () {
    const w = Gefechtswerte(iniBasis: 12, at: 14, pa: 12, ausweichen: 10,
      schildPa: 14, schildkampf2: true);
    final s = beginneGefecht(6);
    final p = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
    final nach = verbraucheGefechtsaktion(s, w, p);
    expect(pruefeGefechtsaktion(nach, w, Gefechtsaktion.schildparade).status,
      Gefechtsfreigabe.gesperrt);
  });
  const kontext = Gefechtswerte(iniBasis: 18, at: 15, pa: 12, ausweichen: 10);
  test('Umwandlung bindet Ansage und erschwert die zweite Attacke', () {
    final start = beginneGefecht(6);
    final s = wandleGefechtUm(start, Gefechtsumwandlung.zweiteAttacke);
    final erste = pruefeGefechtsaktion(s, kontext, Gefechtsaktion.angriff);
    final nach = verbraucheGefechtsaktion(s, kontext, erste);
    final zweite = pruefeGefechtsaktion(nach, kontext, Gefechtsaktion.angriff);
    expect(zweite.zielwert, 11);
    expect(
      () => wandleGefechtUm(nach, Gefechtsumwandlung.zweiteParade),
      throwsStateError,
    );
    expect(
      pruefeGefechtsaktion(nach, kontext, Gefechtsaktion.parade).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('INI-Bonus wird beim ersten Verbrauch fixiert', () {
    final s = beginneGefecht(6);
    final f = pruefeGefechtsaktion(s, kontext, Gefechtsaktion.angriff);
    final nach = verbraucheGefechtsaktion(s, kontext, f);
    expect(nach.fixierterIniBonus, 1);
    expect(gefechtsIniBonus(nach.copyWith(iniVerlust: 10), kontext), 1);
  });
  test('Unbekannte DK prüfen; fehlende Aktion ist nicht bestätigbar', () {
    final s = beginneGefecht(6);
    expect(
      pruefeGefechtsaktion(s, kontext, Gefechtsaktion.angriff).status,
      Gefechtsfreigabe.pruefen,
    );
    final nach = s.copyWith(angriffeVerbraucht: 1);
    expect(
      pruefeGefechtsaktion(nach, kontext, Gefechtsaktion.angriff).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('Ausweichen ist liegend und bei vier Gegnern gesperrt', () {
    final s = beginneGefecht(6);
    for (final zustand in [
      s.copyWith(gegner: 4),
      s.copyWith(haltung: Gefechtshaltung.liegend),
    ]) {
      expect(
        pruefeGefechtsaktion(
          zustand,
          kontext,
          Gefechtsaktion.freiesAusweichen,
        ).status,
        Gefechtsfreigabe.gesperrt,
      );
    }
    final f = pruefeGefechtsaktion(s, kontext, Gefechtsaktion.freiesAusweichen);
    final nach = verbraucheGefechtsaktion(s, kontext, f, erfolg: true);
    expect(nach.iniVerlust, 4);
    expect(nach.desorientiert, true);
  });
  test('Rundenwechsel erhält laufende Handlung, setzt Marken zurück', () {
    final s = beginneGefecht(6).copyWith(
      angriffeVerbraucht: 1,
      handlung: const Gefechtshandlung(titel: 'Waffe ziehen', verbleibend: 2),
    );
    final nach = naechsteGefechtsrunde(s);
    expect(nach.runde, 2);
    expect(nach.angriffeVerbraucht, 0);
    expect(nach.handlung?.verbleibend, 2);
  });
}
