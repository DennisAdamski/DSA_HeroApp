import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/list_tile_material.dart';

/// Karte einer einzelnen Zauberquelle (MAG-EFF-02).
///
/// Rein darstellend: Unterdrücken, Beenden und die Dauer laufen über
/// Callbacks, die Persistenz bleibt beim aufrufenden Dialog.
class SpellEffectInstanceTile extends StatelessWidget {
  /// Erstellt die Karte für genau eine Instanz.
  const SpellEffectInstanceTile({
    super.key,
    required this.instanz,
    required this.titel,
    required this.onWirktChanged,
    required this.onBeenden,
    required this.onAdvanceDuration,
    this.ueberlagert = const <String>[],
    this.mussAufrechterhaltenWerden = false,
  });

  /// Anzuzeigende Instanz.
  final SpellEffectInstance instanz;

  /// Name des Zaubers samt laufender Nummer der Quelle.
  final String titel;

  /// Schaltet die Wirkung ein (`true`) oder unterdrückt sie (`false`).
  final ValueChanged<bool> onWirktChanged;

  /// Beendet nur diese Quelle.
  final VoidCallback onBeenden;

  /// Zieht eine Zeiteinheit von der Restlaufzeit ab.
  final VoidCallback onAdvanceDuration;

  /// Eigenschaften, die diese Quelle verbessern würde, die aber eine bessere
  /// Quelle überlagert (es zählt nur der beste Wert).
  final List<String> ueberlagert;

  /// Der Zauber verlangt Aufrechterhaltung (Katalog „(A)“).
  final bool mussAufrechterhaltenWerden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boni = beschreibeAttributoInstanz(instanz);
    final dauer = instanz.duration;
    final dauerText = describeSpellDuration(dauer);
    final kannZaehlen =
        dauer != null &&
        dauer.amount > 0 &&
        !dauer.isPermanent &&
        dauer.remaining > 0;
    final id = instanz.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTileMaterial(
            child: SwitchListTile(
              key: ValueKey<String>('spell-instance-wirkt-$id'),
              title: Text(titel),
              subtitle: Text(
                [
                  if (instanz.quelle != null) 'Quelle: ${instanz.quelle}',
                  if (boni.isNotEmpty) 'Boni: $boni',
                  if (instanz.unterdrueckt) 'unterdrückt',
                  if (ueberlagert.isNotEmpty)
                    'zählt nicht für ${ueberlagert.join(', ')} (bessere Quelle)',
                  if (mussAufrechterhaltenWerden) 'aufrechterhalten',
                ].join(' · '),
              ),
              value: !instanz.unterdrueckt,
              onChanged: onWirktChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.timelapse_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: kDialogInlineSpacing),
                Expanded(
                  child: Text(
                    dauerText,
                    key: ValueKey<String>('spell-instance-dauer-$id'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('spell-instance-dauer-minus-$id'),
                  tooltip: 'Eine Zeiteinheit abziehen',
                  visualDensity: VisualDensity.compact,
                  onPressed: kannZaehlen ? onAdvanceDuration : null,
                  icon: const Icon(Icons.exposure_minus_1, size: 18),
                ),
                IconButton(
                  key: ValueKey<String>('spell-instance-beenden-$id'),
                  tooltip: 'Diese Quelle beenden',
                  visualDensity: VisualDensity.compact,
                  onPressed: onBeenden,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
