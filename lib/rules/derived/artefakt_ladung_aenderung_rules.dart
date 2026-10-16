// Änderungen am Bogen, die ein Spruchspeicher auslöst: Ladung verbrauchen,
// wieder aufladen, Beschädigung vermerken. Sie treffen den Gegenstand über
// seinen angezeigten Stand (`mitGeaendertemInventarEintrag`) und wirken nur
// auf dessen Artefaktdaten; Zustand und Protokoll bucht der Aufrufer
// getrennt (`artefakt_protokollieren.dart`).

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_intervall_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';

ArtefaktDaten _daten(HeroInventoryEntry eintrag) {
  final daten = eintrag.artefaktDaten;
  if (daten == null) {
    throw StateError('Der Gegenstand ist kein Artefakt mehr.');
  }
  return daten;
}

HeroSheet _ersetze(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
  ArtefaktDaten neu,
) => mitGeaendertemInventarEintrag(
  held,
  angezeigt,
  angezeigt.copyWith(artefaktDaten: neu),
);

/// Markiert die Ladung [ladungId] des angezeigten Spruchspeichers als
/// verbraucht.
///
/// Wirft einen [StateError], wenn der Gegenstand inzwischen geändert wurde,
/// beschädigt ist, die Ladung fehlt oder schon verbraucht ist.
HeroSheet mitVerbrauchterLadung(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
  String ladungId,
) {
  final daten = _daten(angezeigt);
  if (daten.defekt) {
    throw StateError('Die Haltematrix ist irreparabel beschädigt.');
  }
  final index = daten.ladungen.indexWhere((l) => l.id == ladungId);
  if (index < 0) {
    throw StateError('Die Ladung gibt es nicht mehr.');
  }
  if (daten.ladungen[index].verbraucht) {
    throw StateError('Die Ladung ist schon verbraucht.');
  }
  final ladungen = List<ArtefaktLadung>.of(daten.ladungen);
  ladungen[index] = ladungen[index].copyWith(verbraucht: true);
  return _ersetze(held, angezeigt, daten.copyWith(ladungen: ladungen));
}

/// Lädt den angezeigten Spruchspeicher mit den Ladungen [neu] wieder auf.
///
/// Alle neuen Ladungen gelten als unverbraucht; der Aufladezähler steigt um 1.
/// Die Prüfung `pruefeAufladung` sperrt hier erneut, falls der Gegenstand nicht
/// (mehr) aufladbar ist.
HeroSheet mitAufgeladenemSpeicher(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
  List<ArtefaktLadung> neu,
) {
  final daten = _daten(angezeigt);
  final pruefung = pruefeAufladung(daten: daten, neu: neu);
  if (!pruefung.moeglich) {
    throw StateError(pruefung.sperrgrund!);
  }
  return _ersetze(
    held,
    angezeigt,
    daten.copyWith(
      ladungen: [for (final l in neu) l.copyWith(verbraucht: false)],
      aufladungen: daten.aufladungen + 1,
    ),
  );
}

/// Vermerkt eine Anwendung des angezeigten semipermanenten Spruchspeichers.
///
/// Der Zeitpunkt ist das aventurische Datum der Kampagne des gespeicherten
/// Helden (`resolveCurrentAdventureDate`); fehlt es, wird eine Anwendung ohne
/// Datum vermerkt, die erst die ausdrückliche Regeneration löscht. Abgelaufene
/// Anwendungen entfallen. Das Intervall sperrt nie.
HeroSheet mitVermerkterAnwendung(HeroSheet held, HeroInventoryEntry angezeigt) {
  final daten = _daten(angezeigt);
  if (daten.art != ArtefaktArt.spruchspeicherSemipermanent) {
    throw StateError(
      'Nur ein semipermanenter Spruchspeicher vermerkt Anwendungen.',
    );
  }
  if (daten.defekt) {
    throw StateError('Die Haltematrix ist irreparabel beschädigt.');
  }
  final heute = resolveCurrentAdventureDate(held);
  return _ersetze(
    held,
    angezeigt,
    daten.copyWith(anwendungen: anwendungenNachAusloesung(daten, heute)),
  );
}

/// Vermerkt, dass der angezeigte semipermanente Spruchspeicher seine Matrizen
/// regeneriert hat: alle vermerkten Anwendungen entfallen.
HeroSheet mitRegenerierterMatrix(HeroSheet held, HeroInventoryEntry angezeigt) {
  final daten = _daten(angezeigt);
  if (daten.art != ArtefaktArt.spruchspeicherSemipermanent) {
    throw StateError(
      'Nur ein semipermanenter Spruchspeicher regeneriert seine Matrizen.',
    );
  }
  return _ersetze(
    held,
    angezeigt,
    daten.copyWith(anwendungen: const <AventurianDate>[]),
  );
}

/// Vermerkt die irreparable Beschädigung der Haltematrix.
HeroSheet mitBeschaedigtemArtefakt(
  HeroSheet held,
  HeroInventoryEntry angezeigt,
) {
  final daten = _daten(angezeigt);
  if (daten.defekt) {
    return held;
  }
  return _ersetze(held, angezeigt, daten.copyWith(defekt: true));
}
