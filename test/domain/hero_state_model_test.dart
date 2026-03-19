import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

void main() {
  test('hero state roundtrip keeps exhaustion fields', () {
    const state = HeroState(
      currentLep: 12,
      currentAsp: 7,
      currentKap: 1,
      currentAu: 16,
      erschoepfung: 5,
      ueberanstrengung: 2,
    );

    final reloaded = HeroState.fromJson(state.toJson());

    expect(reloaded.schemaVersion, 5);
    expect(reloaded.erschoepfung, 5);
    expect(reloaded.ueberanstrengung, 2);
  });

  test('hero state backwards compatibility defaults new fields to zero', () {
    final loaded = HeroState.fromJson(const <String, dynamic>{
      'schemaVersion': 4,
      'currentLep': 10,
      'currentAsp': 3,
      'currentKap': 0,
      'currentAu': 12,
    });

    expect(loaded.erschoepfung, 0);
    expect(loaded.ueberanstrengung, 0);
  });
}
