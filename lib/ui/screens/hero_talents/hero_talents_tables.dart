part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsTables on _HeroTalentTableTabState {
  Widget _buildTalentsTable({
    required List<TalentDef> talents,
    required Attributes effectiveAttributes,
    required int activeBaseBe,
    required bool showVisibilityControls,
  }) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildHeaderRow(
        isEditing: isEditing,
        showVisibilityControls: showVisibilityControls,
      ),
      ...talents.map(
        (talent) => _buildTalentRow(
          talent: talent,
          effectiveAttributes: effectiveAttributes,
          isEditing: isEditing,
          activeBaseBe: activeBaseBe,
          showVisibilityControls: showVisibilityControls,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: (isEditing || showVisibilityControls) ? 1870 : 1780,
          ),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(220),
              1: const FixedColumnWidth(240),
              2: const FixedColumnWidth(120),
              3: const FixedColumnWidth(70),
              4: const FixedColumnWidth(60),
              5: const FixedColumnWidth(60),
              6: const FixedColumnWidth(90),
              7: const FixedColumnWidth(90),
              8: const FixedColumnWidth(70),
              9: const FixedColumnWidth(70),
              10: const FixedColumnWidth(190),
              if (isEditing) 11: const FixedColumnWidth(95),
              if (isEditing || showVisibilityControls)
                (isEditing ? 12 : 11): const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildCombatTalentsTable({
    required List<TalentDef> talents,
    required bool showVisibilityControls,
  }) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(
        isEditing: isEditing,
        showVisibilityControls: showVisibilityControls,
      ),
      ...talents.map(
        (talent) => _buildCombatTalentRow(
          talent: talent,
          isEditing: isEditing,
          showVisibilityControls: showVisibilityControls,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: (isEditing || showVisibilityControls) ? 1660 : 1570,
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
              10: const FixedColumnWidth(230),
              if (isEditing || showVisibilityControls)
                (isEditing ? 11 : 10): const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  TableRow _buildHeaderRow({
    required bool isEditing,
    required bool showVisibilityControls,
  }) {
    final cells = <Widget>[
      _headerCell('Talent-Name'),
      _headerCell('Eigenschaften'),
      _headerCell('TaW berechnet', highlighted: true),
      _headerCell('Kompl.'),
      _headerCell('BE'),
      _headerCell('eBE'),
      _headerCell('TaW'),
      _headerCell('max TaW'),
      _headerCell('Mod'),
      _headerCell('SE'),
      _headerCell('Spezialisierungen'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Begabung'));
    }
    if (isEditing || showVisibilityControls) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
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
      if (isEditing) _headerCell('Begabung'),
      _headerCell('Spezialisierung'),
    ];
    if (isEditing || showVisibilityControls) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildTalentRow({
    required TalentDef talent,
    required Attributes effectiveAttributes,
    required bool isEditing,
    required int activeBaseBe,
    required bool showVisibilityControls,
  }) {
    final entry = _entryForTalent(talent.id);
    final ebe = computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be);
    final maxTaw = _calculateMaxTaw(
      effectiveAttributes: effectiveAttributes,
      attributeNames: talent.attributes,
      gifted: entry.gifted,
    );
    final isHidden = _isHidden(talent.id);
    final nameLabel = isEditing && isHidden
        ? '${talent.name} (ausgeblendet)'
        : talent.name;

    final cells = <Widget>[
      _textCell(nameLabel, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(
        _buildShortAttributeLabel(effectiveAttributes, talent.attributes),
      ),
      _textCell(
        _formatWholeNumber(_calculateComputedTaw(entry, ebe)),
        key: ValueKey<String>('talents-field-${talent.id}-computed-taw'),
        highlighted: true,
      ),
      _textCell(_fallback(talent.steigerung)),
      _textCell(_fallback(talent.be)),
      _textCell(
        _formatWholeNumber(ebe),
        key: ValueKey<String>('talents-field-${talent.id}-ebe-display'),
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue,
        isEditing: isEditing,
      ),
      _textCell(_formatWholeNumber(maxTaw)),
      _intInputCell(
        talentId: talent.id,
        field: 'modifier',
        value: entry.modifier,
        isEditing: isEditing,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'specialExperiences',
        value: entry.specialExperiences,
        isEditing: isEditing,
      ),
      _textInputCell(
        talentId: talent.id,
        field: 'specializations',
        value: entry.specializations,
        isEditing: isEditing,
      ),
    ];
    if (isEditing) {
      cells.add(
        _giftedCell(
          talentId: talent.id,
          value: entry.gifted,
          isEditing: isEditing,
        ),
      );
    }
    if (isEditing || showVisibilityControls) {
      cells.add(
        _visibilityCell(
          talentId: talent.id,
          isHidden: isHidden,
          enabled: showVisibilityControls,
        ),
      );
    }

    final giftedColor = entry.gifted && isEditing
        ? Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4)
        : null;
    return TableRow(
      decoration: BoxDecoration(
        color: isHidden && (isEditing || showVisibilityControls)
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : giftedColor,
      ),
      children: cells,
    );
  }

  TableRow _buildCombatTalentRow({
    required TalentDef talent,
    required bool isEditing,
    required bool showVisibilityControls,
  }) {
    final entry = _entryForTalent(talent.id);
    final isHidden = _isHidden(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
    final maxTaw = _calculateMaxTawFromTalent(talent: talent, gifted: entry.gifted);
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
      if (isEditing)
        _giftedCell(
          talentId: talent.id,
          value: entry.gifted,
          isEditing: isEditing,
        ),
      _combatSpecializationCell(
        talent: talent,
        entry: entry,
        isEditing: isEditing,
      ),
    ];
    if (isEditing || showVisibilityControls) {
      cells.add(
        _visibilityCell(
          talentId: talent.id,
          isHidden: isHidden,
          enabled: showVisibilityControls,
        ),
      );
    }

    final rowColor = isInvalid
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
        : (isHidden && (isEditing || showVisibilityControls)
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
}
