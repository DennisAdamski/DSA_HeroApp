import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Token der Kartograph-Oberflaeche, wenn der Baum unter ihr liegt; sonst null.
///
/// Bestandsbausteine teilen sich beide Oberflaechen. Mit dieser Abfrage
/// zeichnen sie sich unter Kartograph neu und bleiben in der Codex-Oberflaeche
/// Zeichen fuer Zeichen, wie sie waren. Erkannt wird am Theme: nur Kartograph
/// fuehrt die Erweiterung `KartoTheme` (Wurzeltheme wie Bruecke), das
/// Codex-Theme traegt allein `CodexTheme`.
///
/// Bewusst **nicht** `KartoTheme.of`: das faellt ausserhalb von Kartograph auf
/// die helle Palette zurueck und waere damit immer ein Treffer.
KartoTheme? kartoVariante(BuildContext context) {
  return Theme.of(context).extension<KartoTheme>();
}
