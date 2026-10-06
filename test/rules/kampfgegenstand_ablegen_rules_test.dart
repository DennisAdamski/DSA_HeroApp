import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_slot_instanz_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfgegenstand_ablegen_rules.dart';

// Ablegen und Zurückholen von Kampfgegenständen (ARCH-03, Entscheidung vom
// 06.10.2026).

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  combatConfig: CombatConfig(
    weapons: [
      MainWeaponSlot(name: 'Schwert', tpFlat: 4, wmAt: 1),
      MainWeaponSlot(
        name: 'Kurzbogen',
        combatType: WeaponCombatType.ranged,
        tpFlat: 3,
        rangedProfile: RangedWeaponProfile(
          reloadTime: 2,
          projectiles: [
            RangedProjectile(name: 'Pfeil', count: 12, tpMod: 1),
            RangedProjectile(name: 'Jagdpfeil', count: 0),
          ],
        ),
      ),
    ],
    armor: ArmorConfig(
      pieces: [ArmorPiece(name: 'Helm', rs: 1, isActive: true)],
    ),
    offhandEquipment: [
      OffhandEquipmentEntry(
        name: 'Holzschild',
        type: OffhandEquipmentType.shield,
        paMod: 3,
      ),
    ],
  ),
);

// Normalisiert wie `saveHero`: IDs, Abgleich, Mengen, Instanzen, Bindung.
HeroSheet _gespeichert(HeroSheet held) {
  var n = 0;
  final kampf = held.combatConfig.withStableIds(neueId: () => 'id${++n}');
  final eintraege = vergibInstanzIds(
    ueberfuehreInventarMengen(
      reconcileInventoryWithCombat(held.inventoryEntries, kampf),
    ),
    neueId: () => 'inst${++n}',
  );
  return held.copyWith(
    combatConfig: bindeSlotsAnInstanzen(kampf, eintraege),
    inventoryEntries: eintraege,
  );
}

// Gespeicherter Held, dessen Schwert-Eintrag eine Beschreibung trägt.
HeroSheet _startheld() {
  final erst = _gespeichert(_held);
  final schwertRef = 'w#${erst.combatConfig.weapons[0].id}';
  return erst.copyWith(
    inventoryEntries: [
      for (final e in erst.inventoryEntries)
        e.slotRef == schwertRef
            ? e.copyWith(beschreibung: 'Erbstück', gewichtGramm: 1600)
            : e,
    ],
  );
}

String _neueId() => 'frisch';

HeroInventoryEntry _eintragMit(HeroSheet held, String instanzId) {
  return held.inventoryEntries.singleWhere((e) => e.instanzId == instanzId);
}

