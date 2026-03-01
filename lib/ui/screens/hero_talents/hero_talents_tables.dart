part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsTables on _HeroTalentTableTabState {
  Widget _buildTalentsTable({
    required List<TalentDef> talents,
    required Attributes effectiveAttributes,
    required int activeBaseBe,
  }) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildTalentRow(
          talent: talent,
          effectiveAttributes: effectiveAttributes,
          isEditing: isEditing,
          activeBaseBe: activeBaseBe,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isEditing ? 1900 : 1800),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(220),
              1: const FixedColumnWidth(240),
              2: const FixedColumnWidth(70),
              3: const FixedColumnWidth(60),
              4: const FixedColumnWidth(60),
              5: const FixedColumnWidth(90),
              6: const FixedColumnWidth(90),
              7: const FixedColumnWidth(70),
              8: const FixedColumnWidth(120),
              9: const FixedColumnWidth(70),
              10: const FixedColumnWidth(190),
              11: const FixedColumnWidth(230),
              if (isEditing) 12: const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildCombatTalentsTable({required List<TalentDef> talents}) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildCombatTalentRow(talent: talent, isEditing: isEditing),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isEditing ? 1530 : 1440),
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
              8: const FixedColumnWidth(230),
              if (isEditing) 9: const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  TableRow _buildHeaderRow({required bool isEditing}) {
    final cells = <Widget>[
      _headerCell('Talent-Name'),
      _headerCell('Eigenschaften'),
      _headerCell('Kompl.'),
      _headerCell('BE'),
      _headerCell('eBE'),
      _headerCell('TaW'),
      _headerCell('max TaW'),
      _headerCell('Mod'),
      _headerCell('TaW berechnet'),
      _headerCell('SE'),
      _headerCell('Spezialisierungen'),
      _headerCell('Sonderfertigkeiten'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
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
      _headerCell('Spezialisierung'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildTalentRow({
    required TalentDef talent,
    required Attributes effectiveAttributes,
    required bool isEditing,
    required int activeBaseBe,
  }) {
    final entry = _entryForTalent(talent.id);
    final ebe = computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be);
    final isHidden = _isHidden(talent.id);
    final nameLabel = isEditing && isHidden
        ? '${talent.name} (ausgeblendet)'
        : talent.name;

    final cells = <Widget>[
      _textCell(nameLabel, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(
        _buildShortAttributeLabel(effectiveAttributes, talent.attributes),
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
      _textCell('-'),
      _intInputCell(
        talentId: talent.id,
        field: 'modifier',
        value: entry.modifier,
        isEditing: isEditing,
      ),
      _textCell(
        _formatWholeNumber(_calculateComputedTaw(entry, ebe)),
        key: ValueKey<String>('talents-field-${talent.id}-computed-taw'),
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
      _textInputCell(
        talentId: talent.id,
        field: 'specialAbilities',
        value: entry.specialAbilities,
        isEditing: isEditing,
      ),
    ];
    if (isEditing) {
      cells.add(_visibilityCell(talentId: talent.id, isHidden: isHidden));
    }

    return TableRow(
      decoration: BoxDecoration(
        color: isHidden && isEditing
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
      ),
      children: cells,
    );
  }

  TableRow _buildCombatTalentRow({
    required TalentDef talent,
    required bool isEditing,
  }) {
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
      _combatSpecializationCell(
        talent: talent,
        entry: entry,
        isEditing: isEditing,
      ),
    ];
    if (isEditing) {
      cells.add(_visibilityCell(talentId: talent.id, isHidden: isHidden));
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
}
