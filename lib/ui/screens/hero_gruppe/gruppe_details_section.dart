import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Zeigt Gruppenname, Code und Aktionen (Code kopieren, Gruppe verlassen).
class GruppeDetailsSection extends ConsumerWidget {
  const GruppeDetailsSection({
    super.key,
    required this.heroId,
    required this.mitgliedschaft,
  });

  final String heroId;
  final HeroGruppenMitgliedschaft mitgliedschaft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final codeKurz = mitgliedschaft.gruppenCode.length > 8
        ? '${mitgliedschaft.gruppenCode.substring(0, 8)}…'
        : mitgliedschaft.gruppenCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mitgliedschaft.gruppenName.isEmpty
                        ? 'Unbenannte Gruppe'
                        : mitgliedschaft.gruppenName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<_GruppeAktion>(
                  onSelected: (aktion) =>
                      _handleAktion(context, ref, aktion),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _GruppeAktion.codeKopieren,
                      child: ListTile(
                        leading: Icon(Icons.copy),
                        title: Text('Code kopieren'),
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _GruppeAktion.verlassen,
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Gruppe verlassen'),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _codeKopieren(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.key,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Code: $codeKurz',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAktion(
    BuildContext context,
    WidgetRef ref,
    _GruppeAktion aktion,
  ) {
    switch (aktion) {
      case _GruppeAktion.codeKopieren:
        _codeKopieren(context);
      case _GruppeAktion.verlassen:
        _gruppeVerlassen(context, ref);
    }
  }

  void _codeKopieren(BuildContext context) {
    Clipboard.setData(ClipboardData(text: mitgliedschaft.gruppenCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gruppencode kopiert')),
    );
  }

  Future<void> _gruppeVerlassen(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe verlassen?'),
        content: Text(
          'Möchtest du die Gruppe „${mitgliedschaft.gruppenName}" '
          'wirklich verlassen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verlassen'),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !context.mounted) return;

    await ref.read(heroActionsProvider).verlasseGruppe(
          heroId: heroId,
          gruppenCode: mitgliedschaft.gruppenCode,
        );
  }
}

enum _GruppeAktion { codeKopieren, verlassen }
