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

/// Akzent epischer Sonderfertigkeiten und Grossmeister.
///
/// Klassisch das Goldgelb `0xFFB8860B`, das drei Stellen bisher je selbst
/// kopierten; unter Kartograph Messing, der Akzent der Oberflaeche.
Color epischerAkzent(BuildContext context) {
  return kartoVariante(context)?.messing ?? const Color(0xFFB8860B);
}

/// Radius, der unter Kartograph auf die zwei Stufen der Oberflaeche faellt.
///
/// Klassisch bleibt [klassisch]; unter Kartograph wird daraus `kKartoRadius`,
/// oder `kKartoRadiusKlein` fuer kleine Bedienelemente ([klein]).
double kartoRadiusOder(
  BuildContext context,
  double klassisch, {
  bool klein = false,
}) {
  if (kartoVariante(context) == null) return klassisch;
  return klein ? kKartoRadiusKlein : kKartoRadius;
}
