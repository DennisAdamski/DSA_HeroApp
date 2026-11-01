import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

/// Mindestbreite einer Rastereinheit der Spielansicht.
///
/// Schmale Kacheln wie Kampf oder Dabei sind auf diese Breite ausgelegt; bei
/// weniger Platz rückt das Raster auf eine Spalte weniger.
const double kRasterEinheitMin = 300;

/// Höchstzahl der Rasterspalten; darüber werden die Einheiten nur breiter.
const int kRasterSpaltenMax = 4;

/// Spaltenzahl des Rasters für die verfügbare [breite].
int kartoRasterSpalten(double breite, {double luecke = Abstand.bahn}) {
  if (!breite.isFinite) return 1;
  final spalten = ((breite + luecke) / (kRasterEinheitMin + luecke)).floor();
  return spalten.clamp(1, kRasterSpaltenMax);
}

/// Höhenvorteil, ab dem eine mittlere Kachel schmal in eine Lücke ausweicht.
///
/// Darunter lohnt das Ausweichen nicht: die Kachel würde schmaler und damit
/// höher, ohne sichtbar Platz zu sparen.
const double kRasterAusweichenAb = 96;

/// Belegte Rastereinheiten einer Kachel der [breite] bei [spalten] Spalten.
int kartoRasterSpanne(SpielkachelBreite breite, int spalten) =>
    switch (breite) {
      SpielkachelBreite.schmal => 1,
      SpielkachelBreite.mittel => math.min(2, spalten),
      SpielkachelBreite.voll => spalten,
    };

/// Raster der Spielansicht (SPIEL-07): Kacheln mit eigener Höhe, dicht gepackt.
///
/// Die Spaltenzahl folgt der Breite ([kartoRasterSpalten]). Jede Kachel
/// belegt ihre Spanne ([KartoRasterKachel]) und landet in der Reihenfolge der
/// Kinder an der höchsten freien Stelle, links vor rechts. So entstehen unter
/// kurzen Kacheln keine Löcher wie in einem Zeilenraster. Bleibt neben
/// mittleren Kacheln nur eine Spalte frei, könnte keine von ihnen die Lücke
/// füllen. Folgt keine schmale Kachel mehr, rückt eine mittlere Kachel, die
/// schmal sein darf ([KartoRasterKachel.ausweichen]), schmal hinein, sobald
/// sie dort mindestens [kRasterAusweichenAb] höher steht. Gespeichert bleibt ihre
/// gewählte Breite; sie gilt wieder, sobald die Lücke fehlt. Die Kinder werden mit
/// fester Breite und freier Höhe ausgelegt, ohne Intrinsics, damit Kacheln
/// mit `LayoutBuilder` funktionieren. Fokus- und Lesefolge bleiben die
/// Reihenfolge der Kinder.
class KartoKachelraster extends MultiChildRenderObjectWidget {
  /// Raster aus [children], die je in einer [KartoRasterKachel] stecken.
  const KartoKachelraster({
    super.key,
    this.luecke = Abstand.bahn,
    super.children,
  });

  /// Abstand zwischen Kacheln, waagerecht wie senkrecht.
  final double luecke;

  @override
  RenderKartoKachelraster createRenderObject(BuildContext context) =>
      RenderKartoKachelraster(luecke: luecke);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderKartoKachelraster renderObject,
  ) {
    renderObject.luecke = luecke;
  }
}

/// Legt die [breite] einer Kachel im [KartoKachelraster] fest.
class KartoRasterKachel extends ParentDataWidget<KartoRasterParentData> {
  /// Kachel [child] mit der Breite [breite].
  const KartoRasterKachel({
    super.key,
    required this.breite,
    this.ausweichen = false,
    required super.child,
  });

  /// Gewünschte Breite; wird auf die Spaltenzahl gekappt.
  final SpielkachelBreite breite;

  /// Ob eine mittlere Kachel schmal in eine Lücke ausweichen darf.
  final bool ausweichen;

