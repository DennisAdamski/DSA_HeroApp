// Änderungen an den Begleitern des gespeicherten Helden (ARCH-05).
//
// Die Sofortsteigerung eines Vertrauten bucht direkt, ohne den Editor zu
// speichern. Sie arbeitet deshalb auf dem frisch geladenen Helden und ändert
// nur den betroffenen Begleiter; die übrigen Begleiter und alle anderen
// Bogenfelder bleiben, wie sie gespeichert sind.

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';

/// ID der Ritualkategorie, die früher am Helden und heute am Vertrauten
/// liegt.
const String kVertrautenmagieKategorieId = 'vertrautenmagie';

/// Hält die Startwerte der Pool-Steigerungen fest, falls sie noch fehlen.
///
/// Pool-Werte (LeP, AuP, AsP, MR) steigen ab ihrem Startwert; ohne ihn
/// verschöbe eine spätere Änderung des Basiswerts die gekauften Stufen.
HeroCompanion mitBegleiterStartwerten(HeroCompanion c) {
  var ergebnis = c;
  if (ergebnis.startLep == null && ergebnis.maxLep != null) {
    ergebnis = ergebnis.copyWith(startLep: ergebnis.maxLep);
  }
  if (ergebnis.startAup == null && ergebnis.maxAup != null) {
    ergebnis = ergebnis.copyWith(startAup: ergebnis.maxAup);
  }
  if (ergebnis.startAsp == null && ergebnis.maxAsp != null) {
    ergebnis = ergebnis.copyWith(startAsp: ergebnis.maxAsp);
  }
  if (ergebnis.startMr == null && ergebnis.magieresistenz != null) {
    ergebnis = ergebnis.copyWith(startMr: ergebnis.magieresistenz);
  }
  return ergebnis;
}

/// Überträgt die alte Vertrautenmagie-Kategorie vom Helden auf die
/// Vertrauten.
///
/// Ein Vertrauter ohne eigene Ritualkategorien bekommt die Kategorie des
/// Helden; der Held verliert sie. Das ist die Migration, die der Begleiter-Tab
/// auch beim Bearbeiten anwendet. Gibt es nichts zu übertragen, kommt [held]
/// selbst zurück.
HeroSheet mitVertrautenmagieAmBegleiter(HeroSheet held) {
  HeroRitualCategory? alteKategorie;
  for (final kategorie in held.ritualCategories) {
    if (kategorie.id == kVertrautenmagieKategorieId) {
      alteKategorie = kategorie;
      break;
    }
  }
  if (alteKategorie == null) {
    return held;
  }
  final begleiter = held.companions.map((companion) {
    final braucht =
        companion.typ == BegleiterTyp.vertrauter &&
        companion.ritualCategories.isEmpty;
    if (!braucht) {
      return companion;
    }
    return companion.copyWith(ritualCategories: [alteKategorie!]);
  }).toList();
  final heldenKategorien = held.ritualCategories
      .where((kategorie) => kategorie.id != kVertrautenmagieKategorieId)
      .toList();
  return held.copyWith(
    companions: List<HeroCompanion>.unmodifiable(begleiter),
    ritualCategories: List<HeroRitualCategory>.unmodifiable(heldenKategorien),
  );
}

/// Ersetzt den Begleiter [begleiterId] durch das Ergebnis von [aenderung].
///
/// [aenderung] bekommt den gespeicherten Begleiter. Fehlt er, wirft die
/// Funktion einen [StateError].
HeroSheet ersetzeBegleiter(
  HeroSheet held,
  String begleiterId,
  HeroCompanion Function(HeroCompanion gespeichert) aenderung,
) {
  final index = held.companions.indexWhere((c) => c.id == begleiterId);
  if (index < 0) {
    throw StateError('Der Begleiter wurde inzwischen entfernt.');
  }
  final begleiter = List<HeroCompanion>.of(held.companions);
  begleiter[index] = aenderung(begleiter[index]);
  return held.copyWith(companions: List<HeroCompanion>.unmodifiable(begleiter));
}

/// Bucht eine Vertrauten-Steigerung auf den gespeicherten Helden.
///
/// Wendet zuerst die Vertrautenmagie-Migration an (wie bisher beim
/// Sofortspeichern), steigert dann den Begleiter [begleiterId] über
/// [steigereBegleiter] und hält seine Pool-Startwerte fest.
HeroSheet bucheBegleiterSteigerung(
  HeroSheet held, {
  required String begleiterId,
  required BegleiterSteigerungsziel ziel,
  required int erwarteterStand,
  required int neuerStand,
  required int apKosten,
}) {
  final migriert = mitVertrautenmagieAmBegleiter(held);
  return ersetzeBegleiter(migriert, begleiterId, (gespeichert) {
    final gesteigert = steigereBegleiter(
      gespeichert,
      ziel: ziel,
      erwarteterStand: erwarteterStand,
      neuerStand: neuerStand,
      apKosten: apKosten,
    );
    return mitBegleiterStartwerten(gesteigert);
  });
}
