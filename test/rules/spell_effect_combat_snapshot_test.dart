import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/real_catalog.dart';
import '../ui2/shell/karto_test_support.dart';

const _grund = HeroState(
  currentLep: 30,
  currentAsp: 20,
  currentKap: 0,
  currentAu: 30,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;
  late HeroSheet held;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
    held = testHero();
  });

  HeroComputedSnapshot rechne(HeroState zustand) => buildHeroComputedSnapshot(
    hero: held,
    state: zustand,
    catalog: katalog,
    epicAdvantagesActive: false,
  );

  test('Blitz senkt AT-Basis, PA-Basis und die Helden-INI im Snapshot', () {
    final ohne = rechne(_grund);
    final mit = rechne(
      aktiviereEffektInstanz(
        _grund,
        const SpellEffectInstance(
          id: 'b',
          effectId: kBlitzZauberId,
          zfpStern: 5,
          zfw: 4,
        ),
      ),
    );

    expect(mit.derivedStats.atBase, ohne.derivedStats.atBase - 3);
    expect(mit.derivedStats.paBase, ohne.derivedStats.paBase - 2);
    // INI-Basis bleibt: Blitz senkt den fertigen INI-Wert, nicht die Basis.
    expect(mit.derivedStats.iniBase, ohne.derivedStats.iniBase);
    expect(
      mit.combatPreviewStats.heldenInitiative,
      ohne.combatPreviewStats.heldenInitiative - 4,
    );
    // Herkunft sichtbar: ein benannter Schritt in der AT-Herleitung.
    final schritte = mit.derivedStats.herleitungen!.atBase.schritte;
    expect(
      schritte.where(
        (s) => s.bezeichnung == 'Blitz dich find' && s.betrag == -3,
      ),
      hasLength(1),
    );
  });

  test('Plumbumbarum senkt AT-Basis und INI-Basis, nicht die PA', () {
    final ohne = rechne(_grund);
    final mit = rechne(
      aktiviereEffektInstanz(
        _grund,
        const SpellEffectInstance(
          id: 'p',
          effectId: kPlumbumbarumZauberId,
          zfpStern: 6,
        ),
      ),
    );

    expect(mit.derivedStats.atBase, ohne.derivedStats.atBase - 6);
    expect(mit.derivedStats.iniBase, ohne.derivedStats.iniBase - 6);
    expect(mit.derivedStats.paBase, ohne.derivedStats.paBase);
    expect(mit.combatPreviewStats.at, ohne.combatPreviewStats.at - 6);
    expect(mit.combatPreviewStats.pa, ohne.combatPreviewStats.pa);
  });

  test('Psychostabilis erhöht die MR um ZfP*, +2 nur als Hinweis', () {
    final ohne = rechne(_grund);
    final mit = rechne(
      aktiviereEffektInstanz(
        _grund,
        const SpellEffectInstance(
          id: 'ps',
          effectId: kPsychostabilisZauberId,
          zfpStern: 7,
        ),
      ),
    );

    expect(mit.derivedStats.mr, ohne.derivedStats.mr + 7);
    expect(mit.derivedStats.zauberEffekte.hinweise.single, contains('+2'));
    final schritte = mit.derivedStats.herleitungen!.mr.schritte;
    expect(
      schritte.where((s) => s.bezeichnung == 'Psychostabilis' && s.betrag == 7),
      hasLength(1),
    );
  });

  test('Blitz erschwert die Zauberprobe im Gefecht-Zuschlag um ZfP*', () {
    final ohne = rechne(_grund);
    final mit = rechne(
      aktiviereEffektInstanz(
        _grund,
        const SpellEffectInstance(
          id: 'b',
          effectId: kBlitzZauberId,
          zfpStern: 5,
          zfw: 4,
        ),
      ),
    );

    int zuschlag(HeroComputedSnapshot s) =>
        gefechtsZauberZuschlag(s, aufrechterhalten: 0, simultanzaubern: false);

    expect(zuschlag(mit), zuschlag(ohne) + 5);
  });

  test('Beenden der Quelle stellt alle Werte wieder her', () {
    final ohne = rechne(_grund);
    final mit = aktiviereEffektInstanz(
      _grund,
      const SpellEffectInstance(
        id: 'p',
        effectId: kPlumbumbarumZauberId,
        zfpStern: 6,
      ),
    );

    final danach = rechne(beendeEffektInstanz(mit, 'p'));

    expect(danach.derivedStats.atBase, ohne.derivedStats.atBase);
    expect(danach.combatPreviewStats.at, ohne.combatPreviewStats.at);
    expect(
      danach.combatPreviewStats.initiative,
      ohne.combatPreviewStats.initiative,
    );
  });

  test('Karnifilo: AT-Basis +5, PA-Basis −5, Herkunft sichtbar', () {
    final ohne = rechne(_grund);
    final mit = rechne(
      aktiviereEffektInstanz(
        _grund,
        const SpellEffectInstance(
          id: 'k',
          effectId: kKarnifiloZauberId,
          zfpStern: 4,
        ),
      ),
    );

    expect(mit.derivedStats.atBase, ohne.derivedStats.atBase + 5);
    expect(mit.derivedStats.paBase, ohne.derivedStats.paBase - 5);
    // MU +5 hebt die INI-Basis um (5 + 5) / 5 = 2 (Tischentscheid 18.10.2026).
    expect(mit.derivedStats.iniBase, ohne.derivedStats.iniBase + 2);
    expect(mit.combatPreviewStats.at, ohne.combatPreviewStats.at + 5);
    expect(mit.combatPreviewStats.pa, ohne.combatPreviewStats.pa - 5);
    final schritte = mit.derivedStats.herleitungen!.atBase.schritte;
    expect(
      schritte.where(
        (s) => s.bezeichnung == 'Karnifilo Raserei' && s.betrag == 5,
      ),
      hasLength(1),
    );
  });

  group('Blitz im Fernkampf', () {
    HeroComputedSnapshot rechneFk(HeroState zustand) =>
        buildHeroComputedSnapshot(
          hero: held.copyWith(
            combatConfig: const CombatConfig(
              mainWeapon: MainWeaponSlot(
                name: 'Kurzbogen',
                combatType: WeaponCombatType.ranged,
                weaponType: 'Kurzbogen',
              ),
            ),
          ),
          state: zustand,
          catalog: katalog,
          epicAdvantagesActive: false,
        );
    final blitz = aktiviereEffektInstanz(
      _grund,
      const SpellEffectInstance(
        id: 'b',
        effectId: kBlitzZauberId,
        zfpStern: 5,
        zfw: 4,
      ),
    );

    test(
      'der FK-Wert der Waffe ist um ZfP* erschwert, als eigener Schritt',
      () {
        final ohne = rechneFk(_grund);
        final mit = rechneFk(blitz);

        expect(mit.combatPreviewStats.isRangedWeapon, isTrue);
        // FK-Basis bleibt: die Erschwernis gilt der Probe, nicht dem Basiswert.
        expect(mit.derivedStats.fkBase, ohne.derivedStats.fkBase);
        expect(mit.combatPreviewStats.at, ohne.combatPreviewStats.at - 5);
        final fk = mit.combatPreviewStats.herleitungen!.at;
        expect(fk.wert, mit.combatPreviewStats.at);
        final schritt = fk.schritte.singleWhere(
          (s) => s.bezeichnung == 'Blitz dich find',
        );
        expect(schritt.betrag, -5);
        expect(schritt.bedingung, 'geblendet');
      },
    );

    test('das Gefecht übernimmt denselben FK-Wert', () {
      final mit = rechneFk(blitz);
      final werte = gefechtswerteFuer(mit, katalog: katalog);

      expect(werte.at, mit.combatPreviewStats.at);
      expect(
        werte.atHerleitung!.schritte.where(
          (s) => s.bezeichnung == 'Blitz dich find',
        ),
        hasLength(1),
      );
    });

    test('Nahkampf bekommt keinen Fernkampf-Schritt', () {
      final mit = rechne(blitz);

      expect(mit.combatPreviewStats.isRangedWeapon, isFalse);
      expect(
        mit.combatPreviewStats.herleitungen!.at.schritte.where(
          (s) => s.bedingung == 'geblendet',
        ),
        isEmpty,
      );
    });
  });

  group('Karnifilo-Eigenschaften', () {
    HeroState karnifilo(HeroState z) => aktiviereEffektInstanz(
      z,
      const SpellEffectInstance(
        id: 'k',
        effectId: kKarnifiloZauberId,
        zfpStern: 4,
      ),
    );
    HeroState axxeleratus(HeroState z) => z.copyWith(
      activeSpellEffects: z.activeSpellEffects.withToggled(
        activeSpellEffectAxxeleratus,
        true,
      ),
    );

    test('Proben sehen MU/KK +5 und KL/CH −5, die Eigenschaften nicht', () {
      final ohne = rechne(_grund);
      final mit = rechne(karnifilo(_grund));

      expect(mit.effectiveAttributes.mu, ohne.effectiveAttributes.mu);
      expect(mit.effectiveAttributes.kk, ohne.effectiveAttributes.kk);
      expect(mit.probenEigenschaften.mu, ohne.probenEigenschaften.mu + 5);
      expect(mit.probenEigenschaften.kk, ohne.probenEigenschaften.kk + 5);
      expect(mit.probenEigenschaften.kl, ohne.probenEigenschaften.kl - 5);
      expect(mit.probenEigenschaften.ch, ohne.probenEigenschaften.ch - 5);
      expect(mit.probenEigenschaften.ge, ohne.probenEigenschaften.ge);
    });

    test('MR, GS, LeP und AuP bleiben unverändert', () {
      final ohne = rechne(_grund);
      final mit = rechne(karnifilo(_grund));

      expect(mit.derivedStats.mr, ohne.derivedStats.mr);
      expect(mit.derivedStats.gs, ohne.derivedStats.gs);
      expect(mit.derivedStats.maxLep, ohne.derivedStats.maxLep);
      expect(mit.derivedStats.maxAu, ohne.derivedStats.maxAu);
    });

    test('INI- und FK-Basis tragen je einen eigenen Schritt', () {
      final ohne = rechne(_grund);
      final mit = rechne(karnifilo(_grund));
      final h = mit.derivedStats.herleitungen!;

      expect(mit.derivedStats.fkBase, ohne.derivedStats.fkBase + 1);
      expect(h.iniBase.wert, mit.derivedStats.iniBase);
      expect(h.fkBase.wert, mit.derivedStats.fkBase);
      bool istKarnifilo(HerleitungsSchritt s) =>
          s.bezeichnung == 'Karnifilo Raserei' &&
          s.art == HerleitungsArt.zauber;
      final ini = h.iniBase.schritte.singleWhere(istKarnifilo);
      final fk = h.fkBase.schritte.singleWhere(istKarnifilo);
      expect(ini.betrag, 2);
      expect(fk.betrag, 1);
      expect(h.mr.schritte.where(istKarnifilo), isEmpty);
      expect(h.atBase.schritte.where(istKarnifilo), isEmpty);
    });

    test('Axxeleratus verdoppelt die INI-Basis samt Karnifilo-Anteil', () {
      expect(
        rechne(axxeleratus(karnifilo(_grund)))
            .combatPreviewStats
            .heldenInitiative,
        rechne(axxeleratus(_grund)).combatPreviewStats.heldenInitiative + 4,
      );
    });

    test('TP/KK rechnet mit KK +5 als eigener Schritt', () {
      final ohne = rechne(_grund);
      final mit = rechne(karnifilo(_grund));
      final tp = mit.combatPreviewStats.herleitungen!.tpZuschlag;

      expect(tp.wert, mit.combatPreviewStats.tpCalc);
      final schritt = tp.schritte.where(
        (s) => s.bezeichnung == 'Karnifilo Raserei (KK +5)',
      );
      final nutztTpKk = tp.schritte.any(
        (s) =>
            s.bezeichnung == 'TP/KK' &&
            !(s.formel ?? '').startsWith('deaktiviert'),
      );
      expect(nutztTpKk, isTrue, reason: 'Testheld braucht eine TP/KK-Waffe');
      expect(schritt, hasLength(1));
      expect(
        mit.combatPreviewStats.tpCalc,
        ohne.combatPreviewStats.tpCalc + schritt.single.betrag,
      );
    });
  });

  test('zwei Karnifilo addieren sich nicht', () {
    final ohne = rechne(_grund);
    var z = _grund;
    for (final id in ['k1', 'k2']) {
      z = aktiviereEffektInstanz(
        z,
        SpellEffectInstance(id: id, effectId: kKarnifiloZauberId, zfpStern: 4),
      );
    }

    expect(rechne(z).derivedStats.atBase, ohne.derivedStats.atBase + 5);
  });
}
