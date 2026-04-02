part of 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.entries,
    required this.isEditing,
    required this.onAdd,
    required this.onRemove,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
  });

  final List<HeroNoteEntry> entries;
  final bool isEditing;
  final Future<void> Function() onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, String value) onTitleChanged;
  final void Function(int index, String value) onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(_notesPagePadding),
      children: [
        _SectionCard(
          title: 'Freie Chroniken',
          subtitle: isEditing
              ? 'Lege Einträge mit Titel und Beschreibung an.'
              : 'Tippe auf einen Titel, um die vollständige Beschreibung zu sehen.',
          action: FilledButton(
            key: const ValueKey<String>('notes-add-note'),
            onPressed: onAdd,
            child: const Text('+ Chronik'),
          ),
          child: entries.isEmpty
              ? const _EmptyState(message: 'Noch keine Chroniken vorhanden.')
              : Column(
                  children: [
                    for (var index = 0; index < entries.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == entries.length - 1
                              ? 0
                              : _notesFieldSpacing,
                        ),
                        child: isEditing
                            ? _EditableNoteCard(
                                index: index,
                                entry: entries[index],
                                onRemove: onRemove,
                                onTitleChanged: onTitleChanged,
                                onDescriptionChanged: onDescriptionChanged,
                              )
                            : _ReadOnlyNoteTile(
                                index: index,
                                entry: entries[index],
                              ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: _notesSectionSpacing),
      ],
    );
  }
}

class _ConnectionsSection extends StatelessWidget {
  const _ConnectionsSection({
    required this.entries,
    required this.isEditing,
    required this.adventureOptions,
    required this.adventureLabelForId,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<HeroConnectionEntry> entries;
  final bool isEditing;
  final List<_AdventureTargetOption> adventureOptions;
  final String Function(String adventureId) adventureLabelForId;
  final Future<void> Function() onAdd;
  final void Function(int index) onRemove;
  final void Function(
    int index, {
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
    String? adventureId,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(_notesPagePadding),
      children: [
        _SectionCard(
          title: 'Kontakte & Verbindungen',
          subtitle: isEditing
              ? 'Pflege Kontakte, Beziehungen und optionale Abenteuer-Bezüge.'
              : 'Öffne einen Eintrag, um Details und die Abenteuer-Zuordnung zu sehen.',
          action: FilledButton(
            key: const ValueKey<String>('notes-add-connection'),
            onPressed: onAdd,
            child: const Text('+ Kontakt'),
          ),
          child: entries.isEmpty
              ? const _EmptyState(
                  message: 'Noch keine Kontakte oder Verbindungen vorhanden.',
                )
              : Column(
                  children: [
                    for (var index = 0; index < entries.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == entries.length - 1
                              ? 0
                              : _notesFieldSpacing,
                        ),
                        child: isEditing
                            ? _EditableConnectionCard(
                                index: index,
                                entry: entries[index],
                                adventureOptions: adventureOptions,
                                onRemove: onRemove,
                                onChanged: onChanged,
                              )
                            : _ReadOnlyConnectionTile(
                                index: index,
                                entry: entries[index],
                                adventureLabelForId: adventureLabelForId,
                              ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: _notesSectionSpacing),
      ],
    );
  }
}

class _EditableNoteCard extends StatelessWidget {
  const _EditableNoteCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
  });

  final int index;
  final HeroNoteEntry entry;
  final void Function(int index) onRemove;
  final void Function(int index, String value) onTitleChanged;
  final void Function(int index, String value) onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Chronik ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('notes-remove-note-$index'),
                  onPressed: () => onRemove(index),
                  tooltip: 'Chronik entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-note-title-$index'),
              initialValue: entry.title,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onTitleChanged(index, value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-note-description-$index'),
              initialValue: entry.description,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onDescriptionChanged(index, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyNoteTile extends StatelessWidget {
  const _ReadOnlyNoteTile({required this.index, required this.entry});

  final int index;
  final HeroNoteEntry entry;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim().isEmpty
        ? 'Unbenannte Chronik'
        : entry.title;
    final description = entry.description.trim().isEmpty
        ? 'Keine Beschreibung hinterlegt.'
        : entry.description;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey<String>('notes-note-tile-$index'),
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(description)),
        ],
      ),
    );
  }
}

