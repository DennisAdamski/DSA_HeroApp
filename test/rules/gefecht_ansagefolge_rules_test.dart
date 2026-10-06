import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ansagefolge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_orientieren_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ansagen_paket2_test.dart' as fixture;
import 'gefecht_laden_rules_test.dart' as fk;
import '../ui2/shell/karto_test_support.dart';

// Ein einzelner echter Nahkampfangriff mit getrennten freiwilligen Ansagen.
GefechtAuftrag _auftrag({int finte = 0, int wucht = 0, ManeuverDef? m}) =>
    GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'AT',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      finte: finte,
      wuchtschlag: wucht,
      manoever: m,
    );

void main() {
  final snap = fixture.ansageSnapshot();
  final w = gefechtswerteFuer(snap);
  test('Aktiver Klingentänzer halbiert ungerade Ansagen aufgerundet', () {
    final kt = buildHeroComputedSnapshot(
      hero: snap.hero.copyWith(
        combatConfig: snap.hero.combatConfig.copyWith(
          specialRules: snap.hero.combatConfig.specialRules.copyWith(
            klingentaenzer: true,
          ),
        ),
      ),
      state: snap.state,
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    expect(gefechtsAnsageFehlmalus(kt, _auftrag(finte: 5)), 3);
  });
  test('FK-Sonderansagen erzeugen keinen Nahkampf-Folgemalus', () {
    expect(gefechtsAnsageFehlmalus(fk.ladeSnapshot(), fk.zielauftrag), 0);
  });
  test('Schadenswürfe bleiben auch als manuelle Fachprobe unverändert', () {
    const r = ResolvedProbeRequest(
      type: ProbeType.damage,
      title: 'Schaden',
      subtitle: '',
      ruleHint: '',
      diceSpec: DiceSpec(count: 1, sides: 6),
      targets: [],
    );
    expect(gefechtsProbeMitAnsagefolgemalus(r, 5), same(r));
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.handlung,
      titel: 'Schaden',
      zuschlag: 0,
      dk: null,
      dauer: 1,
      kosten: 0,
      probe: r,
    );
    final p = pruefeGefechtAuftrag(
      const Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5),
      snap,
      testCatalog,
      a,
    );
    expect(gefechtRequestFuerAuftrag(a, p)!.initialSituationalModifier, 0);
  });
  test(
    'Mehrteilige manuelle AT bleibt gesperrt und verändert keine Ansagefolge',
    () {
      const r = ResolvedProbeRequest(
        type: ProbeType.attribute,
        title: 'Manuelle AT',
        subtitle: '',
        ruleHint: '',
        diceSpec: DiceSpec(count: 1, sides: 20),
        targets: [ProbeTargetValue(label: 'AT', value: 14)],
      );
      const a = GefechtAuftrag(
        aktion: Gefechtsaktion.handlung,
        titel: 'Manuelle AT',
        zuschlag: 0,
        dk: null,
        dauer: 2,
        kosten: 1,
        probe: r,
        manuell: true,
        manuelleKampfaktion: Gefechtsaktion.angriff,
      );
      const s = Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5);
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      expect(p.ausfuehrbar, false);
      expect(() => verbraucheGefechtsaktion(s, w, p), throwsStateError);
      expect(s.ansageFolgemalus, 5);
    },
  );
  test('Bestätigte einzelne manuelle AT ohne Marken beendet die Folge', () {
    const s = Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5);
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.handlung,
      titel: 'Manuelle AT',
      zuschlag: 0,
      dk: null,
      dauer: 1,
      kosten: 0,
      zielwert: 12,
      manuell: true,
      manuelleKampfaktion: Gefechtsaktion.angriff,
      bestaetigteEntscheidungen: [
        'Wirkung und Ressourcen dieser Sonderaktion festgelegt.',
      ],
    );
    final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
    expect(p.ausfuehrbar, true);
    expect(p.zielwert, 7);
    expect(p.angriffe + p.paraden + p.zusatz, 0);
    expect(
      verbraucheGefechtsaktion(s, w, p, erfolg: false).ansageFolgemalus,
      0,
    );
  });
  test(
    'Nur misslungene echte Buchung erzeugt volle freiwillige Ansagefolge',
    () {
      const s = Gefechtszustand(iniWurf: 6);
      final p = pruefeGefechtAuftrag(
        s,
        snap,
        testCatalog,
        _auftrag(finte: 3, wucht: 2),
      );
      expect(s.ansageFolgemalus, 0);
      expect(
        verbraucheGefechtsaktion(s, w, p, erfolg: true).ansageFolgemalus,
        0,
      );
      expect(verbraucheGefechtsaktion(s, w, p).ansageFolgemalus, 0);
      expect(
        verbraucheGefechtsaktion(s, w, p, erfolg: false).ansageFolgemalus,
        5,
      );
    },
  );
  test(
    'Feste und freiwillige Ansage bleiben von Situationszuschlägen getrennt',
    () {
      const m = ManeuverDef(
        id: 'man_test',
        name: 'Test',
        gruppe: 'bewaffnet',
        typ: 'Angriffsaktion',
        erschwernis: 'Angriff +4',
      );
      expect(gefechtsAnsageFehlmalus(snap, _auftrag(finte: 3, m: m)), 7);
    },
  );
  test(
    'Nächste echte AT trägt alten Malus noch und ersetzt ihn bei Fehlschlag',
    () {
      const s = Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5);
      final a = _auftrag(finte: 3);
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      final ohne = pruefeGefechtAuftrag(
        s.copyWith(ansageFolgemalus: 0),
        snap,
        testCatalog,
        a,
      );
      expect(p.zielwert, ohne.zielwert! - 5);
      expect(
        verbraucheGefechtsaktion(s, w, p, erfolg: true).ansageFolgemalus,
        0,
      );
      expect(
        verbraucheGefechtsaktion(s, w, p, erfolg: false).ansageFolgemalus,
        3,
      );
      expect(naechsteGefechtsrunde(s).ansageFolgemalus, 5);
    },
  );
  test('Freie Probe erhält Folgemalus und verbraucht ihn nicht', () {
    const s = Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5);
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.freieAktion,
      titel: 'Rufen',
      zuschlag: 0,
      dk: null,
      dauer: 1,
      kosten: 0,
      zielwert: 12,
    );
    final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
    expect(p.zielwert, 7);
    expect(verbraucheGefechtsaktion(s, w, p, erfolg: true).ansageFolgemalus, 5);
  });
  test('Fachprobe übernimmt den endgültigen Zuschlag genau einmal', () {
    const r = ResolvedProbeRequest(
      type: ProbeType.talent,
      title: 'Akrobatik',
      subtitle: 'Freie Fachprobe',
      ruleHint: '',
      diceSpec: DiceSpec(count: 3, sides: 20),
      basePool: 10,
      targets: [ProbeTargetValue(label: 'MU', value: 14)],
      initialSituationalModifier: -1,
    );
    const s = Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5);
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.handlung,
      titel: 'Akrobatik',
      zuschlag: 2,
      dk: null,
      dauer: 1,
      kosten: 1,
      probe: r,
    );
    final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
    expect(gefechtRequestFuerAuftrag(a, p)!.initialSituationalModifier, -8);
    expect(
      gefechtsProbeMitAnsagefolgemalus(r, 5).initialSituationalModifier,
      -6,
    );
  });
  test('Orientieren beendet den Malus auch bei misslungener IN-Probe', () {
    const s = Gefechtszustand(iniWurf: 6, ansageFolgemalus: 5);
    expect(
      uebernimmOrientierung(s, maximum: 6, erfolg: false).ansageFolgemalus,
      0,
    );
  });
}
