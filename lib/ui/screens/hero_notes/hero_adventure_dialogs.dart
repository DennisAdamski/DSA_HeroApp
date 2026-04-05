part of 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';

const List<_AdventureMonthOption> _aventurianMonthOptions =
    <_AdventureMonthOption>[
      _AdventureMonthOption(value: 'praios', label: 'Praios'),
      _AdventureMonthOption(value: 'rondra', label: 'Rondra'),
      _AdventureMonthOption(value: 'efferd', label: 'Efferd'),
      _AdventureMonthOption(value: 'travia', label: 'Travia'),
      _AdventureMonthOption(value: 'boron', label: 'Boron'),
      _AdventureMonthOption(value: 'hesinde', label: 'Hesinde'),
      _AdventureMonthOption(value: 'firun', label: 'Firun'),
      _AdventureMonthOption(value: 'tsa', label: 'Tsa'),
      _AdventureMonthOption(value: 'peraine', label: 'Peraine'),
      _AdventureMonthOption(value: 'ingerimm', label: 'Ingerimm'),
      _AdventureMonthOption(value: 'rahja', label: 'Rahja'),
      _AdventureMonthOption(value: 'namenlose_tage', label: 'Namenlose Tage'),
    ];

Future<HeroAdventureEntry?> _showAdventureCreateDialog({
  required BuildContext context,
  required HeroAdventureEntry initial,
}) {
  return showAdaptiveDetailSheet<HeroAdventureEntry>(
    context: context,
    builder: (_) => _AdventureCreateDialog(initial: initial),
  );
}

Future<HeroAdventureEntry?> _showAdventureCompletionDialog({
  required BuildContext context,
  required HeroAdventureEntry initial,
  required _AdventureRewardTargetOptions rewardTargetOptions,
}) {
  return showAdaptiveDetailSheet<HeroAdventureEntry>(
    context: context,
    builder: (_) => _AdventureCompletionDialog(
      initial: initial,
      rewardTargetOptions: rewardTargetOptions,
    ),
  );
}

Future<_AdventureNoteDialogResult?> _showAdventureNoteDialog({
  required BuildContext context,
  HeroNoteEntry? existing,
  required bool isEditing,
}) {
  return showAdaptiveDetailSheet<_AdventureNoteDialogResult>(
    context: context,
    builder: (_) =>
        _AdventureNoteDialog(existing: existing, isEditing: isEditing),
  );
}

Future<_AdventurePersonDialogResult?> _showAdventurePersonDialog({
  required BuildContext context,
  required HeroAdventurePersonEntry initial,
  required bool isEditing,
}) {
  return showAdaptiveDetailSheet<_AdventurePersonDialogResult>(
    context: context,
    builder: (_) =>
        _AdventurePersonDialog(initial: initial, isEditing: isEditing),
  );
}

class _AdventureMonthOption {
  const _AdventureMonthOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _AdventureDateDraft {
  _AdventureDateDraft.world(HeroAdventureDateValue initial)
    : _usesAventurianMonthPicker = false,
      dayController = TextEditingController(text: initial.day),
      monthController = TextEditingController(text: initial.month),
      yearController = TextEditingController(text: initial.year),
      selectedMonth = '';

  _AdventureDateDraft.aventurian(HeroAdventureDateValue initial)
    : _usesAventurianMonthPicker = true,
      dayController = TextEditingController(text: initial.day),
      monthController = null,
      yearController = TextEditingController(text: initial.year),
      selectedMonth = _normalizeAventurianMonthValue(initial.month);

  final bool _usesAventurianMonthPicker;
  final TextEditingController dayController;
  final TextEditingController? monthController;
  final TextEditingController yearController;
  String selectedMonth;

  HeroAdventureDateValue buildValue() {
    return HeroAdventureDateValue(
      day: dayController.text.trim(),
      month: _usesAventurianMonthPicker
          ? selectedMonth.trim()
          : (monthController?.text.trim() ?? ''),
      year: yearController.text.trim(),
    );
  }

  void dispose() {
    dayController.dispose();
    monthController?.dispose();
    yearController.dispose();
  }
}

class _AdventureLootDraft {
  _AdventureLootDraft(HeroAdventureLootEntry initial)
    : id = initial.id,
      nameController = TextEditingController(text: initial.name),
      quantityController = TextEditingController(text: initial.quantity),
      weightController = TextEditingController(
        text: initial.weightGramm > 0 ? initial.weightGramm.toString() : '',
      ),
      valueController = TextEditingController(
        text: initial.valueSilver > 0 ? initial.valueSilver.toString() : '',
      ),
      originController = TextEditingController(text: initial.origin),
      descriptionController = TextEditingController(text: initial.description),
      itemType = initial.itemType;

