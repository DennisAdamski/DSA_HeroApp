import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Erstes laufendes Abenteuer mit Titel, oder `null`.
///
/// Ein Abenteuer ohne Titel taugt nicht als Seitentitel; eine erfundene
/// Ueberschrift waere schlimmer als gar keine.
HeroAdventureEntry? laufendesAbenteuer(HeroSheet held) {
  for (final abenteuer in held.adventures) {
    if (abenteuer.status != HeroAdventureStatus.current) continue;
    if (abenteuer.title.trim().isNotEmpty) return abenteuer;
  }
  return null;
}

/// Aktueller Stand des Abenteuers, ersatzweise sein Startdatum, formatiert.
///
/// Bewusst nur aus demselben Abenteuer: `resolveCurrentAdventureDate` wiche auf
/// andere Abenteuer aus, und das Datum passte dann nicht zum Titel.
String? abenteuerDatum(HeroAdventureEntry abenteuer) {
  for (final datum in <HeroAdventureDateValue>[
    abenteuer.currentAventurianDate,
    abenteuer.startAventurianDate,
  ]) {
    if (!datum.hasContent) continue;
    return formatAventurianDate(
      AventurianDate.fromParts(datum.day, datum.month, datum.year),
    );
  }
  return null;
}

/// Ersetzt genau das Abenteuer mit [id] und laesst alles andere unberuehrt.
///
/// Das Abenteuerblatt schreibt damit gezielt, statt wie der Verwaltungseditor
/// Notizen, Kontakte und alle Abenteuer als Ganzes zu ersetzen. Ist das
/// Abenteuer inzwischen verschwunden, wird nichts still neu angelegt.
HeroSheet ersetzeAbenteuer(
  HeroSheet held,
  String id,
  HeroAdventureEntry Function(HeroAdventureEntry abenteuer) aenderung,
) {
  final index = held.adventures.indexWhere((eintrag) => eintrag.id == id);
  if (index < 0) {
    throw StateError('Das Abenteuer wurde inzwischen entfernt.');
  }
  final abenteuer = List<HeroAdventureEntry>.of(held.adventures);
  abenteuer[index] = aenderung(abenteuer[index]);
  return held.copyWith(adventures: abenteuer);
}
