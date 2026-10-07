import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_slot_pruefung_rules.dart';

// Slotprüfung der Kampfkonfiguration (ARCH-05): früher im Kampf-Tab-Widget,
// jetzt als Regel mit allen Befunden und dem Vergleich „neuer Fehler“.

const _schwerter = TalentDef(
  id: 'tal_schwerter',
  name: 'Schwerter',
  group: 'Kampftalent',
  steigerung: 'E',
  attributes: [],
  type: 'nahkampf',
);
const _bogen = TalentDef(
  id: 'tal_bogen',
  name: 'Bogen',
  group: 'Kampftalent',
  steigerung: 'E',
  attributes: [],
  type: 'fernkampf',
);
const _klettern = TalentDef(
  id: 'tal_klettern',
  name: 'Klettern',
  group: 'Körper',
  steigerung: 'D',
  attributes: [],
);

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [_schwerter, _bogen, _klettern],
  spells: [],
  weapons: [
    WeaponDef(
      id: 'w_langschwert',
      name: 'Langschwert',
      type: 'Nahkampf',
      combatSkill: 'Schwerter',
      tp: '1W6+4',
    ),
  ],
);

const _schwert = MainWeaponSlot(
  id: 'w1',
  name: 'Schwert',
  talentId: 'tal_schwerter',
  weaponType: 'Langschwert',
);
const _kurzbogen = MainWeaponSlot(
  id: 'w2',
  name: 'Kurzbogen',
  talentId: 'tal_bogen',
  combatType: WeaponCombatType.ranged,
);

// Bewusst über den Konstruktor: `copyWith` normalisiert die Nebenhand und
// löst eine doppelt belegte Waffe still auf; die Prüfung muss sie trotzdem
// melden, falls sie anders entsteht.
CombatConfig _config(
  List<MainWeaponSlot> waffen, {
  OffhandAssignment nebenhand = const OffhandAssignment(),
  List<OffhandEquipmentEntry> teile = const [],
  bool linkhand = false,
  int gewaehlt = 0,
}) {
  return CombatConfig(
    weapons: waffen,
    selectedWeaponIndex: gewaehlt,
    offhandAssignment: nebenhand,
    offhandEquipment: teile,
    specialRules: CombatSpecialRules(linkhandActive: linkhand),
  );
}

List<String> _meldungen(CombatConfig config) => pruefeKampfSlots(
  config: config,
  catalog: _katalog,
).map((befund) => befund.meldung).toList();

