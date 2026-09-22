import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
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
///
/// Farbe und Groesse sind bewusst getrennt verteilt: der **aktuelle** Wert
/// steht gross in Tinte, sein Maximum klein und leise daneben, und die
/// Ressourcenfarbe traegt allein das Symbol und die Balkenfuellung. Traegt
/// stattdessen die ganze Zeile die Ressourcenfarbe, ist nicht mehr erkennbar,
/// welche der beiden Zahlen zaehlt, und vier bunte Zeilen nebeneinander lesen
/// sich als Dekoration statt als Messwerte.
class KartoRessourcenwert extends StatelessWidget {
  /// Erstellt die Anzeige einer einzelnen Ressource.
  const KartoRessourcenwert({
    super.key,
    required this.bezeichnung,
    required this.aktuell,
    required this.maximum,
    this.icon,
    this.farbe,
    this.onBearbeiten,
  });

  /// Ausgeschriebener Name, etwa `Lebenspunkte`.
  final String bezeichnung;

  /// Gespeicherter aktueller Wert; darf negativ oder groesser als [maximum] sein.
  final int aktuell;

  /// Gespeichertes Maximum; `0` bedeutet „kein Balken“, nicht „Division“.
  final int maximum;

  /// Symbol vor der Bezeichnung; traegt zusammen mit dem Balken die Farbe.
  final IconData? icon;

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
    final akzent = farbe ?? karto.schriftLeise;
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
              if (icon != null) ...[
                Icon(icon, size: 16, color: akzent),
                const SizedBox(width: Abstand.knapp),
              ],
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
                    borderRadius: BorderRadius.circular(kKartoRadiusKlein),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.tune,
                        size: 18,
                        color: karto.schriftLeise,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Eine Textzeile aus zwei Spans, nicht zwei Widgets: `find.text`
          // wertet bei `Text.rich` den zusammengesetzten Klartext aus, die
          // Zeile bleibt also als Ganzes auffindbar und vorlesbar.
          Text.rich(
            TextSpan(
              style: texte.wertGross.copyWith(color: karto.schrift),
              children: <InlineSpan>[
                TextSpan(text: '$aktuell'),
                TextSpan(
                  text: ' / $maximum',
                  style: texte.wert.copyWith(color: karto.schriftStumm),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: Abstand.normal),
          Semantics(
            label: bezeichnung,
            value: werteZeile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kKartoRadiusKlein),
              child: LinearProgressIndicator(
                value: _anteil,
                minHeight: 5,
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
