import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';

/// Eine laufende Zauberwirkung im Gefecht: Titel, Eckdaten und Bedienknöpfe.
///
/// Rein darstellend. Alle Texte kommen aus den vorhandenen Regelfunktionen
/// (`beschreibeEffektInstanz`, `describeSpellDuration`, `beschreibeSchutzVorrat`);
/// Schreiben läuft über die Callbacks der Kachel. Alte Einzelwerte
/// (Legacy-Wirkungen) tragen keine Callbacks und werden im Effektedialog bedient.
class GefechtWirkungszeile extends StatelessWidget {
  /// Erstellt die Zeile für genau eine Wirkung.
  const GefechtWirkungszeile({
    super.key,
    required this.instanz,
    required this.titel,
    this.ueberlagert = const <String>[],
    this.mussAufrechterhaltenWerden = false,
    this.gesperrt = false,
    this.onWirktChanged,
    this.onDauerMinus,
    this.onDauer,
    this.onEinsetzen,
    this.einsetzenLabel = 'Einsetzen',
    this.onSchutz,
    this.onBeenden,
  });

  /// Anzuzeigende Wirkung.
  final SpellEffectInstance instanz;

  /// Name des Zaubers, bei mehreren Quellen mit laufender Nummer.
  final String titel;

  /// Eigenschaften, die eine bessere Quelle überlagert.
  final List<String> ueberlagert;

  /// Der Zauber verlangt Aufrechterhaltung (Katalog „(A)“).
  final bool mussAufrechterhaltenWerden;

  /// Sperrt alle Knöpfe, solange eine andere Handlung läuft.
  final bool gesperrt;

  /// Wirkung ein- oder ausschalten; `null` blendet den Schalter aus.
  final ValueChanged<bool>? onWirktChanged;

  /// Eine Zeiteinheit abziehen; `null` blendet den Knopf aus.
  final VoidCallback? onDauerMinus;

  /// Wirkungsdauer festlegen; `null` blendet den Knopf aus.
  final VoidCallback? onDauer;

  /// Einmalige Wirkung einsetzen; `null` blendet den Knopf aus.
  final VoidCallback? onEinsetzen;

  /// Beschriftung des Einsetzen-Knopfs.
  final String einsetzenLabel;

  /// Schutzvorrat korrigieren; `null` blendet den Knopf aus.
  final VoidCallback? onSchutz;

  /// Beendet nur diese Wirkung; `null` blendet den Knopf aus.
  final VoidCallback? onBeenden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = instanz.id;
    final beschreibung = beschreibeEffektInstanz(instanz);
    final dauer = instanz.duration;
    final dauerText = describeSpellDuration(dauer);
    final abgelaufen = dauer?.isExpired ?? false;
    final kannZaehlen =
        dauer != null &&
        dauer.amount > 0 &&
        !dauer.isPermanent &&
        dauer.remaining > 0;
    final eckdaten = [
      if (instanz.quelle != null) 'Quelle: ${instanz.quelle}',
      if (instanz.ziel != null) 'Ziel: ${instanz.ziel}',
      if (beschreibung.isNotEmpty) beschreibung,
      if (kSchutzZauberIds.contains(instanz.effectId))
        beschreibeSchutzVorrat(instanz),
      if (instanz.unterdrueckt) 'unterdrückt',
      if (ueberlagert.isNotEmpty)
        'zählt nicht für ${ueberlagert.join(', ')} (bessere Quelle)',
      if (mussAufrechterhaltenWerden) 'aufrechterhalten',
    ];
    final farbeLeise = theme.colorScheme.onSurfaceVariant;
    return Padding(
      key: ValueKey<String>('gefecht-wirkung-$id'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: instanz.unterdrueckt
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (onWirktChanged != null)
                Switch(
                  key: ValueKey<String>('gefecht-wirkung-wirkt-$id'),
                  value: !instanz.unterdrueckt,
                  onChanged: gesperrt ? null : onWirktChanged,
                ),
            ],
          ),
          if (eckdaten.isNotEmpty)
            Text(
              eckdaten.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: farbeLeise),
            ),
          Row(
            children: [
              Icon(Icons.timelapse_outlined, size: 16, color: farbeLeise),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  abgelaufen
                      ? '$dauerText – Ende am Tisch bestätigen'
                      : dauerText,
                  key: ValueKey<String>('gefecht-wirkung-dauer-$id'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: abgelaufen ? theme.colorScheme.error : farbeLeise,
                  ),
                ),
              ),
              if (onDauerMinus != null)
                IconButton(
                  key: ValueKey<String>('gefecht-wirkung-minus-$id'),
                  tooltip: 'Eine Zeiteinheit abziehen',
                  visualDensity: VisualDensity.compact,
                  onPressed: gesperrt || !kannZaehlen ? null : onDauerMinus,
                  icon: const Icon(Icons.exposure_minus_1, size: 18),
                ),
              if (onSchutz != null)
                IconButton(
                  key: ValueKey<String>('gefecht-wirkung-schutz-$id'),
                  tooltip: 'Schutzvorrat anpassen',
                  visualDensity: VisualDensity.compact,
                  onPressed: gesperrt ? null : onSchutz,
                  icon: const Icon(Icons.shield_outlined, size: 18),
                ),
              if (onDauer != null)
                IconButton(
                  key: ValueKey<String>('gefecht-wirkung-dauer-edit-$id'),
                  tooltip: 'Wirkungsdauer festlegen',
                  visualDensity: VisualDensity.compact,
                  onPressed: gesperrt ? null : onDauer,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                ),
              if (onBeenden != null)
                IconButton(
                  key: ValueKey<String>('gefecht-wirkung-beenden-$id'),
                  tooltip: 'Diese Wirkung beenden',
                  visualDensity: VisualDensity.compact,
                  onPressed: gesperrt ? null : onBeenden,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                ),
            ],
          ),
          if (onEinsetzen != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: ValueKey<String>('gefecht-wirkung-einsetzen-$id'),
                onPressed: gesperrt ? null : onEinsetzen,
                child: Text(einsetzenLabel),
              ),
            ),
        ],
      ),
    );
  }
}
