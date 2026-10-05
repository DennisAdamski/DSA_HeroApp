import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_inventar_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_verbrauch_rules.dart';

import '../ui2/shell/karto_test_support.dart';

const _trank = HeroInventoryEntry(
  gegenstand: 'Heiltrank',
  anzahl: '3',
  woGetragen: 'Gürteltasche',
  itemType: InventoryItemType.verbrauchsgegenstand,
);

void main() {
  test('Menge: menge vor ganzzahliger anzahl, sonst offen', () {
    expect(inventarMenge(_trank), 3);
    expect(inventarMenge(_trank.copyWith(menge: 5)), 5);
    expect(inventarMenge(_trank.copyWith(anzahl: 'ein paar')), isNull);
    expect(inventarMenge(_trank.copyWith(anzahl: '')), isNull);
  });

  test('Verbrauch hält anzahl und menge konsistent', () {
    expect(inventarEintragNachVerbrauch(_trank).anzahl, '2');
    final beide = inventarEintragNachVerbrauch(_trank.copyWith(menge: 3));
    expect(beide.menge, 2);
    expect(beide.anzahl, '2');
    // Abweichender Freitext bleibt unangetastet.
    final abweichend = inventarEintragNachVerbrauch(
      _trank.copyWith(menge: 4, anzahl: 'vier kleine'),
    );
    expect(abweichend.menge, 3);
    expect(abweichend.anzahl, 'vier kleine');
    expect(
      () => inventarEintragNachVerbrauch(_trank.copyWith(anzahl: '0')),
      throwsStateError,
    );
    expect(
      () => inventarEintragNachVerbrauch(_trank.copyWith(anzahl: 'viele')),
      throwsStateError,
    );
    final geschoss = _trank.copyWith(
      source: InventoryItemSource.geschoss,
      sourceRef: 'w:Bogen|p:Pfeil',
    );
    expect(inventarAbbuchbar(geschoss), isFalse);
  });

  test('Abbuchung trifft den Gegenstand über seinen Inhalt', () {
    const seil = HeroInventoryEntry(gegenstand: 'Seil', anzahl: '1');
    final held = testHero().copyWith(inventoryEntries: const [seil, _trank]);
    final neu = mitVerbrauchtemInventarEintrag(held, _trank);
    expect(neu.inventoryEntries[0], seil);
    expect(neu.inventoryEntries[1].anzahl, '2');
    // Inzwischen anders gespeichert: keine Abbuchung am falschen Stück.
    final geaendert = held.copyWith(
      inventoryEntries: [
        seil,
        _trank.copyWith(anzahl: '7'),
      ],
    );
    expect(
      () => mitVerbrauchtemInventarEintrag(geaendert, _trank),
      throwsStateError,
    );
    // Bei 0 bleibt der Eintrag stehen.
    final letzter = mitVerbrauchtemInventarEintrag(
      testHero().copyWith(inventoryEntries: [_trank.copyWith(anzahl: '1')]),
      _trank.copyWith(anzahl: '1'),
    );
    expect(letzter.inventoryEntries.single.anzahl, '0');
  });

  test('Gruppen, Aufbewahrung und Benutzungsdauer (WdS S. 55)', () {
    final held = testHero().copyWith(
      companions: const [HeroCompanion(id: 'h', name: 'Hasso')],
      inventoryEntries: [
        const HeroInventoryEntry(gegenstand: 'Decke'),
        _trank,
        const HeroInventoryEntry(
          gegenstand: 'Futter',
          traegerTyp: InventoryTraeger.begleiter,
          traegerId: 'h',
        ),
        const HeroInventoryEntry(
          gegenstand: 'Schwert',
          source: InventoryItemSource.waffe,
          sourceRef: 'w:Schwert',
          istAusgeruestet: true,
        ),
      ],
    );
    final posten = gefechtsInventar(held);
    expect(posten.map((p) => p.eintrag.gegenstand), [
      'Heiltrank',
      'Schwert',
      'Decke',
      'Futter',
    ]);
    expect(posten.first.benutzbar, isTrue);
    expect(posten[1].benutzbar, isFalse);
    expect(posten.last.traeger, 'Hasso');
    expect(
      gefechtsAufbewahrungVorgabe(_trank),
      GefechtsAufbewahrung.guerteltasche,
    );
    expect(
      gefechtsAufbewahrungVorgabe(_trank.copyWith(woGetragen: 'Rucksack')),
      GefechtsAufbewahrung.rucksack,
    );
    expect(gefechtsBenutzungsdauer(GefechtsAufbewahrung.guerteltasche), 10);
    expect(gefechtsBenutzungsdauer(GefechtsAufbewahrung.rucksack), 20);
    expect(
      gefechtsBenutzungsdauer(
        GefechtsAufbewahrung.guerteltasche,
        ffGelungen: true,
      ),
      5,
    );
    expect(gefechtsBenutzungsdauer(GefechtsAufbewahrung.artefakt), 0);
    expect(
      gefechtsBenutzungsdauer(
        GefechtsAufbewahrung.griffbereit,
        ffGelungen: true,
      ),
      1,
    );
  });

  test('Begleiterprofil rechnet Steigerung und Rüstung ein', () {
    const hund = HeroCompanion(
      id: 'h',
      name: 'Hasso',
      typ: BegleiterTyp.sonstigerBegleiter,
      ini: 12,
      maxLep: 20,
      angriffe: [
        HeroCompanionAttack(
          id: 'b',
          name: 'Biss',
          at: 11,
          tp: '1W6+2',
          dk: 'H',
          steigerungAt: 2,
        ),
      ],
      ruestungsTeile: [
        ArmorPiece(name: 'Lederhaube', isActive: true, rs: 1, be: 0),
      ],
    );
    final p = begleiterKampfprofil(hund);
    expect(p.name, 'Hasso');
    expect(p.ini, 12);
    expect(p.lep, 20);
    expect(p.rs, 1);
    expect(p.angriffe.single.at, 13);
    expect(p.angriffe.single.pa, isNull);
    expect(p.angriffe.single.tp, '1W6+2');
  });
}
