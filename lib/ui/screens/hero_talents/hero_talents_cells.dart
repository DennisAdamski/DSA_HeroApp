part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsCells on _HeroTalentTableTabState {
  Widget _headerCell(String text, {bool highlighted = false}) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.labelMedium;
    final style = highlighted
        ? baseStyle?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          )
        : baseStyle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: style),
      ),
    );
  }

  Widget _tappableNameCell(String text, {Key? key, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textCell(String text, {Key? key, bool highlighted = false}) {
    final theme = Theme.of(context);
    final style = highlighted
        ? TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          )
        : null;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: style),
      ),
    );
  }

  Widget _combatSpecializationCell({
    required TalentDef talent,
    required HeroTalentEntry entry,
    required bool isEditing,
  }) {
    final options = _weaponCategoryOptions(talent);
    final selected = entry.combatSpecializations.isEmpty
        ? _splitSpecializationTokens(entry.specializations)
        : _normalizeStringList(entry.combatSpecializations);

    if (!isEditing) {
      if (selected.isEmpty) {
        return _textCell('-');
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: selected
                .map(
                  (spec) => Chip(
                    label: Text(spec),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: adaptiveTapTargetSize(context),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            ...selected.map(
              (spec) => InputChip(
                key: ValueKey<String>('talents-combat-spec-${talent.id}-$spec'),
                label: Text(spec),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: adaptiveTapTargetSize(context),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                onDeleted: () {
                  final updated = List<String>.from(selected)..remove(spec);
                  _updateCombatSpecializations(talent.id, updated);
                },
              ),
            ),
            if (options.isNotEmpty)
              ActionChip(
                key: ValueKey<String>('talents-combat-spec-add-${talent.id}'),
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Hinzufuegen'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: adaptiveTapTargetSize(context),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.only(right: 6),
                onPressed: () async {
                  final result = await _showCombatSpecializationDialog(
                    title: 'Spezialisierungen: ${talent.name}',
                    options: options,
                    initialSelected: selected,
                  );
                  if (result == null) {
                    return;
                  }
                  _updateCombatSpecializations(talent.id, result);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _showCombatSpecializationDialog({
    required String title,
    required List<String> options,
    required List<String> initialSelected,
  }) {
    final selected = <String>{...initialSelected};
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options
                        .map(
                          (entry) => CheckboxListTile(
                            value: selected.contains(entry),
                            title: Text(entry),
                            dense: true,
                            onChanged: (enabled) {
                              setDialogState(() {
                                if (enabled == true) {
                                  selected.add(entry);
                                } else {
                                  selected.remove(entry);
                                }
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    final normalized = _normalizeStringList(selected);
                    Navigator.of(context).pop(normalized);
                  },
                  child: const Text('Uebernehmen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _intInputCell({
    required String talentId,
    required String field,
    required int value,
    required bool isEditing,
    bool isError = false,
    VoidCallback? onRaise,
    String? raiseTooltip,
  }) {
    final controller = _controllerFor(talentId, field, value.toString());
    final textField = TextField(
      key: ValueKey<String>('talents-field-$talentId-$field'),
      controller: controller,
      readOnly: !isEditing,
      keyboardType: TextInputType.number,
      decoration: _cellInputDecoration(isError: isError).copyWith(
        suffixIcon: onRaise == null
            ? null
            : IconButton(
                key: ValueKey<String>('talents-raise-$talentId-$field'),
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: raiseTooltip ?? 'Steigern',
                onPressed: onRaise,
                icon: const Icon(Icons.trending_up),
              ),
        suffixIconConstraints: onRaise == null
            ? null
            : const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
      onChanged: isEditing
          ? (raw) => _updateIntField(talentId, field, raw)
          : null,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: textField,
    );
  }

  Widget _talentModifierCell({
    required TalentDef talent,
    required HeroTalentEntry entry,
    required bool isEditing,
  }) {
    if (!isEditing) {
      return _textCell(
        _formatWholeNumber(entry.modifier),
        key: ValueKey<String>('talents-field-${talent.id}-modifier-total'),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatWholeNumber(entry.modifier),
              key: ValueKey<String>(
                'talents-field-${talent.id}-modifier-total',
              ),
            ),
          ),
          IconButton(
            key: ValueKey<String>('talents-modifiers-edit-${talent.id}'),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: 'Modifikatoren bearbeiten',
            onPressed: () =>
                _openTalentModifiersDialog(talent: talent, entry: entry),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }

  Future<void> _openTalentModifiersDialog({
    required TalentDef talent,
    required HeroTalentEntry entry,
  }) async {
    final result = await _showTalentModifiersDialog(
      context: context,
      talentName: talent.name,
      initialModifiers: entry.talentModifiers,
    );
    if (result == null) {
      return;
    }
    _updateTalentModifiers(talent.id, result);
  }

  Widget _specializationBadgesCell({
    required String talentId,
    required HeroTalentEntry entry,
    required bool isEditing,
  }) {
    final specs = entry.combatSpecializations.isNotEmpty
        ? _normalizeStringList(entry.combatSpecializations)
        : _splitSpecializationTokens(entry.specializations);

    if (!isEditing) {
      if (specs.isEmpty) {
        return _textCell('-');
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 4,
            runSpacing: 2,
            children: specs
                .map(
                  (spec) => Chip(
                    label: Text(spec),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: adaptiveTapTargetSize(context),
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            ...specs.map(
              (spec) => InputChip(
                key: ValueKey<String>('talents-spec-$talentId-$spec'),
                label: Text(spec),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: adaptiveTapTargetSize(context),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                onDeleted: () {
                  final updated = List<String>.from(specs)..remove(spec);
                  _updateSpecializations(talentId, updated);
                },
              ),
            ),
            ActionChip(
              key: ValueKey<String>('talents-spec-add-$talentId'),
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Hinzufuegen'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.only(right: 6),
              onPressed: () => _showAddSpecializationDialog(talentId, specs),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSpecializationDialog(
    String talentId,
    List<String> currentSpecs,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Spezialisierung hinzufuegen'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Name der Spezialisierung',
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Hinzufuegen'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.trim().isEmpty) {
      return;
    }
    final updated = List<String>.from(currentSpecs)..add(result.trim());
    _updateSpecializations(talentId, updated);
  }

  Widget _giftedCell({
    required String talentId,
    required bool value,
    required bool isEditing,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Checkbox(
        key: ValueKey<String>('talents-gifted-$talentId'),
        value: value,
        onChanged: isEditing ? (next) => _updateGifted(talentId, next!) : null,
      ),
    );
  }

  InputDecoration _cellInputDecoration({bool isError = false}) {
    final theme = Theme.of(context).colorScheme;
    final borderColor = isError ? theme.error : theme.outline;
    return InputDecoration(
      isDense: true,
      border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isError ? theme.error : theme.primary),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  String _buildShortAttributeLabel(
    Attributes attributes,
    List<String> attributeNames,
  ) {
    final parts = <String>[];
    for (final name in attributeNames) {
      final code = parseAttributeCode(name);
      if (code == null) {
        parts.add('${name.trim()}: ?');
        continue;
      }
      final value = readAttributeValue(attributes, code);
      parts.add('${_attributeCodeLabel(code)}: $value');
    }
    return parts.join(' | ');
  }

  String _attributeCodeLabel(AttributeCode code) {
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

  String _formatWholeNumber(num value) {
    if (value == 0 || value == -0.0) {
      return '0';
    }
    if (value is int) {
      return value.toString();
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  int _calculateMaxTaw({
    required Attributes effectiveAttributes,
    required List<String> attributeNames,
    required bool gifted,
  }) {
    return computeTalentMaxValue(
      effectiveAttributes: effectiveAttributes,
      attributeNames: attributeNames,
      gifted: gifted,
    );
  }

  int _calculateMaxTawFromTalent({
    required TalentDef talent,
    required bool gifted,
  }) {
    final hero = _latestHero;
    if (hero == null) {
      return gifted ? 5 : 3;
    }
    final effective = computeEffectiveAttributes(hero);
    return computeCombatTalentMaxValue(
      effectiveAttributes: effective,
      talentType: talent.type,
      gifted: gifted,
    );
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return trimmed;
  }
}
