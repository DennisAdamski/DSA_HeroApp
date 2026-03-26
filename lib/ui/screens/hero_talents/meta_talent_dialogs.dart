part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroMetaTalentDialogs on _HeroTalentTableTabState {
  Future<void> _openMetaTalentManager(List<TalentDef> allTalents) async {
    final sortedTalents = List<TalentDef>.from(allTalents)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showAdaptiveDetailSheet<void>(
      context: context,
      builder: (_) => _MetaTalentManagerDialog(
        initialMetaTalents: _draftMetaTalents,
        allTalents: sortedTalents,
        onChanged: _replaceMetaTalents,
      ),
    );
  }
}

class _MetaTalentManagerDialog extends StatefulWidget {
  const _MetaTalentManagerDialog({
    required this.initialMetaTalents,
    required this.allTalents,
    required this.onChanged,
  });

  final List<HeroMetaTalent> initialMetaTalents;
  final List<TalentDef> allTalents;
  final ValueChanged<List<HeroMetaTalent>> onChanged;

  @override
  State<_MetaTalentManagerDialog> createState() =>
      _MetaTalentManagerDialogState();
}

class _MetaTalentManagerDialogState extends State<_MetaTalentManagerDialog> {
  late List<HeroMetaTalent> _metaTalents;

  @override
  void initState() {
    super.initState();
    _metaTalents = List<HeroMetaTalent>.from(widget.initialMetaTalents);
  }

  void _updateMetaTalents(List<HeroMetaTalent> updated) {
    setState(() {
      _metaTalents = updated;
    });
    widget.onChanged(updated);
  }

  Future<void> _openEditor([HeroMetaTalent? existing]) async {
    final result = await showAdaptiveDetailSheet<HeroMetaTalent>(
      context: context,
      builder: (_) => _MetaTalentEditorDialog(
        allTalents: widget.allTalents,
        initialValue: existing,
      ),
    );
    if (result == null) {
      return;
    }
    final updated = List<HeroMetaTalent>.from(_metaTalents);
    final existingIndex = updated.indexWhere((e) => e.id == result.id);
    if (existingIndex >= 0) {
      updated[existingIndex] = result;
    } else {
      updated.add(result);
    }
    _updateMetaTalents(updated);
  }

  List<String> _componentNames(HeroMetaTalent metaTalent) {
    final nameById = <String, String>{
      for (final talent in widget.allTalents) talent.id: talent.name,
    };
    return metaTalent.componentTalentIds
        .map((id) => nameById[id] ?? id)
        .toList(growable: false);
  }

