import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

import '../ui2/shell/karto_test_support.dart';

void main() {
  test(
    'Manöver erhält Umwandlungssperre der frisch gewählten langen Waffe',
    () {
      final m = ManeuverDef.fromJson({
        'id': 'man_binden',
        'name': 'Binden',
        'typ': 'Abwehraktion',
      });
      final k = RulesCatalog(
        version: 'test',
        source: 'test',
        talents: [],
        spells: [],
        weapons: [
          WeaponDef.fromJson({'name': 'Langwaffe', 'length': '250'}),
        ],
      );
      final snap = buildHeroComputedSnapshot(
        hero: testHero().copyWith(
          combatConfig: const CombatConfig(
            weapons: [
              MainWeaponSlot(
                name: 'Langwaffe',
                weaponType: 'Langwaffe',
                distanceClass: 'N',
              ),
            ],
            specialRules: CombatSpecialRules(activeManeuvers: ['man_binden']),
          ),
        ),
        state: const HeroState.empty(),
        catalog: k,
        epicAdvantagesActive: false,
      );
      final s = beginneGefecht(6)
          .copyWith(umwandlung: Gefechtsumwandlung.zweiteParade, dk: 'N');
      expect(
        pruefeGefechtsmanoever(s, snap, k, m, zuschlag: 0).status,
        Gefechtsfreigabe.gesperrt,
      );
    },
  );

  test('Manöverliste zeigt nur erlernte und allgemein verfügbare Manöver', () {
    const k = RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [],
      spells: [],
      weapons: [],
      maneuvers: [
        ManeuverDef(id: 'man_finte', name: 'Finte', typ: 'Angriffsaktion'),
        ManeuverDef(
          id: 'man_wuchtschlag',
          name: 'Wuchtschlag',
          typ: 'Angriffsaktion',
        ),
        ManeuverDef(id: 'man_binden', name: 'Binden', typ: 'Abwehraktion'),
        ManeuverDef(
          id: 'man_meisterparade',
          name: 'Meisterparade',
          typ: 'Abwehraktion',
        ),
        ManeuverDef(
          id: 'man_scharfschuetze',
          name: 'Scharfschütze',
          mussSeparatErlerntWerden: true,
        ),
      ],
    );
    final snap = buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: const CombatConfig(
          weapons: [
            MainWeaponSlot(
              name: 'Bogen',
              talentId: 'tal_bogen',
              distanceClass: 'N',
            ),
          ],
          specialRules: CombatSpecialRules(
            activeManeuvers: ['man_binden', 'man_scharfschuetze::tal_bogen'],
          ),
        ),
      ),
      state: const HeroState.empty(),
      catalog: k,
      epicAdvantagesActive: false,
    );
    final ids = gefechtsManoeverliste(
      beginneGefecht(6),
      snap,
      k,
    ).map((m) => m.id).toSet();
    expect(ids, {
      'man_finte',
      'man_wuchtschlag',
      'man_binden',
      'man_scharfschuetze',
    });
  });

  test('Neue kurze oder lange Zauber und manuelle Aufträge verdrängen keine Resthandlung', () {
    final snapshot = buildHeroComputedSnapshot(
      hero: testHero(),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    const probe = ResolvedProbeRequest(
      type: ProbeType.spell,
      title: 'Zauber',
      subtitle: '',
      ruleHint: '',
      diceSpec: DiceSpec(count: 3, sides: 20),
      targets: [],
      basePool: 7,
    );
    for (final h in [
      const Gefechtshandlung(
        titel: 'Waffe ziehen',
        verbleibend: 2,
        waffenId: 'w2',
      ),
      const Gefechtshandlung(titel: 'Zauber', verbleibend: 2, probe: probe),
    ]) {
      final s = beginneGefecht(6).copyWith(handlung: h);
      for (final dauer in [1, 3]) {
        for (final zauber in [false, true]) {
          final a = GefechtAuftrag(
            aktion: Gefechtsaktion.handlung,
            titel: 'Neuer Auftrag',
            zuschlag: 0,
            dk: null,
            dauer: dauer,
            kosten: 1,
            zielwert: zauber ? null : 14,
            manuell: true,
            probe: zauber ? probe : null,
          );
          expect(
            pruefeGefechtAuftrag(s, snapshot, testCatalog, a).status,
            Gefechtsfreigabe.gesperrt,
          );
        }
      }
    }
  });
  test('Abwehraktion verwendet die Verteidigungsmarke und Katalogzuschlag', () {
    final m = ManeuverDef.fromJson({
      'id': 'man_binden',
      'name': 'Binden',
      'typ': 'Abwehraktion',
      'erschwernis': 'Abwehr +4',
    });
    final werte = buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: const CombatConfig(
          weapons: [MainWeaponSlot(name: 'Schwert')],
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    final p = pruefeGefechtsmanoever(
      beginneGefecht(6),
      werte,
      testCatalog,
      m,
      zuschlag: 0,
    );
    expect(gefechtsManoeverZuschlag(m), 4);
    expect(p.paraden, 1);
    expect(p.angriffe, 0);
    expect(p.zielwert, werte.combatPreviewStats.pa - 4);
  });
  test(
    'Gegenhalten würfelt AT ohne hohen INI-Paradebonus und verbraucht PA',
    () {
      final m = ManeuverDef.fromJson({
        'id': 'man_gegenhalten',
        'name': 'Gegenhalten',
        'typ': 'Abwehraktion',
        'erschwernis': 'Abwehr +4',
      });
      final snapshot = buildHeroComputedSnapshot(
        hero: testHero().copyWith(
          combatConfig: const CombatConfig(
            weapons: [MainWeaponSlot(name: 'Schwert')],
          ),
        ),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      final p = pruefeGefechtsmanoever(
        beginneGefecht(40),
        snapshot,
        testCatalog,
        m,
        zuschlag: 0,
      );
      expect(p.paraden, 1);
      expect(p.angriffe, 0);
      expect(p.zielwert, snapshot.combatPreviewStats.at - 4);
    },
  );
  test(
    'Aktueller Kopf-INI-Verlust wird zusätzlich zum Wund-Basismalus übernommen',
    () {
      final s = buildHeroComputedSnapshot(
        hero: testHero(),
        state: const HeroState.empty().copyWith(
          wpiZustand: const WundZustand(
            wundenProZone: {WundZone.kopf: 1},
            kopfIniMalus: 8,
          ),
        ),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      expect(
        gefechtswerteFuer(s).iniBasis,
        s.combatPreviewStats.kampfInitiative -
            s.combatPreviewStats.iniWurfEffective -
            8,
      );
    },
  );
  test('Manuelle Sonderprobe berücksichtigt die bestätigte Erschwernis', () {
    final werte = buildHeroComputedSnapshot(
      hero: testHero(),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    const auftrag = GefechtAuftrag(
      aktion: Gefechtsaktion.handlung,
      titel: 'Sonderprobe',
      zuschlag: 4,
      zielwert: 18,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      manuell: true,
    );
    final p = pruefeGefechtAuftrag(
      beginneGefecht(6),
      werte,
      testCatalog,
      auftrag,
    );
    expect(p.zielwert, 14);
    expect(gefechtRequestFuerAuftrag(auftrag, p)!.targets.single.value, 14);
  });
  HeroComputedSnapshot snapshot(
    MainWeaponSlot waffe, {
    List<String> gelernt = const [],
    Map<String, HeroTalentEntry> talente = const {},
  }) => buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      talents: talente,
      combatConfig: CombatConfig(
        weapons: [waffe],
        specialRules: CombatSpecialRules(activeManeuvers: gelernt),
      ),
    ),
    state: const HeroState.empty(),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  final hammer = ManeuverDef.fromJson({
    'id': 'man_hammerschlag',
    'typ': 'Angriffsaktion',
    'name': 'Hammerschlag',
    'muss_separat_erlernt_werden': true,
  });
  final k = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    spells: [],
    weapons: [],
    maneuvers: [hammer],
  );
  GefechtAuftrag auftrag({bool gegner = false, bool schild = false}) =>
      GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: hammer.name,
        zuschlag: 8,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        manoever: hammer,
        grosserGegner: gegner,
        grosserSchild: schild,
      );

  test('Nicht erlerntes Manöver und ungeeignete Waffen bleiben gesperrt', () {
    for (final waffe in [
      const MainWeaponSlot(name: 'Schwert', talentId: 'tal_schwerter'),
      const MainWeaponSlot(
        name: 'Nachtwind',
        talentId: 'tal_anderthalbhaender',
      ),
    ]) {
      expect(
        pruefeGefechtAuftrag(
          beginneGefecht(6),
          snapshot(waffe, gelernt: [hammer.id]),
          k,
          auftrag(),
        ).status,
        Gefechtsfreigabe.gesperrt,
      );
    }
    expect(
      pruefeGefechtAuftrag(
        beginneGefecht(6),
        snapshot(const MainWeaponSlot(name: 'Axt', talentId: 'tal_hiebwaffen')),
        k,
        auftrag(),
      ).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('Hammerschlag verbraucht alle regulären Aktionen und sperrt erkannte Gegner', () {
    final werte = snapshot(
      const MainWeaponSlot(
        name: 'Axt',
        talentId: 'tal_hiebwaffen',
        distanceClass: 'N',
      ),
      gelernt: [hammer.id],
    );
    final s = beginneGefecht(6);
    final p = pruefeGefechtAuftrag(s, werte, k, auftrag());
    expect(p.status, Gefechtsfreigabe.pruefen);
    expect(p.angriffe, 1);
    expect(p.paraden, 1);
    expect(
      pruefeGefechtAuftrag(s, werte, k, auftrag(gegner: true)).status,
      Gefechtsfreigabe.gesperrt,
    );
    expect(
      pruefeGefechtAuftrag(s, werte, k, auftrag(schild: true)).status,
      Gefechtsfreigabe.gesperrt,
    );
    expect(
      pruefeGefechtAuftrag(
        s.copyWith(paradenVerbraucht: 1),
        werte,
        k,
        auftrag(),
      ).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('Stäbe TaW 10 wandeln ohne Zuschlag um; zwei Kosten schließen Dauer zwei ab', () {
    final werte = snapshot(
      const MainWeaponSlot(
        name: 'Stab',
        talentId: 'tal_staebe',
        distanceClass: 'N',
      ),
      talente: {'tal_staebe': const HeroTalentEntry(talentValue: 10)},
    );
    expect(gefechtswerteFuer(werte).stabUmwandlung, true);
    final s = wandleGefechtUm(
      beginneGefecht(6),
      Gefechtsumwandlung.zweiteAttacke,
    ).copyWith(angriffeVerbraucht: 1);
    expect(
      pruefeGefechtsaktion(
        s,
        gefechtswerteFuer(werte),
        Gefechtsaktion.angriff,
      ).erschwernis,
      0,
    );
    final h = gefechtHandlungNachAuftrag(
      titel: 'Sonderaktion',
      dauer: 2,
      pruefung: const Gefechtspruefung(
        aktion: Gefechtsaktion.handlung,
        status: Gefechtsfreigabe.pruefen,
        gruende: [],
        zielwert: null,
        angriffe: 1,
        paraden: 1,
      ),
    );
    expect(h, isNull);
  });
}
