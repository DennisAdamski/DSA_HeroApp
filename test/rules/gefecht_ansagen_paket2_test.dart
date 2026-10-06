import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ansage_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

/// Realer Snapshot mit ausreichendem AT-Wert für unabhängige Ansagen.
HeroComputedSnapshot ansageSnapshot({
  String talent = 'tal_schwerter',
  bool sf = false,
  bool kampfgespuer = false,
}) => buildHeroComputedSnapshot(
  hero: testHero().copyWith(
    talents: {talent: const HeroTalentEntry(talentValue: 16)},
    combatConfig: CombatConfig(
      weapons: [
        MainWeaponSlot(
          id: 'a',
          name: 'Schwert',
          talentId: talent,
          distanceClass: 'N',
          wmAt: 10,
        ),
      ],
      specialRules: CombatSpecialRules(
        kampfgespuer: kampfgespuer,
        activeManeuvers: sf
            ? ['man_finte', 'man_wuchtschlag', 'man_sturmangriff']
            : [],
      ),
    ),
  ),
  state: const HeroState.empty(),
  catalog: testCatalog,
  epicAdvantagesActive: false,
);

GefechtAuftrag _auftrag({
  int finte = 0,
  int wucht = 0,
  int zuschlag = 0,
  ManeuverDef? m,
}) => GefechtAuftrag(
  aktion: Gefechtsaktion.angriff,
  titel: 'AT',
  zuschlag: zuschlag,
  finte: finte,
  wuchtschlag: wucht,
  dk: 'N',
  dauer: 1,
  kosten: 1,
  manoever: m,
);

