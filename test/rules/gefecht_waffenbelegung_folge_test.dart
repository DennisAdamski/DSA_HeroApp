import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zusatz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

const _dolch = MainWeaponSlot(id: 'dolch', name: 'Dolch');

void main() {
  test('Historische Armbrust mit Schild lässt keine SK-II-Restmarke übrig', () {
    final snap = buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: const CombatConfig(
          weapons: [
            MainWeaponSlot(id: 'w', name: 'Armbrust', talentId: 'tal_armbrust'),
          ],
          offhandEquipment: [
            OffhandEquipmentEntry(
              id: 's',
              name: 'Schild',
              type: OffhandEquipmentType.shield,
            ),
          ],
          offhandAssignment: OffhandAssignment(equipmentIndex: 0),
          specialRules: CombatSpecialRules(schildkampfII: true),
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    expect(gefechtsZusatzoptionen(snap).single.verfuegbar, false);
    expect(gefechtswerteFuer(snap).zusatzaktionen, 0);
  });
  for (final w in [
    const MainWeaponSlot(id: 'bow', name: 'Erbstück', talentId: 'tal_boegen'),
    const MainWeaponSlot(
      id: 'crossbow',
      name: 'Erbstück',
      talentId: 'tal_armbrust',
    ),
    const MainWeaponSlot(
      id: 'type',
      name: 'Balestrina',
      weaponType: 'Schwere Armbrust',
    ),
    const MainWeaponSlot(id: 'arbal', weaponType: 'Arbalette'),
  ]) {
    test('Historische Standardbelegung ${w.id} erzwingt beide Hände', () {
      final config = CombatConfig(
        weapons: [w, _dolch],
        offhandAssignment: const OffhandAssignment(weaponIndex: 1),
      );
      expect(gefechtsHandbelegung(config), contains('beide Hände'));
      expect(
        () => mitGefechtsHandbelegung(
          config,
          GefechtsHand.nebenhand,
          waffe: _dolch,
        ),
        throwsStateError,
      );
      expect(
        () => mitGefechtsHandbelegung(config, GefechtsHand.haupthand, waffe: w),
        throwsStateError,
      );
      final snap = buildHeroComputedSnapshot(
        hero: testHero().copyWith(combatConfig: config),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      expect(
        gefechtsKampfmittelprofile(snap).every((p) => p.sperren.isNotEmpty),
        true,
      );
      expect(gefechtsZusatzoptionen(snap).any((o) => o.verfuegbar), false);
      final cleared = mitGefechtsHandbelegung(config, GefechtsHand.nebenhand);
      expect(cleared.selectedWeapon.id, w.id);
      expect(cleared.selectedWeapon.isOneHanded, true);
    });
  }
  test('Bekannte Balestrina bleibt einhändig trotz anderem Anzeigenamen', () {
    const w = MainWeaponSlot(
      id: 'balestrina',
      name: 'Erbstück',
      weaponType: 'Balestrina',
      talentId: 'tal_armbrust',
      isOneHanded: false,
      unbekannteFelder: {'future': 7},
    );
    final c = mitGefechtsHandbelegung(
      const CombatConfig(weapons: [w, _dolch]),
      GefechtsHand.nebenhand,
      waffe: _dolch,
    );
    expect(c.offhandAssignment.usesWeapon, true);
    expect(c.selectedWeapon.isOneHanded, false);
    expect(c.selectedWeapon.unbekannteFelder['future'], 7);
    expect(gefechtsHandbelegung(c), 'Erbstück · Dolch');
  });
  test('Wurfwaffen und unbekannte Waffen behalten ihre Metadaten', () {
    for (final talent in ['tal_wurfmesser', 'tal_wurfbeile', 'future']) {
      for (final oneHanded in [true, false]) {
        final w = MainWeaponSlot(
          id: 'w',
          name: 'Bogen',
          talentId: talent,
          isOneHanded: oneHanded,
        );
        final c = CombatConfig(weapons: [w, _dolch]);
        expect(gefechtsHandbelegung(c).contains('beide Hände'), !oneHanded);
      }
    }
  });
  test(
    'Historischer Bogen darf auch als Nebenhandwaffe nicht zugewiesen werden',
    () {
      const w = MainWeaponSlot(id: 'w', talentId: 'tal_boegen');
      expect(
        () => mitGefechtsHandbelegung(
          const CombatConfig(weapons: [_dolch, w]),
          GefechtsHand.nebenhand,
          waffe: w,
        ),
        throwsStateError,
      );
    },
  );
}
