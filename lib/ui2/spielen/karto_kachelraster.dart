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

/// Belegte Rastereinheiten einer Kachel der [breite] bei [spalten] Spalten.
int kartoRasterSpanne(SpielkachelBreite breite, int spalten) =>
    switch (breite) {
      SpielkachelBreite.schmal => 1,
      SpielkachelBreite.mittel => math.min(2, spalten),
      SpielkachelBreite.voll => spalten,
    };

/// Startspalte jeder Kachel, berechnet aus **Nenngewichten** statt Höhen.
///
/// Jede Kachel ([spanne] Spalten, Nennhöhe [gewicht]) landet in der
/// Reihenfolge der Liste an der höchsten freien Stelle, links vor rechts.
/// Weil nur Spanne und Gewicht eingehen, bleibt die Spalte einer Kachel
/// stabil, wenn sich ihre echte Höhe oder die einer anderen Kachel ändert,
/// etwa beim Einklappen oder bei neuen Daten.
List<int> kartoRasterBelegung(
  List<({int spanne, double gewicht})> kacheln,
  int spalten,
) {
  final boden = List<double>.filled(spalten, 0);
  final starts = <int>[];
  for (final kachel in kacheln) {
    final spanne = math.min(kachel.spanne, spalten);
    final (start, oben) = _hoechsteStelle(boden, spanne);
    for (var i = start; i < start + spanne; i++) {
      boden[i] = oben + kachel.gewicht;
    }
    starts.add(start);
  }
  return starts;
}

// Linkeste Stelle, an der [spanne] Spalten am höchsten frei sind.
(int, double) _hoechsteStelle(List<double> boden, int spanne) {
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

/// Raster der Spielansicht (SPIEL-07): Kacheln mit eigener Höhe, dicht gepackt.
///
/// Die Spaltenzahl folgt der Breite ([kartoRasterSpalten]). Jede Kachel
/// belegt ihre Spanne ([KartoRasterKachel]). Die **Spalte** bestimmt
/// [kartoRasterBelegung] aus den Nenngewichten ([KartoRasterKachel.gewicht]),
/// nie aus der echten Höhe: Einklappen oder neue Daten verschieben deshalb
/// nur Kacheln darunter in derselben Spalte, keine wechselt Spalte oder
/// Breite. Die senkrechte Lage folgt dagegen der echten Unterkante der
/// Kacheln darüber. Die Kinder werden mit fester Breite und freier Höhe
/// ausgelegt, ohne Intrinsics, damit Kacheln mit `LayoutBuilder` funktionieren.
/// Fokus- und Lesefolge bleiben die Reihenfolge der Kinder.
///
/// **Lückenschluss:** Beginnt die nächste Kachel einer Spalte tiefer als die
/// Unterkante plus Lücke (weil sie mehrere Spalten überspannt und auf die
/// tiefste wartet), wird die Kachel darüber bis an sie heran gedehnt
/// ([KartoRasterKachel.dehnbar]). Das ändert keine Lage: gedehnt wird nur in
/// vorhandenen Leerraum. Die letzte Kachel einer Spalte behält ihre Höhe.
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
    this.gewicht = 1,
    this.dehnbar = true,
    required super.child,
  });

  /// Gewünschte Breite; wird auf die Spaltenzahl gekappt.
  final SpielkachelBreite breite;

  /// Nennhöhe für die Spaltenwahl; nur das Verhältnis zählt.
  final double gewicht;

  /// Ob die Kachel Leerraum bis zur nächsten Kachel darunter füllen darf.
  ///
  /// `false` etwa für eingeklappte Kacheln, deren Kopf nicht aufgezogen
  /// werden soll.
  final bool dehnbar;

  @override
  void applyParentData(RenderObject renderObject) {
    final daten = renderObject.parentData! as KartoRasterParentData;
    if (daten.breite != breite ||
        daten.gewicht != gewicht ||
        daten.dehnbar != dehnbar) {
      daten
        ..breite = breite
        ..gewicht = gewicht
        ..dehnbar = dehnbar;
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

  /// Nennhöhe für die Spaltenwahl.
  double gewicht = 1;

  /// Ob die Kachel Leerraum unter sich füllen darf.
  bool dehnbar = true;
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
    // Spalten aus den Nenngewichten; die Höhen gehen nicht ein.
    final nenn = <({int spanne, double gewicht})>[];
    for (var c = firstChild; c != null; c = childAfter(c)) {
      final daten = c.parentData! as KartoRasterParentData;
      nenn.add((
        spanne: kartoRasterSpanne(daten.breite, spalten),
        gewicht: daten.gewicht,
      ));
    }
    final starts = kartoRasterBelegung(nenn, spalten);

    // Echte Unterkante je Spalte, samt folgender Lücke.
    final boden = List<double>.filled(spalten, 0);
    // Letzte Kachel je Spalte, um sie an die nächste heran zu dehnen.
    final letzte = List<RenderBox?>.filled(spalten, null);
    // Oberkante der nächsten Kachel darunter, je Kachel die kleinste über
    // ihre Spalten; fehlt der Eintrag, folgt keine Kachel.
    final naechste = <RenderBox, double>{};
    var stelle = 0;
    var child = firstChild;
    while (child != null) {
      final daten = child.parentData! as KartoRasterParentData;
      final spanne = nenn[stelle].spanne;
      final start = starts[stelle++];
      var oben = 0.0;
      for (var i = start; i < start + spanne; i++) {
        oben = math.max(oben, boden[i]);
      }
      final kachelbreite = einheit * spanne + luecke * (spanne - 1);
      child.layout(
        BoxConstraints.tightFor(width: kachelbreite),
        parentUsesSize: true,
      );
      daten.offset = Offset((einheit + luecke) * start, oben);
      for (var i = start; i < start + spanne; i++) {
        final darueber = letzte[i];
        if (darueber != null) {
          naechste[darueber] = math.min(
            naechste[darueber] ?? double.infinity,
            oben,
          );
        }
        letzte[i] = child;
        boden[i] = oben + child.size.height + luecke;
      }
      child = daten.nextSibling;
    }

    // Lückenschluss: Leerraum bis zur nächsten Kachel füllt die Kachel
    // darüber. Die Lagen stehen fest, gedehnt wird nur in freien Raum.
    for (final MapEntry(key: kachel, value: grenze) in naechste.entries) {
      final daten = kachel.parentData! as KartoRasterParentData;
      if (!daten.dehnbar) continue;
      final ziel = grenze - luecke - daten.offset.dy;
      if (ziel <= kachel.size.height + 0.5) continue;
      // Nur eine Mindesthöhe, keine feste: mit fester Höhe wäre die Kachel
      // eine Layoutgrenze, und wachsender Inhalt erreichte das Raster nicht.
      kachel.layout(
        BoxConstraints(
          minWidth: kachel.size.width,
          maxWidth: kachel.size.width,
          minHeight: ziel,
        ),
        parentUsesSize: true,
      );
    }

    final hoehe = firstChild == null ? 0.0 : boden.reduce(math.max) - luecke;
    size = constraints.constrain(Size(breite, math.max(0, hoehe)));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
