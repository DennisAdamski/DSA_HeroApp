part of '../hero_magic_tab.dart';

const Uuid _ritualDialogUuid = Uuid();

Future<HeroRitualCategory?> _showRitualCategoryDialog({
  required BuildContext context,
  required List<TalentDef> catalogTalents,
  HeroRitualCategory? existing,
}) {
  return showAdaptiveDetailSheet<HeroRitualCategory>(
    context: context,
    builder: (dialogContext) {
      return _RitualCategoryDialog(
        catalogTalents: catalogTalents,
        existing: existing,
      );
    },
  );
}

class _RitualCategoryDialog extends StatefulWidget {
  const _RitualCategoryDialog({required this.catalogTalents, this.existing});

  final List<TalentDef> catalogTalents;
  final HeroRitualCategory? existing;

  @override
  State<_RitualCategoryDialog> createState() => _RitualCategoryDialogState();
}

class _RitualCategoryDialogState extends State<_RitualCategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _knowledgeValueController;
  late final TextEditingController _talentSearchController;
  late HeroRitualKnowledgeMode _knowledgeMode;
  late String _learningComplexity;
  late Set<String> _selectedTalentIds;
  late List<_EditableRitualFieldDefDraft> _fieldDefs;
  String _talentSearch = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final ownKnowledge =
        existing?.ownKnowledge ??
        buildDefaultRitualKnowledge(existing?.name ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _knowledgeValueController = TextEditingController(
      text: ownKnowledge.value.toString(),
    );
    _talentSearchController = TextEditingController();
    _knowledgeMode =
        existing?.knowledgeMode ?? HeroRitualKnowledgeMode.ownKnowledge;
    _learningComplexity = ownKnowledge.learningComplexity;
    _selectedTalentIds = Set<String>.from(
      existing?.derivedTalentIds ?? const [],
    );
    _fieldDefs = (existing?.additionalFieldDefs ?? const <HeroRitualFieldDef>[])
        .map(_EditableRitualFieldDefDraft.fromDef)
        .toList(growable: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _knowledgeValueController.dispose();
    _talentSearchController.dispose();
    for (final fieldDef in _fieldDefs) {
      fieldDef.dispose();
    }
    super.dispose();
  }

  List<TalentDef> get _filteredTalents {
    final sorted = List<TalentDef>.from(widget.catalogTalents)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (_talentSearch.isEmpty) {
      return sorted;
    }
    final needle = _talentSearch.toLowerCase();
    return sorted
        .where((talent) => talent.name.toLowerCase().contains(needle))
        .toList(growable: false);
  }

  void _addFieldDef() {
    setState(() {
      _fieldDefs.add(_EditableRitualFieldDefDraft.create());
    });
  }

  void _removeFieldDef(int index) {
    setState(() {
      _fieldDefs[index].dispose();
      _fieldDefs.removeAt(index);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = 'Bitte einen Kategorienamen eingeben.';
      });
      return;
    }
    if (_knowledgeMode == HeroRitualKnowledgeMode.derivedTalents &&
        _selectedTalentIds.isEmpty) {
      setState(() {
        _errorText = 'Bitte mindestens ein Talent auswaehlen.';
      });
      return;
    }
    for (final fieldDef in _fieldDefs) {
      if (fieldDef.labelController.text.trim().isEmpty) {
        setState(() {
          _errorText = 'Zusatzfelder brauchen eine Bezeichnung.';
        });
        return;
      }
    }

    final knowledgeValue = int.tryParse(_knowledgeValueController.text.trim());
    final builtCategory = HeroRitualCategory(
      id: widget.existing?.id ?? _ritualDialogUuid.v4(),
      name: name,
      knowledgeMode: _knowledgeMode,
      ownKnowledge: _knowledgeMode == HeroRitualKnowledgeMode.ownKnowledge
          ? HeroRitualKnowledge(
              name: name,
              value: (knowledgeValue ?? 3).clamp(0, 9999),
              learningComplexity: _learningComplexity,
            )
          : null,
      derivedTalentIds: _knowledgeMode == HeroRitualKnowledgeMode.derivedTalents
          ? _selectedTalentIds.toList(growable: false)
          : const <String>[],
      additionalFieldDefs: _fieldDefs
          .map((fieldDef) {
            return HeroRitualFieldDef(
              id: fieldDef.id,
              label: fieldDef.labelController.text.trim(),
              type: fieldDef.type,
            );
          })
          .toList(growable: false),
      rituals: widget.existing?.rituals ?? const <HeroRitualEntry>[],
    );
    Navigator.of(context).pop(normalizeRitualCategory(builtCategory));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey<String>('magic-ritual-category-dialog'),
      title: Text(
        widget.existing == null
            ? 'Ritualkategorie anlegen'
            : 'Ritualkategorie bearbeiten',
      ),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey<String>('magic-ritual-category-name-field'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'z.B. Elfenlieder',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Text(
                'Wissensbasis',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<HeroRitualKnowledgeMode>(
                segments: const [
                  ButtonSegment(
                    value: HeroRitualKnowledgeMode.ownKnowledge,
                    label: Text('Ritualkenntnis'),
                  ),
                  ButtonSegment(
                    value: HeroRitualKnowledgeMode.derivedTalents,
                    label: Text('Talent'),
                  ),
                ],
                selected: <HeroRitualKnowledgeMode>{_knowledgeMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _knowledgeMode = selection.single;
                    _errorText = null;
                    if (_knowledgeMode ==
                            HeroRitualKnowledgeMode.ownKnowledge &&
                        _knowledgeValueController.text.trim().isEmpty) {
                      _knowledgeValueController.text = '3';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_knowledgeMode == HeroRitualKnowledgeMode.ownKnowledge)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>(
                          'magic-ritual-category-value-field',
                        ),
                        controller: _knowledgeValueController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'TaW',
                          helperText: 'Neue Kategorien starten i.d.R. mit 3.',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey<String>(
                          'magic-ritual-category-complexity-field',
                        ),
                        initialValue: _learningComplexity,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Lernkomplexitaet',
                        ),
                        items: kRitualKnowledgeComplexities
                            .map((complexity) {
                              return DropdownMenuItem<String>(
                                value: complexity,
                                child: Text(complexity),
                              );
                            })
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _learningComplexity = value;
                          });
                        },
                      ),
                    ),
                  ],
                )
              else ...[
                TextField(
                  controller: _talentSearchController,
                  decoration: InputDecoration(
                    labelText: 'Talente suchen',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _talentSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _talentSearchController.clear();
                              setState(() {
                                _talentSearch = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _talentSearch = value.trim();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    children: _filteredTalents
                        .map((talent) {
                          return CheckboxListTile(
                            key: ValueKey<String>(
                              'magic-ritual-category-talent-${talent.id}',
                            ),
                            dense: true,
                            title: Text(talent.name),
                            subtitle: talent.group.isNotEmpty
                                ? Text(talent.group)
                                : null,
                            value: _selectedTalentIds.contains(talent.id),
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  _selectedTalentIds.add(talent.id);
                                } else {
                                  _selectedTalentIds.remove(talent.id);
                                }
                              });
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Zusatzfelder',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    key: const ValueKey<String>(
                      'magic-ritual-category-add-field',
                    ),
                    onPressed: _addFieldDef,
                    icon: const Icon(Icons.add),
                    label: const Text('Feld'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_fieldDefs.isEmpty)
                Text(
                  'Keine Zusatzfelder definiert.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ..._fieldDefs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final fieldDef = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: ValueKey<String>(
                              'magic-ritual-category-field-label-$index',
                            ),
                            controller: fieldDef.labelController,
                            decoration: const InputDecoration(
                              labelText: 'Bezeichnung',
                              hintText: 'z.B. Probe',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<HeroRitualFieldType>(
                            key: ValueKey<String>(
                              'magic-ritual-category-field-type-$index',
                            ),
                            initialValue: fieldDef.type,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Typ'),
                            items: HeroRitualFieldType.values
                                .map((type) {
                                  return DropdownMenuItem<HeroRitualFieldType>(
                                    value: type,
                                    child: Text(_ritualFieldTypeLabel(type)),
                                  );
                                })
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                fieldDef.type = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: ValueKey<String>(
                            'magic-ritual-category-field-remove-$index',
                          ),
                          onPressed: () => _removeFieldDef(index),
                          icon: const Icon(Icons.delete, size: 18),
                          tooltip: 'Feld entfernen',
                        ),
                      ],
                    ),
                  );
                }),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
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
          key: const ValueKey<String>('magic-ritual-category-save'),
          onPressed: _save,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _EditableRitualFieldDefDraft {
  _EditableRitualFieldDefDraft({
    required this.id,
    required String label,
    required this.type,
  }) : labelController = TextEditingController(text: label);

  factory _EditableRitualFieldDefDraft.create() {
    return _EditableRitualFieldDefDraft(
      id: _ritualDialogUuid.v4(),
      label: '',
      type: HeroRitualFieldType.text,
    );
  }

  factory _EditableRitualFieldDefDraft.fromDef(HeroRitualFieldDef fieldDef) {
    return _EditableRitualFieldDefDraft(
      id: fieldDef.id,
      label: fieldDef.label,
      type: fieldDef.type,
    );
  }

  final String id;
  final TextEditingController labelController;
  HeroRitualFieldType type;

  void dispose() {
    labelController.dispose();
  }
}
