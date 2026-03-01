part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsCells on _HeroTalentTableTabState {
  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }

  Widget _textCell(String text, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(text)),
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
    final label = selected.isEmpty ? '-' : selected.join(', ');
    if (!isEditing) {
      return _textCell(label);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          key: ValueKey<String>('talents-combat-spec-${talent.id}'),
          onPressed: options.isEmpty
              ? null
              : () async {
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
          child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
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
  }) {
    final controller = _controllerFor(talentId, field, value.toString());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: TextField(
        key: ValueKey<String>('talents-field-$talentId-$field'),
        controller: controller,
        readOnly: !isEditing,
        keyboardType: TextInputType.number,
        decoration: _cellInputDecoration(isError: isError),
        onChanged: isEditing
            ? (raw) => _updateIntField(talentId, field, raw)
            : null,
      ),
    );
  }

  Widget _textInputCell({
    required String talentId,
    required String field,
    required String value,
    required bool isEditing,
  }) {
    final controller = _controllerFor(talentId, field, value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: TextField(
        key: ValueKey<String>('talents-field-$talentId-$field'),
        controller: controller,
        readOnly: !isEditing,
        decoration: _cellInputDecoration(),
        onChanged: isEditing
            ? (raw) => _updateStringField(talentId, field, raw)
            : null,
      ),
    );
  }

  Widget _visibilityCell({
    required String talentId,
    required bool isHidden,
    required bool enabled,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: ValueKey<String>('talents-visibility-$talentId'),
        icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
        tooltip: isHidden ? 'Talent einblenden' : 'Talent ausblenden',
        onPressed: enabled ? () => _toggleHidden(talentId) : null,
      ),
    );
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

  int _calculateComputedTaw(HeroTalentEntry entry, int ebe) {
    return entry.talentValue + entry.modifier + ebe;
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
    var maxValue = 0;
    for (final name in attributeNames) {
      final code = parseAttributeCode(name);
      if (code == null) {
        continue;
      }
      final value = readAttributeValue(effectiveAttributes, code);
      if (value > maxValue) {
        maxValue = value;
      }
    }
    return maxValue + (gifted ? 5 : 3);
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
    return _calculateMaxTaw(
      effectiveAttributes: effective,
      attributeNames: talent.attributes,
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
