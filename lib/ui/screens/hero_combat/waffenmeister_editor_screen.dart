import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/waffenmeister_editor/waffenmeister_basic_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/waffenmeister_editor/waffenmeister_bonus_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/waffenmeister_editor/waffenmeister_preview_section.dart';

/// Editor-Screen fuer eine Waffenmeisterschaft.
///
/// Zeigt den 15-Punkte-Baukasten mit Stammdaten, Bonus-Verteilung und
/// Zusammenfassung. Funktioniert als eigenstaendiger Screen.
class WaffenmeisterEditorScreen extends StatefulWidget {
  const WaffenmeisterEditorScreen({
    super.key,
    required this.initialConfig,
    required this.isNew,
    required this.combatTalents,
    required this.catalog,
    required this.onSaved,
    required this.onCancel,
  });

  final WaffenmeisterConfig initialConfig;
  final bool isNew;
  final List<TalentDef> combatTalents;
  final RulesCatalog catalog;
  final ValueChanged<WaffenmeisterConfig> onSaved;
  final VoidCallback onCancel;

  @override
  State<WaffenmeisterEditorScreen> createState() =>
      _WaffenmeisterEditorScreenState();
}

class _WaffenmeisterEditorScreenState extends State<WaffenmeisterEditorScreen> {
  late WaffenmeisterConfig _draft;
  late final TextEditingController _styleNameController;
  late final TextEditingController _masterNameController;
  late final TextEditingController _attr1ValueController;
  late final TextEditingController _attr2ValueController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialConfig;
    _styleNameController = TextEditingController(text: _draft.styleName);
    _masterNameController = TextEditingController(text: _draft.masterName);
    _attr1ValueController = TextEditingController(
      text: _draft.requiredAttribute1Value.toString(),
    );
    _attr2ValueController = TextEditingController(
      text: _draft.requiredAttribute2Value.toString(),
    );
  }

  @override
  void dispose() {
    _styleNameController.dispose();
    _masterNameController.dispose();
    _attr1ValueController.dispose();
    _attr2ValueController.dispose();
    super.dispose();
  }

  void _setDraft(WaffenmeisterConfig next) {
    setState(() {
      _draft = next;
    });
  }

  // ---------------------------------------------------------------------------
  // Budget-Berechnung
  // ---------------------------------------------------------------------------

  int _computeAutoPointCost() {
    var cost = 0;
    // Steigerungsspalte
    final talentDef = widget.combatTalents
        .where((t) => t.id == _draft.talentId)
        .firstOrNull;
    final steigerung = talentDef?.steigerung.trim().toUpperCase() ?? '';
    if (steigerung == 'C') {
      cost += 4;
    } else if (steigerung == 'D') {
      cost += 2;
    }
    // Reine Angriffswaffe (Fernkampf, Peitsche, Lanzenreiten)
    final talentType = talentDef?.type ?? '';
    final talentName = talentDef?.name.toLowerCase() ?? '';
    if (talentType == 'Fernkampf' ||
        talentName == 'peitsche' ||
        talentName == 'lanzenreiten') {
      cost += 4;
    }
    // Zusaetzliche Waffen
    if (_draft.additionalWeaponTypes.isNotEmpty) {
      cost += 2;
    }
    return cost;
  }

  int _computeAllocatedPoints() {
    var total = 0;
    for (final bonus in _draft.bonuses) {
      total += _pointCostForBonus(bonus);
    }
    return total;
  }

  int _pointCostForBonus(WaffenmeisterBonus bonus) {
    switch (bonus.type) {
      case WaffenmeisterBonusType.maneuverReduction:
        return bonus.value.abs();
      case WaffenmeisterBonusType.iniBonus:
        return bonus.value * 3;
      case WaffenmeisterBonusType.tpKkReduction:
        return 2;
      case WaffenmeisterBonusType.atWmBonus:
        return bonus.value * 5;
      case WaffenmeisterBonusType.paWmBonus:
        return bonus.value * 5;
      case WaffenmeisterBonusType.ausfallPenaltyRemoval:
        return 2;
      case WaffenmeisterBonusType.additionalManeuver:
        return 5;
      case WaffenmeisterBonusType.rangeIncrease:
        return bonus.value;
      case WaffenmeisterBonusType.gezielterSchussReduction:
        return 2;
      case WaffenmeisterBonusType.reloadTimeHalved:
        return 5;
      case WaffenmeisterBonusType.customAdvantage:
        return bonus.customPointCost.clamp(2, 5);
    }
  }

  // ---------------------------------------------------------------------------
  // Bonus-Verwaltung
  // ---------------------------------------------------------------------------

  void _addBonus(WaffenmeisterBonus bonus) {
    final next = List<WaffenmeisterBonus>.from(_draft.bonuses)..add(bonus);
    _setDraft(_draft.copyWith(bonuses: next));
  }

  void _updateBonus(int index, WaffenmeisterBonus bonus) {
    final next = List<WaffenmeisterBonus>.from(_draft.bonuses);
    next[index] = bonus;
    _setDraft(_draft.copyWith(bonuses: next));
  }

  void _removeBonus(int index) {
    final next = List<WaffenmeisterBonus>.from(_draft.bonuses)..removeAt(index);
    _setDraft(_draft.copyWith(bonuses: next));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final autoCost = _computeAutoPointCost();
    final allocated = _computeAllocatedPoints();
    final totalUsed = autoCost + allocated;
    const totalBudget = 15;
    final remaining = totalBudget - totalUsed;
    final isOverBudget = remaining < 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onCancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isNew
                ? 'Waffenmeister hinzufügen'
                : 'Waffenmeister bearbeiten',
          ),
        ),
        body: Column(
          children: [
            // Budget-Anzeige
            _buildBudgetBar(
              totalBudget: totalBudget,
              autoCost: autoCost,
              allocated: allocated,
              remaining: remaining,
              isOverBudget: isOverBudget,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WaffenmeisterBasicSection(
                      draft: _draft,
                      combatTalents: widget.combatTalents,
                      catalog: widget.catalog,
                      styleNameController: _styleNameController,
                      masterNameController: _masterNameController,
                      attr1ValueController: _attr1ValueController,
                      attr2ValueController: _attr2ValueController,
                      onChanged: _setDraft,
                    ),
                    const SizedBox(height: 16),
                    WaffenmeisterBonusSection(
                      draft: _draft,
                      catalog: widget.catalog,
                      combatTalents: widget.combatTalents,
                      autoCost: autoCost,
                      allocated: allocated,
                      remaining: remaining,
                      onAddBonus: _addBonus,
                      onUpdateBonus: _updateBonus,
                      onRemoveBonus: _removeBonus,
                    ),
                    const SizedBox(height: 16),
                    WaffenmeisterPreviewSection(
                      draft: _draft,
                      autoCost: autoCost,
                      allocated: allocated,
                      pointCostForBonus: _pointCostForBonus,
                    ),
                  ],
                ),
              ),
            ),
            _buildActions(isOverBudget: isOverBudget),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetBar({
    required int totalBudget,
    required int autoCost,
    required int allocated,
    required int remaining,
    required bool isOverBudget,
  }) {
    final usedTotal = autoCost + allocated;
    final progress = (usedTotal / totalBudget).clamp(0.0, 1.0);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOverBudget
          ? colorScheme.errorContainer
          : colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Budget: $usedTotal / $totalBudget Punkte',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isOverBudget ? colorScheme.error : null,
                ),
              ),
              const Spacer(),
              if (autoCost > 0)
                Chip(
                  label: Text('Grundkosten: $autoCost'),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  isOverBudget
                      ? 'Überbudget: ${remaining.abs()}'
                      : 'Frei: $remaining',
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: isOverBudget ? colorScheme.errorContainer : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            color: isOverBudget ? colorScheme.error : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActions({required bool isOverBudget}) {
    final canSave = _draft.talentId.isNotEmpty &&
        _draft.weaponType.trim().isNotEmpty &&
        !isOverBudget;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Abbrechen'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSave ? () => widget.onSaved(_draft) : null,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
