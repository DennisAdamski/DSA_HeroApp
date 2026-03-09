part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroMetaTalentDialogs on _HeroTalentTableTabState {
  Future<void> _openMetaTalentManager(List<TalentDef> allTalents) async {
    final sortedTalents = List<TalentDef>.from(allTalents)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    await showAdaptiveDetailSheet<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> openEditor([HeroMetaTalent? existing]) async {
              final result = await _showMetaTalentEditorDialog(
                allTalents: sortedTalents,
                initialValue: existing,
              );
              if (result == null) {
                return;
              }
              final updated = List<HeroMetaTalent>.from(_draftMetaTalents);
              final existingIndex = updated.indexWhere(
                (entry) => entry.id == result.id,
              );
              if (existingIndex >= 0) {
                updated[existingIndex] = result;
              } else {
                updated.add(result);
              }
              setDialogState(() {
                _replaceMetaTalents(updated);
              });
            }

            return AlertDialog(
              title: const Text('Meta-Talente verwalten'),
              content: SizedBox(
                width: 820,
                height: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: const ValueKey<String>(
                          'meta-talents-manager-add',
                        ),
                        onPressed: () => openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Meta-Talent anlegen'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: _draftMetaTalents.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Noch keine Meta-Talente angelegt.',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _draftMetaTalents.length,
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final metaTalent = _draftMetaTalents[index];
                                final componentNames = _metaTalentComponentNames(
                                  metaTalent: metaTalent,
                                  catalogTalents: sortedTalents,
                                );
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
                                        onPressed: () => openEditor(metaTalent),
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
                                                _draftMetaTalents,
                                              )..removeWhere(
                                                (entry) =>
                                                    entry.id == metaTalent.id,
                                              );
                                          setDialogState(() {
                                            _replaceMetaTalents(updated);
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Loeschen',
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Schliessen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<HeroMetaTalent?> _showMetaTalentEditorDialog({
    required List<TalentDef> allTalents,
    HeroMetaTalent? initialValue,
  }) {
    final nameController = TextEditingController(text: initialValue?.name ?? '');
    final beController = TextEditingController(text: initialValue?.be ?? '');
    final selectedTalentIds = <String>{
      ...?initialValue?.componentTalentIds,
    };
    final selectedAttributes = List<String?>.filled(3, null, growable: false);
    final initialAttributes = initialValue?.attributes ?? const <String>[];
    for (var index = 0; index < initialAttributes.length && index < 3; index++) {
      selectedAttributes[index] = _normalizeAttributeLabel(
        initialAttributes[index],
      );
    }
    final allowedTalentIds = allTalents
        .map((talent) => talent.id)
        .toSet();
    String? validationMessage;

    return showAdaptiveDetailSheet<HeroMetaTalent>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final componentTalentIds = allTalents
                  .where((talent) => selectedTalentIds.contains(talent.id))
                  .map((talent) => talent.id)
                  .toList(growable: false);
              final normalizedAttributes = selectedAttributes
                  .map((entry) => entry?.trim() ?? '')
                  .where((entry) => entry.isNotEmpty)
                  .toList(growable: false);
              final candidate = HeroMetaTalent(
                id: initialValue?.id ?? _createMetaTalentId(),
                name: nameController.text.trim(),
                componentTalentIds: componentTalentIds,
                attributes: normalizedAttributes,
                be: beController.text.trim(),
              );
              final issues = validateHeroMetaTalent(
                metaTalent: candidate,
                allowedTalentIds: allowedTalentIds,
              );
              if (issues.isNotEmpty) {
                setDialogState(() {
                  validationMessage = issues.first;
                });
                return;
              }
              Navigator.of(context).pop(candidate);
            }

            return AlertDialog(
              title: Text(
                initialValue == null
                    ? 'Meta-Talent anlegen'
                    : 'Meta-Talent bearbeiten',
              ),
              content: SizedBox(
                width: 760,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey<String>('meta-talent-name-field'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (validationMessage == null) {
                            return;
                          }
                          setDialogState(() {
                            validationMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey<String>('meta-talent-be-field'),
                        controller: beController,
                        decoration: const InputDecoration(
                          labelText: 'BE-Regel (optional)',
                          hintText: 'z. B. -, -2, x2',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (validationMessage == null) {
                            return;
                          }
                          setDialogState(() {
                            validationMessage = null;
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
                              initialValue: selectedAttributes[index],
                              decoration: InputDecoration(
                                labelText: 'Eigenschaft ${index + 1}',
                                border: const OutlineInputBorder(),
                              ),
                              items: _attributeDropdownItems(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedAttributes[index] = value;
                                  validationMessage = null;
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
                          children: allTalents.map((talent) {
                            final selected = selectedTalentIds.contains(
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
                                setDialogState(() {
                                  if (enabled == true) {
                                    selectedTalentIds.add(talent.id);
                                  } else {
                                    selectedTalentIds.remove(talent.id);
                                  }
                                  validationMessage = null;
                                });
                              },
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      if (validationMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          validationMessage!,
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
                  onPressed: submit,
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      beController.dispose();
    });
  }

  List<DropdownMenuItem<String>> _attributeDropdownItems() {
    return AttributeCode.values
        .map((code) => _attributeCodeLabel(code))
        .map(
          (label) => DropdownMenuItem<String>(value: label, child: Text(label)),
        )
        .toList(growable: false);
  }

  String _normalizeAttributeLabel(String raw) {
    final code = parseAttributeCode(raw);
    if (code == null) {
      return raw.trim().toUpperCase();
    }
    return _attributeCodeLabel(code);
  }

  String _createMetaTalentId() {
    return 'meta_${DateTime.now().microsecondsSinceEpoch}';
  }
}
