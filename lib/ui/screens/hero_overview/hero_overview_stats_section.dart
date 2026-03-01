part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewStatsSection on _HeroOverviewTabState {
  Widget _buildCombinedStatsAndAttributesSection(
    HeroSheet hero,
    HeroState state,
    DerivedStats derived,
    Attributes effectiveAttributes,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final derivedSection = _buildDerivedValuesSection(hero, state, derived);
        final attributesSection = _buildAttributesSection(effectiveAttributes);
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
    final entries = <_DerivedRow>[
      _DerivedRow(
        label: 'LeP',
        current: derived.maxLep,
        modifier: totalMods.lep + _cappedLevel(hero.level),
        bought: hero.bought.lep,
        boughtKey: 'b_lep',
      ),
      _DerivedRow(
        label: 'Au',
        current: derived.maxAu,
        modifier: totalMods.au + hero.level * 2,
        bought: hero.bought.au,
        boughtKey: 'b_au',
      ),
      _DerivedRow(
        label: 'AsP',
        current: derived.maxAsp,
        modifier: totalMods.asp + hero.level * 2,
        bought: hero.bought.asp,
        boughtKey: 'b_asp',
      ),
      _DerivedRow(
        label: 'KaP',
        current: derived.maxKap,
        modifier: totalMods.kap,
        bought: hero.bought.kap,
        boughtKey: 'b_kap',
      ),
      _DerivedRow(
        label: 'MR',
        current: derived.mr,
        modifier: totalMods.mr,
        bought: hero.bought.mr,
        boughtKey: 'b_mr',
      ),
      _DerivedRow(
        label: 'Ini-Basis',
        current: derived.iniBase,
        modifier: totalMods.iniBase,
      ),
      _DerivedRow(
        label: 'AT-Basis',
        current: derived.atBase,
        modifier: totalMods.at,
      ),
      _DerivedRow(
        label: 'PA-Basis',
        current: derived.paBase,
        modifier: totalMods.pa,
      ),
      _DerivedRow(
        label: 'FK-Basis',
        current: derived.fkBase,
        modifier: totalMods.fk,
      ),
      _DerivedRow(label: 'GS', current: derived.gs, modifier: totalMods.gs),
    ];

    return _SectionCard(
      title: 'Basiswerte',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 560),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: FixedColumnWidth(112),
              1: FixedColumnWidth(_attributeValueCellWidth),
              2: FixedColumnWidth(_attributeValueCellWidth),
              3: FixedColumnWidth(_attributeValueCellWidth),
              4: FixedColumnWidth(_attributeValueCellWidth),
            },
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
                    _buildAttributesTableLabelCell(entry.label),
                    _buildDerivedValueCell(
                      value:
                          (entry.current - entry.modifier - (entry.bought ?? 0))
                              .toString(),
                    ),
                    _buildDerivedValueCell(value: entry.modifier.toString()),
                    _buildDerivedValueCell(value: entry.current.toString()),
                    _buildDerivedBoughtCell(entry),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributesSection(Attributes effectiveAttributes) {
    final rows = _HeroOverviewTabState._attributeEntries
        .map((entry) {
          final key = entry.$2;
          final startKey = '${key}_start';
          final tempKey = '${key}_temp';
          final effective = _effectiveValueByKey(effectiveAttributes, key);
          return TableRow(
            children: [
              _buildAttributesTableLabelCell(entry.$1),
              _buildAttributesNumericCell(
                keyName: startKey,
                isAdjustable: false,
              ),
              _buildAttributesNumericCell(keyName: key, isAdjustable: true),
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
          constraints: const BoxConstraints(minWidth: 520),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: FixedColumnWidth(96),
              1: FixedColumnWidth(_attributeValueCellWidth),
              2: FixedColumnWidth(_attributeValueCellWidth),
              3: FixedColumnWidth(_attributeValueCellWidth),
              4: FixedColumnWidth(_attributeValueCellWidth),
            },
            children: [
              TableRow(
                children: [
                  _buildAttributesTableHeaderCell('Eigenschaft'),
                  _buildAttributesTableHeaderCell('Start'),
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
  }) {
    if (!isAdjustable) {
      return _buildAttributesStaticCell(
        key: ValueKey<String>('overview-field-$keyName'),
        value: _field(keyName).text,
      );
    }

    final isReadOnly = !_editController.isEditing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: SizedBox(
        width: _attributeValueCellWidth,
        child: TextField(
          key: ValueKey<String>('overview-field-$keyName'),
          controller: _field(keyName),
          readOnly: isReadOnly,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('').copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          onChanged: isReadOnly ? null : _onFieldChanged,
        ),
      ),
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
      child: SizedBox(
        width: _attributeValueCellWidth,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }

  Widget _buildDerivedValueCell({required String value}) {
    return _buildAttributesStaticCell(value: value);
  }

  Widget _buildDerivedBoughtCell(_DerivedRow entry) {
    final keyName = entry.boughtKey;
    if (keyName == null) {
      return _buildDerivedValueCell(value: '-');
    }
    final isReadOnly = !_editController.isEditing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: SizedBox(
        width: _attributeValueCellWidth,
        child: TextField(
          key: ValueKey<String>('overview-derived-bought-$keyName'),
          controller: _field(keyName),
          readOnly: isReadOnly,
          keyboardType: TextInputType.number,
          decoration: _inputDecoration('').copyWith(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
          ),
          onChanged: isReadOnly ? null : _onFieldChanged,
        ),
      ),
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
    switch (key) {
      case 'mu':
        return effective.mu;
      case 'kl':
        return effective.kl;
      case 'inn':
        return effective.inn;
      case 'ch':
        return effective.ch;
      case 'ff':
        return effective.ff;
      case 'ge':
        return effective.ge;
      case 'ko':
        return effective.ko;
      case 'kk':
        return effective.kk;
      default:
        return 0;
    }
  }
}
