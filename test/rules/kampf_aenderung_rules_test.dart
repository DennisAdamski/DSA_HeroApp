import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';

// Sofortänderungen im Kampf-Tab (ARCH-05): Jede Funktion arbeitet auf der
// gespeicherten Kampfkonfiguration, trifft Slots über ihre Identität statt
// über ihre Position und ändert nur die gemeinten Felder.

const _pfeile = RangedProjectile(id: 'p1', name: 'Pfeile', count: 10);
const _jagdpfeile = RangedProjectile(id: 'p2', name: 'Jagdpfeile', count: 5);

const _schwert = MainWeaponSlot(
  id: 'w1',
  name: 'Schwert',
  talentId: 'tal_schwerter',
  breakFactor: 2,
);
const _bogen = MainWeaponSlot(
  id: 'w2',
  name: 'Kurzbogen',
  talentId: 'tal_bogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: [_pfeile, _jagdpfeile],
    selectedProjectileIndex: 0,
  ),
);
const _dolch = MainWeaponSlot(id: 'w3', name: 'Dolch', talentId: 'tal_dolche');
const _axt = MainWeaponSlot(id: 'w4', name: 'Axt', talentId: 'tal_hiebwaffen');

const _schild = OffhandEquipmentEntry(
  id: 'oh1',
  name: 'Holzschild',
  type: OffhandEquipmentType.shield,
);
const _linkhand = OffhandEquipmentEntry(id: 'oh2', name: 'Linkhand');
const _buckler = OffhandEquipmentEntry(
  id: 'oh3',
  name: 'Buckler',
  type: OffhandEquipmentType.shield,
);

const _helm = ArmorPiece(id: 'a1', name: 'Helm', rs: 1, be: 0);
const _kette = ArmorPiece(id: 'a2', name: 'Kettenhemd', rs: 3, be: 2);

CombatConfig _config({
  List<MainWeaponSlot> waffen = const [_schwert, _bogen, _dolch],
  int gewaehlt = 0,
  OffhandAssignment nebenhand = const OffhandAssignment(),
  List<OffhandEquipmentEntry> teile = const [_schild, _linkhand],
  List<ArmorPiece> ruestung = const [_helm, _kette],
}) {
  return const CombatConfig().copyWith(
    weapons: waffen,
    selectedWeaponIndex: gewaehlt,
    offhandEquipment: teile,
    offhandAssignment: nebenhand,
    armor: ArmorConfig(pieces: ruestung),
  );
}

List<String> _namen(CombatConfig config) =>
    config.weaponSlots.map((slot) => slot.name).toList();

