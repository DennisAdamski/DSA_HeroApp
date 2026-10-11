import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_impact_rules.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

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

  /// Rechenblatt statt Kachel: ein Kopfband mit Akzentkante, darunter je Wert
  /// eine Zeile mit Vorher → Nachher. So hebt sich die Berechnung von den
  /// Kacheln der Eigenschaften und der zugekauften Basiswerte ab.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final karto = kartoVariante(context);
    final akzent = karto?.messing ?? theme.colorScheme.tertiary;
    final leise = karto?.schriftLeise ?? theme.colorScheme.onSurfaceVariant;
    final linie = karto?.hoehenlinie ?? theme.colorScheme.outlineVariant;
    final stats = impact.stats;
    final inhalt = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(color: akzent, child: const SizedBox(height: 3)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.functions, size: 20, color: akzent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Basiswertberechnung',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              Text(
                showUnlocked
                    ? 'Aktuelle Planung → Mit dieser Erhöhung'
                    : 'Vor der Runde → Geplant',
                style: theme.textTheme.bodySmall?.copyWith(color: leise),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, showUnlocked ? 0 : 8),
          child: Column(
            children: [
              for (var i = 0; i < stats.length; i++)
                _StatZeile(
                  stat: stats[i],
                  trenner: i < stats.length - 1 ? linie : null,
                  leise: leise,
                ),
            ],
          ),
        ),
        if (showUnlocked)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 24, color: linie),
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
            ),
          ),
      ],
    );
    final geklippt = ClipRRect(
      borderRadius: BorderRadius.circular(kartoRadiusOder(context, 12)),
      child: inhalt,
    );
    if (karto != null) {
      return KartoFlaeche(
        stufe: KartoFlaechenstufe.senke,
        kante: StrichGewicht.grat,
        child: geklippt,
      );
    }
    return Card(margin: EdgeInsets.zero, child: geklippt);
  }
}

/// Eine Zeile des Rechenblatts. Die Pfeil- und Deltaschreibweise bleibt auch
/// ohne Farbwahrnehmung lesbar; Bildschirmleser erhalten den ganzen Satz.
class _StatZeile extends StatelessWidget {
  const _StatZeile({
    required this.stat,
    required this.trenner,
    required this.leise,
  });
  final AdvancementStatChange stat;
  final Color? trenner;
  final Color leise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final geaendert = stat.delta != 0;
    final farbe = stat.delta < 0
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final zahlen = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: geaendert ? farbe : null,
      fontWeight: geaendert ? FontWeight.bold : null,
    );
    return Semantics(
      container: true,
      label: _statText(stat),
      excludeSemantics: true,
      child: DecoratedBox(
        key: ValueKey('advancement-impact-${stat.label}'),
        decoration: BoxDecoration(
          border: trenner == null
              ? null
              : Border(bottom: BorderSide(color: trenner!, width: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stat.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: geaendert ? null : leise,
                  ),
                ),
              ),
              Text('${stat.before} → ${stat.after}', style: zahlen),
              SizedBox(
                width: 44,
                child: geaendert
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: farbe.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            child: Text(
                              '${stat.delta > 0 ? '+' : ''}${stat.delta}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: farbe,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
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
