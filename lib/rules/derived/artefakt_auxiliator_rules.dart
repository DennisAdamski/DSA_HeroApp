import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';

// Regeln für Zaubertalismane (Auxiliatoren; Wege der Alchimie 2. Auflage
// S. 88; Stäbe, Ringe, Dschinnenlampen S. 12): Der Anwender spricht den Zauber
// selbst (Zauberdauer, eigene Probe) und lässt zusätzlich Astralenergie in das
// Artefakt fließen. Die Matrix des Auxiliators harmonisiert die Matrix der
// gesprochenen Formel und stellt zusätzliche ZfP* zur Verfügung – nur, wenn
// der Spruch auch ohne ihn gelungen wäre. Gewürfelt wird in der Oberfläche.

/// Zuschlag auf den Ausfallwurf, wenn ein misslungener Spruch durch den
/// Auxiliator geleitet wird.
const int kAuxiliatorAusfallAufschlagMisslungen = 2;

/// Ergebnis der ZfP*-Berechnung eines Auxiliators.
class AuxiliatorBerechnung {
  /// Erstellt ein Ergebnis.
  const AuxiliatorBerechnung({
    required this.bonus,
    this.halbiert = false,
    this.gedeckelt = false,
    this.zfwFehlt = false,
    this.nichtGelungen = false,
    this.ohneGespeicherteZfp = false,
  });

  /// Zusätzliche ZfP*, die der Auxiliator liefert.
  final int bonus;

  /// Ob die gespeicherten ZfP* wegen fremder Repräsentation halbiert wurden.
  final bool halbiert;

  /// Ob der ZfW des Anwenders den Bonus begrenzt hat.
  final bool gedeckelt;

  /// Ob der ZfW des Anwenders fehlt und deshalb keine Begrenzung gilt.
  final bool zfwFehlt;

  /// Ob der Spruch ohne Auxiliator misslungen wäre: dann gibt es keinen Bonus.
  final bool nichtGelungen;

  /// Ob im Artefakt keine ZfP* gespeichert sind.
  final bool ohneGespeicherteZfp;
}

/// Zusätzliche ZfP*, die ein Auxiliator zu einem gelungenen Spruch beiträgt.
///
/// Der Bonus sind die im Artefakt gespeicherten ZfP* ([gespeicherteZfp]),
/// höchstens so viele wie der ZfW des Anwenders im gesprochenen Zauber
/// ([anwenderZfw]). Gehören gesprochener und gespeicherter Spruch nicht zur
/// selben Repräsentation ([gleicheRepraesentation]), kommt nur die Hälfte der
/// gespeicherten ZfP* zur Wirkung (abgerundet; die Regel nennt keine
/// Rundung). Ein Spruch, der ohne den Auxiliator misslungen wäre
/// ([spruchGelungen] ist `false`), erhält keinen Bonus.
AuxiliatorBerechnung berechneAuxiliatorBonus({
  required int? gespeicherteZfp,
  required int? anwenderZfw,
  required bool gleicheRepraesentation,
  required bool spruchGelungen,
}) {
  if (!spruchGelungen) {
    return const AuxiliatorBerechnung(bonus: 0, nichtGelungen: true);
  }
  if (gespeicherteZfp == null || gespeicherteZfp <= 0) {
    return const AuxiliatorBerechnung(bonus: 0, ohneGespeicherteZfp: true);
  }
  var wirksam = gespeicherteZfp;
  var halbiert = false;
  if (!gleicheRepraesentation) {
    wirksam = wirksam ~/ 2;
    halbiert = true;
  }
  if (anwenderZfw == null) {
    return AuxiliatorBerechnung(
      bonus: wirksam,
      halbiert: halbiert,
      zfwFehlt: true,
    );
  }
  final deckel = anwenderZfw < 0 ? 0 : anwenderZfw;
  final gedeckelt = wirksam > deckel;
  return AuxiliatorBerechnung(
    bonus: gedeckelt ? deckel : wirksam,
    halbiert: halbiert,
    gedeckelt: gedeckelt,
  );
}

