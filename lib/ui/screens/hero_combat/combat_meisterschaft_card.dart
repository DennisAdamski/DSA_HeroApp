import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/grossmeister_rules.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Kachel der Kampfübersicht: Waffenmeister und Waffen-Großmeister der
/// geführten Waffe mit allen Wirkungen, dem Säbel-Pool und dem Schalter
/// „GE statt KK“. Rechnet nichts; die Werte kommen aus der Kampfvorschau.
class CombatMeisterschaftCard extends StatelessWidget {
  const CombatMeisterschaftCard({
    super.key,
    required this.meisterschaft,
    required this.onGeStattKk,
  });

  final MeisterschaftUebersicht meisterschaft;

  /// Schaltet den Bonusschaden aus GE statt KK.
  final ValueChanged<bool> onGeStattKk;

  @override
  Widget build(BuildContext context) {
    final m = meisterschaft;
    final theme = Theme.of(context);
    final gross = m.grossmeisterName.isNotEmpty;
    final pool = m.poolPunkte;

    Widget liste(String titel, List<String> eintraege) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titel, style: theme.textTheme.titleSmall),
          for (final eintrag in eintraege)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $eintrag'),
            ),
        ],
      ),
    );

    return CodexSectionCard(
      key: const ValueKey<String>('combat-meisterschaft-card'),
      title: gross ? 'Großmeister' : 'Waffenmeister',
      subtitle: [
        if (gross) m.grossmeisterName,
        if (m.waffenmeisterName.isNotEmpty) m.waffenmeisterName,
      ].join(' · '),
      leading: const Icon(Icons.military_tech_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pool != null)
            Text(
              'Säbel-Pool: $pool Punkte je KR',
              key: const ValueKey<String>('combat-meisterschaft-pool'),
              style: theme.textTheme.titleMedium,
            ),
          if (pool != null)
            Text(
              'aus dem GE/INI-Bonus, frei verteilbar auf '
              '${saebelPoolManoever.join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          if (m.geStattKkMoeglich)
            SwitchListTile(
              key: const ValueKey<String>('combat-meisterschaft-ge-statt-kk'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Bonusschaden aus GE statt KK'),
              subtitle: Text(
                'TP/KK-Zuschlag mit GE +${m.tpKkMitGe}, mit KK '
                '+${m.tpKkMitKk}${m.geStattKkAktiv ? ' – GE wirkt' : ''}; '
                'nicht mit Wuchtschlag und darauf aufbauenden Manövern.',
              ),
              value: m.geStattKkAktiv,
              onChanged: onGeStattKk,
            ),
          if (gross && m.grossmeisterWirkungen.isNotEmpty)
            liste('Eingerechnet (Großmeister)', m.grossmeisterWirkungen),
          if (m.waffenmeisterWirkungen.isNotEmpty)
            liste('Waffenmeister', m.waffenmeisterWirkungen),
          if (m.hinweise.isNotEmpty) liste('Am Spieltisch', m.hinweise),
        ],
      ),
    );
  }
}
