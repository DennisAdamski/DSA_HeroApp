import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';

void main() {
  const noMain = Attributes.zero();
  final muMain = noMain.copyWith(mu: 1);
  final innMain = noMain.copyWith(inn: 1);
  final kkMain = noMain.copyWith(kk: 1);
  final koMain = noMain.copyWith(ko: 1);
  final ffMain = noMain.copyWith(ff: 1);
  final muKkMain = noMain.copyWith(mu: 1, kk: 1);

  group('isEpicMainAttributeBonusActive', () {
    test('Gate off when rule inactive', () {
      expect(
        isEpicMainAttributeBonusActive(
          ruleActive: false,
          isEpisch: true,
          mainAttributes: muMain,
          code: AttributeCode.mu,
        ),
        isFalse,
      );
    });

    test('Gate off when not epic', () {
      expect(
        isEpicMainAttributeBonusActive(
          ruleActive: true,
          isEpisch: false,
          mainAttributes: muMain,
          code: AttributeCode.mu,
        ),
        isFalse,
      );
    });

    test('Gate off when attribute not chosen', () {
      expect(
        isEpicMainAttributeBonusActive(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: noMain,
          code: AttributeCode.mu,
        ),
        isFalse,
      );
    });

    test('Gate on when all conditions met', () {
      expect(
        isEpicMainAttributeBonusActive(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: muMain,
          code: AttributeCode.mu,
        ),
        isTrue,
      );
    });
  });

  test('MU-Haupteigenschaft: MR +7 gegen Angst', () {
    expect(
      epicMrBonusVsFear(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: muMain,
      ),
      7,
    );
    expect(
      epicMrBonusVsFear(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: noMain,
      ),
      0,
    );
    expect(
      epicMrBonusVsFear(
        ruleActive: false,
        isEpisch: true,
        mainAttributes: muMain,
      ),
      0,
    );
  });

  test('IN-Haupteigenschaft: Finten +2 erschwert', () {
    expect(
      epicFinteErschwernis(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: innMain,
      ),
      2,
    );
    expect(
      epicFinteErschwernis(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: muMain,
      ),
      0,
    );
  });

  test('KK-Haupteigenschaft: Tragkraft x1.5, eBE x0.5', () {
    expect(
      epicTragkraftMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: kkMain,
      ),
      1.5,
    );
    expect(
      epicKkBeMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: kkMain,
      ),
      0.5,
    );
    expect(
      epicTragkraftMultiplier(
        ruleActive: false,
        isEpisch: true,
        mainAttributes: kkMain,
      ),
      1.0,
    );
    expect(
      epicKkBeMultiplier(
        ruleActive: true,
        isEpisch: false,
        mainAttributes: kkMain,
      ),
      1.0,
    );
  });

  test('KO-Haupteigenschaft: Gifte x0.5, Krankheiten x0.7', () {
    expect(
      epicGiftDamageMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: koMain,
      ),
      0.5,
    );
    expect(
      epicKrankheitTimeMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: koMain,
      ),
      0.7,
    );
    expect(
      epicGiftDamageMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: noMain,
      ),
      1.0,
    );
  });

  test('FF-Haupteigenschaft: Handwerksprodukte x1.1', () {
    expect(
      epicHandwerkWertMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: ffMain,
      ),
      1.1,
    );
    expect(
      epicHandwerkWertMultiplier(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: noMain,
      ),
      1.0,
    );
  });

  group('activeEpicMainAttributeHints', () {
    test('leer bei inaktiver Regel', () {
      final hints = activeEpicMainAttributeHints(
        ruleActive: false,
        isEpisch: true,
        mainAttributes: muMain,
      );
      expect(hints, isEmpty);
    });

    test('leer bei nicht-epischem Helden', () {
      final hints = activeEpicMainAttributeHints(
        ruleActive: true,
        isEpisch: false,
        mainAttributes: muMain,
      );
      expect(hints, isEmpty);
    });

    test('enthaelt genau die gewaehlten Haupteigenschaften', () {
      final hints = activeEpicMainAttributeHints(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: muKkMain,
      );
      expect(hints.length, 2);
      expect(hints.any((h) => h.startsWith('MU:')), isTrue);
      expect(hints.any((h) => h.startsWith('KK:')), isTrue);
    });
  });
}
