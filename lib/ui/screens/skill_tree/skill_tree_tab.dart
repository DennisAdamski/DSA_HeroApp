import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/skill_tree_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_detail_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_graph_view.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_node_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_empty_state.dart';

/// Workspace-Tab: grafischer Skilltree der aufeinander aufbauenden
/// Sonderfertigkeiten (Kampf und Magie), helden-bezogen ausgewertet.
class SkillTreeTab extends ConsumerStatefulWidget {
  const SkillTreeTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<bool> onEditingChanged;
  final ValueChanged<WorkspaceAsyncAction> onRegisterDiscard;
  final ValueChanged<WorkspaceTabEditActions> onRegisterEditActions;

  @override
  ConsumerState<SkillTreeTab> createState() => _SkillTreeTabState();
}

class _SkillTreeTabState extends ConsumerState<SkillTreeTab> {
  SkillTreeCategory _category = SkillTreeCategory.combat;

  @override
  void initState() {
    super.initState();
    // Kein Edit-Modus: Lernen committet direkt.
    widget.onEditingChanged(false);
    widget.onDirtyChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden'));
    }
    final magicEnabled = computeHeroResourceActivation(hero).magic.isEnabled;
    final category = (_category == SkillTreeCategory.magic && !magicEnabled)
        ? SkillTreeCategory.combat
        : _category;

    final viewAsync = ref.watch(
      skillTreeViewProvider((heroId: widget.heroId, category: category)),
    );

    return Column(
      children: [
        _Header(
          category: category,
          magicEnabled: magicEnabled,
          onChanged: (next) => setState(() => _category = next),
        ),
        const _Legend(),
        Expanded(
          child: viewAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CodexEmptyState(
                  title: 'Skilltree nicht verfügbar',
                  message: 'Der Regelkatalog konnte nicht geladen werden.\n$error',
                  assetPath: 'assets/ui/codex/arcane_seal.png',
                ),
              ),
            ),
            data: (view) {
              if (view.graph.nodes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CodexEmptyState(
                      title: 'Keine Sonderfertigkeiten',
                      message:
                          'Für diese Kategorie sind keine aufeinander '
                          'aufbauenden Sonderfertigkeiten hinterlegt.',
                      assetPath: 'assets/ui/codex/arcane_seal.png',
                    ),
                  ),
                );
              }
              return SkillTreeGraphView(
                view: view,
                onNodeTap: (evaluated) => showSkillTreeDetailSheet(
                  context: context,
                  heroId: widget.heroId,
                  category: category,
                  evaluated: evaluated,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.category,
    required this.magicEnabled,
    required this.onChanged,
  });

  final SkillTreeCategory category;
  final bool magicEnabled;
  final ValueChanged<SkillTreeCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<SkillTreeCategory>(
          segments: <ButtonSegment<SkillTreeCategory>>[
            const ButtonSegment(
              value: SkillTreeCategory.combat,
              label: Text('Kampf'),
              icon: Icon(Icons.sports_martial_arts_outlined),
            ),
            ButtonSegment(
              value: SkillTreeCategory.magic,
              label: const Text('Magie'),
              icon: const Icon(Icons.bolt_outlined),
              enabled: magicEnabled,
            ),
          ],
          selected: <SkillTreeCategory>{category},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: const [
          _LegendChip(state: SkillNodeState.learned),
          _LegendChip(state: SkillNodeState.learnable),
          _LegendChip(state: SkillNodeState.unknownRequirements),
          _LegendChip(state: SkillNodeState.locked),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.state});

  final SkillNodeState state;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final color = skillNodeStateColor(codex, state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          skillNodeStateLabel(state),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
