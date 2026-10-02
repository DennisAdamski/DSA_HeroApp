import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

void main() {
  test('Defensiver Kampfstil erleichtert zweite PA, nicht zweite AT', () {
    const w = Gefechtswerte(
      iniBasis: 20,
      at: 18,
      pa: 16,
      ausweichen: 10,
      defensiverKampfstil: true,
    );
    final s = beginneGefecht(6).copyWith(
      umwandlung: Gefechtsumwandlung.zweiteParade,
      defensiverStil: true,
      paradenVerbraucht: 1,
    );
    expect(pruefeGefechtsaktion(s, w, Gefechtsaktion.parade).erschwernis, 0);
    final a = s.copyWith(
      umwandlung: Gefechtsumwandlung.zweiteAttacke,
      paradenVerbraucht: 0,
      angriffeVerbraucht: 1,
    );
    expect(pruefeGefechtsaktion(a, w, Gefechtsaktion.angriff).erschwernis, 4);
  });
  test('Bekannte Umwandlungssperre und zweite AT unter null sind bindend', () {
    const w = Gefechtswerte(
      iniBasis: 0,
      at: 12,
      pa: 12,
      ausweichen: 10,
      umwandlungVerboten: true,
    );
    expect(
      gefechtUmwandlungMoeglich(
        beginneGefecht(6),
        Gefechtsumwandlung.zweiteParade,
        werte: w,
      ),
      false,
    );
  });
}
