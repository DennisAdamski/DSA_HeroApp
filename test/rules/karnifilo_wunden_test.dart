import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/real_catalog.dart';

// Karnifilo Raserei (LC S. 136): Wunden mindern AT und PA nicht und machen
// nicht kampfunfähig; FK, INI-Basis, GS und Probenverluste bleiben.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

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
  const held = HeroSheet(
    id: 'h',
    name: 'Test',
    level: 1,
    attributes: attribute,
    combatConfig: CombatConfig(
      mainWeapon: MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 3),
      offhandAssignment: OffhandAssignment(equipmentIndex: 0),
      offhandEquipment: <OffhandEquipmentEntry>[
        OffhandEquipmentEntry(
          name: 'Holzschild',
          type: OffhandEquipmentType.shield,
          paMod: 3,
        ),
      ],
    ),
  );

  HeroComputedSnapshot rechne({
    Map<WundZone, int> wunden = const <WundZone, int>{},
    bool karnifilo = false,
  }) {
    var zustand = HeroState(
      currentLep: 30,
      currentAsp: 0,
      currentKap: 0,
      currentAu: 30,
      wpiZustand: WundZustand(wundenProZone: wunden),
    );
    if (karnifilo) {
      zustand = aktiviereEffektInstanz(
        zustand,
        const SpellEffectInstance(
          id: 'k',
          effectId: kKarnifiloZauberId,
          zfpStern: 5,
        ),
      );
    }
    return buildHeroComputedSnapshot(
      hero: held,
      state: zustand,
      catalog: katalog,
      epicAdvantagesActive: false,
    );
  }

  test('Wunden mindern AT und PA im Kampfrausch nicht, auch die Armwunden', () {
    const wunden = {WundZone.rechterArm: 1, WundZone.linkerArm: 1};
    final rausch = rechne(karnifilo: true).combatPreviewStats;
    final rauschVerwundet = rechne(
      karnifilo: true,
      wunden: wunden,
    ).combatPreviewStats;

    expect(rauschVerwundet.at, rausch.at);
    expect(rauschVerwundet.pa, rausch.pa);
    expect(rauschVerwundet.shieldPa, rausch.shieldPa);
    expect(rauschVerwundet.schwertarmWundMalus, 0);
    expect(rauschVerwundet.schildarmWundMalus, 0);

    // Gegenprobe ohne Karnifilo: dieselben Wunden wirken.
    final ohne = rechne().combatPreviewStats;
    final verwundet = rechne(wunden: wunden).combatPreviewStats;
    expect(verwundet.at, lessThan(ohne.at));
  });

  test('INI-Basis, GS und Probenverluste der Wunden bleiben', () {
    const wunden = {WundZone.rechtesBein: 2};
    final ohne = rechne();
    final verwundet = rechne(wunden: wunden);
    final rausch = rechne(karnifilo: true);
    final rauschVerwundet = rechne(karnifilo: true, wunden: wunden);

    expect(
      rauschVerwundet.derivedStats.iniBase - rausch.derivedStats.iniBase,
      verwundet.derivedStats.iniBase - ohne.derivedStats.iniBase,
    );
    expect(
      rauschVerwundet.derivedStats.gs - rausch.derivedStats.gs,
      verwundet.derivedStats.gs - ohne.derivedStats.gs,
    );
    expect(
      rauschVerwundet.probenEigenschaften.ge - rausch.probenEigenschaften.ge,
      verwundet.probenEigenschaften.ge - ohne.probenEigenschaften.ge,
    );
  });

  test('dritte Brustwunde: im Kampfrausch nicht kampfunfähig, mit Hinweis', () {
    const wunden = {WundZone.brust: 3};
    expect(rechne(wunden: wunden).wundEffekte.kampfunfaehig, isTrue);

    final rausch = rechne(karnifilo: true, wunden: wunden).wundEffekte;
    expect(rausch.kampfunfaehig, isFalse);
    expect(rausch.zonenMitDritterWunde, contains(WundZone.brust));
    expect(
      rausch.hinweise.where((h) => h.startsWith('Karnifilo Raserei')),
      hasLength(1),
    );
  });

  test('ohne Wunden bleibt das Ergebnis unverändert', () {
    const leer = WundEffekte();
    expect(
      identical(wundEffekteImKampfrausch(leer, quelle: 'Karnifilo'), leer),
      isTrue,
    );
  });

  test('wundEffekteImKampfrausch nimmt nur AT/PA und Kampfunfähigkeit', () {
    const effekte = WundEffekte(
      atMalus: -2,
      paMalus: -2,
      fkMalus: -2,
      iniBasisMalus: -2,
      gsMalus: -1,
      schwertarmAtPaMalus: -2,
      schildarmAtPaMalus: -2,
      eigenschaftsVerluste: AttributeModifiers(ge: -2),
      kampfunfaehig: true,
      linkshaender: true,
    );
    final rausch = wundEffekteImKampfrausch(effekte, quelle: 'Karnifilo');

    expect(rausch.atMalus, 0);
    expect(rausch.paMalus, 0);
    expect(rausch.schwertarmAtPaMalus, 0);
    expect(rausch.schildarmAtPaMalus, 0);
    expect(rausch.kampfunfaehig, isFalse);
    expect(rausch.fkMalus, -2);
    expect(rausch.iniBasisMalus, -2);
    expect(rausch.gsMalus, -1);
    expect(rausch.eigenschaftsVerluste.ge, -2);
    expect(rausch.linkshaender, isTrue);
  });

  test('Karnifilo meldet die Erschöpfung ZfP*/2 aufgerundet', () {
    final b = berechneSpellEffectBeitraege(
      zustand: aktiviereEffektInstanz(
        const HeroState(
          currentLep: 30,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 30,
        ),
        const SpellEffectInstance(
          id: 'k',
          effectId: kKarnifiloZauberId,
          zfpStern: 5,
        ),
      ),
      katalog: katalog,
    );
    expect(b.kampfrauschQuelle, 'Karnifilo Raserei');
    expect(b.hinweise.join(' '), contains('3 Punkte Erschöpfung'));
  });
}
