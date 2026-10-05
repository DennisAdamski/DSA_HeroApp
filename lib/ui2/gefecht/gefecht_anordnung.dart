import 'package:flutter/material.dart';

/// Breite, ab der die Gefechtsansicht zweispaltig wird.
const kGefechtZweispaltig = 744.0;

/// Breite, ab der die Gefechtsansicht dreispaltig wird.
const kGefechtDreispaltig = 1100.0;

/// Ordnet die Abschnitte der Gefechtsansicht nach Häufigkeit der Nutzung.
///
/// Schmal stehen Vitalwerte vor den Aktionen und die Verteidigung direkt
/// nach dem Angriff, weil Parade und Ausweichen ebenso häufig sind wie die
/// Attacke. Begegnung (Gegner, gemeinsame Initiative) und Ausrüstung folgen
/// danach. Breite Fenster verteilen dieselben Abschnitte auf Spalten; die
/// Reihenfolge innerhalb einer Spalte bleibt gleich.
class GefechtAnordnung extends StatelessWidget {
  /// Alle Abschnitte werden fertig gebaut übergeben; leere Listen entfallen.
  const GefechtAnordnung({
    super.key,
    required this.breite,
    required this.vitalwerte,
    required this.angriff,
    required this.verteidigung,
    required this.manoever,
    required this.magie,
    required this.weitere,
    required this.begegnung,
    required this.ausruestung,
  });

  /// Verfügbare Breite aus dem umgebenden `LayoutBuilder`.
  final double breite;
  final Widget vitalwerte, angriff, verteidigung, manoever, magie;

  /// Weitere Aktionen einschließlich Abwarten.
  final List<Widget> weitere;

  /// Gegner und gemeinsame Initiative.
  final List<Widget> begegnung;
  final Widget ausruestung;

  // Einheitlicher Abstand zwischen gestapelten Abschnitten.
  Widget _spalte(List<Widget> kinder) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final k in kinder)
        Padding(padding: const EdgeInsets.only(bottom: 16), child: k),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (breite < kGefechtZweispaltig) {
      return _spalte([
        vitalwerte,
        angriff,
        verteidigung,
        manoever,
        magie,
        ...weitere,
        ...begegnung,
        ausruestung,
      ]);
    }
    if (breite < kGefechtDreispaltig) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _spalte([angriff, manoever, magie])),
          const SizedBox(width: 16),
          Expanded(
            child: _spalte([
              vitalwerte,
              verteidigung,
              ...weitere,
              ...begegnung,
              ausruestung,
            ]),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _spalte([vitalwerte, ausruestung, ...begegnung]),
        ),
        const SizedBox(width: 16),
        Expanded(flex: 4, child: _spalte([angriff, manoever, magie])),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: _spalte([verteidigung, ...weitere])),
      ],
    );
  }
}
