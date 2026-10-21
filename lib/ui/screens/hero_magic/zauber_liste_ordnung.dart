import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';

// Sortierung und Merkmalsfilter der Zaubertabelle im Magie-Tab
// (reine Praesentationslogik ohne Regelrechnung).

/// Sortierkriterium der Zaubertabelle.
enum ZauberSortierung { name, zfw }

/// Liefert die eindeutigen Merkmale der uebergebenen Zauber, alphabetisch.
List<String> merkmaleDerZauber(Iterable<SpellDef> defs) {
  final merkmale = <String>{
    for (final def in defs) ...parseSpellTraits(def.traits),
  };
  return merkmale.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Filtert und sortiert die Zauber-IDs fuer die Tabellenanzeige.
///
/// Mit [merkmal] bleiben nur Zauber, die dieses Merkmal tragen; Zauber ohne
/// Katalogeintrag fallen dann heraus. Die ZfW-Sortierung liest
/// [zfwJeZauber] (fehlend = 0), Gleichstand ordnet aufsteigend nach Name.
/// [aufsteigend] dreht nur das Hauptkriterium.
List<String> ordneZauberliste({
  required Iterable<String> ids,
  required Map<String, SpellDef> defs,
  required Map<String, int> zfwJeZauber,
  required ZauberSortierung sortierung,
  required bool aufsteigend,
  String? merkmal,
}) {
  final gefiltert = merkmal == null
      ? ids.toList()
      : ids.where((id) {
          final def = defs[id];
          return def != null && parseSpellTraits(def.traits).contains(merkmal);
        }).toList();

  String nameVon(String id) => (defs[id]?.name ?? id).toLowerCase();
  int nachName(String a, String b) => nameVon(a).compareTo(nameVon(b));
  final richtung = aufsteigend ? 1 : -1;

  return gefiltert..sort((a, b) {
    switch (sortierung) {
      case ZauberSortierung.name:
        return richtung * nachName(a, b);
      case ZauberSortierung.zfw:
        final vergleich = (zfwJeZauber[a] ?? 0).compareTo(zfwJeZauber[b] ?? 0);
        return vergleich != 0 ? richtung * vergleich : nachName(a, b);
    }
  });
}
