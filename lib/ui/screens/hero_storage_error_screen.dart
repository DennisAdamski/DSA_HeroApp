import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

/// Fehleransicht fuer ungueltige oder nicht verfuegbare Heldenspeicherpfade.
class HeroStorageErrorScreen extends StatelessWidget {
  const HeroStorageErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heldenspeicher nicht verfügbar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Die Heldendaten konnten nicht geladen werden.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text('$error', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                const Text(
                  'Prüfe den konfigurierten Heldenspeicher in den '
                  'Einstellungen. App-Einstellungen bleiben lokal verfügbar.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Einstellungen öffnen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
