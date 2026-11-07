import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Höchstzahl der Treffer in der Katalogsuche für Vor- und Nachteile.
const int kMerkmalSucheMaxTreffer = 80;

/// Durchsucht den Katalog der Vor- und Nachteile nach [begriff].
///
/// Beide Oberflächen nutzen dieselbe Suche: nur aktive Einträge, gefaltet
/// über [suchFaltung] (Umlaute und ihre Umschreibungen fallen zusammen), über
/// Name, Kostentext, Quelle und Marker. Ein leerer [begriff] liefert alle
/// aktiven Einträge; die Liste ist auf [kMerkmalSucheMaxTreffer] gekürzt.
List<HeroTraitDef> sucheMerkmale(Iterable<HeroTraitDef> defs, String begriff) {
  final gesucht = suchFaltung(begriff);
  return defs
      .where((def) => def.active)
      .where(
        (def) =>
            gesucht.isEmpty ||
            suchFaltung(
              [def.name, def.costText, def.source, ...def.markers].join(' '),
            ).contains(gesucht),
      )
      .take(kMerkmalSucheMaxTreffer)
      .toList(growable: false);
}
