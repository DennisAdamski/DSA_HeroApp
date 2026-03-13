import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';

void main() {
  test('serializes and deserializes hero storage path', () {
    const settings = AppSettings(
      debugModus: true,
      dunkelModus: true,
      heroStoragePath: 'C:/Cloud/Helden',
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.debugModus, isTrue);
    expect(restored.dunkelModus, isTrue);
    expect(restored.heroStoragePath, 'C:/Cloud/Helden');
  });

  test('copyWith can clear hero storage path explicitly', () {
    const settings = AppSettings(heroStoragePath: 'C:/Cloud/Helden');

    final updated = settings.copyWith(heroStoragePath: null);

    expect(updated.heroStoragePath, isNull);
  });
}
