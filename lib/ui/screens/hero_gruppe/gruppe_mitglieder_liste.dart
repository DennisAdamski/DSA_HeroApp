import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Zeigt die Mitglieder einer Gruppe als Karten-Liste an.
class GruppeMitgliederListe extends ConsumerWidget {
  const GruppeMitgliederListe({
    super.key,
    required this.heroId,
    required this.gruppenCode,
  });

  final String heroId;
  final String gruppenCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mitglieder = ref.watch(
      gruppenMitgliederProvider((heroId: heroId, gruppenCode: gruppenCode)),
    );

    if (mitglieder.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Noch keine Mitglieder',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Mitglieder (${mitglieder.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final held in mitglieder)
          _ExternerHeldKarte(
            held: held,
            onEntfernen: () => _entferneHeld(ref, held.id),
          ),
      ],
    );
  }

  Future<void> _entferneHeld(WidgetRef ref, String externerHeldId) async {
    await ref.read(heroActionsProvider).removeExternerHeld(
          heroId: heroId,
          gruppenCode: gruppenCode,
          externerHeldId: externerHeldId,
        );
  }
}

class _ExternerHeldKarte extends StatelessWidget {
  const _ExternerHeldKarte({
    required this.held,
    required this.onEntfernen,
  });

  final ExternerHeld held;
  final VoidCallback onEntfernen;

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          held.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (held.istVerknuepft)
                        Tooltip(
                          message: 'Verknüpft (Live-Sync)',
                          child: Icon(
                            Icons.cloud_done_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Tooltip(
                          message: 'Manuell hinzugefügt',
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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
                  if (held.notizen.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      held.notizen,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'entfernen') onEntfernen();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'entfernen',
                  child: ListTile(
                    leading: Icon(Icons.person_remove_outlined),
                    title: Text('Entfernen'),
                    dense: true,
                  ),
                ),
              ],
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
        // Ungueltige Base64-Daten.
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
