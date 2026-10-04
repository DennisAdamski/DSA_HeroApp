import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fernkampf_ladezeit_rules.dart';

void main() {
  test('Armbrust Schnellladen erhält gerundete drei Viertel der Basis', () {
    for (final eintrag in [(4, 3), (8, 6), (5, 4), (7, 5)]) {
      final r = computeRangedReloadTime(
        weapon: MainWeaponSlot(
          weaponType: 'Armbrust',
          rangedProfile: RangedWeaponProfile(reloadTime: eintrag.$1),
        ),
        specialRules: const CombatSpecialRules(
          activeManeuvers: ['man_schnellladen_armbrust'],
        ),
        axxeleratusActive: false,
        talentName: 'Armbrust',
      );
      expect(r.effectiveReloadTime, eintrag.$2);
      expect(r.displayLabel, '${eintrag.$2} Aktionen');
    }
  });
  test('Armbrust SF plus Axxeleratus und Waffenmeister zentral gerechnet', () {
    for (final eintrag in [(false, 1, 3), (true, 1, 2), (true, 2, 1)]) {
      final r = computeRangedReloadTime(
        weapon: const MainWeaponSlot(
          weaponType: 'Armbrust',
          rangedProfile: RangedWeaponProfile(reloadTime: 4),
        ),
        specialRules: const CombatSpecialRules(
          activeManeuvers: ['man_schnellladen_armbrust'],
        ),
        axxeleratusActive: eintrag.$1,
        talentName: 'Armbrust',
        reloadDivisor: eintrag.$2,
      );
      expect(r.effectiveReloadTime, eintrag.$3);
    }
  });
}
