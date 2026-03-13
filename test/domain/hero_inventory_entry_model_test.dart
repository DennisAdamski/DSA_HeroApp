import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

void main() {
  group('HeroInventoryEntry – Roundtrip', () {
    test('alle neuen Felder werden korrekt serialisiert und deserialisiert', () {
      final entry = HeroInventoryEntry(
        gegenstand: 'Jaegerstiefel',
        beschreibung: 'Robuste Lederstiefel',
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.manuell,
        sourceRef: null,
        istAusgeruestet: true,
        modifiers: const [
          InventoryItemModifier(
            kind: InventoryModifierKind.stat,
            targetId: 'gs',
            wert: 2,
            beschreibung: 'Jaegerstiefel',
          ),
          InventoryItemModifier(
            kind: InventoryModifierKind.talent,
            targetId: 'tal_schleichen',
            wert: 3,
          ),
        ],
        gewichtGramm: 800,
        wertSilber: 15,
        herkunft: 'Haendler in Ferdok',
      );

      final json = entry.toJson();
      final reloaded = HeroInventoryEntry.fromJson(json);

      expect(reloaded.gegenstand, 'Jaegerstiefel');
      expect(reloaded.beschreibung, 'Robuste Lederstiefel');
      expect(reloaded.itemType, InventoryItemType.ausruestung);
      expect(reloaded.source, InventoryItemSource.manuell);
      expect(reloaded.sourceRef, isNull);
      expect(reloaded.istAusgeruestet, isTrue);
      expect(reloaded.modifiers.length, 2);
      expect(reloaded.modifiers[0].kind, InventoryModifierKind.stat);
      expect(reloaded.modifiers[0].targetId, 'gs');
      expect(reloaded.modifiers[0].wert, 2);
      expect(reloaded.modifiers[1].kind, InventoryModifierKind.talent);
      expect(reloaded.modifiers[1].targetId, 'tal_schleichen');
      expect(reloaded.gewichtGramm, 800);
      expect(reloaded.wertSilber, 15);
      expect(reloaded.herkunft, 'Haendler in Ferdok');
    });

    test('sourceRef wird korrekt gesetzt und gelesen', () {
      final entry = HeroInventoryEntry(
        gegenstand: 'Langschwert',
        source: InventoryItemSource.waffe,
        sourceRef: 'w:Langschwert',
        itemType: InventoryItemType.ausruestung,
        istAusgeruestet: true,
      );

      final reloaded = HeroInventoryEntry.fromJson(entry.toJson());
      expect(reloaded.sourceRef, 'w:Langschwert');
      expect(reloaded.source, InventoryItemSource.waffe);
    });
  });

  group('HeroInventoryEntry.fromJson – Abwaertskompatibilitaet', () {
    test('altes Schema ohne neue Felder liefert korrekte Standardwerte', () {
      final oldJson = const <String, dynamic>{
        'gegenstand': 'Schwert',
        'woGetragen': 'Guertel',
        'typ': '',
        'welchesAbenteuer': '',
        'gewicht': '1500',
        'wert': '25',
        'artefakt': '',
        'anzahl': '1',
        'amKoerper': 'ja',
        'woDann': '',
        'gruppe': '',
        'beschreibung': '',
      };

      final entry = HeroInventoryEntry.fromJson(oldJson);

      expect(entry.itemType, InventoryItemType.sonstiges);
      expect(entry.source, InventoryItemSource.manuell);
      expect(entry.sourceRef, isNull);
      expect(entry.istAusgeruestet, isFalse);
      expect(entry.modifiers, isEmpty);
      expect(entry.gewichtGramm, 0);
      expect(entry.wertSilber, 0);
      expect(entry.herkunft, '');
      // Alte String-Felder unveraendert
      expect(entry.gegenstand, 'Schwert');
      expect(entry.gewicht, '1500');
    });

    test('unbekannter itemType-String faellt auf sonstiges zurueck', () {
      final json = const <String, dynamic>{
        'gegenstand': 'Unbekannt',
        'itemType': 'kompletterUnsinn',
      };
      final entry = HeroInventoryEntry.fromJson(json);
      expect(entry.itemType, InventoryItemType.sonstiges);
    });

    test('unbekannter source-String faellt auf manuell zurueck', () {
      final json = const <String, dynamic>{
        'source': 'nichtExistent',
      };
      final entry = HeroInventoryEntry.fromJson(json);
      expect(entry.source, InventoryItemSource.manuell);
    });

    test('altes JSON ohne traegerTyp deserialisiert als held', () {
      final json = const <String, dynamic>{'gegenstand': 'Schwert'};
      final entry = HeroInventoryEntry.fromJson(json);
      expect(entry.traegerTyp, InventoryTraeger.held);
      expect(entry.traegerId, isNull);
    });

    test('unbekannter traegerTyp-String faellt auf held zurueck', () {
      final json = const <String, dynamic>{'traegerTyp': 'nichtExistent'};
      final entry = HeroInventoryEntry.fromJson(json);
      expect(entry.traegerTyp, InventoryTraeger.held);
    });
  });

  group('InventoryTraeger – Roundtrip', () {
    test('Träger Held wird korrekt serialisiert', () {
      const entry = HeroInventoryEntry(
        gegenstand: 'Rucksack',
        traegerTyp: InventoryTraeger.held,
      );
      final json = entry.toJson();
      final restored = HeroInventoryEntry.fromJson(json);
      expect(restored.traegerTyp, InventoryTraeger.held);
      expect(restored.traegerId, isNull);
    });

    test('Träger Begleiter mit ID wird korrekt serialisiert', () {
      const entry = HeroInventoryEntry(
        gegenstand: 'Satteltasche',
        traegerTyp: InventoryTraeger.begleiter,
        traegerId: 'companion-uuid-42',
      );
      final json = entry.toJson();
      expect(json['traegerTyp'], 'begleiter');
      expect(json['traegerId'], 'companion-uuid-42');

      final restored = HeroInventoryEntry.fromJson(json);
      expect(restored.traegerTyp, InventoryTraeger.begleiter);
      expect(restored.traegerId, 'companion-uuid-42');
    });

    test('copyWith aendert Traeger auf Begleiter', () {
      const entry = HeroInventoryEntry(gegenstand: 'Proviant');
      final updated = entry.copyWith(
        traegerTyp: InventoryTraeger.begleiter,
        traegerId: 'comp-1',
      );
      expect(updated.traegerTyp, InventoryTraeger.begleiter);
      expect(updated.traegerId, 'comp-1');
    });

    test('copyWith setzt traegerId auf null zurueck', () {
      const entry = HeroInventoryEntry(
        gegenstand: 'Schatz',
        traegerTyp: InventoryTraeger.begleiter,
        traegerId: 'comp-1',
      );
      final updated = entry.copyWith(
        traegerTyp: InventoryTraeger.held,
        traegerId: null,
      );
      expect(updated.traegerTyp, InventoryTraeger.held);
      expect(updated.traegerId, isNull);
    });
  });

  group('InventoryItemModifier – Roundtrip', () {
    test('stat-Modifikator wird korrekt serialisiert', () {
      const mod = InventoryItemModifier(
        kind: InventoryModifierKind.stat,
        targetId: 'lep',
        wert: -2,
        beschreibung: 'Fluch',
      );
      final reloaded = InventoryItemModifier.fromJson(mod.toJson());
      expect(reloaded.kind, InventoryModifierKind.stat);
      expect(reloaded.targetId, 'lep');
      expect(reloaded.wert, -2);
      expect(reloaded.beschreibung, 'Fluch');
    });

    test('attribut-Modifikator wird korrekt serialisiert', () {
      const mod = InventoryItemModifier(
        kind: InventoryModifierKind.attribut,
        targetId: 'ge',
        wert: 1,
      );
      final reloaded = InventoryItemModifier.fromJson(mod.toJson());
      expect(reloaded.kind, InventoryModifierKind.attribut);
      expect(reloaded.targetId, 'ge');
    });

    test('unbekannter kind-String faellt auf stat zurueck', () {
      final json = const <String, dynamic>{
        'kind': 'ungueltig',
        'targetId': 'gs',
        'wert': 1,
      };
      final mod = InventoryItemModifier.fromJson(json);
      expect(mod.kind, InventoryModifierKind.stat);
    });
  });

  group('HeroInventoryEntry.copyWith – nullable sourceRef', () {
    test('sourceRef kann auf null gesetzt werden', () {
      final entry = HeroInventoryEntry(
        gegenstand: 'Bogen',
        sourceRef: 'w:Bogen',
      );
      final cleared = entry.copyWith(sourceRef: null);
      expect(cleared.sourceRef, isNull);
    });

    test('sourceRef wird beibehalten wenn nicht uebergeben', () {
      final entry = HeroInventoryEntry(
        gegenstand: 'Bogen',
        sourceRef: 'w:Bogen',
      );
      final copy = entry.copyWith(gegenstand: 'Kurzbogen');
      expect(copy.sourceRef, 'w:Bogen');
    });
  });
}
