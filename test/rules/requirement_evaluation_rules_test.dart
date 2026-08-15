import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';

void main() {
  HeroRequirementContext context({
    Map<String, int> eigenschaften = const <String, int>{},
    List<String> sonderfertigkeiten = const <String>[],
    Map<String, int> zauberwerte = const <String, int>{},
    Map<String, int> talentwerte = const <String, int>{},
    Map<String, int> ritualkenntnisse = const <String, int>{},
    List<TraditionDef> traditionen = const <TraditionDef>[],
    List<String> merkmalskenntnisse = const <String>[],
    List<String> vorteile = const <String>[],
    List<String> nachteile = const <String>[],
    String rasse = '',
    String leiteigenschaftOverride = '',
  }) {
    return HeroRequirementContext(
      eigenschaften: eigenschaften,
      sonderfertigkeiten: sonderfertigkeiten,
      zauberwerte: zauberwerte,
      talentwerte: talentwerte,
      ritualkenntnisse: ritualkenntnisse,
      traditionen: traditionen,
      merkmalskenntnisse: merkmalskenntnisse,
      vorteile: vorteile,
      nachteile: nachteile,
      rasse: rasse,
      leiteigenschaftOverride: leiteigenschaftOverride,
    );
  }

  group('Eigenschaften', () {
    test('erfuellt, wenn der Wert erreicht ist', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'MU',
          min: 15,
        ),
        context(eigenschaften: const <String, int>{'MU': 15}),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
      expect(ergebnis.sollText, 'MU 15');
    });

    test('nicht erfuellt, wenn der Wert darunter liegt', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.eigenschaft,
          code: 'IN',
          min: 13,
        ),
        context(eigenschaften: const <String, int>{'IN': 12}),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
      expect(ergebnis.istText, contains('12'));
    });
  });

  group('Leiteigenschaft', () {
    test('nutzt die Leiteigenschaft der Tradition', () {
      final elf = traditionByName('Elf')!;
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.leiteigenschaft,
          min: 18,
        ),
        context(
          eigenschaften: const <String, int>{'KL': 20, 'IN': 18},
          traditionen: <TraditionDef>[elf],
        ),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
      expect(ergebnis.istText, contains('IN'));
      expect(ergebnis.istText, contains('Elf'));
    });

    test('ignoriert Eigenschaften, die nicht Leiteigenschaft sind', () {
      final gildenmagier = traditionByName('Gildenmagier')!;
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.leiteigenschaft,
          min: 20,
        ),
        context(
          eigenschaften: const <String, int>{'KL': 15, 'IN': 21},
          traditionen: <TraditionDef>[gildenmagier],
        ),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });

    test('ohne Tradition bleibt es ein Hinweis statt ein Fehler', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.leiteigenschaft,
          min: 20,
        ),
        context(eigenschaften: const <String, int>{'KL': 21}),
      );

      expect(ergebnis.status, RequirementStatus.hinweis);
    });
  });

  group('Sonderfertigkeiten', () {
    test('erkennt eine erworbene Sonderfertigkeit', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Zauberkontrolle',
        ),
        context(sonderfertigkeiten: const <String>['Zauberkontrolle (ZH)']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('prueft die geforderte Kettenstufe', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 2,
        ),
        context(sonderfertigkeiten: const <String>['Eiserner Wille I']),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
      expect(ergebnis.sollText, contains('II'));
    });

    test('eine hoehere Stufe erfuellt die Forderung nach einer niedrigeren', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 1,
        ),
        context(sonderfertigkeiten: const <String>['Eiserner Wille II']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('der alte Sammelname zaehlt als Stufe I', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 1,
        ),
        context(sonderfertigkeiten: const <String>['Eiserner Wille I / II']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('ein Eintrag ohne Stufenangabe erfuellt die Forderung nach Stufe I', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 1,
        ),
        context(sonderfertigkeiten: const <String>['Eiserner Wille']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('ein Eintrag ohne Stufenangabe erfuellt Stufe II nicht', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Eiserner Wille',
          stufe: 2,
        ),
        context(sonderfertigkeiten: const <String>['Eiserner Wille']),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });

    test('Katalog-Suffixe stoeren die Stufenerkennung nicht', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.sonderfertigkeit,
          name: 'Regeneration',
          stufe: 2,
        ),
        context(sonderfertigkeiten: const <String>['Regeneration II (ZH)']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });
  });

  group('Werte aus Zaubern, Talenten und Ritualkenntnissen', () {
    test('prueft den ZfW eines Zaubers', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.zauber,
          name: 'ARCANOVI',
          min: 14,
        ),
        context(zauberwerte: const <String, int>{'ARCANOVI': 14}),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('prueft den TaW eines Talents', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.talent,
          name: 'Magiekunde',
          min: 11,
        ),
        context(talentwerte: const <String, int>{'Magiekunde': 10}),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });

    test('prueft den RkW einer Ritualkenntnis', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.ritualkenntnis,
          name: 'Geode',
          min: 3,
        ),
        context(ritualkenntnisse: const <String, int>{'Ritualkenntnis Geode': 5}),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });
  });

  group('Tradition', () {
    test('erfuellt, wenn der Held eine der Traditionen fuehrt', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.tradition,
          namen: <String>['Gildenmagier', 'Hexe'],
        ),
        context(traditionen: <TraditionDef>[traditionByName('Hexe')!]),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('nicht erfuellt bei fremder Tradition', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.tradition,
          namen: <String>['Derwisch'],
        ),
        context(traditionen: <TraditionDef>[traditionByName('Hexe')!]),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });

    test('eine Ritualkenntnis-Tradition ohne Repraesentation zaehlt', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.tradition,
          namen: <String>['Derwisch'],
        ),
        context(traditionen: <TraditionDef>[traditionByName('Derwisch')!]),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });
  });

  group('Vor- und Nachteile, Rasse, Merkmale', () {
    test('erkennt einen vorhandenen Vorteil', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.vorteil,
          name: 'Zweistimmiger Gesang',
        ),
        context(vorteile: const <String>['Zweistimmiger Gesang']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('ein verbotener Nachteil blockiert', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.nachteilVerboten,
          name: 'Jähzorn',
        ),
        context(nachteile: const <String>['Jähzorn 7']),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });

    test('ohne den verbotenen Nachteil ist die Bedingung erfuellt', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.nachteilVerboten,
          name: 'Jähzorn',
        ),
        context(nachteile: const <String>['Unstet']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('prueft die Rasse', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.rasse,
          namen: <String>['Achaz'],
        ),
        context(rasse: 'Achaz (Waldmenschen)'),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('eine Merkmalskenntnis ohne konkretes Merkmal genuegt irgendeine', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.merkmalskenntnis,
        ),
        context(merkmalskenntnisse: const <String>['Antimagie']),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('ein konkretes Merkmal muss passen', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.merkmalskenntnis,
          name: 'Dämonisch (Thargunitoth)',
        ),
        context(merkmalskenntnisse: const <String>['Antimagie']),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });
  });

  group('Spruchzauberer', () {
    test('erfuellt mit mindestens einer Repraesentation', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(art: RequirementArt.spruchzauberer),
        context(traditionen: <TraditionDef>[traditionByName('Gildenmagier')!]),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
    });

    test('eine Tradition ohne Repraesentation genuegt nicht', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(art: RequirementArt.spruchzauberer),
        context(traditionen: <TraditionDef>[traditionByName('Derwisch')!]),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });
  });

  group('Oder-Gruppen', () {
    test('erfuellt, sobald eine Teilbedingung erfuellt ist', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.oderGruppe,
          bedingungen: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'KL',
              min: 20,
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'IN',
              min: 20,
            ),
          ],
        ),
        context(eigenschaften: const <String, int>{'KL': 14, 'IN': 20}),
      );

      expect(ergebnis.status, RequirementStatus.erfuellt);
      expect(ergebnis.teilergebnisse, hasLength(2));
    });

    test('eine Und-Gruppe als Oder-Zweig braucht alle Teilbedingungen', () {
      const zweigKlIn = SpecialAbilityRequirement(
        art: RequirementArt.undGruppe,
        bedingungen: <SpecialAbilityRequirement>[
          SpecialAbilityRequirement(
            art: RequirementArt.eigenschaft,
            code: 'KL',
            min: 24,
          ),
          SpecialAbilityRequirement(
            art: RequirementArt.eigenschaft,
            code: 'IN',
            min: 23,
          ),
        ],
      );
      const zweigInKl = SpecialAbilityRequirement(
        art: RequirementArt.undGruppe,
        bedingungen: <SpecialAbilityRequirement>[
          SpecialAbilityRequirement(
            art: RequirementArt.eigenschaft,
            code: 'IN',
            min: 26,
          ),
          SpecialAbilityRequirement(
            art: RequirementArt.eigenschaft,
            code: 'KL',
            min: 20,
          ),
        ],
      );
      const freizauberei = SpecialAbilityRequirement(
        art: RequirementArt.oderGruppe,
        bedingungen: <SpecialAbilityRequirement>[zweigKlIn, zweigInKl],
      );

      expect(
        evaluateRequirement(
          freizauberei,
          context(eigenschaften: const <String, int>{'KL': 20, 'IN': 26}),
        ).status,
        RequirementStatus.erfuellt,
      );
      expect(
        evaluateRequirement(
          freizauberei,
          context(eigenschaften: const <String, int>{'KL': 24, 'IN': 20}),
        ).status,
        RequirementStatus.nichtErfuellt,
      );
    });

    test('nicht erfuellt, wenn keine Teilbedingung greift', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.oderGruppe,
          bedingungen: <SpecialAbilityRequirement>[
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'KL',
              min: 20,
            ),
            SpecialAbilityRequirement(
              art: RequirementArt.eigenschaft,
              code: 'IN',
              min: 20,
            ),
          ],
        ),
        context(eigenschaften: const <String, int>{'KL': 14, 'IN': 15}),
      );

      expect(ergebnis.status, RequirementStatus.nichtErfuellt);
    });
  });

  group('Hinweise und unbekannte Arten', () {
    test('ein Hinweis gilt nie als unerfuellt', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.hinweis,
          text: 'Zugang zu den genannten Buechern',
        ),
        context(),
      );

      expect(ergebnis.status, RequirementStatus.hinweis);
    });

    test('eine unbekannte Art wird wie ein Hinweis behandelt', () {
      final ergebnis = evaluateRequirement(
        const SpecialAbilityRequirement(
          art: RequirementArt.unbekannt,
          text: 'irgendwas',
        ),
        context(),
      );

      expect(ergebnis.status, RequirementStatus.hinweis);
    });
  });

  group('evaluateRequirements und offeneVoraussetzungen', () {
    const bedingungen = <SpecialAbilityRequirement>[
      SpecialAbilityRequirement(
        art: RequirementArt.eigenschaft,
        code: 'MU',
        min: 15,
      ),
      SpecialAbilityRequirement(
        art: RequirementArt.eigenschaft,
        code: 'IN',
        min: 13,
      ),
      SpecialAbilityRequirement(
        art: RequirementArt.hinweis,
        text: 'Ein halbes Jahr Kontemplation',
      ),
    ];

    test('meldet nur die tatsaechlich offenen Punkte', () {
      final ergebnisse = evaluateRequirements(
        bedingungen,
        context(eigenschaften: const <String, int>{'MU': 15, 'IN': 12}),
      );

      expect(ergebnisse, hasLength(3));
      expect(offeneVoraussetzungen(ergebnisse), hasLength(1));
      expect(alleVoraussetzungenErfuellt(ergebnisse), isFalse);
    });

    test('ein reiner Hinweis blockiert den Erwerb nicht', () {
      final ergebnisse = evaluateRequirements(
        bedingungen,
        context(eigenschaften: const <String, int>{'MU': 15, 'IN': 13}),
      );

      expect(offeneVoraussetzungen(ergebnisse), isEmpty);
      expect(alleVoraussetzungenErfuellt(ergebnisse), isTrue);
    });

    test('ohne Bedingungen gilt alles als erfuellt', () {
      expect(
        alleVoraussetzungenErfuellt(
          evaluateRequirements(
            const <SpecialAbilityRequirement>[],
            context(),
          ),
        ),
        isTrue,
      );
    });
  });
}
