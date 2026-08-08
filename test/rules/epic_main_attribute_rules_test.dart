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

  group('isEpicMainAttribute', () {
    test('true fuer die gewaehlte Haupteigenschaft', () {
      expect(
        isEpicMainAttribute(mainAttributes: muKkMain, code: AttributeCode.mu),
        isTrue,
      );
      expect(
        isEpicMainAttribute(mainAttributes: muKkMain, code: AttributeCode.kk),
        isTrue,
      );
    });

    test('false fuer nicht gewaehlte Eigenschaften', () {
      expect(
        isEpicMainAttribute(mainAttributes: muKkMain, code: AttributeCode.kl),
        isFalse,
      );
      expect(
        isEpicMainAttribute(mainAttributes: noMain, code: AttributeCode.mu),
        isFalse,
      );
    });
  });

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

  group('activeEpicMainAttributeBonuses', () {
    test('leer bei inaktiver Regel', () {
      expect(
        activeEpicMainAttributeBonuses(
          ruleActive: false,
          isEpisch: true,
          mainAttributes: muMain,
        ),
        isEmpty,
      );
    });

    test('leer bei nicht-epischem Helden', () {
      expect(
        activeEpicMainAttributeBonuses(
          ruleActive: true,
          isEpisch: false,
          mainAttributes: muMain,
        ),
        isEmpty,
      );
    });

    test('enthaelt genau die gewaehlten Haupteigenschaften', () {
      final boni = activeEpicMainAttributeBonuses(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: muKkMain,
      );
      expect(
        boni.map((bonus) => bonus.code).toSet(),
        <AttributeCode>{AttributeCode.mu, AttributeCode.kk},
      );
    });

    test('KK liefert genau einen automatischen und drei manuelle Boni', () {
      final boni = activeEpicMainAttributeBonuses(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: kkMain,
      );
      expect(boni.length, 4);
      expect(
        boni
            .where((b) => b.umsetzung == EpicBonusUmsetzung.automatisch)
            .map((b) => b.text),
        <String>['eBE bei KK-Talenten halbiert'],
      );
      expect(
        boni.where((b) => b.umsetzung == EpicBonusUmsetzung.manuell).length,
        3,
      );
    });

    test('IN-Finte ist als Hinweis ausgewiesen', () {
      final boni = activeEpicMainAttributeBonuses(
        ruleActive: true,
        isEpisch: true,
        mainAttributes: innMain,
      );
      final finte = boni.firstWhere((b) => b.text.contains('Finten'));
      expect(finte.umsetzung, EpicBonusUmsetzung.hinweis);
    });
  });

  group('epicMainAttributeBonusSummary', () {
    test('fasst alle Einzelboni einer Eigenschaft zusammen', () {
      final summary = epicMainAttributeBonusSummary(AttributeCode.kk);
      expect(summary, contains('eBE bei KK-Talenten halbiert'));
      expect(summary, contains('Tragkraft KK'));
    });
  });

  group('talentProbeUsesAttribute', () {
    test('erkennt KK in allen Katalog-Schreibweisen', () {
      for (final token in const <String>['KK', 'Koerperkraft', 'Körperkraft']) {
        expect(
          talentProbeUsesAttribute(<String>['Mut', 'Gewandheit', token],
              AttributeCode.kk),
          isTrue,
          reason: token,
        );
      }
    });

    test('lehnt Ketten ohne die Eigenschaft ab', () {
      expect(
        talentProbeUsesAttribute(
          <String>['Klugheit', 'Intuition', 'Charisma'],
          AttributeCode.kk,
        ),
        isFalse,
      );
    });
  });

  group('epicTalentEbeMultiplier', () {
    const kkChain = <String>['Mut', 'Gewandheit', 'Koerperkraft'];
    const klChain = <String>['Klugheit', 'Intuition', 'Charisma'];

    test('halbiert nur bei KK-Haupteigenschaft und KK-Talent', () {
      expect(
        epicTalentEbeMultiplier(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: kkMain,
          talentAttributes: kkChain,
        ),
        0.5,
      );
    });

    test('neutral bei Talent ohne KK-Probe', () {
      expect(
        epicTalentEbeMultiplier(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: kkMain,
          talentAttributes: klChain,
        ),
        1.0,
      );
    });

    test('neutral ohne KK-Haupteigenschaft', () {
      expect(
        epicTalentEbeMultiplier(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: koMain,
          talentAttributes: kkChain,
        ),
        1.0,
      );
    });

    test('neutral bei inaktiver Regel oder nicht-epischem Helden', () {
      expect(
        epicTalentEbeMultiplier(
          ruleActive: false,
          isEpisch: true,
          mainAttributes: kkMain,
          talentAttributes: kkChain,
        ),
        1.0,
      );
      expect(
        epicTalentEbeMultiplier(
          ruleActive: true,
          isEpisch: false,
          mainAttributes: kkMain,
          talentAttributes: kkChain,
        ),
        1.0,
      );
    });
  });

  group('buildEpicFinteDefenseHint', () {
    test('liefert Text bei IN-Haupteigenschaft', () {
      expect(
        buildEpicFinteDefenseHint(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: innMain,
        ),
        contains('Finten gegen dich sind um 2 erschwert'),
      );
    });

    test('leer ohne IN-Haupteigenschaft', () {
      expect(
        buildEpicFinteDefenseHint(
          ruleActive: true,
          isEpisch: true,
          mainAttributes: kkMain,
        ),
        isEmpty,
      );
    });

    test('leer bei inaktiver Regel oder nicht-epischem Helden', () {
      expect(
        buildEpicFinteDefenseHint(
          ruleActive: false,
          isEpisch: true,
          mainAttributes: innMain,
        ),
        isEmpty,
      );
      expect(
        buildEpicFinteDefenseHint(
          ruleActive: true,
          isEpisch: false,
          mainAttributes: innMain,
        ),
        isEmpty,
      );
    });
  });
}
