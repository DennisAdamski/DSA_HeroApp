import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Darstellender Ressourcenwert mit Balken.
///
/// Das Widget kennt weder Persistenz noch DSA-Grenzen: es zeigt genau die
/// uebergebenen Zahlen und meldet den Bearbeitungswunsch nach oben. Der
/// Balkenanteil ist **Darstellung** — er wird auf 0..1 begrenzt, damit ein
/// negativer oder ueberheilter Wert ueberhaupt zeichenbar bleibt. Der
/// gespeicherte Wert selbst wird dafuer nie gekuerzt, sondern unveraendert
/// als Text ausgegeben.
class KartoRessourcenwert extends StatelessWidget {
  /// Erstellt die Anzeige einer einzelnen Ressource.
  const KartoRessourcenwert({
    super.key,
    required this.bezeichnung,
    required this.aktuell,
    required this.maximum,
    this.farbe,
    this.onBearbeiten,
  });

  /// Ausgeschriebener Name, etwa `Lebenspunkte`.
  final String bezeichnung;

  /// Gespeicherter aktueller Wert; darf negativ oder groesser als [maximum] sein.
  final int aktuell;

  /// Gespeichertes Maximum; `0` bedeutet „kein Balken“, nicht „Division“.
  final int maximum;

  /// Ressourcenfarbe. `null` bleibt bewusst einfarbig: nur die drei Token
  /// [KartoTheme.lebensenergie], [KartoTheme.astralenergie] und
  /// [KartoTheme.ausdauer] stehen in der Spielansicht fuer sich.
  final Color? farbe;

  /// Oeffnet die Bearbeitung. `null` blendet das Bearbeitungsziel aus.
  final VoidCallback? onBearbeiten;

  // Anteil fuer den Balken; ausserhalb von 0..1 gibt es nichts zu zeichnen.
  double get _anteil {
    if (maximum <= 0) return 0;
    return (aktuell / maximum).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final akzent = farbe ?? karto.schrift;
    final werteZeile = '$aktuell / $maximum';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Abstand.weit,
        vertical: Abstand.normal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  bezeichnung,
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onBearbeiten != null)
                Tooltip(
                  message: '$bezeichnung ändern',
                  child: InkWell(
                    onTap: onBearbeiten,
                    borderRadius: BorderRadius.circular(kKartoRadius),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.tune, size: 20),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            werteZeile,
            style: texte.wertGross.copyWith(color: akzent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Abstand.knapp),
          Semantics(
            label: bezeichnung,
            value: werteZeile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kKartoRadius),
              child: LinearProgressIndicator(
                value: _anteil,
                minHeight: Strich.ufer,
                backgroundColor: karto.raster,
                valueColor: AlwaysStoppedAnimation<Color>(akzent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
