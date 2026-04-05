part of 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';

class _AdventuresSection extends StatelessWidget {
  const _AdventuresSection({
    required this.entries,
    required this.selectedAdventureId,
    required this.isEditing,
    required this.onAdd,
    required this.onSelectAdventure,
    required this.onRemoveSelected,
    required this.onMoveSelectedUp,
    required this.onMoveSelectedDown,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onStartWorldDateChanged,
    required this.onStartAventurianDateChanged,
    required this.onEndWorldDateChanged,
    required this.onEndAventurianDateChanged,
    required this.onCurrentAventurianDateChanged,
    required this.onAddNote,
    required this.onOpenNote,
    required this.onAddPerson,
    required this.onOpenPerson,
    required this.onCompleteAdventure,
    required this.onReopenAdventure,
    required this.revokeCheckForAdventure,
  });

  final List<HeroAdventureEntry> entries;
  final String selectedAdventureId;
  final bool isEditing;
  final Future<void> Function() onAdd;
  final void Function(String adventureId) onSelectAdventure;
  final VoidCallback onRemoveSelected;
  final VoidCallback onMoveSelectedUp;
  final VoidCallback onMoveSelectedDown;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onSummaryChanged;
  final ValueChanged<HeroAdventureDateValue> onStartWorldDateChanged;
  final ValueChanged<HeroAdventureDateValue> onStartAventurianDateChanged;
  final ValueChanged<HeroAdventureDateValue> onEndWorldDateChanged;
  final ValueChanged<HeroAdventureDateValue> onEndAventurianDateChanged;
  final ValueChanged<HeroAdventureDateValue> onCurrentAventurianDateChanged;
  final Future<void> Function() onAddNote;
  final Future<void> Function(int noteIndex) onOpenNote;
  final Future<void> Function() onAddPerson;
  final Future<void> Function(int personIndex) onOpenPerson;
  final Future<void> Function(String adventureId) onCompleteAdventure;
  final Future<void> Function(String adventureId) onReopenAdventure;
  final AdventureRewardRevokeCheck Function(String adventureId)
  revokeCheckForAdventure;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = entries.indexWhere(
      (entry) => entry.id == selectedAdventureId,
    );
    final selectedEntry = selectedIndex >= 0 ? entries[selectedIndex] : null;
    final currentEntries = entries
        .where((entry) => entry.status == HeroAdventureStatus.current)
        .toList(growable: false);
    final completedEntries = entries
        .where((entry) => entry.status == HeroAdventureStatus.completed)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(_notesPagePadding),
      children: [
        _SectionCard(
          title: 'Abenteuer',
          subtitle: isEditing
              ? 'Pflege Abenteuer als Übersicht mit Detailfokus, Datumsblöcken, Notizen, Personen und Belohnungen.'
              : 'Wähle ein Abenteuer aus der Übersicht, um Details, Notizen, Personen und Belohnungen zu sehen.',
          action: FilledButton(
            key: const ValueKey<String>('notes-add-adventure'),
            onPressed: onAdd,
            child: const Text('+ Abenteuer'),
          ),
          child: entries.isEmpty
              ? const _EmptyState(message: 'Noch keine Abenteuer vorhanden.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AdventureOverviewGroup(
                      title: 'Aktuell',
                      entries: currentEntries,
                      selectedAdventureId: selectedAdventureId,
                      onSelectAdventure: onSelectAdventure,
                    ),
                    const SizedBox(height: _notesFieldSpacing),
                    _AdventureOverviewGroup(
                      title: 'Abgeschlossen',
                      entries: completedEntries,
                      selectedAdventureId: selectedAdventureId,
                      onSelectAdventure: onSelectAdventure,
                    ),
                    const SizedBox(height: _notesSectionSpacing),
                    if (selectedEntry != null)
                      _AdventureDetailCard(
                        entry: selectedEntry,
                        selectedIndex: selectedIndex,
                        totalEntries: entries.length,
                        isEditing: isEditing,
                        revokeCheck: revokeCheckForAdventure(selectedEntry.id),
                        onMoveUp: onMoveSelectedUp,
                        onMoveDown: onMoveSelectedDown,
                        onRemove: onRemoveSelected,
                        onTitleChanged: onTitleChanged,
                        onSummaryChanged: onSummaryChanged,
                        onStartWorldDateChanged: onStartWorldDateChanged,
                        onStartAventurianDateChanged:
                            onStartAventurianDateChanged,
                        onEndWorldDateChanged: onEndWorldDateChanged,
                        onEndAventurianDateChanged: onEndAventurianDateChanged,
                        onCurrentAventurianDateChanged:
                            onCurrentAventurianDateChanged,
                        onAddNote: onAddNote,
                        onOpenNote: onOpenNote,
                        onAddPerson: onAddPerson,
                        onOpenPerson: onOpenPerson,
                        onCompleteAdventure: onCompleteAdventure,
                        onReopenAdventure: onReopenAdventure,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: _notesSectionSpacing),
      ],
    );
  }
}

