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

  test('disabled house rule pack ids round-trip through json', () {
    const settings = AppSettings(
      disabledHouseRulePackIds: {'epic_rules_v1', 'epic_rules_v1.advantages'},
    );

    final json = settings.toJson();
    final restored = AppSettings.fromJson(json);

    expect(restored.disabledHouseRulePackIds, {
      'epic_rules_v1',
      'epic_rules_v1.advantages',
    });
  });

  test('legacy disabledHouseRuleSourceKeys migrate to pack ids', () {
    final settings = AppSettings.fromJson(const <String, dynamic>{
      'disabledHouseRuleSourceKeys': <String>[
        'epic_rules_v1',
        'epic_rules_v1.advantages',
      ],
    });

    expect(settings.disabledHouseRulePackIds, {
      'epic_rules_v1',
      'epic_rules_v1.advantages',
    });
  });

  test('missing disabledHouseRulePackIds defaults to empty set', () {
    final settings = AppSettings.fromJson(const <String, dynamic>{});

    expect(settings.disabledHouseRulePackIds, isEmpty);
  });

  test('copyWith can replace disabledHouseRulePackIds', () {
    const settings = AppSettings();

    final updated = settings.copyWith(
      disabledHouseRulePackIds: const {'epic_rules_v1'},
    );

    expect(updated.disabledHouseRulePackIds, {'epic_rules_v1'});
  });
}