void main() {
  test('Bezahlte FK-Zielzeit ist nicht auf andere Munition übertragbar', () {
    final basis = ansageSnapshot();
    final waffe = basis.hero.combatConfig.selectedWeapon.copyWith(
      combatType: WeaponCombatType.ranged,
      rangedProfile: const RangedWeaponProfile(
        selectedProjectileIndex: 0,
        projectiles: [
          RangedProjectile(id: 'p1', name: 'Pfeil', count: 10),
          RangedProjectile(id: 'p2', name: 'Anderer Pfeil', count: 10),
        ],
      ),
    );
    HeroComputedSnapshot snapshot(MainWeaponSlot w) =>
        buildHeroComputedSnapshot(
          hero: basis.hero.copyWith(
            combatConfig: basis.hero.combatConfig.copyWith(weapons: [w]),
          ),
          state: const HeroState.empty(),
          catalog: testCatalog,
          epicAdvantagesActive: false,
        );
    final snap = snapshot(waffe);
    final z = Gefechtszielstand(
      kampfmittel: const GefechtsKampfmittelwahl(
        GefechtsKampfmittelArt.hauptwaffe,
        'a',
      ),
      zielkontakt: 'Ork',
      ansage: 5,
      bezahlteAktionen: 3,
      geschossId: 'p1',
      waffenprofilKey: gefechtsZielprofilKey(waffe),
    );
    final s = Gefechtszustand(
      iniWurf: 6,
      zielstand: z,
      kontext: const Gefechtskontext(kontakt: 'Ork', geladen: true),
    );
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'FK',
      zuschlag: 0,
      dk: null,
      dauer: 1,
      kosten: 1,
      fernkampfansage: 5,
    );
    final geaendert = snapshot(
      waffe.copyWith(
        rangedProfile: waffe.rangedProfile.copyWith(selectedProjectileIndex: 1),
      ),
    );
    final p = pruefeGefechtAuftrag(s, geaendert, testCatalog, a);
    expect(
      p.fehlendeAngaben.join(' '),
      contains('bezahlte zusätzliche Zielaktionen'),
    );
    expect(
      snap
          .hero
          .combatConfig
          .selectedWeapon
          .rangedProfile
          .selectedProjectileOrNull!
          .id,
      'p1',
    );
    final bezahlt = pruefeGefechtAuftrag(s, snap, testCatalog, a);
    expect(
      bezahlt.fehlendeAngaben.join(' '),
      isNot(contains('bezahlte zusätzliche Zielaktionen')),
    );
    final unbezahlt = pruefeGefechtAuftrag(
      s.copyWith(ohneZielstand: true),
      snap,
      testCatalog,
      a,
    );
    expect(
      unbezahlt.fehlendeAngaben.join(' '),
      contains('bezahlte zusätzliche Zielaktionen'),
    );
  });
  test(
    'Getrennte Finte und Wuchtschlag addieren nur ihre eigenen Zuschläge',
    () {
      final snap = ansageSnapshot(sf: true);
      const s = Gefechtszustand(iniWurf: 6, dk: 'N');
      final basis = pruefeGefechtAuftrag(s, snap, testCatalog, _auftrag());
      final p = pruefeGefechtAuftrag(
        s,
        snap,
        testCatalog,
        _auftrag(finte: 3, wucht: 4, zuschlag: 2),
      );
      expect(p.zielwert, basis.zielwert! - 9);
      expect(p.modifikatoren.where((m) => m.name == 'Finte').single.wert, 3);
      expect(
        p.modifikatoren.where((m) => m.name == 'Wuchtschlag').single.wert,
        4,
      );
      final effekt = gefechtsAnsagewirkung(
        snap,
        testCatalog,
        _auftrag(finte: 3, wucht: 4),
      );
      expect(effekt.abwehrmalus, 3);
      expect(effekt.tpBonus, 4);
    },
  );
  test('Ohne SF wirkt die aufgerundete halbe Ansage mit Erklärung', () {
    final snap = ansageSnapshot();
    final a = _auftrag(finte: 5, wucht: 5);
    final effekt = gefechtsAnsagewirkung(snap, testCatalog, a);
    expect(effekt.abwehrmalus, 3);
    expect(effekt.tpBonus, 3);
    final p = pruefeGefechtAuftrag(
      const Gefechtszustand(iniWurf: 6, dk: 'N'),
      snap,
      testCatalog,
      a,
    );
    expect(p.sperrgruende, isEmpty);
    expect(p.hinweise.join(' '), contains('halbe'));
  });
  test('Waffenverbote und gemeinsame TaW-Grenze werden hart gesperrt', () {
    final s = const Gefechtszustand(iniWurf: 6, dk: 'N');
    final p = pruefeGefechtAuftrag(
      s,
      ansageSnapshot(talent: 'tal_kettenwaffen'),
      testCatalog,
      _auftrag(finte: 1),
    );
    expect(p.sperrgruende.join(' '), contains('Finte'));
    final q = pruefeGefechtAuftrag(
      s,
      ansageSnapshot(sf: true),
      testCatalog,
      _auftrag(finte: 9, wucht: 9),
    );
    expect(q.sperrgruende.join(' '), contains('Ansagegrenze'));
  });
  test('Sturmangriff erlaubt beide Ansagen, unbekannte Kombination bleibt Entscheidung', () {
    expect(
      gefechtsAnsagekombination(
        'man_sturmangriff',
        finte: true,
        wuchtschlag: true,
      ),
      GefechtsAnsagekombination.erlaubt,
    );
    expect(
      gefechtsAnsagekombination(
        'man_klingensturm',
        finte: true,
        wuchtschlag: true,
      ),
      GefechtsAnsagekombination.verboten,
    );
    const m = ManeuverDef(
      id: 'man_unbekannt',
      name: 'Unbekannt',
      typ: 'Angriffsmanöver',
    );
    final p = pruefeGefechtAuftrag(
      const Gefechtszustand(iniWurf: 6, dk: 'N'),
      ansageSnapshot(),
      testCatalog,
      _auftrag(finte: 1, m: m),
    );
    expect(p.entscheidungen.join(' '), contains('Kombination'));
  });
  test('FK-Ansage bezahlt normale und SF-Zieldauer unabhängig von TP', () {
    final normal = gefechtsFernkampfansage(5, taw: 10, fk: 16);
    expect(normal.tpBonus, 3);
    expect(normal.zielaktionen, 3);
    expect(normal.grenze, 10);
    final scharf = gefechtsFernkampfansage(
      7,
      taw: 10,
      fk: 16,
      scharfschuetze: true,
    );
    expect(scharf.tpBonus, 7);
    expect(scharf.zielaktionen, 2);
    final meister = gefechtsFernkampfansage(
      15,
      taw: 10,
      fk: 16,
      meisterschuetze: true,
    );
    expect(meister.tpBonus, 15);
    expect(meister.zielaktionen, 1);
    expect(meister.grenze, 16);
  });
  test(
    'Sturmangriff addiert feste +4 und beide Ansagen einmal, bezahlt auch PA',
    () {
      const m = ManeuverDef(
        id: 'man_sturmangriff',
        name: 'Sturmangriff',
        typ: 'Angriffsmanöver',
        erschwernis: 'Angriff +4',
      );
      final snap = ansageSnapshot(sf: true);
      const s = Gefechtszustand(iniWurf: 6, dk: 'N');
      final normal = pruefeGefechtAuftrag(s, snap, testCatalog, _auftrag());
      final a = _auftrag(m: m, finte: 3, wucht: 4, zuschlag: 2);
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      expect(p.sperrgruende, isEmpty);
      expect(p.zielwert, normal.zielwert! - 13);
      expect(p.angriffe, 1);
      expect(p.paraden, 1);
      expect(p.entscheidungen.join(' '), contains('4 Schritt'));
      expect(gefechtsAnsagewirkung(snap, testCatalog, a).tpBonus, 12);
      final gesperrt = pruefeGefechtAuftrag(
        s.copyWith(paradenVerbraucht: 1),
        snap,
        testCatalog,
        a,
      );
      expect(gesperrt.sperrgruende.join(' '), contains('Abwehraktion'));
    },
  );
  test('Schild und Waffenmeister gelten bei primärer oder zusätzlicher Finte einmal', () {
    final basis = ansageSnapshot(sf: true);
    final config = basis.hero.combatConfig.copyWith(
      weapons: [
        basis.hero.combatConfig.selectedWeapon.copyWith(weaponType: 'Schwert'),
      ],
      offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
      offhandEquipment: const [
        OffhandEquipmentEntry(
          id: 's',
          name: 'Schild',
          type: OffhandEquipmentType.shield,
          shieldSize: ShieldSize.large,
        ),
      ],
      waffenmeisterschaften: const [
        WaffenmeisterConfig(
          talentId: 'tal_schwerter',
          weaponType: 'Schwert',
          bonuses: [
            WaffenmeisterBonus(
              type: WaffenmeisterBonusType.maneuverReduction,
              targetManeuver: 'man_finte',
              value: 2,
            ),
          ],
        ),
      ],
    );
    final snap = buildHeroComputedSnapshot(
      hero: basis.hero.copyWith(combatConfig: config),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    const s = Gefechtszustand(iniWurf: 6, dk: 'N');
    const m = ManeuverDef(
      id: 'man_finte',
      name: 'Finte',
      typ: 'Angriffsmanöver',
    );
    final normal = pruefeGefechtAuftrag(s, snap, testCatalog, _auftrag());
    final direkt = pruefeGefechtAuftrag(
      s,
      snap,
      testCatalog,
      _auftrag(finte: 3, wucht: 4, m: m),
    );
    final kombiniert = pruefeGefechtAuftrag(
      s,
      snap,
      testCatalog,
      _auftrag(finte: 3, wucht: 4),
    );
    expect(direkt.zielwert, normal.zielwert! - 7);
    expect(kombiniert.zielwert, direkt.zielwert);
  });
}
