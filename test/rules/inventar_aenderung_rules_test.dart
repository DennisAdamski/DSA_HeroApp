import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';

// Editorergebnisse im Inventar (ARCH-05): Anlegen und Bearbeiten arbeiten auf
// dem gespeicherten Helden. Ein Eintrag wird über seinen Inhalt getroffen,
// ein inzwischen geänderter abgewiesen, und in den Kampf schreibt nur der
// bearbeitete Eintrag selbst.

const _seil = HeroInventoryEntry(gegenstand: 'Seil', anzahl: '1');
const _fackel = HeroInventoryEntry(gegenstand: 'Fackel', anzahl: '3');

const _held = HeroSheet(
  id: 'held',
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
);

MainWeaponSlot _bogen(String id, int pfeile) => MainWeaponSlot(
  id: id,
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: [RangedProjectile(id: 'p', name: 'Pfeil', count: pfeile)],
  ),
);

HeroInventoryEntry _pfeile(String bogenId, String anzahl) => HeroInventoryEntry(
  gegenstand: 'Pfeil',
  anzahl: anzahl,
  itemType: InventoryItemType.verbrauchsgegenstand,
  source: InventoryItemSource.geschoss,
  sourceRef: 'w:Kurzbogen|p:Pfeil',
  slotRef: 'w#$bogenId|p#p',
);

// Zwei gleichnamige Bögen; der Namensverweis träfe beide Male den ersten.
HeroSheet _schuetze({int pfeileA = 10, int pfeileB = 20}) => _held.copyWith(
  combatConfig: CombatConfig(
    weapons: [_bogen('a', pfeileA), _bogen('b', pfeileB)],
  ),
  inventoryEntries: [_pfeile('a', '10'), _pfeile('b', '20'), _seil],
);

int _pfeileVon(HeroSheet held, int bogen) =>
    held.combatConfig.weaponSlots[bogen].rangedProfile.projectiles.single.count;

