import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
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
}
