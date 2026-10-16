import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';

const a = MainWeaponSlot(id: 'a', name: 'Schwert');
const b = MainWeaponSlot(
  id: 'b',
  name: 'Dolch',
  unbekannteFelder: {'future': 7},
);

void main() {
  test(
    'Nebenhand trifft stabile ID nach Verschiebung und erhält fremde Daten',
    () {
      const c = CombatConfig(
        weapons: [b, a],
        selectedWeaponIndex: 1,
        offhandAssignment: OffhandAssignment(unbekannteFelder: {'future': 42}),
      );
      final neu = mitGefechtsHandbelegung(c, GefechtsHand.nebenhand, waffe: b);
      expect(neu.selectedWeapon.id, 'a');
      expect(neu.offhandAssignment.weaponIndex, 0);
      expect(neu.offhandAssignment.unbekannteFelder['future'], 42);
      expect(neu.weaponSlots.first.unbekannteFelder['future'], 7);
    },
  );
  test(
    'Doppelbelegung und zweihändige Konflikte werden nicht normalisiert',
    () {
      const c = CombatConfig(weapons: [a, b]);
      expect(
        () => mitGefechtsHandbelegung(c, GefechtsHand.nebenhand, waffe: a),
        throwsStateError,
      );
      final belegt = mitGefechtsHandbelegung(
        c,
        GefechtsHand.nebenhand,
        waffe: b,
      );
      expect(
        () => mitGefechtsHandbelegung(belegt, GefechtsHand.haupthand, waffe: b),
        throwsStateError,
      );
      final z = c.copyWith(weapons: [a.copyWith(isOneHanded: false), b]);
      expect(
        () => mitGefechtsHandbelegung(z, GefechtsHand.nebenhand, waffe: b),
        throwsStateError,
      );
      expect(
        mitGefechtsHandbelegung(
          belegt,
          GefechtsHand.nebenhand,
        ).offhandAssignment.isNone,
        true,
      );
    },
  );
  test('Geänderte oder entfernte Zielwaffe benötigt neue Bestätigung', () {
    expect(
      () => mitGefechtsHandbelegung(
        CombatConfig(weapons: [a, b.copyWith(wmPa: 3)]),
        GefechtsHand.nebenhand,
        waffe: b,
      ),
      throwsStateError,
    );
    expect(
      () => mitGefechtsHandbelegung(
        const CombatConfig(weapons: [a]),
        GefechtsHand.nebenhand,
        waffe: b,
      ),
      throwsStateError,
    );
  });
  test('Der beim Speichern gesetzte Instanzverweis ist keine Änderung', () {
    // Angezeigt vor dem ersten Speichern, gespeichert danach (ARCH-03).
    final neu = mitGefechtsHandbelegung(
      CombatConfig(
        weapons: [
          a,
          b.copyWith(inventarInstanzId: 'i1'),
        ],
      ),
      GefechtsHand.nebenhand,
      waffe: b,
    );
    expect(neu.offhandAssignment.weaponIndex, 1);
  });
}
