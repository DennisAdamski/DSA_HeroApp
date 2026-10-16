part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

/// Eine Zeile der Basiswerttabelle der Übersicht.
class _DerivedRow {
  const _DerivedRow({
    required this.label,
    required this.variableName,
    required this.statKey,
    required this.current,
    required this.start,
    required this.modifier,
    this.bought,
    this.boughtKey,
    this.herleitung,
  });

  final String label;
  final String variableName;

  /// Schluessel fuer benannte Modifikatoren (z.B. 'lep', 'au', 'iniBase').
  final String statKey;
  final int current;

  /// Grundwert aus der Herleitung (Spalte „Start“).
  final int start;

  /// Alles außer Grundwert und Zukauf (Spalte „Modifikator“).
  final int modifier;
  final int? bought;
  final String? boughtKey;

  /// Herleitung des Regelmoduls, im Modifikatordialog angezeigt (ARCH-04).
  final Herleitung? herleitung;
}
