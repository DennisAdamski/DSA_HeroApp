import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zuletzt_gewuerfelt_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_info_chip.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Streifen mit den zuletzt gewürfelten Proben (SPIEL-01).
///
/// Jede Marke wiederholt ihre Probe mit einem Tipp über den normalen
/// Probendialog. Die Auswahl leitet [zuletztGewuerfelteProben] aus dem
/// Würfelprotokoll ab; der Streifen speichert nichts und synchronisiert
/// nichts. Ohne wiederholbaren Wurf bleibt er unsichtbar, statt einen leeren
/// Rahmen zu zeigen.
class KartoZuletztGewuerfelt extends StatelessWidget {
  /// Erstellt den Streifen für das Würfelprotokoll [protokoll].
  const KartoZuletztGewuerfelt({
    super.key,
    required this.protokoll,
    required this.onWiederholen,
  });

  /// Das Würfelprotokoll des Helden, ältester Eintrag zuerst.
  final List<DiceLogEntry> protokoll;

  /// Wiederholt die Probe des angetippten Eintrags.
  final void Function(DiceLogEntry eintrag) onWiederholen;

  @override
  Widget build(BuildContext context) {
    final proben = zuletztGewuerfelteProben(protokoll);
    if (proben.isEmpty) return const SizedBox.shrink();
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: Abstand.weit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zuletzt gewürfelt',
            style: texte.marke.copyWith(color: karto.schriftLeise),
          ),
          const SizedBox(height: Abstand.normal),
          Wrap(
            spacing: Abstand.normal,
            runSpacing: Abstand.normal,
            children: [
              for (final eintrag in proben)
                Tooltip(
                  message: 'Nochmal würfeln: ${probenKurzname(eintrag)}',
                  child: KartoInfoChip(
                    key: ValueKey<String>(
                      'karto-spiel-zuletzt-${eintrag.type.name}-${eintrag.title}',
                    ),
                    symbol: Icons.replay,
                    text: probenKurzname(eintrag),
                    onTap: () => onWiederholen(eintrag),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
