part of 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';

class _AdventuresSection extends StatelessWidget {
  const _AdventuresSection({
    required this.entries,
    required this.isEditing,
    required this.onAdd,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onApRewardChanged,
    required this.onAddNote,
    required this.onRemoveNote,
    required this.onAdventureNoteTitleChanged,
    required this.onAdventureNoteDescriptionChanged,
    required this.onAddSeReward,
    required this.onRemoveSeReward,
    required this.onSeRewardTypeChanged,
    required this.onSeRewardTargetChanged,
    required this.onSeRewardCountChanged,
    required this.onApplyRewards,
    required this.onRevokeRewards,
    required this.targetOptionsForType,
    required this.revokeCheckForAdventure,
  });

  final List<HeroAdventureEntry> entries;
  final bool isEditing;
  final Future<void> Function() onAdd;
  final void Function(int index) onRemove;
  final void Function(int index) onMoveUp;
  final void Function(int index) onMoveDown;
  final void Function(int index, String value) onTitleChanged;
  final void Function(int index, String value) onSummaryChanged;
  final void Function(int index, String rawValue) onApRewardChanged;
  final void Function(int adventureIndex) onAddNote;
  final void Function(int adventureIndex, int noteIndex) onRemoveNote;
  final void Function(int adventureIndex, int noteIndex, String value)
  onAdventureNoteTitleChanged;
  final void Function(int adventureIndex, int noteIndex, String value)
  onAdventureNoteDescriptionChanged;
  final void Function(int adventureIndex) onAddSeReward;
  final void Function(int adventureIndex, int rewardIndex) onRemoveSeReward;
  final void Function(
    int adventureIndex,
    int rewardIndex,
    HeroAdventureSeTargetType type,
  )
  onSeRewardTypeChanged;
  final void Function(
    int adventureIndex,
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  })
  onSeRewardTargetChanged;
  final void Function(int adventureIndex, int rewardIndex, String rawValue)
  onSeRewardCountChanged;
  final Future<void> Function(String adventureId) onApplyRewards;
  final Future<void> Function(String adventureId) onRevokeRewards;
  final List<_AdventureTargetOption> Function(HeroAdventureSeTargetType type)
  targetOptionsForType;
  final AdventureRewardRevokeCheck Function(String adventureId)
  revokeCheckForAdventure;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(_notesPagePadding),
      children: [
        _SectionCard(
          title: 'Abenteuer',
          subtitle: isEditing
              ? 'Pflege die Etappen des Helden mit Notizen, AP und Sondererfahrungen.'
              : 'Öffne ein Abenteuer für Zusammenfassung, Notizen und Belohnungen.',
          action: FilledButton(
            key: const ValueKey<String>('notes-add-adventure'),
            onPressed: onAdd,
            child: const Text('+ Abenteuer'),
          ),
          child: entries.isEmpty
              ? const _EmptyState(message: 'Noch keine Abenteuer vorhanden.')
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
                            ? _EditableAdventureCard(
                                index: index,
                                entry: entries[index],
                                isFirst: index == 0,
                                isLast: index == entries.length - 1,
                                targetOptionsForType: targetOptionsForType,
                                onRemove: onRemove,
                                onMoveUp: onMoveUp,
                                onMoveDown: onMoveDown,
                                onTitleChanged: onTitleChanged,
                                onSummaryChanged: onSummaryChanged,
                                onApRewardChanged: onApRewardChanged,
                                onAddNote: onAddNote,
                                onRemoveNote: onRemoveNote,
                                onAdventureNoteTitleChanged:
                                    onAdventureNoteTitleChanged,
                                onAdventureNoteDescriptionChanged:
                                    onAdventureNoteDescriptionChanged,
                                onAddSeReward: onAddSeReward,
                                onRemoveSeReward: onRemoveSeReward,
                                onSeRewardTypeChanged: onSeRewardTypeChanged,
                                onSeRewardTargetChanged:
                                    onSeRewardTargetChanged,
                                onSeRewardCountChanged: onSeRewardCountChanged,
                              )
                            : _ReadOnlyAdventureTile(
                                entry: entries[index],
                                revokeCheck: revokeCheckForAdventure(
                                  entries[index].id,
                                ),
                                onApplyRewards: onApplyRewards,
                                onRevokeRewards: onRevokeRewards,
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

class _EditableAdventureCard extends StatelessWidget {
  const _EditableAdventureCard({
    required this.index,
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.targetOptionsForType,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTitleChanged,
    required this.onSummaryChanged,
    required this.onApRewardChanged,
    required this.onAddNote,
    required this.onRemoveNote,
    required this.onAdventureNoteTitleChanged,
    required this.onAdventureNoteDescriptionChanged,
    required this.onAddSeReward,
    required this.onRemoveSeReward,
    required this.onSeRewardTypeChanged,
    required this.onSeRewardTargetChanged,
    required this.onSeRewardCountChanged,
  });

  final int index;
  final HeroAdventureEntry entry;
  final bool isFirst;
  final bool isLast;
  final List<_AdventureTargetOption> Function(HeroAdventureSeTargetType type)
  targetOptionsForType;
  final void Function(int index) onRemove;
  final void Function(int index) onMoveUp;
  final void Function(int index) onMoveDown;
  final void Function(int index, String value) onTitleChanged;
  final void Function(int index, String value) onSummaryChanged;
  final void Function(int index, String rawValue) onApRewardChanged;
  final void Function(int adventureIndex) onAddNote;
  final void Function(int adventureIndex, int noteIndex) onRemoveNote;
  final void Function(int adventureIndex, int noteIndex, String value)
  onAdventureNoteTitleChanged;
  final void Function(int adventureIndex, int noteIndex, String value)
  onAdventureNoteDescriptionChanged;
  final void Function(int adventureIndex) onAddSeReward;
  final void Function(int adventureIndex, int rewardIndex) onRemoveSeReward;
  final void Function(
    int adventureIndex,
    int rewardIndex,
    HeroAdventureSeTargetType type,
  )
  onSeRewardTypeChanged;
  final void Function(
    int adventureIndex,
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  })
  onSeRewardTargetChanged;
  final void Function(int adventureIndex, int rewardIndex, String rawValue)
  onSeRewardCountChanged;

  @override
  Widget build(BuildContext context) {
    final rewardLocked = entry.rewardsApplied;
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
                    'Abenteuer ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('notes-adventure-move-up-$index'),
                  onPressed: isFirst ? null : () => onMoveUp(index),
                  tooltip: 'Nach oben',
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  key: ValueKey<String>('notes-adventure-move-down-$index'),
                  onPressed: isLast ? null : () => onMoveDown(index),
                  tooltip: 'Nach unten',
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  key: ValueKey<String>('notes-remove-adventure-$index'),
                  onPressed: rewardLocked ? null : () => onRemove(index),
                  tooltip: rewardLocked
                      ? 'Belohnungen zuerst zurücknehmen'
                      : 'Abenteuer entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (rewardLocked) ...[
              Text(
                'Belohnungen wurden bereits angewendet. AP und Sondererfahrungen sind gesperrt, bis sie zurückgenommen werden.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: _notesFieldSpacing),
            ],
            TextFormField(
              key: ValueKey<String>('notes-adventure-title-$index'),
              initialValue: entry.title,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onTitleChanged(index, value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>('notes-adventure-summary-$index'),
              initialValue: entry.summary,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Zusammenfassung',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onSummaryChanged(index, value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureSubsectionHeader(
              title: 'Abenteuer-Notizen',
              action: TextButton(
                key: ValueKey<String>('notes-adventure-add-note-$index'),
                onPressed: () => onAddNote(index),
                child: const Text('+ Notiz'),
              ),
            ),
            if (entry.notes.isEmpty)
              const _EmptyState(
                message: 'Noch keine abenteuerbezogenen Notizen vorhanden.',
              )
            else
              Column(
                children: [
                  for (
                    var noteIndex = 0;
                    noteIndex < entry.notes.length;
                    noteIndex++
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        top: noteIndex == 0 ? 0 : _notesFieldSpacing,
                      ),
                      child: _EditableAdventureNoteCard(
                        adventureIndex: index,
                        noteIndex: noteIndex,
                        entry: entry.notes[noteIndex],
                        onRemove: onRemoveNote,
                        onTitleChanged: onAdventureNoteTitleChanged,
                        onDescriptionChanged: onAdventureNoteDescriptionChanged,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureSubsectionHeader(title: 'Belohnungen'),
            TextFormField(
              key: ValueKey<String>('notes-adventure-ap-$index'),
              initialValue: entry.apReward.toString(),
              enabled: !rewardLocked,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'AP',
                border: OutlineInputBorder(),
              ),
              onChanged: rewardLocked
                  ? null
                  : (value) => onApRewardChanged(index, value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            _AdventureSubsectionHeader(
              title: 'Sondererfahrungen',
              action: TextButton(
                key: ValueKey<String>('notes-adventure-add-se-$index'),
                onPressed: rewardLocked ? null : () => onAddSeReward(index),
                child: const Text('+ Sondererfahrung'),
              ),
            ),
            if (entry.seRewards.isEmpty)
              const _EmptyState(
                message: 'Noch keine Sondererfahrungen definiert.',
              )
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
                        adventureIndex: index,
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
        ),
      ),
    );
  }
}

class _EditableAdventureNoteCard extends StatelessWidget {
  const _EditableAdventureNoteCard({
    required this.adventureIndex,
    required this.noteIndex,
    required this.entry,
    required this.onRemove,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
  });

  final int adventureIndex;
  final int noteIndex;
  final HeroNoteEntry entry;
  final void Function(int adventureIndex, int noteIndex) onRemove;
  final void Function(int adventureIndex, int noteIndex, String value)
  onTitleChanged;
  final void Function(int adventureIndex, int noteIndex, String value)
  onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
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
                    'Notiz ${noteIndex + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'notes-adventure-remove-note-$adventureIndex-$noteIndex',
                  ),
                  onPressed: () => onRemove(adventureIndex, noteIndex),
                  tooltip: 'Notiz entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>(
                'notes-adventure-note-title-$adventureIndex-$noteIndex',
              ),
              initialValue: entry.title,
              decoration: const InputDecoration(
                labelText: 'Titel',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  onTitleChanged(adventureIndex, noteIndex, value),
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>(
                'notes-adventure-note-description-$adventureIndex-$noteIndex',
              ),
              initialValue: entry.description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  onDescriptionChanged(adventureIndex, noteIndex, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableAdventureSeRewardCard extends StatelessWidget {
  const _EditableAdventureSeRewardCard({
    required this.adventureIndex,
    required this.rewardIndex,
    required this.entry,
    required this.rewardLocked,
    required this.targetOptions,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onTargetChanged,
    required this.onCountChanged,
  });

  final int adventureIndex;
  final int rewardIndex;
  final HeroAdventureSeReward entry;
  final bool rewardLocked;
  final List<_AdventureTargetOption> targetOptions;
  final void Function(int adventureIndex, int rewardIndex) onRemove;
  final void Function(
    int adventureIndex,
    int rewardIndex,
    HeroAdventureSeTargetType type,
  )
  onTypeChanged;
  final void Function(
    int adventureIndex,
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  })
  onTargetChanged;
  final void Function(int adventureIndex, int rewardIndex, String rawValue)
  onCountChanged;

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
                    'notes-adventure-remove-se-$adventureIndex-$rewardIndex',
                  ),
                  onPressed: rewardLocked
                      ? null
                      : () => onRemove(adventureIndex, rewardIndex),
                  tooltip: 'Sondererfahrung entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            DropdownButtonFormField<HeroAdventureSeTargetType>(
              key: ValueKey<String>(
                'notes-adventure-se-type-$adventureIndex-$rewardIndex',
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
                        onTypeChanged(adventureIndex, rewardIndex, value);
                      }
                    },
            ),
            const SizedBox(height: _notesFieldSpacing),
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'notes-adventure-se-target-$adventureIndex-$rewardIndex',
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
                          .where((entry) => entry.id == value)
                          .firstOrNull;
                      onTargetChanged(
                        adventureIndex,
                        rewardIndex,
                        targetId: value,
                        targetLabel: option?.label ?? value,
                      );
                    },
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextFormField(
              key: ValueKey<String>(
                'notes-adventure-se-count-$adventureIndex-$rewardIndex',
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
                  : (value) =>
                        onCountChanged(adventureIndex, rewardIndex, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyAdventureTile extends StatelessWidget {
  const _ReadOnlyAdventureTile({
    required this.entry,
    required this.revokeCheck,
    required this.onApplyRewards,
    required this.onRevokeRewards,
  });

  final HeroAdventureEntry entry;
  final AdventureRewardRevokeCheck revokeCheck;
  final Future<void> Function(String adventureId) onApplyRewards;
  final Future<void> Function(String adventureId) onRevokeRewards;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.trim().isEmpty
        ? 'Unbenanntes Abenteuer'
        : entry.title;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey<String>('notes-adventure-tile-${entry.id}'),
        title: Text(title),
        subtitle: _AdventureRewardsSummary(entry: entry),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (entry.summary.trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(entry.summary),
              ),
            ),
          if (entry.notes.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notizen',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            for (final note in entry.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_formatAdventureNote(note)),
                ),
              ),
          ],
          if (entry.hasRewards) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.apReward > 0)
                  Chip(label: Text('+${entry.apReward} AP')),
                ...entry.seRewards
                    .where((reward) => reward.hasContent)
                    .map(
                      (reward) => Chip(
                        label: Text('${reward.count}× ${_rewardLabel(reward)}'),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: entry.rewardsApplied
                  ? Tooltip(
                      message: revokeCheck.isAllowed
                          ? 'Belohnungen zurücknehmen'
                          : revokeCheck.reason,
                      child: FilledButton.tonalIcon(
                        key: ValueKey<String>(
                          'notes-adventure-revoke-${entry.id}',
                        ),
                        onPressed: revokeCheck.isAllowed
                            ? () => onRevokeRewards(entry.id)
                            : null,
                        icon: const Icon(Icons.undo),
                        label: const Text('Belohnungen zurücknehmen'),
                      ),
                    )
                  : FilledButton.icon(
                      key: ValueKey<String>(
                        'notes-adventure-apply-${entry.id}',
                      ),
                      onPressed: () => onApplyRewards(entry.id),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Belohnungen anwenden'),
                    ),
            ),
          ] else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Keine Belohnungen definiert.'),
            ),
        ],
      ),
    );
  }

  String _formatAdventureNote(HeroNoteEntry note) {
    final title = note.title.trim();
    final description = note.description.trim();
    if (title.isEmpty) {
      return description;
    }
    if (description.isEmpty) {
      return title;
    }
    return '$title: $description';
  }

  String _rewardLabel(HeroAdventureSeReward reward) {
    final label = reward.targetLabel.trim();
    if (label.isNotEmpty) {
      return label;
    }
    return reward.targetId.trim().isEmpty ? 'Zielwert' : reward.targetId;
  }
}

class _AdventureRewardsSummary extends StatelessWidget {
  const _AdventureRewardsSummary({required this.entry});

  final HeroAdventureEntry entry;

  @override
  Widget build(BuildContext context) {
    final values = <String>[];
    if (entry.apReward > 0) {
      values.add('+${entry.apReward} AP');
    }
    final totalSe = entry.seRewards
        .where((reward) => reward.hasContent)
        .fold<int>(0, (sum, reward) => sum + reward.count);
    if (totalSe > 0) {
      values.add('$totalSe SE');
    }
    if (entry.rewardsApplied) {
      values.add('angewendet');
    }
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(values.join('  |  '));
  }
}

class _AdventureSubsectionHeader extends StatelessWidget {
  const _AdventureSubsectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...?action == null ? null : <Widget>[action!],
      ],
    );
  }
}
