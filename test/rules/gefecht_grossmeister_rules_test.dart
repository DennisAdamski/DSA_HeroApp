import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ansage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_grossmeister_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfwerte_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

// Epische Stufen S. 18: GE 21 mit Amazonensäbel (GE/INI 15/2) → 3 Punkte.
HeroComputedSnapshot _saebelmeister({bool geStattKk = false}) =>
    buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        attributes: testHero().attributes.copyWith(ge: 21, kk: 12),
        talents: {'tal_saebel': const HeroTalentEntry(talentValue: 24)},
        combatConfig: CombatConfig(
          weapons: const [
            MainWeaponSlot(
              id: 'a',
              name: 'Amazonensäbel',
              weaponType: 'Amazonensäbel',
              talentId: 'tal_saebel',
              distanceClass: 'N',
              kkBase: 11,
              kkThreshold: 4,
              wmAt: 10,
            ),
          ],
          specialRules: CombatSpecialRules(
            activeCombatSpecialAbilityIds: const ['esf_grossmeister_saebel'],
            activeManeuvers: const ['man_entwaffnen', 'man_wuchtschlag'],
            grossmeisterGeStattKk: geStattKk,
          ),
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );

GefechtAuftrag _entwaffnen(int pool) => GefechtAuftrag(
  aktion: Gefechtsaktion.angriff,
  titel: 'Entwaffnen',
  zuschlag: 0,
  dk: 'N',
  dauer: 1,
  kosten: 1,
  manoever: const ManeuverDef(
    id: 'man_entwaffnen',
    name: 'Entwaffnen',
    gruppe: 'bewaffnet',
    typ: 'Angriffsaktion',
    erschwernis: 'Angriff +8 +Ansage',
  ),
  grossmeisterPool: pool,
);

void main() {
  const s = Gefechtszustand(iniWurf: 4, dk: 'N');

  test('Säbel-Pool erleichtert Entwaffnen und wird für die KR verbraucht', () {
    final snap = _saebelmeister();
    expect(gefechtsGrossmeisterPoolFrei(s, snap), 3);
    final ohne = pruefeGefechtAuftrag(s, snap, testCatalog, _entwaffnen(0));
    final mit = pruefeGefechtAuftrag(s, snap, testCatalog, _entwaffnen(2));
    expect(ohne.zielwert, isNotNull, reason: ohne.gruende.join(' / '));
    expect(mit.zielwert, ohne.zielwert! + 2);
    expect(mit.grossmeisterPool, 2);
    expect(mit.modifikatoren.map((m) => m.name), contains('Säbel-Pool'));

    final w = gefechtswerteFuer(snap, katalog: testCatalog);
    final danach = verbraucheGefechtsaktion(s, w, mit);
    expect(gefechtsGrossmeisterPoolFrei(danach, snap), 1);
    final zuViel = pruefeGefechtAuftrag(
      danach,
      snap,
      testCatalog,
      _entwaffnen(2),
    );
    expect(zuViel.ausfuehrbar, isFalse);
    expect(
      gefechtsGrossmeisterPoolFrei(naechsteGefechtsrunde(danach), snap),
      3,
    );
  });

  test('Pool nicht für fremde Manöver', () {
    final snap = _saebelmeister();
    final p = pruefeGefechtAuftrag(
      s,
      snap,
      testCatalog,
      GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: 'AT',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        grossmeisterPool: 1,
      ),
    );
    expect(p.ausfuehrbar, isFalse);
  });

  test('GE statt KK: Wuchtschlag fällt auf den KK-Zuschlag zurück', () {
    final snap = _saebelmeister(geStattKk: true);
    final auftrag = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'AT',
      zuschlag: 0,
      wuchtschlag: 2,
      dk: 'N',
      dauer: 1,
      kosten: 1,
    );
    // TP/KK mit GE +2, mit KK +0 → Wuchtschlag +2 wirkt netto +0.
    expect(gefechtsAnsagewirkung(snap, testCatalog, auftrag).tpBonus, 0);
    expect(
      gefechtsAnsagewirkung(_saebelmeister(), testCatalog, auftrag).tpBonus,
      2,
    );
  });

  test('Kampfwertleiste zeigt den freien Pool', () {
    final werte = gefechtsKampfwerte(s, _saebelmeister(), testCatalog);
    final gm = werte.firstWhere((w) => w.id == 'grossmeister');
    expect(gm.anzeige, '3/3');
    expect(gm.titel, 'Waffen-Großmeister (Säbel)');
  });
}
