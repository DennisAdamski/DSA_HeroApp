import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ausweichen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fernkampf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

const _zustand = HeroState(
  currentLep: 0,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 0,
);

const _zustandMitAxx = HeroState(
  currentLep: 0,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 0,
  activeSpellEffects: ActiveSpellEffectsState(
    activeEffectIds: <String>[activeSpellEffectAxxeleratus],
  ),
);

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

HeroSheet _held({
  CombatConfig combatConfig = const CombatConfig(),
  Map<String, HeroTalentEntry> talents = const <String, HeroTalentEntry>{},
  Attributes attribute = _attribute,
}) {
  return HeroSheet(
    id: 'h',
    name: 'Testheld',
    level: 10,
    attributes: attribute,
    talents: talents,
    combatConfig: combatConfig,
    vorteileText: '',
    nachteileText: '',
  );
}

HerleitungsSchritt _schritt(Herleitung h, String bezeichnung) =>
    h.schritte.singleWhere((s) => s.bezeichnung == bezeichnung);

List<String> _sichtbar(Herleitung h) =>
    h.sichtbareSchritte.map((s) => s.bezeichnung).toList();

/// Jede Herleitung gleicht dem Feld, das die übrige App verwendet.
void _pruefeGleichheit(CombatPreviewStats c, {String reason = ''}) {
  final h = c.herleitungen!;
  expect(h.rs.wert, c.rsTotal, reason: '$reason RS');
  expect(h.beKampf.wert, c.beKampf, reason: '$reason BE');
  expect(h.ebe.wert, c.ebe, reason: '$reason eBE');
  expect(h.at.wert, c.at, reason: '$reason AT');
  expect(h.pa?.wert ?? 0, c.pa, reason: '$reason PA');
  expect(
    h.paMitIniParade?.wert ?? 0,
    c.paMitIniParadeMod,
    reason: '$reason PA mit INI',
  );
  expect(h.tpZuschlag.wert, c.tpCalc, reason: '$reason TP');
  expect(h.heldenIni.wert, c.heldenInitiative, reason: '$reason Helden-INI');
  expect(h.kampfIni.wert, c.kampfInitiative, reason: '$reason Kampf-INI');
  expect(h.ausweichen.wert, c.ausweichen, reason: '$reason Ausweichen');
  expect(h.schildPa == null, !c.offhandIsShield, reason: '$reason Schild');
  if (h.schildPa case final schild?) {
    expect(schild.wert, c.shieldPa, reason: '$reason Schild-PA');
  }
  expect(
    h.schildPaMitIniParade == null,
    !c.offhandIsShield,
    reason: '$reason Schild mit INI',
  );
  if (h.schildPaMitIniParade case final schild?) {
    expect(
      schild.wert,
      c.shieldPa + c.iniParadeMod,
      reason: '$reason Schild-PA mit INI',
    );
    expect(
      c.offhandPreview!.shieldPaMitIniParadeMod,
      schild.wert,
      reason: '$reason Schild-PA mit INI in der Vorschau',
    );
    expect(
      schild.schritte.map((e) => e.bezeichnung),
      contains('INI-Parade-Bonus'),
    );
  }
  final neben = c.offhandPreview;
  if (neben != null && neben.isWeapon) {
    final nh = neben.herleitungen!;
    expect(nh.at.wert, neben.at, reason: '$reason Nebenhand AT');
    expect(nh.pa?.wert ?? 0, neben.pa, reason: '$reason Nebenhand PA');
    expect(nh.tpZuschlag.wert, neben.tpCalc, reason: '$reason Nebenhand TP');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Begrenzungen', () {
    test('mitObergrenze gleicht nur Überschreitungen aus', () {
      const schritte = <HerleitungsSchritt>[
        HerleitungsSchritt(
          bezeichnung: 'A',
          betrag: 2,
          art: HerleitungsArt.grundwert,
        ),
      ];
      final begrenzt = mitObergrenze(
        schritte,
        obergrenze: 0,
        bezeichnung: 'Höchstens 0',
      );
      expect(summeDer(begrenzt), 0);
      expect(begrenzt.last.art, HerleitungsArt.begrenzung);
      expect(
        mitObergrenze(schritte, obergrenze: 5, bezeichnung: 'x'),
        same(schritte),
      );
    });

    test('eBE bleibt höchstens 0, auch bei negativer Talentregel', () {
      final h = herleiteEbe(beKampf: 0, beMod: -2, talentBe: '+2');
      expect(h.wert, 0);
      expect(_sichtbar(h), contains('Höchstens 0'));
    });

    test('schwere Rüstung: Ausweichen bleibt 0, Begrenzung sichtbar', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            armor: ArmorConfig(
              pieces: <ArmorPiece>[
                ArmorPiece(
                  name: 'Plattenrüstung',
                  isActive: true,
                  rs: 6,
                  be: 20,
                ),
              ],
            ),
          ),
        ),
        _zustand,
      );
      final h = c.herleitungen!;
      expect(c.ausweichen, 0);
      expect(_sichtbar(h.ausweichen), contains('Untergrenze 0'));
      expect(_schritt(h.ausweichen, 'BE Kampf').betrag, -20);
      expect(_schritt(h.rs, 'Plattenrüstung').betrag, 6);
      _pruefeGleichheit(c);
    });
  });

  group('Nahkampf', () {
    test('Axxeleratus: Ausweichen zeigt PA-Basis, Axx-PA und Axx-Bonus', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            mainWeapon: MainWeaponSlot(tpFlat: 4, kkBase: 12, kkThreshold: 2),
          ),
        ),
        _zustandMitAxx,
      );
      final h = c.herleitungen!;
      expect(_schritt(h.ausweichen, 'PA-Basis').betrag, c.paBase - 2);
      expect(_schritt(h.ausweichen, 'Axxeleratus PA').betrag, 2);
      expect(_schritt(h.ausweichen, 'Axxeleratus').betrag, 2);
      expect(_schritt(h.pa!, 'Axxeleratus PA').betrag, 2);
      expect(_schritt(h.tpZuschlag, 'Axxeleratus').betrag, 2);
      // Gleich der bisherigen Einzelformel.
      expect(
        c.ausweichen,
        computeAusweichen(
          paBase: c.paBase,
          sfAusweichenBonus: c.sfAusweichenBonus,
          akrobatikBonus: c.akrobatikBonus,
          axxAusweichenBonus: c.axxAusweichenBonus,
          iniAusweichenBonus: c.iniAusweichenBonus,
          ausweichenMod: c.ausweichenMod,
          beKampf: c.beKampf,
        ),
      );
      _pruefeGleichheit(c);
    });

    test('AT-Basis ist ein eigener Schritt, kein Restwert', () {
      final c = computeCombatPreviewStats(
        _held(
          talents: const <String, HeroTalentEntry>{
            'tal_schwerter': HeroTalentEntry(
              talentValue: 8,
              atValue: 5,
              paValue: 3,
            ),
          },
          combatConfig: const CombatConfig(
            mainWeapon: MainWeaponSlot(
              name: 'Schwert',
              talentId: 'tal_schwerter',
              wmAt: 1,
              wmPa: -1,
            ),
            manualMods: CombatManualMods(atMod: 2, paMod: -1),
          ),
        ),
        _zustand,
      );
      final h = c.herleitungen!;
      final atBasis = _schritt(h.at, 'AT-Basis');
      expect(atBasis.art, HerleitungsArt.grundwert);
      expect(_schritt(h.at, 'Talent AT-Anteil').betrag, 5);
      expect(_schritt(h.at, 'WM AT (Waffe)').betrag, 1);
      expect(_schritt(h.at, 'Manueller Mod').betrag, 2);
      expect(_schritt(h.pa!, 'Talent PA-Anteil').betrag, 3);
      expect(h.paMitIniParade!.wert - h.pa!.wert, c.iniParadeMod);
      _pruefeGleichheit(c);
    });

    test('Schwertarmwunde erscheint als Wundschritt in AT und PA', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            mainWeapon: MainWeaponSlot(name: 'Schwert'),
          ),
        ),
        _zustand,
        wunden: const WundEffekte(schwertarmAtPaMalus: -2),
      );
      final h = c.herleitungen!;
      expect(_schritt(h.at, 'Wunden Schwertarm').betrag, -2);
      expect(_schritt(h.pa!, 'Wunden Schwertarm').betrag, -2);
      _pruefeGleichheit(c);
    });

    test('Rüstungsgewöhnung mindert die BE als eigener Schritt', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            armor: ArmorConfig(
              globalArmorTrainingLevel: 2,
              pieces: <ArmorPiece>[
                ArmorPiece(name: 'Kettenhemd', isActive: true, rs: 3, be: 3),
              ],
            ),
          ),
        ),
        _zustand,
      );
      final h = c.herleitungen!;
      final rg = _schritt(h.beKampf, 'Rüstungsgewöhnung');
      expect(rg.betrag, -1);
      expect(rg.quelle, 'Rüstungsgewöhnung II');
      expect(c.beKampf, 2);
      expect(_schritt(h.ebe, 'BE Kampf').betrag, -2);
      _pruefeGleichheit(c);
    });
  });

  group('Initiative', () {
    test('Nebenhandausrüstung senkt die Kampf-INI über ihren Modifikator', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            mainWeapon: MainWeaponSlot(iniMod: 3),
            offhandAssignment: OffhandAssignment(equipmentIndex: 0),
            offhandEquipment: <OffhandEquipmentEntry>[
              OffhandEquipmentEntry(
                type: OffhandEquipmentType.shield,
                iniMod: -1,
              ),
            ],
            manualMods: CombatManualMods(iniWurf: 2),
          ),
        ),
        _zustand,
      );
      final h = c.herleitungen!;
      expect(_schritt(h.kampfIni, 'Nebenhand INI').betrag, -1);
      expect(_schritt(h.kampfIni, 'INI-Wurf').betrag, 2);
      expect(_schritt(h.kampfIni, 'Waffen-INI Mod').betrag, 3);
      _pruefeGleichheit(c);
    });

    test('schnellere Nebenhandwaffe erscheint als eigener Schritt', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(
                name: 'Kurzschwert',
                iniMod: 1,
                kkBase: 12,
                kkThreshold: 2,
              ),
              MainWeaponSlot(
                name: 'Dolch',
                iniMod: 4,
                kkBase: 14,
                kkThreshold: 1,
              ),
            ],
            selectedWeaponIndex: 0,
            offhandAssignment: OffhandAssignment(weaponIndex: 1),
          ),
        ),
        _zustand,
      );
      final h = c.herleitungen!;
      final schritt = _schritt(h.kampfIni, 'Höhere INI der Nebenhandwaffe');
      expect(
        schritt.betrag,
        c.offhandWeaponInitiative! - c.kombinierteHeldenWaffenIni,
      );
      expect(schritt.quelle, 'Dolch');
      _pruefeGleichheit(c);
    });

    test('negative Helden-INI wird sichtbar auf 0 begrenzt', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            manualMods: CombatManualMods(iniMod: -40),
          ),
        ),
        _zustand,
      );
      final h = c.herleitungen!;
      expect(c.heldenInitiative, 0);
      expect(_sichtbar(h.heldenIni), contains('Untergrenze 0'));
      _pruefeGleichheit(c);
    });
  });

  group('Schild und Parierwaffe', () {
    CombatPreviewStats mitNebenhand(
      OffhandEquipmentEntry ausruestung,
      CombatSpecialRules sf, {
      WundEffekte wunden = const WundEffekte(),
      ArmorConfig ruestung = const ArmorConfig(),
    }) {
      return computeCombatPreviewStats(
        _held(
          combatConfig: CombatConfig(
            mainWeapon: const MainWeaponSlot(name: 'Schwert', wmPa: 0),
            offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
            offhandEquipment: <OffhandEquipmentEntry>[ausruestung],
            specialRules: sf,
            armor: ruestung,
          ),
        ),
        _zustandMitAxx,
        wunden: wunden,
      );
    }

    const schild = OffhandEquipmentEntry(
      name: 'Holzschild',
      type: OffhandEquipmentType.shield,
      paMod: 3,
    );

    for (final (sf, bonus, name) in <(CombatSpecialRules, int, String?)>[
      (const CombatSpecialRules(), 0, null),
      (const CombatSpecialRules(linkhandActive: true), 1, 'Linkhand'),
      (const CombatSpecialRules(schildkampfI: true), 3, 'Schildkampf I'),
      (
        const CombatSpecialRules(schildkampfI: true, schildkampfII: true),
        5,
        'Schildkampf II',
      ),
    ]) {
      test('Schild-PA mit SF-Bonus $bonus aus ${name ?? 'keiner SF'}', () {
        final c = mitNebenhand(
          schild,
          sf,
          wunden: const WundEffekte(schildarmAtPaMalus: -2),
          ruestung: const ArmorConfig(
            pieces: <ArmorPiece>[
              ArmorPiece(name: 'Kettenhemd', isActive: true, rs: 3, be: 3),
            ],
          ),
        );
        final h = c.herleitungen!.schildPa!;
        expect(h.bezeichnung, 'Schild-PA');
        expect(_schritt(h, 'PA-Basis').betrag, c.paBase - 2);
        expect(_schritt(h, 'Axxeleratus PA').betrag, 2);
        expect(_schritt(h, 'Schild-WM').betrag, 3);
        expect(_schritt(h, 'Schild-WM').quelle, 'Holzschild');
        expect(_schritt(h, 'SF Schildkampf').betrag, bonus);
        expect(_schritt(h, 'SF Schildkampf').quelle, name);
        expect(_schritt(h, 'eBE PA-Anteil').betrag, -2);
        expect(_schritt(h, 'Wunden Schildarm').betrag, -2);
        expect(c.shieldPaBonus, 3 + bonus);
        _pruefeGleichheit(c);
      });
    }

    for (final (sf, bonus, name) in <(CombatSpecialRules, int, String)>[
      (
        const CombatSpecialRules(linkhandActive: true),
        -4,
        'ohne Parierwaffen-SF',
      ),
      (
        const CombatSpecialRules(linkhandActive: true, parierwaffenI: true),
        -1,
        'Parierwaffen I',
      ),
      (
        const CombatSpecialRules(
          linkhandActive: true,
          parierwaffenI: true,
          parierwaffenII: true,
        ),
        2,
        'Parierwaffen II',
      ),
    ]) {
      test('Parierwaffe: WM und SF $name als getrennte Schritte', () {
        final c = mitNebenhand(
          const OffhandEquipmentEntry(name: 'Linkhand-Dolch', paMod: 1),
          sf,
        );
        final pa = c.herleitungen!.pa!;
        expect(_schritt(pa, 'Nebenhand PA').betrag, 1);
        expect(_schritt(pa, 'Nebenhand PA').quelle, 'Linkhand-Dolch');
        expect(_schritt(pa, 'SF Parierwaffen').betrag, bonus);
        expect(_schritt(pa, 'SF Parierwaffen').quelle, name);
        expect(c.offhandPaBonus, 1 + bonus);
        expect(c.herleitungen!.schildPa, isNull);
        _pruefeGleichheit(c);
      });
    }

    test('Parierwaffe ohne Linkhand bringt keinen PA-Anteil', () {
      final c = mitNebenhand(
        const OffhandEquipmentEntry(name: 'Linkhand-Dolch', paMod: 1),
        const CombatSpecialRules(),
      );
      final pa = c.herleitungen!.pa!;
      expect(_schritt(pa, 'Nebenhand PA').betrag, 0);
      expect(_schritt(pa, 'SF Parierwaffen').betrag, 0);
      expect(c.offhandRequiresLinkhand, isTrue);
      _pruefeGleichheit(c);
    });
  });

  group('Nebenhandwaffe', () {
    test('AT und PA enthalten Basis, falsche Hand und Schildarmwunde', () {
      final c = computeCombatPreviewStats(
        _held(
          combatConfig: const CombatConfig(
            weapons: <MainWeaponSlot>[
              MainWeaponSlot(name: 'Kurzschwert'),
              MainWeaponSlot(name: 'Dolch', wmAt: 1),
            ],
            selectedWeaponIndex: 0,
            offhandAssignment: OffhandAssignment(weaponIndex: 1),
          ),
        ),
        _zustand,
        wunden: const WundEffekte(schildarmAtPaMalus: -2),
      );
      final neben = c.offhandPreview!;
      final nh = neben.herleitungen!;
      expect(_schritt(nh.at, 'AT-Basis').art, HerleitungsArt.grundwert);
      expect(_schritt(nh.pa!, 'PA-Basis').art, HerleitungsArt.grundwert);
      expect(_schritt(nh.at, 'Wunden Schildarm').betrag, -2);
      expect(_schritt(nh.at, 'WM AT (Waffe)').betrag, 1);
      final falscheHand = nh.at.schritte.where(
        (s) => s.betrag == neben.falseHandAtMod && s.betrag != 0,
      );
      if (neben.falseHandAtMod != 0) {
        expect(falscheHand, isNotEmpty);
      }
      _pruefeGleichheit(c);
    });
  });

  group('Fernkampf', () {
    test('FK enthält genau die Summanden von computeRangedAtValue', () {
      final c = computeCombatPreviewStats(
        _held(
          talents: const <String, HeroTalentEntry>{
            'tal_boegen': HeroTalentEntry(
              talentValue: 7,
              atValue: 1,
              combatSpecializations: <String>['Kurzbogen'],
            ),
          },
          combatConfig: const CombatConfig(
            mainWeapon: MainWeaponSlot(
              name: 'Kurzbogen',
              talentId: 'tal_boegen',
              combatType: WeaponCombatType.ranged,
              weaponType: 'Kurzbogen',
              wmAt: 2,
            ),
            manualMods: CombatManualMods(atMod: 1, iniWurf: 3),
          ),
        ),
        _zustandMitAxx,
      );
      final h = c.herleitungen!;
      expect(h.at.bezeichnung, 'FK');
      expect(_schritt(h.at, 'FK-Basis').betrag, c.rangedAtBase);
      expect(_schritt(h.at, 'Spezialisierung').betrag, 2);
      expect(
        c.at,
        computeRangedAtValue(
          rangedAtBase: c.rangedAtBase,
          talentAtValue: 1,
          weaponAtMod: 2,
          ebeAttackPart: c.ebe,
          specializationBonus: c.specBonus,
          projectileAtMod: c.projectileAtMod,
          manualAtMod: 1,
        ),
      );
      expect(h.pa, isNull);
      expect(h.paMitIniParade, isNull);
      // Fernkampf-INI zeigt Wurf und Axxeleratus wie der Nahkampf.
      expect(_schritt(h.kampfIni, 'INI-Wurf').betrag, 3);
      expect(_schritt(h.kampfIni, 'Axxeleratus').betrag, c.axxIniBonus);
      // Axxeleratus wirkt im Fernkampf nicht auf die TP.
      expect(_schritt(h.tpZuschlag, 'Axxeleratus').betrag, 0);
      _pruefeGleichheit(c);
    });
  });

  group('Zaubereffekt im Fernkampf', () {
    test(
      'Blitz-Erschwernis ist ein Schritt und zählt in computeRangedAtValue',
      () {
        final h = herleiteFernkampfAt(
          fkBasis: 9,
          talentAt: 6,
          waffenWm: 1,
          ebe: -1,
          spezialisierung: 0,
          zauberMalus: -4,
          zauberName: 'Blitz dich find',
        );
        expect(_schritt(h, 'Blitz dich find').betrag, -4);
        expect(
          h.wert,
          computeRangedAtValue(
            rangedAtBase: 9,
            talentAtValue: 6,
            weaponAtMod: 1,
            ebeAttackPart: -1,
            specializationBonus: 0,
            projectileAtMod: 0,
            manualAtMod: 0,
            zauberMalus: -4,
          ),
        );
        expect(
          herleiteFernkampfAt(
            fkBasis: 9,
            talentAt: 6,
            waffenWm: 1,
            ebe: -1,
            spezialisierung: 0,
          ).schritte.where((s) => s.art == HerleitungsArt.zauber),
          isEmpty,
        );
      },
    );

    test('TP/KK-Schritt eines Zaubers zeigt die veränderte KK', () {
      final h = herleiteTpZuschlag(
        tpGrundwert: 4,
        nutztTpKk: true,
        tpKk: 0,
        kk: 13,
        kkBasis: 12,
        kkSchwelle: 3,
        zauberTpKk: 2,
        zauberKk: 5,
        zauberName: 'Karnifilo Raserei',
      );
      final schritt = _schritt(h, 'Karnifilo Raserei (KK +5)');
      expect(schritt.betrag, 2);
      expect(schritt.formel, contains('KK 18'));
      expect(h.wert, 6);
      // Ohne TP/KK-Regel (0/0) gibt es keinen Zauberanteil.
      expect(
        herleiteTpZuschlag(
          tpGrundwert: 4,
          nutztTpKk: false,
          tpKk: 0,
          kk: 13,
          kkBasis: 0,
          kkSchwelle: 0,
          zauberKk: 5,
        ).wert,
        4,
      );
    });
  });

  group('Waffenmeister im Fernkampf', () {
    // Nutzerentscheidung (14.10.2026): Der AT-WM-Bonus gilt auch für
    // Fernkampfwaffen, sonst wäre er dort wirkungslos.
    CombatPreviewStats vorschau({required bool waffenmeister}) =>
        computeCombatPreviewStats(
          _held(
            talents: const <String, HeroTalentEntry>{
              'tal_boegen': HeroTalentEntry(talentValue: 7, atValue: 1),
            },
            combatConfig: CombatConfig(
              mainWeapon: const MainWeaponSlot(
                name: 'Kurzbogen',
                talentId: 'tal_boegen',
                combatType: WeaponCombatType.ranged,
                weaponType: 'Kurzbogen',
                wmAt: 2,
              ),
              waffenmeisterschaften: [
                if (waffenmeister)
                  const WaffenmeisterConfig(
                    talentId: 'tal_boegen',
                    weaponType: 'Kurzbogen',
                    bonuses: [
                      WaffenmeisterBonus(
                        type: WaffenmeisterBonusType.atWmBonus,
                        value: 2,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _zustand,
        );

    test('FK enthält den Waffenmeister-Bonus als eigenen Schritt', () {
      final ohne = vorschau(waffenmeister: false);
      final mit = vorschau(waffenmeister: true);
      expect(mit.waffenmeisterAtBonus, 2);
      expect(_schritt(mit.herleitungen!.at, 'Waffenmeister AT').betrag, 2);
      expect(_schritt(ohne.herleitungen!.at, 'Waffenmeister AT').betrag, 0);
      expect(mit.at, ohne.at + 2);
      expect(
        mit.at,
        computeRangedAtValue(
          rangedAtBase: mit.rangedAtBase,
          talentAtValue: 1,
          weaponAtMod: 2,
          waffenmeisterAtBonus: 2,
          ebeAttackPart: mit.ebe,
          specializationBonus: mit.specBonus,
          projectileAtMod: mit.projectileAtMod,
          manualAtMod: 0,
        ),
      );
      _pruefeGleichheit(mit);
    });
  });

  group('Bestandshelden', () {
    late EchterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    for (final bestand in Bestandsheld.values) {
      test('${bestand.datei}: Kampfherleitungen gleichen der Vorschau', () {
        final bundle = ladeBestandsheld(bestand);
        for (final zustand in <HeroState>[
          bundle.state,
          bundle.state.copyWith(
            wpiZustand: const WundZustand(
              wundenProZone: <WundZone, int>{
                WundZone.rechterArm: 1,
                WundZone.linkerArm: 1,
              },
            ),
            activeSpellEffects: const ActiveSpellEffectsState(
              activeEffectIds: <String>[activeSpellEffectAxxeleratus],
            ),
          ),
        ]) {
          final snapshot = buildHeroComputedSnapshot(
            hero: bundle.hero,
            state: zustand,
            catalog: katalog.catalog,
            epicAdvantagesActive: true,
          );
          _pruefeGleichheit(snapshot.combatPreviewStats, reason: bestand.datei);
        }
      });
    }
  });
}
