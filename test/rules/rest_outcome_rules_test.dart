import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_outcome_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';

import '../test_support/hero_fixtures.dart';

const _eigenschaften = Attributes(
  mu: 12,
  kl: 15,
  inn: 14,
  ch: 11,
  ff: 10,
  ge: 12,
  ko: 13,
  kk: 12,
);

RestOutcomeInput _eingabe(
  RestActivity activity, {
  Map<RestRollSlot, int> rolls = const <RestRollSlot, int>{},
  int requestedConditionHours = 1,
  bool applySecondPhase = true,
  bool magicEnabled = true,
  RestEnvironmentInput environment = const RestEnvironmentInput(),
  RestAbilitySummary abilities = const RestAbilitySummary(),
  String magicLeadAttribute = '',
  int maxLep = 30,
  int maxAu = 30,
  int maxAsp = 20,
}) {
  return RestOutcomeInput(
    activity: activity,
    requestedConditionHours: requestedConditionHours,
    applySecondPhase: applySecondPhase,
    rolls: rolls,
    environment: environment,
    abilities: abilities,
    effectiveAttributes: _eigenschaften,
    magicLeadAttribute: magicLeadAttribute,
    magicEnabled: magicEnabled,
    maxLep: maxLep,
    maxAu: maxAu,
    maxAsp: maxAsp,
  );
}

RestVitals _werte({
  int lep = 10,
  int au = 10,
  int asp = 5,
  int ueber = 0,
  int ersch = 0,
}) {
  return RestVitals(
    currentLep: lep,
    currentAu: au,
    currentAsp: asp,
    ueberanstrengung: ueber,
    erschoepfung: ersch,
  );
}

