part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatTalentsSubtab on _HeroCombatTabState {
  Widget _buildCombatTalentsSubTab(
    List<TalentDef> talents, {
    required Attributes effectiveAttributes,
  }) {
    final visibilityMode = ref.watch(
      combatTechniquesVisibilityModeProvider(widget.heroId),
    );
    final grouped = <String, List<TalentDef>>{};
    for (final talent in talents) {
      final group = talent.type.trim().isEmpty
          ? 'Kampf (ohne Typ)'
          : talent.type;
      grouped.putIfAbsent(group, () => <TalentDef>[]).add(talent);
    }
    final groups = grouped.keys.toList(growable: false)..sort();
    final showAllTalents = _editController.isEditing || visibilityMode;
    final visibleGroups = groups
        .where((group) {
          if (showAllTalents) {
            return true;
          }
          final entries = grouped[group] ?? const <TalentDef>[];
          return entries.any((talent) => !_isHidden(talent.id));
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      children: [
        if (widget.showInlineCombatTalentsActions)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey<String>('combat-talents-start-edit'),
                      onPressed: _editController.isEditing
                          ? null
                          : () {
                              _startEdit();
                            },
                      icon: const Icon(Icons.edit),
                      label: const Text('Bearbeiten'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      key: const ValueKey<String>(
                        'combat-talents-visibility-mode-toggle',
                      ),
                      onPressed: () =>
                          _setCombatTalentsVisibilityMode(!visibilityMode),
                      icon: Icon(
                        visibilityMode
                            ? Icons.visibility_off_outlined
                            : Icons.visibility,
                      ),
                      label: Text(
                        visibilityMode
                            ? 'Sichtbarkeit beenden'
                            : 'Sichtbarkeit bearbeiten',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ...List<Widget>.generate(visibleGroups.length, (index) {
          final group = visibleGroups[index];
          final entries = List<TalentDef>.from(grouped[group]!)
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          final visibleEntries = showAllTalents
              ? entries
              : entries
                    .where((talent) => !_isHidden(talent.id))
                    .toList(growable: false);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              title: Text(group),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${visibleEntries.length}/${entries.length} sichtbar',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (visibilityMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            TextButton(
                              key: ValueKey<String>(
                                'combat-group-show-all-$group',
                              ),
                              onPressed: () =>
                                  _setHiddenForGroup(entries, hidden: false),
                              child: const Text('Alle einblenden'),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
                              key: ValueKey<String>(
                                'combat-group-hide-all-$group',
                              ),
                              onPressed: () =>
                                  _setHiddenForGroup(entries, hidden: true),
                              child: const Text('Alle ausblenden'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              children: [
                _buildCombatTalentsTable(
                  visibleEntries,
                  effectiveAttributes: effectiveAttributes,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCombatTalentsTable(
    List<TalentDef> talents, {
    required Attributes effectiveAttributes,
  }) {
    final visibilityMode = ref.watch(
      combatTechniquesVisibilityModeProvider(widget.heroId),
    );
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(
        isEditing: isEditing,
        showVisibilityControls: visibilityMode,
      ),
      ...talents.map(
        (talent) => _buildCombatTalentRow(
          talent,
          isEditing,
          effectiveAttributes: effectiveAttributes,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: (isEditing || visibilityMode) ? 1485 : 1395,
          ),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(220),
              1: const FixedColumnWidth(300),
              2: const FixedColumnWidth(220),
              3: const FixedColumnWidth(70),
              4: const FixedColumnWidth(60),
              5: const FixedColumnWidth(90),
              6: const FixedColumnWidth(90),
              7: const FixedColumnWidth(90),
              8: const FixedColumnWidth(90),
              if (isEditing) 9: const FixedColumnWidth(95),
              if (isEditing || visibilityMode)
                (isEditing ? 10 : 9): const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  TableRow _buildCombatHeaderRow({
    required bool isEditing,
    required bool showVisibilityControls,
  }) {
    final cells = <Widget>[
      _headerCell('Talent-Name'),
      _headerCell('Waffengattung'),
      _headerCell('Ersatzweise'),
      _headerCell('Kompl.'),
      _headerCell('BE'),
      _headerCell('TaW'),
      _headerCell('AT'),
      _headerCell('PA'),
      _headerCell('max TaW'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Begabung'));
    }
    if (isEditing || showVisibilityControls) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildCombatTalentRow(
    TalentDef talent,
    bool isEditing, {
    required Attributes effectiveAttributes,
  }) {
    final visibilityMode = ref.watch(
      combatTechniquesVisibilityModeProvider(widget.heroId),
    );
    final entry = _entryForTalent(talent.id);
    final isHidden = _isHidden(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
    final maxTaw = _calculateMaxTaw(
      effectiveAttributes: effectiveAttributes,
      attributeNames: talent.attributes,
      gifted: entry.gifted,
    );
    final nameLabel = isEditing && isHidden
        ? '${talent.name} (ausgeblendet)'
        : talent.name;

    final cells = <Widget>[
      _textCell(nameLabel, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(_fallback(talent.weaponCategory)),
      _textCell(_fallback(talent.alternatives)),
      _textCell(_fallback(talent.steigerung)),
      _textCell(_fallback(talent.be)),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'atValue',
        value: entry.atValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'paValue',
        value: entry.paValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _textCell(_formatWholeNumber(maxTaw)),
    ];
    if (isEditing) {
      cells.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Checkbox(
            key: ValueKey<String>('combat-talents-gifted-${talent.id}'),
            value: entry.gifted,
            onChanged: (value) => _updateGifted(talent.id, value ?? false),
          ),
        ),
      );
    }
    if (isEditing || visibilityMode) {
      cells.add(_visibilityCell(talent.id, isHidden));
    }

    final rowColor = isInvalid
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
        : (isHidden && (isEditing || visibilityMode)
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : (entry.gifted && isEditing
                    ? Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer.withValues(alpha: 0.4)
                    : null));

    return TableRow(
      decoration: BoxDecoration(color: rowColor),
      children: cells,
    );
  }

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

  Widget _intInputCell({
    required String talentId,
    required String field,
    required int value,
    required bool isEditing,
    bool isError = false,
  }) {
    final controller = _controllerFor(
      'talent::$talentId::$field',
      value.toString(),
    );
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

  Widget _visibilityCell(String talentId, bool isHidden) {
    final visibilityMode = ref.watch(
      combatTechniquesVisibilityModeProvider(widget.heroId),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: ValueKey<String>('talents-visibility-$talentId'),
        icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
        tooltip: isHidden ? 'Talent einblenden' : 'Talent ausblenden',
        onPressed: visibilityMode ? () => _toggleHidden(talentId) : null,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
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
}
