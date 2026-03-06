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
          constraints: BoxConstraints(
            minWidth: isEditing ? 1780 : 1780,
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
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildCombatTalentsTable({
    required List<TalentDef> talents,
  }) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildCombatTalentRow(
          talent: talent,
          isEditing: isEditing,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1570),
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
      _headerCell('max TaW'),
      if (isEditing) _headerCell('Begabung'),
      _headerCell('Spezialisierung'),
    ];
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
    final maxTaw = _calculateMaxTaw(
      effectiveAttributes: effectiveAttributes,
      attributeNames: talent.attributes,
      gifted: entry.gifted,
    );

    final cells = <Widget>[
      _tappableNameCell(
        talent.name,
        key: ValueKey<String>('talents-row-${talent.id}'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _TalentDetailDialog(
            talent: talent,
            entry: entry,
            effectiveAttributes: effectiveAttributes,
            activeBaseBe: activeBaseBe,
          ),
        ),
      ),
      _textCell(
        _buildShortAttributeLabel(effectiveAttributes, talent.attributes),
      ),
      _textCell(
        _formatWholeNumber(
          computeTalentComputedTaw(
            talentValue: entry.talentValue,
            modifier: entry.modifier,
            ebe: ebe,
          ),
        ),
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
      _specializationBadgesCell(
        talentId: talent.id,
        entry: entry,
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

    final giftedColor = entry.gifted && isEditing
        ? Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4)
        : null;
    return TableRow(
      decoration: BoxDecoration(color: giftedColor),
      children: cells,
    );
  }

  TableRow _buildCombatTalentRow({
    required TalentDef talent,
    required bool isEditing,
  }) {
    final entry = _entryForTalent(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
    final maxTaw = _calculateMaxTawFromTalent(talent: talent, gifted: entry.gifted);

    final effective = _latestHero != null
        ? computeEffectiveAttributes(_latestHero!)
        : const Attributes();

    final cells = <Widget>[
      _tappableNameCell(
        talent.name,
        key: ValueKey<String>('talents-row-${talent.id}'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _TalentDetailDialog(
            talent: talent,
            entry: entry,
            effectiveAttributes: effective,
            activeBaseBe: 0,
          ),
        ),
      ),
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
}
