import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_impact_rules.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';

/// Zeigt entweder die Rundensummen oder die zusätzliche Eigenschaftswirkung.
class AdvancementImpactPanel extends ConsumerWidget {
  /// Ohne Eigenschaft/Zielwert wird der Beginn mit der aktuellen Runde verglichen.
  const AdvancementImpactPanel({
    super.key,
    required this.session,
    this.attribute,
    this.targetValue,
  }) : assert((attribute == null) == (targetValue == null));
  final AdvancementSession session;
  final AttributeCode? attribute;
  final int? targetValue;

  /// Verwendet für beide Vergleichsstände denselben reaktiven Laufzeitzustand.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(heroStateProvider(session.base.id));
    final epicActive = ref.watch(
      isHouseRuleActiveProvider(EpicRuleKeys.advantages),
    );
    return state.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Basiswerte werden geladen …'),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Basiswerte konnten nicht geladen werden.'),
      ),
      data: (state) {
        final impact = attribute == null
            ? computeAdvancementImpact(
                before: session.base,
                after: session.preview,
                state: state,
                catalog: session.catalog,
                epicAdvantagesActive: epicActive,
              )
            : computeAttributeAdvancementImpact(
                hero: session.preview,
                catalog: session.catalog,
                state: state,
                attribute: attribute!,
                targetValue: targetValue!,
                epicAdvantagesActive: epicActive,
              );
        return _ImpactCard(impact: impact, showUnlocked: attribute != null);
      },
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({required this.impact, required this.showUnlocked});
  final AdvancementImpact impact;
  final bool showUnlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basiswerte', style: theme.textTheme.titleMedium),
            Text(
              showUnlocked
                  ? 'Aktuelle Planung → Mit dieser Erhöhung'
                  : 'Vor der Runde → Geplant',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final stat in impact.stats)
                  Text(
                    _statText(stat),
                    key: ValueKey('advancement-impact-${stat.label}'),
                    style: stat.delta == 0
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                  ),
              ],
            ),
            if (showUnlocked) ...[
              const Divider(height: 24),
              Text(
                'Durch diese Erhöhung weiter steigerbar',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              if (impact.unlocked.isEmpty)
                const Text(
                  'Durch diese Erhöhung wird kein weiterer '
                  'Talent- oder Zauberwert steigerbar.',
                )
              else ...[
                for (final entry in impact.unlocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${entry.category}: ${entry.before.label} · '
                      'Wert ${entry.before.currentValue} · '
                      'Maximum ${entry.before.maxValue} → ${entry.after.maxValue}',
                      key: ValueKey(
                        'advancement-unlocked-'
                        '${entry.before.kind.name}-${entry.before.targetId}',
                      ),
                    ),
                  ),
                Text(
                  'Regeltechnischer Spielraum; verfügbare AP werden '
                  'hier nicht geprüft.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// Auch ohne Farbwahrnehmung bleibt jede Änderung durch Pfeil und Delta erkennbar.
String _statText(AdvancementStatChange stat) {
  final delta = stat.delta;
  final suffix = delta == 0 ? '' : ' (${delta > 0 ? '+' : ''}$delta)';
  return '${stat.label} ${stat.before} → ${stat.after}$suffix';
}
