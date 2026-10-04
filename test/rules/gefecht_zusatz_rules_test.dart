import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zusatz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

import '../ui2/shell/karto_test_support.dart';

const _kontext = Gefechtskontext(
  angriffsart: Gefechtsangriffsart.nahkampf,
  finte: 3,
  paradeVerboten: false,
  weitereRegelnGeprueft: true,
);
HeroComputedSnapshot _s({bool sf = true}) => buildHeroComputedSnapshot(
  hero: testHero().copyWith(
    combatConfig: CombatConfig(
      weapons: const [
        MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N'),
        MainWeaponSlot(id: 'b', name: 'Dolch', distanceClass: 'N'),
      ],
      offhandAssignment: const OffhandAssignment(weaponIndex: 1),
      specialRules: CombatSpecialRules(
        activeCombatSpecialAbilityIds: sf ? ['ksf_beidhaendiger_kampf_ii'] : [],
      ),
    ),
  ),
  state: const HeroState.empty(),
  catalog: testCatalog,
  epicAdvantagesActive: false,
);
GefechtAuftrag _auftrag(
  Gefechtsaktion a,
  GefechtsKampfmittelwahl w, {
  bool pa = false,
}) => GefechtAuftrag(
  aktion: a,
  titel: 'Test',
  zuschlag: 0,
  dk: 'N',
  dauer: 1,
  kosten: 1,
  kampfmittel: w,
  zusatzParade: pa,
  kontext: _kontext,
);