void main() {
  group('RestActivityRules', () {
    test('ordnet jeder Aktivität ihre Teilregeln zu', () {
      expect(RestActivity.kurzeRast.recoversAu, isFalse);
      expect(RestActivity.schlaf.recoversAu, isTrue);
      expect(RestActivity.bettruhe.recoversAu, isTrue);
      expect(RestActivity.nurAusruhen.recoversAu, isTrue);

      expect(RestActivity.kurzeRast.reducesConditions, isTrue);
      expect(RestActivity.schlaf.reducesConditions, isTrue);
      expect(RestActivity.bettruhe.reducesConditions, isTrue);
      expect(RestActivity.nurAusruhen.reducesConditions, isFalse);

      expect(RestActivity.kurzeRast.conditionMode, RestConditionMode.rast);
      expect(RestActivity.schlaf.conditionMode, RestConditionMode.schlaf);
      expect(RestActivity.bettruhe.conditionMode, RestConditionMode.schlaf);

      expect(RestActivity.kurzeRast.conditionHours(3), 3);
      expect(RestActivity.schlaf.conditionHours(3), 8);
      expect(RestActivity.bettruhe.conditionHours(3), 8);
      expect(RestActivity.nurAusruhen.conditionHours(3), 8);
    });

    test('bestimmt die Anzahl der Regenerationsphasen', () {
      int phasen(RestActivity activity, bool zweite) =>
          activity.regenerationPhases(applySecondPhase: zweite);
      expect(phasen(RestActivity.kurzeRast, true), 0);
      expect(phasen(RestActivity.nurAusruhen, true), 0);
      expect(phasen(RestActivity.schlaf, true), 1);
      expect(phasen(RestActivity.schlaf, false), 1);
      expect(phasen(RestActivity.bettruhe, true), 2);
      expect(phasen(RestActivity.bettruhe, false), 1);
    });
  });

  test('isRestProbeSuccessful wertet 1, 20, Zielwert und fehlenden Wurf', () {
    expect(isRestProbeSuccessful(roll: null, target: 20), isFalse);
    expect(isRestProbeSuccessful(roll: 1, target: 0), isTrue);
    expect(isRestProbeSuccessful(roll: 20, target: 25), isFalse);
    expect(isRestProbeSuccessful(roll: 13, target: 13), isTrue);
    expect(isRestProbeSuccessful(roll: 14, target: 13), isFalse);
    expect(isRestProbeSuccessful(roll: 0, target: 5), isTrue);
  });

  group('applicableRestRollSlots', () {
    test('folgt der Protokollreihenfolge je Aktivität', () {
      expect(
        applicableRestRollSlots(_eingabe(RestActivity.kurzeRast)),
        isEmpty,
      );
      expect(applicableRestRollSlots(_eingabe(RestActivity.nurAusruhen)), [
        RestRollSlot.auRoll,
        RestRollSlot.auKoProbe,
      ]);
      expect(applicableRestRollSlots(_eingabe(RestActivity.schlaf)), [
        RestRollSlot.auRoll,
        RestRollSlot.auKoProbe,
        RestRollSlot.phase1Lep,
        RestRollSlot.phase1KoProbe,
        RestRollSlot.phase1Asp,
        RestRollSlot.phase1InProbe,
      ]);
      expect(applicableRestRollSlots(_eingabe(RestActivity.bettruhe)), [
        RestRollSlot.auRoll,
        RestRollSlot.auKoProbe,
        RestRollSlot.phase1Lep,
        RestRollSlot.phase1KoProbe,
        RestRollSlot.phase1Asp,
        RestRollSlot.phase1InProbe,
        RestRollSlot.phase2Lep,
        RestRollSlot.phase2KoProbe,
        RestRollSlot.phase2Asp,
        RestRollSlot.phase2InProbe,
      ]);
    });

    test('lässt AsP und IN ohne Magie weg', () {
      expect(
        applicableRestRollSlots(
          _eingabe(
            RestActivity.bettruhe,
            magicEnabled: false,
            applySecondPhase: false,
          ),
        ),
        [
          RestRollSlot.auRoll,
          RestRollSlot.auKoProbe,
          RestRollSlot.phase1Lep,
          RestRollSlot.phase1KoProbe,
        ],
      );
    });
  });

  group('computeRestOutcome', () {
    test('kurze Rast baut nur Zustände im Rasttempo ab', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.kurzeRast,
          requestedConditionHours: 3,
          rolls: const {RestRollSlot.auRoll: 18, RestRollSlot.phase1Lep: 6},
        ),
        // Werte über dem Maximum bleiben ohne Regeneration unangetastet.
        current: _werte(lep: 40, au: 40, asp: 25, ueber: 2, ersch: 4),
      );

      expect(outcome.au, isNull);
      expect(outcome.phases, isEmpty);
      expect(outcome.conditions!.mode, RestConditionMode.rast);
      expect(outcome.conditions!.hours, 3);
      expect(outcome.after.currentLep, 40);
      expect(outcome.after.currentAu, 40);
      expect(outcome.after.currentAsp, 25);
      // 2 Stunden für 2 Überanstrengung, 1 Stunde für 2 Erschöpfung.
      expect(outcome.after.ueberanstrengung, 0);
      expect(outcome.after.erschoepfung, 2);
    });

    test('nur ausruhen regeneriert Ausdauer bis zum Maximum', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.nurAusruhen,
          rolls: const {RestRollSlot.auRoll: 9, RestRollSlot.auKoProbe: 1},
          maxAu: 22,
        ),
        current: _werte(au: 10, ueber: 3, ersch: 3),
      );

      expect(outcome.au!.recovered, 12);
      expect(outcome.after.currentAu, 22);
      expect(outcome.conditions, isNull);
      expect(outcome.after.ueberanstrengung, 3);
      expect(outcome.after.erschoepfung, 3);
    });

    test('fehlender Ausdauerwurf zählt 0, fehlende Probe misslingt', () {
      final mitProbe = computeRestOutcome(
        input: _eingabe(
          RestActivity.nurAusruhen,
          rolls: const {RestRollSlot.auKoProbe: 5},
        ),
        current: _werte(au: 10),
      );
      final ohneProbe = computeRestOutcome(
        input: _eingabe(
          RestActivity.nurAusruhen,
          rolls: const {RestRollSlot.auRoll: 7},
        ),
        current: _werte(au: 10),
      );

      expect(mitProbe.after.currentAu, 16);
      expect(ohneProbe.after.currentAu, 17);
      expect(ohneProbe.au!.koBonusApplied, isFalse);
    });

    test('Schlaf nutzt eine Phase und ignoriert Würfe der zweiten', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.schlaf,
          rolls: const {
            RestRollSlot.auRoll: 10,
            RestRollSlot.phase1Lep: 4,
            RestRollSlot.phase1KoProbe: 2,
            RestRollSlot.phase1Asp: 3,
            RestRollSlot.phase1InProbe: 19,
            RestRollSlot.phase2Lep: 6,
            RestRollSlot.phase2Asp: 6,
          },
        ),
        current: _werte(lep: 10, au: 10, asp: 5, ueber: 4, ersch: 8),
      );

      expect(outcome.phases, hasLength(1));
      expect(outcome.conditions!.mode, RestConditionMode.schlaf);
      expect(outcome.conditions!.hours, 8);
      expect(outcome.after.currentAu, 20);
      // 4 + KO-Probe gelungen.
      expect(outcome.after.currentLep, 15);
      // 3, IN-Probe misslungen.
      expect(outcome.after.currentAsp, 8);
      expect(outcome.after.ueberanstrengung, 0);
      expect(outcome.after.erschoepfung, 0);
    });

    test('Bettruhe baut Phase 2 auf Phase 1 auf und hält am Maximum', () {
      const rolls = {
        RestRollSlot.phase1Lep: 6,
        RestRollSlot.phase1Asp: 5,
        RestRollSlot.phase2Lep: 6,
        RestRollSlot.phase2Asp: 5,
      };
      final zweiPhasen = computeRestOutcome(
        input: _eingabe(
          RestActivity.bettruhe,
          rolls: rolls,
          maxLep: 20,
          maxAsp: 12,
        ),
        current: _werte(lep: 10, asp: 5),
      );
      final einePhase = computeRestOutcome(
        input: _eingabe(
          RestActivity.bettruhe,
          rolls: rolls,
          applySecondPhase: false,
          maxLep: 20,
          maxAsp: 12,
        ),
        current: _werte(lep: 10, asp: 5),
      );
      final schlaf = computeRestOutcome(
        input: _eingabe(
          RestActivity.schlaf,
          rolls: rolls,
          maxLep: 20,
          maxAsp: 12,
        ),
        current: _werte(lep: 10, asp: 5),
      );

      expect(zweiPhasen.phases.map((phase) => phase.lepGain), [6, 4]);
      expect(zweiPhasen.phases.map((phase) => phase.aspGain), [5, 2]);
      expect(zweiPhasen.after.currentLep, 20);
      expect(zweiPhasen.after.currentAsp, 12);
      expect(einePhase.after.currentLep, 16);
      expect(einePhase.after.currentAsp, 10);
      expect(schlaf.after.currentLep, einePhase.after.currentLep);
      expect(schlaf.after.currentAsp, einePhase.after.currentAsp);
    });

    test('Krankheit gibt keine LeP und genau 1 AsP', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.schlaf,
          rolls: const {RestRollSlot.phase1Lep: 6, RestRollSlot.phase1Asp: 6},
          environment: const RestEnvironmentInput(isIll: true),
        ),
        current: _werte(lep: 10, asp: 5),
      );

      expect(outcome.after.currentLep, 10);
      expect(outcome.after.currentAsp, 6);
    });

    test('Meisterliche Regeneration und Umgebung wirken durch', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.schlaf,
          rolls: const {RestRollSlot.phase1Lep: 4, RestRollSlot.phase1Asp: 1},
          abilities: const RestAbilitySummary(hasMasterfulRegeneration: true),
          magicLeadAttribute: 'KL',
          environment: const RestEnvironmentInput(hasWatchDuty: true),
        ),
        current: _werte(lep: 10, asp: 0),
      );

      final phase = outcome.phases.single.result;
      expect(phase.usedMasterfulRegeneration, isTrue);
      expect(phase.environmentModifier, -1);
      expect(outcome.after.currentLep, 13);
      expect(outcome.after.currentAsp, phase.aspRecovered);
    });

    test('Regeneration senkt Werte über dem Maximum und hebt negative LeP', () {
      final ueberMaximum = computeRestOutcome(
        input: _eingabe(RestActivity.schlaf, maxLep: 20, maxAu: 20),
        current: _werte(lep: 25, au: 25, asp: 5),
      );
      final negativ = computeRestOutcome(
        input: _eingabe(RestActivity.schlaf),
        current: _werte(lep: -5),
      );

      expect(ueberMaximum.after.currentLep, 20);
      expect(ueberMaximum.after.currentAu, 20);
      expect(negativ.after.currentLep, 0);
    });

    test('ohne Magie sinken AsP über dem Maximum auf das Maximum', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.schlaf,
          magicEnabled: false,
          maxAsp: 0,
          rolls: const {RestRollSlot.phase1Asp: 6},
        ),
        current: _werte(asp: 4),
      );

      expect(outcome.phases.single.aspGain, -4);
      expect(outcome.after.currentAsp, 0);
    });

    test('ein negatives Maximum gilt als 0 statt zu werfen', () {
      final outcome = computeRestOutcome(
        input: _eingabe(
          RestActivity.bettruhe,
          maxLep: -3,
          maxAu: -1,
          maxAsp: -2,
        ),
        current: _werte(lep: 4, au: 4, asp: 4),
      );

      expect(outcome.after.currentLep, 0);
      expect(outcome.after.currentAu, 0);
      expect(outcome.after.currentAsp, 0);
    });
  });

  test('applyRestOutcome ersetzt nur die fünf Rastwerte', () {
    const vorher = HeroState(
      currentLep: 10,
      currentAsp: 5,
      currentKap: 3,
      currentAu: 10,
      ueberanstrengung: 2,
      erschoepfung: 4,
      wpiZustand: WundZustand(wundenProZone: <WundZone, int>{WundZone.kopf: 1}),
    );
    final outcome = computeRestOutcome(
      input: _eingabe(
        RestActivity.schlaf,
        rolls: const {RestRollSlot.auRoll: 5, RestRollSlot.phase1Lep: 3},
      ),
      current: RestVitals.fromState(vorher),
    );

    final nachher = applyRestOutcome(vorher, outcome);

    expect(nachher.currentLep, 13);
    expect(nachher.currentAu, 15);
    expect(nachher.ueberanstrengung, 0);
    expect(nachher.erschoepfung, 0);
    expectNurGeaendert(vorher.toJson(), nachher.toJson(), {
      'currentLep',
      'currentAu',
      'currentAsp',
      'ueberanstrengung',
      'erschoepfung',
    });
  });
}
