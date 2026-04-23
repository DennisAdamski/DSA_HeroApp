import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

void main() {
  HeroSheet baseHero({
    Attributes? mainAttributes,
    String? policy,
    Set<String> lockedWaffenmeister = const <String>{},
    Set<String> unactivatedTalents = const <String>{},
  }) {
    return HeroSheet(
      id: 'h-epic',
      name: 'Episch',
      level: 21,
      attributes: const Attributes.zero(),
      isEpisch: true,
      epicStartAp: 21000,
      epicMainAttributes: mainAttributes ?? const Attributes.zero(),
      epicActivationPolicy: policy,
      epicLockedWaffenmeisterCategories: lockedWaffenmeister,
      epicUnactivatedTalentIds: unactivatedTalents,
    );
  }

  test('Default-HeroSheet hat schemaVersion 26 und leere Epic-Felder', () {
    const hero = HeroSheet(
      id: 'h-default',
      name: 'Default',
      level: 1,
      attributes: Attributes.zero(),
    );

    expect(hero.schemaVersion, 26);
    expect(hero.isEpisch, isFalse);
    expect(hero.epicMainAttributes.mu, 0);
    expect(hero.epicMainAttributes.kk, 0);
    expect(hero.epicActivationPolicy, isNull);
    expect(hero.epicLockedWaffenmeisterCategories, isEmpty);
    expect(hero.epicUnactivatedTalentIds, isEmpty);
  });

  test('Epic-Felder ueberleben den JSON-Roundtrip', () {
    final mainAttrs = const Attributes.zero().copyWith(mu: 1, kk: 1);
    final hero = baseHero(
      mainAttributes: mainAttrs,
      policy: 'standard',
      lockedWaffenmeister: const {'nahkampf', 'schilde'},
      unactivatedTalents: const {'tal_alchimie', 'tal_himmelskunde'},
    );

    final restored = HeroSheet.fromJson(hero.toJson());

    expect(restored.epicMainAttributes.mu, 1);
    expect(restored.epicMainAttributes.kk, 1);
    expect(restored.epicMainAttributes.kl, 0);
    expect(restored.epicActivationPolicy, 'standard');
    expect(
      restored.epicLockedWaffenmeisterCategories,
      {'nahkampf', 'schilde'},
    );
    expect(
      restored.epicUnactivatedTalentIds,
      {'tal_alchimie', 'tal_himmelskunde'},
    );
  });

  test('Fehlende Epic-Felder im JSON liefern Defaults zurueck', () {
    final restored = HeroSheet.fromJson(const <String, dynamic>{
      'id': 'legacy-hero',
      'name': 'Alt',
      'level': 1,
      'isEpisch': true,
      'epicStartAp': 21000,
    });

    expect(restored.isEpisch, isTrue);
    expect(restored.epicStartAp, 21000);
    expect(restored.epicMainAttributes.mu, 0);
    expect(restored.epicMainAttributes.kk, 0);
    expect(restored.epicActivationPolicy, isNull);
    expect(restored.epicLockedWaffenmeisterCategories, isEmpty);
    expect(restored.epicUnactivatedTalentIds, isEmpty);
  });

  test('copyWith kann epicActivationPolicy explizit auf null setzen', () {
    final hero = baseHero(policy: 'standard');
    final cleared = hero.copyWith(epicActivationPolicy: null);

    expect(cleared.epicActivationPolicy, isNull);
    // andere Felder unveraendert
    expect(cleared.isEpisch, isTrue);
  });

  test('copyWith ohne epicActivationPolicy laesst den Wert stehen', () {
    final hero = baseHero(policy: 'paktierer');
    final unchanged = hero.copyWith(level: 22);

    expect(unchanged.epicActivationPolicy, 'paktierer');
    expect(unchanged.level, 22);
  });

  test('copyWith kann Lock-Sets ersetzen', () {
    final hero = baseHero(
      lockedWaffenmeister: const {'fernkampf'},
      unactivatedTalents: const {'tal_alchimie'},
    );
    final updated = hero.copyWith(
      epicLockedWaffenmeisterCategories: const {'nahkampf'},
      epicUnactivatedTalentIds: const {'tal_himmelskunde'},
    );

    expect(updated.epicLockedWaffenmeisterCategories, {'nahkampf'});
    expect(updated.epicUnactivatedTalentIds, {'tal_himmelskunde'});
  });
}
