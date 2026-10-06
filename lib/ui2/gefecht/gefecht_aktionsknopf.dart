import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_freigabe_rules.dart';

/// Aktionsknopf der Gefechtsansicht mit Status und sichtbarem Grund.
///
/// Der Status stammt aus derselben Prüfung wie Dialog und Ausführung; ein
/// gesperrter oder klärungsbedürftiger Knopf nennt seinen wichtigsten Grund
/// direkt, statt ihn erst im Dialog zu verraten. Gesperrte Knöpfe bleiben
/// antippbar, damit der Dialog alle Gründe vollständig erklären kann.
class GefechtAktionsknopf extends StatelessWidget {
  /// [pruefung] `null` bedeutet, dass der Regelkatalog noch lädt.
  const GefechtAktionsknopf({
    super.key,
    required this.titel,
    required this.pruefung,
    required this.onPressed,
  });

  /// Sichtbarer Aktionsname.
  final String titel;

  /// Gemeinsame Freigabe der Aktion.
  final Gefechtspruefung? pruefung;

  /// Öffnet den Aktionsdialog; `null` sperrt den Knopf.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = pruefung;
    final texte = Theme.of(context).textTheme;
    final grund = p == null || p.status == Gefechtsfreigabe.bereit
        ? null
        : gefechtsHauptgrund(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(titel)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      p == null ? 'Lädt' : gefechtsKnopfstatus(p),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              if (grund != null)
                Text(
                  grund,
                  style: texte.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