void main() {
  group('Waffe ablegen', () {
    test('das Exemplar bleibt mit Kampfwerten und Angaben im Inventar', () {
      final held = _startheld();
      final schwert = held.combatConfig.weapons[0];

      final abgelegt = _gespeichert(
        ohneWaffeImKampf(
          held,
          schwert,
          index: 0,
          wie: KampfgegenstandEntfernen.ablegen,
          neueId: _neueId,
        ),
      );

      expect(abgelegt.combatConfig.weapons.map((w) => w.name), ['Kurzbogen']);
      final eintrag = _eintragMit(abgelegt, schwert.inventarInstanzId);
      expect(eintrag.source, InventoryItemSource.manuell);
      expect(eintrag.sourceRef, isNull);
      expect(eintrag.slotRef, isNull);
      expect(eintrag.istAusgeruestet, isFalse);
      expect(eintrag.beschreibung, 'Erbstück');
      expect(eintrag.gewichtGramm, 1600);
      expect(eintrag.abgelegt!.waffe!.tpFlat, 4);
      expect(eintrag.abgelegt!.waffe!.wmAt, 1);
      expect(eintrag.abgelegt!.waffe!.inventarInstanzId, isEmpty);
      expect(istAbgelegterKampfgegenstand(eintrag), isTrue);
      expect(anzeigeQuelleImInventar(eintrag), InventoryItemSource.waffe);
    });

    test('ganz entfernt verschwindet der Eintrag', () {
      final held = _startheld();
      final schwert = held.combatConfig.weapons[0];

      final weg = _gespeichert(
        ohneWaffeImKampf(
          held,
          schwert,
          index: 0,
          wie: KampfgegenstandEntfernen.ganzEntfernen,
          neueId: _neueId,
        ),
      );

      expect(
        weg.inventoryEntries.where(
          (e) => e.instanzId == schwert.inventarInstanzId,
        ),
        isEmpty,
      );
    });

    test('ein Bogen legt seine Geschosse in jedem Fall ab, auch mit 0', () {
      final held = _startheld();
      final bogen = held.combatConfig.weapons[1];
      final [pfeil, jagdpfeil] = bogen.rangedProfile.projectiles;

      for (final wie in KampfgegenstandEntfernen.values) {
        final ohneBogen = _gespeichert(
          ohneWaffeImKampf(held, bogen, index: 1, wie: wie, neueId: _neueId),
        );

        final pfeile = _eintragMit(ohneBogen, pfeil.inventarInstanzId);
        expect(pfeile.menge, 12, reason: '$wie');
        expect(pfeile.abgelegt!.geschoss!.tpMod, 1, reason: '$wie');
        expect(anzeigeQuelleImInventar(pfeile), InventoryItemSource.geschoss);
        final leer = _eintragMit(ohneBogen, jagdpfeil.inventarInstanzId);
        expect(leer.menge, 0, reason: '$wie');
        expect(leer.anzahl, '0', reason: '$wie');
      }
    });

    test('ein abgelegter Bogen merkt sich keine Geschosse', () {
      final held = _startheld();
      final bogen = held.combatConfig.weapons[1];

      final ohneBogen = ohneWaffeImKampf(
        held,
        bogen,
        index: 1,
        wie: KampfgegenstandEntfernen.ablegen,
        neueId: _neueId,
      );

      final profil = _eintragMit(ohneBogen, bogen.inventarInstanzId).abgelegt!;
      expect(profil.waffe!.rangedProfile.projectiles, isEmpty);
      expect(profil.waffe!.rangedProfile.reloadTime, 2);
    });
  });

  group('Geschosse im Editor entfernt', () {
    test('abgelegt bleiben sie mit Menge im Inventar', () {
      final held = _startheld();
      final bogen = held.combatConfig.weapons[1];
      final pfeil = bogen.rangedProfile.projectiles[0];
      final ohnePfeil = bogen.copyWith(
        rangedProfile: bogen.rangedProfile.copyWith(
          projectiles: [bogen.rangedProfile.projectiles[1]],
        ),
      );

      expect(entfernteGeschosse(bogen, ohnePfeil).map((g) => g.name), [
        'Pfeil',
      ]);
      final ergebnis = _gespeichert(
        ersetzeWaffeImKampf(
          held,
          ausgang: bogen,
          neu: ohnePfeil,
          index: 1,
          geschosseAblegen: true,
          neueId: _neueId,
        ),
      );
      final eintrag = _eintragMit(ergebnis, pfeil.inventarInstanzId);
      expect(eintrag.menge, 12);
      expect(istAbgelegtesGeschoss(eintrag), isTrue);

      final ganz = _gespeichert(
        ersetzeWaffeImKampf(
          held,
          ausgang: bogen,
          neu: ohnePfeil,
          index: 1,
          geschosseAblegen: false,
          neueId: _neueId,
        ),
      );
      expect(
        ganz.inventoryEntries.where(
          (e) => e.instanzId == pfeil.inventarInstanzId,
        ),
        isEmpty,
      );
    });
  });

  group('Rüstung und Nebenhand', () {
    test('ablegen behält, ganz entfernen löscht', () {
      final held = _startheld();
      final helm = held.combatConfig.armor.pieces.single;
      final schild = held.combatConfig.offhandEquipment.single;

      final abgelegt = _gespeichert(
        ohneNebenhandteilImKampf(
          ohneRuestungsteilImKampf(
            held,
            helm,
            index: 0,
            wie: KampfgegenstandEntfernen.ablegen,
            neueId: _neueId,
          ),
          schild,
          index: 0,
          wie: KampfgegenstandEntfernen.ablegen,
          neueId: _neueId,
        ),
      );
      expect(abgelegt.combatConfig.armor.pieces, isEmpty);
      expect(abgelegt.combatConfig.offhandEquipment, isEmpty);
      final helmEintrag = _eintragMit(abgelegt, helm.inventarInstanzId);
      expect(helmEintrag.abgelegt!.ruestungsteil!.rs, 1);
      final schildEintrag = _eintragMit(abgelegt, schild.inventarInstanzId);
      expect(schildEintrag.abgelegt!.nebenhandteil!.paMod, 3);

      final weg = _gespeichert(
        ohneRuestungsteilImKampf(
          held,
          helm,
          index: 0,
          wie: KampfgegenstandEntfernen.ganzEntfernen,
          neueId: _neueId,
        ),
      );
      expect(
        weg.inventoryEntries.where(
          (e) => e.instanzId == helm.inventarInstanzId,
        ),
        isEmpty,
      );
    });
  });

  group('In Kampfbereich übernehmen', () {
    test('die Waffe kommt mit ihren Werten als dasselbe Exemplar zurück', () {
      final held = _startheld();
      final schwert = held.combatConfig.weapons[0];
      final abgelegt = _gespeichert(
        ohneWaffeImKampf(
          held,
          schwert,
          index: 0,
          wie: KampfgegenstandEntfernen.ablegen,
          neueId: _neueId,
        ),
      );
      // Im Inventar umbenannt, während es abgelegt war.
      final angezeigt = _eintragMit(
        abgelegt,
        schwert.inventarInstanzId,
      ).copyWith(gegenstand: 'Ahnenschwert');
      final umbenannt = abgelegt.copyWith(
        inventoryEntries: [
          for (final e in abgelegt.inventoryEntries)
            e.instanzId == angezeigt.instanzId ? angezeigt : e,
        ],
      );

      final zurueck = _gespeichert(
        mitUebernommenemKampfgegenstand(umbenannt, angezeigt, neueId: _neueId),
      );

      final waffe = zurueck.combatConfig.weapons.last;
      expect(waffe.name, 'Ahnenschwert');
      expect(waffe.tpFlat, 4);
      expect(waffe.wmAt, 1);
      expect(waffe.inventarInstanzId, schwert.inventarInstanzId);
      final eintrag = _eintragMit(zurueck, schwert.inventarInstanzId);
      expect(eintrag.source, InventoryItemSource.waffe);
      expect(eintrag.slotRef, 'w#${waffe.id}');
      expect(eintrag.abgelegt, isNull);
      expect(eintrag.beschreibung, 'Erbstück');
      expect(eintrag.gewichtGramm, 1600);
      expect(eintrag.istAusgeruestet, isTrue);
    });

    test('ein Geschoss kommt mit seiner Menge an die gewählte Waffe', () {
      final held = _startheld();
      final bogen = held.combatConfig.weapons[1];
      final pfeil = bogen.rangedProfile.projectiles[0];
      final ohnePfeil = _gespeichert(
        ersetzeWaffeImKampf(
          held,
          ausgang: bogen,
          neu: bogen.copyWith(
            rangedProfile: bogen.rangedProfile.copyWith(
              projectiles: [bogen.rangedProfile.projectiles[1]],
            ),
          ),
          index: 1,
          geschosseAblegen: true,
          neueId: _neueId,
        ),
      );
      final angezeigt = mitInventarMenge(
        _eintragMit(ohnePfeil, pfeil.inventarInstanzId),
        9,
      );
      final mitNeun = ohnePfeil.copyWith(
        inventoryEntries: [
          for (final e in ohnePfeil.inventoryEntries)
            e.instanzId == angezeigt.instanzId ? angezeigt : e,
        ],
      );

      expect(
        () => mitUebernommenemKampfgegenstand(
          mitNeun,
          angezeigt,
          neueId: _neueId,
        ),
        throwsStateError,
      );
      expect(zielwaffenFuerGeschoss(mitNeun.combatConfig).map((w) => w.id), [
        bogen.id,
      ]);
      final zurueck = _gespeichert(
        mitUebernommenemKampfgegenstand(
          mitNeun,
          angezeigt,
          zielWaffeId: bogen.id,
          neueId: _neueId,
        ),
      );

      final geschosse =
          zurueck.combatConfig.weapons[1].rangedProfile.projectiles;
      expect(geschosse.map((g) => g.name), ['Jagdpfeil', 'Pfeil']);
      expect(geschosse.last.count, 9);
      expect(geschosse.last.tpMod, 1);
      final eintrag = _eintragMit(zurueck, pfeil.inventarInstanzId);
      expect(eintrag.source, InventoryItemSource.geschoss);
      expect(eintrag.menge, 9);
    });

    test('ein inzwischen geänderter Eintrag wird nicht übernommen', () {
      final held = _startheld();
      final schwert = held.combatConfig.weapons[0];
      final abgelegt = ohneWaffeImKampf(
        held,
        schwert,
        index: 0,
        wie: KampfgegenstandEntfernen.ablegen,
        neueId: _neueId,
      );
      final angezeigt = _eintragMit(abgelegt, schwert.inventarInstanzId);
      final fremd = abgelegt.copyWith(
        inventoryEntries: [
          for (final e in abgelegt.inventoryEntries)
            e.instanzId == angezeigt.instanzId
                ? e.copyWith(beschreibung: 'anderswo geändert')
                : e,
        ],
      );

      expect(
        () =>
            mitUebernommenemKampfgegenstand(fremd, angezeigt, neueId: _neueId),
        throwsStateError,
      );
    });

    test(
      'ein manueller Eintrag ohne Kampfwerte lässt sich nicht übernehmen',
      () {
        const manuell = HeroInventoryEntry(gegenstand: 'Seil', instanzId: 's');
        final held = _held.copyWith(inventoryEntries: const [manuell]);

        expect(istAbgelegterKampfgegenstand(manuell), isFalse);
        expect(
          () => mitUebernommenemKampfgegenstand(held, manuell, neueId: _neueId),
          throwsStateError,
        );
      },
    );
  });
}