class _EditableConnectionCard extends StatelessWidget {
  const _EditableConnectionCard({
    required this.index,
    required this.entry,
    required this.adventureOptions,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final HeroConnectionEntry entry;
  final List<_AdventureTargetOption> adventureOptions;
  final void Function(int index) onRemove;
  final void Function(
    int index, {
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
    String? adventureId,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedAdventureId = entry.adventureId.trim();
    final dropdownValue = normalizedAdventureId.isEmpty
        ? ''
        : adventureOptions.any((option) => option.id == normalizedAdventureId)
        ? normalizedAdventureId
        : '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kontakt ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('notes-remove-connection-$index'),
                  onPressed: () => onRemove(index),
                  tooltip: 'Kontakt entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-connection-name-$index'),
              initialValue: entry.name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(index, name: value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 640;
                final fields = <Widget>[
                  _CompactTextField(
                    fieldKey: ValueKey<String>('notes-connection-ort-$index'),
                    label: 'Ort',
                    initialValue: entry.ort,
                    onChanged: (value) => onChanged(index, ort: value),
                  ),
                  _CompactTextField(
                    fieldKey: ValueKey<String>(
                      'notes-connection-sozialstatus-$index',
                    ),
                    label: 'Sozialstatus',
                    initialValue: entry.sozialstatus,
                    onChanged: (value) => onChanged(index, sozialstatus: value),
                  ),
                  _CompactTextField(
                    fieldKey: ValueKey<String>(
                      'notes-connection-loyalitaet-$index',
                    ),
                    label: 'Loyalität',
                    initialValue: entry.loyalitaet,
                    onChanged: (value) => onChanged(index, loyalitaet: value),
                  ),
                ];
                if (!useTwoColumns) {
                  return Column(
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        fields[i],
                        if (i < fields.length - 1)
                          const SizedBox(height: _notesFieldSpacing),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: _notesFieldSpacing,
                  runSpacing: _notesFieldSpacing,
                  children: fields
                      .map(
                        (field) => SizedBox(
                          width:
                              (constraints.maxWidth - _notesFieldSpacing) / 2,
                          child: field,
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
            const SizedBox(height: _notesFieldSpacing),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('notes-connection-adventure-$index'),
              initialValue: dropdownValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Abenteuer',
                border: OutlineInputBorder(),
              ),
              selectedItemBuilder: (context) {
                return [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kein Abenteuer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...adventureOptions.map(
                    (option) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ];
              },
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    'Kein Abenteuer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...adventureOptions.map(
                  (option) => DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => onChanged(index, adventureId: value ?? ''),
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-connection-description-$index'),
              initialValue: entry.beschreibung,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(index, beschreibung: value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyConnectionTile extends StatelessWidget {
  const _ReadOnlyConnectionTile({
    required this.index,
    required this.entry,
    required this.adventureLabelForId,
  });

  final int index;
  final HeroConnectionEntry entry;
  final String Function(String adventureId) adventureLabelForId;

  @override
  Widget build(BuildContext context) {
    final name = entry.name.trim().isEmpty ? 'Unbenannter Kontakt' : entry.name;
    final adventureLabel = adventureLabelForId(entry.adventureId);
    final chips = <String>[
      if (entry.ort.trim().isNotEmpty) 'Ort: ${entry.ort}',
      if (entry.sozialstatus.trim().isNotEmpty)
        'Sozialstatus: ${entry.sozialstatus}',
      if (entry.loyalitaet.trim().isNotEmpty) 'Loyalität: ${entry.loyalitaet}',
      if (adventureLabel.trim().isNotEmpty) 'Abenteuer: $adventureLabel',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey<String>('notes-connection-tile-$index'),
        title: Text(name),
        subtitle: chips.isEmpty ? null : Text(chips.join('  |  ')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (entry.beschreibung.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(entry.beschreibung),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Keine Beschreibung hinterlegt.'),
            ),
        ],
      ),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final headerChildren = <Widget>[
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ];
    final trailingAction = action;
    if (trailingAction != null) {
      headerChildren.add(trailingAction);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: headerChildren),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: _notesFieldSpacing),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
