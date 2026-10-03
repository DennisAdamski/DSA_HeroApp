import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kontext_rules.dart';

void main() {
  const w = Gefechtswerte(
    iniBasis: 10,
    at: 15,
    pa: 14,
    ausweichen: 12,
    waffenDk: 'N',
  );
  test('DK sperrt unmögliche AT und berechnet AT/PA unterschiedlich', () {
    for (final dk in ['H', 'N', 'S', 'P']) {
      final s = Gefechtszustand(
        iniWurf: 6,
        dk: dk,
        kontext: const Gefechtskontext(
          gegnerzahl: 1,
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          paradeVerboten: false,
        ),
      );
      final at = pruefeGefechtsaktion(s, w, Gefechtsaktion.angriff);
      final pa = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
      expect(at.zielwert, dk == 'H' || dk == 'S' ? 9 : 15);
      expect(pa.zielwert, dk == 'H' ? 8 : 14);
      expect(at.status == Gefechtsfreigabe.gesperrt, dk == 'P');
    }
  });
  test('Finte einmal und freies Ausweichen mit einfacher DK', () {
    const s = Gefechtszustand(
      iniWurf: 6,
      dk: 'N',
      kontext: Gefechtskontext(
        gegnerzahl: 1,
        platzZumAusweichen: true,
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 3,
        paradeVerboten: false,
      ),
    );
    expect(pruefeGefechtsaktion(s, w, Gefechtsaktion.parade).zielwert, 11);
    expect(
      pruefeGefechtsaktion(s, w, Gefechtsaktion.freiesAusweichen).zielwert,
      7,
    );
  });
  test('Kontaktwechsel verwirft DK und einzelne Angriffsdaten', () {
    const s = Gefechtszustand(
      iniWurf: 6,
      dk: 'N',
      kontext: Gefechtskontext(kontakt: 'Ork', finte: 4),
    );
    final neu = wechsleGefechtskontakt(s, 'Wolf');
    expect(neu.dk, isNull);
    expect(neu.kontext.finte, isNull);
    expect(neu.kontext.kontakt, 'Wolf');
  });
}
