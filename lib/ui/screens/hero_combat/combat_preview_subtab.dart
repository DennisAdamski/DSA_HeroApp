part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kampfwerte-Subtab mit Auswahl links und aktueller Übersicht rechts.
extension _CombatPreviewSubtab on _HeroCombatTabState {
  Widget _buildCombatPreviewSubTab({
    required List<TalentDef> combatTalents,
    required RulesCatalog catalog,
    required HeroSheet hero,
    required HeroState heroState,
    required CombatPreviewStats preview,
  }) {
    final weaponSlots = _draftCombatConfig.weaponSlots;
    final selectedWeaponIndex = _selectedWeaponIndex();
    final sortedTalents = sortedCombatTalents(combatTalents);
    final offhandWeapon = _offhandWeaponOrNull();
    final offhandEquipment = _offhandEquipmentOrNull();
    final isEditing = _editController.isEditing;
    final manual = _draftCombatConfig.manualMods;
    final leftColumnChildren = <Widget>[
      _buildPreviewWeaponSelection(
        catalog: catalog,
        combatTalents: sortedTalents,
        selectedWeaponIndex: selectedWeaponIndex,
        weaponSlots: weaponSlots,
        preview: preview,
      ),
      const SizedBox(height: 12),
      _buildPreviewOffhandCard(
        catalog: catalog,
        combatTalents: sortedTalents,
        mainPreview: preview,
        hero: hero,
        heroState: heroState,
        offhandWeapon: offhandWeapon,
        offhandEquipment: offhandEquipment,
      ),
      const SizedBox(height: 12),
      buildWeaponCalculationDetails(preview: preview, isEditing: isEditing),
      if (isEditing) ...[
        const SizedBox(height: 12),
        _buildManualModifiersCard(manual: manual),
      ],
    ];
    final rightColumnChildren = <Widget>[
      _buildCombatPreviewValuesCard(
        preview: preview,
        offhandWeapon: offhandWeapon,
        catalog: catalog,
      ),
      if (preview.axxAttackDefenseHint.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(preview.axxAttackDefenseHint),
      ],
      const SizedBox(height: 12),
      _buildPossibleManeuversPreviewCard(catalog: catalog, preview: preview),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = constraints.maxWidth >= 1000;
        if (!useSplitLayout) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...leftColumnChildren,
                const SizedBox(height: 12),
                ...rightColumnChildren,
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: leftColumnChildren,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rightColumnChildren,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Zeigt die aktuellen Kampfwerte in einer kompakten Übersicht.
  Widget _buildCombatPreviewValuesCard({
    required CombatPreviewStats preview,
    required MainWeaponSlot? offhandWeapon,
    required RulesCatalog catalog,
  }) {
    final hasHeldRangedWeapon = _hasHeldRangedWeapon(
      preview: preview,
      offhandWeapon: offhandWeapon,
    );
    final activeDistanceLabel = preview.activeDistanceLabel.trim().isEmpty
        ? '-'
        : preview.activeDistanceLabel;
    final activeProjectileName = preview.activeProjectileName.trim().isEmpty
        ? '-'
        : preview.activeProjectileName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aktuelle Kampfwerte',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            CombatQuickStats(
              at: preview.at,
              pa: preview.isRangedWeapon ? null : preview.paMitIniParadeMod,
              tpExpression: preview.tpExpression,
              kampfInitiative: preview.kampfInitiative,
              ausweichen: preview.ausweichen,
              rs: preview.rsTotal,
              ebe: preview.ebe,
              isRanged: preview.isRangedWeapon,
              ladezeit: preview.isRangedWeapon
                  ? preview.reloadTimeDisplay
                  : null,
              geschosse: preview.isRangedWeapon
                  ? preview.activeProjectileCount
                  : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasHeldRangedWeapon)
                  Chip(label: Text('Distanz: $activeDistanceLabel')),
                if (hasHeldRangedWeapon)
                  Chip(label: Text('Geschoss: $activeProjectileName')),
                ..._buildWaffenmeisterPreviewChips(
                  catalog: catalog,
                  preview: preview,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Zeigt die zur aktuellen Waffe möglichen Manöver.
  Widget _buildPossibleManeuversPreviewCard({
    required RulesCatalog catalog,
    required CombatPreviewStats preview,
  }) {
    final maneuverIds = _activePreviewManeuverIds(catalog, preview);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutzbare Manöver',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (maneuverIds.isEmpty)
              const Text(
                'Für die aktive Waffe sind aktuell keine nutzbaren Manöver hinterlegt.',
              ),
            ...maneuverIds.map((maneuverId) {
              final maneuver = _maneuverById(catalog, maneuverId);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: maneuver == null
                      ? null
                      : () => _showCombatManeuverDetailsDialog(
                          context: context,
                          maneuver: maneuver,
                        ),
                  title: Text(_maneuverLabel(catalog, maneuverId)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _buildPreviewManeuverMetaChips(
                        catalog: catalog,
                        preview: preview,
                        maneuverId: maneuverId,
                        maneuverDef: maneuver,
                      ),
                    ),
                  ),
                  trailing: maneuver == null
                      ? null
                      : const Icon(Icons.open_in_new),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Kennzeichnet, ob aktuell in Haupt- oder Nebenhand eine Fernkampfwaffe
  /// gehalten wird.
  bool _hasHeldRangedWeapon({
    required CombatPreviewStats preview,
    required MainWeaponSlot? offhandWeapon,
  }) {
    if (preview.isRangedWeapon) {
      return true;
    }
    return offhandWeapon?.isRanged ?? false;
  }

  /// Rendert die expliziten Waffenmeister-Boni fuer die Kampfwerte-Quickview.
  List<Widget> _buildWaffenmeisterPreviewChips({
    required RulesCatalog catalog,
    required CombatPreviewStats preview,
  }) {
    if (!preview.waffenmeisterActive) {
      return const <Widget>[];
    }

    final chips = <Widget>[Chip(label: Text(preview.waffenmeisterName))];
    if (preview.waffenmeisterAtBonus != 0) {
      chips.add(Chip(label: Text('WM AT: +${preview.waffenmeisterAtBonus}')));
    }
    if (preview.waffenmeisterPaBonus != 0) {
      chips.add(Chip(label: Text('WM PA: +${preview.waffenmeisterPaBonus}')));
    }
    if (preview.waffenmeisterIniBonus != 0) {
      chips.add(Chip(label: Text('WM INI: +${preview.waffenmeisterIniBonus}')));
    }
    for (final entry in preview.waffenmeisterManeuverReductions.entries) {
      final label = displayNameForManeuverId(
        entry.key,
        catalogManeuvers: catalog.maneuvers,
      );
      chips.add(Chip(label: Text('$label -${entry.value}')));
    }
    for (final maneuverId in preview.waffenmeisterAdditionalManeuvers) {
      final label = displayNameForManeuverId(
        maneuverId,
        catalogManeuvers: catalog.maneuvers,
      );
      chips.add(Chip(label: Text('WM Manöver: $label')));
    }
    return chips;
  }

  // ---------------------------------------------------------------------------
  // Haupthand-Auswahl
  // ---------------------------------------------------------------------------

  Widget _buildPreviewWeaponSelection({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    required int selectedWeaponIndex,
    required List<MainWeaponSlot> weaponSlots,
    required CombatPreviewStats preview,
  }) {
    final hasActiveWeapon =
        selectedWeaponIndex >= 0 && selectedWeaponIndex < weaponSlots.length;
    final activeWeapon = hasActiveWeapon
        ? weaponSlots[selectedWeaponIndex]
        : const MainWeaponSlot();

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
            if (hasActiveWeapon && preview.isRangedWeapon) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                key: const ValueKey<String>(
                  'combat-active-weapon-distance-select',
                ),
                initialValue: activeWeapon.rangedProfile.selectedDistanceIndex,
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
                            : activeWeapon.rangedProfile.distanceBands[i].label,
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
                    ),
                  ),
                ],
              ),
            ] else if (hasActiveWeapon && !preview.isRangedWeapon) ...[
              const SizedBox(height: 8),
              _activeWeaponIniRollEditor(preview),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Nebenhand kompakte Vorschau
  // ---------------------------------------------------------------------------

  Widget _buildPreviewOffhandCard({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    required CombatPreviewStats mainPreview,
    required HeroSheet hero,
    required HeroState heroState,
    required MainWeaponSlot? offhandWeapon,
    required OffhandEquipmentEntry? offhandEquipment,
  }) {
    final assignment = _draftCombatConfig.offhandAssignment;
    final selectedValue = assignment.usesWeapon
        ? 'weapon:${assignment.weaponIndex}'
        : (assignment.usesEquipment
              ? 'equipment:${assignment.equipmentIndex}'
              : 'none');
    final selectedWeaponIndex = _selectedWeaponIndex();

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
            const SizedBox(height: 8),
            if (offhandWeapon != null)
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
                  Chip(label: Text(combatTypeLabel(offhandWeapon.combatType))),
                ],
              )
            else if (offhandEquipment != null)
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
                  Chip(
                    label: Text(
                      offhandEquipment.isShield ? 'Schild' : 'Parierwaffe',
                    ),
                  ),
                  Chip(label: Text('PA Mod: ${offhandEquipment.paMod}')),
                  if (offhandEquipment.isShield)
                    Chip(
                      key: const ValueKey<String>('combat-offhand-shield-pa'),
                      label: Text('Schild-PA: ${mainPreview.shieldPa}'),
                    ),
                  if (mainPreview.offhandRequiresLinkhand)
                    const Chip(label: Text('Linkhand erforderlich')),
                ],
              )
            else
              const Text('Keine Nebenhand belegt.'),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Manuelle Modifikatoren
  // ---------------------------------------------------------------------------

  Widget _buildManualModifiersCard({required CombatManualMods manual}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manuelle Modifikatoren',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _previewModField(
                  key: 'combat-manual-ini-mod',
                  label: 'INI Mod',
                  initialValue: manual.iniMod,
                  onChanged: (value) {
                    _draftCombatConfig = _draftCombatConfig.copyWith(
                      manualMods: _draftCombatConfig.manualMods.copyWith(
                        iniMod: value,
                      ),
                    );
                    _markFieldChanged();
                  },
                ),
                _previewModField(
                  key: 'combat-manual-ausw-mod',
                  label: 'Ausweichen Mod',
                  initialValue: manual.ausweichenMod,
                  onChanged: (value) {
                    _draftCombatConfig = _draftCombatConfig.copyWith(
                      manualMods: _draftCombatConfig.manualMods.copyWith(
                        ausweichenMod: value,
                      ),
                    );
                    _markFieldChanged();
                  },
                ),
                _previewModField(
                  key: 'combat-manual-at-mod',
                  label: 'AT Mod',
                  initialValue: manual.atMod,
                  onChanged: (value) {
                    _draftCombatConfig = _draftCombatConfig.copyWith(
                      manualMods: _draftCombatConfig.manualMods.copyWith(
                        atMod: value,
                      ),
                    );
                    _markFieldChanged();
                  },
                ),
                _previewModField(
                  key: 'combat-manual-pa-mod',
                  label: 'PA Mod',
                  initialValue: manual.paMod,
                  onChanged: (value) {
                    _draftCombatConfig = _draftCombatConfig.copyWith(
                      manualMods: _draftCombatConfig.manualMods.copyWith(
                        paMod: value,
                      ),
                    );
                    _markFieldChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Baut ein kompaktes Eingabefeld fuer manuelle Kampfmodifikatoren.
  Widget _previewModField({
    required String key,
    required String label,
    required int initialValue,
    required void Function(int value) onChanged,
  }) {
    final controller = _controllerFor(key, initialValue.toString());
    return SizedBox(
      width: 140,
      child: TextField(
        key: ValueKey<String>(key),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (raw) {
          final parsed = int.tryParse(raw.trim()) ?? 0;
          onChanged(parsed);
        },
      ),
    );
  }
}