  final String id;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController weightController;
  final TextEditingController valueController;
  final TextEditingController originController;
  final TextEditingController descriptionController;
  InventoryItemType itemType;

  HeroAdventureLootEntry buildValue() {
    final parsedWeight = int.tryParse(weightController.text.trim()) ?? 0;
    final parsedValue = int.tryParse(valueController.text.trim()) ?? 0;
    return HeroAdventureLootEntry(
      id: id,
      name: nameController.text.trim(),
      quantity: quantityController.text.trim(),
      itemType: itemType,
      weightGramm: parsedWeight < 0 ? 0 : parsedWeight,
      valueSilver: parsedValue < 0 ? 0 : parsedValue,
      origin: originController.text.trim(),
      description: descriptionController.text.trim(),
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    weightController.dispose();
    valueController.dispose();
    originController.dispose();
    descriptionController.dispose();
  }
}

class _AdventureNoteDialogResult {
  const _AdventureNoteDialogResult({
    required this.entry,
    this.deleteRequested = false,
  });

  final HeroNoteEntry entry;
  final bool deleteRequested;
}

class _AdventurePersonDialogResult {
  const _AdventurePersonDialogResult({
    required this.entry,
    this.deleteRequested = false,
  });

  final HeroAdventurePersonEntry entry;
  final bool deleteRequested;
}

class _AdventureCreateDialog extends StatefulWidget {
  const _AdventureCreateDialog({required this.initial});

  final HeroAdventureEntry initial;

