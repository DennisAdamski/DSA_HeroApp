import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_visibility_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_visibility_toggle.dart';

import 'advancement_ability_details.dart';

import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_skill_tree.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_option_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/skill_tree_branch.dart';

/// Durchsuchbarer Fähigkeitenbaum mit logischen Verknüpfungen und Erwerbsdetails.
class AdvancementSkillTreeView extends StatefulWidget {
  /// Bindet den Baum an die bereits berechneten Optionen der Sitzung.
  const AdvancementSkillTreeView({
    super.key,
    required this.session,
    required this.options,
    required this.query,
    this.onPlan,
    this.onShowInapplicableChanged,
  });
  final AdvancementSession session;
  final List<AdvancementOption> options;
  final String query;
  final ValueChanged<AdvancementOption>? onPlan;

  /// Speichert die heldenspezifische Anzeige unter Erhalt des Entwurfs.
  final Future<void> Function(bool)? onShowInapplicableChanged;

  /// Behält den gewählten Themenbereich während einzelner Planungsschritte.
  @override
  State<AdvancementSkillTreeView> createState() =>
      _AdvancementSkillTreeViewState();
}

class _AdvancementSkillTreeViewState extends State<AdvancementSkillTreeView> {
  String? _category;
  late AdvancementSkillTree _graph;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    _rebuildGraph();
  }

  @override
  void didUpdateWidget(covariant AdvancementSkillTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options ||
        oldWidget.session != widget.session) {
      _rebuildGraph();
    }
  }

  // Die Such-/Filterbedienung benötigt keine erneute Regelauswertung.
  void _rebuildGraph() {
    final hero = widget.session.preview;
    final visible = visibleAdvancementAbilityOptions(
      options: widget.options,
      activation: computeHeroResourceActivation(hero),
      showInapplicable: hero.showInapplicableSpecialAbilities,
      plannedTargets: {
        for (final entry in widget.session.entries)
          '${entry.kind.name}:${entry.targetId}',
      },
    );
    _graph = buildAdvancementSkillTree(
      options: visible,
      availableAp: widget.session.preview.apAvailable,
      plannedTargets: {
        for (final entry in widget.session.entries)
          if (!widget.session.errors.containsKey(entry.id))
            '${entry.kind.name}:${entry.targetId}',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = _graph.components(
      query: widget.query,
      category: _category,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SpecialAbilityVisibilityToggle(
            value: widget.session.preview.showInapplicableSpecialAbilities,
            onChanged: widget.session.isSaving
                ? null
                : widget.onShowInapplicableChanged,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final category in [
                null,
                'Kampf',
                'Allgemein',
                'Magie',
                'Karma',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category ?? 'Alle'),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('advancement-skill-tree'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: branches.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fähigkeitenbaum',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Von links nach rechts entwickeln. Knoten öffnen für '
                        'Voraussetzungen und Erwerb. Breite Zweige seitlich verschieben.',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          for (final status in SkillTreeStatus.values)
                            SkillTreeStatusLabel(status: status),
                        ],
                      ),
                      if (branches.isEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Keine passenden Fähigkeiten. Suche oder Bereich ändern.',
                        ),
                      ],
                    ],
                  ),
                );
              }
              final ids = branches[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SkillTreeBranch(
                  graph: _graph,
                  ids: ids,
                  onSelect: _detailsOpen ? null : _openDetails,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Details schließen vor dem Erwerbsdialog, damit kein Dialogstapel entsteht.
  Future<void> _openDetails(SkillTreeNode node) async {
    final option = node.option;
    if (option == null || _detailsOpen) return;
    setState(() => _detailsOpen = true);
    try {
      final plan = await showAdaptiveInputDialog<bool>(
        context: context,
        builder: (context) => AdaptiveInputDialog(
          title: option.label,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdvancementOptionCard(
                option: option,
                expandRequirements: true,
                planned: node.status == SkillTreeStatus.planned,
                onPlan: widget.onPlan == null
                    ? null
                    : () => Navigator.of(context).pop(true),
              ),
              if (option.ability case final ability?)
                AdvancementAbilityDetails(
                  ability: ability,
                  catalog: widget.session.catalog,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
      if (plan == true && mounted) widget.onPlan?.call(option);
    } finally {
      if (mounted) setState(() => _detailsOpen = false);
    }
  }
}
