part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kampf-Rechner-Subtab: Aktive-Waffe-Auswahl, Detailvorschau,
/// Nebenhand-Info, Ruestungs-Vorschau, INI/Ausweichen.
extension _HeroCombatCalculatorSubtab on _HeroCombatTabState {
  Widget _buildMeleeCalculatorSubTab(
    List<TalentDef> combatTalents,
    RulesCatalog catalog,
    HeroSheet hero,
    HeroState heroState,
    CombatPreviewStats preview,
  ) {
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final armor = _draftCombatConfig.armor;
    final manual = _draftCombatConfig.manualMods;
    final sortedTalents = sortedCombatTalents(combatTalents);
    final offhandWeapon = _offhandWeaponOrNull();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final selectionCard = _buildActiveWeaponSelectionCard(
              catalog: catalog,
              combatTalents: sortedTalents,
              selectedWeaponIndex: selectedWeaponIndex,
              weaponSlots: weaponSlots,
            );
            final infoCard = _buildActiveWeaponInfoCard(
              selectedWeaponIndex: selectedWeaponIndex,
              preview: preview,
              catalog: catalog,
            );
            final offhandCard = _buildOffhandSelectionAndInfoCard(
              catalog: catalog,
              combatTalents: sortedTalents,
              mainPreview: preview,
              hero: hero,
              heroState: heroState,
              offhandWeapon: offhandWeapon,
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  selectionCard,
                  const SizedBox(height: 12),
                  infoCard,
                  const SizedBox(height: 12),
                  offhandCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: selectionCard),
                const SizedBox(width: 12),
                Expanded(child: infoCard),
                const SizedBox(width: 12),
                Expanded(child: offhandCard),
              ],
            );
          },
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final armorCard = _buildCalcArmorCard(
              armor: armor,
              preview: preview,
              catalog: catalog,
              sortedTalents: sortedTalents,
            );
            final iniAusweichenCard = _buildIniAusweichenOverviewCard(
              preview: preview,
              manualAusweichenMod: manual.ausweichenMod,
            );
            if (constraints.maxWidth < 1100) {
              return Column(
                children: [
                  armorCard,
                  const SizedBox(height: 12),
                  iniAusweichenCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: armorCard),
                const SizedBox(width: 12),
                Expanded(child: iniAusweichenCard),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActiveWeaponSelectionCard({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    required int selectedWeaponIndex,
    required List<MainWeaponSlot> weaponSlots,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Haupthand', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              key: ValueKey<String>(
                'combat-main-weapon-select-${selectedWeaponIndex < 0 ? 'none' : selectedWeaponIndex}-${weaponSlots.length}',
              ),
              initialValue: selectedWeaponIndex < 0
                  ? null
                  : selectedWeaponIndex,
              decoration: const InputDecoration(
                labelText: 'Aktive Waffe',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Keine Waffe'),
                ),
                for (var i = 0; i < weaponSlots.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      weaponSlots[i].name.trim().isEmpty
                          ? 'Waffe ${i + 1}'
                          : weaponSlots[i].name,
                    ),
                  ),
              ],
              onChanged: (value) {
                _selectWeaponIndex(
                  value,
                  catalog: catalog,
                  combatTalents: combatTalents,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffhandSelectionAndInfoCard({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    required CombatPreviewStats mainPreview,
    required HeroSheet hero,
    required HeroState heroState,
    required MainWeaponSlot? offhandWeapon,
  }) {
    final assignment = _draftCombatConfig.offhandAssignment;
    final offhandEquipment = _offhandEquipmentOrNull();
    final selectedValue = assignment.usesWeapon
        ? 'weapon:${assignment.weaponIndex}'
        : (assignment.usesEquipment
              ? 'equipment:${assignment.equipmentIndex}'
              : 'none');
    final selectedWeaponIndex = _selectedWeaponIndex();
    final offhandWeaponPreview =
        assignment.usesWeapon &&
            assignment.weaponIndex >= 0 &&
            assignment.weaponIndex < _draftCombatConfig.weaponSlots.length
        ? computeCombatPreviewStats(
            hero,
            heroState,
            overrideConfig: _draftCombatConfig.copyWith(
              selectedWeaponIndex: assignment.weaponIndex,
              mainWeapon:
                  _draftCombatConfig.weaponSlots[assignment.weaponIndex],
              offhandAssignment: const OffhandAssignment(),
              manualMods: _draftCombatConfig.manualMods.copyWith(
                iniWurf: _effectiveIniRollForConfig(_draftCombatConfig),
              ),
            ),
            overrideTalents: _draftTalents,
            catalogTalents: catalog.talents,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nebenhand', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('combat-offhand-selection'),
              initialValue: selectedValue,
              decoration: const InputDecoration(
                labelText: 'Nebenhand',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: 'none',
                  child: Text('Keine'),
                ),
                for (var i = 0; i < _draftCombatConfig.weaponSlots.length; i++)
                  if (i != selectedWeaponIndex)
                    DropdownMenuItem<String>(
                      value: 'weapon:$i',
                      child: Text(
                        'Waffe: ${_draftCombatConfig.weaponSlots[i].name.trim().isEmpty ? 'Waffe ${i + 1}' : _draftCombatConfig.weaponSlots[i].name}',
                      ),
                    ),
                for (
                  var i = 0;
                  i < _draftCombatConfig.offhandEquipment.length;
                  i++
                )
                  DropdownMenuItem<String>(
                    value: 'equipment:$i',
                    child: Text(
                      '${_draftCombatConfig.offhandEquipment[i].isShield ? 'Schild' : 'Parierwaffe'}: '
                      '${_draftCombatConfig.offhandEquipment[i].name.trim().isEmpty ? 'Eintrag ${i + 1}' : _draftCombatConfig.offhandEquipment[i].name}',
                    ),
                  ),
              ],
              onChanged: (value) {
                final nextAssignment = switch (value ?? 'none') {
                  'none' => const OffhandAssignment(),
                  final raw when raw.startsWith('weapon:') => OffhandAssignment(
                    weaponIndex:
                        int.tryParse(raw.substring('weapon:'.length)) ?? -1,
                  ),
                  final raw when raw.startsWith('equipment:') =>
                    OffhandAssignment(
                      equipmentIndex:
                          int.tryParse(raw.substring('equipment:'.length)) ??
                          -1,
                    ),
                  _ => const OffhandAssignment(),
                };
                _applyCombatConfigChange(
                  nextConfig: _draftCombatConfig.copyWith(
                    offhandAssignment: nextAssignment,
                  ),
                  catalog: catalog,
                  combatTalents: combatTalents,
                );
              },
            ),
            const SizedBox(height: 12),
            if (offhandWeaponPreview != null && offhandWeapon != null) ...[
              Text(
                'Nebenhand-Waffe',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      offhandWeapon.name.trim().isEmpty
                          ? 'Waffe'
                          : offhandWeapon.name,
                    ),
                  ),
                  Chip(label: Text('AT: ${offhandWeaponPreview.at}')),
                  if (!offhandWeaponPreview.isRangedWeapon)
                    Chip(
                      label: Text(
                        'PA: ${offhandWeaponPreview.paMitIniParadeMod}',
                      ),
                    ),
                  Chip(label: Text('TP: ${offhandWeaponPreview.tpExpression}')),
                  Chip(label: Text('INI: ${mainPreview.kampfInitiative}')),
                ],
              ),
            ] else if (offhandEquipment != null) ...[
              Text(
                offhandEquipment.isShield ? 'Schild' : 'Parierwaffe',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      offhandEquipment.name.trim().isEmpty
                          ? 'Unbenannt'
                          : offhandEquipment.name,
                    ),
                  ),
                  Chip(label: Text('AT Mod: ${offhandEquipment.atMod}')),
                  Chip(label: Text('INI Mod: ${offhandEquipment.iniMod}')),
                  Chip(label: Text('PA Mod: ${offhandEquipment.paMod}')),
                  if (offhandEquipment.isShield)
                    Chip(
                      key: const ValueKey<String>('combat-offhand-shield-pa'),
                      label: Text('Schild-PA: ${mainPreview.shieldPa}'),
                    ),
                  if (mainPreview.offhandRequiresLinkhand)
                    const Chip(label: Text('Linkhand erforderlich')),
                ],
              ),
            ] else
              const Text('Keine Nebenhand belegt.'),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcArmorCard({
    required ArmorConfig armor,
    required CombatPreviewStats preview,
    required RulesCatalog catalog,
    required List<TalentDef> sortedTalents,
  }) {
    const armorDetailsBreakpoint = 760.0;
    final showPieceRg1 = armor.globalArmorTrainingLevel == 1;
    final armorRows = <FlexibleTableRow>[
      for (var i = 0; i < armor.pieces.length; i++)
        FlexibleTableRow(
          cells: [
            _calcTappableNameCell(
              armor.pieces[i].name.trim().isEmpty
                  ? 'Rüstung ${i + 1}'
                  : armor.pieces[i].name,
              onTap: () => _openArmorPieceEditor(
                catalog: catalog,
                combatTalents: sortedTalents,
                pieceIndex: i,
              ),
            ),
            Text(armor.pieces[i].rs.toString()),
            Text(armor.pieces[i].be.toString()),
            Text(armor.pieces[i].isActive ? 'Ja' : 'Nein'),
            if (showPieceRg1) Text(armor.pieces[i].rg1Active ? 'Ja' : 'Nein'),
            IconButton(
              key: ValueKey<String>('combat-armor-remove-$i'),
              tooltip: 'Rüstung entfernen',
              onPressed: () => _removeArmorPiece(
                i,
                catalog: catalog,
                combatTalents: sortedTalents,
              ),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rüstung', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final armorTableSection = Column(
                  key: const ValueKey<String>('combat-armor-table-section'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FlexibleTable(
                      tableKey: const ValueKey<String>('combat-armor-table'),
                      columnSpecs: _calcArmorColumnSpecs(
                        showPieceRg1: showPieceRg1,
                      ),
                      headerCells: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Name'),
                            IconButton(
                              key: const ValueKey<String>('combat-armor-add'),
                              tooltip: 'Rüstung hinzufügen',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 30,
                                height: 30,
                              ),
                              onPressed: () => _openArmorPieceEditor(
                                catalog: catalog,
                                combatTalents: sortedTalents,
                              ),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                          ],
                        ),
                        const Text('RS'),
                        const Text('BE'),
                        const Text('Aktiv'),
                        if (showPieceRg1) const Text('RG I'),
                        const Text('Aktion'),
                      ],
                      rows: armorRows,
                    ),
                    if (armorRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Keine Rüstungsstücke erfasst.'),
                      ),
                  ],
                );
                final armorCalculationSection = Column(
                  key: const ValueKey<String>(
                    'combat-armor-calculation-section',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RS gesamt = Summe aktiver RS = ${preview.rsTotal}'),
                    Text(
                      'BE (Kampf) = BE Roh (${preview.beTotalRaw}) - RG (${preview.rgReduction}) = ${preview.beKampf}',
                    ),
                    Text(
                      'eBE = min(0, -BE(Kampf) (${preview.beKampf}) - BE Mod (${preview.beMod})) = ${preview.ebe}',
                    ),
                  ],
                );
                if (constraints.maxWidth < armorDetailsBreakpoint) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      armorTableSection,
                      const SizedBox(height: 8),
                      armorCalculationSection,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: armorTableSection),
                    const SizedBox(width: 16),
                    Expanded(child: armorCalculationSection),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static List<AdaptiveTableColumnSpec> _calcArmorColumnSpecs({
    required bool showPieceRg1,
  }) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),
      if (showPieceRg1)
        const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),
      const AdaptiveTableColumnSpec.fixed(56),
    ];
  }

  Widget _calcTappableNameCell(String text, {required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final display = text.trim().isEmpty ? '-' : text.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        display,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildIniAusweichenOverviewCard({
    required CombatPreviewStats preview,
    required int manualAusweichenMod,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ini & Ausweichen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _resultChip('Kampf INI', preview.kampfInitiative),
                _resultChip(
                  'Helden+Waffen INI',
                  preview.kombinierteHeldenWaffenIni,
                ),
                _resultChip('PA inkl. INI-Bonus', preview.paMitIniParadeMod),
              ],
            ),
            const Divider(),
            Text(
              'Ausweichen = ${preview.ausweichen}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'PA Anzeige = Waffen-PA (${preview.pa})'
              ' + INI-Parade-Bonus (${preview.iniParadeMod})'
              ' = ${preview.paMitIniParadeMod}',
            ),
            const SizedBox(height: 4),
            Text(
              'PA-Basis (${preview.paBase})'
              ' [Grundwert + Axx (${preview.axxPaBaseBonus})]'
              ' + SF (${preview.sfAusweichenBonus})'
              ' + Akrobatik (${preview.akrobatikBonus})'
              ' + Axx (${preview.axxAusweichenBonus})'
              ' + INI (${preview.iniAusweichenBonus})'
              ' + Mod ($manualAusweichenMod)'
              ' - BE (${preview.beKampf})',
            ),
            if (preview.axxAttackDefenseHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(preview.axxAttackDefenseHint),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWeaponInfoCard({
    required int selectedWeaponIndex,
    required CombatPreviewStats preview,
    required RulesCatalog catalog,
  }) {
    final hasActiveWeapon =
        selectedWeaponIndex >= 0 &&
        selectedWeaponIndex < _draftCombatConfig.weaponSlots.length;
    final activeWeapon = hasActiveWeapon
        ? _draftCombatConfig.weaponSlots[selectedWeaponIndex]
        : const MainWeaponSlot();
    final activeSupportedManeuvers = hasActiveWeapon
        ? _activeSupportedManeuversForSelectedWeapon(catalog)
        : const <String>[];
    return Card(
      key: const ValueKey<String>('combat-active-weapon-info-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktive Waffe - Übersicht',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (!hasActiveWeapon)
              const Text('Keine aktive Waffe ausgewählt.')
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (preview.isRangedWeapon)
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-at',
                      ),
                      label: Text('AT: ${preview.at}'),
                    )
                  else ...[
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-at',
                      ),
                      label: Text('AT: ${preview.at}'),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-pa',
                      ),
                      label: Text('PA: ${preview.paMitIniParadeMod}'),
                    ),
                  ],
                  Chip(
                    key: const ValueKey<String>('combat-active-weapon-info-tp'),
                    label: Text('TP: ${preview.tpExpression}'),
                  ),
                  if (preview.isRangedWeapon) ...[
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-reload-time',
                      ),
                      label: Text('Ladezeit: ${preview.reloadTimeDisplay}'),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-projectile-count',
                      ),
                      label: Text(
                        'Geschosse: ${preview.activeProjectileCount}',
                      ),
                    ),
                  ] else ...[
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-helden-ini',
                      ),
                      label: Text(_heldenIniLabel(preview)),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-helden-waffen-ini',
                      ),
                      label: Text(_heldenWaffenIniLabel(preview)),
                    ),
                    Chip(
                      key: const ValueKey<String>(
                        'combat-active-weapon-info-ini',
                      ),
                      label: Text(_kampfIniLabel(preview)),
                    ),
                  ],
                ],
              ),
              if (preview.isRangedWeapon) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey<String>(
                    'combat-active-weapon-distance-select',
                  ),
                  initialValue:
                      activeWeapon.rangedProfile.selectedDistanceIndex,
                  decoration: const InputDecoration(
                    labelText: 'Entfernung',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (
                      var i = 0;
                      i < activeWeapon.rangedProfile.distanceBands.length;
                      i++
                    )
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          activeWeapon.rangedProfile.distanceBands[i].label
                                  .trim()
                                  .isEmpty
                              ? 'Distanz ${i + 1}'
                              : activeWeapon
                                    .rangedProfile
                                    .distanceBands[i]
                                    .label,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _updateSelectedRangedDistance(value, catalog: catalog);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  key: const ValueKey<String>(
                    'combat-active-weapon-projectile-select',
                  ),
                  initialValue:
                      activeWeapon.rangedProfile.selectedProjectileIndex < 0
                      ? null
                      : activeWeapon.rangedProfile.selectedProjectileIndex,
                  decoration: const InputDecoration(
                    labelText: 'Geschoss',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Kein Geschoss'),
                    ),
                    for (
                      var i = 0;
                      i < activeWeapon.rangedProfile.projectiles.length;
                      i++
                    )
                      DropdownMenuItem<int?>(
                        value: i,
                        child: Text(
                          activeWeapon.rangedProfile.projectiles[i].name
                                  .trim()
                                  .isEmpty
                              ? 'Geschoss ${i + 1}'
                              : activeWeapon.rangedProfile.projectiles[i].name,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    _updateSelectedRangedProjectile(
                      value ?? -1,
                      catalog: catalog,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey<String>(
                        'combat-active-weapon-projectile-count-decrement',
                      ),
                      onPressed: () =>
                          _adjustSelectedProjectileCount(-1, catalog: catalog),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'combat-active-weapon-projectile-count-increment',
                      ),
                      onPressed: () =>
                          _adjustSelectedProjectileCount(1, catalog: catalog),
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preview.activeProjectileDescription.trim().isEmpty
                            ? 'Keine Geschossbeschreibung vorhanden.'
                            : preview.activeProjectileDescription,
                        key: const ValueKey<String>(
                          'combat-active-weapon-info-projectile-description',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(height: 8),
                _activeWeaponIniRollEditor(preview),
                const SizedBox(height: 12),
              ],
              buildWeaponCalculationDetails(
                preview: preview,
                isEditing: _editController.isEditing,
              ),
              if (!preview.isRangedWeapon) ...[
                const SizedBox(height: 8),
                Text('Manoever', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                if (activeSupportedManeuvers.isEmpty)
                  const Text(
                    'Keine erlernten, waffenkompatiblen Manöver.',
                    key: ValueKey<String>(
                      'combat-active-weapon-info-maneuvers',
                    ),
                  )
                else
                  Wrap(
                    key: const ValueKey<String>(
                      'combat-active-weapon-info-maneuvers',
                    ),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final maneuver in activeSupportedManeuvers)
                        Chip(label: Text(maneuver)),
                    ],
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<String> _activeSupportedManeuversForSelectedWeapon(
    RulesCatalog catalog,
  ) {
    final activeManeuvers = _draftCombatConfig.specialRules.activeManeuvers;
    if (activeManeuvers.isEmpty) {
      return const <String>[];
    }
    final allCatalogManeuvers = _collectCatalogManeuvers(catalog.weapons);
    if (allCatalogManeuvers.isEmpty) {
      return const <String>[];
    }
    final supportByManeuver = _buildManeuverSupportMap(
      catalog,
      allCatalogManeuvers,
    );
    final supportedTokens = supportByManeuver.entries
        .where((entry) => entry.value == _ManeuverSupportStatus.supported)
        .map((entry) => _normalizeToken(entry.key))
        .where((entry) => entry.isNotEmpty)
        .toSet();
    final filtered = <String>[];
    final seen = <String>{};
    for (final raw in activeManeuvers) {
      final trimmed = raw.trim();
      final token = _normalizeToken(trimmed);
      if (trimmed.isEmpty ||
          token.isEmpty ||
          seen.contains(token) ||
          !supportedTokens.contains(token)) {
        continue;
      }
      seen.add(token);
      filtered.add(trimmed);
    }
    return filtered;
  }

  String _heldenIniLabel(CombatPreviewStats preview) {
    final specialRules = _draftCombatConfig.specialRules;
    final rollToken = specialRules.aufmerksamkeit
        ? '${preview.iniDiceCount}W6'
        : preview.iniWurfEffective.toString();
    final heldenBaseWithoutRoll =
        preview.heldenInitiative - preview.iniWurfEffective;
    final eigenschaftsIni = preview.eigenschaftsIni;
    final axxIni = preview.axxIniBonus;
    final sonstigeIni = heldenBaseWithoutRoll - eigenschaftsIni - axxIni;
    if (axxIni > 0) {
      return 'Helden INI: Ini-Basis $eigenschaftsIni + Axx $axxIni + '
          'sonstige Modifikatoren $sonstigeIni + $rollToken = '
          '${preview.heldenInitiative}';
    }
    return 'Helden INI: $heldenBaseWithoutRoll + $rollToken = '
        '${preview.heldenInitiative}';
  }

  String _kampfIniLabel(CombatPreviewStats preview) {
    final diff = preview.kampfInitiative - preview.kombinierteHeldenWaffenIni;
    final sign = diff < 0 ? '-' : '+';
    return 'Kampf INI: ${preview.kombinierteHeldenWaffenIni} $sign ${diff.abs()} = ${preview.kampfInitiative}';
  }

  String _heldenWaffenIniLabel(CombatPreviewStats preview) {
    final diff = preview.kombinierteHeldenWaffenIni - preview.heldenInitiative;
    final sign = diff < 0 ? '-' : '+';
    return 'Helden+Waffen INI: ${preview.heldenInitiative} $sign ${diff.abs()} = ${preview.kombinierteHeldenWaffenIni}';
  }

  Widget _activeWeaponIniRollEditor(CombatPreviewStats preview) {
    final maxRoll = preview.iniDiceCount * 6;
    final isAuto = _draftCombatConfig.specialRules.aufmerksamkeit;
    final effectiveRoll = _effectiveIniRollForConfig(_draftCombatConfig);
    final controller = _controllerFor(
      'combat-active-weapon-info-ini-roll',
      effectiveRoll.toString(),
    );
    final desiredText = effectiveRoll.toString();
    if (controller.text != desiredText) {
      controller.value = TextEditingValue(
        text: desiredText,
        selection: TextSelection.collapsed(offset: desiredText.length),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: TextField(
            key: const ValueKey<String>('combat-active-weapon-info-ini-roll'),
            controller: controller,
            readOnly: isAuto,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'INI-Wurf (0-$maxRoll)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: isAuto
                ? null
                : (raw) {
                    final parsed = int.tryParse(raw.trim()) ?? 0;
                    _setTemporaryIniRoll(parsed);
                  },
          ),
        ),
        if (isAuto)
          Chip(label: Text('Aufmerksamkeit aktiv: automatisch $maxRoll')),
      ],
    );
  }
}
