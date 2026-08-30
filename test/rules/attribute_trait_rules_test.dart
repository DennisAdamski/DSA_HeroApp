import 'package:dsa_heldenverwaltung/rules/derived/attribute_trait_rules.dart';
import 'package:flutter_test/flutter_test.dart';

AttributeTraitMatch? parseAdvantage(String fragment) {
  return parseAttributeTraitFragment(
    fragment: fragment,
    allowAdvantages: true,
    allowDisadvantages: false,
  );
}

void main() {
  test('erkennt Herausragende Eigenschaft mit Kurzcode und Wert', () {
    final match = parseAdvantage('Herausragende Eigenschaft KK 2');

    expect(match, isNotNull);
    expect(match!.hasAttribute, isTrue);
    expect(match.raisesStartValue, isTrue);
    expect(match.attributeMods.kk, 2);
    expect(match.attributeMods.mu, 0);
  });

  test('erkennt ausgeschriebene Eigenschaftsnamen inklusive Umlaut', () {
    expect(
      parseAdvantage('Herausragende Eigenschaft Körperkraft 2')!
          .attributeMods
          .kk,
      2,
    );
    expect(
      parseAdvantage('Herausragende Eigenschaft Mut 1')!.attributeMods.mu,
      1,
    );
    expect(
      parseAdvantage('Herausragende Eigenschaft Intuition 3')!
          .attributeMods
          .inn,
      3,
    );
    // IN wird als 'IN' gespeichert, heisst im Modell aber 'inn' — genau der
    // Code, den das Dropdown fuer diese Eigenschaft liefert.
    expect(
      parseAdvantage('Herausragende Eigenschaft IN 3')!.attributeMods.inn,
      3,
    );
  });

  test('toleriert Doppelpunkt, Klammern und Pluszeichen', () {
    expect(
      parseAdvantage('Herausragende Eigenschaft: KK +2')!.attributeMods.kk,
      2,
    );
    expect(
      parseAdvantage('Herausragende Eigenschaft (KK 2)')!.attributeMods.kk,
      2,
    );
    expect(
      parseAdvantage('herausragende eigenschaft kk 2')!.attributeMods.kk,
      2,
    );
  });

  test('nimmt fehlenden Wert als einen Punkt an', () {
    final match = parseAdvantage('Herausragende Eigenschaft KK');

    expect(match!.hasAttribute, isTrue);
    expect(match.attributeMods.kk, 1);
  });

  test('meldet unbekannte Eigenschaft als hasAttribute false', () {
    final match = parseAdvantage('Herausragende Eigenschaft Zauberei 2');

    expect(match, isNotNull);
    expect(match!.hasAttribute, isFalse);
    expect(match.attributeMods.kk, 0);
  });

  test('greift nicht in Nachteilen und nicht in Herkunftstexten', () {
    expect(
      parseAttributeTraitFragment(
        fragment: 'Herausragende Eigenschaft KK 2',
        allowAdvantages: false,
        allowDisadvantages: true,
      ),
      isNull,
    );
    expect(
      parseAttributeTraitFragment(
        fragment: 'Herausragende Eigenschaft KK 2',
        allowAdvantages: false,
        allowDisadvantages: false,
      ),
      isNull,
    );
  });

  test('verwechselt benachbarte Herausragende-Vorteile nicht', () {
    expect(parseAdvantage('Herausragende Balance'), isNull);
    expect(parseAdvantage('Herausragendes Aussehen'), isNull);
    expect(parseAdvantage('Herausragender Sinn Gehör'), isNull);
    expect(parseAdvantage('Herausragender Sechster Sinn'), isNull);
  });

  test('deckelt unplausible Werte', () {
    expect(
      parseAdvantage('Herausragende Eigenschaft KK 99')!.attributeMods.kk,
      8,
    );
  });

  test('ignoriert leere und fremde Fragmente', () {
    expect(parseAdvantage(''), isNull);
    expect(parseAdvantage('KK+2'), isNull);
    expect(parseAdvantage('Hohe Lebenskraft 3'), isNull);
  });
}
