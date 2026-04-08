import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_modifier_rules.dart';

HeroInventoryEntry _equippedItem(List<InventoryItemModifier> modifiers) {
  return HeroInventoryEntry(
    gegenstand: 'Testobjekt',
    itemType: InventoryItemType.ausruestung,
    istAusgeruestet: true,
    modifiers: modifiers,
  );
}

void main() {
  group('aggregateInventoryModifiers', () {
    test('leere Liste liefert Null-Aggregation', () {
      final result = aggregateInventoryModifiers([]);
      expect(result.statMods.gs, 0);
      expect(result.attributeMods.ge, 0);
      expect(result.talentMods, isEmpty);
    });

    test('stat-Modifikator gs wird korrekt aggregiert', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'gs',
            wert: 2,
          ),
        ]),
      ]);
      expect(result.statMods.gs, 2);
    });

    test('mehrere stat-Modifikatoren werden addiert', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'lep',
            wert: 5,
          ),
        ]),
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'lep',
            wert: 3,
          ),
        ]),
      ]);
      expect(result.statMods.lep, 8);
    });

    test('attribut-Modifikator ge wird korrekt aggregiert', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.attribut,
            targetId: 'ge',
            wert: 1,
          ),
        ]),
      ]);
      expect(result.attributeMods.ge, 1);
    });

    test('talent-Modifikator wird korrekt aggregiert', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.talent,
            targetId: 'tal_schleichen',
            wert: 3,
          ),
        ]),
      ]);
      expect(result.talentMods['tal_schleichen'], 3);
    });

    test('talent-Modifikatoren desselben Talents werden addiert', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.talent,
            targetId: 'tal_schleichen',
            wert: 3,
          ),
        ]),
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.talent,
            targetId: 'tal_schleichen',
            wert: 2,
          ),
        ]),
      ]);
      expect(result.talentMods['tal_schleichen'], 5);
    });

    test('nicht ausgeruestete Items werden ignoriert', () {
      final notEquipped = HeroInventoryEntry(
        gegenstand: 'Rucksack',
        itemType: InventoryItemType.ausruestung,
        istAusgeruestet: false,
        modifiers: const [
          InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'gs',
            wert: 10,
          ),
        ],
      );
      final result = aggregateInventoryModifiers([notEquipped]);
      expect(result.statMods.gs, 0);
    });

    test('Verbrauchsgegenstande werden ignoriert', () {
      final consumable = HeroInventoryEntry(
        gegenstand: 'Trank',
        itemType: InventoryItemType.verbrauchsgegenstand,
        istAusgeruestet: true,
        modifiers: const [
          InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'lep',
            wert: 10,
          ),
        ],
      );
      final result = aggregateInventoryModifiers([consumable]);
      expect(result.statMods.lep, 0);
    });

    test('unbekannter stat-Feldname wird ignoriert', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'nichtExistent',
            wert: 99,
          ),
        ]),
      ]);
      // Alle stat-Felder bleiben 0
      expect(result.statMods.gs, 0);
      expect(result.statMods.lep, 0);
    });

    test('negative Modifikatoren werden korrekt verarbeitet', () {
      final result = aggregateInventoryModifiers([
        _equippedItem([
          const InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'at',
            wert: -2,
          ),
        ]),
      ]);
      expect(result.statMods.at, -2);
    });

    test('talentgruppe-Modifikator wird auf alle Talente der Gruppe aufgeloest', () {
      final talents = [
        const TalentDef(
          id: 'tal_klettern',
          name: 'Klettern',
          group: 'Körperliche Talente',
          steigerung: 'B',
          attributes: ['MU', 'GE', 'KK'],
        ),
        const TalentDef(
          id: 'tal_koerperbeherrschung',
          name: 'Körperbeherrschung',
          group: 'Körperliche Talente',
          steigerung: 'D',
          attributes: ['MU', 'IN', 'GE'],
        ),
        const TalentDef(
          id: 'tal_menschenkenntnis',
          name: 'Menschenkenntnis',
          group: 'Gesellschaftliche Talente',
          steigerung: 'C',
          attributes: ['KL', 'IN', 'CH'],
        ),
      ];
      final result = aggregateInventoryModifiers(
        [
          _equippedItem([
            const InventoryItemModifier(
              kind: InventoryModifierKind.talentgruppe,
              targetId: 'Körperliche Talente',
              wert: 2,
            ),
          ]),
        ],
        talents: talents,
      );
      expect(result.talentMods['tal_klettern'], 2);
      expect(result.talentMods['tal_koerperbeherrschung'], 2);
      expect(result.talentMods.containsKey('tal_menschenkenntnis'), isFalse);
    });

    test('talentgruppe-Modifikator ohne passende Talente aendert nichts', () {
      final result = aggregateInventoryModifiers(
        [
          _equippedItem([
            const InventoryItemModifier(
              kind: InventoryModifierKind.talentgruppe,
              targetId: 'Unbekannte Gruppe',
              wert: 5,
            ),
          ]),
        ],
        talents: const [],
      );
      expect(result.talentMods, isEmpty);
    });

    test('talentgruppe und talent-Modifikatoren werden addiert', () {
      final talents = [
        const TalentDef(
          id: 'tal_klettern',
          name: 'Klettern',
          group: 'Körperliche Talente',
          steigerung: 'B',
          attributes: ['MU', 'GE', 'KK'],
        ),
      ];
      final result = aggregateInventoryModifiers(
        [
          _equippedItem([
            const InventoryItemModifier(
              kind: InventoryModifierKind.talentgruppe,
              targetId: 'Körperliche Talente',
              wert: 2,
            ),
            const InventoryItemModifier(
              kind: InventoryModifierKind.talent,
              targetId: 'tal_klettern',
              wert: 3,
            ),
          ]),
        ],
        talents: talents,
      );
      expect(result.talentMods['tal_klettern'], 5);
    });

    test('alle StatModifiers-Felder koennen gesetzt werden', () {
      final mods = <InventoryItemModifier>[
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'lep',
          wert: 1,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'au',
          wert: 2,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'asp',
          wert: 3,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'kap',
          wert: 4,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'mr',
          wert: 5,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'iniBase',
          wert: 6,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'at',
          wert: 7,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'pa',
          wert: 8,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'fk',
          wert: 9,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'gs',
          wert: 10,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'ausweichen',
          wert: 11,
        ),
        const InventoryItemModifier(
          kind: InventoryModifierKind.stat,
          targetId: 'rs',
          wert: 12,
        ),
      ];
      final result = aggregateInventoryModifiers([_equippedItem(mods)]);
      expect(result.statMods.lep, 1);
      expect(result.statMods.au, 2);
      expect(result.statMods.asp, 3);
      expect(result.statMods.kap, 4);
      expect(result.statMods.mr, 5);
      expect(result.statMods.iniBase, 6);
      expect(result.statMods.at, 7);
      expect(result.statMods.pa, 8);
      expect(result.statMods.fk, 9);
      expect(result.statMods.gs, 10);
      expect(result.statMods.ausweichen, 11);
      expect(result.statMods.rs, 12);
    });
  });
}
