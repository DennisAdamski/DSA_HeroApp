import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

// Armwunden wirken nur auf die Waffe in diesem Arm (WdS S. 109: „wenn er
// diesen Arm benutzt“). Rechts ist der Schwertarm, mit Linkshänder links.
void main() {
  const attribute = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );
  const schwert = MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 3);
  const dolch = MainWeaponSlot(name: 'Dolch', kkBase: 12, kkThreshold: 3);
  const bogen = MainWeaponSlot(
    name: 'Kurzbogen',
    combatType: WeaponCombatType.ranged,
  );
  const schild = OffhandEquipmentEntry(
    name: 'Holzschild',
    type: OffhandEquipmentType.shield,
    paMod: 3,
  );
  const parierwaffe = OffhandEquipmentEntry(
    name: 'Linkhand',
    type: OffhandEquipmentType.parryWeapon,
    paMod: 1,
  );

  HeroSheet held(CombatConfig config, {String vorteile = ''}) => HeroSheet(
    id: 'h',
    name: 'Test',
    level: 1,
    attributes: attribute,
    vorteileText: vorteile,
    combatConfig: config,
  );

  HeroComputedSnapshot rechne(
    HeroSheet held, [
    Map<WundZone, int> wunden = const <WundZone, int>{},
  ]) {
    return buildHeroComputedSnapshot(
      hero: held,
      state: HeroState(
        currentLep: 20,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 20,
        wpiZustand: WundZustand(wundenProZone: wunden),
      ),
      catalog: null,
      epicAdvantagesActive: false,
    );
  }

  const mitSchild = CombatConfig(
    mainWeapon: schwert,
    offhandAssignment: OffhandAssignment(equipmentIndex: 0),
    offhandEquipment: <OffhandEquipmentEntry>[schild],
  );

  test('Schildarmwunde senkt nur die Schild-PA', () {
    final ohne = rechne(held(mitSchild)).combatPreviewStats;
    final mit = rechne(held(mitSchild), const {
      WundZone.linkerArm: 1,
    }).combatPreviewStats;
    // Allgemein −2 auf alles, der Armanteil −2 nur auf den Schild.
    expect(mit.at, ohne.at - 2);
    expect(mit.pa, ohne.pa - 2);
    expect(mit.shieldPa, ohne.shieldPa - 4);
    expect(mit.schwertarmWundMalus, 0);
    expect(mit.schildarmWundMalus, -2);
  });

  test('Schwertarmwunde senkt nur die Hauptwaffe', () {
    final ohne = rechne(held(mitSchild)).combatPreviewStats;
    final mit = rechne(held(mitSchild), const {
      WundZone.rechterArm: 1,
    }).combatPreviewStats;
    expect(mit.at, ohne.at - 4);
    expect(mit.pa, ohne.pa - 4);
    expect(mit.shieldPa, ohne.shieldPa - 2);
    expect(mit.schwertarmWundMalus, -2);
  });

  test('Linkshänder tauscht die Arme', () {
    final linkshaender = held(mitSchild, vorteile: 'Linkshänder');
    final ohne = rechne(linkshaender).combatPreviewStats;
    final links = rechne(linkshaender, const {
      WundZone.linkerArm: 1,
    }).combatPreviewStats;
    expect(links.at, ohne.at - 4, reason: 'links ist jetzt der Schwertarm');
    expect(links.shieldPa, ohne.shieldPa - 2);
    final rechts = rechne(linkshaender, const {
      WundZone.rechterArm: 1,
    }).combatPreviewStats;
    expect(rechts.at, ohne.at - 2);
    expect(rechts.shieldPa, ohne.shieldPa - 4);
  });

  test('Nebenhandwaffe liegt im Schildarm', () {
    const zweiWaffen = CombatConfig(
      weapons: <MainWeaponSlot>[schwert, dolch],
      selectedWeaponIndex: 0,
      offhandAssignment: OffhandAssignment(weaponIndex: 1),
    );
    final ohne = rechne(held(zweiWaffen)).combatPreviewStats;
    final mit = rechne(held(zweiWaffen), const {
      WundZone.linkerArm: 1,
    }).combatPreviewStats;
    expect(mit.at, ohne.at - 2);
    expect(mit.offhandPreview!.at, ohne.offhandPreview!.at! - 4);
    expect(mit.offhandPreview!.pa, ohne.offhandPreview!.pa! - 4);
    expect(mit.offhandPreview!.schildarmWundMalus, -2);
  });

  test('Fernkampf trägt keinen Armanteil', () {
    const fernkampf = CombatConfig(mainWeapon: bogen);
    final ohne = rechne(held(fernkampf)).combatPreviewStats;
    final mit = rechne(held(fernkampf), const {
      WundZone.rechterArm: 1,
    }).combatPreviewStats;
    expect(mit.at, ohne.at - 2, reason: 'nur der allgemeine FK-Abzug');
    expect(mit.schwertarmWundMalus, 0);
  });

  test('eine Parierwaffe hat keine eigene PA: Haupt-PA nur Schwertarm', () {
    const mitParierwaffe = CombatConfig(
      mainWeapon: schwert,
      offhandAssignment: OffhandAssignment(equipmentIndex: 0),
      offhandEquipment: <OffhandEquipmentEntry>[parierwaffe],
    );
    final ohne = rechne(held(mitParierwaffe)).combatPreviewStats;
    final schildarm = rechne(held(mitParierwaffe), const {
      WundZone.linkerArm: 1,
    }).combatPreviewStats;
    expect(schildarm.pa, ohne.pa - 2);
  });

  test('ohne abgeleitete Werte rechnet die Vorschau dieselben Wunden', () {
    final snapshot = rechne(held(mitSchild), const {
      WundZone.linkerArm: 1,
      WundZone.brust: 1,
    });
    final ersatz = computeCombatPreviewStats(
      snapshot.hero,
      snapshot.state,
      wunden: snapshot.wundEffekte,
    );
    expect(ersatz.at, snapshot.combatPreviewStats.at);
    expect(ersatz.pa, snapshot.combatPreviewStats.pa);
    expect(ersatz.shieldPa, snapshot.combatPreviewStats.shieldPa);
  });

  test('Wunden ändern keine abgeleiteten Werte über Eigenschaften', () {
    final ohne = rechne(held(mitSchild));
    final mit = rechne(held(mitSchild), const {
      WundZone.kopf: 1,
      WundZone.brust: 1,
      WundZone.linkerArm: 1,
    });
    // Eigenschaftsverluste nur für Proben (WdS S. 111).
    expect(mit.effectiveAttributes.toJson(), ohne.effectiveAttributes.toJson());
    expect(mit.derivedStats.maxLep, ohne.derivedStats.maxLep);
    expect(mit.derivedStats.maxAu, ohne.derivedStats.maxAu);
    expect(mit.derivedStats.mr, ohne.derivedStats.mr);
    expect(mit.wundschwelle, ohne.wundschwelle);
    expect(
      mit.combatPreviewStats.tpExpression,
      ohne.combatPreviewStats.tpExpression,
    );
    expect(mit.probenEigenschaften.mu, ohne.probenEigenschaften.mu - 2);
    expect(mit.probenEigenschaften.ge, ohne.probenEigenschaften.ge - 6);
    expect(mit.probenEigenschaften.kk, ohne.probenEigenschaften.kk - 3);
    expect(mit.probenEigenschaften.ko, ohne.probenEigenschaften.ko - 1);
    expect(mit.probenEigenschaften.ff, ohne.probenEigenschaften.ff - 2);
  });

  test('Wunden senken die GS nie unter 1', () {
    final ohne = rechne(held(mitSchild));
    expect(ohne.derivedStats.gs, 8);
    final beine = rechne(held(mitSchild), const {
      WundZone.linkesBein: 3,
      WundZone.rechtesBein: 3,
    });
    // 6 Beinwunden: GS −12 rechnerisch, begrenzt auf 1.
    expect(beine.derivedStats.gs, 1);
  });
}
