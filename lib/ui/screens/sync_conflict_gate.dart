import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Blockiert die App-Nutzung, solange Konto-Sync-Konflikte offen sind.
class SyncConflictGate extends StatelessWidget {
  /// Erstellt ein Gate um [child], falls [syncController] Konflikte meldet.
  const SyncConflictGate({
    super.key,
    required this.syncController,
    required this.child,
  });

  /// Aktiver Sync-Controller oder `null` im Offline-Modus.
  final AppSyncController? syncController;

  /// Normale App-Startseite ohne offene Konflikte.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = syncController;
    if (controller == null) {
      return child;
    }
    return StreamBuilder<SyncStatusSnapshot>(
      stream: controller.watchStatus(),
      initialData: controller.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? controller.currentStatus;
        if (status.openConflicts.isEmpty) {
          return child;
        }
        return _SyncConflictScreen(status: status, controller: controller);
      },
    );
  }
}

class _SyncConflictScreen extends StatelessWidget {
  const _SyncConflictScreen({required this.status, required this.controller});

  final SyncStatusSnapshot status;
  final AppSyncController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sync-Konflikte lösen')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Online- und Offline-Daten unterscheiden sich. '
                'Wähle pro Eintrag, welche Version erhalten bleibt.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              for (final conflict in status.openConflicts) ...[
                _SyncConflictCard(
                  conflict: conflict,
                  onResolve: (choice) {
                    controller.resolveConflict(conflict.id, choice);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncConflictCard extends StatelessWidget {
  const _SyncConflictCard({required this.conflict, required this.onResolve});

  final SyncConflict conflict;
  final ValueChanged<SyncResolutionChoice> onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conflict.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Lokal: ${conflict.localSummary}'),
            Text('Online: ${conflict.remoteSummary}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onResolve(SyncResolutionChoice.keepLocal),
                  icon: const Icon(Icons.computer),
                  label: const Text('Lokal behalten'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onResolve(SyncResolutionChoice.keepRemote),
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('Online behalten'),
                ),
                if (conflict.supportsKeepBoth)
                  FilledButton.icon(
                    onPressed: () => onResolve(SyncResolutionChoice.keepBoth),
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Beide behalten'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
