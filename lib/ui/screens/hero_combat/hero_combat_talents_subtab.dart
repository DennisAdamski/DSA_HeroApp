part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatTalentsSubtab on _HeroCombatTabState {
  void _toggleCombatTalent(String talentId, bool activate) {
    if (activate) {
      _draftTalents.putIfAbsent(talentId, () => const HeroTalentEntry());
    } else {
      _draftTalents.remove(talentId);
      _controllers.remove('talent::$talentId::talentValue')?.dispose();
      _controllers.remove('talent::$talentId::atValue')?.dispose();
      _controllers.remove('talent::$talentId::paValue')?.dispose();
    }
    _markFieldChanged();
  }

  void _showCombatTalentKatalog(
    BuildContext context,
    List<TalentDef> allCombatTalents,
  ) {
    final localActiveIds = _draftTalents.keys.toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: screenHeight * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _CombatTalentCatalogTable(
                      allTalents: allCombatTalents,
                      activeTalentIds: localActiveIds,
                      onToggleTalent: (id, activate) {
                        _toggleCombatTalent(id, activate);
                        setSheetState(() {
                          if (activate) {
                            localActiveIds.add(id);
                          } else {
                            localActiveIds.remove(id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCombatTalentsSubTab(
    List<TalentDef> talents, {
    required Attributes effectiveAttributes,
  }) {
    final grouped = <String, List<TalentDef>>{};
    for (final talent in talents) {
      final group = talent.type.trim().isEmpty
          ? 'Kampf (ohne Typ)'
          : talent.type;
      grouped.putIfAbsent(group, () => <TalentDef>[]).add(talent);
    }
    final groups = grouped.keys.toList(growable: false)..sort();

    // Nur Talente anzeigen, die in _draftTalents enthalten sind
    final visibleGroups = groups
        .where((group) {
          if (_editController.isEditing) {
            // Im Edit-Modus alle Gruppen zeigen, die aktive Talente haben
            final entries = grouped[group] ?? const <TalentDef>[];
            return entries.any((t) => _draftTalents.containsKey(t.id));
          }
          final entries = grouped[group] ?? const <TalentDef>[];
          return entries.any((t) => _draftTalents.containsKey(t.id));
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      children: [
        if (widget.showInlineCombatTalentsActions || _editController.isEditing)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showInlineCombatTalentsActions)
                      FilledButton.icon(
                        key: const ValueKey<String>(
                          'combat-talents-start-edit',
                        ),
                        onPressed: _editController.isEditing
                            ? null
                            : () {
                                _startEdit();
                              },
                        icon: const Icon(Icons.edit),
                        label: const Text('Bearbeiten'),
                      ),
                    if (_editController.isEditing) ...[
                      if (widget.showInlineCombatTalentsActions)
                        const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const ValueKey<String>(
                          'combat-talents-catalog-open',
                        ),
                        onPressed: () =>
                            _showCombatTalentKatalog(context, talents),
                        icon: const Icon(Icons.library_add),
                        label: const Text('Kampftalente verwalten'),
                      ),
                    ],
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
          final activeEntries = entries
              .where((t) => _draftTalents.containsKey(t.id))
              .toList(growable: false);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              title: Text(group),
              subtitle: Text(
                '${activeEntries.length}/${entries.length} aktiv',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                _buildCombatTalentsTable(
                  activeEntries,
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
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
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
          constraints: BoxConstraints(minWidth: isEditing ? 1625 : 1535),
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
              9: const FixedColumnWidth(230),
              if (isEditing) 10: const FixedColumnWidth(95),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  TableRow _buildCombatHeaderRow({required bool isEditing}) {
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
      _headerCell('Spezialisierung'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Begabung'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildCombatTalentRow(
    TalentDef talent,
    bool isEditing, {
    required Attributes effectiveAttributes,
  }) {
    final entry = _entryForTalent(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
    final effectiveKomplexitaet = effectiveTalentLernkomplexitaet(
      basisKomplexitaet: talent.steigerung,
      gifted: entry.gifted,
    );
    final maxTaw = computeCombatTalentMaxValue(
      effectiveAttributes: effectiveAttributes,
      talentType: talent.type,
      gifted: entry.gifted,
    );

    final cells = <Widget>[
      _textCell(talent.name, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(_fallback(talent.weaponCategory)),
      _textCell(_fallback(talent.alternatives)),
      _textCell(_fallback(effectiveKomplexitaet)),
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
      _combatSpecializationCell(
        talent: talent,
        entry: entry,
        isEditing: isEditing,
      ),
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

    final rowColor = isInvalid
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
        : (entry.gifted && isEditing
              ? Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.4)
              : null);

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
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                key: ValueKey<String>('combat-spec-${talent.id}-$spec'),
                label: Text(spec),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                key: ValueKey<String>('combat-spec-add-${talent.id}'),
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Hinzufuegen'),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
