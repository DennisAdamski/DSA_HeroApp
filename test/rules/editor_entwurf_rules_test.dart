import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';

// Editorentwürfe (ARCH-05): Der Entwurf wird beim Speichern mit dem frisch
// geladenen Helden abgeglichen. Was anderswo inzwischen gespeichert wurde,
// bleibt; überschneiden sich Änderungen, entscheidet der Nutzer, und eine
// Buchung wird nie zurückgenommen.

const _held = HeroSheet(
  id: 'held',
  name: 'Rondra',
  level: 1,
  apTotal: 1000,
  apSpent: 400,
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
  talents: <String, HeroTalentEntry>{
    'tal_klettern': HeroTalentEntry(talentValue: 4),
  },
  combatConfig: CombatConfig(
    weapons: <MainWeaponSlot>[MainWeaponSlot(name: 'Schwert')],
  ),
);

// Wie gespeichert und wieder geladen: Slots tragen ihre IDs.
HeroSheet _gespeichert(HeroSheet held) => HeroSheet.fromJson(
  jsonDecode(jsonEncode(held.toJson())) as Map<String, dynamic>,
);

final HeroSheet _basis = _gespeichert(_held);

int _naechsteId = 0;
String _neueId() => 'neu-${_naechsteId++}';

HeroSheet _uebernimm({
  required HeroSheet entwurf,
  required HeroSheet aktuell,
  Set<String> erzwungen = const <String>{},
}) {
  return uebernimmEditorEntwurf(
    basis: _basis,
    entwurf: entwurf,
    aktuell: aktuell,
    erzwungen: erzwungen,
    neueId: _neueId,
  );
}

HeroSheet _mitKlettern(HeroSheet held, int wert) => held.copyWith(
  talents: <String, HeroTalentEntry>{
    ...held.talents,
    'tal_klettern': HeroTalentEntry(talentValue: wert),
  },
);

EditorEntwurfKonflikt _konfliktVon(void Function() aufruf) {
  try {
    aufruf();
  } on EditorEntwurfKonflikt catch (konflikt) {
    return konflikt;
  }
  fail('Ein Konflikt war erwartet.');
}

HeroAdventureEntry _abenteuer({
  String titel = 'Die Phileasson-Saga',
  HeroAdventureStatus status = HeroAdventureStatus.current,
  bool belohnt = false,
}) {
  return HeroAdventureEntry(
    id: 'abenteuer-1',
    title: titel,
    status: status,
    rewardsApplied: belohnt,
  );
}

