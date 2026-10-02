import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';

void main() {
  test('Negative Initiative erlaubt eine reguläre Reaktion, keine zwei Daueraktionen', () {
    const w = Gefechtswerte(iniBasis: -10, at: 14, pa: 12, ausweichen: 10);
    final s = beginneGefecht(6);
    final eine = pruefeManuelleGefechtsaktion(s, w, kosten: 1);
    expect(eine.status, isNot(Gefechtsfreigabe.gesperrt));
    expect(eine.angriffe, 0);
    expect(eine.paraden, 1);
    expect(
      pruefeManuelleGefechtsaktion(s, w, kosten: 2).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('SK-II-Zusatzparade bezahlt weder Ausweichen noch Position', () {
    const w = Gefechtswerte(
      iniBasis: 12,
      at: 14,
      pa: 12,
      ausweichen: 10,
      schildPa: 14,
      schildkampf2: true,
      ausweichen1: true,
    );
    final s = beginneGefecht(6).copyWith(
      dk: 'N',
      angriffeVerbraucht: 1,
      paradenVerbraucht: 1,
      schildparadenVerbraucht: 1,
    );
    for (final a in [
      Gefechtsaktion.gezieltesAusweichen,
      Gefechtsaktion.position,
    ]) {
      expect(pruefeGefechtsaktion(s, w, a).status, Gefechtsfreigabe.gesperrt);
    }
    expect(
      pruefeGefechtsaktion(s, w, Gefechtsaktion.schildparade).status,
      Gefechtsfreigabe.pruefen,
    );
  });
  test(
    'Kampfgespür kann eine noch unbenutzte Parade später in AT umwandeln',
    () {
      const w = Gefechtswerte(
        iniBasis: 18,
        at: 14,
        pa: 12,
        ausweichen: 10,
        kampfgespuer: true,
      );
      final s = beginneGefecht(6)
          .copyWith(angriffeVerbraucht: 1, regulaereAttacke: true);
      expect(
        wandleGefechtUm(
          s,
          Gefechtsumwandlung.zweiteAttacke,
          werte: w,
        ).umwandlung,
        Gefechtsumwandlung.zweiteAttacke,
      );
      expect(
        () => wandleGefechtUm(s, Gefechtsumwandlung.zweiteParade, werte: w),
        throwsStateError,
      );
    },
  );
  test('Längere Handlung bezahlt keine Voraussetzung für Zusatzattacke', () {
    const w = Gefechtswerte(
      iniBasis: 10,
      at: 14,
      pa: 12,
      ausweichen: 10,
      zusatzaktionen: 1,
    );
    final s = beginneGefecht(6);
    final h = pruefeManuelleGefechtsaktion(s, w, kosten: 2);
    final nach = verbraucheGefechtsaktion(s, w, h);
    expect(
      pruefeGefechtsaktion(nach, w, Gefechtsaktion.zusatzaktion).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('Kostenfreie Korrektur fixiert noch keinen INI-Bonus', () {
    const w = Gefechtswerte(iniBasis: 18, at: 14, pa: 12, ausweichen: 10);
    final s = beginneGefecht(6);
    final p = pruefeManuelleGefechtsaktion(s, w, kosten: 0);
    expect(verbraucheGefechtsaktion(s, w, p).fixierterIniBonus, isNull);
  });
  test(
    'Kostenfreie bestätigte Handlung nach regulärem Budget bleibt möglich',
    () {
      const w = Gefechtswerte(iniBasis: 10, at: 14, pa: 12, ausweichen: 10);
      final s = beginneGefecht(6)
          .copyWith(angriffeVerbraucht: 1, paradenVerbraucht: 1);
      expect(
        pruefeManuelleGefechtsaktion(s, w, kosten: 0).status,
        Gefechtsfreigabe.pruefen,
      );
      expect(
        pruefeManuelleGefechtsaktion(s, w, kosten: 1).status,
        Gefechtsfreigabe.gesperrt,
      );
    },
  );
  test('SK II zweite Parade setzt erste Schildparade voraus', () {
    const w = Gefechtswerte(
      iniBasis: 12,
      at: 14,
      pa: 12,
      ausweichen: 10,
      schildPa: 14,
      schildkampf2: true,
    );
    final s = beginneGefecht(6);
    final p = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
    final nach = verbraucheGefechtsaktion(s, w, p);
    expect(
      pruefeGefechtsaktion(nach, w, Gefechtsaktion.schildparade).status,
      Gefechtsfreigabe.gesperrt,
    );
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
