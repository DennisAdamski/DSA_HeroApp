import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ansagefolge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

void main() {
  test('Gefechtsumbauten behalten die Pool-Herleitung (ARCH-04)', () {
    final herleitung = Herleitung(
      bezeichnung: 'ZfW*',
      schritte: const <HerleitungsSchritt>[
        HerleitungsSchritt(
          bezeichnung: 'ZfW',
          betrag: 5,
          art: HerleitungsArt.zukauf,
        ),
      ],
    );
    final p = ResolvedProbeRequest(
      type: ProbeType.spell,
      title: 'LK',
      subtitle: '',
      ruleHint: '',
      diceSpec: const DiceSpec(count: 3, sides: 20),
      targets: const [],
      basePool: 5,
      specializationBonus: 2,
      poolHerleitung: herleitung,
    );
    final umgebaut = <ResolvedProbeRequest>[
      modifiziereGefechtsWirkprobe(p, 3),
      gefechtsProbeMitAnsagefolgemalus(p, 2),
      gefechtRequestFuerAuftrag(
        GefechtAuftrag(
          aktion: Gefechtsaktion.handlung,
          titel: 'LK',
          zuschlag: 0,
          dk: null,
          dauer: 1,
          kosten: 1,
          probe: p,
        ),
        const Gefechtspruefung(
          aktion: Gefechtsaktion.handlung,
          status: Gefechtsfreigabe.bereit,
          gruende: [],
          zielwert: null,
          erschwernis: 4,
        ),
      )!,
    ];
    for (final r in umgebaut) {
      expect(r.poolHerleitung, same(herleitung));
      expect(r.basePool, 5);
      expect(r.specializationBonus, 2);
    }
    final mirakel = gefechtsProbeMitBonus(
      p,
      const GefechtsProbenbonus('LK', 3),
    );
    expect(mirakel.basePool, 8);
    expect(mirakel.poolHerleitung!.wert, 8);
    expect(mirakel.poolHerleitung!.schritte.last.bezeichnung, 'Mirakelbonus');
  });
  test('Neue Armatrutz-Werte erhalten frische unbekannte Effektdaten', () {
    final state = HeroState.empty().copyWith(
      activeSpellEffects: const ActiveSpellEffectsState(
        activeEffectIds: [activeSpellEffectArmatrutz],
        effectDetails: {
          activeSpellEffectArmatrutz: ActiveSpellEffectDetail(
            amount: 2,
            unbekannteFelder: {'future': 42},
          ),
        },
      ),
    );
    final neu = uebernimmGefechtsArmatrutz(
      state,
      const ActiveSpellEffectDetail(amount: 5),
    );
    final detail = neu.activeSpellEffects.detailFor(activeSpellEffectArmatrutz);
    expect(detail.amount, 5);
    expect(detail.unbekannteFelder['future'], 42);
  });
  test('Karmale Kultketten, Wiederholungen und Vorzeichen', () {
    for (final k in ['Boron', 'Hesinde', 'Nandus']) {
      expect(gefechtsKultEigenschaften(k), ['MU', 'KL', 'IN']);
    }
    expect(gefechtsKultEigenschaften('unbekannt'), isNull);
    const p = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'LK',
      subtitle: '',
      ruleHint: '',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: [],
      basePool: 5,
    );
    final zuschlag = gefechtsKarmalzuschlag(
      grad: 3,
      mirakel: false,
      mirakelklasse: 0,
      fehlversuche: 2,
      zusaetzlich: 1,
    );
    expect(zuschlag, 11);
    expect(
      modifiziereGefechtsWirkprobe(p, zuschlag).initialSituationalModifier,
      -11,
    );
    expect(
      gefechtsProbeMitBonus(p, const GefechtsProbenbonus('Andere Probe', 7)),
      same(p),
    );
    expect(
      gefechtsProbeMitBonus(p, const GefechtsProbenbonus('LK', 7)).basePool,
      12,
    );
    expect(gefechtsStoerungszuschlag(7, konzentrationsstaerke: true), 0);
  });
  test('Startprobe bindet volle oder bis zur Erkennung verkürzte Dauer', () {
    for (final d in [1, 2, 5]) {
      expect(gefechtsWirkdauer(d, erfolg: true, zauberkontrolle: false), d);
      expect(
        gefechtsWirkdauer(d, erfolg: false, zauberkontrolle: false),
        (d + 1) ~/ 2,
      );
      expect(gefechtsWirkdauer(d, erfolg: false, zauberkontrolle: true), 1);
    }
  });
  test('Kostenmatrix und Grade I bis VI', () {
    expect(
      gefechtsWirkkosten(5, Gefechtshandlungsart.zauber, erfolg: false),
      3,
    );
    expect(
      gefechtsWirkkosten(6, Gefechtshandlungsart.zauber, erfolg: false),
      3,
    );
    expect(
      gefechtsWirkkosten(5, Gefechtshandlungsart.mirakel, erfolg: false),
      1,
    );
    for (var g = 1; g <= 6; g++) {
      expect(gefechtsGradkosten(g), g * 5);
      expect(gefechtsGradzuschlag(g), (g - 1) * 2);
    }
  });
  test('Frische Ressourcen bleiben erhalten; unzureichende Energie sperrt', () {
    const state = HeroState(
      currentLep: 17,
      currentAsp: 9,
      currentKap: 11,
      currentAu: 20,
      unbekannteFelder: {'future': 7},
    );
    final neu = uebernimmGefechtsWirkkosten(state, 3, karmal: false);
    expect(neu.currentAsp, 6);
    expect(neu.currentLep, 17);
    expect(neu.currentKap, 11);
    expect(neu.unbekannteFelder['future'], 7);
    expect(
      () => uebernimmGefechtsWirkkosten(state, 10, karmal: false),
      throwsStateError,
    );
  });
  test('Nur eindeutige feste Angaben werden vorbelegt', () {
    expect(gefechtsFesteAktionen('5 Aktionen'), 5);
    expect(gefechtsFesteAktionen('1–20 Aktionen'), isNull);
    expect(gefechtsFesteAktionen('1 SR'), isNull);
    expect(gefechtsFesteKosten('7 AsP'), 7);
    expect(gefechtsFesteKosten('3 AsP pro Ziel'), isNull);
  });
}
