import 'package:flutter/material.dart';

/// Wiederverwendbares Split-View-Layout fuer Tablet- und breite Screens.
class CodexSplitView extends StatelessWidget {
  /// Erstellt eine mehrspaltige Arbeitsflaeche mit optionaler Rail.
  const CodexSplitView({
    super.key,
    required this.primary,
    this.rail,
    this.railWidth = 0,
    this.primaryWidth,
    this.secondary,
    this.secondaryWidth,
    this.showDividers = true,
  });

  /// Hauptinhalt der Arbeitsflaeche.
  final Widget primary;

  /// Optionale Rail oder kompakte Navigation links.
  final Widget? rail;

  /// Feste Breite der Rail.
  final double railWidth;

  /// Optionale feste Breite des Primaerbereichs.
  final double? primaryWidth;

  /// Optionaler Sekundaerbereich rechts.
  final Widget? secondary;

  /// Feste Breite des Sekundaerbereichs.
  final double? secondaryWidth;

  /// Steuert vertikale Trenner zwischen den Bereichen.
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (rail != null && railWidth > 0) {
      children.add(SizedBox(width: railWidth, child: rail));
      if (showDividers) {
        children.add(const VerticalDivider(width: 1));
      }
    }

    final primaryChild = primaryWidth == null
        ? Expanded(child: primary)
        : SizedBox(width: primaryWidth, child: primary);
    children.add(primaryChild);

    if (secondary != null) {
      if (showDividers) {
        children.add(const VerticalDivider(width: 1));
      }
      final secondaryChild = secondaryWidth == null
          ? Expanded(child: secondary!)
          : SizedBox(width: secondaryWidth, child: secondary!);
      children.add(secondaryChild);
    }

    return Row(children: children);
  }
}
