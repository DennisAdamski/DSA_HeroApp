import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_tools.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_management_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_unlock_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/house_rule_pack_management_screen.dart';

part 'settings/settings_navigation.dart';
part 'settings/settings_pages.dart';

/// Einstellungs-Screen für globale, heldenunabhängige Optionen.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Erstellt die adaptive Einstellungsnavigation.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsDestination _selectedDestination = _SettingsDestination.appearance;

  @override
  Widget build(BuildContext context) {
    final layout = appLayoutOf(context);
    final showSplitView = layout.hasPersistentDetailPane;

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: showSplitView
          ? _SettingsSplitView(
              selectedDestination: _selectedDestination,
              onSelectDestination: _selectDestination,
              onToggleDebugMode: _toggleDebugMode,
            )
          : _SettingsMenuOverview(
              onSelectDestination: _openDestination,
              onToggleDebugMode: _toggleDebugMode,
            ),
    );
  }

  void _selectDestination(_SettingsDestination destination) {
    if (destination.isDirectToggle) {
      return;
    }
    setState(() => _selectedDestination = destination);
  }

  void _openDestination(_SettingsDestination destination) {
    if (destination.isDirectToggle) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsDetailScreen(destination: destination),
      ),
    );
  }

  Future<void> _toggleDebugMode() async {
    await ref.read(settingsActionsProvider).toggleDebugModus();
  }
}
