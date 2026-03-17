part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsTables on _HeroTalentTableTabState {
  static const List<AdaptiveTableColumnSpec> _metaTalentColumnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 240, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 220, maxWidth: 420, flex: 3),
        AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 240, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90),
        AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 120),
      ];

  List<AdaptiveTableColumnSpec> _talentColumnSpecs({required bool isEditing}) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 240, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 280, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 84, maxWidth: 132),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 72),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 72),
      if (isEditing)
        const AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 110)
      else
        const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90),
      const AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 110),
      const AdaptiveTableColumnSpec(minWidth: 92, maxWidth: 140),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 76),
      const AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 280, flex: 3),
      if (isEditing) const AdaptiveTableColumnSpec.fixed(90),
    ];
  }

  List<AdaptiveTableColumnSpec> _combatTalentColumnSpecs({
    required bool isEditing,
  }) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 240, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 320, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 240, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 72),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90),
      const AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 100),
      if (isEditing) const AdaptiveTableColumnSpec.fixed(90),
      const AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 320, flex: 3),
    ];
  }

  Widget _buildMetaTalentsCard({
    required List<HeroMetaTalent> metaTalents,
    required List<TalentDef> catalogTalents,
    required Attributes effectiveAttributes,
    required int activeBaseBe,
  }) {
    final rows = <TableRow>[
      _buildMetaHeaderRow(),
      ...metaTalents.map(
        (metaTalent) => _buildMetaTalentRow(
          metaTalent: metaTalent,
          catalogTalents: catalogTalents,
          effectiveAttributes: effectiveAttributes,
          activeBaseBe: activeBaseBe,
        ),
      ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: const Text('Meta-Talente'),
        subtitle: Text(
          '${metaTalents.length} Talente',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = resolveAdaptiveTableLayout(
                  _metaTalentColumnSpecs,
                  availableWidth: constraints.maxWidth,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: layout.tableWidth,
                    child: Table(
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      columnWidths: layout.toColumnWidthMap(),
                      children: rows,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalentsTable({
    required List<TalentDef> talents,
    required Attributes effectiveAttributes,
    required int activeBaseBe,
    Map<String, int> inventoryTalentMods = const {},
  }) {
    final isEditing = _editController.isEditing;
    final columnSpecs = _talentColumnSpecs(isEditing: isEditing);
    final rows = <TableRow>[
      _buildHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildTalentRow(
          talent: talent,
          effectiveAttributes: effectiveAttributes,
          isEditing: isEditing,
          activeBaseBe: activeBaseBe,
          inventoryMod: inventoryTalentMods[talent.id] ?? 0,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = resolveAdaptiveTableLayout(
            columnSpecs,
            availableWidth: constraints.maxWidth,
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: layout.tableWidth,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: layout.toColumnWidthMap(),
                children: rows,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCombatTalentsTable({required List<TalentDef> talents}) {
    final isEditing = _editController.isEditing;
    final columnSpecs = _combatTalentColumnSpecs(isEditing: isEditing);
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildCombatTalentRow(talent: talent, isEditing: isEditing),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = resolveAdaptiveTableLayout(
            columnSpecs,
            availableWidth: constraints.maxWidth,
          );
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: layout.tableWidth,
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: layout.toColumnWidthMap(),
                children: rows,
              ),
            ),
          );
        },
      ),
    );
  }

  TableRow _buildHeaderRow({required bool isEditing}) {
    final debug = ref.read(debugModusProvider);
    final cells = <Widget>[
      _headerCell(debug ? 'talentName' : 'Talent-Name'),
      _headerCell(debug ? 'attributes' : 'Eigenschaften'),
      _headerCell(debug ? 'talentValue' : 'TaW berechnet', highlighted: true),
      _headerCell(debug ? 'steigerung' : 'Kompl.'),
      _headerCell(debug ? 'be' : 'BE'),
      _headerCell(debug ? 'eBe' : 'eBE'),
      _headerCell(debug ? 'taw' : 'TaW'),
      _headerCell(debug ? 'maxTaw' : 'max TaW'),
      _headerCell(debug ? 'modifier' : 'Mod'),
      _headerCell(debug ? 'se' : 'SE'),
      _headerCell(debug ? 'specializations' : 'Spezialisierungen'),
    ];
    if (isEditing) {
      cells.add(_headerCell(debug ? 'gifted' : 'Begabung'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildCombatHeaderRow({required bool isEditing}) {
    final debug = ref.read(debugModusProvider);
    final cells = <Widget>[
      _headerCell(debug ? 'talentName' : 'Talent-Name'),
      _headerCell(debug ? 'waffengattung' : 'Waffengattung'),
      _headerCell(debug ? 'ersatzweise' : 'Ersatzweise'),
      _headerCell(debug ? 'steigerung' : 'Kompl.'),
      _headerCell(debug ? 'be' : 'BE'),
      _headerCell(debug ? 'taw' : 'TaW'),
      _headerCell(debug ? 'at' : 'AT'),
      _headerCell(debug ? 'pa' : 'PA'),
      _headerCell(debug ? 'maxTaw' : 'max TaW'),
      if (isEditing) _headerCell(debug ? 'gifted' : 'Begabung'),
      _headerCell(debug ? 'specialization' : 'Spezialisierung'),
    ];
    return TableRow(children: cells);
  }

  TableRow _buildMetaHeaderRow() {
    final debug = ref.read(debugModusProvider);
    return TableRow(
      children: [
        _headerCell(debug ? 'talentName' : 'Talent-Name'),
        _headerCell(debug ? 'components' : 'Bestandteile'),
        _headerCell(debug ? 'attributes' : 'Eigenschaften'),
        _headerCell(debug ? 'be' : 'BE'),
        _headerCell(debug ? 'eBe' : 'eBE'),
        _headerCell(debug ? 'taw' : 'TaW'),
        _headerCell(debug ? 'talentValue' : 'TaW berechnet', highlighted: true),
        _headerCell(debug ? 'maxTaw' : 'max TaW'),
      ],
    );
  }

  TableRow _buildTalentRow({
    required TalentDef talent,
    required Attributes effectiveAttributes,
    required bool isEditing,
    required int activeBaseBe,
    int inventoryMod = 0,
  }) {
    final entry = _entryForTalent(talent.id);
    final ebe = computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be);
    final effectiveKomplexitaet = effectiveTalentLernkomplexitaet(
      basisKomplexitaet: talent.steigerung,
      gifted: entry.gifted,
    );
    final maxTaw = _calculateMaxTaw(
      effectiveAttributes: effectiveAttributes,
      attributeNames: talent.attributes,
      gifted: entry.gifted,
    );

    final cells = <Widget>[
      _tappableNameCell(
        talent.name,
        key: ValueKey<String>('talents-row-${talent.id}'),
        onTap: () => showAdaptiveDetailSheet<void>(
          context: context,
          builder: (_) => _TalentDetailDialog(
            talent: talent,
            entry: entry,
            effectiveAttributes: effectiveAttributes,
            activeBaseBe: activeBaseBe,
            inventoryMod: inventoryMod,
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
            inventoryMod: inventoryMod,
          ),
        ),
        key: ValueKey<String>('talents-field-${talent.id}-computed-taw'),
        highlighted: true,
      ),
      _textCell(
        _fallback(effectiveKomplexitaet),
        highlighted: effectiveKomplexitaet != talent.steigerung,
      ),
      _textCell(_fallback(talent.be)),
      _textCell(
        _formatWholeNumber(ebe),
        key: ValueKey<String>('talents-field-${talent.id}-ebe-display'),
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue ?? 0,
        isEditing: isEditing,
        onRaise: isEditing && _canUseSteigerungsDialog
            ? () => _steigereTalent(talent.id)
            : null,
        raiseTooltip: 'Talent steigern',
      ),
      _textCell(_formatWholeNumber(maxTaw)),
      _talentModifierCell(talent: talent, entry: entry, isEditing: isEditing),
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
    final effectiveKomplexitaet = effectiveTalentLernkomplexitaet(
      basisKomplexitaet: talent.steigerung,
      gifted: entry.gifted,
    );
    final maxTaw = _calculateMaxTawFromTalent(
      talent: talent,
      gifted: entry.gifted,
    );

    final effective = _latestHero != null
        ? computeEffectiveAttributes(_latestHero!)
        : const Attributes(
            mu: 0,
            kl: 0,
            inn: 0,
            ch: 0,
            ff: 0,
            ge: 0,
            ko: 0,
            kk: 0,
          );

    final cells = <Widget>[
      _tappableNameCell(
        talent.name,
        key: ValueKey<String>('talents-row-${talent.id}'),
        onTap: () => showAdaptiveDetailSheet<void>(
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
      _textCell(
        _fallback(effectiveKomplexitaet),
        highlighted: effectiveKomplexitaet != talent.steigerung,
      ),
      _textCell(_fallback(talent.be)),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue ?? 0,
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

  TableRow _buildMetaTalentRow({
    required HeroMetaTalent metaTalent,
    required List<TalentDef> catalogTalents,
    required Attributes effectiveAttributes,
    required int activeBaseBe,
  }) {
    final componentNames = _metaTalentComponentNames(
      metaTalent: metaTalent,
      catalogTalents: catalogTalents,
    );
    final ebe = computeMetaTalentEbe(
      baseBe: activeBaseBe,
      beRule: metaTalent.be,
    );
    final rawTaw = computeMetaTalentBaseTaw(
      talentEntries: _draftTalents,
      componentTalentIds: metaTalent.componentTalentIds,
    );
    final computedTaw = computeMetaTalentComputedTaw(baseTaw: rawTaw, ebe: ebe);
    final maxTaw = _calculateMaxTaw(
      effectiveAttributes: effectiveAttributes,
      attributeNames: metaTalent.attributes,
      gifted: false,
    );

    return TableRow(
      children: [
        _textCell(
          metaTalent.name,
          key: ValueKey<String>('meta-talents-row-${metaTalent.id}'),
        ),
        _textCell(componentNames.join(', ')),
        _textCell(
          _buildShortAttributeLabel(effectiveAttributes, metaTalent.attributes),
        ),
        _textCell(_fallback(metaTalent.be)),
        _textCell(
          _formatWholeNumber(ebe),
          key: ValueKey<String>('meta-talents-field-${metaTalent.id}-ebe'),
        ),
        _textCell(
          _formatWholeNumber(rawTaw),
          key: ValueKey<String>('meta-talents-field-${metaTalent.id}-raw-taw'),
        ),
        _textCell(
          _formatWholeNumber(computedTaw),
          key: ValueKey<String>(
            'meta-talents-field-${metaTalent.id}-computed-taw',
          ),
          highlighted: true,
        ),
        _textCell(_formatWholeNumber(maxTaw)),
      ],
    );
  }

  List<String> _metaTalentComponentNames({
    required HeroMetaTalent metaTalent,
    required List<TalentDef> catalogTalents,
  }) {
    final nameById = <String, String>{
      for (final talent in catalogTalents) talent.id: talent.name,
    };
    return metaTalent.componentTalentIds
        .map((id) => nameById[id] ?? id)
        .toList(growable: false);
  }
}
