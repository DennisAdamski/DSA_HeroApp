import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

void main() {
  test('setTableColumnWidth merges column and table preferences', () async {
    final repository = _FakeSettingsRepository(
      const AppSettings(
        tableColumnWidths: <String, Map<String, double>>{
          'magic.activeSpells': <String, double>{'name': 280},
          'inventory.items': <String, double>{'status': 360},
        },
      ),
    );
    final actions = SettingsActions(repository);

    await actions.setTableColumnWidth('magic.activeSpells', 'effect', 420);

    expect(repository.settings.tableColumnWidths, <String, Map<String, double>>{
      'magic.activeSpells': <String, double>{'name': 280, 'effect': 420},
      'inventory.items': <String, double>{'status': 360},
    });
  });

  test('resetTableColumnWidths removes only the addressed table', () async {
    final repository = _FakeSettingsRepository(
      const AppSettings(
        tableColumnWidths: <String, Map<String, double>>{
          'magic.activeSpells': <String, double>{'name': 280},
          'inventory.items': <String, double>{'status': 360},
        },
      ),
    );
    final actions = SettingsActions(repository);

    await actions.resetTableColumnWidths('magic.activeSpells');

    expect(repository.settings.tableColumnWidths, <String, Map<String, double>>{
      'inventory.items': <String, double>{'status': 360},
    });
  });
}

class _FakeSettingsRepository implements HiveSettingsRepository {
  _FakeSettingsRepository(this.settings);

  AppSettings settings;

  @override
  AppSettings load() => settings;

  @override
  Future<void> save(AppSettings next) async {
    settings = next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
