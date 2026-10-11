import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';

/// Ein in ein Artefakt gesprochener Zauber in der Zauberliste des Helden.
///
/// Der Zauber gehört dem Gegenstand, nicht dem Helden: Repräsentation, ZfW
/// und ZfP* stammen von dessen Sprecher.
class ArtefaktZauberEintrag {
  /// Erstellt den Eintrag.
  const ArtefaktZauberEintrag({required this.artefakt, required this.zauber});

  /// Inventareintrag mit den Artefaktdaten.
  final HeroInventoryEntry artefakt;

  /// Der gespeicherte Zauber.
  final ArtefaktZauber zauber;

  /// Artefaktdaten des Gegenstands.
  ArtefaktDaten get daten => artefakt.artefaktDaten!;

  /// Ob der Gegenstand ausgerüstet ist.
  bool get ausgeruestet => artefakt.istAusgeruestet;

  /// Ob die Matrix irreparabel beschädigt ist.
  bool get defekt => daten.defekt;

  /// Zauberdaten in einer Zeile: Variante, Repräsentation, ZfW, ZfP*, AsP.
  String get detail => [
    if (zauber.variante.trim().isNotEmpty)
      'Variante: ${zauber.variante.trim()}',
    if (zauber.repraesentation.trim().isNotEmpty) zauber.repraesentation.trim(),
    if (zauber.zfw != null) 'ZfW ${zauber.zfw}',
    if (zauber.zfpStern != null) 'ZfP* ${zauber.zfpStern}',
    if (zauber.kostenAsp != null) '${zauber.kostenAsp} AsP',
  ].join(' · ');
}

/// Alle Zauber aus den Artefakten des Helden, in Inventarreihenfolge.
///
/// Gelistet wird jeder Zauber jedes Matrixgebers, auch wenn der Gegenstand
/// nicht ausgerüstet oder beschädigt ist; der Eintrag trägt diesen Status.
/// Gegenstände, die ein Begleiter trägt, gehören nicht zum Helden.
List<ArtefaktZauberEintrag> artefaktZauberListe(HeroSheet hero) => [
  for (final e in hero.inventoryEntries)
    if (e.artefaktDaten != null && e.traegerTyp == InventoryTraeger.held)
      for (final z in e.artefaktDaten!.zauber)
        ArtefaktZauberEintrag(artefakt: e, zauber: z),
];

/// Matrixgeber, die im Kampf bereitstehen: ausgerüstet, vom Helden getragen
/// und nicht beschädigt.
List<HeroInventoryEntry> gefechtsMatrixgeber(HeroSheet hero) => [
  for (final e in hero.inventoryEntries)
    if (e.artefaktDaten != null &&
        e.istAusgeruestet &&
        e.traegerTyp == InventoryTraeger.held &&
        !e.artefaktDaten!.defekt)
      e,
];

/// Zeile für einen Matrixgeber: Zaubernamen, Kosten und Auslöserdauer.
String matrixgeberZusammenfassung(ArtefaktDaten daten) {
  final namen = daten.zauber
      .map((z) => z.name.trim())
      .where((n) => n.isNotEmpty)
      .join(' + ');
  final aktionen = daten.ausloeserAktionen < 1 ? 1 : daten.ausloeserAktionen;
  return [
    if (namen.isNotEmpty) namen,
    if (!matrixKostenOffen(daten))
      matrixKostenMitDifferenz(daten)
          ? '${matrixGrundkosten(daten)} AsP ± W6'
          : '${matrixGrundkosten(daten)} AsP',
    '$aktionen Aktion${aktionen == 1 ? '' : 'en'}',
  ].join(' · ');
}
