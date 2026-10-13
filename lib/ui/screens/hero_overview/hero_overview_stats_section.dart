part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewStatsSection on _HeroOverviewTabState {
  static const AdaptiveTableColumnSpec _startColumnSpec =
      AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120, flex: 1);

  // Hinweis: Die Spalten brauchen `flex`, damit `ResponsiveAdaptiveTable` die
  // verfuegbare Breite verteilt (es nutzt feste Spaltenbreiten, keine
  // IntrinsicColumnWidth). Interaktive Zellen mit Icon-Buttons (Modifikator,
  // Summe, Zugekauft, Wert) bekommen eine Mindestbreite, die ihre Inhalte
  // sicher aufnimmt; sonst laeuft die Zelle in der Tabellenansicht ueber.
  static const List<AdaptiveTableColumnSpec>
  _derivedValueColumnSpecsBase = <AdaptiveTableColumnSpec>[
    AdaptiveTableColumnSpec(
      minWidth: 96,
      maxWidth: 150,
      flex: 2,
    ), // Wert (LeP, AsP, …)
    AdaptiveTableColumnSpec(
      minWidth: 92,
      maxWidth: 132,
      flex: 1,
    ), // Modifikator
    AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120, flex: 1), // Summe
    AdaptiveTableColumnSpec(minWidth: 92, maxWidth: 130, flex: 1), // Zugekauft
  ];

  static const List<AdaptiveTableColumnSpec>
  _attributeColumnSpecsBase = <AdaptiveTableColumnSpec>[
    AdaptiveTableColumnSpec(
      minWidth: 96,
      maxWidth: 170,
      flex: 2,
    ), // Eigenschaft
    AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 120, flex: 1), // Max
    AdaptiveTableColumnSpec(minWidth: 88, maxWidth: 130, flex: 1), // Wert
    AdaptiveTableColumnSpec(minWidth: 112, maxWidth: 160, flex: 1), // Aktuell
  ];

  List<AdaptiveTableColumnSpec> _derivedValueColumnSpecs({
    required bool showStart,
  }) {
    if (!showStart) {
      return _derivedValueColumnSpecsBase;
    }
    return <AdaptiveTableColumnSpec>[
      _derivedValueColumnSpecsBase[0], // Wert
      _startColumnSpec, // Start
      ..._derivedValueColumnSpecsBase.sublist(1),
    ];
  }

  List<AdaptiveTableColumnSpec> _attributeColumnSpecs({
    required bool showStart,
  }) {
    if (!showStart) {
      return _attributeColumnSpecsBase;
    }
    return <AdaptiveTableColumnSpec>[
      _attributeColumnSpecsBase[0], // Eigenschaft
      _startColumnSpec, // Start
      ..._attributeColumnSpecsBase.sublist(1),
    ];
  }

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
    final debugModus = ref.read(debugModusProvider);
    // Start, Modifikator und Zukauf liest die Tabelle aus der Herleitung des
    // Regelmoduls (ARCH-04); sie rechnet nichts selbst nach.
    _DerivedRow zeile(
      String label,
      String variableName,
      String statKey,
      int current, {
      int? bought,
      String? boughtKey,
    }) {
      final herleitung = derived.herleitungen?.fuer(statKey);
      final start = herleitung?.summeVon(HerleitungsArt.grundwert) ?? current;
      final zukauf = herleitung?.summeVon(HerleitungsArt.zukauf) ?? 0;
      return _DerivedRow(
        label: label,
        variableName: variableName,
        statKey: statKey,
        current: current,
        start: start,
        modifier: current - start - zukauf,
        bought: bought,
        boughtKey: boughtKey,
        herleitung: herleitung,
      );
    }

    final entries = <_DerivedRow>[
      zeile(
        'LeP',
        'maxLep',
        'lep',
        derived.maxLep,
        bought: hero.bought.lep,
        boughtKey: 'b_lep',
      ),
      zeile(
        'Au',
        'maxAu',
        'au',
        derived.maxAu,
        bought: hero.bought.au,
        boughtKey: 'b_au',
      ),
      if (resourceActivation.magic.isEnabled)
        zeile(
          'AsP',
          'maxAsp',
          'asp',
          derived.maxAsp,
          bought: hero.bought.asp,
          boughtKey: 'b_asp',
        ),
      if (resourceActivation.divine.isEnabled)
        zeile(
          'KaP',
          'maxKap',
          'kap',
          derived.maxKap,
          bought: hero.bought.kap,
          boughtKey: 'b_kap',
        ),
      zeile(
        'MR',
        'mr',
        'mr',
        derived.mr,
        bought: hero.bought.mr,
        boughtKey: 'b_mr',
      ),
      zeile('Ini-Basis', 'iniBase', 'iniBase', derived.iniBase),
      zeile('AT-Basis', 'atBase', 'at', derived.atBase),
      zeile('PA-Basis', 'paBase', 'pa', derived.paBase),
      zeile('FK-Basis', 'fkBase', 'fk', derived.fkBase),
      zeile('GS', 'gs', 'gs', derived.gs),
    ];

    final showStart = _editController.isEditing;
    final columnSpecs = _derivedValueColumnSpecs(showStart: showStart);

    return _SectionCard(
      title: 'Basiswerte',
      titleAction: IconButton(
        key: const ValueKey<String>('overview-resource-settings-open'),
        tooltip: 'Ressourcen-Einstellungen',
        onPressed: () => _openResourceActivationDialog(hero),
        icon: const Icon(Icons.settings_outlined),
      ),
      child: ResponsiveAdaptiveTable<_DerivedRow>(
        columnSpecs: columnSpecs,
        items: entries,
        headerRow: TableRow(
          children: [
            _buildAttributesTableHeaderCell('Wert'),
            if (showStart) _buildAttributesTableHeaderCell('Start'),
            _buildAttributesTableHeaderCell('Modifikator'),
            _buildAttributesTableHeaderCell('Summe'),
            _buildAttributesTableHeaderCell('Zugekauft'),
          ],
        ),
        tableRowBuilder: (entry) => TableRow(
          children: [
            _buildAttributesTableLabelCell(
              debugModus ? entry.variableName : entry.label,
              '',
              false,
            ),
            if (showStart)
              _buildDerivedValueCell(value: entry.start.toString()),
            _buildTappableStatModifierCell(entry, hero, state, snapshot),
            _buildDerivedValueCell(value: entry.current.toString()),
            _buildDerivedBoughtCell(entry),
          ],
        ),
        cardBuilder: (cardContext, entry) => _buildDerivedValueMobileCard(
          entry: entry,
          hero: hero,
          state: state,
          snapshot: snapshot,
          showStart: showStart,
          debugModus: debugModus,
        ),
        ansicht: _tabellenAnsicht,
      ),
    );
  }

  Future<void> _openResourceActivationDialog(HeroSheet hero) async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
    var dialogMagicEnabledOverride = _editController.isEditing
        ? _draftMagicEnabledOverride
        : hero.resourceActivationConfig.magicEnabledOverride;
    var dialogDivineEnabledOverride = _editController.isEditing
        ? _draftDivineEnabledOverride
        : hero.resourceActivationConfig.divineEnabledOverride;
    // Gespeichert wird nur, was im Dialog umgestellt wurde (ARCH-05).
    final magieVorher = dialogMagicEnabledOverride;
    final goettlichVorher = dialogDivineEnabledOverride;

    await showAdaptiveDetailSheet<void>(
      context: context,
      // Speicherfehler erscheinen im Blatt; eine Snackbar läge dahinter.
      builder: (_) => ZustandFehlerBereich(
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final resourceActivation = _buildResourceActivationForOverrides(
              hero,
              magicEnabledOverride: dialogMagicEnabledOverride,
              divineEnabledOverride: dialogDivineEnabledOverride,
            );
            return AlertDialog(
              key: const ValueKey<String>('overview-resource-settings-dialog'),
              title: const Text('Ressourcen-Einstellungen'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ZustandFehlerAnzeige(),
                    _buildResourceActivationRow(
                      label: 'Magie',
                      keySuffix: 'magic',
                      activation: resourceActivation.magic,
                      onChanged: (value) => setDialogState(() {
                        dialogMagicEnabledOverride = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    _buildResourceActivationRow(
                      label: 'Göttliches',
                      keySuffix: 'divine',
                      activation: resourceActivation.divine,
                      onChanged: (value) => setDialogState(() {
                        dialogDivineEnabledOverride = value;
                      }),
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
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  key: const ValueKey<String>(
                    'overview-resource-settings-save',
                  ),
                  onPressed: () async {
                    if (_editController.isEditing) {
                      _applyDraftResourceActivationOverrides(
                        magicEnabledOverride: dialogMagicEnabledOverride,
                        divineEnabledOverride: dialogDivineEnabledOverride,
                      );
                    } else {
                      final gespeichert =
                          await _saveResourceActivationOverrides(
                            meldeKontext: dialogContext,
                            magieVorher: magieVorher,
                            goettlichVorher: goettlichVorher,
                            magicEnabledOverride: dialogMagicEnabledOverride,
                            divineEnabledOverride: dialogDivineEnabledOverride,
                          );
                      if (!gespeichert) {
                        return;
                      }
                    }
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        ),
      ),
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
    return Row(
      key: ValueKey<String>('overview-resource-row-$keySuffix'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                'Aktuell: $statusText ($sourceText)',
                key: ValueKey<String>('overview-resource-status-$keySuffix'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
    final showStart = _editController.isEditing;
    final columnSpecs = _attributeColumnSpecs(showStart: showStart);

    return _SectionCard(
      title: 'Eigenschaften',
      child: ResponsiveAdaptiveTable<(String, String)>(
        columnSpecs: columnSpecs,
        items: _HeroOverviewTabState._attributeEntries,
        headerRow: TableRow(
          children: [
            _buildAttributesTableHeaderCell('Eigenschaft'),
            if (showStart) _buildAttributesTableHeaderCell('Start'),
            _buildAttributesTableHeaderCell('Max'),
            _buildAttributesTableHeaderCell('Wert'),
            _buildAttributesTableHeaderCell('Aktuell'),
          ],
        ),
        tableRowBuilder: (entry) => _buildAttributeTableRow(
          entry,
          effectiveStartAttributes: effectiveStartAttributes,
          attributeMaximums: attributeMaximums,
          effectiveAttributes: effectiveAttributes,
          snapshot: snapshot,
          showStart: showStart,
          attrDebugModus: attrDebugModus,
        ),
        cardBuilder: (cardContext, entry) => _buildAttributeMobileCard(
          entry,
          effectiveStartAttributes: effectiveStartAttributes,
          attributeMaximums: attributeMaximums,
          effectiveAttributes: effectiveAttributes,
          snapshot: snapshot,
          showStart: showStart,
          attrDebugModus: attrDebugModus,
        ),
        ansicht: _tabellenAnsicht,
      ),
    );
  }

  TableRow _buildAttributeTableRow(
    (String, String) entry, {
    required Attributes effectiveStartAttributes,
    required Attributes attributeMaximums,
    required Attributes effectiveAttributes,
    required HeroComputedSnapshot snapshot,
    required bool showStart,
    required bool attrDebugModus,
  }) {
    final key = entry.$2;
    final startValue = _valueByKey(effectiveStartAttributes, key);
    final maximumValue = _valueByKey(attributeMaximums, key);
    final epicBonusVal = _attrBonusValue(
      snapshot.hero.epicAttributeMaxBonus,
      key,
    );
    final effective = _effectiveValueByKey(effectiveAttributes, key);
    return TableRow(
      children: [
        _buildAttributesTableLabelCell(
          attrDebugModus ? entry.$2 : entry.$1,
          key,
          _attrBonusValue(snapshot.hero.epicMainAttributes, key) > 0,
        ),
        if (showStart)
          _buildAttributesComputedCell(
            keyName: '${key}_start',
            value: startValue.toString(),
          ),
        _buildAttributesComputedCell(
          keyName: '${key}_max',
          value: epicBonusVal > 0
              ? '${maximumValue - epicBonusVal}+$epicBonusVal'
              : maximumValue.toString(),
        ),
        _buildAttributesNumericCell(keyName: key, isAdjustable: true),
        _buildTappableAttributeComputedCell(
          label: entry.$1,
          attrKey: key,
          effective: effective,
          snapshot: snapshot,
        ),
      ],
    );
  }

  /// Kartenansicht eines Eigenschaften-Eintrags fuer schmale Bildschirme.
  Widget _buildAttributeMobileCard(
    (String, String) entry, {
    required Attributes effectiveStartAttributes,
    required Attributes attributeMaximums,
    required Attributes effectiveAttributes,
    required HeroComputedSnapshot snapshot,
    required bool showStart,
    required bool attrDebugModus,
  }) {
    final key = entry.$2;
    final startValue = _valueByKey(effectiveStartAttributes, key);
    final maximumValue = _valueByKey(attributeMaximums, key);
    final epicBonusVal = _attrBonusValue(
      snapshot.hero.epicAttributeMaxBonus,
      key,
    );
    final effective = _effectiveValueByKey(effectiveAttributes, key);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttributesTableLabelCell(
              attrDebugModus ? entry.$2 : entry.$1,
              key,
              _attrBonusValue(snapshot.hero.epicMainAttributes, key) > 0,
            ),
            if (showStart)
              _buildStatCardFieldRow(
                label: 'Start',
                value: _buildAttributesComputedCell(
                  keyName: '${key}_start',
                  value: startValue.toString(),
                ),
              ),
            _buildStatCardFieldRow(
              label: 'Max',
              value: _buildAttributesComputedCell(
                keyName: '${key}_max',
                value: epicBonusVal > 0
                    ? '${maximumValue - epicBonusVal}+$epicBonusVal'
                    : maximumValue.toString(),
              ),
            ),
            _buildStatCardFieldRow(
              label: 'Wert',
              value: _buildAttributesNumericCell(
                keyName: key,
                isAdjustable: true,
              ),
            ),
            _buildStatCardFieldRow(
              label: 'Aktuell',
              value: _buildTappableAttributeComputedCell(
                label: entry.$1,
                attrKey: key,
                effective: effective,
                snapshot: snapshot,
              ),
            ),
          ],
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

  /// Baut die Label-Zelle für eine Eigenschaft.
  ///
  /// Wenn [showEpicBonus] gesetzt ist (d. h. diese Eigenschaft ist die
  /// gewählte Haupteigenschaft des epischen Helden), wird ein ⓘ-Icon
  /// angehängt, das den aktiven Bonus beim Antippen erklärt.
  Widget _buildAttributesTableLabelCell(
    String text,
    String attrKey,
    bool showEpicBonus,
  ) {
    final theme = Theme.of(context);
    if (!showEpicBonus) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        child: Text(text, style: theme.textTheme.titleSmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, style: theme.textTheme.titleSmall)),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: 'Epischer Haupteigenschafts-Bonus',
            icon: Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => _showEpicAttrBonusInfo(attrKey, text),
          ),
        ],
      ),
    );
  }

  /// Öffnet einen Dialog mit den epischen Haupteigenschafts-Boni für [attrKey].
  ///
  /// Zeigt jeden Einzelbonus mit seinem Umsetzungsgrad, damit erkennbar
  /// bleibt, welchen Wert die App bereits einrechnet.
  void _showEpicAttrBonusInfo(String attrKey, String label) {
    final code = parseAttributeCode(attrKey);
    final boni = code == null
        ? const <EpicMainAttributeBonus>[]
        : epicMainAttributeBonusesFor(code);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final dialogTheme = Theme.of(ctx);
        return AlertDialog(
          title: Text('$label – Epischer Haupteigenschafts-Bonus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final bonus in boni)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _epicBonusInfoLine(bonus),
                    style: dialogTheme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Formatiert einen Bonus samt Umsetzungs-Marker fuer den Info-Dialog.
  String _epicBonusInfoLine(EpicMainAttributeBonus bonus) {
    final marker = _epicBonusMarker(bonus.umsetzung);
    return marker == null ? '• ${bonus.text}' : '• ${bonus.text}  ($marker)';
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

  Widget _buildDerivedBoughtCell(_DerivedRow entry) {
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
    );
  }

  /// Beschriftete Zeile (Label links, Wert rechts) fuer die Kartenansicht der
  /// Basiswerte-/Eigenschaften-Tabellen auf schmalen Bildschirmen.
  Widget _buildStatCardFieldRow({
    required String label,
    required Widget value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: value),
          ),
        ],
      ),
    );
  }

  /// Kartenansicht eines Basiswert-Eintrags fuer schmale Bildschirme.
  Widget _buildDerivedValueMobileCard({
    required _DerivedRow entry,
    required HeroSheet hero,
    required HeroState state,
    required HeroComputedSnapshot snapshot,
    required bool showStart,
    required bool debugModus,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAttributesTableLabelCell(
              debugModus ? entry.variableName : entry.label,
              '',
              false,
            ),
            if (showStart)
              _buildStatCardFieldRow(
                label: 'Start',
                value: _buildDerivedValueCell(value: entry.start.toString()),
              ),
            _buildStatCardFieldRow(
              label: 'Modifikator',
              value: _buildTappableStatModifierCell(
                entry,
                hero,
                state,
                snapshot,
              ),
            ),
            _buildStatCardFieldRow(
              label: 'Summe',
              value: _buildDerivedValueCell(value: entry.current.toString()),
            ),
            _buildStatCardFieldRow(
              label: 'Zugekauft',
              value: _buildDerivedBoughtCell(entry),
            ),
          ],
        ),
      ),
    );
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
      key: ValueKey<String>('overview-stat-modifier-${entry.statKey}'),
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
            const SizedBox(width: 2),
            IconButton(
              key: ValueKey<String>('overview-roll-$attrKey'),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: '$label würfeln',
              onPressed: () => showLoggedProbeDialog(
                context: context,
                ref: ref,
                heroId: widget.heroId,
                // Wunden senken die Eigenschaft nur für den Wurf.
                request: buildAttributeProbeRequest(
                  label: label,
                  effectiveValue: _effectiveValueByKey(
                    snapshot.probenEigenschaften,
                    attrKey,
                  ),
                ),
              ),
              icon: const Icon(Icons.casino_outlined),
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
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
    final statKey = entry.statKey;
    final namedMods = hero.statModifiers[statKey] ?? const [];

    final result = await showStatModifierDetailDialog(
      context: context,
      statLabel: entry.label,
      namedModifiers: namedMods,
      total: entry.modifier,
      herleitung: entry.herleitung,
    );
    if (result == null || !mounted) {
      return;
    }
    // Frisch: nur dieser Grundwert wird ersetzt (ARCH-05).
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: '${entry.label}-Modifikatoren',
      aenderung: (held) => mitBenanntenStatModifikatoren(held, statKey, result),
    );
  }

  Future<void> _openAttributeModifierDialog({
    required String label,
    required String attrKey,
    required int effective,
    required HeroComputedSnapshot snapshot,
  }) async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
    final hero = snapshot.hero;
    final state = snapshot.state;
    final breakdown = computeModifierSourceBreakdown(
      hero,
      catalog: ref.read(rulesCatalogProvider).valueOrNull,
    );
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
    // Frisch: nur diese Eigenschaft wird ersetzt (ARCH-05).
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: '$label-Modifikatoren',
      aenderung: (held) =>
          mitBenanntenEigenschaftsModifikatoren(held, attrKey, result),
    );
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
