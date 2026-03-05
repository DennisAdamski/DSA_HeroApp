part of '../hero_magic_tab.dart';

/// Sektion fuer magische Sonderfertigkeiten (strukturierte Liste).
class _MagicSpecialAbilitiesSection extends StatelessWidget {
  const _MagicSpecialAbilitiesSection({
    required this.abilities,
    required this.isEditing,
    required this.onChanged,
  });

  final List<MagicSpecialAbility> abilities;
  final bool isEditing;
  final void Function(List<MagicSpecialAbility>) onChanged;

  void _addAbility(BuildContext context) {
    _showEditDialog(context, null, (ability) {
      onChanged([...abilities, ability]);
    });
  }

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

    showDialog<void>(
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
            Text('Sonderfertigkeiten',
                style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text('(${abilities.length})',
                style: theme.textTheme.bodySmall),
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
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () => _addAbility(context),
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
            ),
        ],
      ),
    );
  }
}
