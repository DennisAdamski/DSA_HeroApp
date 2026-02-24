import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

void main() {
  const attributes = Attributes(
    mu: 11,
    kl: 12,
    inn: 13,
    ch: 14,
    ff: 15,
    ge: 16,
    ko: 17,
    kk: 18,
  );

  test('parseAttributeCode resolves abbreviations and names', () {
    expect(parseAttributeCode('MU'), AttributeCode.mu);
    expect(parseAttributeCode('mut'), AttributeCode.mu);
    expect(parseAttributeCode('KLUGHEIT'), AttributeCode.kl);
    expect(parseAttributeCode('Intuition'), AttributeCode.inn);
    expect(parseAttributeCode('Körperkraft'), AttributeCode.kk);
    expect(parseAttributeCode('unknown'), isNull);
  });

  test('normalizeAttributeToken transliterates umlauts and strips symbols', () {
    expect(normalizeAttributeToken('Körper-kraft!'), 'koerperkraft');
    expect(normalizeAttributeToken('  GE '), 'ge');
  });

  test('readAttributeValue maps canonical codes to values', () {
    expect(readAttributeValue(attributes, AttributeCode.mu), 11);
    expect(readAttributeValue(attributes, AttributeCode.kl), 12);
    expect(readAttributeValue(attributes, AttributeCode.inn), 13);
    expect(readAttributeValue(attributes, AttributeCode.ch), 14);
    expect(readAttributeValue(attributes, AttributeCode.ff), 15);
    expect(readAttributeValue(attributes, AttributeCode.ge), 16);
    expect(readAttributeValue(attributes, AttributeCode.ko), 17);
    expect(readAttributeValue(attributes, AttributeCode.kk), 18);
  });
}