void main() {
  group('mitNeuemInventarEintrag', () {
    test('hängt an den gespeicherten Stand an, der Kampf bleibt', () {
      final gespeichert = _schuetze(pfeileA: 14);

      final ergebnis = mitNeuemInventarEintrag(gespeichert, _fackel);

      expect(ergebnis.inventoryEntries.map((e) => e.gegenstand), [
        'Pfeil',
        'Pfeil',
        'Seil',
        'Fackel',
      ]);
      expect(
        identical(ergebnis.combatConfig, gespeichert.combatConfig),
        isTrue,
      );
    });

    test('der neue Eintrag ist bei Gleichheit der hintere', () {
      const eintraege = [_seil, _fackel, _seil];
      expect(findeLetztenGleichenInventarEintrag(eintraege, _seil), 2);
      expect(findeGleichenInventarEintrag(eintraege, _seil), 0);
      expect(findeLetztenGleichenInventarEintrag(const [_fackel], _seil), -1);
    });
  });

  group('mitGeaendertemInventarEintrag', () {
    test('trifft den angezeigten Eintrag auch nach einer Verschiebung', () {
      // Angezeigt war das Seil an Position 0; inzwischen wurde davor eine
      // Fackel gespeichert.
      final gespeichert = _held.copyWith(
        inventoryEntries: const [_fackel, _seil],
      );

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        _seil,
        _seil.copyWith(anzahl: '2'),
      );

      expect(
        ergebnis.inventoryEntries.map((e) => '${e.gegenstand} ${e.anzahl}'),
        ['Fackel 3', 'Seil 2'],
      );
    });

    test('ein geänderter oder entfernter Eintrag wird abgewiesen', () {
      final geaendert = _held.copyWith(
        inventoryEntries: [_seil.copyWith(anzahl: '5')],
      );
      final entfernt = _held.copyWith(inventoryEntries: const [_fackel]);
      final abgewiesen = throwsA(
        isA<StateError>().having(
          (fehler) => fehler.message,
          'message',
          contains('inzwischen geändert'),
        ),
      );

      for (final gespeichert in [geaendert, entfernt]) {
        expect(
          () => mitGeaendertemInventarEintrag(
            gespeichert,
            _seil,
            _seil.copyWith(anzahl: '2'),
          ),
          abgewiesen,
        );
      }
    });

    test('ohne Änderung kommt derselbe Held zurück', () {
      final gespeichert = _held.copyWith(inventoryEntries: const [_seil]);

      final ergebnis = mitGeaendertemInventarEintrag(gespeichert, _seil, _seil);

      expect(identical(ergebnis, gespeichert), isTrue);
    });

    test('ein manueller Eintrag lässt den Kampf unverändert', () {
      final gespeichert = _schuetze();

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        _seil,
        _seil.copyWith(beschreibung: '20 Schritt'),
      );

      expect(ergebnis.inventoryEntries.last.beschreibung, '20 Schritt');
      expect(
        identical(ergebnis.combatConfig, gespeichert.combatConfig),
        isTrue,
      );
    });

    test('die Geschossmenge landet beim eigenen Bogen', () {
      final gespeichert = _schuetze();

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        _pfeile('b', '20'),
        _pfeile('b', '25'),
      );

      expect(_pfeileVon(ergebnis, 0), 10);
      expect(_pfeileVon(ergebnis, 1), 25);
    });

    test('nur der bearbeitete Eintrag schreibt seine Menge', () {
      // Der erste Bogen hält 14 Pfeile, sein Eintrag nennt noch 10: Ein
      // Rückschreiben aller Einträge setzte ihn auf 10 zurück.
      final gespeichert = _schuetze(pfeileA: 14);

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        _pfeile('b', '20'),
        _pfeile('b', '25'),
      );

      expect(_pfeileVon(ergebnis, 0), 14);
      expect(_pfeileVon(ergebnis, 1), 25);
    });

    test('eine unveränderte Menge schreibt nicht in den Kampf', () {
      final gespeichert = _schuetze(pfeileB: 30);

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        _pfeile('b', '20'),
        _pfeile('b', '20').copyWith(beschreibung: 'Jagdpfeile'),
      );

      expect(_pfeileVon(ergebnis, 1), 30);
      expect(ergebnis.inventoryEntries[1].beschreibung, 'Jagdpfeile');
    });

    test('Markierungen eines verknüpften Eintrags gehen an seinen Slot', () {
      const schwert = HeroInventoryEntry(
        gegenstand: 'Langschwert',
        itemType: InventoryItemType.ausruestung,
        source: InventoryItemSource.waffe,
        sourceRef: 'w:Langschwert',
        slotRef: 'w#s',
      );
      final gespeichert = _held.copyWith(
        combatConfig: const CombatConfig(
          weapons: [MainWeaponSlot(id: 's', name: 'Langschwert')],
        ),
        inventoryEntries: const [schwert],
      );

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        schwert,
        schwert.copyWith(isMagisch: true, magischDescription: 'Runenätzung'),
      );

      final slot = ergebnis.combatConfig.weaponSlots.single;
      expect(slot.isArtifact, isTrue);
      expect(slot.artifactDescription, 'Runenätzung');
    });

    test('unbekannte Felder des Eintrags bleiben erhalten', () {
      final angezeigt = HeroInventoryEntry.fromJson(const {
        'gegenstand': 'Seil',
        'anzahl': '1',
        'zukunftsFeld': 'bleibt',
      });
      final gespeichert = _held.copyWith(inventoryEntries: [angezeigt]);

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        angezeigt,
        angezeigt.copyWith(anzahl: '2'),
      );

      final json = ergebnis.inventoryEntries.single.toJson();
      expect(json['zukunftsFeld'], 'bleibt');
      expect(json['anzahl'], '2');
    });
  });

  // Das Speichern vergibt fehlende Instanz-IDs (ARCH-03). Ein Eintrag, der
  // vorher ohne ID angezeigt wurde, ist dadurch nicht geändert.
  group('beim Speichern vergebene Instanz-ID', () {
    final seilMitId = _seil.copyWith(instanzId: 'i-seil');

    test('ein Eintrag ohne ID findet sich mit ID wieder', () {
      final eintraege = [_fackel, seilMitId];
      expect(findeGleichenInventarEintrag(eintraege, _seil), 1);
      expect(findeLetztenGleichenInventarEintrag(eintraege, _seil), 1);
    });

    test('eine andere ID bleibt ein anderer Eintrag', () {
      final anderesSeil = _seil.copyWith(instanzId: 'i-anderes');
      expect(findeGleichenInventarEintrag([seilMitId], anderesSeil), -1);
    });

    test('Bearbeiten trifft den Eintrag und behält seine ID', () {
      final gespeichert = _held.copyWith(
        inventoryEntries: [_fackel, seilMitId],
      );

      final ergebnis = mitGeaendertemInventarEintrag(
        gespeichert,
        _seil,
        _seil.copyWith(gegenstand: 'Seil, 20 m'),
      );

      final seil = ergebnis.inventoryEntries[1];
      expect(seil.gegenstand, 'Seil, 20 m');
      expect(seil.instanzId, 'i-seil');
    });

    test('Löschen trifft den Eintrag', () {
      final gespeichert = _held.copyWith(
        inventoryEntries: [_fackel, seilMitId],
      );

      final ergebnis = ohneInventarEintrag(gespeichert, _seil);

      expect(ergebnis.inventoryEntries.map((e) => e.gegenstand), ['Fackel']);
    });
  });
}
