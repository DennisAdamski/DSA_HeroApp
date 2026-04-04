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
  late final _AdventureDateDraft _endWorldDate;
  late final _AdventureDateDraft _endAventurianDate;
  late final _AdventureDateDraft _currentAventurianDate;
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
    _endWorldDate = _AdventureDateDraft.world(initial.endWorldDate);
    _endAventurianDate = _AdventureDateDraft.aventurian(
      initial.endAventurianDate,
    );
    _currentAventurianDate = _AdventureDateDraft.aventurian(
      initial.currentAventurianDate,
    );
    _status = initial.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _startWorldDate.dispose();
    _startAventurianDate.dispose();
    _endWorldDate.dispose();
    _endAventurianDate.dispose();
    _currentAventurianDate.dispose();
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
        endWorldDate: _endWorldDate.buildValue(),
        endAventurianDate: _endAventurianDate.buildValue(),
        currentAventurianDate: _currentAventurianDate.buildValue(),
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
              const SizedBox(height: 16),
              _AdventureDialogDateSection(
                title: 'Ende des Abenteuers',
                worldDateKeyPrefix: 'notes-adventure-dialog-end-world',
                aventurianDateKeyPrefix:
                    'notes-adventure-dialog-end-aventurian',
                worldDate: _endWorldDate,
                aventurianDate: _endAventurianDate,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),
              _AdventureDialogSingleDateSection(
                title: 'Aktuelles Datum',
                keyPrefix: 'notes-adventure-dialog-current-aventurian',
                date: _currentAventurianDate,
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

class _AdventureDialogSingleDateSection extends StatelessWidget {
  const _AdventureDialogSingleDateSection({
    required this.title,
    required this.keyPrefix,
    required this.date,
    required this.onChanged,
  });

  final String title;
  final String keyPrefix;
  final _AdventureDateDraft date;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _AdventureDialogDateFields(
      title: title,
      keyPrefix: keyPrefix,
      date: date,
      usesMonthPicker: true,
      onChanged: onChanged,
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
