import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';

/// Ein in ein Artefakt gesprochener Zauber in der Zauberliste des Helden.
///
/// Der Zauber gehört dem Gegenstand, nicht dem Helden: Repräsentation, ZfW
/// und ZfP* stammen von dessen Sprecher.
class ArtefaktZauberEintrag {
  /// Erstellt den Eintrag.
  const ArtefaktZauberEintrag({
    required this.artefakt,
    required this.zauber,
    this.ladung,
  });

  /// Inventareintrag mit den Artefaktdaten.
  final HeroInventoryEntry artefakt;

  /// Der gespeicherte Zauber.
  final ArtefaktZauber zauber;

  /// Ladung, zu der der Zauber gehört; `null` bei einem Matrixgeber.
  final ArtefaktLadung? ladung;

  /// Artefaktdaten des Gegenstands.
  ArtefaktDaten get daten => artefakt.artefaktDaten!;

  /// Ob der Gegenstand ausgerüstet ist.
  bool get ausgeruestet => artefakt.istAusgeruestet;

  /// Ob die Matrix irreparabel beschädigt ist.
  bool get defekt => daten.defekt;

  /// Ob die Ladung des Zaubers schon verbraucht ist.
  bool get verbraucht => ladung?.verbraucht ?? false;

  /// Zauberdaten in einer Zeile: Variante, Repräsentation, ZfW, ZfP*, AsP.
  String get detail => [
    if (zauber.variante.trim().isNotEmpty)
      'Variante: ${zauber.variante.trim()}',
    if (zauber.repraesentation.trim().isNotEmpty) zauber.repraesentation.trim(),
    if (zauber.zfw != null) 'ZfW ${zauber.zfw}',
    if (zauber.zfpStern != null) 'ZfP* ${zauber.zfpStern}',
    if (zauber.kostenAsp != null) '${zauber.kostenAsp} AsP',
    if (zauber.pAsP != null) '${zauber.pAsP} pAsP',
  ].join(' · ');
}

/// Alle Zauber aus den Artefakten des Helden, in Inventarreihenfolge.
///
/// Gelistet wird jeder Zauber jedes Artefakts (Matrixgeber und Ladungen von
/// Spruchspeichern), auch wenn der Gegenstand nicht ausgerüstet, beschädigt
/// oder die Ladung verbraucht ist; der Eintrag trägt diesen Status.
/// Gegenstände, die ein Begleiter trägt, gehören nicht zum Helden.
List<ArtefaktZauberEintrag> artefaktZauberListe(HeroSheet hero) => [
  for (final e in hero.inventoryEntries)
    if (e.artefaktDaten != null && e.traegerTyp == InventoryTraeger.held) ...[
      for (final z in e.artefaktDaten!.zauber)
        ArtefaktZauberEintrag(artefakt: e, zauber: z),
      for (final l in e.artefaktDaten!.ladungen)
        for (final z in l.zauber)
          ArtefaktZauberEintrag(artefakt: e, zauber: z, ladung: l),
    ],
];

/// Artefakte, die im Kampf bereitstehen: ausgerüstet, vom Helden getragen und
/// auslösbar (nicht beschädigt, bei Spruchspeichern mit freier Ladung).
List<HeroInventoryEntry> gefechtsArtefakte(HeroSheet hero) => [
  for (final e in hero.inventoryEntries)
    if (e.artefaktDaten != null &&
        e.istAusgeruestet &&
        e.traegerTyp == InventoryTraeger.held &&
        artefaktAusloesbar(e.artefaktDaten!))
      e,
];

/// Zeile für ein Artefakt: Zaubernamen, Kosten bzw. Ladungen und
/// Auslöserdauer.
String artefaktZusammenfassung(ArtefaktDaten daten) {
  if (!artefaktIstSpruchspeicher(daten.art)) {
    return matrixgeberZusammenfassung(daten);
  }
  final aktionen = daten.ausloeserAktionen < 1 ? 1 : daten.ausloeserAktionen;
  final frei = freieLadungen(daten);
  final namen = frei
      .expand((l) => l.zauber)
      .map((z) => z.name.trim())
      .where((n) => n.isNotEmpty)
      .toSet()
      .join(' + ');
  final pAsP = artefaktPAspGesamt(daten);
  return [
    if (namen.isNotEmpty) namen,
    spruchspeicherLadungenText(daten),
    '$aktionen Aktion${aktionen == 1 ? '' : 'en'}',
    if (pAsP != null) '$pAsP pAsP',
  ].join(' · ');
}

/// „2 von 3 Ladungen frei“ bzw. „erloschen“ bzw. „keine Ladung hinterlegt“.
String spruchspeicherLadungenText(ArtefaktDaten daten) {
  if (daten.ladungen.isEmpty) {
    return 'keine Ladung hinterlegt';
  }
  if (spruchspeicherErloschen(daten)) {
    return 'erloschen';
  }
  final frei = freieLadungen(daten).length;
  final gesamt = daten.ladungen.length;
  return '$frei von $gesamt Ladung${gesamt == 1 ? '' : 'en'} frei';
}

/// Zeile für einen Matrixgeber: Zaubernamen, Kosten und Auslöserdauer.
String matrixgeberZusammenfassung(ArtefaktDaten daten) {
  final namen = daten.zauber
      .map((z) => z.name.trim())
      .where((n) => n.isNotEmpty)
      .join(' + ');
  final aktionen = daten.ausloeserAktionen < 1 ? 1 : daten.ausloeserAktionen;
  final pAsP = artefaktPAspGesamt(daten);
  return [
    if (namen.isNotEmpty) namen,
    if (!matrixKostenOffen(daten))
      matrixKostenMitDifferenz(daten)
          ? '${matrixGrundkosten(daten)} AsP ± W6'
          : '${matrixGrundkosten(daten)} AsP',
    '$aktionen Aktion${aktionen == 1 ? '' : 'en'}',
    if (pAsP != null) '$pAsP pAsP',
  ].join(' · ');
}