  @override
  void applyParentData(RenderObject renderObject) {
    final daten = renderObject.parentData! as KartoRasterParentData;
    if (daten.breite != breite || daten.ausweichen != ausweichen) {
      daten
        ..breite = breite
        ..ausweichen = ausweichen;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => KartoKachelraster;
}

/// Lage und Breite einer Kachel im Raster.
class KartoRasterParentData extends ContainerBoxParentData<RenderBox> {
  /// Breite der Kachel; ohne Angabe eine Einheit.
  SpielkachelBreite breite = SpielkachelBreite.schmal;

  /// Ob die Kachel schmal in eine Lücke ausweichen darf.
  bool ausweichen = false;
}

/// Render-Objekt zu [KartoKachelraster].
class RenderKartoKachelraster extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, KartoRasterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, KartoRasterParentData> {
  /// Raster mit der Lücke [luecke].
  RenderKartoKachelraster({required this._luecke});

  double _luecke;

  /// Abstand zwischen Kacheln.
  double get luecke => _luecke;
  set luecke(double wert) {
    if (wert == _luecke) return;
    _luecke = wert;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! KartoRasterParentData) {
      child.parentData = KartoRasterParentData();
    }
  }

  @override
  void performLayout() {
    final breite = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : constraints.minWidth;
    final spalten = kartoRasterSpalten(breite, luecke: luecke);
    final einheit = (breite - luecke * (spalten - 1)) / spalten;
    // Unterkante je Spalte, samt folgender Lücke.
    final boden = List<double>.filled(spalten, 0);

    // Wie viele schmale Kacheln noch folgen: solange eine kommt, füllt sie
    // die Lücke, und keine mittlere Kachel muss dafür schmaler werden.
    var schmaleDanach = 0;
    var zaehler = firstChild;
    while (zaehler != null) {
      final daten = zaehler.parentData! as KartoRasterParentData;
      if (kartoRasterSpanne(daten.breite, spalten) == 1) schmaleDanach++;
      zaehler = daten.nextSibling;
    }

    var child = firstChild;
    while (child != null) {
      final daten = child.parentData! as KartoRasterParentData;
      var spanne = kartoRasterSpanne(daten.breite, spalten);
      if (spanne == 1) schmaleDanach--;
      var (beste, besteHoehe) = _hoechsteStelle(boden, spanne);
      if (daten.ausweichen &&
          schmaleDanach == 0 &&
          daten.breite == SpielkachelBreite.mittel &&
          spanne > 1) {
        final (start, oben) = _hoechsteStelle(boden, 1);
        if (besteHoehe - oben >= kRasterAusweichenAb) {
          spanne = 1;
          beste = start;
          besteHoehe = oben;
        }
      }
      final kachelbreite = einheit * spanne + luecke * (spanne - 1);
      child.layout(
        BoxConstraints.tightFor(width: kachelbreite),
        parentUsesSize: true,
      );
      daten.offset = Offset((einheit + luecke) * beste, besteHoehe);
      for (var i = beste; i < beste + spanne; i++) {
        boden[i] = besteHoehe + child.size.height + luecke;
      }
      child = daten.nextSibling;
    }

    final hoehe = firstChild == null ? 0.0 : boden.reduce(math.max) - luecke;
    size = constraints.constrain(Size(breite, math.max(0, hoehe)));
  }

  // Linkeste Stelle, an der [spanne] Spalten am höchsten frei sind.
  static (int, double) _hoechsteStelle(List<double> boden, int spanne) {
    var beste = 0;
    var besteHoehe = double.infinity;
    for (var start = 0; start + spanne <= boden.length; start++) {
      var oben = 0.0;
      for (var i = start; i < start + spanne; i++) {
        oben = math.max(oben, boden[i]);
      }
      if (oben < besteHoehe) {
        besteHoehe = oben;
        beste = start;
      }
    }
    return (beste, besteHoehe);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
