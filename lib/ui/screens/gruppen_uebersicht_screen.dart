import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/gruppen_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';

/// Read-only Uebersicht der aktuell geladenen Heldengruppe.
class GruppenUebersichtScreen extends ConsumerWidget {
  const GruppenUebersichtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(gruppenSnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gruppenübersicht')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _updateGruppe(context, ref),
        icon: const Icon(Icons.refresh),
        label: const Text('Aktualisieren'),
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          if (snapshot == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Gruppe geladen.\n'
                  'Importiere eine .dsa-gruppe.json-Datei oder '
                  'lasse dir eine von einem Gruppenmitglied schicken.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _GruppenInhalt(snapshot: snapshot);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
      ),
    );
  }

  Future<void> _updateGruppe(BuildContext context, WidgetRef ref) async {
    try {
      const actions = WorkspaceImportExportActions();
      final result = await actions.importSmartData(
        context: context,
        ref: ref,
      );
      if (result == null || !context.mounted) return;
      if (result.type == ImportResult.gruppe) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruppe aktualisiert')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Einzelner Held importiert (keine Gruppendatei)'),
          ),
        );
      }
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import ungültig: ${error.message}')),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: $error')),
      );
    }
  }
}

class _GruppenInhalt extends StatelessWidget {
  const _GruppenInhalt({required this.snapshot});

  final GruppenSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standText = _formatDateTime(snapshot.exportedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            snapshot.gruppenName,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Stand: $standText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            itemCount: snapshot.helden.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _HeldKarte(held: snapshot.helden[index]);
            },
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}

class _HeldKarte extends StatelessWidget {
  const _HeldKarte({required this.held});

  final HeldVisitenkarte held;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final herkunft = [held.rasse, held.kultur, held.profession]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(theme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    held.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (herkunft.isNotEmpty)
                    Text(
                      herkunft,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _StatChip(label: 'Stufe', value: held.level),
                      _StatChip(label: 'LeP', value: held.maxLep),
                      if (held.maxAsp > 0)
                        _StatChip(label: 'AsP', value: held.maxAsp),
                      _StatChip(label: 'Au', value: held.maxAu),
                      _StatChip(label: 'INI', value: held.iniBase),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (held.avatarThumbnailBase64 != null &&
        held.avatarThumbnailBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(held.avatarThumbnailBase64!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholderAvatar(theme),
          ),
        );
      } on FormatException {
        // Ungueltige Base64-Daten — Platzhalter anzeigen.
      }
    }
    return _placeholderAvatar(theme);
  }

  Widget _placeholderAvatar(ThemeData theme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.person_outline,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}
