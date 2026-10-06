import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_freigabe_rules.dart';

/// Ein Eintrag der Schnellleiste mit derselben Prüfung wie der Aktionsknopf.
class GefechtSchnellaktion {
  /// [pruefung] `null` bedeutet: ohne Regelprüfung (etwa Rundenwechsel).
  const GefechtSchnellaktion({
    required this.titel,
    required this.symbol,
    required this.onPressed,
    this.pruefung,
    this.schluessel,
  });
  final String titel;
  final IconData symbol;
  final VoidCallback? onPressed;
  final Gefechtspruefung? pruefung;

  /// Stabiler Schlüssel für Tests und Fokus.
  final String? schluessel;
}

/// Feste untere Leiste der schmalen Gefechtsansicht.
///
/// Die häufigsten Handlungen bleiben unabhängig von der Scrollposition mit
/// einem Tipp erreichbar. Gesperrte Einträge sind deaktiviert; ihre Gründe
/// nennt der gleichnamige Knopf im jeweiligen Abschnitt.
class GefechtSchnellleiste extends StatelessWidget {
  /// Zeigt die [aktionen] gleich breit nebeneinander.
  const GefechtSchnellleiste({super.key, required this.aktionen});

  /// Einträge von links nach rechts.
  final List<GefechtSchnellaktion> aktionen;

  // Zielwert nur bei bereiter Aktion; sonst derselbe Status wie am Knopf.
  static String? _unterzeile(Gefechtspruefung? p) => switch (p?.status) {
    Gefechtsfreigabe.bereit => p!.zielwert?.toString(),
    Gefechtsfreigabe.pruefen => gefechtsKnopfstatus(p!),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              for (final a in aktionen)
                Expanded(
                  child: TextButton(
                    key: a.schluessel == null
                        ? null
                        : ValueKey<String>(a.schluessel!),
                    onPressed: a.pruefung?.status == Gefechtsfreigabe.gesperrt
                        ? null
                        : a.onPressed,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.symbol),
                        Text(
                          a.titel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: texte.labelSmall,
                        ),
                        if (_unterzeile(a.pruefung) case final zeile?)
                          Text(
                            zeile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: texte.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
