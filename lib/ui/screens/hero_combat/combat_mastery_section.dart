part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// UI-Helfer fuer strukturierte Kampfmeisterschaften.
extension _CombatMasterySection on _HeroCombatTabState {
  Widget _buildCombatMasteriesSection({
    required HeroSheet hero,
    required HeroState heroState,
    required RulesCatalog catalog,
  }) {
    final effectiveAttributes = computeEffectiveAttributes(
      hero,
      tempAttributeMods: heroState.tempAttributeMods,
    );
    final combatTalents = sortedCombatTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Kampfmeisterschaften',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_editController.isEditing)
              OutlinedButton.icon(
                key: const ValueKey<String>('combat-mastery-add'),
                onPressed: () => _addCombatMastery(
                  hero: hero,
                  effectiveAttributes: effectiveAttributes,
                  catalog: catalog,
                  combatTalents: combatTalents,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Hinzufügen'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_draftCombatMasteries.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Keine Kampfmeisterschaften angelegt.'),
              subtitle: Text(
                'Hier werden Waffenmeister und spaetere Meisterschaftsarten strukturiert verwaltet.',
              ),
            ),
          ),
        ..._draftCombatMasteries.asMap().entries.map(
          (entry) => _buildCombatMasteryCard(
            index: entry.key,
            mastery: entry.value,
            hero: hero,
            effectiveAttributes: effectiveAttributes,
            catalog: catalog,
            combatTalents: combatTalents,
          ),
        ),
      ],
    );
  }

  Widget _buildCombatMasteryCard({
    required int index,
    required CombatMastery mastery,
    required HeroSheet hero,
    required Attributes effectiveAttributes,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) {
    final relatedTalent = _findTalentDefById(
      catalog.talents,
      mastery.requirements.requiredTalentId,
    );
    final budget = evaluateCombatMasteryBudget(
      mastery: mastery,
      relatedTalent: relatedTalent,
    );
    final requirements = evaluateCombatMasteryRequirements(
      mastery: mastery,
      hero: hero,
      effectiveAttributes: effectiveAttributes,
    );
    final summary = deriveCombatMasteryModifiers(
      masteries: <CombatMastery>[mastery],
      hero: hero,
      effectiveAttributes: effectiveAttributes,
      selectedWeapon: _draftCombatConfig.selectedWeapon,
      offhandEquipment: _offhandEquipmentOrNull(),
      catalogTalents: catalog.talents,
      catalogManeuvers: catalog.maneuvers,
    ).applicableMasteries;
    final automaticLabels = summary.isEmpty
        ? mastery.effects
              .where(
                (effect) =>
                    !effect.isConditional &&
                    effect.type != CombatMasteryEffectType.specialRuleNote &&
                    effect.type != CombatMasteryEffectType.conditionalToggle,
              )
              .map(
                (effect) => describeCombatMasteryEffect(
                  effect,
                  catalogManeuvers: catalog.maneuvers,
                ),
              )
              .toList(growable: false)
        : summary.single.automaticEffectLabels;
    final conditionalLabels = summary.isEmpty
        ? mastery.effects
              .where(
                (effect) =>
                    effect.isConditional ||
                    effect.type == CombatMasteryEffectType.specialRuleNote ||
                    effect.type == CombatMasteryEffectType.conditionalToggle,
              )
              .map(
                (effect) => describeCombatMasteryEffect(
                  effect,
                  catalogManeuvers: catalog.maneuvers,
                ),
              )
              .toList(growable: false)
        : summary.single.conditionalEffectLabels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mastery.name.trim().isEmpty
                        ? 'Unbenannte Meisterschaft'
                        : mastery.name.trim(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_editController.isEditing) ...[
                  IconButton(
                    tooltip: 'Bearbeiten',
                    onPressed: () => _editCombatMastery(
                      index: index,
                      hero: hero,
                      effectiveAttributes: effectiveAttributes,
                      catalog: catalog,
                      combatTalents: combatTalents,
                    ),
                    icon: const Icon(Icons.edit),
                  ),
                  IconButton(
                    tooltip: 'Entfernen',
                    onPressed: () => _removeCombatMastery(index),
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(describeCombatMasteryTarget(mastery))),
                Chip(
                  label: Text(
                    'Budget ${budget.totalCost}/${mastery.buildPoints}',
                  ),
                ),
                Chip(
                  label: Text(
                    requirements.isFulfilled
                        ? 'Voraussetzungen prüfbar erfüllt'
                        : 'Voraussetzungen offen',
                  ),
                ),
              ],
            ),
            if (automaticLabels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Automatische Effekte',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              ...automaticLabels.map((label) => Text('• $label')),
            ],
            if (conditionalLabels.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Bedingte / manuelle Effekte',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              ...conditionalLabels.map((label) => Text('• $label')),
            ],
            if (budget.issues.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Budget / Regelhinweise',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              ...budget.issues.map((label) => Text('• $label')),
            ],
            if (requirements.missingReasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Fehlende Voraussetzungen',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              ...requirements.missingReasons.map((label) => Text('• $label')),
            ],
            if (requirements.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Warnungen',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              ...requirements.warnings.map((label) => Text('• $label')),
            ],
            if (mastery.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                mastery.notes.trim(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApplicableCombatMasteriesPreview(CombatPreviewStats preview) {
    if (preview.applicableMasteries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anwendbare Meisterschaften',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...preview.applicableMasteries.map((summary) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(summary.name)),
                        Chip(label: Text(summary.targetLabel)),
                        if (!summary.requirementStatus.isFulfilled)
                          const Chip(label: Text('Voraussetzungen offen')),
                      ],
                    ),
                    if (summary.automaticEffectLabels.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...summary.automaticEffectLabels.map(
                        (label) => Text('• $label'),
                      ),
                    ],
                    if (summary.conditionalEffectLabels.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Bedingte Effekte',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      ...summary.conditionalEffectLabels.map(
                        (label) => Text('• $label'),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _addCombatMastery({
    required HeroSheet hero,
    required Attributes effectiveAttributes,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final mastery = await _showCombatMasteryDialog(
      hero: hero,
      effectiveAttributes: effectiveAttributes,
      catalog: catalog,
      combatTalents: combatTalents,
    );
    if (mastery == null) {
      return;
    }
    _draftCombatMasteries = <CombatMastery>[
      ..._draftCombatMasteries,
      mastery,
    ];
    _markFieldChanged();
  }

  Future<void> _editCombatMastery({
    required int index,
    required HeroSheet hero,
    required Attributes effectiveAttributes,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) async {
    final existing = _draftCombatMasteries[index];
    final updated = await _showCombatMasteryDialog(
      hero: hero,
      effectiveAttributes: effectiveAttributes,
      catalog: catalog,
      combatTalents: combatTalents,
      existing: existing,
    );
    if (updated == null) {
      return;
    }
    final next = List<CombatMastery>.from(_draftCombatMasteries);
    next[index] = updated;
    _draftCombatMasteries = next;
    _markFieldChanged();
  }

  void _removeCombatMastery(int index) {
    final next = List<CombatMastery>.from(_draftCombatMasteries);
    next.removeAt(index);
    _draftCombatMasteries = next;
    _markFieldChanged();
  }

  Future<CombatMastery?> _showCombatMasteryDialog({
    required HeroSheet hero,
    required Attributes effectiveAttributes,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
    CombatMastery? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetRefsController = TextEditingController(
      text: existing?.targetRefs.join(', ') ?? '',
    );
    final requiredCombatApController = TextEditingController(
      text: (existing?.requirements.requiredCombatAp ?? 2500).toString(),
    );
    final requiredTalentValueController = TextEditingController(
      text: (existing?.requirements.requiredTalentValue ?? 18).toString(),
    );
    final attributePairTotalController = TextEditingController(
      text: (existing?.requirements.attributePairMinimumTotal ?? 32).toString(),
    );
    final apCostController = TextEditingController(
      text: (existing?.apCost ?? 400).toString(),
    );
    final buildPointsController = TextEditingController(
      text: (existing?.buildPoints ?? 15).toString(),
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final requirementNotesController = TextEditingController(
      text: existing?.requirements.notes ?? '',
    );
    var targetScope =
        existing?.targetScope ?? CombatMasteryTargetScope.singleWeapon;
    var requiredTalentId = existing?.requirements.requiredTalentId ?? '';
    var requiresWeaponSpecialization =
        existing?.requirements.requiresWeaponSpecialization ?? true;
    var attributeRequirements = List<CombatMasteryAttributeRequirement>.from(
      existing?.requirements.attributeRequirements ??
          const <CombatMasteryAttributeRequirement>[],
    );
    var effects = List<CombatMasteryEffect>.from(
      existing?.effects ?? const <CombatMasteryEffect>[],
    );

    final result = await showDialog<CombatMastery>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final draft = CombatMastery(
              id: existing?.id ?? _nextCombatMasteryId(),
              name: nameController.text.trim(),
              targetScope: targetScope,
              targetRefs: _splitTextList(targetRefsController.text),
              effects: effects,
              requirements: CombatMasteryRequirements(
                requiredCombatAp:
                    int.tryParse(requiredCombatApController.text.trim()) ??
                    2500,
                requiredTalentId: requiredTalentId,
                requiredTalentValue:
                    int.tryParse(requiredTalentValueController.text.trim()) ??
                    18,
                requiresWeaponSpecialization: requiresWeaponSpecialization,
                attributePairMinimumTotal:
                    int.tryParse(attributePairTotalController.text.trim()) ?? 32,
                attributeRequirements: attributeRequirements,
                notes: requirementNotesController.text.trim(),
              ),
              apCost: int.tryParse(apCostController.text.trim()) ?? 400,
              buildPoints: int.tryParse(buildPointsController.text.trim()) ?? 15,
              notes: notesController.text.trim(),
            );
            final relatedTalent = _findTalentDefById(
              catalog.talents,
              draft.requirements.requiredTalentId,
            );
            final budget = evaluateCombatMasteryBudget(
              mastery: draft,
              relatedTalent: relatedTalent,
            );
            final requirements = evaluateCombatMasteryRequirements(
              mastery: draft,
              hero: hero,
              effectiveAttributes: effectiveAttributes,
            );

            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Kampfmeisterschaft hinzufügen'
                    : 'Kampfmeisterschaft bearbeiten',
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey<String>('combat-mastery-name'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'z. B. Waffenmeister (Langschwert)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<CombatMasteryTargetScope>(
                        initialValue: targetScope,
                        decoration: const InputDecoration(
                          labelText: 'Zieltyp',
                          border: OutlineInputBorder(),
                        ),
                        items: CombatMasteryTargetScope.values
                            .map(
                              (scope) => DropdownMenuItem(
                                value: scope,
                                child: Text(
                                  _combatMasteryTargetScopeLabel(scope),
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            targetScope = value;
                          });
                        },
                      ),
                      if (targetScope != CombatMasteryTargetScope.shield &&
                          targetScope != CombatMasteryTargetScope.parryWeapon) ...[
                        const SizedBox(height: 10),
                        TextField(
                          key: const ValueKey<String>(
                            'combat-mastery-target-refs',
                          ),
                          controller: targetRefsController,
                          decoration: const InputDecoration(
                            labelText: 'Ziele',
                            hintText: 'Waffenarten kommagetrennt',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Voraussetzungen',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: const ValueKey<String>(
                          'combat-mastery-required-talent',
                        ),
                        initialValue: requiredTalentId.isEmpty
                            ? ''
                            : requiredTalentId,
                        decoration: const InputDecoration(
                          labelText: 'Kampftalent',
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Kein Talent'),
                          ),
                          ...combatTalents.map(
                            (talent) => DropdownMenuItem<String>(
                              value: talent.id,
                              child: Text(talent.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            requiredTalentId = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: requiredCombatApController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Kampf-SF-AP',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: requiredTalentValueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Mindest-TaW',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: attributePairTotalController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Eigenschaftssumme',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Waffenspezialisierung erforderlich'),
                        value: requiresWeaponSpecialization,
                        onChanged: (value) {
                          setDialogState(() {
                            requiresWeaponSpecialization = value;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildAttributeRequirementsEditor(
                        requirements: attributeRequirements,
                        onAdd: () async {
                          final requirement =
                              await _showCombatMasteryAttributeRequirementDialog();
                          if (requirement == null) {
                            return;
                          }
                          setDialogState(() {
                            attributeRequirements =
                                <CombatMasteryAttributeRequirement>[
                                  ...attributeRequirements,
                                  requirement,
                                ];
                          });
                        },
                        onEdit: (index) async {
                          final updated =
                              await _showCombatMasteryAttributeRequirementDialog(
                            existing: attributeRequirements[index],
                          );
                          if (updated == null) {
                            return;
                          }
                          setDialogState(() {
                            final next =
                                List<CombatMasteryAttributeRequirement>.from(
                              attributeRequirements,
                            );
                            next[index] = updated;
                            attributeRequirements = next;
                          });
                        },
                        onDelete: (index) {
                          setDialogState(() {
                            final next =
                                List<CombatMasteryAttributeRequirement>.from(
                              attributeRequirements,
                            );
                            next.removeAt(index);
                            attributeRequirements = next;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: requirementNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Zusatzvoraussetzungen',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Effekte',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildCombatMasteryEffectsEditor(
                        catalog: catalog,
                        effects: effects,
                        onAdd: () async {
                          final effect = await _showCombatMasteryEffectDialog(
                            catalog: catalog,
                          );
                          if (effect == null) {
                            return;
                          }
                          setDialogState(() {
                            effects = <CombatMasteryEffect>[...effects, effect];
                          });
                        },
                        onEdit: (index) async {
                          final effect = await _showCombatMasteryEffectDialog(
                            catalog: catalog,
                            existing: effects[index],
                          );
                          if (effect == null) {
                            return;
                          }
                          setDialogState(() {
                            final next = List<CombatMasteryEffect>.from(effects);
                            next[index] = effect;
                            effects = next;
                          });
                        },
                        onDelete: (index) {
                          setDialogState(() {
                            final next = List<CombatMasteryEffect>.from(effects);
                            next.removeAt(index);
                            effects = next;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: apCostController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'AP-Kosten',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: buildPointsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Punktbudget',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notizen',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Budget ${budget.totalCost}/${draft.buildPoints}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              requirements.isFulfilled
                                  ? 'Voraussetzungen erfüllt'
                                  : 'Voraussetzungen offen',
                            ),
                          ),
                        ],
                      ),
                      if (budget.issues.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...budget.issues.map((entry) => Text('• $entry')),
                      ],
                      if (requirements.missingReasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...requirements.missingReasons.map(
                          (entry) => Text('• $entry'),
                        ),
                      ],
                      if (requirements.warnings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...requirements.warnings.map(
                          (entry) => Text('• $entry'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    final saved = draft.copyWith(
                      name: nameController.text.trim(),
                    );
                    if (saved.name.trim().isEmpty) {
                      return;
                    }
                    Navigator.of(dialogContext).pop(saved);
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Widget _buildAttributeRequirementsEditor({
    required List<CombatMasteryAttributeRequirement> requirements,
    required Future<void> Function() onAdd,
    required Future<void> Function(int index) onEdit,
    required void Function(int index) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Eigenschaftsanforderungen')),
            IconButton(
              key: const ValueKey<String>('combat-mastery-attribute-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Eigenschaft hinzufügen',
            ),
          ],
        ),
        if (requirements.isEmpty)
          const Text('Keine Eigenschaftsanforderungen hinterlegt.'),
        ...requirements.asMap().entries.map((entry) {
          final index = entry.key;
          final requirement = entry.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${requirement.attributeCode} ${requirement.minimum}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onEdit(index),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () => onDelete(index),
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCombatMasteryEffectsEditor({
    required RulesCatalog catalog,
    required List<CombatMasteryEffect> effects,
    required Future<void> Function() onAdd,
    required Future<void> Function(int index) onEdit,
    required void Function(int index) onDelete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Effekte')),
            IconButton(
              key: const ValueKey<String>('combat-mastery-effect-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: 'Effekt hinzufügen',
            ),
          ],
        ),
        if (effects.isEmpty)
          const Text('Keine Effekte hinzugefügt.'),
        ...effects.asMap().entries.map((entry) {
          final index = entry.key;
          final effect = entry.value;
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              describeCombatMasteryEffect(
                effect,
                catalogManeuvers: catalog.maneuvers,
              ),
            ),
            subtitle: effect.notes.trim().isEmpty
                ? null
                : Text(effect.notes.trim()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onEdit(index),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () => onDelete(index),
                  icon: const Icon(Icons.delete),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<CombatMasteryAttributeRequirement?>
  _showCombatMasteryAttributeRequirementDialog({
    CombatMasteryAttributeRequirement? existing,
  }) async {
    var selectedCode = existing?.attributeCode ?? 'GE';
    final minimumController = TextEditingController(
      text: (existing?.minimum ?? 13).toString(),
    );
    final result = await showDialog<CombatMasteryAttributeRequirement>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Eigenschaft hinzufügen'
                    : 'Eigenschaft bearbeiten',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCode,
                    decoration: const InputDecoration(
                      labelText: 'Eigenschaft',
                      border: OutlineInputBorder(),
                    ),
                    items: const <String>[
                      'MU',
                      'KL',
                      'IN',
                      'CH',
                      'FF',
                      'GE',
                      'KO',
                      'KK',
                    ].map((code) {
                      return DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      );
                    }).toList(growable: false),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCode = value ?? 'GE';
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: minimumController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Mindestwert',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      CombatMasteryAttributeRequirement(
                        attributeCode: selectedCode,
                        minimum:
                            int.tryParse(minimumController.text.trim()) ?? 0,
                      ),
                    );
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  Future<CombatMasteryEffect?> _showCombatMasteryEffectDialog({
    required RulesCatalog catalog,
    CombatMasteryEffect? existing,
  }) async {
    var type = existing?.type ?? CombatMasteryEffectType.maneuverDiscount;
    var maneuverId = existing?.maneuverId.isNotEmpty == true
        ? existing!.maneuverId
        : (catalog.maneuvers.isEmpty ? '' : catalog.maneuvers.first.id);
    final labelController = TextEditingController(text: existing?.label ?? '');
    final valueController = TextEditingController(
      text: (existing?.value ?? 0).toString(),
    );
    final secondaryValueController = TextEditingController(
      text: (existing?.secondaryValue ?? 0).toString(),
    );
    final pointCostController = TextEditingController(
      text: existing?.pointCostOverride?.toString() ?? '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    var isConditional = existing?.isConditional ?? false;
    var isManualActivation = existing?.isManualActivation ?? false;

    final result = await showDialog<CombatMasteryEffect>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final draft = CombatMasteryEffect(
              type: type,
              maneuverId: maneuverId,
              label: labelController.text.trim(),
              value: int.tryParse(valueController.text.trim()) ?? 0,
              secondaryValue:
                  int.tryParse(secondaryValueController.text.trim()) ?? 0,
              pointCostOverride: pointCostController.text.trim().isEmpty
                  ? null
                  : int.tryParse(pointCostController.text.trim()),
              isConditional: isConditional,
              isManualActivation: isManualActivation,
              notes: notesController.text.trim(),
            );
            return AlertDialog(
              title: Text(
                existing == null ? 'Effekt hinzufügen' : 'Effekt bearbeiten',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<CombatMasteryEffectType>(
                        key: const ValueKey<String>(
                          'combat-mastery-effect-type',
                        ),
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Effekttyp',
                          border: OutlineInputBorder(),
                        ),
                        items: CombatMasteryEffectType.values.map((entry) {
                          return DropdownMenuItem<CombatMasteryEffectType>(
                            value: entry,
                            child: Text(_combatMasteryEffectTypeLabel(entry)),
                          );
                        }).toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            type = value;
                          });
                        },
                      ),
                      if (_effectUsesManeuver(type) &&
                          catalog.maneuvers.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: maneuverId,
                          decoration: const InputDecoration(
                            labelText: 'Manöver',
                            border: OutlineInputBorder(),
                          ),
                          items: catalog.maneuvers.map((maneuver) {
                            return DropdownMenuItem<String>(
                              value: maneuver.id,
                              child: Text(maneuver.name),
                            );
                          }).toList(growable: false),
                          onChanged: (value) {
                            setDialogState(() {
                              maneuverId = value ?? maneuverId;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          labelText: 'Label / Kurzname',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey<String>(
                                'combat-mastery-effect-value',
                              ),
                              controller: valueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Wert',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: secondaryValueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Sekundärwert',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: pointCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Punktkosten Override',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notizen',
                        ),
                        maxLines: 2,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bedingter Effekt'),
                        value: isConditional,
                        onChanged: (value) {
                          setDialogState(() {
                            isConditional = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Für spätere manuelle Aktivierung markieren',
                        ),
                        value: isManualActivation,
                        onChanged: (value) {
                          setDialogState(() {
                            isManualActivation = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          describeCombatMasteryEffect(
                            draft,
                            catalogManeuvers: catalog.maneuvers,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(draft),
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  List<String> _splitTextList(String raw) {
    final tokens = raw.split(RegExp(r'[\n,;]+'));
    final values = <String>[];
    final seen = <String>{};
    for (final token in tokens) {
      final trimmed = token.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      values.add(trimmed);
    }
    return values;
  }

  String _nextCombatMasteryId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'combat_mastery_$timestamp';
  }

  String _combatMasteryTargetScopeLabel(CombatMasteryTargetScope scope) {
    switch (scope) {
      case CombatMasteryTargetScope.singleWeapon:
        return 'Einzelwaffe';
      case CombatMasteryTargetScope.weaponSet:
        return 'Waffenliste';
      case CombatMasteryTargetScope.shield:
        return 'Schild';
      case CombatMasteryTargetScope.parryWeapon:
        return 'Parierwaffe';
      case CombatMasteryTargetScope.customGroup:
        return 'Freie Gruppe';
    }
  }

  String _combatMasteryEffectTypeLabel(CombatMasteryEffectType type) {
    switch (type) {
      case CombatMasteryEffectType.maneuverDiscount:
        return 'Manövererleichterung';
      case CombatMasteryEffectType.allowedAdditionalManeuver:
        return 'Zusätzliches Manöver';
      case CombatMasteryEffectType.initiativeBonus:
        return 'INI-Bonus';
      case CombatMasteryEffectType.attackModifier:
        return 'AT-WM';
      case CombatMasteryEffectType.parryModifier:
        return 'PA-WM';
      case CombatMasteryEffectType.shieldParryModifier:
        return 'Schild-PA';
      case CombatMasteryEffectType.tpkkShift:
        return 'TP/KK-Verschiebung';
      case CombatMasteryEffectType.rangedRangePercent:
        return 'Reichweitenbonus';
      case CombatMasteryEffectType.targetedShotDiscount:
        return 'Gezielter Schuss';
      case CombatMasteryEffectType.reloadModifier:
        return 'Ladezeit';
      case CombatMasteryEffectType.specialRuleNote:
        return 'Sonderregel';
      case CombatMasteryEffectType.conditionalToggle:
        return 'Bedingter Effekt';
    }
  }

  bool _effectUsesManeuver(CombatMasteryEffectType type) {
    return type == CombatMasteryEffectType.maneuverDiscount ||
        type == CombatMasteryEffectType.allowedAdditionalManeuver;
  }

  TalentDef? _findTalentDefById(List<TalentDef> talents, String talentId) {
    final trimmed = talentId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    for (final talent in talents) {
      if (talent.id == trimmed) {
        return talent;
      }
    }
    return null;
  }
}
