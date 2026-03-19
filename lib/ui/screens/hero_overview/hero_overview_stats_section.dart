part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewStatsSection on _HeroOverviewTabState {
  static const List<AdaptiveTableColumnSpec> _derivedValueColumnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 96, maxWidth: 136),
        AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 92, maxWidth: 132),
        AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 82, maxWidth: 120),
      ];

  static const List<AdaptiveTableColumnSpec> _attributeColumnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 96, maxWidth: 136),
        AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120),
        AdaptiveTableColumnSpec(minWidth: 86, maxWidth: 132),
      ];

  Widget _buildCombinedStatsAndAttributesSection(
    HeroComputedSnapshot snapshot,
    HeroResourceActivation resourceActivation,
  ) {
    final hero = snapshot.hero;
    final state = snapshot.state;
    final derived = snapshot.derivedStats;
    return LayoutBuilder(
      builder: (context, constraints) {
        final derivedSection = _buildDerivedValuesSection(
          hero,
          state,
          derived,
          snapshot,
          resourceActivation,
        );
        final attributesSection = _buildAttributesSection(
          snapshot.effectiveStartAttributes,
          snapshot.attributeMaximums,
          snapshot.effectiveAttributes,
          snapshot,
        );
        if (constraints.maxWidth >= _largeTwoColumnBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: attributesSection),
              const SizedBox(width: _sectionSpacing),
              Expanded(child: derivedSection),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            attributesSection,
            const SizedBox(height: _sectionSpacing),
            derivedSection,
          ],
        );
      },
    );
  }

  Widget _buildDerivedValuesSection(
    HeroSheet hero,
    HeroState state,
    DerivedStats derived,
    HeroComputedSnapshot snapshot,
    HeroResourceActivation resourceActivation,
  ) {
    final parsed = parseModifierTextsForHero(hero);
    final namedStatMods = aggregateNamedStatModifiers(hero.statModifiers);
    final totalMods =
        hero.persistentMods +
        namedStatMods +
        parsed.statMods +
        state.tempMods +
        snapshot.inventoryStatMods;
    final debugModus = ref.read(debugModusProvider);
    final entries = <_DerivedRow>[
      _DerivedRow(
        label: 'LeP',
        variableName: 'maxLep',
        statKey: 'lep',
        current: derived.maxLep,
        modifier: totalMods.lep + _cappedLevel(hero.level),
        bought: hero.bought.lep,
        boughtKey: 'b_lep',
      ),
      _DerivedRow(
        label: 'Au',
        variableName: 'maxAu',
        statKey: 'au',
        current: derived.maxAu,
        modifier: totalMods.au + hero.level * 2,
        bought: hero.bought.au,
        boughtKey: 'b_au',
      ),
      if (resourceActivation.magic.isEnabled)
        _DerivedRow(
          label: 'AsP',
          variableName: 'maxAsp',
          statKey: 'asp',
          current: derived.maxAsp,
          modifier: totalMods.asp + hero.level * 2,
          bought: hero.bought.asp,
          boughtKey: 'b_asp',
        ),
      if (resourceActivation.divine.isEnabled)
        _DerivedRow(
          label: 'KaP',
          variableName: 'maxKap',
          statKey: 'kap',
          current: derived.maxKap,
          modifier: totalMods.kap,
          bought: hero.bought.kap,
          boughtKey: 'b_kap',
        ),
      _DerivedRow(
        label: 'MR',
        variableName: 'mr',
        statKey: 'mr',
        current: derived.mr,
        modifier: totalMods.mr,
        bought: hero.bought.mr,
        boughtKey: 'b_mr',
      ),
      _DerivedRow(
        label: 'Ini-Basis',
        variableName: 'iniBase',
        statKey: 'iniBase',
        current: derived.iniBase,
        modifier: totalMods.iniBase,
      ),
      _DerivedRow(
        label: 'AT-Basis',
        variableName: 'atBase',
        statKey: 'at',
        current: derived.atBase,
        modifier: totalMods.at,
      ),
      _DerivedRow(
        label: 'PA-Basis',
        variableName: 'paBase',
        statKey: 'pa',
        current: derived.paBase,
        modifier: totalMods.pa,
      ),
      _DerivedRow(
        label: 'FK-Basis',
        variableName: 'fkBase',
        statKey: 'fk',
        current: derived.fkBase,
        modifier: totalMods.fk,
      ),
      _DerivedRow(
        label: 'GS',
        variableName: 'gs',
        statKey: 'gs',
        current: derived.gs,
        modifier: totalMods.gs,
      ),
    ];

    return _SectionCard(
      title: 'Basiswerte',
      titleAction: IconButton(
        key: const ValueKey<String>('overview-resource-settings-open'),
        tooltip: 'Ressourcen-Einstellungen',
        onPressed: () => _openResourceActivationDialog(hero),
        icon: const Icon(Icons.settings_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: adaptiveTableMinWidth(_derivedValueColumnSpecs),
              ),
              child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: buildAdaptiveTableColumnWidths(
                  _derivedValueColumnSpecs,
                ),
                children: [
                  TableRow(
                    children: [
                      _buildAttributesTableHeaderCell('Wert'),
                      _buildAttributesTableHeaderCell('Start'),
                      _buildAttributesTableHeaderCell('Modifikator'),
                      _buildAttributesTableHeaderCell('Aktuell'),
                      _buildAttributesTableHeaderCell('Zugekauft'),
                    ],
                  ),
                  ...entries.map(
                    (entry) => TableRow(
                      children: [
                        _buildAttributesTableLabelCell(
                          debugModus ? entry.variableName : entry.label,
                        ),
                        _buildDerivedValueCell(
                          value:
                              (entry.current -
                                      entry.modifier -
                                      (entry.bought ?? 0))
                                  .toString(),
                        ),
                        _buildTappableStatModifierCell(
                          entry,
                          hero,
                          state,
                          snapshot,
                        ),
                        _buildDerivedValueCell(value: entry.current.toString()),
                        _buildDerivedBoughtCell(
                          entry,
                          onRaise:
                              _canUseSteigerungsDialog &&
                                  entry.boughtKey != null &&
                                  kGrundwertKomplexitaeten.containsKey(
                                    entry.boughtKey!.replaceFirst('b_', ''),
                                  )
                              ? () => _steigeGrundwert(
                                  entry.boughtKey!.replaceFirst('b_', ''),
                                )
                              : null,
                          raiseTooltip: entry.boughtKey == null
                              ? null
                              : '${entry.label} steigern',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResourceActivationDialog(HeroSheet hero) async {
    await showAdaptiveDetailSheet<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final resourceActivation = _buildCurrentResourceActivation(hero);
            return AlertDialog(
              key: const ValueKey<String>('overview-resource-settings-dialog'),
              title: const Text('Ressourcen-Einstellungen'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResourceActivationRow(
                      label: 'Magie',
                      keySuffix: 'magic',
                      activation: resourceActivation.magic,
                      onChanged: (value) {
                        _setMagicEnabledOverride(value);
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildResourceActivationRow(
                      label: 'Göttliches',
                      keySuffix: 'divine',
                      activation: resourceActivation.divine,
                      onChanged: (value) {
                        _setDivineEnabledOverride(value);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey<String>(
                    'overview-resource-settings-close',
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Schließen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResourceActivationRow({
    required String label,
    required String keySuffix,
    required ResourceActivationStatus activation,
    required ValueChanged<bool?> onChanged,
  }) {
    final statusText = activation.isEnabled ? 'aktiviert' : 'deaktiviert';
    final sourceText = activation.hasManualOverride ? 'manuell' : 'automatisch';
    if (!_editController.isEditing) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '$label: $statusText ($sourceText)',
              key: ValueKey<String>('overview-resource-status-$keySuffix'),
            ),
          ),
        ],
      );
    }

    return Row(
      key: ValueKey<String>('overview-resource-row-$keySuffix'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                'Standard: ${activation.autoEnabled ? 'aktiviert' : 'deaktiviert'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Switch.adaptive(
          key: ValueKey<String>('overview-resource-toggle-$keySuffix'),
          value: activation.isEnabled,
          onChanged: (value) => onChanged(value),
        ),
        if (activation.hasManualOverride) ...[
          const SizedBox(width: 8),
          TextButton(
            key: ValueKey<String>('overview-resource-reset-$keySuffix'),
            onPressed: () => onChanged(null),
            child: const Text('Standard'),
          ),
        ],
      ],
    );
  }

  Widget _buildAttributesSection(
    Attributes effectiveStartAttributes,
    Attributes attributeMaximums,
    Attributes effectiveAttributes,
    HeroComputedSnapshot snapshot,
  ) {
    final attrDebugModus = ref.read(debugModusProvider);
    final rows = _HeroOverviewTabState._attributeEntries
        .map((entry) {
          final key = entry.$2;
          final startValue = _valueByKey(effectiveStartAttributes, key);
          final maximumValue = _valueByKey(attributeMaximums, key);
          final effective = _effectiveValueByKey(effectiveAttributes, key);
          return TableRow(
            children: [
              _buildAttributesTableLabelCell(
                attrDebugModus ? entry.$2 : entry.$1,
              ),
              _buildAttributesComputedCell(
                keyName: '${key}_start',
                value: startValue.toString(),
              ),
              _buildAttributesComputedCell(
                keyName: '${key}_max',
                value: maximumValue.toString(),
              ),
              _buildAttributesNumericCell(
                keyName: key,
                isAdjustable: true,
                onRaise: _canUseSteigerungsDialog
                    ? () => _steigeEigenschaft(parseAttributeCode(key)!)
                    : null,
                raiseTooltip: '${entry.$1} steigern',
              ),
              _buildTappableAttributeComputedCell(
                label: entry.$1,
                attrKey: key,
                effective: effective,
                snapshot: snapshot,
              ),
            ],
          );
        })
        .toList(growable: false);

    return _SectionCard(
      title: 'Eigenschaften',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: adaptiveTableMinWidth(_attributeColumnSpecs),
          ),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: buildAdaptiveTableColumnWidths(_attributeColumnSpecs),
            children: [
              TableRow(
                children: [
                  _buildAttributesTableHeaderCell('Eigenschaft'),
                  _buildAttributesTableHeaderCell('Start'),
                  _buildAttributesTableHeaderCell('Max'),
                  _buildAttributesTableHeaderCell('Wert'),
                  _buildAttributesTableHeaderCell('Aktuell'),
                ],
              ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributesTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  Widget _buildAttributesTableLabelCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _buildAttributesNumericCell({
    required String keyName,
    required bool isAdjustable,
    VoidCallback? onRaise,
    String? raiseTooltip,
  }) {
    if (!isAdjustable) {
      return _buildAttributesStaticCell(
        key: ValueKey<String>('overview-field-$keyName'),
        value: _field(keyName).text,
      );
    }

    // Regulaere Eigenschaftsfelder: View-Modus = Plain Text.
    final isEditing = _editController.isEditing;
    return EditAwareTableCell(
      key: ValueKey<String>('overview-field-$keyName'),
      value: _field(keyName).text,
      isEditing: isEditing,
      controller: _field(keyName),
      keyboardType: TextInputType.number,
      onChanged: isEditing ? _onFieldChanged : null,
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      suffixIcon: onRaise == null
          ? null
          : IconButton(
              key: ValueKey<String>('overview-raise-$keyName'),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: raiseTooltip ?? 'Steigern',
              onPressed: onRaise,
              icon: const Icon(Icons.trending_up),
            ),
      suffixIconConstraints: onRaise == null
          ? null
          : const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildAttributesComputedCell({
    required String keyName,
    required String value,
  }) {
    return _buildAttributesStaticCell(
      key: ValueKey<String>('overview-effective-$keyName'),
      value: value,
    );
  }

  Widget _buildAttributesStaticCell({required String value, Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _buildDerivedValueCell({required String value}) {
    return _buildAttributesStaticCell(value: value);
  }

  Widget _buildDerivedBoughtCell(
    _DerivedRow entry, {
    VoidCallback? onRaise,
    String? raiseTooltip,
  }) {
    final keyName = entry.boughtKey;
    if (keyName == null) {
      return _buildDerivedValueCell(value: '-');
    }
    final isEditing = _editController.isEditing;
    return EditAwareTableCell(
      key: ValueKey<String>('overview-derived-bought-$keyName'),
      value: _field(keyName).text,
      isEditing: isEditing,
      controller: _field(keyName),
      keyboardType: TextInputType.number,
      onChanged: isEditing ? _onFieldChanged : null,
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      suffixIcon: onRaise == null
          ? null
          : IconButton(
              key: ValueKey<String>('overview-derived-raise-$keyName'),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: raiseTooltip ?? 'Steigern',
              onPressed: onRaise,
              icon: const Icon(Icons.trending_up),
            ),
      suffixIconConstraints: onRaise == null
          ? null
          : const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  int _cappedLevel(int level) {
    if (level < 0) {
      return 0;
    }
    if (level > 21) {
      return 21;
    }
    return level;
  }

  // ---------------------------------------------------------------------------
  // Tappbare Modifier-Zellen
  // ---------------------------------------------------------------------------

  Widget _buildTappableStatModifierCell(
    _DerivedRow entry,
    HeroSheet hero,
    HeroState state,
    HeroComputedSnapshot snapshot,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openStatModifierDialog(entry, hero, state, snapshot),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.modifier.toString(), style: theme.textTheme.bodyMedium),
            const SizedBox(width: 4),
            Icon(
              Icons.tune,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTappableAttributeComputedCell({
    required String label,
    required String attrKey,
    required int effective,
    required HeroComputedSnapshot snapshot,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openAttributeModifierDialog(
        label: label,
        attrKey: attrKey,
        effective: effective,
        snapshot: snapshot,
      ),
      child: Padding(
        key: ValueKey<String>('overview-effective-$attrKey'),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(effective.toString(), style: theme.textTheme.bodyMedium),
            const SizedBox(width: 4),
            Icon(
              Icons.tune,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStatModifierDialog(
    _DerivedRow entry,
    HeroSheet hero,
    HeroState state,
    HeroComputedSnapshot snapshot,
  ) async {
    final breakdown = computeModifierSourceBreakdown(hero);
    final statKey = entry.statKey;
    final namedMods = hero.statModifiers[statKey] ?? const [];

    // Level-basierte Boni.
    int levelBonus = 0;
    if (statKey == 'lep') {
      levelBonus = _cappedLevel(hero.level);
    } else if (statKey == 'au' || statKey == 'asp') {
      levelBonus = hero.level * 2;
    }

    final sources = <ModifierSourceEntry>[
      (label: 'Rasse', value: statModValue(breakdown.rasseStatMods, statKey)),
      (label: 'Kultur', value: statModValue(breakdown.kulturStatMods, statKey)),
      (
        label: 'Profession',
        value: statModValue(breakdown.professionStatMods, statKey),
      ),
      (
        label: 'Vorteile',
        value: statModValue(breakdown.vorteileStatMods, statKey),
      ),
      (
        label: 'Nachteile',
        value: statModValue(breakdown.nachteileStatMods, statKey),
      ),
      (label: 'Temporaer', value: statModValue(state.tempMods, statKey)),
      if (levelBonus != 0) (label: 'Level', value: levelBonus),
      (
        label: 'Inventar',
        value: statModValue(snapshot.inventoryStatMods, statKey),
      ),
    ];

    final result = await showStatModifierDetailDialog(
      context: context,
      statLabel: entry.label,
      namedModifiers: namedMods,
      parsedSources: sources,
      total: entry.modifier,
    );
    if (result == null || !mounted) {
      return;
    }
    final updatedMap = Map<String, List<HeroTalentModifier>>.from(
      hero.statModifiers,
    );
    if (result.isEmpty) {
      updatedMap.remove(statKey);
    } else {
      updatedMap[statKey] = result;
    }
    final updatedHero = hero.copyWith(statModifiers: updatedMap);
    await ref.read(heroActionsProvider).saveHero(updatedHero);
  }

  Future<void> _openAttributeModifierDialog({
    required String label,
    required String attrKey,
    required int effective,
    required HeroComputedSnapshot snapshot,
  }) async {
    final hero = snapshot.hero;
    final state = snapshot.state;
    final breakdown = computeModifierSourceBreakdown(hero);
    final namedMods = hero.attributeModifiers[attrKey] ?? const [];
    final baseValue = _valueByKey(hero.attributes, attrKey);

    final tempValue = attributeModValue(state.tempAttributeMods, attrKey);
    final sources = <ModifierSourceEntry>[
      (
        label: 'Rasse',
        value: attributeModValue(breakdown.rasseAttributeMods, attrKey),
      ),
      (
        label: 'Kultur',
        value: attributeModValue(breakdown.kulturAttributeMods, attrKey),
      ),
      (
        label: 'Profession',
        value: attributeModValue(breakdown.professionAttributeMods, attrKey),
      ),
      (
        label: 'Vorteile',
        value: attributeModValue(breakdown.vorteileAttributeMods, attrKey),
      ),
      (
        label: 'Nachteile',
        value: attributeModValue(breakdown.nachteileAttributeMods, attrKey),
      ),
      if (tempValue != 0) (label: 'Attributo', value: tempValue),
      (
        label: 'Inventar',
        value: attributeModValue(snapshot.inventoryAttributeMods, attrKey),
      ),
    ];

    final result = await showAttributeModifierDetailDialog(
      context: context,
      attributeLabel: label,
      baseValue: baseValue,
      namedModifiers: namedMods,
      parsedSources: sources,
      effectiveValue: effective,
    );
    if (result == null || !mounted) {
      return;
    }
    final updatedMap = Map<String, List<HeroTalentModifier>>.from(
      hero.attributeModifiers,
    );
    if (result.isEmpty) {
      updatedMap.remove(attrKey);
    } else {
      updatedMap[attrKey] = result;
    }
    final updatedHero = hero.copyWith(attributeModifiers: updatedMap);
    await ref.read(heroActionsProvider).saveHero(updatedHero);
  }

  int _effectiveValueByKey(Attributes effective, String key) {
    return _valueByKey(effective, key);
  }

  int _valueByKey(Attributes attributes, String key) {
    switch (key) {
      case 'mu':
        return attributes.mu;
      case 'kl':
        return attributes.kl;
      case 'inn':
        return attributes.inn;
      case 'ch':
        return attributes.ch;
      case 'ff':
        return attributes.ff;
      case 'ge':
        return attributes.ge;
      case 'ko':
        return attributes.ko;
      case 'kk':
        return attributes.kk;
      default:
        return 0;
    }
  }
}