  @override
  State<_AdventureCreateDialog> createState() => _AdventureCreateDialogState();
}

class _AdventureCreateDialogState extends State<_AdventureCreateDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final _AdventureDateDraft _startWorldDate;
  late final _AdventureDateDraft _startAventurianDate;
  late HeroAdventureStatus _status;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial.title);
    _summaryController = TextEditingController(text: initial.summary);
    _startWorldDate = _AdventureDateDraft.world(initial.startWorldDate);
    _startAventurianDate = _AdventureDateDraft.aventurian(
      initial.startAventurianDate,
    );
    _status = initial.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _startWorldDate.dispose();
    _startAventurianDate.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorText = 'Bitte gib dem Abenteuer mindestens einen Titel.';
      });
      return;
    }

    Navigator.of(context).pop(
      widget.initial.copyWith(
        title: title,
        summary: _summaryController.text.trim(),
        status: _status,
        startWorldDate: _startWorldDate.buildValue(),
        startAventurianDate: _startAventurianDate.buildValue(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('notes-adventure-dialog'),
      title: const Text('Abenteuer anlegen'),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey<String>('notes-adventure-dialog-title'),
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('notes-adventure-dialog-summary'),
                controller: _summaryController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Zusammenfassung',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _AdventureStatusField(
                currentValue: _status,
                fieldKeyPrefix: 'notes-adventure-dialog-status',
                onChanged: (value) {
                  setState(() {
                    _status = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _AdventureDialogDateSection(
                title: 'Start des Abenteuers',
                worldDateKeyPrefix: 'notes-adventure-dialog-start-world',
                aventurianDateKeyPrefix:
                    'notes-adventure-dialog-start-aventurian',
                worldDate: _startWorldDate,
                aventurianDate: _startAventurianDate,
                onChanged: () => setState(() {}),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('notes-adventure-dialog-save'),
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _AdventureCompletionDialog extends StatefulWidget {
  const _AdventureCompletionDialog({
    required this.initial,
    required this.rewardTargetOptions,
  });

  final HeroAdventureEntry initial;
  final _AdventureRewardTargetOptions rewardTargetOptions;

  @override
  State<_AdventureCompletionDialog> createState() =>
      _AdventureCompletionDialogState();
}

class _AdventureCompletionDialogState
    extends State<_AdventureCompletionDialog> {
  late final _AdventureDateDraft _endWorldDate;
  late final _AdventureDateDraft _endAventurianDate;
  late final TextEditingController _dukatenController;
  late final List<_AdventureLootDraft> _lootDrafts;
  late int _apReward;
  late List<HeroAdventureSeReward> _seRewards;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final defaultWorldDate = initial.endWorldDate.hasContent
        ? initial.endWorldDate
        : HeroAdventureDateValue.fromDateTime(DateTime.now());
    final defaultAventurianDate = initial.endAventurianDate.hasContent
        ? initial.endAventurianDate
        : initial.currentAventurianDate;
    _endWorldDate = _AdventureDateDraft.world(defaultWorldDate);
    _endAventurianDate = _AdventureDateDraft.aventurian(defaultAventurianDate);
    _dukatenController = TextEditingController(
      text: _formatAdventureDukatenDraft(initial.dukatenReward),
    );
    _lootDrafts = initial.lootRewards
        .map(_AdventureLootDraft.new)
        .toList(growable: true);
    _apReward = initial.apReward;
    _seRewards = List<HeroAdventureSeReward>.from(initial.seRewards);
  }

  @override
  void dispose() {
    _endWorldDate.dispose();
    _endAventurianDate.dispose();
    _dukatenController.dispose();
    for (final draft in _lootDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addLootDraft() {
    setState(() {
      _lootDrafts.add(
        _AdventureLootDraft(HeroAdventureLootEntry(id: _uuid.v4())),
      );
    });
  }

  void _removeLootDraft(int index) {
    if (index < 0 || index >= _lootDrafts.length) {
      return;
    }
    setState(() {
      final removed = _lootDrafts.removeAt(index);
      removed.dispose();
    });
  }

  HeroAdventureEntry get _rewardDraftEntry {
    return widget.initial.copyWith(apReward: _apReward, seRewards: _seRewards);
  }

  void _updateApReward(String rawValue) {
    final parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    setState(() {
      _apReward = parsedValue < 0 ? 0 : parsedValue;
    });
  }

  void _addSeReward() {
    final defaultOption = widget.rewardTargetOptions
        .optionsForType(HeroAdventureSeTargetType.talent)
        .firstOrNull;
    setState(() {
      _seRewards = List<HeroAdventureSeReward>.from(_seRewards)
        ..add(
          HeroAdventureSeReward(
            targetType: HeroAdventureSeTargetType.talent,
            targetId: defaultOption?.id ?? '',
            targetLabel: defaultOption?.label ?? '',
            count: 1,
          ),
        );
    });
  }

  void _removeSeReward(int rewardIndex) {
    if (rewardIndex < 0 || rewardIndex >= _seRewards.length) {
      return;
    }
    setState(() {
      _seRewards = List<HeroAdventureSeReward>.from(_seRewards)
        ..removeAt(rewardIndex);
    });
  }

  void _updateSeRewardType(
    int rewardIndex,
    HeroAdventureSeTargetType targetType,
  ) {
    final defaultOption = widget.rewardTargetOptions
        .optionsForType(targetType)
        .firstOrNull;
    _updateSeReward(
      rewardIndex,
      targetType: targetType,
      targetId: defaultOption?.id ?? '',
      targetLabel: defaultOption?.label ?? '',
    );
  }

  void _updateSeRewardTarget(
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  }) {
    _updateSeReward(rewardIndex, targetId: targetId, targetLabel: targetLabel);
  }

  void _updateSeRewardCount(int rewardIndex, String rawValue) {
    final parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    _updateSeReward(rewardIndex, count: parsedValue < 0 ? 0 : parsedValue);
  }

  void _updateSeReward(
    int rewardIndex, {
    HeroAdventureSeTargetType? targetType,
    String? targetId,
    String? targetLabel,
    int? count,
  }) {
    if (rewardIndex < 0 || rewardIndex >= _seRewards.length) {
      return;
    }
    setState(() {
      final nextRewards = List<HeroAdventureSeReward>.from(_seRewards);
      nextRewards[rewardIndex] = nextRewards[rewardIndex].copyWith(
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
        count: count,
      );
      _seRewards = nextRewards;
    });
  }

  void _save() {
    final parsedDukaten = _parseAdventureDukatenDraft(_dukatenController.text);
    if (parsedDukaten == null || parsedDukaten < 0) {
      setState(() {
        _errorText = 'Bitte gib einen numerischen Dukatenwert an.';
      });
      return;
    }

    final nextLoot = _lootDrafts
        .map((draft) => draft.buildValue())
        .where((entry) => entry.hasContent)
        .toList(growable: false);
    final nextAdventure = widget.initial.copyWith(
      endWorldDate: _endWorldDate.buildValue(),
      endAventurianDate: _endAventurianDate.buildValue(),
      apReward: _apReward,
      seRewards: _seRewards,
      dukatenReward: parsedDukaten,
      lootRewards: nextLoot,
    );
    Navigator.of(context).pop(nextAdventure);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('notes-adventure-complete-dialog'),
      title: Text('${_adventureCompletionTitle(widget.initial)} abschließen'),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdventureDialogDateSection(
                title: 'Ende des Abenteuers',
                worldDateKeyPrefix: 'notes-adventure-complete-end-world',
                aventurianDateKeyPrefix:
                    'notes-adventure-complete-end-aventurian',
                worldDate: _endWorldDate,
                aventurianDate: _endAventurianDate,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              _AdventureSubsectionHeader(title: 'Belohnungen'),
              const SizedBox(height: 8),
              _EditableAdventureRewards(
                entry: _rewardDraftEntry,
                rewardLocked: false,
                targetOptionsForType: widget.rewardTargetOptions.optionsForType,
                onApRewardChanged: _updateApReward,
                onAddSeReward: _addSeReward,
                onRemoveSeReward: _removeSeReward,
                onSeRewardTypeChanged: _updateSeRewardType,
                onSeRewardTargetChanged: _updateSeRewardTarget,
                onSeRewardCountChanged: _updateSeRewardCount,
              ),
              const SizedBox(height: 12),
              _CompletionRewardSummary(entry: _rewardDraftEntry),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey<String>('notes-adventure-complete-dukaten'),
                controller: _dukatenController,
                decoration: const InputDecoration(
                  labelText: 'Dukaten',
                  border: OutlineInputBorder(),
                  hintText: '0',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              _AdventureSubsectionHeader(
                title: 'Gegenstände',
                action: TextButton(
                  key: const ValueKey<String>(
                    'notes-adventure-complete-add-loot',
                  ),
                  onPressed: _addLootDraft,
                  child: const Text('+ Gegenstand'),
                ),
              ),
              const SizedBox(height: 8),
              if (_lootDrafts.isEmpty)
                const _EmptyState(
                  message: 'Keine zusätzlichen Gegenstände erfasst.',
                )
              else
                Column(
                  children: [
                    for (var index = 0; index < _lootDrafts.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : _notesFieldSpacing,
                        ),
                        child: _AdventureLootEditorCard(
                          index: index,
                          draft: _lootDrafts[index],
                          onRemove: () => _removeLootDraft(index),
                        ),
                      ),
                  ],
                ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('notes-adventure-complete-dialog-save'),
          onPressed: _save,
          child: const Text('Bestätigen'),
        ),
      ],
    );
  }
}

class _CompletionRewardSummary extends StatelessWidget {
  const _CompletionRewardSummary({required this.entry});

  final HeroAdventureEntry entry;

  @override
  Widget build(BuildContext context) {
    final rewardChips = <Widget>[
      if (entry.apReward > 0) Chip(label: Text('+${entry.apReward} AP')),
      ...entry.seRewards
          .where((reward) => reward.hasContent)
          .map(
            (reward) =>
                Chip(label: Text('${reward.count}× ${_rewardLabel(reward)}')),
          ),
    ];
    if (rewardChips.isEmpty) {
      return const Text('Keine AP- oder SE-Belohnungen definiert.');
    }
    return Wrap(spacing: 8, runSpacing: 8, children: rewardChips);
  }
}

class _AdventureLootEditorCard extends StatelessWidget {
  const _AdventureLootEditorCard({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final _AdventureLootDraft draft;
  final VoidCallback onRemove;

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
                    'Gegenstand ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'notes-adventure-complete-remove-loot-$index',
                  ),
                  onPressed: onRemove,
                  tooltip: 'Gegenstand entfernen',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextField(
              key: ValueKey<String>(
                'notes-adventure-complete-loot-name-$index',
              ),
              controller: draft.nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: _notesFieldSpacing),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey<String>(
                      'notes-adventure-complete-loot-quantity-$index',
                    ),
                    controller: draft.quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Anzahl',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<InventoryItemType>(
                    key: ValueKey<String>(
                      'notes-adventure-complete-loot-type-$index',
                    ),
                    initialValue: draft.itemType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Typ',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: InventoryItemType.ausruestung,
                        child: Text('Ausrüstung'),
                      ),
                      DropdownMenuItem(
                        value: InventoryItemType.verbrauchsgegenstand,
                        child: Text('Verbrauchsgegenstand'),
                      ),
                      DropdownMenuItem(
                        value: InventoryItemType.wertvolles,
                        child: Text('Wertvolles'),
                      ),
                      DropdownMenuItem(
                        value: InventoryItemType.sonstiges,
                        child: Text('Sonstiges'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        draft.itemType = value;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey<String>(
                      'notes-adventure-complete-loot-weight-$index',
                    ),
                    controller: draft.weightController,
                    decoration: const InputDecoration(
                      labelText: 'Gewicht (g)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: ValueKey<String>(
                      'notes-adventure-complete-loot-value-$index',
                    ),
                    controller: draft.valueController,
                    decoration: const InputDecoration(
                      labelText: 'Wert (S)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextField(
              key: ValueKey<String>(
                'notes-adventure-complete-loot-origin-$index',
              ),
              controller: draft.originController,
              decoration: const InputDecoration(
                labelText: 'Herkunft',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: _notesFieldSpacing),
            TextField(
              key: ValueKey<String>(
                'notes-adventure-complete-loot-description-$index',
              ),
              controller: draft.descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdventureNoteDialog extends StatefulWidget {
  const _AdventureNoteDialog({required this.isEditing, this.existing});

  final HeroNoteEntry? existing;
  final bool isEditing;

  @override
  State<_AdventureNoteDialog> createState() => _AdventureNoteDialogState();
}

class _AdventureNoteDialogState extends State<_AdventureNoteDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty && description.isEmpty) {
      setState(() {
        _errorText = 'Bitte gib der Notiz einen Titel oder eine Beschreibung.';
      });
      return;
    }

    Navigator.of(context).pop(
      _AdventureNoteDialogResult(
        entry: HeroNoteEntry(title: title, description: description),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? 'Notiz hinzufügen'
        : widget.isEditing
        ? 'Notiz bearbeiten'
        : 'Notiz';
    return AlertDialog(
      key: const ValueKey<String>('notes-adventure-note-dialog'),
      title: Text(title),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey<String>(
                  'notes-adventure-note-dialog-title',
                ),
                controller: _titleController,
                readOnly: !widget.isEditing,
                autofocus: widget.isEditing,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>(
                  'notes-adventure-note-dialog-description',
                ),
                controller: _descriptionController,
                readOnly: !widget.isEditing,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEditing ? 'Abbrechen' : 'Schließen'),
        ),
        if (widget.isEditing && widget.existing != null)
          TextButton(
            key: const ValueKey<String>('notes-adventure-note-dialog-delete'),
            onPressed: () => Navigator.of(context).pop(
              _AdventureNoteDialogResult(
                entry: widget.existing!,
                deleteRequested: true,
              ),
            ),
            child: Text(
              'Löschen',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (widget.isEditing)
          FilledButton(
            key: const ValueKey<String>('notes-adventure-note-dialog-save'),
            onPressed: _save,
            child: const Text('Speichern'),
          ),
      ],
    );
  }
}

class _AdventurePersonDialog extends StatefulWidget {
  const _AdventurePersonDialog({
    required this.initial,
    required this.isEditing,
  });

  final HeroAdventurePersonEntry initial;
  final bool isEditing;

  @override
  State<_AdventurePersonDialog> createState() => _AdventurePersonDialogState();
}

class _AdventurePersonDialogState extends State<_AdventurePersonDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _descriptionController = TextEditingController(
      text: widget.initial.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Bitte gib der Person mindestens einen Namen.';
      });
      return;
    }

    Navigator.of(context).pop(
      _AdventurePersonDialogResult(
        entry: widget.initial.copyWith(
          name: name,
          description: _descriptionController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initial.name.trim().isEmpty
        ? 'Person hinzufügen'
        : widget.isEditing
        ? 'Person bearbeiten'
        : widget.initial.name.trim();
    return AlertDialog(
      key: const ValueKey<String>('notes-adventure-person-dialog'),
      title: Text(title),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey<String>(
                  'notes-adventure-person-dialog-name',
                ),
                controller: _nameController,
                readOnly: !widget.isEditing,
                autofocus: widget.isEditing,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>(
                  'notes-adventure-person-dialog-description',
                ),
                controller: _descriptionController,
                readOnly: !widget.isEditing,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEditing ? 'Abbrechen' : 'Schließen'),
        ),
        if (widget.isEditing && widget.initial.name.trim().isNotEmpty)
          TextButton(
            key: const ValueKey<String>('notes-adventure-person-dialog-delete'),
            onPressed: () => Navigator.of(context).pop(
              _AdventurePersonDialogResult(
                entry: widget.initial,
                deleteRequested: true,
              ),
            ),
            child: Text(
              'Löschen',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (widget.isEditing)
          FilledButton(
            key: const ValueKey<String>('notes-adventure-person-dialog-save'),
            onPressed: _save,
            child: const Text('Speichern'),
          ),
      ],
    );
  }
}

class _AdventureDialogDateSection extends StatelessWidget {
  const _AdventureDialogDateSection({
    required this.title,
    required this.worldDateKeyPrefix,
    required this.aventurianDateKeyPrefix,
    required this.worldDate,
    required this.aventurianDate,
    required this.onChanged,
  });

  final String title;
  final String worldDateKeyPrefix;
  final String aventurianDateKeyPrefix;
  final _AdventureDateDraft worldDate;
  final _AdventureDateDraft aventurianDate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _AdventureDialogDateFields(
          title: 'Weltlich',
          keyPrefix: worldDateKeyPrefix,
          date: worldDate,
          usesMonthPicker: false,
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        _AdventureDialogDateFields(
          title: 'Aventurisch',
          keyPrefix: aventurianDateKeyPrefix,
          date: aventurianDate,
          usesMonthPicker: true,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AdventureDialogDateFields extends StatelessWidget {
  const _AdventureDialogDateFields({
    required this.title,
    required this.keyPrefix,
    required this.date,
    required this.usesMonthPicker,
    required this.onChanged,
  });

  final String title;
  final String keyPrefix;
  final _AdventureDateDraft date;
  final bool usesMonthPicker;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = constraints.maxWidth >= 540
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth;
            final fields = <Widget>[
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: ValueKey<String>('$keyPrefix-day'),
                  controller: date.dayController,
                  decoration: const InputDecoration(
                    labelText: 'Tag',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: usesMonthPicker
                    ? DropdownButtonFormField<String>(
                        key: ValueKey<String>('$keyPrefix-month'),
                        initialValue: date.selectedMonth.isEmpty
                            ? null
                            : date.selectedMonth,
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
                        onChanged: (value) {
                          date.selectedMonth = value ?? '';
                          onChanged();
                        },
                      )
                    : TextField(
                        key: ValueKey<String>('$keyPrefix-month'),
                        controller: date.monthController,
                        decoration: const InputDecoration(
                          labelText: 'Monat',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => onChanged(),
                      ),
              ),
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  key: ValueKey<String>('$keyPrefix-year'),
                  controller: date.yearController,
                  decoration: const InputDecoration(
                    labelText: 'Jahr',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
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

String _normalizeAventurianMonthValue(String rawValue) {
  final normalizedValue = rawValue.trim().toLowerCase();
  for (final option in _aventurianMonthOptions) {
    if (option.value == normalizedValue ||
        option.label.toLowerCase() == normalizedValue) {
      return option.value;
    }
  }
  return '';
}

String _aventurianMonthLabel(String rawValue) {
  final normalizedValue = _normalizeAventurianMonthValue(rawValue);
  final option = _aventurianMonthOptions
      .where((entry) => entry.value == normalizedValue)
      .firstOrNull;
  return option?.label ?? rawValue.trim();
}

String _adventureCompletionTitle(HeroAdventureEntry entry) {
  final title = entry.title.trim();
  return title.isEmpty ? 'Abenteuer' : title;
}

String _formatAdventureDukatenDraft(double value) {
  if (value <= 0) {
    return '';
  }
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

double? _parseAdventureDukatenDraft(String rawValue) {
  final normalized = rawValue.trim();
  if (normalized.isEmpty) {
    return 0;
  }
  final compact = normalized.replaceAll(' ', '');
  return double.tryParse(compact.replaceAll(',', '.'));
}