void main() {
  test('eine gültige Konfiguration hat keine Befunde', () {
    expect(_meldungen(_config([_schwert, _kurzbogen])), isEmpty);
    expect(_meldungen(_config([const MainWeaponSlot()])), isEmpty);
  });

  group('Meldungen je Waffenplatz', () {
    final faelle = <String, (MainWeaponSlot, String)>{
      'kein Kampftalent': (
        _schwert.copyWith(talentId: 'tal_klettern'),
        'Waffe 1: Das gewählte Talent ist kein gültiges Kampftalent.',
      ),
      'falscher Kampftyp': (
        _schwert.copyWith(talentId: 'tal_bogen', weaponType: ''),
        'Waffe 1: Talent "Bogen" passt nicht zum Waffenkampftyp.',
      ),
      'fremde Waffenart': (
        _schwert.copyWith(weaponType: 'Kriegsbogen'),
        'Waffe 1: Waffenart "Kriegsbogen" passt nicht zum Talent '
            '"Schwerter".',
      ),
      'Waffenart ohne Talent': (
        _schwert.copyWith(talentId: ''),
        'Waffe 1: Waffenart "Langschwert" benötigt ein gültiges Talent.',
      ),
      'negative KK-Schwelle': (
        _schwert.copyWith(kkThreshold: -1),
        'Waffe 1: KK-Schwelle darf nicht negativ sein.',
      ),
      'halb deaktiviertes TP/KK': (
        _schwert.copyWith(kkThreshold: 0, kkBase: 12),
        'Waffe 1: TP/KK darf nur als 0/0 deaktiviert werden.',
      ),
      'kein Schadenswürfel': (
        _schwert.copyWith(tpDiceCount: 0),
        'Waffe 1: Würfelanzahl muss >= 1 sein.',
      ),
      'negative Ladezeit': (
        _kurzbogen.copyWith(
          rangedProfile: const RangedWeaponProfile(reloadTime: -1),
        ),
        'Waffe 1: Ladezeit darf nicht negativ sein.',
      ),
      'negativer Geschossbestand': (
        _kurzbogen.copyWith(
          rangedProfile: const RangedWeaponProfile(
            projectiles: [RangedProjectile(id: 'p', name: 'Pfeile', count: -1)],
          ),
        ),
        'Waffe 1: Geschossbestände dürfen nicht negativ sein.',
      ),
    };
    faelle.forEach((name, fall) {
      test(name, () {
        expect(_meldungen(_config([fall.$1])), [fall.$2]);
      });
    });
  });

  group('Nebenhand', () {
    test('dieselbe Waffe in beiden Händen', () {
      expect(
        _meldungen(
          _config([
            _schwert,
            _kurzbogen,
          ], nebenhand: const OffhandAssignment(weaponIndex: 0)),
        ),
        [
          'Nebenhand: Haupthand und Nebenhand dürfen nicht dieselbe Waffe nutzen.',
        ],
      );
    });

    test('Parierwaffe ohne Linkhand und negativer BF', () {
      const parierwaffe = OffhandEquipmentEntry(
        id: 'oh',
        name: 'Linkhanddolch',
        type: OffhandEquipmentType.parryWeapon,
        breakFactor: -1,
      );
      final config = _config(
        [_schwert],
        nebenhand: const OffhandAssignment(equipmentIndex: 0),
        teile: const [parierwaffe],
      );
      expect(_meldungen(config), [
        'Nebenhand: Parierwaffen erfordern die Sonderfertigkeit Linkhand.',
        'Nebenhand: BF darf nicht negativ sein.',
      ]);
      expect(
        _meldungen(
          _config(
            [_schwert],
            nebenhand: const OffhandAssignment(equipmentIndex: 0),
            teile: [parierwaffe.copyWith(breakFactor: 1)],
            linkhand: true,
          ),
        ),
        isEmpty,
      );
    });
  });

  test('alle Befunde in Slotreihenfolge, die Nebenhand zuletzt', () {
    final config = _config([
      _schwert.copyWith(tpDiceCount: 0),
      _kurzbogen.copyWith(kkThreshold: -1),
    ], nebenhand: const OffhandAssignment(weaponIndex: 0));
    expect(_meldungen(config), [
      'Waffe 1: Würfelanzahl muss >= 1 sein.',
      'Waffe 2: KK-Schwelle darf nicht negativ sein.',
      'Nebenhand: Haupthand und Nebenhand dürfen nicht dieselbe Waffe nutzen.',
    ]);
  });

  group('neuerKampfSlotFehler', () {
    final kaputt = _schwert.copyWith(kkThreshold: -1);

    test('ein schon gespeicherter Fehler sperrt andere Änderungen nicht', () {
      final vorher = _config([kaputt, _kurzbogen]);
      final nachher = _config([kaputt, _kurzbogen.copyWith(name: 'Langbogen')]);
      expect(
        neuerKampfSlotFehler(
          vorher: vorher,
          nachher: nachher,
          catalog: _katalog,
        ),
        isNull,
      );
    });

    test('ein neuer Fehler wird gemeldet', () {
      final vorher = _config([kaputt, _kurzbogen]);
      final nachher = _config([kaputt, _kurzbogen.copyWith(tpDiceCount: 0)]);
      final befund = neuerKampfSlotFehler(
        vorher: vorher,
        nachher: nachher,
        catalog: _katalog,
      );
      expect(befund?.meldung, 'Waffe 2: Würfelanzahl muss >= 1 sein.');
    });

    test('eine neue Art am selben Slot gilt als neuer Fehler', () {
      final vorher = _config([kaputt]);
      final nachher = _config([kaputt.copyWith(tpDiceCount: 0)]);
      expect(
        neuerKampfSlotFehler(
          vorher: vorher,
          nachher: nachher,
          catalog: _katalog,
        )?.art,
        KampfSlotFehlerArt.wuerfelanzahlZuKlein,
      );
    });

    test('Umsortieren erzeugt keinen neuen Fehler', () {
      final vorher = _config([kaputt, _kurzbogen], gewaehlt: 1);
      final nachher = _config([_kurzbogen, kaputt]);
      expect(
        neuerKampfSlotFehler(
          vorher: vorher,
          nachher: nachher,
          catalog: _katalog,
        ),
        isNull,
      );
    });
  });
}