void main() {
  group('uebernimmEditorEntwurf', () {
    test('ohne fremde Änderung kommt der Entwurf selbst zurück', () {
      final entwurf = _mitKlettern(_basis, 7);
      final aktuell = _basis.copyWith(lastModified: DateTime.utc(2026, 10));

      expect(
        identical(_uebernimm(entwurf: entwurf, aktuell: aktuell), entwurf),
        isTrue,
      );
    });

    test('eine fremde Änderung an einem anderen Bereich bleibt erhalten', () {
      final entwurf = _mitKlettern(_basis, 7);
      final aktuell = _basis.copyWith(dukaten: '42');

      final ergebnis = _uebernimm(entwurf: entwurf, aktuell: aktuell);

      expect(ergebnis.talents['tal_klettern']!.talentValue, 7);
      expect(ergebnis.dukaten, '42');
    });

    test('ein im Entwurf unveränderter Bereich nimmt den gespeicherten', () {
      // Der Notizen-Tab legte früher alle Abenteuer zurück über den Helden.
      final entwurf = _basis.copyWith(
        notes: const <HeroNoteEntry>[HeroNoteEntry(title: 'Neu')],
      );
      final aktuell = _basis.copyWith(adventures: [_abenteuer()]);

      final ergebnis = _uebernimm(entwurf: entwurf, aktuell: aktuell);

      expect(ergebnis.notes.single.title, 'Neu');
      expect(ergebnis.adventures.single.id, 'abenteuer-1');
    });

    test('derselbe Bereich auf beiden Seiten verschieden ist ein Konflikt', () {
      final entwurf = _mitKlettern(_basis, 7);
      final aktuell = _mitKlettern(_basis, 9).copyWith(dukaten: '42');

      final konflikt = _konfliktVon(
        () => _uebernimm(entwurf: entwurf, aktuell: aktuell),
      );

      expect(konflikt.schluessel, {'talents'});
      expect(konflikt.erzwingbar, isTrue);
    });

    test('dieselbe Änderung auf beiden Seiten ist kein Konflikt', () {
      final entwurf = _mitKlettern(_basis, 7);
      final aktuell = _mitKlettern(_basis, 7).copyWith(dukaten: '42');

      final ergebnis = _uebernimm(entwurf: entwurf, aktuell: aktuell);

      expect(ergebnis.talents['tal_klettern']!.talentValue, 7);
      expect(ergebnis.dukaten, '42');
    });

    test('Erzwingen übernimmt nur die bestätigten Bereiche', () {
      final entwurf = _mitKlettern(_basis, 7).copyWith(name: 'Rondrian');
      final aktuell = _mitKlettern(_basis, 9).copyWith(dukaten: '42');

      final ergebnis = _uebernimm(
        entwurf: entwurf,
        aktuell: aktuell,
        erzwungen: {'talents'},
      );

      expect(ergebnis.talents['tal_klettern']!.talentValue, 7);
      expect(ergebnis.name, 'Rondrian');
      expect(ergebnis.dukaten, '42');
    });

    test('ein neuer Konflikt außerhalb der Bestätigung wird gemeldet', () {
      final entwurf = _mitKlettern(_basis, 7).copyWith(name: 'Rondrian');
      final aktuell = _mitKlettern(_basis, 9).copyWith(name: 'Rondriane');

      final konflikt = _konfliktVon(
        () => _uebernimm(
          entwurf: entwurf,
          aktuell: aktuell,
          erzwungen: {'talents'},
        ),
      );

      expect(konflikt.schluessel, {'name'});
    });

    test('AP sind Zähler: beide Seiten tragen ihre Differenz bei', () {
      // Der Entwurf gibt 50 AP aus, anderswo kamen 100 AP hinzu und
      // wurden 30 AP ausgegeben.
      final entwurf = _basis.copyWith(apSpent: 450);
      final aktuell = _basis.copyWith(apTotal: 1100, apSpent: 430);

      final ergebnis = _uebernimm(entwurf: entwurf, aktuell: aktuell);

      expect(ergebnis.apTotal, 1100);
      expect(ergebnis.apSpent, 480);
    });

    test('nur bei Belegung geschriebene Felder zählen als eigener Wert', () {
      final basis = _basis;
      expect(basis.toJson().containsKey('vorteilEintraege'), isFalse);
      // Der Entwurf belegt die Liste, anderswo wurde etwas anderes geändert.
      final entwurf = basis.copyWith(
        vorteilEintraege: const [
          HeroMerkmal(katalogId: 'adv_flink', text: 'Flink'),
        ],
      );
      final aktuell = basis.copyWith(dukaten: '42');

      final ergebnis = _uebernimm(entwurf: entwurf, aktuell: aktuell);

      expect(ergebnis.vorteilEintraege.single.katalogId, 'adv_flink');
      expect(ergebnis.dukaten, '42');
    });

    test('ein im Entwurf geleertes Feld wird geleert', () {
      final basis = _gespeichert(
        _held.copyWith(
          vorteilEintraege: const [
            HeroMerkmal(katalogId: 'adv_flink', text: 'Flink'),
          ],
        ),
      );
      final entwurf = basis.copyWith(vorteilEintraege: const <HeroMerkmal>[]);
      final aktuell = basis.copyWith(dukaten: '42');

      final ergebnis = uebernimmEditorEntwurf(
        basis: basis,
        entwurf: entwurf,
        aktuell: aktuell,
        neueId: _neueId,
      );

      expect(ergebnis.vorteilEintraege, isEmpty);
      expect(ergebnis.dukaten, '42');
    });

    test('ein neuer Kampf-Slot bekommt seine ID aus neueId', () {
      final entwurf = _basis.copyWith(
        combatConfig: _basis.combatConfig.copyWith(
          weapons: <MainWeaponSlot>[
            ..._basis.combatConfig.weaponSlots,
            const MainWeaponSlot(name: 'Dolch'),
          ],
        ),
      );
      final aktuell = _basis.copyWith(dukaten: '42');

      final ergebnis = uebernimmEditorEntwurf(
        basis: _basis,
        entwurf: entwurf,
        aktuell: aktuell,
        neueId: () => 'zufall',
      );

      final ids = ergebnis.combatConfig.weaponSlots.map((slot) => slot.id);
      expect(ids, [_basis.combatConfig.weaponSlots.single.id, 'zufall']);
    });

    test('unbekannte Felder beider Seiten bleiben erhalten', () {
      final basis = _gespeichert(
        _held.copyWith(
          unbekannteFelder: const {'zukunft': 1},
          talents: const <String, HeroTalentEntry>{
            'tal_klettern': HeroTalentEntry(
              talentValue: 4,
              unbekannteFelder: {'neu': 'x'},
            ),
          },
        ),
      );
      final entwurf = basis.copyWith(
        talents: <String, HeroTalentEntry>{
          'tal_klettern': basis.talents['tal_klettern']!.copyWith(
            talentValue: 7,
          ),
        },
      );
      final aktuell = basis.copyWith(
        dukaten: '42',
        unbekannteFelder: const {'zukunft': 2},
      );

      final ergebnis = uebernimmEditorEntwurf(
        basis: basis,
        entwurf: entwurf,
        aktuell: aktuell,
        neueId: _neueId,
      );

      expect(ergebnis.unbekannteFelder, {'zukunft': 2});
      expect(ergebnis.talents['tal_klettern']!.talentValue, 7);
      expect(ergebnis.talents['tal_klettern']!.unbekannteFelder, {'neu': 'x'});
    });

    test('ein inzwischen abgeschlossenes Abenteuer ist nicht erzwingbar', () {
      final basis = _gespeichert(_held.copyWith(adventures: [_abenteuer()]));
      final entwurf = basis.copyWith(
        adventures: [_abenteuer(titel: 'Umbenannt')],
      );
      final aktuell = basis.copyWith(
        adventures: [
          _abenteuer(status: HeroAdventureStatus.completed, belohnt: true),
        ],
      );

      for (final erzwungen in [
        <String>{},
        {'adventures'},
      ]) {
        final konflikt = _konfliktVon(
          () => uebernimmEditorEntwurf(
            basis: basis,
            entwurf: entwurf,
            aktuell: aktuell,
            erzwungen: erzwungen,
            neueId: _neueId,
          ),
        );
        expect(konflikt.schluessel, {'adventures'});
        expect(konflikt.erzwingbar, isFalse);
      }
    });

    test('ein anderswo umbenanntes Abenteuer ist erzwingbar', () {
      final basis = _gespeichert(_held.copyWith(adventures: [_abenteuer()]));
      final entwurf = basis.copyWith(
        adventures: [_abenteuer(titel: 'Hier umbenannt')],
      );
      final aktuell = basis.copyWith(
        adventures: [_abenteuer(titel: 'Dort umbenannt')],
      );

      final konflikt = _konfliktVon(
        () => uebernimmEditorEntwurf(
          basis: basis,
          entwurf: entwurf,
          aktuell: aktuell,
          neueId: _neueId,
        ),
      );
      expect(konflikt.erzwingbar, isTrue);

      final ergebnis = uebernimmEditorEntwurf(
        basis: basis,
        entwurf: entwurf,
        aktuell: aktuell,
        erzwungen: {'adventures'},
        neueId: _neueId,
      );
      expect(ergebnis.adventures.single.title, 'Hier umbenannt');
    });
  });

  group('bucheReiseberichtEntwurf', () {
    const katalog = <ReiseberichtDef>[
      ReiseberichtDef(
        id: 'r1',
        name: 'Erster Ork',
        kategorie: 'kampferfahrungen',
        typ: 'checkpoint',
        ap: 10,
        se: [ReiseberichtSeDef(ziel: 'talent', name: 'tal_klettern')],
      ),
    ];
    const entwurf = HeroReisebericht(checkedIds: {'r1'});

    test('bucht auf den gespeicherten Helden', () {
      final aktuell = _mitKlettern(_basis, 9).copyWith(apTotal: 1100);

      final ergebnis = bucheReiseberichtEntwurf(
        basis: _basis,
        aktuell: aktuell,
        entwurf: entwurf,
        katalog: katalog,
      );

      expect(ergebnis.apTotal, 1110);
      expect(ergebnis.talents['tal_klettern']!.talentValue, 9);
      expect(ergebnis.talents['tal_klettern']!.specialExperiences, 1);
      expect(ergebnis.reisebericht.appliedRewardIds, {'r1'});
    });

    test('Enthaken nimmt auf dem gespeicherten Helden zurück', () {
      final gebucht = _gespeichert(
        _held.copyWith(
          apTotal: 1010,
          talents: const {
            'tal_klettern': HeroTalentEntry(
              talentValue: 4,
              specialExperiences: 1,
            ),
          },
          reisebericht: const HeroReisebericht(
            checkedIds: {'r1'},
            appliedRewardIds: {'r1'},
          ),
        ),
      );
      // Inzwischen anderswo: 100 AP dazu.
      final aktuell = gebucht.copyWith(apTotal: 1110);

      final ergebnis = bucheReiseberichtEntwurf(
        basis: gebucht,
        aktuell: aktuell,
        entwurf: const HeroReisebericht(),
        katalog: katalog,
      );

      expect(ergebnis.apTotal, 1100);
      expect(ergebnis.talents['tal_klettern']!.specialExperiences, 0);
      expect(ergebnis.reisebericht.checkedIds, isEmpty);
      expect(ergebnis.reisebericht.appliedRewardIds, isEmpty);
    });

    test('ein unveränderter Entwurf lässt den gespeicherten Stand', () {
      final aktuell = _basis.copyWith(
        reisebericht: const HeroReisebericht(
          checkedIds: {'r2'},
          appliedRewardIds: {'r2'},
        ),
      );

      final ergebnis = bucheReiseberichtEntwurf(
        basis: _basis,
        aktuell: aktuell,
        entwurf: _basis.reisebericht,
        katalog: katalog,
      );

      expect(identical(ergebnis, aktuell), isTrue);
    });

    test('anderswo gebuchte Belohnungen werden nie doppelt gebucht', () {
      final aktuell = _basis.copyWith(
        apTotal: 1010,
        reisebericht: const HeroReisebericht(
          checkedIds: {'r1'},
          appliedRewardIds: {'r1'},
        ),
      );

      for (final erzwingen in [false, true]) {
        final konflikt = _konfliktVon(
          () => bucheReiseberichtEntwurf(
            basis: _basis,
            aktuell: aktuell,
            entwurf: entwurf,
            katalog: katalog,
            erzwingen: erzwingen,
          ),
        );
        expect(konflikt.schluessel, {'reisebericht'});
        expect(konflikt.erzwingbar, isFalse);
      }
    });

    test('ein anderswo geänderter Haken ist erzwingbar', () {
      final aktuell = _basis.copyWith(
        reisebericht: const HeroReisebericht(checkedIds: {'r2'}),
      );

      final konflikt = _konfliktVon(
        () => bucheReiseberichtEntwurf(
          basis: _basis,
          aktuell: aktuell,
          entwurf: entwurf,
          katalog: katalog,
        ),
      );
      expect(konflikt.erzwingbar, isTrue);

      final ergebnis = bucheReiseberichtEntwurf(
        basis: _basis,
        aktuell: aktuell,
        entwurf: entwurf,
        katalog: katalog,
        erzwingen: true,
      );
      expect(ergebnis.reisebericht.checkedIds, {'r1'});
      expect(ergebnis.apTotal, 1010);
    });
  });
}
