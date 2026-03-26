part of '../hero_magic_tab.dart';

/// Sektion fuer magische Sonderfertigkeiten (strukturierte Liste).
class _MagicSpecialAbilitiesSection extends StatelessWidget {
  const _MagicSpecialAbilitiesSection({
    required this.abilities,
    required this.isEditing,
    required this.onChanged,
    this.onAdd,
  });

  final List<MagicSpecialAbility> abilities;
  final bool isEditing;
  final void Function(List<MagicSpecialAbility>) onChanged;
  final VoidCallback? onAdd;

  void _editAbility(BuildContext context, int index) {
    _showEditDialog(context, abilities[index], (ability) {
      final updated = List<MagicSpecialAbility>.from(abilities);
      updated[index] = ability;
      onChanged(updated);
    });
  }

  void _removeAbility(int index) {
    final updated = List<MagicSpecialAbility>.from(abilities);
    updated.removeAt(index);
    onChanged(updated);
  }

  void _showEditDialog(
    BuildContext context,
    MagicSpecialAbility? existing,
    void Function(MagicSpecialAbility) onSave,
  ) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');

    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null
              ? 'Sonderfertigkeit hinzufügen'
              : 'Sonderfertigkeit bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'z.B. Kraftlinienmagie',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Notiz (optional)',
                  hintText: 'z.B. Stufe II',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                onSave(MagicSpecialAbility(
                  name: name,
                  note: noteController.text.trim(),
                ));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    ).then((_) {
      nameController.dispose();
      noteController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Expanded(
              child: Text('Sonderfertigkeiten',
                  style: theme.textTheme.titleSmall),
            ),
            const SizedBox(width: 8),
            Text('(${abilities.length})',
                style: theme.textTheme.bodySmall),
            if (onAdd != null) ...[
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey<String>('magic-sf-add'),
                onPressed: onAdd,
                child: const Text('+ Sonderfertigkeit'),
              ),
            ],
          ],
        ),
        children: [
          if (abilities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Keine Sonderfertigkeiten eingetragen.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ...abilities.asMap().entries.map((entry) {
            final index = entry.key;
            final ability = entry.value;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(ability.name),
              subtitle: ability.note.isNotEmpty
                  ? Text(ability.note)
                  : null,
              trailing: isEditing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () =>
                              _editAbility(context, index),
                          tooltip: 'Bearbeiten',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => _removeAbility(index),
                          tooltip: 'Entfernen',
                        ),
                      ],
                    )
                  : null,
            );
          }),
        ],
      ),
    );
  }
}