/// Zuschlag auf den Ausfallwurf: +2, wenn ein misslungener Spruch durch den
/// Auxiliator geleitet wird.
int auxiliatorAusfallAufschlag({required bool spruchGelungen}) =>
    spruchGelungen ? 0 : kAuxiliatorAusfallAufschlagMisslungen;

/// AsP, die in das Artefakt fließen: [grundkosten] des Spruchs plus [w3]
/// zusätzliche AsP für die Harmonisierung.
int auxiliatorKosten({required int grundkosten, required int w3}) =>
    (grundkosten < 0 ? 0 : grundkosten) + w3;

/// Ob zwei Repräsentationsangaben dieselbe Repräsentation nennen.
///
/// Verglichen wird ohne Rücksicht auf Groß- und Kleinschreibung und Leerraum.
/// Fehlt eine der Angaben, ist die Übereinstimmung unbekannt (`null`).
bool? gleicheRepraesentation(String anwender, String gespeichert) {
  final a = anwender.trim().toLowerCase();
  final g = gespeichert.trim().toLowerCase();
  if (a.isEmpty || g.isEmpty) {
    return null;
  }
  return a == g;
}

/// Prüfergebnis vor dem Einsatz eines Auxiliators.
class AuxiliatorPruefung {
  /// Erstellt ein Prüfergebnis.
  const AuxiliatorPruefung({this.sperrgrund, this.hinweise = const <String>[]});

  /// Grund, warum es nicht geht; `null`, wenn es geht.
  final String? sperrgrund;

  /// Hinweise, die den Einsatz nicht verhindern (Meisterentscheid).
  final List<String> hinweise;

  /// Ob der Einsatz möglich ist.
  bool get moeglich => sperrgrund == null;
}

/// Prüft, ob der Zaubertalisman [daten] eingesetzt werden kann.
///
/// Ein beschädigtes Artefakt sperrt. Fehlende Zauber, Zauberkunde (kein
/// AsP-Vorrat) und fehlende Angaben sind Hinweise.
AuxiliatorPruefung pruefeAuxiliator({
  required ArtefaktDaten daten,
  required int maxAsp,
}) {
  if (daten.defekt) {
    return const AuxiliatorPruefung(
      sperrgrund: 'Die Matrix ist irreparabel beschädigt.',
    );
  }
  return AuxiliatorPruefung(
    hinweise: [
      if (maxAsp <= 0)
        'Der Anwender hat keinen Astralenergie-Vorrat. Ein Auxiliator '
            'braucht einen zauberkundigen Anwender.',
      if (daten.zauber.isEmpty) 'Im Artefakt ist kein Zauber hinterlegt.',
    ],
  );
}

/// Ob [daten] im Kampf als eigener Punkt ausgelöst wird.
///
/// Ein Zaubertalisman wirkt nur beim Zaubern des Anwenders und taucht nicht
/// als auslösbares Artefakt auf.
bool artefaktImKampfAusloesbar(ArtefaktDaten daten) =>
    daten.art != ArtefaktArt.zaubertalisman && artefaktAusloesbar(daten);

/// Katalog-ID des Zaubers aus der Kennung eines Gefechts-Wirkprofils
/// (`zauber::<id>`); `null`, wenn die Kennung keinen Zauber nennt.
String? gefechtsWirkZauberId(String identitaet) {
  final teile = identitaet.split(':');
  if (teile.length < 3 || teile.first != 'zauber') {
    return null;
  }
  final id = teile.skip(2).join(':').trim();
  return id.isEmpty ? null : id;
}

/// Ausgerüstete, unbeschädigte Zaubertalismane des Helden, die einen Zauber
/// mit der Katalog-ID [zauberId] gespeichert haben.
List<HeroInventoryEntry> gefechtsAuxiliatoren(
  HeroSheet hero,
  String zauberId,
) => [
  for (final e in hero.inventoryEntries)
    if (e.artefaktDaten != null &&
        e.artefaktDaten!.art == ArtefaktArt.zaubertalisman &&
        !e.artefaktDaten!.defekt &&
        e.istAusgeruestet &&
        e.traegerTyp == InventoryTraeger.held &&
        e.artefaktDaten!.zauber.any((z) => z.spellId == zauberId))
      e,
];
