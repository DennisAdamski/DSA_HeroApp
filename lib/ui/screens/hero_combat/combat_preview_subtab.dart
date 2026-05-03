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
    final artifactSummaryCard = _buildCombatArtifactSummaryCard(
      offhandWeapon: offhandWeapon,
      offhandEquipment: offhandEquipment,
    );
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
      if (artifactSummaryCard != null) ...[
        const SizedBox(height: 12),
        artifactSummaryCard,
      ],
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
      ),
      if (_buildTwoWeaponActionCard(preview: preview)
          case final actionCard?) ...[
        const SizedBox(height: 12),
        actionCard,
      ],
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

  /// Zeigt die aktuellen Kampfwerte in einer kompakten Übersicht, aufgeteilt
  /// in globale Werte, Haupthand und optionale Nebenhand.
  Widget _buildCombatPreviewValuesCard({
    required CombatPreviewStats preview,
    required MainWeaponSlot? offhandWeapon,
  }) {
    final offhandPreview = preview.offhandPreview;
    return CodexSectionCard(
      title: 'Aktuelle Kampfwerte',
      subtitle:
          'Sofort spielbare Werte für die aktive Waffenhaltung und aktuelle Distanz.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Globale / waffenunabhängige Werte ---
          _buildGlobalCombatValues(preview: preview),
          const Divider(height: 24),
          // --- Haupthand ---
          _buildMainHandValues(preview: preview),
          // --- Nebenhand (konditionell) ---
          if (offhandPreview != null) ...[
            const Divider(height: 24),
            _buildOffhandValues(offhandPreview: offhandPreview),
          ],
        ],
      ),
    );
  }

  /// Globale Kampfwerte: INI, Ausweichen, RS.
  Widget _buildGlobalCombatValues({required CombatPreviewStats preview}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 160,
              child: CodexMetricTile(
                label: 'Kampf-INI',
                value: preview.kampfInitiative.toString(),
                icon: Icons.flash_on_outlined,
                onTap: () => showLoggedProbeDialog(
                  context: context,
                  ref: ref,
                  heroId: widget.heroId,
                  request: buildInitiativeProbeRequest(
                    title: 'Initiativwurf',
                    diceSpec: preview.initiativeDiceSpec,
                    fixedRollTotal: preview.initiativeFixedRollTotal,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: CodexMetricTile(
                label: 'Ausweichen',
                value: preview.ausweichen.toString(),
                icon: Icons.directions_run_outlined,
                onTap: () => showLoggedProbeDialog(
                  context: context,
                  ref: ref,
                  heroId: widget.heroId,
                  request: buildCombatCheckProbeRequest(
                    type: ProbeType.dodge,
                    title: 'Kampfprobe: Ausweichen',
                    targetValue: preview.ausweichen,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: CodexMetricTile(
                label: 'RS',
                value: preview.rsTotal.toString(),
                icon: Icons.health_and_safety_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _initiativeRollEditor(preview),
      ],
    );
  }

  /// Haupthand-spezifische Kampfwerte: AT, PA, TP, eBE, Fernkampf-Chips.
  Widget _buildMainHandValues({required CombatPreviewStats preview}) {
    final mainName = _draftCombatConfig.selectedWeapon.name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Haupthand${mainName.isEmpty ? '' : ': $mainName'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 140,
              child: CodexMetricTile(
                label: 'AT',
                value: preview.at.toString(),
                icon: Icons.gps_fixed,
                highlight: true,
                onTap: () => showLoggedProbeDialog(
                  context: context,
                  ref: ref,
                  heroId: widget.heroId,
                  request: buildCombatCheckProbeRequest(
                    type: ProbeType.combatAttack,
                    title: 'Kampfprobe: AT',
                    targetValue: preview.at,
                  ),
                ),
              ),
            ),
            if (!preview.isRangedWeapon)
              SizedBox(
                width: 140,
                child: CodexMetricTile(
                  label: 'PA',
                  value: preview.paMitIniParadeMod.toString(),
                  icon: Icons.shield_outlined,
                  onTap: () => showLoggedProbeDialog(
                    context: context,
                    ref: ref,
                    heroId: widget.heroId,
                    request: buildCombatCheckProbeRequest(
                      type: ProbeType.combatParry,
                      title: 'Kampfprobe: PA',
                      targetValue: preview.paMitIniParadeMod,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: 160,
              child: CodexMetricTile(
                label: 'TP',
                value: preview.tpExpression,
                icon: Icons.whatshot_outlined,
                onTap: () => showLoggedProbeDialog(
                  context: context,
                  ref: ref,
                  heroId: widget.heroId,
                  request: buildDamageProbeRequest(
                    title: 'Schadenswurf',
                    diceSpec: preview.damageDiceSpec,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: CodexMetricTile(
                label: 'eBE',
                value: preview.ebe.toString(),
                icon: Icons.balance_outlined,
              ),
            ),
            if (preview.isRangedWeapon)
              SizedBox(
                width: 160,
                child: CodexMetricTile(
                  label: 'Ladezeit',
                  value: preview.reloadTimeDisplay,
                  icon: Icons.timer_outlined,
                ),
              ),
          ],
        ),
        if (preview.isRangedWeapon) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  'Distanz: ${preview.activeDistanceLabel.trim().isEmpty ? '-' : preview.activeDistanceLabel}',
                ),
              ),
              Chip(
                label: Text(
                  'Geschoss: ${preview.activeProjectileName.trim().isEmpty ? '-' : preview.activeProjectileName}',
                ),
              ),
              Chip(label: Text('Geschosse: ${preview.activeProjectileCount}')),
            ],
          ),
        ],
        if (preview.waffenmeisterActive) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildWaffenmeisterPreviewChips(preview: preview),
          ),
        ],
      ],
    );
  }

  /// Nebenhand-spezifische Kampfwerte – Inhalt abhaengig vom Nebenhand-Typ.
  Widget _buildOffhandValues({required OffhandCombatPreview offhandPreview}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nebenhand: ${offhandPreview.displayName}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (offhandPreview.isWeapon)
          _buildOffhandWeaponValues(offhandPreview: offhandPreview)
        else if (offhandPreview.isShield)
          _buildOffhandShieldValues(offhandPreview: offhandPreview)
        else if (offhandPreview.isParryWeapon)
          _buildOffhandParryWeaponValues(offhandPreview: offhandPreview),
      ],
    );
  }

  /// Nebenhand = zweite Waffe: volle AT/PA/TP/eBE.
  Widget _buildOffhandWeaponValues({
    required OffhandCombatPreview offhandPreview,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (offhandPreview.at != null)
              SizedBox(
                width: 140,
                child: CodexMetricTile(
                  label: 'AT',
                  value: offhandPreview.at.toString(),
                  icon: Icons.gps_fixed,
                  onTap: () => showLoggedProbeDialog(
                    context: context,
                    ref: ref,
                    heroId: widget.heroId,
                    request: buildCombatCheckProbeRequest(
                      type: ProbeType.combatAttack,
                      title: 'Kampfprobe: AT (NH)',
                      targetValue: offhandPreview.at!,
                    ),
                  ),
                ),
              ),
            if (offhandPreview.pa != null && !offhandPreview.isRangedWeapon)
              SizedBox(
                width: 140,
                child: CodexMetricTile(
                  label: 'PA',
                  value:
                      (offhandPreview.paMitIniParadeMod ?? offhandPreview.pa!)
                          .toString(),
                  icon: Icons.shield_outlined,
                  onTap: () => showLoggedProbeDialog(
                    context: context,
                    ref: ref,
                    heroId: widget.heroId,
                    request: buildCombatCheckProbeRequest(
                      type: ProbeType.combatParry,
                      title: 'Kampfprobe: PA (NH)',
                      targetValue:
                          offhandPreview.paMitIniParadeMod ??
                          offhandPreview.pa!,
                    ),
                  ),
                ),
              ),
            if (offhandPreview.tpExpression != null)
              SizedBox(
                width: 160,
                child: CodexMetricTile(
                  label: 'TP',
                  value: offhandPreview.tpExpression!,
                  icon: Icons.whatshot_outlined,
                  onTap: offhandPreview.damageDiceSpec == null
                      ? null
                      : () => showLoggedProbeDialog(
                          context: context,
                          ref: ref,
                          heroId: widget.heroId,
                          request: buildDamageProbeRequest(
                            title: 'Schadenswurf (NH)',
                            diceSpec: offhandPreview.damageDiceSpec!,
                          ),
                        ),
                ),
              ),
            if (offhandPreview.ebe != null)
              SizedBox(
                width: 130,
                child: CodexMetricTile(
                  label: 'eBE',
                  value: offhandPreview.ebe.toString(),
                  icon: Icons.balance_outlined,
                ),
              ),
            if (offhandPreview.isRangedWeapon &&
                offhandPreview.reloadTimeDisplay != null)
              SizedBox(
                width: 160,
                child: CodexMetricTile(
                  label: 'Ladezeit',
                  value: offhandPreview.reloadTimeDisplay!,
                  icon: Icons.timer_outlined,
                ),
              ),
          ],
        ),
        if (offhandPreview.isRangedWeapon) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (offhandPreview.activeDistanceLabel != null)
                Chip(
                  label: Text(
                    'Distanz: ${offhandPreview.activeDistanceLabel!.trim().isEmpty ? '-' : offhandPreview.activeDistanceLabel}',
                  ),
                ),
              if (offhandPreview.activeProjectileName != null)
                Chip(
                  label: Text(
                    'Geschoss: ${offhandPreview.activeProjectileName!.trim().isEmpty ? '-' : offhandPreview.activeProjectileName}',
                  ),
                ),
              if (offhandPreview.activeProjectileCount != null)
                Chip(
                  label: Text(
                    'Geschosse: ${offhandPreview.activeProjectileCount}',
                  ),
                ),
            ],
          ),
        ],
        if (offhandPreview.waffenmeisterActive) ...[
          const SizedBox(height: 8),
          Chip(label: Text(offhandPreview.waffenmeisterName)),
        ],
        if (offhandPreview.falseHandLabel != null &&
            (offhandPreview.falseHandAtMod != null ||
                offhandPreview.falseHandPaMod != null)) ...[
          const SizedBox(height: 8),
          Chip(
            label: Text(
              '${offhandPreview.falseHandLabel}: AT ${offhandPreview.falseHandAtMod}, PA ${offhandPreview.falseHandPaMod}',
            ),
          ),
        ],
      ],
    );
  }

  /// Nebenhand = Schild: Schild-PA.
  Widget _buildOffhandShieldValues({
    required OffhandCombatPreview offhandPreview,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (offhandPreview.shieldPa != null)
          SizedBox(
            width: 160,
            child: CodexMetricTile(
              label: 'Schild-PA',
              value: offhandPreview.shieldPa.toString(),
              icon: Icons.shield,
              onTap: () => showLoggedProbeDialog(
                context: context,
                ref: ref,
                heroId: widget.heroId,
                request: buildCombatCheckProbeRequest(
                  type: ProbeType.combatParry,
                  title: 'Kampfprobe: Schild-PA',
                  targetValue: offhandPreview.shieldPa!,
                ),
              ),
            ),
          ),
        if (offhandPreview.atMod != null)
          Chip(label: Text('AT-Mod: ${offhandPreview.atMod}')),
        if (offhandPreview.iniMod != null)
          Chip(label: Text('INI-Mod: ${offhandPreview.iniMod}')),
      ],
    );
  }

  /// Nebenhand = Parierwaffe: PA-Mod und Linkhand-Warnung.
  Widget _buildOffhandParryWeaponValues({
    required OffhandCombatPreview offhandPreview,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (offhandPreview.mainPaMod != null)
          Chip(label: Text('PA-Mod: ${offhandPreview.mainPaMod}')),
        if (offhandPreview.atMod != null)
          Chip(label: Text('AT-Mod: ${offhandPreview.atMod}')),
        if (offhandPreview.iniMod != null)
          Chip(label: Text('INI-Mod: ${offhandPreview.iniMod}')),
        if (offhandPreview.requiresLinkhandViolation)
          const Chip(label: Text('Linkhand erforderlich')),
      ],
    );
  }

  /// Zeigt die zur aktuellen Waffe möglichen Manöver mit Hand-Zuordnung.
  /// Zeigt verfuegbare Zusatzaktionen fuer beidhändigen Kampf und Parierwaffen.
  Widget? _buildTwoWeaponActionCard({required CombatPreviewStats preview}) {
    final snapshot = preview.twoWeaponCombat;
    if (snapshot == null || !snapshot.isRelevant || snapshot.options.isEmpty) {
      return null;
    }
    final selectedType = _effectiveTwoWeaponAction(preview);
    final selectedOption =
        snapshot.optionFor(selectedType) ?? snapshot.options.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nebenhand-Aktionen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: snapshot.options
                  .map(
                    (option) => ChoiceChip(
                      label: Text(option.label),
                      selected: selectedOption.type == option.type,
                      onSelected: (_) => _selectTwoWeaponAction(option.type),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              selectedOption.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (!selectedOption.isAvailable)
              Text(
                selectedOption.availabilityReason,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (selectedOption.isAvailable)
              _buildTwoWeaponActionMetrics(option: selectedOption),
            if (selectedOption.exclusionNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...selectedOption.exclusionNotes.map(
                (note) => Text(
                  '- $note',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (snapshot.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...snapshot.notes.map(
                (note) => Text(
                  '- $note',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Verdichtet die Zielwerte fuer die aktuell ausgewaehlte Nebenhand-Aktion.
  Widget _buildTwoWeaponActionMetrics({required TwoWeaponActionOption option}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (option.mainAttackTarget != null)
          SizedBox(
            width: 140,
            child: CodexMetricTile(
              label: 'HH-AT',
              value: option.mainAttackTarget.toString(),
              icon: Icons.gps_fixed,
            ),
          ),
        if (option.offhandAttackTarget != null)
          SizedBox(
            width: 140,
            child: CodexMetricTile(
              label: 'NH-AT',
              value: option.offhandAttackTarget.toString(),
              icon: Icons.gps_not_fixed,
            ),
          ),
        if (option.offhandParryTarget != null)
          SizedBox(
            width: 140,
            child: CodexMetricTile(
              label: 'NH-PA',
              value: option.offhandParryTarget.toString(),
              icon: Icons.shield_outlined,
            ),
          ),
      ],
    );
  }

  /// Hält eine sinnvolle Default-Auswahl fuer die Aktionskarte stabil.
  TwoWeaponActionType _effectiveTwoWeaponAction(CombatPreviewStats preview) {
    final snapshot = preview.twoWeaponCombat;
    if (snapshot == null || snapshot.options.isEmpty) {
      return TwoWeaponActionType.none;
    }
    final current = snapshot.optionFor(_selectedTwoWeaponAction);
    if (current != null) {
      return current.type;
    }
    for (final option in snapshot.options) {
      if (option.isAvailable) {
        return option.type;
      }
    }
    return snapshot.options.first.type;
  }

  Widget _buildPossibleManeuversPreviewCard({
    required RulesCatalog catalog,
    required CombatPreviewStats preview,
  }) {
    final entries = _activePreviewManeuverEntries(catalog, preview);
    final hasOffhand = preview.offhandPreview != null;

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
            if (entries.isEmpty)
              const Text(
                'Für die aktive Waffenhaltung sind aktuell keine nutzbaren Manöver hinterlegt.',
              ),
            ...entries.map((entry) {
              final maneuver = _maneuverById(catalog, entry.maneuverId);
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  onTap: maneuver == null
                      ? null
                      : () => _showCombatManeuverDetailsDialog(
                          context: context,
                          maneuver: maneuver,
                        ),
                  title: Text(_maneuverLabel(catalog, entry.maneuverId)),
                  subtitle: Text(
                    _buildPreviewManeuverSummary(
                      preview: preview,
                      maneuverId: entry.maneuverId,
                      maneuverDef: maneuver,
                    ),
                  ),
                  trailing: hasOffhand
                      ? _buildHandBadge(entry.availableHands)
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Kleiner Badge fuer die Hand-Zuordnung eines Manoevers.
  Widget _buildHandBadge(ManeuverHandAvailability availability) {
    final label = switch (availability) {
      ManeuverHandAvailability.mainOnly => 'HH',
      ManeuverHandAvailability.offhandOnly => 'NH',
      ManeuverHandAvailability.both => 'HH+NH',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  /// Kennzeichnet im Preview nur, dass eine passende Waffenmeisterschaft aktiv ist.
  List<Widget> _buildWaffenmeisterPreviewChips({
    required CombatPreviewStats preview,
  }) {
    if (!preview.waffenmeisterActive) {
      return const <Widget>[];
    }

    return <Widget>[Chip(label: Text(preview.waffenmeisterName))]; /*
      chips.add(Chip(label: Text('WM Manöver: $label')));
    */
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
            if (offhandWeapon != null) ...[
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
              ),
              if (offhandWeapon.isRanged &&
                  offhandWeapon.rangedProfile.distanceBands.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: const ValueKey<String>(
                    'combat-offhand-weapon-distance-select',
                  ),
                  initialValue:
                      offhandWeapon.rangedProfile.selectedDistanceIndex,
                  decoration: const InputDecoration(
                    labelText: 'Entfernung (NH)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (
                      var i = 0;
                      i < offhandWeapon.rangedProfile.distanceBands.length;
                      i++
                    )
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(
                          offhandWeapon.rangedProfile.distanceBands[i].label
                                  .trim()
                                  .isEmpty
                              ? 'Distanz ${i + 1}'
                              : offhandWeapon
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
                    _updateOffhandRangedDistance(value, catalog: catalog);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  key: const ValueKey<String>(
                    'combat-offhand-weapon-projectile-select',
                  ),
                  initialValue:
                      offhandWeapon.rangedProfile.selectedProjectileIndex < 0
                      ? null
                      : offhandWeapon.rangedProfile.selectedProjectileIndex,
                  decoration: const InputDecoration(
                    labelText: 'Geschoss (NH)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Kein Geschoss'),
                    ),
                    for (
                      var i = 0;
                      i < offhandWeapon.rangedProfile.projectiles.length;
                      i++
                    )
                      DropdownMenuItem<int?>(
                        value: i,
                        child: Text(
                          offhandWeapon.rangedProfile.projectiles[i].name
                                  .trim()
                                  .isEmpty
                              ? 'Geschoss ${i + 1}'
                              : offhandWeapon.rangedProfile.projectiles[i].name,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    _updateOffhandRangedProjectile(
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
                        'combat-offhand-weapon-projectile-count-decrement',
                      ),
                      onPressed: () =>
                          _adjustOffhandProjectileCount(-1, catalog: catalog),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      key: const ValueKey<String>(
                        'combat-offhand-weapon-projectile-count-increment',
                      ),
                      onPressed: () =>
                          _adjustOffhandProjectileCount(1, catalog: catalog),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ] else if (offhandEquipment != null)
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
