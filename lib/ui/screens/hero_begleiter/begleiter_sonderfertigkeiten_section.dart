part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Sonderfertigkeiten
// ---------------------------------------------------------------------------

class _SonderfertigkeitenSection extends StatelessWidget {
  const _SonderfertigkeitenSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    final sfs = companion.sonderfertigkeiten;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Sonderfertigkeiten'),
        if (sfs.isEmpty && !isEditing)
          Text(
            'Keine Sonderfertigkeiten eingetragen.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (int i = 0; i < sfs.length; i++)
            _SonderfertigkeitTile(
              sf: sfs[i],
              isEditing: isEditing,
              onEdit: () async {
                final ctx = context;
                if (!ctx.mounted) return;
                final result =
                    await showAdaptiveInputDialog<HeroCompanionSonderfertigkeit>(
                  context: ctx,
                  builder: (_) => _SonderfertigkeitDialog(initial: sfs[i]),
                );
                if (result != null) {
                  final next =
                      List<HeroCompanionSonderfertigkeit>.from(sfs);
                  next[i] = result;
                  onChanged(companion.copyWith(sonderfertigkeiten: next));
                }
              },
              onDelete: () {
                final next =
                    List<HeroCompanionSonderfertigkeit>.from(sfs)
                      ..removeAt(i);
                onChanged(companion.copyWith(sonderfertigkeiten: next));
              },
            ),
        if (isEditing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final result = await showAdaptiveInputDialog<HeroCompanionSonderfertigkeit>(
                context: context,
                builder: (_) => const _SonderfertigkeitDialog(),
              );
              if (result != null) {
                onChanged(
                  companion.copyWith(
                    sonderfertigkeiten: [
                      ...companion.sonderfertigkeiten,
                      result,
                    ],
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Sonderfertigkeit hinzufügen'),
          ),
        ],
      ],
    );
  }
}

class _SonderfertigkeitTile extends StatelessWidget {
  const _SonderfertigkeitTile({
    required this.sf,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
  });

  final HeroCompanionSonderfertigkeit sf;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sf.name.isEmpty ? '–' : sf.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (sf.beschreibung.isNotEmpty)
                Text(
                  sf.beschreibung,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (isEditing) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            tooltip: 'Bearbeiten',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            tooltip: 'Löschen',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

class _SonderfertigkeitDialog extends StatefulWidget {
  const _SonderfertigkeitDialog({this.initial});
  final HeroCompanionSonderfertigkeit? initial;

  @override
  State<_SonderfertigkeitDialog> createState() =>
      _SonderfertigkeitDialogState();
}

class _SonderfertigkeitDialogState extends State<_SonderfertigkeitDialog> {
  late final TextEditingController _name;
  late final TextEditingController _beschreibung;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _beschreibung = TextEditingController(
      text: widget.initial?.beschreibung ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return AdaptiveInputDialog(
      title: isNew
          ? 'Sonderfertigkeit hinzufügen'
          : 'Sonderfertigkeit bearbeiten',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          const SizedBox(height: _fieldSpacing),
          TextField(
            controller: _beschreibung,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            HeroCompanionSonderfertigkeit(
              name: _name.text.trim(),
              beschreibung: _beschreibung.text.trim(),
            ),
          ),
          child: Text(isNew ? 'Hinzufügen' : 'Speichern'),
        ),
      ],
    );
  }
}