class _AdventureOverviewGroup extends StatelessWidget {
  const _AdventureOverviewGroup({
    required this.title,
    required this.entries,
    required this.selectedAdventureId,
    required this.onSelectAdventure,
  });

  final String title;
  final List<HeroAdventureEntry> entries;
  final String selectedAdventureId;
  final void Function(String adventureId) onSelectAdventure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Text(
            'Keine Einträge vorhanden.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries)
                ChoiceChip(
                  key: ValueKey<String>('notes-adventure-chip-${entry.id}'),
                  label: Text(_adventureChipLabel(entry)),
                  selected: entry.id == selectedAdventureId,
                  onSelected: (_) => onSelectAdventure(entry.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _AdventureDetailCard extends StatelessWidget {
  const _AdventureDetailCard({
    required this.entry,
    required this.selectedIndex,
    required this.totalEntries,
    required this.isEditing,
    required this.revokeCheck,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onStartWorldDateChanged,
    required this.onStartAventurianDateChanged,
    required this.onEndWorldDateChanged,
    required this.onEndAventurianDateChanged,
    required this.onCurrentAventurianDateChanged,
    required this.onAddNote,
    required this.onOpenNote,
    required this.onAddPerson,
    required this.onOpenPerson,
    required this.onCompleteAdventure,
    required this.onReopenAdventure,
  });

  final HeroAdventureEntry entry;
  final int selectedIndex;
  final int totalEntries;
  final bool isEditing;
  final AdventureRewardRevokeCheck revokeCheck;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onSummaryChanged;
  final ValueChanged<HeroAdventureDateValue> onStartWorldDateChanged;
  final ValueChanged<HeroAdventureDateValue> onStartAventurianDateChanged;
  final ValueChanged<HeroAdventureDateValue> onEndWorldDateChanged;
  final ValueChanged<HeroAdventureDateValue> onEndAventurianDateChanged;
  final ValueChanged<HeroAdventureDateValue> onCurrentAventurianDateChanged;
  final Future<void> Function() onAddNote;
  final Future<void> Function(int noteIndex) onOpenNote;
  final Future<void> Function() onAddPerson;
  final Future<void> Function(int personIndex) onOpenPerson;
  final Future<void> Function(String adventureId) onCompleteAdventure;
  final Future<void> Function(String adventureId) onReopenAdventure;

  @override
  Widget build(BuildContext context) {
    final rewardLocked = entry.rewardsApplied;
    final completionAction = switch (entry.status) {
      HeroAdventureStatus.current => FilledButton.icon(
        key: ValueKey<String>('notes-adventure-complete-${entry.id}'),
        onPressed: () => onCompleteAdventure(entry.id),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Abschließen'),
      ),
      HeroAdventureStatus.completed => Tooltip(
        message: revokeCheck.isAllowed
            ? 'Abschluss zurücknehmen'
            : revokeCheck.reason,
        child: FilledButton.tonalIcon(
          key: ValueKey<String>('notes-adventure-reopen-${entry.id}'),
          onPressed: revokeCheck.isAllowed
              ? () => onReopenAdventure(entry.id)
              : null,
          icon: const Icon(Icons.undo),
          label: const Text('Abschluss zurücknehmen'),
        ),
      ),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          key: ValueKey<String>('notes-adventure-detail-${entry.id}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _adventureChipLabel(entry),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!isEditing) ...[completionAction, const SizedBox(width: 8)],
                if (isEditing) ...[
                  IconButton(
                    key: ValueKey<String>(
                      'notes-adventure-move-up-${entry.id}',
                    ),
                    onPressed: selectedIndex <= 0 ? null : onMoveUp,
                    tooltip: 'Nach oben',
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    key: ValueKey<String>(
                      'notes-adventure-move-down-${entry.id}',
                    ),
                    onPressed: selectedIndex >= totalEntries - 1
                        ? null
                        : onMoveDown,
                    tooltip: 'Nach unten',
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    key: ValueKey<String>('notes-remove-adventure-${entry.id}'),
                    onPressed: rewardLocked ? null : onRemove,
                    tooltip: rewardLocked
                        ? 'Belohnungen zuerst zurücknehmen'
                        : 'Abenteuer entfernen',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            if (rewardLocked && isEditing) ...[
              const SizedBox(height: 8),
              Text(
                'Belohnungen, Dukaten und Abschluss-Gegenstände sind gesperrt, bis der Abschluss zurückgenommen wird.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: _notesFieldSpacing),
            if (isEditing) ...[
              TextFormField(
                key: ValueKey<String>('notes-adventure-title-${entry.id}'),
                initialValue: entry.title,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
                onChanged: onTitleChanged,
              ),
              const SizedBox(height: _notesFieldSpacing),
              TextFormField(
                key: ValueKey<String>('notes-adventure-summary-${entry.id}'),
                initialValue: entry.summary,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Zusammenfassung',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: onSummaryChanged,
              ),
            ] else ...[
              _ReadOnlyTextBlock(
                title: 'Titel',
                value: entry.title.trim(),
                emptyValue: 'Kein Titel hinterlegt.',
              ),
              const SizedBox(height: _notesFieldSpacing),
              _ReadOnlyTextBlock(
                title: 'Zusammenfassung',
                value: entry.summary.trim(),
                emptyValue: 'Keine Zusammenfassung hinterlegt.',
              ),
            ],
            const SizedBox(height: _notesFieldSpacing),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [Chip(label: Text(_statusLabel(entry.status)))],
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureDateBlock(
              title: 'Start des Abenteuers',
              entryId: entry.id,
              isEditing: isEditing,
              worldDate: entry.startWorldDate,
              aventurianDate: entry.startAventurianDate,
              worldPrefix: 'notes-adventure-start-world',
              aventurianPrefix: 'notes-adventure-start-aventurian',
              onWorldDateChanged: onStartWorldDateChanged,
              onAventurianDateChanged: onStartAventurianDateChanged,
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureDateBlock(
              title: 'Ende des Abenteuers',
              entryId: entry.id,
              isEditing: false,
              worldDate: entry.endWorldDate,
              aventurianDate: entry.endAventurianDate,
              worldPrefix: 'notes-adventure-end-world',
              aventurianPrefix: 'notes-adventure-end-aventurian',
              onWorldDateChanged: onEndWorldDateChanged,
              onAventurianDateChanged: onEndAventurianDateChanged,
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureCurrentDateBlock(
              entryId: entry.id,
              date: entry.currentAventurianDate,
              onChanged: onCurrentAventurianDateChanged,
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureNoteExpansion(
              entry: entry,
              onAdd: onAddNote,
              onOpen: onOpenNote,
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventurePeopleExpansion(
              entry: entry,
              onAdd: onAddPerson,
              onOpen: onOpenPerson,
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureSubsectionHeader(title: 'Belohnungen'),
            const SizedBox(height: 8),
            _ReadOnlyAdventureRewards(entry: entry),
            if (isEditing) ...[
              const SizedBox(height: 8),
              Text(
                'AP und Sondererfahrungen werden im Abschließen-Dialog erfasst.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: _notesFieldSpacing),
            _AdventureSubsectionHeader(title: 'Abschluss'),
            const SizedBox(height: 8),
            _AdventureCompletionSummary(entry: entry),
          ],
        ),
      ),
    );
  }
}

class _AdventureStatusField extends StatelessWidget {
  const _AdventureStatusField({
    required this.currentValue,
    required this.fieldKeyPrefix,
    required this.onChanged,
  });

  final HeroAdventureStatus currentValue;
  final String fieldKeyPrefix;
  final ValueChanged<HeroAdventureStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Status', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: ValueKey<String>('$fieldKeyPrefix-current'),
              label: const Text('Aktuell'),
              selected: currentValue == HeroAdventureStatus.current,
              onSelected: (_) => onChanged(HeroAdventureStatus.current),
            ),
            ChoiceChip(
              key: ValueKey<String>('$fieldKeyPrefix-completed'),
              label: const Text('Abgeschlossen'),
              selected: currentValue == HeroAdventureStatus.completed,
              onSelected: (_) => onChanged(HeroAdventureStatus.completed),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdventureDateBlock extends StatelessWidget {
  const _AdventureDateBlock({
    required this.title,
    required this.entryId,
    required this.isEditing,
    required this.worldDate,
    required this.aventurianDate,
    required this.worldPrefix,
    required this.aventurianPrefix,
    required this.onWorldDateChanged,
    required this.onAventurianDateChanged,
  });

  final String title;
  final String entryId;
  final bool isEditing;
  final HeroAdventureDateValue worldDate;
  final HeroAdventureDateValue aventurianDate;
  final String worldPrefix;
  final String aventurianPrefix;
  final ValueChanged<HeroAdventureDateValue> onWorldDateChanged;
  final ValueChanged<HeroAdventureDateValue> onAventurianDateChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdventureSubsectionHeader(title: title),
        const SizedBox(height: 8),
        if (isEditing)
          Column(
            children: [
              _AdventureDateEditor(
                title: 'Weltlich',
                keyPrefix: '$worldPrefix-$entryId',
                value: worldDate,
                usesAventurianMonthPicker: false,
                onChanged: onWorldDateChanged,
              ),
              const SizedBox(height: 12),
              _AdventureDateEditor(
                title: 'Aventurisch',
                keyPrefix: '$aventurianPrefix-$entryId',
                value: aventurianDate,
                usesAventurianMonthPicker: true,
                onChanged: onAventurianDateChanged,
              ),
            ],
          )
        else
          _AdventureDateSummary(
            worldDate: worldDate,
            aventurianDate: aventurianDate,
          ),
      ],
    );
  }
}

class _AdventureCurrentDateBlock extends StatelessWidget {
  const _AdventureCurrentDateBlock({
    required this.entryId,
    required this.date,
    required this.onChanged,
  });

  final String entryId;
  final HeroAdventureDateValue date;
  final ValueChanged<HeroAdventureDateValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AdventureSubsectionHeader(title: 'Aktuelles Datum'),
        const SizedBox(height: 8),
        _AdventureDateEditor(
          title: 'Aventurisch',
          keyPrefix: 'notes-adventure-current-aventurian-$entryId',
          value: date,
          usesAventurianMonthPicker: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AdventureDateEditor extends StatelessWidget {
  const _AdventureDateEditor({
    required this.title,
    required this.keyPrefix,
    required this.value,
    required this.usesAventurianMonthPicker,
    required this.onChanged,
  });

  final String title;
  final String keyPrefix;
  final HeroAdventureDateValue value;
  final bool usesAventurianMonthPicker;
  final ValueChanged<HeroAdventureDateValue> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedMonth = usesAventurianMonthPicker
        ? _normalizeAventurianMonthValue(value.month)
        : value.month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final useColumns = constraints.maxWidth >= 540;
            final fieldWidth = useColumns
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            final fields = <Widget>[
              SizedBox(
                width: fieldWidth,
                child: TextFormField(
                  key: ValueKey<String>('$keyPrefix-day'),
                  initialValue: value.day,
                  decoration: const InputDecoration(
                    labelText: 'Tag',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (nextDay) =>
                      onChanged(value.copyWith(day: nextDay)),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: usesAventurianMonthPicker
                    ? DropdownButtonFormField<String>(
                        key: ValueKey<String>('$keyPrefix-month'),
                        initialValue: normalizedMonth.isEmpty
                            ? null
                            : normalizedMonth,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Monat',
                          border: OutlineInputBorder(),
                        ),
                        selectedItemBuilder: (context) {
                          return _aventurianMonthOptions
                              .map(
                                (option) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(growable: false);
                        },
                        items: _aventurianMonthOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option.value,
                                child: Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (nextMonth) =>
                            onChanged(value.copyWith(month: nextMonth ?? '')),
                      )
                    : TextFormField(
                        key: ValueKey<String>('$keyPrefix-month'),
                        initialValue: value.month,
                        decoration: const InputDecoration(
                          labelText: 'Monat',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (nextMonth) =>
                            onChanged(value.copyWith(month: nextMonth)),
                      ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextFormField(
                  key: ValueKey<String>('$keyPrefix-year'),
                  initialValue: value.year,
                  decoration: const InputDecoration(
                    labelText: 'Jahr',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (nextYear) =>
                      onChanged(value.copyWith(year: nextYear)),
                ),
              ),
            ];
            return Wrap(spacing: 12, runSpacing: 12, children: fields);
          },
        ),
      ],
    );
  }
}

class _AdventureDateSummary extends StatelessWidget {
  const _AdventureDateSummary({
    required this.worldDate,
    required this.aventurianDate,
  });

  final HeroAdventureDateValue worldDate;
  final HeroAdventureDateValue aventurianDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final blockWidth = constraints.maxWidth >= 640
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: blockWidth,
              child: _ReadOnlyTextBlock(
                title: 'Weltlich',
                value: _formatDateValue(worldDate),
                emptyValue: 'Nicht gepflegt.',
              ),
            ),
            SizedBox(
              width: blockWidth,
              child: _ReadOnlyTextBlock(
                title: 'Aventurisch',
                value: _formatDateValue(
                  aventurianDate,
                  usesAventurianMonthLabel: true,
                ),
                emptyValue: 'Nicht gepflegt.',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdventureNoteExpansion extends StatelessWidget {
  const _AdventureNoteExpansion({
    required this.entry,
    required this.onAdd,
    required this.onOpen,
  });

  final HeroAdventureEntry entry;
  final Future<void> Function() onAdd;
  final Future<void> Function(int noteIndex) onOpen;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey<String>('notes-adventure-notes-${entry.id}'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Notizen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton(
            key: ValueKey<String>('notes-adventure-add-note-${entry.id}'),
            onPressed: onAdd,
            child: const Text('+ Notiz'),
          ),
        ],
      ),
      children: [
        if (entry.notes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _EmptyState(
              message: 'Noch keine abenteuerbezogenen Notizen vorhanden.',
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < entry.notes.length; index++)
                  ActionChip(
                    key: ValueKey<String>(
                      'notes-adventure-note-chip-${entry.id}-$index',
                    ),
                    label: Text(_noteChipLabel(entry.notes[index])),
                    onPressed: () => onOpen(index),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AdventurePeopleExpansion extends StatelessWidget {
  const _AdventurePeopleExpansion({
    required this.entry,
    required this.onAdd,
    required this.onOpen,
  });

  final HeroAdventureEntry entry;
  final Future<void> Function() onAdd;
  final Future<void> Function(int personIndex) onOpen;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey<String>('notes-adventure-people-${entry.id}'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Personen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton(
            key: ValueKey<String>('notes-adventure-add-person-${entry.id}'),
            onPressed: onAdd,
            child: const Text('+ Person'),
          ),
        ],
      ),
      children: [
        if (entry.people.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _EmptyState(message: 'Noch keine Personen vorhanden.'),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < entry.people.length; index++)
                  ActionChip(
                    key: ValueKey<String>(
                      'notes-adventure-person-chip-${entry.id}-${entry.people[index].id}',
                    ),
                    label: Text(_personChipLabel(entry.people[index])),
                    onPressed: () => onOpen(index),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _EditableAdventureRewards extends StatelessWidget {
  const _EditableAdventureRewards({
    required this.entry,
    required this.rewardLocked,
    required this.targetOptionsForType,
    required this.onApRewardChanged,
    required this.onAddSeReward,
    required this.onRemoveSeReward,
    required this.onSeRewardTypeChanged,
    required this.onSeRewardTargetChanged,
    required this.onSeRewardCountChanged,
  });

  final HeroAdventureEntry entry;
  final bool rewardLocked;
  final List<_AdventureTargetOption> Function(HeroAdventureSeTargetType type)
  targetOptionsForType;
  final ValueChanged<String> onApRewardChanged;
  final VoidCallback onAddSeReward;
  final void Function(int rewardIndex) onRemoveSeReward;
  final void Function(int rewardIndex, HeroAdventureSeTargetType type)
  onSeRewardTypeChanged;
  final void Function(
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  })
  onSeRewardTargetChanged;
  final void Function(int rewardIndex, String rawValue) onSeRewardCountChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey<String>('notes-adventure-ap-${entry.id}'),
          initialValue: entry.apReward.toString(),
          enabled: !rewardLocked,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'AP',
            border: OutlineInputBorder(),
          ),
          onChanged: rewardLocked ? null : onApRewardChanged,
        ),
        const SizedBox(height: _notesFieldSpacing),
        _AdventureSubsectionHeader(
          title: 'Sondererfahrungen',
          action: TextButton(
            key: ValueKey<String>('notes-adventure-add-se-${entry.id}'),
            onPressed: rewardLocked ? null : onAddSeReward,
            child: const Text('+ Sondererfahrung'),
          ),
        ),
        const SizedBox(height: 8),
        if (entry.seRewards.isEmpty)
          const _EmptyState(message: 'Noch keine Sondererfahrungen definiert.')
        else
          Column(
            children: [
              for (
                var rewardIndex = 0;
                rewardIndex < entry.seRewards.length;
                rewardIndex++
              )
                Padding(
                  padding: EdgeInsets.only(
                    top: rewardIndex == 0 ? 0 : _notesFieldSpacing,
                  ),
                  child: _EditableAdventureSeRewardCard(
                    adventureId: entry.id,
                    rewardIndex: rewardIndex,
                    entry: entry.seRewards[rewardIndex],
                    rewardLocked: rewardLocked,
                    targetOptions: targetOptionsForType(
                      entry.seRewards[rewardIndex].targetType,
                    ),
                    onRemove: onRemoveSeReward,
                    onTypeChanged: onSeRewardTypeChanged,
                    onTargetChanged: onSeRewardTargetChanged,
                    onCountChanged: onSeRewardCountChanged,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _EditableAdventureSeRewardCard extends StatelessWidget {
  const _EditableAdventureSeRewardCard({
    required this.adventureId,
    required this.rewardIndex,
    required this.entry,
    required this.rewardLocked,
    required this.targetOptions,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onTargetChanged,
    required this.onCountChanged,
  });

  final String adventureId;
  final int rewardIndex;
  final HeroAdventureSeReward entry;
  final bool rewardLocked;
  final List<_AdventureTargetOption> targetOptions;
  final void Function(int rewardIndex) onRemove;
  final void Function(int rewardIndex, HeroAdventureSeTargetType type)
  onTypeChanged;
  final void Function(
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  })
  onTargetChanged;
  final void Function(int rewardIndex, String rawValue) onCountChanged;

  @override
  Widget build(BuildContext context) {
    final targetValue = entry.targetId.trim();
    final resolvedTargetValue =
        targetOptions.any((option) => option.id == targetValue)
        ? targetValue
        : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sondererfahrung ${rewardIndex + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'notes-adventure-remove-se-$adventureId-$rewardIndex',
                  ),
                  onPressed: rewardLocked ? null : () => onRemove(rewardIndex),
                  tooltip: 'Sondererfahrung entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            DropdownButtonFormField<HeroAdventureSeTargetType>(
              key: ValueKey<String>(
                'notes-adventure-se-type-$adventureId-$rewardIndex',
              ),
              initialValue: entry.targetType,
              decoration: const InputDecoration(
                labelText: 'Zieltyp',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<HeroAdventureSeTargetType>(
                  value: HeroAdventureSeTargetType.talent,
                  child: Text('Talent'),
                ),
                DropdownMenuItem<HeroAdventureSeTargetType>(
                  value: HeroAdventureSeTargetType.grundwert,
                  child: Text('Grundwert'),
                ),
                DropdownMenuItem<HeroAdventureSeTargetType>(
                  value: HeroAdventureSeTargetType.eigenschaft,
                  child: Text('Eigenschaft'),
                ),
              ],
              onChanged: rewardLocked
                  ? null
                  : (value) {
                      if (value != null) {
                        onTypeChanged(rewardIndex, value);
                      }
                    },
            ),
            const SizedBox(height: _notesFieldSpacing),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'notes-adventure-se-target-$adventureId-$rewardIndex',
              ),
              initialValue: resolvedTargetValue,
              decoration: const InputDecoration(
                labelText: 'Ziel',
                border: OutlineInputBorder(),
              ),
              items: targetOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(option.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: rewardLocked
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      final option = targetOptions
                          .where((candidate) => candidate.id == value)
                          .firstOrNull;
                      onTargetChanged(
                        rewardIndex,
                        targetId: value,
                        targetLabel: option?.label ?? value,
                      );
                    },
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>(
                'notes-adventure-se-count-$adventureId-$rewardIndex',
              ),
              initialValue: entry.count.toString(),
              enabled: !rewardLocked,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Anzahl',
                border: OutlineInputBorder(),
              ),
              onChanged: rewardLocked
                  ? null
                  : (value) => onCountChanged(rewardIndex, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyAdventureRewards extends StatelessWidget {
  const _ReadOnlyAdventureRewards({required this.entry});

  final HeroAdventureEntry entry;

  @override
  Widget build(BuildContext context) {
    final rewardWidgets = <Widget>[
      if (entry.apReward > 0) Chip(label: Text('+${entry.apReward} AP')),
      ...entry.seRewards
          .where((reward) => reward.hasContent)
          .map(
            (reward) =>
                Chip(label: Text('${reward.count}× ${_rewardLabel(reward)}')),
          ),
    ];
    if (rewardWidgets.isEmpty) {
      return const Text('Keine AP- oder SE-Belohnungen definiert.');
    }

    return Wrap(spacing: 8, runSpacing: 8, children: rewardWidgets);
  }
}

class _AdventureCompletionSummary extends StatelessWidget {
  const _AdventureCompletionSummary({required this.entry});

  final HeroAdventureEntry entry;

  @override
  Widget build(BuildContext context) {
    final lootEntries = entry.lootRewards
        .where((loot) => loot.hasContent)
        .toList(growable: false);
    final rewardParts = <Widget>[
      if (entry.dukatenReward > 0)
        Chip(
          label: Text('${_formatDukatenReward(entry.dukatenReward)} Dukaten'),
        ),
      for (final loot in lootEntries)
        Chip(
          label: Text(
            loot.quantity.trim().isEmpty
                ? _lootRewardLabel(loot)
                : '${loot.quantity.trim()}× ${_lootRewardLabel(loot)}',
          ),
        ),
    ];

    if (rewardParts.isEmpty) {
      return const Text('Keine Dukaten oder Gegenstände hinterlegt.');
    }

    return Wrap(spacing: 8, runSpacing: 8, children: rewardParts);
  }
}

class _ReadOnlyTextBlock extends StatelessWidget {
  const _ReadOnlyTextBlock({
    required this.title,
    required this.value,
    required this.emptyValue,
  });

  final String title;
  final String value;
  final String emptyValue;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? emptyValue : value.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(displayValue),
      ],
    );
  }
}

class _AdventureSubsectionHeader extends StatelessWidget {
  const _AdventureSubsectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    if (action == null) {
      return Text(title, style: Theme.of(context).textTheme.titleSmall);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStackAction = constraints.maxWidth <= 320;
        if (shouldStackAction) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Align(alignment: Alignment.centerRight, child: action!),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            action!,
          ],
        );
      },
    );
  }
}

String _adventureChipLabel(HeroAdventureEntry entry) {
  final title = entry.title.trim();
  return title.isEmpty ? 'Unbenanntes Abenteuer' : title;
}

String _statusLabel(HeroAdventureStatus status) {
  return switch (status) {
    HeroAdventureStatus.current => 'Aktuell',
    HeroAdventureStatus.completed => 'Abgeschlossen',
  };
}

String _noteChipLabel(HeroNoteEntry note) {
  final title = note.title.trim();
  if (title.isNotEmpty) {
    return title;
  }

  final description = note.description.trim();
  if (description.isEmpty) {
    return 'Notiz';
  }
  if (description.length <= 32) {
    return description;
  }
  return '${description.substring(0, 29)}...';
}

String _personChipLabel(HeroAdventurePersonEntry person) {
  final name = person.name.trim();
  return name.isEmpty ? 'Person' : name;
}

String _formatDateValue(
  HeroAdventureDateValue value, {
  bool usesAventurianMonthLabel = false,
}) {
  final parts = <String>[
    value.day.trim(),
    usesAventurianMonthLabel
        ? _aventurianMonthLabel(value.month)
        : value.month.trim(),
    value.year.trim(),
  ].where((entry) => entry.isNotEmpty).toList(growable: false);
  return parts.join(' ').trim();
}

String _rewardLabel(HeroAdventureSeReward reward) {
  final label = reward.targetLabel.trim();
  if (label.isNotEmpty) {
    return label;
  }
  return reward.targetId.trim().isEmpty ? 'Zielwert' : reward.targetId;
}

String _lootRewardLabel(HeroAdventureLootEntry loot) {
  final label = loot.name.trim();
  return label.isEmpty ? 'Gegenstand' : label;
}

String _formatDukatenReward(double value) {
  final isWhole = value == value.roundToDouble();
  if (isWhole) {
    return value.round().toString();
  }
  final trimmed = value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return trimmed.replaceAll('.', ',');
}
