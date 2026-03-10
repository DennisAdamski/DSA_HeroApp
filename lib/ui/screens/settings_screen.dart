import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Einstellungs-Screen fuer globale, heldenunabhaengige Optionen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugModus = ref.watch(debugModusProvider);
    final dunkelModus = ref.watch(dunkelModusProvider);
    final actions = ref.read(settingsActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Debug-Modus'),
            subtitle: const Text(
              'Variablennamen statt Anzeigebezeichnungen',
            ),
            value: debugModus,
            onChanged: (_) => actions.toggleDebugModus(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Dunkelmodus'),
            subtitle: const Text('Dunkles Farbschema'),
            value: dunkelModus,
            onChanged: (_) => actions.toggleDunkelModus(),
          ),
        ],
      ),
    );
  }
}
