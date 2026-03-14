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
        AdaptiveTableColumnSpec(minWidth: 86, maxWidth: 132),
      ];

  Widget _buildCombinedStatsAndAttributesSection(
    HeroSheet hero,
    HeroState state,
    DerivedStats derived,
    Attributes effectiveStartAttributes,
    Attributes attributeMaximums,
    Attributes effectiveAttributes,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final derivedSection = _buildDerivedValuesSection(hero, state, derived);
        final attributesSection = _buildAttributesSection(
          effectiveStartAttributes,
          attributeMaximums,
          effectiveAttributes,
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
  ) {
    final parsed = parseModifierTextsForHero(hero);
    final totalMods = hero.persistentMods + parsed.statMods + state.tempMods;
    final debugModus = ref.read(debugModusProvider);
    final entries = <_DerivedRow>[
      _DerivedRow(
        label: 'LeP',
        variableName: 'maxLep',
        current: derived.maxLep,
        modifier: totalMods.lep + _cappedLevel(hero.level),
        bought: hero.bought.lep,
        boughtKey: 'b_lep',
      ),
      _DerivedRow(
        label: 'Au',
        variableName: 'maxAu',
        current: derived.maxAu,
        modifier: totalMods.au + hero.level * 2,
        bought: hero.bought.au,
        boughtKey: 'b_au',
      ),
      _DerivedRow(
        label: 'AsP',
        variableName: 'maxAsp',
        current: derived.maxAsp,
        modifier: totalMods.asp + hero.level * 2,
        bought: hero.bought.asp,
        boughtKey: 'b_asp',
      ),
      _DerivedRow(
        label: 'KaP',
        variableName: 'maxKap',
        current: derived.maxKap,
        modifier: totalMods.kap,
        bought: hero.bought.kap,
        boughtKey: 'b_kap',
      ),
      _DerivedRow(
        label: 'MR',
        variableName: 'mr',
        current: derived.mr,
        modifier: totalMods.mr,
        bought: hero.bought.mr,
        boughtKey: 'b_mr',
      ),
      _DerivedRow(
        label: 'Ini-Basis',
        variableName: 'iniBase',
        current: derived.iniBase,
        modifier: totalMods.iniBase,
      ),
      _DerivedRow(
        label: 'AT-Basis',
        variableName: 'atBase',
        current: derived.atBase,
        modifier: totalMods.at,
      ),
      _DerivedRow(
        label: 'PA-Basis',
        variableName: 'paBase',
        current: derived.paBase,
        modifier: totalMods.pa,
      ),
      _DerivedRow(
        label: 'FK-Basis',
        variableName: 'fkBase',
        current: derived.fkBase,
        modifier: totalMods.fk,
      ),
      _DerivedRow(
        label: 'GS',
        variableName: 'gs',
        current: derived.gs,
        modifier: totalMods.gs,
      ),
    ];

    return _SectionCard(
      title: 'Basiswerte',
      child: SingleChildScrollView(
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
                          (entry.current - entry.modifier - (entry.bought ?? 0))
                              .toString(),
                    ),
                    _buildDerivedValueCell(value: entry.modifier.toString()),
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
    );
  }

  Widget _buildAttributesSection(
    Attributes effectiveStartAttributes,
    Attributes attributeMaximums,
    Attributes effectiveAttributes,
  ) {
    final attrDebugModus = ref.read(debugModusProvider);
    final rows = _HeroOverviewTabState._attributeEntries
        .map((entry) {
          final key = entry.$2;
          final tempKey = '${key}_temp';
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
              _buildAttributesNumericCell(keyName: tempKey, isAdjustable: true),
              _buildAttributesComputedCell(
                keyName: key,
                value: effective.toString(),
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
                  _buildAttributesTableHeaderCell('Aktuell'),
                  _buildAttributesTableHeaderCell('Temp-Mod'),
                  _buildAttributesTableHeaderCell('Berechnet'),
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

    final isTempModifier = _isTempAttributeKey(keyName);
    final isReadOnly = isTempModifier ? false : !_editController.isEditing;
    final textField = TextField(
      key: ValueKey<String>('overview-field-$keyName'),
      controller: _field(keyName),
      focusNode: isTempModifier ? _focusNode(keyName) : null,
      readOnly: isReadOnly,
      keyboardType: TextInputType.number,
      textInputAction: isTempModifier ? TextInputAction.done : null,
      decoration: _inputDecoration('').copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      ),
      onChanged: isTempModifier
          ? (_) {
              if (mounted) {
                _viewRevision.value++;
              }
            }
          : (isReadOnly ? null : _onFieldChanged),
      onSubmitted: isTempModifier
          ? (_) => _commitTempAttributeField(keyName)
          : null,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: textField,
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
    final isReadOnly = !_editController.isEditing;
    final textField = TextField(
      key: ValueKey<String>('overview-derived-bought-$keyName'),
      controller: _field(keyName),
      readOnly: isReadOnly,
      keyboardType: TextInputType.number,
      decoration: _inputDecoration('').copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      ),
      onChanged: isReadOnly ? null : _onFieldChanged,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: textField,
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
