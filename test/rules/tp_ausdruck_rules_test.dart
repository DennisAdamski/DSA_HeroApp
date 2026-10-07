import 'package:dsa_heldenverwaltung/rules/derived/tp_ausdruck_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rechnet den Zuschlag in den festen Anteil', () {
    expect(tpMitZuschlag('2W6+1', 2), '2W6+3');
    expect(tpMitZuschlag('1W6', 2), '1W6+2');
    expect(tpMitZuschlag('1W6-1', 1), '1W6');
    expect(tpMitZuschlag('1W6 + 2', 2), '1W6+4');
    expect(tpMitZuschlag('1W6+1', -3), '1W6-2');
  });

  test('Text hinter dem festen Anteil bleibt stehen', () {
    expect(tpMitZuschlag('1W+4 (A)', 1), '1W+5 (A)');
  });

  test('unlesbare Angaben bekommen den Zuschlag angehaengt', () {
    expect(tpMitZuschlag('Huf', 2), 'Huf +2');
    expect(tpMitZuschlag('', 2), '+2');
  });

  test('ohne Zuschlag bleibt die Angabe unveraendert', () {
    expect(tpMitZuschlag(' 1W6 + 2 ', 0), ' 1W6 + 2 ');
  });
}
