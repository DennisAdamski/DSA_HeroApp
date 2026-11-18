import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui2/shell/karto_test_support.dart';

// Proben für Reittiere (Reittiere P2): Reiten mit dem Stufenmodifikator des
// Reittiers (ZBA S. 35, die Tabellenwerte sind in
// reittier_ausbildung_rules_test.dart belegt) und LO auf die wirksame
// Loyalität.

const _reiten = TalentDef(
  id: 'tal_reiten',
  name: 'Reiten',
  group: 'Körper',
  steigerung: 'B',
  attributes: ['Charisma', 'Gewandtheit', 'Körperkraft'],
  be: 'x2',
);

HeroComputedSnapshot _snapshot({bool reitenGefuehrt = true}) =>
    buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        talents: reitenGefuehrt
            ? const {'tal_reiten': HeroTalentEntry(talentValue: 9)}
            : const {},
      ),
      state: const HeroState.empty(),
      catalog: const RulesCatalog(
        version: 'test',
        source: 'test',
        talents: [_reiten],
        spells: [],
        weapons: [],
      ),
      epicAdvantagesActive: false,
    );

HeroCompanion _pferd({ReittierAusbildung? ausbildung, int lo = 12}) =>
    HeroCompanion(
      id: 'p1',
      name: 'Windfang',
      typ: BegleiterTyp.reittier,
      loyalitaet: lo,
      reittierAusbildung: ausbildung,
    );

typedef _Ergebnis = ({ResolvedProbeRequest? request, String? hinweis});

_Ergebnis _baue(
  HeroCompanion pferd, {
  bool imKampf = false,
  bool zauberer = false,
  bool gefuehrt = true,
  List<TalentDef> talente = const [_reiten],
}) {
  final aufbau = reittierReitenProbe(
    snapshot: _snapshot(reitenGefuehrt: gefuehrt),
    talente: talente,
    reittier: pferd,
    imKampf: imKampf,
    reiterIstZauberer: zauberer,
    epicAdvantagesActive: false,
  );
  return (request: aufbau.request, hinweis: aufbau.hinweis);
}

void main() {
  const erprobtLaendlich = ReittierAusbildung(
    ausgangsstufe: ReittierAusbildungsstufe.erprobt,
  );
  const streitross = ReittierAusbildung(
    ausgangsstufe: ReittierAusbildungsstufe.erprobt,
    ausgangsart: ReittierAusbildungsart.fundiert,
    varianteId: 'pvar_leichtes_streitross',
    schritte: <ReittierAusbildungsschritt>[
      ReittierAusbildungsschritt(
        nach: ReittierAusbildungsstufe.geschult,
        art: ReittierAusbildungsart.fundiert,
      ),
    ],
  );

  group('Reiten-Probe', () {
    test('trägt den Stufenmodifikator als situative Erschwernis', () {
      final probe = _baue(_pferd(ausbildung: erprobtLaendlich));
      expect(probe.hinweis, isNull);
      final request = probe.request!;
      expect(request.basePool, 9);
      // erprobt: Reiten −1, also erleichtert; Modell: negativ = erschwert.
      expect(request.initialSituationalModifier, 1);
      expect(request.title, contains('Reiten'));
      expect(request.title, contains('Windfang'));
      expect(request.ruleHint, contains('ZBA S. 35'));
      expect(
        request.verweis,
        isNull,
        reason: 'kein Wiederholen ohne Modifikator',
      );
    });

    test('im Kampf gilt die Kampfzeile samt Hinweisen zum ländlichen Tier', () {
      final probe = _baue(_pferd(ausbildung: erprobtLaendlich), imKampf: true);
      final request = probe.request!;
      // erprobt im Kampf 0, ländlich im Kampf +3 → erschwert um 3.
      expect(request.initialSituationalModifier, -3);
      expect(request.title, contains('im Kampf'));
      expect(request.ruleHint, contains('Ländlich ausgebildet'));
      expect(request.ruleHint, contains('nicht in dieser Probe'));
    });

    test('ein geschultes Kampfpferd im Kampf ist stärker erleichtert', () {
      final normal = _baue(_pferd(ausbildung: streitross)).request!;
      final kampf = _baue(
        _pferd(ausbildung: streitross),
        imKampf: true,
      ).request!;
      // geschult −2, als Kampfpferd im Kampf −3 (ZBA S. 35).
      expect(normal.initialSituationalModifier, 2);
      expect(kampf.initialSituationalModifier, 3);
    });

    test('ohne erfasste Ausbildung: kein Modifikator, der Hinweis sagt es', () {
      final request = _baue(_pferd()).request!;
      expect(request.initialSituationalModifier, 0);
      expect(request.ruleHint, contains('keine Ausbildung erfasst'));
    });

    test('Magierpferd gibt Zauberkundigen −1', () {
      const magierpferd = ReittierAusbildung(
        ausgangsstufe: ReittierAusbildungsstufe.erprobt,
        ausgangsart: ReittierAusbildungsart.fundiert,
        varianteId: 'pvar_magierpferd',
        schritte: <ReittierAusbildungsschritt>[
          ReittierAusbildungsschritt(
            nach: ReittierAusbildungsstufe.geschult,
            art: ReittierAusbildungsart.fundiert,
          ),
        ],
      );
      final ohne = _baue(_pferd(ausbildung: magierpferd)).request!;
      final mit = _baue(
        _pferd(ausbildung: magierpferd),
        zauberer: true,
      ).request!;
      expect(
        mit.initialSituationalModifier,
        ohne.initialSituationalModifier + 1,
      );
      expect(mit.ruleHint, contains('Magierpferd'));
    });

    test(
      'ohne geführtes Talent oder ohne Katalogeintrag gibt es einen Hinweis',
      () {
        final ohneTalent = _baue(
          _pferd(ausbildung: erprobtLaendlich),
          gefuehrt: false,
        );
        expect(ohneTalent.request, isNull);
        expect(ohneTalent.hinweis, contains('führt Reiten nicht'));
        final ohneKatalog = _baue(
          _pferd(ausbildung: erprobtLaendlich),
          talente: const [],
        );
        expect(ohneKatalog.request, isNull);
        expect(ohneKatalog.hinweis, contains('nicht im Katalog'));
      },
    );
  });

  group('LO-Probe', () {
    test('würfelt 1W20 auf die wirksame Loyalität inklusive Ausbildung', () {
      // Geschultes leichtes Streitross: LO +4 (reittier_ausbildung_rules_test).
      final request = begleiterLoyalitaetsProbe(
        _pferd(ausbildung: streitross, lo: 12),
      );
      expect(request.targets.single.value, 16);
      expect(request.diceSpec.count, 1);
      expect(request.diceSpec.sides, 20);
      expect(request.title, contains('Windfang'));
      expect(request.type, ProbeType.attribute);
    });

    test('ohne Ausbildung gilt der eingetragene Wert', () {
      expect(
        begleiterLoyalitaetsProbe(_pferd(lo: 14)).targets.single.value,
        14,
      );
    });
  });

  test('nur Reittiere bieten Proben an', () {
    expect(reittierHatProben(_pferd()), isTrue);
    expect(
      reittierHatProben(
        const HeroCompanion(id: 'v', typ: BegleiterTyp.vertrauter),
      ),
      isFalse,
    );
    expect(
      reittierHatProben(
        const HeroCompanion(id: 's', typ: BegleiterTyp.sonstigerBegleiter),
      ),
      isFalse,
    );
  });
}
