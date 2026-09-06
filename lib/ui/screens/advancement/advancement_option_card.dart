import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/requirement_checklist.dart';

/// Kompakte Zielkarte mit Regelhinweisen und einer vorgemerkten Aktion.
class AdvancementOptionCard extends StatelessWidget {
  /// Stellt eine Regeloption dar, ohne Werte oder Kosten selbst zu berechnen.
  const AdvancementOptionCard({
    super.key,
    required this.option,
    required this.planned,
    required this.onPlan,
  });

  /// Bereits durch das Regelmodul aufgelöstes Steigerungsziel.
  final AdvancementOption option;

  /// Kennzeichnet Ziele mit Einträgen in der laufenden Runde.
  final bool planned;

  /// Öffnet den passenden Planungsdialog; null sperrt die Aktion vorübergehend.
  final VoidCallback? onPlan;

  /// Bricht die Kopfaktion auf schmalen Geräten unter den Titel um.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValue = option.isValueAdvancement;
    // Eine erworbene Sonderfertigkeit ohne offene Auswahl ist kein Fehlerfall,
    // sondern der Bestandsnachweis. Sie bekommt deshalb weder einen gesperrten
    // Knopf noch den Sperrgrund als Warnhinweis.
    final acquired = !isValue && option.isOwned;
    final acquiredClosed = acquired && option.unavailableReason != null;
    final description = isValue
        ? '${_valueText()} · Maximum: ${option.maxValue}'
              ' · SE: ${option.seAvailable}'
        : option.apCost == null
        ? 'AP-Kosten im Erwerbsdialog festlegen'
        : 'Basiskosten: ${option.apCost} AP';
    final actionLabel = isValue
        ? (option.currentValue < 0 ? 'Aktivieren' : 'Steigern')
        : acquired
        ? 'Weitere Auswahl'
        : '+ Sonderfertigkeit';
    final action = acquiredClosed
        ? Row(
            key: ValueKey(
              'advancement-owned-${option.kind.name}-${option.targetId}',
            ),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: context.codexTheme.accent,
              ),
              const SizedBox(width: 6),
              Text('Erworben', style: theme.textTheme.labelLarge),
            ],
          )
        : Tooltip(
            message: option.unavailableReason ?? '$actionLabel vormerken',
            child: OutlinedButton(
              key: ValueKey(
                'advancement-plan-${option.kind.name}-${option.targetId}',
              ),
              onPressed: option.unavailableReason == null ? onPlan : null,
              child: Text(actionLabel),
            ),
          );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(option.label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(_kindLabel(option.kind), style: theme.textTheme.bodySmall),
        if (planned)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Geplant',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.codexTheme.accent,
              ),
            ),
          ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 430) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 8), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    action,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(description, style: theme.textTheme.bodySmall),
            if (acquired && option.ownedCount > 0)
              Text(
                '${option.ownedCount}× erworben',
                style: theme.textTheme.bodySmall,
              ),
            if (option.ability?.kosten.isNotEmpty == true)
              Text(option.ability!.kosten, style: theme.textTheme.bodySmall),
            if (option.complexityHint?.isNotEmpty == true)
              Text(option.complexityHint!, style: theme.textTheme.bodySmall),
            if (option.unavailableReason != null && !acquiredClosed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  option.unavailableReason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.codexTheme.inkMuted,
                  ),
                ),
              ),
            if (option.requirements.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Voraussetzungen'),
                children: [
                  RequirementChecklist(
                    ergebnisse: option.requirements,
                    titel: '',
                    dicht: true,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Trennt „gar nicht vorhanden“ von „vorhanden, aber noch nicht bezahlt“.
  String _valueText() {
    if (!option.isOwned) return 'Noch nicht auf dem Heldenbogen';
    if (option.currentValue < 0) return 'Eingeblendet · noch nicht aktiviert';
    return 'Wert: ${option.currentValue}';
  }

  // Beschriftungen halten gemeinsame Katalogbereiche nachvollziehbar.
  String _kindLabel(AdvancementKind kind) => switch (kind) {
    AdvancementKind.attribute => 'Eigenschaft',
    AdvancementKind.boughtStat => 'Grundwert · Zukauf',
    AdvancementKind.talent => option.isCombatTalent ? 'Kampftalent' : 'Talent',
    AdvancementKind.language => 'Sprache',
    AdvancementKind.script => 'Schrift',
    AdvancementKind.spell => 'Zauber',
    AdvancementKind.generalAbility => 'Allgemeine Sonderfertigkeit',
    AdvancementKind.magicAbility => 'Magische Sonderfertigkeit',
    AdvancementKind.karmalAbility => 'Karmale Sonderfertigkeit',
    AdvancementKind.combatAbility => 'Kampfsonderfertigkeit',
  };
}
