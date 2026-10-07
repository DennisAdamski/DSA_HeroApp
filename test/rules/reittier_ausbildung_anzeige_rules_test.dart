import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbildung_anzeige_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vorzeichen mit typografischem Minus', () {
    expect(mitVorzeichen(3), '+3');
    expect(mitVorzeichen(-1), '−1');
    expect(mitVorzeichen(0), '±0');
  });

  test('Modifikationen und Proben als Kurztext', () {
    expect(
      reittierModifikationenText(
        const ReittierModifikationen(
          lo: 4,
          at: 1,
          tpTritt: 1,
          gsTrab: 2,
          gsGalopp: 1,
          tkFaktor: 1,
        ),
      ),
      'LO +4 · AT +1 · TP (Tritt) +1 · GS Trab +2 / Galopp +1 · TK +1×KK',
    );
    expect(reittierModifikationenText(ReittierModifikationen.keine), '');
    expect(
      reittierProbeText(kReittierStufenschritte.last.proben.last),
      '2× Reiten +5 (Zugtiere: Fahrzeug Lenken)',
    );
  });

  test('faellige Unarten: laendlich jede, fundiert je drei (ZBA S. 34)', () {
    expect(faelligeUnarten(ReittierAusbildungsart.laendlich, 2), 2);
    expect(faelligeUnarten(ReittierAusbildungsart.fundiert, 2), 0);
    expect(faelligeUnarten(ReittierAusbildungsart.fundiert, 7), 2);
  });

  test('Profilzeile fuer das Gefecht', () {
    const profil = ReittierProfil(
      stufe: 'erprobt',
      art: 'ländlich',
      variante: '',
      kampfpferd: false,
      reitenNormal: -1,
      reitenImKampf: 3,
      reiterKampfErschwernis: 3,
    );

    expect(
      reittierProfilText(profil),
      'Ausbildung: erprobt (ländlich) · Reiten −1 / im Kampf +3 · '
      'Reiter-AT/PA +3',
    );
  });
}
