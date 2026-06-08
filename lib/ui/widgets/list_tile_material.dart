import 'package:flutter/material.dart';

/// Stellt fuer ListTile-Familienwidgets einen lokalen Material-Layer bereit.
///
/// Flutter zeichnet ListTile-Hintergruende und Ink-Effekte auf dem naechsten
/// Material-Ancestor. In farbig dekorierten Panels verhindert dieser Wrapper,
/// dass diese Effekte hinter dem Panel verschwinden.
class ListTileMaterial extends StatelessWidget {
  /// Erstellt einen transparenten Material-Layer fuer [child].
  const ListTileMaterial({
    super.key,
    required this.child,
    this.shape,
    this.clipBehavior = Clip.antiAlias,
  });

  /// Das ListTile, SwitchListTile oder ein vergleichbares Kachelwidget.
  final Widget child;

  /// Optionale Form fuer Ink-Clipping und Tile-Hintergruende.
  final ShapeBorder? shape;

  /// Clipping-Verhalten, wenn [shape] gesetzt ist.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final hasShape = shape != null;
    return Material(
      type: MaterialType.transparency,
      shape: shape,
      clipBehavior: hasShape ? clipBehavior : Clip.none,
      child: child,
    );
  }
}