void main() {
  for (final schild in [false, true]) {
    test(
      'Zusatzparade Schild=$schild: Quelle, gemeinsames Budget und Rundenreset',
      () {
        final base = _s();
        final snap = buildHeroComputedSnapshot(
          hero: base.hero.copyWith(
            combatConfig: base.hero.combatConfig.copyWith(
              offhandEquipment: [
                OffhandEquipmentEntry(
                  id: 'p',
                  name: 'Abwehrmittel',
                  paMod: 3,
                  type: schild
                      ? OffhandEquipmentType.shield
                      : OffhandEquipmentType.parryWeapon,
                ),
              ],
              offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
              specialRules: const CombatSpecialRules(
                linkhandActive: true,
                parierwaffenII: true,
                schildkampfII: true,
              ),
            ),
          ),
          state: base.state,
          catalog: testCatalog,
          epicAdvantagesActive: false,
        );
        final option = gefechtsZusatzoptionen(snap).firstWhere((o) => o.parade);
        expect(option.verfuegbar, true);
        final w = gefechtswerteFuer(snap);
        var s = const Gefechtszustand(
          iniWurf: 6,
          dk: 'N',
          fixierterIniBonus: 2,
        );
        final regular = _auftrag(Gefechtsaktion.parade, option.kampfmittel);
        final rp = pruefeGefechtAuftrag(s, snap, testCatalog, regular);
        s = verbraucheGefechtsaktion(s, w, rp);
        expect(gefechtsRegulaereParaden(s), 0);
        expect(gefechtsParaden(s, w), 0);
        final extra = _auftrag(
          Gefechtsaktion.zusatzaktion,
          option.kampfmittel,
          pa: true,
        );
        final p = pruefeGefechtAuftrag(s, snap, testCatalog, extra);
        expect(p.status, isNot(Gefechtsfreigabe.gesperrt));
        expect(
          p.probenart,
          schild ? Gefechtsaktion.schildparade : Gefechtsaktion.parade,
        );
        s = verbraucheGefechtsaktion(s, w, p);
        expect(s.paradenVerbraucht, 1);
        expect(s.zusatzVerbraucht, 1);
        expect(
          pruefeGefechtAuftrag(s, snap, testCatalog, extra).status,
          Gefechtsfreigabe.gesperrt,
        );
        final neu = naechsteGefechtsrunde(s);
        expect(neu.regulaeresParadepaar, isNull);
        expect(
          pruefeGefechtAuftrag(neu, snap, testCatalog, extra).status,
          Gefechtsfreigabe.gesperrt,
        );
        if (schild) {
          final ohneWm = GefechtAuftrag(
            aktion: Gefechtsaktion.parade,
            titel: 'Kettenwaffe',
            zuschlag: 0,
            dk: 'N',
            dauer: 1,
            kosten: 1,
            kampfmittel: option.kampfmittel,
            kontext: _kontext.copyWith(schildWmWirksam: false),
          );
          final q = pruefeGefechtAuftrag(neu, snap, testCatalog, ohneWm);
          expect(
            q.zielwert,
            snap.combatPreviewStats.shieldPa - 3 + gefechtsIniBonus(neu, w) - 3,
          );
        } else {
          final ansage = s.copyWith(zusatzVerbraucht: 0, paradeMitAnsage: true);
          expect(
            pruefeGefechtAuftrag(ansage, snap, testCatalog, extra).status,
            Gefechtsfreigabe.gesperrt,
          );
        }
      },
    );
  }
  test('Konkrete Zusatzparade braucht passende reguläre Aktion; Zielwert ohne doppelten INI-Bonus', () {
    final snap = _s();
    final extra = gefechtsZusatzoptionen(snap).firstWhere((o) => o.parade);
    var s = const Gefechtszustand(iniWurf: 6, dk: 'N', fixierterIniBonus: 2);
    final auftrag = _auftrag(
      Gefechtsaktion.zusatzaktion,
      extra.kampfmittel,
      pa: true,
    );
    expect(
      pruefeGefechtAuftrag(s, snap, testCatalog, auftrag).status,
      Gefechtsfreigabe.gesperrt,
    );
    const haupt = GefechtsKampfmittelwahl(
      GefechtsKampfmittelArt.hauptwaffe,
      'a',
    );
    final p = pruefeGefechtAuftrag(
      s,
      snap,
      testCatalog,
      _auftrag(Gefechtsaktion.parade, haupt),
    );
    s = verbraucheGefechtsaktion(s, gefechtswerteFuer(snap), p);
    final q = pruefeGefechtAuftrag(s, snap, testCatalog, auftrag);
    expect(q.status, isNot(Gefechtsfreigabe.gesperrt));
    expect(q.zielwert, snap.combatPreviewStats.offhandPreview!.pa! + 2 - 3);
    expect(q.paraden, 0);
    expect(q.zusatz, 1);
    s = s.copyWith(kontext: _kontext.copyWith(schildWmWirksam: false));
    s = verbraucheGefechtsaktion(s, gefechtswerteFuer(snap), q);
    expect(s.kontext.finte, isNull);
    expect(s.kontext.paradeVerboten, isNull);
    expect(s.kontext.schildWmWirksam, isNull);
    expect(
      pruefeGefechtAuftrag(s, snap, testCatalog, auftrag).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
  test('Ohne SF kein Zusatzangriff; Waffenwechsel hebt vorherige Bindung nicht auf', () {
    final snap = _s();
    final extra = gefechtsZusatzoptionen(snap).firstWhere((o) => !o.parade);
    var s = const Gefechtszustand(iniWurf: 6, dk: 'N');
    const haupt = GefechtsKampfmittelwahl(
      GefechtsKampfmittelArt.hauptwaffe,
      'a',
    );
    s = verbraucheGefechtsaktion(
      s,
      gefechtswerteFuer(snap),
      pruefeGefechtAuftrag(
        s,
        snap,
        testCatalog,
        _auftrag(Gefechtsaktion.angriff, haupt),
      ),
    );
    final a = _auftrag(Gefechtsaktion.zusatzaktion, extra.kampfmittel);
    expect(
      pruefeGefechtAuftrag(s, _s(sf: false), testCatalog, a).status,
      Gefechtsfreigabe.gesperrt,
    );
    final neu = buildHeroComputedSnapshot(
      hero: snap.hero.copyWith(
        combatConfig: snap.hero.combatConfig.copyWith(
          weapons: [
            snap.hero.combatConfig.weaponSlots.first.copyWith(id: 'c'),
            snap.hero.combatConfig.weaponSlots.last,
          ],
        ),
      ),
      state: snap.state,
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    expect(
      pruefeGefechtAuftrag(s, neu, testCatalog, a).status,
      Gefechtsfreigabe.gesperrt,
    );
  });
}
