import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';

void main() {
  HeroTransferBundle buildBundle() {
    const hero = HeroSheet(
      id: 'hero-1',
      name: 'Alrik',
      level: 3,
      attributes: Attributes(
        mu: 12,
        kl: 11,
        inn: 10,
        ch: 9,
        ff: 8,
        ge: 12,
        ko: 13,
        kk: 12,
      ),
      rasse: 'Mensch',
    );
    const state = HeroState(
      currentLep: 30,
      currentAsp: 12,
      currentKap: 0,
      currentAu: 26,
      tempAttributeMods: AttributeModifiers(mu: 2),
    );
    return HeroTransferBundle(
      exportedAt: DateTime.utc(2026, 2, 22, 12, 0, 0),
      hero: hero,
      state: state,
    );
  }

  test('roundtrip keeps hero and state values', () {
    final bundle = buildBundle();
    final reloaded = HeroTransferBundle.fromJson(bundle.toJson());

    expect(reloaded.hero.id, bundle.hero.id);
    expect(reloaded.hero.name, bundle.hero.name);
    expect(reloaded.hero.rasse, bundle.hero.rasse);
    expect(reloaded.hero.startAttributes.mu, bundle.hero.startAttributes.mu);
    expect(reloaded.state.currentLep, bundle.state.currentLep);
    expect(reloaded.state.currentAu, bundle.state.currentAu);
    expect(reloaded.state.tempAttributeMods.mu, 2);
    expect(reloaded.exportedAt.toUtc(), bundle.exportedAt.toUtc());
  });

  test('rejects wrong kind', () {
    final map = buildBundle().toJson();
    map['kind'] = 'wrong.kind';

    expect(
      () => HeroTransferBundle.fromJson(map),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsupported transfer version', () {
    final map = buildBundle().toJson();
    map['transferSchemaVersion'] = 2;

    expect(
      () => HeroTransferBundle.fromJson(map),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects missing or invalid hero/state maps', () {
    final withoutHero = buildBundle().toJson()..remove('hero');
    final withoutState = buildBundle().toJson()..remove('state');

    expect(
      () => HeroTransferBundle.fromJson(withoutHero),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => HeroTransferBundle.fromJson(withoutState),
      throwsA(isA<FormatException>()),
    );
  });
}
