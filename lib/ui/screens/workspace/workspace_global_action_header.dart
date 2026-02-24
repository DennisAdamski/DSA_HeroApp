import 'package:flutter/material.dart';

/// Einheitliche Action-Leiste fuer globale Bearbeiten/Speichern/Abbrechen-
/// Aktionen in der Workspace-Shell.
class WorkspaceGlobalActionHeader extends StatelessWidget {
  const WorkspaceGlobalActionHeader({
    super.key,
    required this.isEditableTab,
    required this.isEditing,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancel,
  });

  final bool isEditableTab;
  final bool isEditing;
  final VoidCallback? onStartEdit;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    if (!isEditableTab) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Tooltip(
              message: 'In diesem Tab noch nicht verfügbar',
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.edit),
                label: const Text('Bearbeiten'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'In diesem Tab noch nicht verfügbar',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isEditing) ...[
            OutlinedButton(
              onPressed: onCancel,
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onSave,
              child: const Text('Speichern'),
            ),
          ] else
            FilledButton.icon(
              onPressed: onStartEdit,
              icon: const Icon(Icons.edit),
              label: const Text('Bearbeiten'),
            ),
        ],
      ),
    );
  }
}
