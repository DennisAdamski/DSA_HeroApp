import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/sync_conflict_comparison_table.dart';

/// Blockiert die App-Nutzung, solange Konto-Sync-Konflikte offen sind.
///
/// Der Bildschirm ist bewusst kein Sackgasse: ueber `Später entscheiden` gelangt
/// der Nutzer angemeldet in die App (die Konflikte bleiben unter
/// `Einstellungen > Konto & Sync` loesbar), ueber `Abmelden` zurueck ins
/// Offline-Profil.
class SyncConflictGate extends StatefulWidget {
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
  State<SyncConflictGate> createState() => _SyncConflictGateState();
}

class _SyncConflictGateState extends State<SyncConflictGate> {
  /// Nur fuer diese Sitzung zurueckgestellt; beim naechsten Start wird erneut
  /// gefragt, solange die Konflikte offen sind.
  bool _postponed = false;

  @override
  void didUpdateWidget(covariant SyncConflictGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncController != widget.syncController) {
      _postponed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.syncController;
    if (controller == null || _postponed) {
      return widget.child;
    }
    return StreamBuilder<SyncStatusSnapshot>(
      stream: controller.watchStatus(),
      initialData: controller.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? controller.currentStatus;
        if (status.openConflicts.isEmpty) {
          return widget.child;
        }
        return _SyncConflictScreen(
          status: status,
          controller: controller,
          onPostpone: () => setState(() => _postponed = true),
        );
      },
    );
  }
}

class _SyncConflictScreen extends ConsumerWidget {
  const _SyncConflictScreen({
    required this.status,
    required this.controller,
    required this.onPostpone,
  });

  final SyncStatusSnapshot status;
  final AppSyncController controller;
  final VoidCallback onPostpone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authService = ref.watch(authServiceProvider);
    final conflicts = status.openConflicts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync-Konflikte lösen'),
        actions: [
          TextButton.icon(
            onPressed: onPostpone,
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Später entscheiden'),
          ),
          if (authService != null)
            IconButton(
              tooltip: 'Abmelden',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmAndSignOut(context, authService),
            ),
          const SizedBox(width: 8),
        ],
      ),
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
              const SizedBox(height: 8),
              Text(
                'Ungelöste Konflikte bleiben unter '
                'Einstellungen > Konto & Sync verfügbar.',
                style: theme.textTheme.bodySmall,
              ),
              if (conflicts.length > 1) ...[
                const SizedBox(height: 16),
                _BulkActions(
                  conflictCount: conflicts.length,
                  onResolveAll: (choice) =>
                      _resolveAll(context, conflicts, choice),
                ),
              ],
              const SizedBox(height: 16),
              for (final conflict in conflicts) ...[
                _SyncConflictCard(
                  conflict: conflict,
                  diff: controller.conflictDiff(conflict.id),
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

  Future<void> _resolveAll(
    BuildContext context,
    List<SyncConflict> conflicts,
    SyncResolutionChoice choice,
  ) async {
    final label = choice == SyncResolutionChoice.keepRemote
        ? 'Online-Version'
        : 'lokale Version';
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Alle Konflikte lösen?',
      content:
          'Für alle ${conflicts.length} Einträge wird die $label behalten. '
          'Das lässt sich nicht rückgängig machen.',
      confirmLabel: 'Alle lösen',
      isDestructive: true,
    );
    if (confirmed != AdaptiveConfirmResult.confirm) {
      return;
    }
    // Sequenziell: jede Aufloesung schreibt lokal und ggf. remote. Die Liste
    // ist danach nicht zwingend leer -- ein Konflikt kann mit frischem
    // Remote-Stand bewusst neu geoeffnet werden.
    for (final conflict in conflicts) {
      await controller.resolveConflict(conflict.id, choice);
    }
  }

  Future<void> _confirmAndSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Abmelden?',
      content:
          'Die offenen Konflikte bleiben ungelöst und werden beim nächsten '
          'Anmelden erneut gezeigt. Deine Konto-Daten bleiben online '
          'gespeichert, die App wechselt ins lokale Offline-Profil.',
      confirmLabel: 'Abmelden',
      isDestructive: true,
    );
    if (confirmed != AdaptiveConfirmResult.confirm) {
      return;
    }
    await authService.signOut();
  }
}

class _BulkActions extends StatelessWidget {
  const _BulkActions({required this.conflictCount, required this.onResolveAll});

  final int conflictCount;
  final ValueChanged<SyncResolutionChoice> onResolveAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alle $conflictCount Einträge auf einmal',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onResolveAll(SyncResolutionChoice.keepRemote),
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('Alle: Online behalten'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onResolveAll(SyncResolutionChoice.keepLocal),
                  icon: const Icon(Icons.computer),
                  label: const Text('Alle: Lokal behalten'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncConflictCard extends StatelessWidget {
  const _SyncConflictCard({
    required this.conflict,
    required this.onResolve,
    this.diff,
  });

  final SyncConflict conflict;
  final ValueChanged<SyncResolutionChoice> onResolve;

  /// Feld-Diff des Konflikts oder `null`, wenn keine Volldaten vorliegen.
  final SyncObjectDiff? diff;

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
            SyncConflictComparisonTable(conflict: conflict, diff: diff),
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