void main() {
  group('mitKampfAenderung', () {
    final held = HeroSheet(
      id: 'held',
      name: 'Rondra',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      combatConfig: _config(),
    );

    test('ohne inhaltliche Änderung kommt derselbe Held zurück', () {
      final ergebnis = mitKampfAenderung(
        held,
        (config) => mitAktiverWaffe(config, _schwert),
      );
      expect(identical(ergebnis, held), isTrue);
    });

    test('ändert nur die Kampfkonfiguration', () {
      final ergebnis = mitKampfAenderung(
        held,
        (config) => mitAktiverWaffe(config, _dolch),
      );
      expect(ergebnis.combatConfig.selectedWeaponIndex, 2);
      expect(
        ergebnis.copyWith(combatConfig: held.combatConfig).toJson(),
        held.toJson(),
      );
    });
  });

  group('mitAktiverWaffe', () {
    test('trifft die angezeigte Waffe nach einer Einfügung davor', () {
      // Angezeigt stand der Dolch an Position 2; inzwischen kam die Axt davor.
      final gespeichert = _config(
        waffen: const [_axt, _schwert, _bogen, _dolch],
      );
      final ergebnis = mitAktiverWaffe(gespeichert, _dolch, index: 2);
      expect(ergebnis.selectedWeaponIndex, 3);
      expect(ergebnis.selectedWeapon.name, 'Dolch');
    });

    test('null wählt keine Waffe', () {
      final ergebnis = mitAktiverWaffe(_config(), null);
      expect(ergebnis.selectedWeaponIndex, -1);
    });

    test('eine inzwischen entfernte Waffe wird gemeldet', () {
      final gespeichert = _config(waffen: const [_schwert, _bogen]);
      expect(
        () => mitAktiverWaffe(gespeichert, _dolch, index: 2),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Die Waffe wurde inzwischen geändert oder entfernt.',
          ),
        ),
      );
    });

    test('die bisherige Nebenhandwaffe verlässt die Nebenhand', () {
      final gespeichert = _config(
        nebenhand: const OffhandAssignment(weaponIndex: 2),
      );
      final ergebnis = mitAktiverWaffe(gespeichert, _dolch);
      expect(ergebnis.selectedWeaponIndex, 2);
      expect(ergebnis.offhandAssignment.isNone, isTrue);
    });

    group('Slots ohne ID', () {
      const leer1 = MainWeaponSlot(talentId: 'tal_raufen');
      const leer2 = MainWeaponSlot(talentId: 'tal_ringen');

      test('die angezeigte Position gewinnt, wenn der Inhalt passt', () {
        final gespeichert = _config(waffen: const [leer1, leer1, leer2]);
        final ergebnis = mitAktiverWaffe(gespeichert, leer1, index: 1);
        expect(ergebnis.selectedWeaponIndex, 1);
      });

      test('sonst gilt der erste inhaltsgleiche Slot', () {
        final gespeichert = _config(waffen: const [leer2, leer1]);
        final ergebnis = mitAktiverWaffe(gespeichert, leer1, index: 0);
        expect(ergebnis.selectedWeaponIndex, 1);
      });

      test('eine beim Speichern vergebene ID stört nicht', () {
        const neu = MainWeaponSlot(name: 'Neu', talentId: 'tal_dolche');
        final gespeichert = _config(
          waffen: [
            _schwert,
            neu.copyWith(id: 'uuid-1'),
          ],
        );
        final ergebnis = mitAktiverWaffe(gespeichert, neu, index: 1);
        expect(ergebnis.selectedWeaponIndex, 1);
      });

      test('ein inhaltlich geänderter Slot wird gemeldet', () {
        final gespeichert = _config(waffen: const [leer2]);
        expect(
          () => mitAktiverWaffe(gespeichert, leer1, index: 0),
          throwsStateError,
        );
      });
    });
  });

  group('aendereWaffe', () {
    test('ändert nur den gespeicherten Slot der angezeigten Waffe', () {
      final bogenMitFeld = _bogen.copyWith(
        unbekannteFelder: const {'zukunft': 1},
      );
      // Inzwischen gespeichert: Axt davor, Pfeilbestand geändert.
      final gespeichert = _config(
        waffen: [
          _axt,
          _schwert,
          bogenMitFeld.copyWith(
            rangedProfile: bogenMitFeld.rangedProfile.copyWith(
              projectiles: [_pfeile.copyWith(count: 20), _jagdpfeile],
            ),
          ),
        ],
      );
      final ergebnis = aendereWaffe(
        gespeichert,
        _bogen,
        (slot) => slot.copyWith(breakFactor: 4),
        index: 1,
      );
      final bogen = ergebnis.weaponSlots[2];
      expect(bogen.breakFactor, 4);
      expect(bogen.rangedProfile.projectiles.first.count, 20);
      expect(bogen.unbekannteFelder, {'zukunft': 1});
      expect(_namen(ergebnis), ['Axt', 'Schwert', 'Kurzbogen']);
    });

    test('Änderung der aktiven Waffe erreicht auch den Spiegel', () {
      final ergebnis = aendereWaffe(
        _config(),
        _schwert,
        (slot) => slot.copyWith(breakFactor: 5),
      );
      expect(ergebnis.selectedWeapon.breakFactor, 5);
      expect(ergebnis.mainWeapon.breakFactor, 5);
    });
  });

  group('Entfernung und Geschosswahl', () {
    test('mitEntfernung setzt die Stufe der angezeigten Waffe', () {
      final ergebnis = mitEntfernung(_config(), _bogen, 3);
      expect(ergebnis.weaponSlots[1].rangedProfile.selectedDistanceIndex, 3);
    });

    test('mitGeschossWahl trifft das Geschoss über seine ID', () {
      final gespeichert = _config(
        waffen: [
          _schwert,
          _bogen.copyWith(
            rangedProfile: _bogen.rangedProfile.copyWith(
              projectiles: const [_jagdpfeile, _pfeile],
            ),
          ),
        ],
      );
      final ergebnis = mitGeschossWahl(
        gespeichert,
        _bogen,
        _jagdpfeile,
        geschossIndex: 1,
      );
      final profil = ergebnis.weaponSlots[1].rangedProfile;
      expect(profil.selectedProjectileOrNull?.name, 'Jagdpfeile');
    });

    test('null wählt kein Geschoss', () {
      final ergebnis = mitGeschossWahl(_config(), _bogen, null);
      final profil = ergebnis.weaponSlots[1].rangedProfile;
      expect(profil.selectedProjectileIndex, -1);
    });
  });

  group('mitGeschossSchritt', () {
    CombatConfig mitPfeilen(int anzahl) => _config(
      waffen: [
        _schwert,
        _bogen.copyWith(
          rangedProfile: _bogen.rangedProfile.copyWith(
            projectiles: [
              _pfeile.copyWith(count: anzahl),
              _jagdpfeile,
            ],
          ),
        ),
      ],
    );

    int pfeile(CombatConfig config) =>
        config.weaponSlots[1].rangedProfile.projectiles.first.count;

    test('zählt vom gespeicherten Bestand', () {
      // Angezeigt: 10 Pfeile; gespeichert inzwischen 20.
      final ergebnis = mitGeschossSchritt(mitPfeilen(20), _bogen, _pfeile, 1);
      expect(pfeile(ergebnis), 21);
    });

    test('drei Schritte mit demselben angezeigten Stand zählen dreimal', () {
      var config = mitPfeilen(10);
      for (var i = 0; i < 3; i++) {
        config = mitGeschossSchritt(config, _bogen, _pfeile, 1);
      }
      expect(pfeile(config), 13);
    });

    test('begrenzt auf 0 und den Höchstbestand', () {
      final unten = mitGeschossSchritt(mitPfeilen(0), _bogen, _pfeile, -1);
      expect(pfeile(unten), 0);
      final oben = mitGeschossSchritt(
        mitPfeilen(kGeschossHoechstbestand),
        _bogen,
        _pfeile,
        1,
      );
      expect(pfeile(oben), kGeschossHoechstbestand);
    });

    test('trifft das angezeigte, nicht das gewählte Geschoss', () {
      final gespeichert = mitGeschossWahl(mitPfeilen(10), _bogen, _jagdpfeile);
      final ergebnis = mitGeschossSchritt(gespeichert, _bogen, _pfeile, -1);
      final geschosse = ergebnis.weaponSlots[1].rangedProfile.projectiles;
      expect(geschosse.map((g) => g.count), [9, 5]);
    });

    test('ein entferntes Geschoss wird gemeldet', () {
      final gespeichert = _config(
        waffen: [
          _schwert,
          _bogen.copyWith(
            rangedProfile: _bogen.rangedProfile.copyWith(
              projectiles: const [_jagdpfeile],
            ),
          ),
        ],
      );
      expect(
        () => mitGeschossSchritt(gespeichert, _bogen, _pfeile, 1),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Das Geschoss wurde inzwischen geändert oder entfernt.',
          ),
        ),
      );
    });
  });

  group('Waffen anlegen und ersetzen', () {
    test('mitNeuerWaffe hängt an', () {
      final ergebnis = mitNeuerWaffe(_config(), _axt);
      expect(_namen(ergebnis), ['Schwert', 'Kurzbogen', 'Dolch', 'Axt']);
    });

    test('ersetzeWaffe tauscht die unveränderte Waffe', () {
      final gespeichert = _config(waffen: const [_axt, _schwert, _bogen]);
      final ergebnis = ersetzeWaffe(
        gespeichert,
        ausgang: _schwert,
        neu: _schwert.copyWith(name: 'Langschwert'),
        index: 0,
      );
      expect(_namen(ergebnis), ['Axt', 'Langschwert', 'Kurzbogen']);
    });

    test('ersetzeWaffe weist eine inzwischen geänderte Waffe ab', () {
      final gespeichert = _config(
        waffen: [_schwert, _bogen.copyWith(breakFactor: 3)],
      );
      expect(
        () => ersetzeWaffe(
          gespeichert,
          ausgang: _bogen,
          neu: _bogen.copyWith(name: 'Langbogen'),
        ),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Die Waffe wurde inzwischen geändert.',
          ),
        ),
      );
    });
  });

  group('ohneWaffe', () {
    test('entfernt über die ID und lässt die aktive Waffe nachrücken', () {
      final gespeichert = _config(gewaehlt: 2);
      final ergebnis = ohneWaffe(gespeichert, _schwert, index: 0);
      expect(_namen(ergebnis), ['Kurzbogen', 'Dolch']);
      expect(ergebnis.selectedWeapon.name, 'Dolch');
    });

    test('die entfernte aktive Waffe hinterlässt keine Auswahl', () {
      final ergebnis = ohneWaffe(_config(gewaehlt: 1), _bogen);
      expect(ergebnis.selectedWeaponIndex, -1);
    });

    test('die Nebenhandwaffe rückt nach', () {
      // Vorher verlor die Nebenhand bei jeder Entfernung davor ihre Waffe.
      final gespeichert = _config(
        waffen: const [_schwert, _bogen, _dolch],
        nebenhand: const OffhandAssignment(weaponIndex: 2),
      );
      final ergebnis = ohneWaffe(gespeichert, _bogen);
      expect(ergebnis.offhandAssignment.weaponIndex, 1);
      expect(ergebnis.weaponSlots[1].name, 'Dolch');
    });

    test('die Nebenhand trifft nie die aktive Waffe', () {
      // Aktiv: Dolch, Nebenhand: Axt; der Bogen davor fällt weg.
      final gespeichert = _config(
        waffen: const [_schwert, _bogen, _dolch, _axt],
        gewaehlt: 2,
        nebenhand: const OffhandAssignment(weaponIndex: 3),
      );
      final ergebnis = ohneWaffe(gespeichert, _bogen);
      expect(ergebnis.selectedWeapon.name, 'Dolch');
      final nebenhand = ergebnis.offhandAssignment.weaponIndex;
      expect(ergebnis.weaponSlots[nebenhand].name, 'Axt');
    });

    test('die entfernte Nebenhandwaffe leert die Nebenhand', () {
      final gespeichert = _config(
        nebenhand: const OffhandAssignment(weaponIndex: 2),
      );
      final ergebnis = ohneWaffe(gespeichert, _dolch);
      expect(ergebnis.offhandAssignment.isNone, isTrue);
    });

    test('die letzte Waffe bleibt', () {
      expect(
        () => ohneWaffe(_config(waffen: const [_schwert]), _schwert),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Die letzte Waffe lässt sich nicht entfernen.',
          ),
        ),
      );
    });
  });

  group('mitNebenhand', () {
    test('Waffe über ihre ID nach einer Einfügung davor', () {
      final gespeichert = _config(
        waffen: const [_axt, _schwert, _bogen, _dolch],
      );
      final ergebnis = mitNebenhand(gespeichert, waffe: _dolch, waffenIndex: 2);
      expect(ergebnis.offhandAssignment.weaponIndex, 3);
      expect(ergebnis.offhandAssignment.equipmentIndex, -1);
    });

    test('Teil über seine ID', () {
      final gespeichert = _config(teile: const [_buckler, _schild, _linkhand]);
      final ergebnis = mitNebenhand(gespeichert, teil: _linkhand, teilIndex: 1);
      expect(ergebnis.offhandAssignment.equipmentIndex, 2);
      expect(ergebnis.offhandAssignment.weaponIndex, -1);
    });

    test('ohne Angabe bleibt die Nebenhand leer', () {
      final gespeichert = _config(
        nebenhand: const OffhandAssignment(equipmentIndex: 0),
      );
      expect(mitNebenhand(gespeichert).offhandAssignment.isNone, isTrue);
    });
  });

  group('Rüstungsteile', () {
    List<String> teile(CombatConfig config) =>
        config.armor.pieces.map((teil) => teil.name).toList();

    test('anlegen hängt an', () {
      const arm = ArmorPiece(name: 'Armschienen', rs: 1);
      expect(teile(mitRuestungsteil(_config(), arm)), [
        'Helm',
        'Kettenhemd',
        'Armschienen',
      ]);
    });

    test('ersetzen trifft das Teil über seine ID', () {
      final gespeichert = _config(ruestung: const [_kette, _helm]);
      final ergebnis = mitRuestungsteil(
        gespeichert,
        _helm.copyWith(rs: 2),
        ausgang: _helm,
        index: 0,
      );
      expect(ergebnis.armor.pieces.map((teil) => teil.rs), [3, 2]);
    });

    test('ein inzwischen geändertes Teil wird nicht überschrieben', () {
      final gespeichert = _config(ruestung: [_helm.copyWith(isActive: true)]);
      expect(
        () => mitRuestungsteil(
          gespeichert,
          _helm.copyWith(rs: 2),
          ausgang: _helm,
        ),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Das Rüstungsteil wurde inzwischen geändert.',
          ),
        ),
      );
    });

    test('entfernen trifft das angezeigte Teil', () {
      final gespeichert = _config(ruestung: const [_kette, _helm]);
      final ergebnis = ohneRuestungsteil(gespeichert, _helm, index: 0);
      expect(teile(ergebnis), ['Kettenhemd']);
    });
  });

  group('Nebenhandteile', () {
    test('anlegen und ersetzen', () {
      final angelegt = mitNebenhandTeil(_config(), _buckler);
      expect(angelegt.offhandEquipment.map((t) => t.name), [
        'Holzschild',
        'Linkhand',
        'Buckler',
      ]);
      final ersetzt = mitNebenhandTeil(
        angelegt,
        _schild.copyWith(paMod: 2),
        ausgang: _schild,
      );
      expect(ersetzt.offhandEquipment.first.paMod, 2);
    });

    test('ein inzwischen geändertes Teil wird nicht überschrieben', () {
      final gespeichert = _config(teile: [_schild.copyWith(breakFactor: 3)]);
      expect(
        () => mitNebenhandTeil(gespeichert, _schild, ausgang: _schild),
        throwsA(
          isA<StateError>().having(
            (fehler) => fehler.message,
            'message',
            'Das Nebenhandteil wurde inzwischen geändert.',
          ),
        ),
      );
    });

    test('entfernen lässt die Nebenhand nachrücken', () {
      // Vorher zeigte die Nebenhand danach auf das falsche Teil.
      final gespeichert = _config(
        teile: const [_schild, _linkhand, _buckler],
        nebenhand: const OffhandAssignment(equipmentIndex: 2),
      );
      final ergebnis = ohneNebenhandTeil(gespeichert, _schild);
      final nebenhand = ergebnis.offhandAssignment.equipmentIndex;
      expect(ergebnis.offhandEquipment[nebenhand].name, 'Buckler');
    });

    test('das entfernte zugeordnete Teil leert die Nebenhand', () {
      final gespeichert = _config(
        nebenhand: const OffhandAssignment(equipmentIndex: 1),
      );
      final ergebnis = ohneNebenhandTeil(gespeichert, _linkhand);
      expect(ergebnis.offhandAssignment.isNone, isTrue);
    });
  });
}
