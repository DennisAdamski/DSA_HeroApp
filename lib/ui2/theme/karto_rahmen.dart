import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Gerundeter Rahmen mit Messingkante oben, die Kartusche der Dialoge.
///
/// Ein `RoundedRectangleBorder` mit einer zusaetzlichen, farbigen Leiste an
/// der Oberkante. Die Leiste liegt innerhalb der Rundung und wird mit ihr
/// beschnitten, so wie bei `KartoAbschnitt` mit `KartoAkzent.messing`.
///
/// Als `ShapeBorder` statt als Dekoration, damit er ueber `DialogTheme.shape`
/// jeden Dialog erreicht — auch die der Bestandsoberflaeche, ohne dass einer
/// davon angefasst werden muss.
@immutable
class KartoRahmen extends OutlinedBorder {
  /// Erstellt den Rahmen.
  const KartoRahmen({
    super.side = BorderSide.none,
    this.radius = kKartoRadius,
    this.akzent,
    this.akzentStaerke = 3,
  });

  /// Eckenradius.
  final double radius;

  /// Farbe der Oberkante; `null` laesst sie weg.
  final Color? akzent;

  /// Hoehe der Oberkante.
  final double akzentStaerke;

  RoundedRectangleBorder get _basis => RoundedRectangleBorder(
    side: side,
    borderRadius: BorderRadius.circular(radius),
  );

  @override
  EdgeInsetsGeometry get dimensions => _basis.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _basis.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _basis.getOuterPath(rect, textDirection: textDirection);

  // Erst die Kante, dann die Leiste darueber: sonst laege die Kuestenlinie
  // auf dem Messing und liesse nur einen Haarstrich davon stehen.
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    _basis.paint(canvas, rect, textDirection: textDirection);
    final farbe = akzent;
    if (farbe != null && akzentStaerke > 0) {
      canvas.save();
      canvas.clipPath(getOuterPath(rect, textDirection: textDirection));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, akzentStaerke),
        Paint()..color = farbe,
      );
      canvas.restore();
    }
  }

  @override
  KartoRahmen copyWith({
    BorderSide? side,
    double? radius,
    Color? akzent,
    double? akzentStaerke,
  }) {
    return KartoRahmen(
      side: side ?? this.side,
      radius: radius ?? this.radius,
      akzent: akzent ?? this.akzent,
      akzentStaerke: akzentStaerke ?? this.akzentStaerke,
    );
  }

  @override
  KartoRahmen scale(double t) {
    return KartoRahmen(
      side: side.scale(t),
      radius: radius * t,
      akzent: akzent,
      akzentStaerke: akzentStaerke * t,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is KartoRahmen) return _zwischen(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is KartoRahmen) return _zwischen(this, b, t);
    return super.lerpTo(b, t);
  }

  static KartoRahmen _zwischen(KartoRahmen a, KartoRahmen b, double t) {
    return KartoRahmen(
      side: BorderSide.lerp(a.side, b.side, t),
      radius: lerpDouble(a.radius, b.radius, t)!,
      akzent: Color.lerp(a.akzent, b.akzent, t),
      akzentStaerke: lerpDouble(a.akzentStaerke, b.akzentStaerke, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KartoRahmen &&
        other.side == side &&
        other.radius == radius &&
        other.akzent == akzent &&
        other.akzentStaerke == akzentStaerke;
  }

  @override
  int get hashCode => Object.hash(side, radius, akzent, akzentStaerke);
}
