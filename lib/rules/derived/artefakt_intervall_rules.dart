import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';

// Regeln für intervallbasierte (semipermanente) Spruchspeicher (Wege der
// Alchimie 2. Auflage S. 82; Stäbe, Ringe, Dschinnenlampen S. 8): Das Artefakt
// regeneriert die Wirkungsmatrizen der verbrauchten Sprüche innerhalb von Tag,
// Woche, Monat oder Jahr selbst. Bei einem Artefakt, das z. B. einmal
// wöchentlich eingesetzt werden kann, liegen zwischen zwei Anwendungen
// mindestens sieben Tage; ab zwei Anwendungen je Intervall zählen die
// Anwendungen der letzten Intervalllänge. Die App zeigt den Stand nur an und
// sperrt nie (Meisterentscheid).

/// Tage eines aventurischen Jahres: zwölf Göttermonate und die Namenlosen Tage.
const int aventurianTageProJahr =
    aventurianDaysPerMonth * 12 + aventurianNamenloseTageCount;

/// Tage je Intervall: Tag 1, Woche 7, Monat 30 (Göttermonat), Jahr 365.
int artefaktIntervallTage(ArtefaktIntervall intervall) => switch (intervall) {
  ArtefaktIntervall.tag => 1,
  ArtefaktIntervall.woche => 7,
  ArtefaktIntervall.monat => aventurianDaysPerMonth,
  ArtefaktIntervall.jahr => aventurianTageProJahr,
};

/// Anzeigename des Intervalls.
String artefaktIntervallLabel(ArtefaktIntervall intervall) =>
    switch (intervall) {
      ArtefaktIntervall.tag => 'Tag',
      ArtefaktIntervall.woche => 'Woche',
      ArtefaktIntervall.monat => 'Monat',
      ArtefaktIntervall.jahr => 'Jahr',
    };

/// Fortlaufende Tagesnummer eines Datums, oder `null` bei unvollständiger
/// oder unlesbarer Angabe (Jahr, Monat und Tag müssen lesbar sein).
int? aventurischerTag(AventurianDate datum) {
  final jahr = parseAventurianYear(datum.year);
  final imJahr = aventurianDayOfYear(datum);
  if (jahr == null || imJahr == null) {
    return null;
  }
  return jahr * aventurianTageProJahr + imJahr;
}

/// Das Datum zur fortlaufenden Tagesnummer [tag] (Umkehrung von
/// [aventurischerTag]).
AventurianDate aventurischesDatum(int tag) {
  final fortlaufend = tag - 1;
  final jahr = fortlaufend ~/ aventurianTageProJahr;
  final imJahr = fortlaufend - jahr * aventurianTageProJahr + 1;
  final monatIndex = (imJahr - 1) ~/ aventurianDaysPerMonth;
  final tagImMonat = (imJahr - 1) % aventurianDaysPerMonth + 1;
  return AventurianDate(
    day: '$tagImMonat',
    month: aventurianMonths[monatIndex].value,
    year: '$jahr',
  );
}

/// Stand der Anwendungen eines semipermanenten Spruchspeichers.
class IntervallStatus {
  /// Erstellt den Stand.
  const IntervallStatus({
    required this.erlaubt,
    required this.verbraucht,
    required this.datumUnbekannt,
    this.fruehestensWieder,
  });

  /// Anwendungen je Intervall.
  final int erlaubt;

  /// Anwendungen, die im laufenden Intervall zählen.
  final int verbraucht;

  /// Ob der heutige Tag unbekannt ist: Es verfällt dann nichts von selbst.
  final bool datumUnbekannt;

  /// Frühester Tag, an dem wieder eine Anwendung frei wird; `null`, solange
  /// noch eine frei ist oder keine Berechnung möglich ist.
  final AventurianDate? fruehestensWieder;

  /// Freie Anwendungen im Intervall (nie unter 0).
  int get frei => erlaubt > verbraucht ? erlaubt - verbraucht : 0;

  /// Ob mindestens eine Anwendung frei ist.
  bool get istFrei => frei > 0;
}

