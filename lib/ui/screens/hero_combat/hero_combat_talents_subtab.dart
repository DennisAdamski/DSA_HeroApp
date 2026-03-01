part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

extension _HeroCombatTalentsSubtab on _HeroCombatTabState {
  Widget _buildCombatTalentsSubTab(List<TalentDef> talents) {
    final grouped = <String, List<TalentDef>>{};
    for (final talent in talents) {
      final group = talent.type.trim().isEmpty
          ? 'Kampf (ohne Typ)'
          : talent.type;
      grouped.putIfAbsent(group, () => <TalentDef>[]).add(talent);
    }
    final groups = grouped.keys.toList(growable: false)..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final entries = List<TalentDef>.from(
          grouped[group]!,
        )..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final visibleEntries = _editController.isEditing
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
            subtitle: Text(
              '${visibleEntries.length}/${entries.length} sichtbar',
            ),
            children: [_buildCombatTalentsTable(visibleEntries)],
          ),
        );
      },
    );
  }

  Widget _buildCombatTalentsTable(List<TalentDef> talents) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
      ...talents.map((talent) => _buildCombatTalentRow(talent, isEditing)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isEditing ? 1300 : 1210),
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
              if (isEditing) 8: const FixedColumnWidth(90),
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
    ];
    if (isEditing) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildCombatTalentRow(TalentDef talent, bool isEditing) {
    final entry = _entryForTalent(talent.id);
    final isHidden = _isHidden(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
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
    ];
    if (isEditing) {
      cells.add(_visibilityCell(talent.id, isHidden));
    }

    final rowColor = isInvalid
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
        : (isHidden && isEditing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
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

  Widget _visibilityCell(String talentId, bool isHidden) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: ValueKey<String>('talents-visibility-$talentId'),
        icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
        tooltip: isHidden ? 'Talent einblenden' : 'Talent ausblenden',
        onPressed: () => _toggleHidden(talentId),
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
}
