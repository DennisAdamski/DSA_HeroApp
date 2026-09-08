import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/skill_tree/skill_tree_models.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/skill_tree_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/skill_tree/skill_tree_node_card.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Oeffnet das Detail-Sheet einer Skilltree-Knotens mit Lern-Aktion.
Future<void> showSkillTreeDetailSheet({
  required BuildContext context,
  required String heroId,
  required SkillTreeCategory category,
  required EvaluatedNode evaluated,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _SkillTreeDetailSheet(
      heroId: heroId,
      category: category,
      evaluated: evaluated,
    ),
  );
}

class _SkillTreeDetailSheet extends ConsumerWidget {
  const _SkillTreeDetailSheet({
    required this.heroId,
    required this.category,
    required this.evaluated,
  });

  final String heroId;
  final SkillTreeCategory category;
  final EvaluatedNode evaluated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final node = evaluated.node;
    final hero = ref.watch(heroByIdProvider(heroId));
    final apAvailable = hero?.apAvailable ?? 0;
    final stateColor = skillNodeStateColor(codex, evaluated.state);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(node.name, style: theme.textTheme.titleLarge),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(codex.panelRadius),
                    border: Border.all(color: stateColor),
                  ),
                  child: Text(
                    skillNodeStateLabel(evaluated.state),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (node.beschreibung.isNotEmpty) ...[
              Text(node.beschreibung, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            _InfoRow(
              label: 'AP-Kosten',
              value: node.apCost != null
                  ? '${node.apCost} AP'
                  : (node.kostenRaw.isEmpty ? 'unbekannt' : node.kostenRaw),
            ),
            _InfoRow(label: 'Verfügbare AP', value: '$apAvailable AP'),
            if (node.voraussetzungenRaw.isNotEmpty)
              _InfoRow(label: 'Voraussetzungen', value: node.voraussetzungenRaw),
            const SizedBox(height: 12),
            _RequirementList(
              requirements: node.requirements,
              unmet: evaluated.unmetRequirements,
            ),
            const SizedBox(height: 16),
            _LearnButton(
              heroId: heroId,
              category: category,
              evaluated: evaluated,
              canAfford: evaluated.canAfford,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: codex.inkMuted),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _RequirementList extends StatelessWidget {
  const _RequirementList({required this.requirements, required this.unmet});

  final List<SkillRequirement> requirements;
  final List<SkillRequirement> unmet;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    if (requirements.isEmpty) {
      return Text(
        'Keine besonderen Voraussetzungen.',
        style: theme.textTheme.bodySmall?.copyWith(color: codex.inkMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Voraussetzungen', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final req in requirements)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  unmet.contains(req)
                      ? Icons.cancel_outlined
                      : (req is UnknownRequirement
                            ? Icons.help_outline
                            : Icons.check_circle_outline),
                  size: 16,
                  color: unmet.contains(req)
                      ? codex.danger
                      : (req is UnknownRequirement
                            ? codex.warning
                            : codex.success),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    describeRequirement(req),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LearnButton extends ConsumerStatefulWidget {
  const _LearnButton({
    required this.heroId,
    required this.category,
    required this.evaluated,
    required this.canAfford,
  });

  final String heroId;
  final SkillTreeCategory category;
  final EvaluatedNode evaluated;
  final bool canAfford;

  @override
  ConsumerState<_LearnButton> createState() => _LearnButtonState();
}

class _LearnButtonState extends ConsumerState<_LearnButton> {
  bool _busy = false;

  Future<void> _learn() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(skillTreeActionsProvider)
          .learn(
            heroId: widget.heroId,
            node: widget.evaluated.node,
            category: widget.category,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.evaluated.node.name} gelernt')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lernen fehlgeschlagen: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluated = widget.evaluated;
    final node = evaluated.node;

    if (!node.isSpecialAbility) {
      return const SizedBox.shrink();
    }
    if (evaluated.state == SkillNodeState.learned) {
      return const FilledButton.tonal(
        onPressed: null,
        child: Text('Bereits gelernt'),
      );
    }
    if (evaluated.state == SkillNodeState.locked) {
      return const FilledButton(
        onPressed: null,
        child: Text('Voraussetzungen nicht erfüllt'),
      );
    }
    if (!widget.canAfford) {
      return const FilledButton(
        onPressed: null,
        child: Text('Nicht genug AP'),
      );
    }

    final cost = node.apCost ?? 0;
    final label = evaluated.state == SkillNodeState.unknownRequirements
        ? 'Trotzdem lernen ($cost AP)'
        : 'Lernen ($cost AP)';
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _learn,
        child: _busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

/// Liefert eine lesbare Beschreibung einer Voraussetzung.
String describeRequirement(SkillRequirement req) {
  switch (req) {
    case AttributeRequirement(:final attribute, :final min):
      return '${_attributeLabel(attribute)} $min';
    case TalentRequirement(:final name, :final minTaW):
      return 'TaW $name $minTaW';
    case SpellRequirement(:final name, :final minZfW):
      return 'ZfW $name $minZfW';
    case AbilityRequirement(:final name):
      return 'SF $name';
    case TraitRequirement(:final name):
      return 'Vorteil $name';
    case RaceRequirement(:final name):
      return 'Rasse $name';
    case OrRequirement(:final options):
      return options.map(describeRequirement).join(' oder ');
    case UnknownRequirement(:final rawText):
      return rawText;
  }
}

String _attributeLabel(String key) => switch (key) {
  'mu' => 'MU',
  'kl' => 'KL',
  'inn' => 'IN',
  'ch' => 'CH',
  'ff' => 'FF',
  'ge' => 'GE',
  'ko' => 'KO',
  'kk' => 'KK',
  _ => key.toUpperCase(),
};