// Ob eine vermerkte Anwendung am Tag [heute] noch zählt: ein unbekanntes
// Datum zählt, bis der Nutzer die Regeneration vermerkt; sonst zählt sie
// innerhalb der Intervalllänge.
bool _zaehlt(AventurianDate anwendung, int? heute, int tage) {
  final tag = aventurischerTag(anwendung);
  if (tag == null || heute == null) {
    return true;
  }
  return heute - tag < tage;
}

/// Berechnet den Stand der Anwendungen am Tag [heute].
///
/// [heute] ist das aventurische Datum der Kampagne
/// (`resolveCurrentAdventureDate`); fehlt es oder ist es unlesbar, gilt jede
/// vermerkte Anwendung weiter, bis der Nutzer die Regeneration vermerkt.
IntervallStatus intervallStatus(ArtefaktDaten daten, AventurianDate? heute) {
  final tage = artefaktIntervallTage(daten.intervall);
  final erlaubt = daten.anwendungenProIntervall < 1
      ? 1
      : daten.anwendungenProIntervall;
  final heuteTag = heute == null ? null : aventurischerTag(heute);
  final zaehlend = [
    for (final a in daten.anwendungen)
      if (_zaehlt(a, heuteTag, tage)) a,
  ];
  final status = IntervallStatus(
    erlaubt: erlaubt,
    verbraucht: zaehlend.length,
    datumUnbekannt: heuteTag == null,
  );
  if (status.istFrei || heuteTag == null) {
    return status;
  }
  // Die älteste zählende Anwendung mit Datum wird zuerst frei.
  final tageDerAnwendungen = [for (final a in zaehlend) ?aventurischerTag(a)]
    ..sort();
  if (tageDerAnwendungen.length != zaehlend.length ||
      tageDerAnwendungen.isEmpty) {
    return status;
  }
  // Frei wird eine Anwendung, sobald so viele zählende Anwendungen verfallen
  // sind, dass weniger als [erlaubt] übrig bleiben.
  final nochNoetig = zaehlend.length - erlaubt + 1;
  final wieder = tageDerAnwendungen[nochNoetig - 1] + tage;
  return IntervallStatus(
    erlaubt: erlaubt,
    verbraucht: zaehlend.length,
    datumUnbekannt: false,
    fruehestensWieder: aventurischesDatum(wieder),
  );
}

/// Die Anwendungen nach einer weiteren Auslösung am Tag [heute].
///
/// Abgelaufene Anwendungen entfallen (nur bei bekanntem Datum), die neue
/// kommt ans Ende, und es bleiben höchstens so viele wie das Intervall
/// erlaubt. Ohne Datum wird eine Anwendung ohne Datum vermerkt.
List<AventurianDate> anwendungenNachAusloesung(
  ArtefaktDaten daten,
  AventurianDate? heute,
) {
  final tage = artefaktIntervallTage(daten.intervall);
  final erlaubt = daten.anwendungenProIntervall < 1
      ? 1
      : daten.anwendungenProIntervall;
  final heuteTag = heute == null ? null : aventurischerTag(heute);
  final liste = <AventurianDate>[
    for (final a in daten.anwendungen)
      if (_zaehlt(a, heuteTag, tage)) a,
    heuteTag == null ? const AventurianDate() : heute!,
  ];
  return liste.length > erlaubt ? liste.sublist(liste.length - erlaubt) : liste;
}

/// Kurztext zum Stand: „2 von 3 Anwendungen je Woche frei“ mit Hinweis auf
/// ein unbekanntes Datum oder den frühesten freien Tag.
String intervallStatusText(ArtefaktDaten daten, IntervallStatus status) {
  final teile = <String>[
    '${status.frei} von ${status.erlaubt} Anwendung'
        '${status.erlaubt == 1 ? '' : 'en'} je '
        '${artefaktIntervallLabel(daten.intervall)} frei',
  ];
  if (status.datumUnbekannt && status.verbraucht > 0) {
    teile.add('Datum unbekannt, es verfällt nichts von selbst');
  }
  final wieder = status.fruehestensWieder;
  if (wieder != null) {
    teile.add('frühestens wieder am ${formatAventurianDate(wieder)}');
  }
  return teile.join(' · ');
}
