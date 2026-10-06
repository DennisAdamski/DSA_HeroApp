import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ansage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ladezustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_slot_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';

// Verweis Slot → Instanz (ARCH-03): `bindeSlotsAnInstanzen` setzt ihn, der
// Abgleich ordnet über ihn zuerst zu.

// Verknüpfter Dolch-Eintrag; [beschreibung] dient als Kennung im Test.
HeroInventoryEntry _dolch(
  String beschreibung, {
  String? instanzId,
  String? slotRef,
}) {
  return HeroInventoryEntry(
    gegenstand: 'Dolch',
    source: InventoryItemSource.waffe,
    sourceRef: 'w:Dolch',
    slotRef: slotRef,
    instanzId: instanzId,
    beschreibung: beschreibung,
  );
}

const _vollerKampf = CombatConfig(
  weapons: [
    MainWeaponSlot(
      id: 'w1',
      name: 'Kurzbogen',
      combatType: WeaponCombatType.ranged,
      rangedProfile: RangedWeaponProfile(
        projectiles: [RangedProjectile(id: 'p1', name: 'Pfeil', count: 12)],
      ),
    ),
    MainWeaponSlot(), // unbenannt: kein Eintrag, kein Verweis
  ],
  armor: ArmorConfig(
    pieces: [ArmorPiece(id: 'a1', name: 'Helm')],
  ),
  offhandEquipment: [OffhandEquipmentEntry(id: 'oh1', name: 'Schild')],
);

// Abgleich und Instanzvergabe wie in `saveHero`, mit fortlaufenden IDs.
List<HeroInventoryEntry> _gespeichert(
  CombatConfig kampf, [
  List<HeroInventoryEntry> bisher = const [],
]) {
  var n = 0;
  return vergibInstanzIds(
    reconcileInventoryWithCombat(bisher, kampf),
    neueId: () => 'neu${++n}',
  );
}