  String _normalizeAttributeLabel(String raw) {
    final code = parseAttributeCode(raw);
    if (code == null) {
      return raw.trim().toUpperCase();
    }
    return _formatAttributeCode(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meta-Talente verwalten'),
      content: SizedBox(
        width: kDialogWidthLarge,
        height: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey<String>('meta-talents-manager-add'),
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Meta-Talent anlegen'),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _metaTalents.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Noch keine Meta-Talente angelegt.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _metaTalents.length,
                      separatorBuilder: (_, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final metaTalent = _metaTalents[index];
                        final componentNames = _componentNames(metaTalent);
                        final attributeText = metaTalent.attributes
                            .map(_normalizeAttributeLabel)
                            .join('/');
                        return ListTile(
                          key: ValueKey<String>(
                            'meta-talent-item-${metaTalent.id}',
                          ),
                          contentPadding: EdgeInsets.zero,
                          title: Text(metaTalent.name),
                          subtitle: Text(
                            '${componentNames.join(', ')} | $attributeText',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                key: ValueKey<String>(
                                  'meta-talent-edit-${metaTalent.id}',
                                ),
                                onPressed: () => _openEditor(metaTalent),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Bearbeiten',
                              ),
                              IconButton(
                                key: ValueKey<String>(
                                  'meta-talent-delete-${metaTalent.id}',
                                ),
                                onPressed: () {
                                  final updated =
                                      List<HeroMetaTalent>.from(
                                        _metaTalents,
                                      )..removeWhere(
                                        (entry) =>
                                            entry.id == metaTalent.id,
                                      );
                                  _updateMetaTalents(updated);
                                },
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Löschen',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}

class _MetaTalentEditorDialog extends StatefulWidget {
  const _MetaTalentEditorDialog({
    required this.allTalents,
    this.initialValue,
  });

  final List<TalentDef> allTalents;
  final HeroMetaTalent? initialValue;

  @override
  State<_MetaTalentEditorDialog> createState() =>
      _MetaTalentEditorDialogState();
}

class _MetaTalentEditorDialogState extends State<_MetaTalentEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _beController;
  late final Set<String> _selectedTalentIds;
  late final List<String?> _selectedAttributes;
  late final Set<String> _allowedTalentIds;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialValue?.name ?? '',
    );
    _beController = TextEditingController(
      text: widget.initialValue?.be ?? '',
    );
    _selectedTalentIds = <String>{
      ...?widget.initialValue?.componentTalentIds,
    };
    _selectedAttributes = List<String?>.filled(3, null, growable: false);
    final initialAttributes =
        widget.initialValue?.attributes ?? const <String>[];
    for (var index = 0;
        index < initialAttributes.length && index < 3;
        index++) {
      _selectedAttributes[index] = _normalizeAttributeLabel(
        initialAttributes[index],
      );
    }
    _allowedTalentIds = widget.allTalents.map((t) => t.id).toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _beController.dispose();
    super.dispose();
  }

  String _normalizeAttributeLabel(String raw) {
    final code = parseAttributeCode(raw);
    if (code == null) {
      return raw.trim().toUpperCase();
    }
    return _formatAttributeCode(code);
  }

  List<DropdownMenuItem<String>> _attributeDropdownItems() {
    return AttributeCode.values
        .map((code) => _formatAttributeCode(code))
        .map(
          (label) =>
              DropdownMenuItem<String>(value: label, child: Text(label)),
        )
        .toList(growable: false);
  }

  void _submit() {
    final componentTalentIds = widget.allTalents
        .where((talent) => _selectedTalentIds.contains(talent.id))
        .map((talent) => talent.id)
        .toList(growable: false);
    final normalizedAttributes = _selectedAttributes
        .map((entry) => entry?.trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    final candidate = HeroMetaTalent(
      id: widget.initialValue?.id ??
          'meta_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      componentTalentIds: componentTalentIds,
      attributes: normalizedAttributes,
      be: _beController.text.trim(),
    );
    final issues = validateHeroMetaTalent(
      metaTalent: candidate,
      allowedTalentIds: _allowedTalentIds,
    );
    if (issues.isNotEmpty) {
      setState(() {
        _validationMessage = issues.first;
      });
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialValue == null
            ? 'Meta-Talent anlegen'
            : 'Meta-Talent bearbeiten',
      ),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey<String>('meta-talent-name-field'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_validationMessage == null) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey<String>('meta-talent-be-field'),
                controller: _beController,
                decoration: const InputDecoration(
                  labelText: 'BE-Regel (optional)',
                  hintText: 'z. B. -, -2, x2',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_validationMessage == null) {
                    return;
                  }
                  setState(() {
                    _validationMessage = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Eigenschaften',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List<Widget>.generate(3, (index) {
                  return SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'meta-talent-attribute-$index',
                      ),
                      initialValue: _selectedAttributes[index],
                      decoration: InputDecoration(
                        labelText: 'Eigenschaft ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      items: _attributeDropdownItems(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAttributes[index] = value;
                          _validationMessage = null;
                        });
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                'Bestandteils-Talente',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: widget.allTalents.map((talent) {
                    final selected = _selectedTalentIds.contains(
                      talent.id,
                    );
                    final groupLabel = talent.group.trim().isEmpty
                        ? talent.type.trim()
                        : talent.group.trim();
                    return CheckboxListTile(
                      key: ValueKey<String>(
                        'meta-talent-component-${talent.id}',
                      ),
                      value: selected,
                      dense: true,
                      title: Text(talent.name),
                      subtitle: groupLabel.isEmpty
                          ? null
                          : Text(groupLabel),
                      onChanged: (enabled) {
                        setState(() {
                          if (enabled == true) {
                            _selectedTalentIds.add(talent.id);
                          } else {
                            _selectedTalentIds.remove(talent.id);
                          }
                          _validationMessage = null;
                        });
                      },
                    );
                  }).toList(growable: false),
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationMessage!,
                  key: const ValueKey<String>(
                    'meta-talent-validation-message',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
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
          key: const ValueKey<String>('meta-talent-editor-save'),
          onPressed: _submit,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

String _formatAttributeCode(AttributeCode code) {
  switch (code) {
    case AttributeCode.mu:
      return 'MU';
    case AttributeCode.kl:
      return 'KL';
    case AttributeCode.inn:
      return 'IN';
    case AttributeCode.ch:
      return 'CH';
    case AttributeCode.ff:
      return 'FF';
    case AttributeCode.ge:
      return 'GE';
    case AttributeCode.ko:
      return 'KO';
    case AttributeCode.kk:
      return 'KK';
  }
}
