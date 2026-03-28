part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsTables on _HeroTalentTableTabState {
  // Meta-Talente haben eine andere Struktur, daher eigene Spaltenspezifikationen
  static const List<AdaptiveTableColumnSpec> _metaTalentColumnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 240, flex: 2), // Name
        AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 180), // Eigenschaften
        AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // TaW*
        AdaptiveTableColumnSpec(minWidth: 60, maxWidth: 60), // eBE
        AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // TaW
        AdaptiveTableColumnSpec(
          minWidth: 180,
          maxWidth: 400,
          flex: 2,
        ), // Bestandteile
      ];

  // Normale Talente (nicht-Kampf) haben die Standardstruktur, aber die TaW-Spalte ist im Bearbeitungsmodus breiter, um den Steigerungsbutton aufzunehmen
  List<AdaptiveTableColumnSpec> _talentColumnSpecs({required bool isEditing}) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(
        minWidth: 160,
        maxWidth: 240,
        flex: 2,
      ), // Talent-Name
      const AdaptiveTableColumnSpec(
        minWidth: 180,
        maxWidth: 180,
      ), // Eigenschaften
      const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // TaW*
      const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // Kompl.
      const AdaptiveTableColumnSpec(minWidth: 60, maxWidth: 60), // eBE
      if (isEditing)
        const AdaptiveTableColumnSpec(
          minWidth: 80,
          maxWidth: 110,
        ) // TaW (edit: breiter)
      else
        const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // TaW
      const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // Mod
      const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 70), // SE
      const AdaptiveTableColumnSpec(
        minWidth: 160,
        maxWidth: 280,
        flex: 3,
      ), // Spezialisierungen
      if (isEditing) const AdaptiveTableColumnSpec.fixed(90), // Begabung
    ];
  }

  // Kampf-Talente haben zusätzliche Spalten für AT/PA und Waffengattung, daher eigene Spaltenspezifikationen. Auch hier ist die TaW-Spalte im Bearbeitungsmodus breiter.
  List<AdaptiveTableColumnSpec> _combatTalentColumnSpecs({
    required bool isEditing,
  }) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(
        minWidth: 160,
        maxWidth: 240,
        flex: 2,
      ), // Talent-Name
      const AdaptiveTableColumnSpec(
        minWidth: 180,
        maxWidth: 320,
        flex: 2,
      ), // Waffengattung
      const AdaptiveTableColumnSpec(
        minWidth: 160,
        maxWidth: 240,
        flex: 2,
      ), // Ersatzweise
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80), // Kompl.
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90), // TaW
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90), // AT
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 90), // PA
      if (isEditing) const AdaptiveTableColumnSpec.fixed(90), // Begabung
      const AdaptiveTableColumnSpec(
        minWidth: 180,
        maxWidth: 320,
        flex: 3,
      ), // Spezialisierung
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
      _headerCell(debug ? 'talentName' : 'Name'),
      _headerCell(debug ? 'attributes' : 'Eigenschaften'),
      _headerCell(debug ? 'talentValue' : 'TaW*', highlighted: true),
      _headerCell(debug ? 'steigerung' : 'Kompl.'),
      _headerCell(debug ? 'eBe' : 'eBE'),
      _headerCell(debug ? 'taw' : 'TaW'),
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
      _headerCell(debug ? 'talentName' : 'Name'),
      _headerCell(debug ? 'waffengattung' : 'Waffengattung'),
      _headerCell(debug ? 'ersatzweise' : 'Ersatzweise'),
      _headerCell(debug ? 'steigerung' : 'Kompl.'),
      _headerCell(debug ? 'taw' : 'TaW'),
      _headerCell(debug ? 'at' : 'AT'),
      _headerCell(debug ? 'pa' : 'PA'),
      if (isEditing) _headerCell(debug ? 'gifted' : 'Begabung'),
      _headerCell(debug ? 'specialization' : 'Spezialisierung'),
    ];
    return TableRow(children: cells);
  }

  TableRow _buildMetaHeaderRow() {
    final debug = ref.read(debugModusProvider);
    return TableRow(
      children: [
        _headerCell(debug ? 'talentName' : 'Name'),
        _headerCell(debug ? 'attributes' : 'Eigenschaften'),
        _headerCell(debug ? 'talentValue' : 'TaW*', highlighted: true),
        _headerCell(debug ? 'eBe' : 'eBE'),
        _headerCell(debug ? 'taw' : 'TaW'),
        _headerCell(debug ? 'components' : 'Bestandteile'),
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
    final computedTaw = computeTalentComputedTaw(
      talentValue: entry.talentValue,
      modifier: entry.modifier,
      ebe: ebe,
      inventoryMod: inventoryMod,
    );
    final hasSpecialization =
        entry.combatSpecializations.isNotEmpty ||
        _splitSpecializationTokens(entry.specializations).isNotEmpty;

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
        trailing: IconButton(
          key: ValueKey<String>('talents-roll-${talent.id}'),
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: '${talent.name} würfeln',
          onPressed: () => showProbeDialog(
            context: context,
            request: buildTalentProbeRequest(
              title: talent.name,
              targets: _buildProbeTargets(
                effectiveAttributes,
                talent.attributes,
              ),
              basePool: computedTaw,
              hasSpecialization: hasSpecialization,
              wundMalus:
                  ref
                      .read(heroComputedProvider(widget.heroId))
                      .asData
                      ?.value
                      .wundEffekte
                      .talentProbeMalus ??
                  0,
            ),
          ),
          icon: const Icon(Icons.casino_outlined),
        ),
      ),
      _textCell(
        _buildShortAttributeLabel(effectiveAttributes, talent.attributes),
      ),
      _textCell(
        _formatWholeNumber(computedTaw),
        key: ValueKey<String>('talents-field-${talent.id}-computed-taw'),
        highlighted: true,
      ),
      _textCell(
        _fallback(effectiveKomplexitaet),
        highlighted: effectiveKomplexitaet != talent.steigerung,
      ),
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
    final talentProbeMalus =
        ref
            .read(heroComputedProvider(widget.heroId))
            .asData
            ?.value
            .wundEffekte
            .talentProbeMalus ??
        0;

    return TableRow(
      children: [
        _tappableNameCell(
          metaTalent.name,
          key: ValueKey<String>('meta-talents-row-${metaTalent.id}'),
          onTap: () => showAdaptiveDetailSheet<void>(
            context: context,
            builder: (_) => _MetaTalentDetailDialog(
              metaTalent: metaTalent,
              effectiveAttributes: effectiveAttributes,
              activeBaseBe: activeBaseBe,
              componentNames: componentNames,
              rawTaw: rawTaw,
              computedTaw: computedTaw,
            ),
          ),
          trailing: IconButton(
            key: ValueKey<String>('meta-talents-roll-${metaTalent.id}'),
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: '${metaTalent.name} würfeln',
            onPressed: () => showProbeDialog(
              context: context,
              request: buildTalentProbeRequest(
                title: metaTalent.name,
                targets: _buildProbeTargets(
                  effectiveAttributes,
                  metaTalent.attributes,
                ),
                basePool: computedTaw,
                wundMalus: talentProbeMalus,
              ),
            ),
            icon: const Icon(Icons.casino_outlined),
          ),
        ),
        _textCell(
          _buildShortAttributeLabel(effectiveAttributes, metaTalent.attributes),
        ),
        _textCell(
          _formatWholeNumber(computedTaw),
          key: ValueKey<String>(
            'meta-talents-field-${metaTalent.id}-computed-taw',
          ),
          highlighted: true,
        ),
        _textCell(
          _formatWholeNumber(ebe),
          key: ValueKey<String>('meta-talents-field-${metaTalent.id}-ebe'),
        ),
        _textCell(
          _formatWholeNumber(rawTaw),
          key: ValueKey<String>('meta-talents-field-${metaTalent.id}-raw-taw'),
        ),
        _textCell(componentNames.join(', ')),
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