void main() {
  group('bindeSlotsAnInstanzen', () {
    test('setzt die Instanz an Waffe, Geschoss, Rüstung und Nebenhand', () {
      final eintraege = _gespeichert(_vollerKampf);
      final gebunden = bindeSlotsAnInstanzen(_vollerKampf, eintraege);

      String instanzVon(String slotRef) =>
          eintraege.singleWhere((e) => e.slotRef == slotRef).instanzId!;
      final bogen = gebunden.weapons[0];
      expect(bogen.inventarInstanzId, instanzVon('w#w1'));
      expect(
        bogen.rangedProfile.projectiles.single.inventarInstanzId,
        instanzVon('w#w1|p#p1'),
      );
      expect(gebunden.weapons[1].inventarInstanzId, isEmpty);
      expect(
        gebunden.armor.pieces.single.inventarInstanzId,
        instanzVon('a#a1'),
      );
      expect(
        gebunden.offhandEquipment.single.inventarInstanzId,
        instanzVon('oh#oh1'),
      );
      // Die aktive Waffe wird im JSON gespiegelt und trägt ihn mit.
      expect(
        gebunden.toJson()['mainWeapon']['inventarInstanzId'],
        instanzVon('w#w1'),
      );
    });

    test('ist ein Fixpunkt', () {
      final eintraege = _gespeichert(_vollerKampf);
      final gebunden = bindeSlotsAnInstanzen(_vollerKampf, eintraege);

      expect(
        identical(bindeSlotsAnInstanzen(gebunden, eintraege), gebunden),
        isTrue,
      );
    });

    test('ohne Eintrag verliert ein Slot seinen veralteten Verweis', () {
      const kampf = CombatConfig(
        weapons: [MainWeaponSlot(name: '', inventarInstanzId: 'alt')],
      );

      final gebunden = bindeSlotsAnInstanzen(kampf, const []);

      expect(gebunden.weapons.single.inventarInstanzId, isEmpty);
    });

    test('manuelle Einträge binden keinen Slot', () {
      const kampf = CombatConfig(
        weapons: [MainWeaponSlot(id: 'w1', name: 'Dolch')],
      );
      const manuell = HeroInventoryEntry(
        gegenstand: 'Dolch',
        slotRef: 'w#w1',
        instanzId: 'x',
      );

      expect(identical(bindeSlotsAnInstanzen(kampf, [manuell]), kampf), isTrue);
    });
  });

  group('Abgleich: Instanz zuerst', () {
    const zweiDolche = CombatConfig(
      weapons: [
        MainWeaponSlot(id: 'a', name: 'Dolch', inventarInstanzId: 'ia'),
        MainWeaponSlot(id: 'b', name: 'Dolch', inventarInstanzId: 'ib'),
      ],
    );

    test('ohne slotRef entscheidet die Instanz, nicht die Reihenfolge', () {
      final ergebnis = reconcileInventoryWithCombat([
        _dolch('B', instanzId: 'ib'),
        _dolch('A', instanzId: 'ia'),
      ], zweiDolche);

      expect(ergebnis.map((e) => e.beschreibung), ['A', 'B']);
      expect(ergebnis.map((e) => e.slotRef), ['w#a', 'w#b']);
    });

    test('ein Eintrag mit veraltetem slotRef folgt seiner Instanz', () {
      const neueId = CombatConfig(
        weapons: [
          MainWeaponSlot(id: 'c', name: 'Dolch', inventarInstanzId: 'ia'),
        ],
      );

      final ergebnis = reconcileInventoryWithCombat([
        _dolch('A', instanzId: 'ia', slotRef: 'w#a'),
      ], neueId);

      expect(ergebnis.single.beschreibung, 'A');
      expect(ergebnis.single.instanzId, 'ia');
      expect(ergebnis.single.slotRef, 'w#c');
    });

    test('ein Eintrag eines anderen bestehenden Slots bleibt dort', () {
      // Slot a verweist veraltet auf die Instanz von b.
      const veraltet = CombatConfig(
        weapons: [
          MainWeaponSlot(id: 'a', name: 'Dolch', inventarInstanzId: 'ib'),
          MainWeaponSlot(id: 'b', name: 'Dolch', inventarInstanzId: 'ib'),
        ],
      );

      final ergebnis = reconcileInventoryWithCombat([
        _dolch('A', instanzId: 'ia', slotRef: 'w#a'),
        _dolch('B', instanzId: 'ib', slotRef: 'w#b'),
      ], veraltet);

      expect(ergebnis.map((e) => e.beschreibung), ['A', 'B']);
      expect(ergebnis.map((e) => e.instanzId), ['ia', 'ib']);
    });

    test('eine Kopie vor ihrem Vorbild bekommt ein eigenes Exemplar', () {
      // Die Kopie trägt die Instanz ihres Vorbilds, aber keinen Eintrag.
      const mitKopie = CombatConfig(
        weapons: [
          MainWeaponSlot(id: 'k', name: 'Dolch', inventarInstanzId: 'ia'),
          MainWeaponSlot(id: 'a', name: 'Dolch', inventarInstanzId: 'ia'),
        ],
      );

      final ergebnis = reconcileInventoryWithCombat([
        _dolch('A', instanzId: 'ia', slotRef: 'w#a'),
      ], mitKopie);

      expect(ergebnis.map((e) => e.beschreibung), ['', 'A']);
      expect(ergebnis.map((e) => e.instanzId), [null, 'ia']);
      expect(ergebnis.map((e) => e.slotRef), ['w#k', 'w#a']);
    });

    test('zwei Slots mit derselben Instanz teilen kein Exemplar', () {
      const doppelt = CombatConfig(
        weapons: [
          MainWeaponSlot(id: 'a', name: 'Dolch', inventarInstanzId: 'ia'),
          MainWeaponSlot(id: 'k', name: 'Dolch', inventarInstanzId: 'ia'),
        ],
      );

      final ergebnis = reconcileInventoryWithCombat([
        _dolch('A', instanzId: 'ia'),
      ], doppelt);

      expect(ergebnis.map((e) => e.beschreibung), ['A', '']);
      expect(ergebnis.map((e) => e.instanzId), ['ia', null]);
    });

    test('die Instanz gilt nur für dieselbe Quelle', () {
      const helm = CombatConfig(
        armor: ArmorConfig(
          pieces: [ArmorPiece(id: 'h', name: 'Helm', inventarInstanzId: 'x')],
        ),
      );

      final ergebnis = reconcileInventoryWithCombat([
        _dolch('Dolch', instanzId: 'x'),
      ], helm);

      expect(ergebnis.single.source, InventoryItemSource.ruestung);
      expect(ergebnis.single.instanzId, isNull);
    });

    test('ein neuer Eintrag übernimmt die Instanz des Slots nicht', () {
      final ergebnis = reconcileInventoryWithCombat(const [], zweiDolche);

      expect(ergebnis.map((e) => e.instanzId), [null, null]);
    });

    test('Markierungen gehen über dieselbe Paarung an den Slot', () {
      final kampf = applyLinkedInventoryDetailsToConfig(zweiDolche, [
        _dolch('B', instanzId: 'ib').copyWith(isMagisch: true),
        _dolch('A', instanzId: 'ia'),
      ]);

      expect(kampf.weapons.map((w) => w.isArtifact), [false, true]);
    });
  });

  test('ohneInstanzverweise entfernt den Verweis auf jeder Ebene', () {
    final gebunden = bindeSlotsAnInstanzen(
      _vollerKampf,
      _gespeichert(_vollerKampf),
    );

    expect(
      ohneInstanzverweise(gebunden.weapons[0].toJson()),
      _vollerKampf.weapons[0].toJson(),
    );
  });

  test('Gefechtsprofile binden die Waffe, nicht den Instanzverweis', () {
    // Ein Ladezustand vor dem ersten Speichern gilt danach weiter.
    final vorher = _vollerKampf.weapons[0];
    final gebunden = bindeSlotsAnInstanzen(
      _vollerKampf,
      _gespeichert(_vollerKampf),
    ).weapons[0];

    expect(gefechtsLadeprofilKey(gebunden), gefechtsLadeprofilKey(vorher));
    expect(gefechtsZielprofilKey(gebunden), gefechtsZielprofilKey(vorher));
  });
}
