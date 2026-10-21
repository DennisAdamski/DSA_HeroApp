import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Kleine Marke mit Symbol und einer Zeile Text, etwa Datum oder Standort.
///
/// Sitzt als Senke unter dem Abschnitt. Mit [onTap] ist die ganze Marke das
/// Tippziel (mindestens 40 dp hoch); ist [leer] gesetzt, lädt sie in der
/// Meerfarbe zum Ergänzen ein statt einen Wert zu behaupten.
class KartoInfoChip extends StatelessWidget {
  /// Erstellt die Marke.
  const KartoInfoChip({
    super.key,
    required this.symbol,
    required this.text,
    this.leer = false,
    this.onTap,
    this.textKey,
  });

  /// Symbol vor dem Text.
  final IconData symbol;

  /// Gezeigter Wert oder Aufforderung.
  final String text;

  /// Ob [text] eine Aufforderung statt eines Werts ist.
  final bool leer;

  /// Öffnet die Bearbeitung; `null` zeigt die Marke nur an.
  final VoidCallback? onTap;

  /// Schlüssel für den Text, damit Tests Wert und Aufforderung unterscheiden.
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final farbe = leer && onTap != null ? karto.meer : karto.schrift;
    final inhalt = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Abstand.normal,
          vertical: Abstand.knapp,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(symbol, size: 16, color: karto.schriftLeise),
            const SizedBox(width: Abstand.knapp),
            Flexible(
              child: Text(
                text,
                key: textKey,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: texte.etikett.copyWith(color: farbe),
              ),
            ),
          ],
        ),
      ),
    );
    return KartoFlaeche(
      stufe: KartoFlaechenstufe.senke,
      klein: true,
      child: onTap == null
          ? inhalt
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(kKartoRadiusKlein),
                child: inhalt,
              ),
            ),
    );
  }
}
