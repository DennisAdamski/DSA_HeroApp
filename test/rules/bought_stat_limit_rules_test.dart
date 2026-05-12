import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/bought_stat_limit_rules.dart';

void main() {
  group('computeBoughtStatMaximum', () {
    const attributes = Attributes(
      mu: 13,
      kl: 10,
      inn: 10,
      ch: 10,
      ff: 10,
      ge: 10,
      ko: 15,
      kk: 10,
    );

    test('begrenzt LeP auf KO halbiert, AU auf KO und MR auf MU halbiert', () {
      expect(
        computeBoughtStatMaximum(
          statKey: 'lep',
          permanentAttributes: attributes,
        ),
        7,
      );
      expect(
        computeBoughtStatMaximum(
          statKey: 'au',
          permanentAttributes: attributes,
        ),
        15,
      );
      expect(
        computeBoughtStatMaximum(
          statKey: 'mr',
          permanentAttributes: attributes,
        ),
        6,
      );
    });

    test('laesst AE und KE ohne harte Grenze', () {
      expect(
        computeBoughtStatMaximum(
          statKey: 'asp',
          permanentAttributes: attributes,
        ),
        isNull,
      );
      expect(
        computeBoughtStatMaximum(
          statKey: 'kap',
          permanentAttributes: attributes,
        ),
        isNull,
      );
    });
  });

  group('resolveBoughtStatDialogMaximum', () {
    test('nutzt die kleinere Grenze aus AP-Reichweite und Regelmaximum', () {
      expect(
        resolveBoughtStatDialogMaximum(apReachableMaximum: 12, ruleMaximum: 7),
        7,
      );
      expect(
        resolveBoughtStatDialogMaximum(apReachableMaximum: 5, ruleMaximum: 7),
        5,
      );
    });
  });
}
