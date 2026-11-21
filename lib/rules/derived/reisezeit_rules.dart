import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_calendar_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';

// Reisezeit nach Regelwerk: Strecke und Wegarten kommen von Avesmaps, die
// Dauer rechnet die App nach Basisregelwerk S. 192 (Tagesstrecken,
// Gelände- und Wettermodifikatoren) und Geographia Aventurica S. 123
// (Eilmarsch, Wetter). Je Etappe gilt
// Tage = Meilen ÷ (Tagesstrecke × Gelände × Wetter).

/// Reisemittel „zu Fuß“.
const String kReiseMittelFuss = 'fuss';

/// Reisemittel „beritten“.
const String kReiseMittelBeritten = 'beritten';

/// Reisemittel „Fuhrwerk“ (Ochsenkarren, Pferdefuhrwerk).
const String kReiseMittelFuhrwerk = 'fuhrwerk';

/// Reisemittel „Kutsche“ (Reisekutsche ohne Pferdewechsel).
const String kReiseMittelKutsche = 'kutsche';

/// Alle Reisemittel in fester Reihenfolge.
const List<String> kReiseMittel = <String>[
  kReiseMittelFuss,
  kReiseMittelBeritten,
  kReiseMittelFuhrwerk,
  kReiseMittelKutsche,
];

/// Normales Reisetempo.
const String kReiseTempoNormal = 'normal';

/// Eilmarsch bzw. Eilritt.
const String kReiseTempoEil = 'eil';

/// Ein Wetter mit seinem Modifikator der Tagesstrecke.
class ReiseWetter {
  /// Erstellt den Eintrag.
  const ReiseWetter(this.schluessel, this.name, this.faktor);

  /// Gespeicherter Schlüssel; leer für gutes Wetter.
  final String schluessel;

  /// Anzeigename.
  final String name;

  /// Faktor auf die Tagesstrecke.
  final double faktor;

  /// Ob das Wetter einen Eilmarsch vereitelt (GA S. 123: Sturm und heftiger
  /// Regenfall).
  bool get verhindertEile => faktor <= .7;
}

/// Wetter nach Basisregelwerk S. 192 und Geographia Aventurica S. 123.
const List<ReiseWetter> kReiseWetter = <ReiseWetter>[
  ReiseWetter('', 'Gutes Wetter', 1),
  ReiseWetter(
    'leicht',
    'Nieselregen, Schwüle, Frost, leichter Nebel, steife Brise',
    .9,
  ),
  ReiseWetter('hitze', 'Große Hitze', .8),
  ReiseWetter('dauerregen', 'Dauerregen oder Sturm', .7),
  ReiseWetter('schauer', 'Heftiger Schauer oder dichter Nebel', .5),
  ReiseWetter('orkan', 'Orkan', .3),
];

/// Das Wetter zu [schluessel]; unbekannte Werte zählen als gutes Wetter.
ReiseWetter reiseWetter(String schluessel) => kReiseWetter.firstWhere(
  (w) => w.schluessel == schluessel,
  orElse: () => kReiseWetter.first,
);

/// Anzeigename eines Reisemittels.
String reiseMittelName(String mittel) => switch (mittel) {
  kReiseMittelFuss => 'zu Fuß',
  kReiseMittelBeritten => 'beritten',
  kReiseMittelFuhrwerk => 'Fuhrwerk',
  kReiseMittelKutsche => 'Kutsche',
  _ => 'zu Fuß',
};

/// Das bekannte Reisemittel zu [mittel]; leer oder unbekannt heißt zu Fuß.
String reiseMittelOderFuss(String mittel) =>
    kReiseMittel.contains(mittel) ? mittel : kReiseMittelFuss;

/// Tagesstrecke in Meilen an Land (Basisregelwerk S. 192; Eilmarsch ×1,5,
/// Fuhrwerk und Kutsche höchstens ×1,25 nach Geographia Aventurica S. 123).
double reiseTagesstrecke(String mittel, {required bool eil}) {
  return switch (reiseMittelOderFuss(mittel)) {
    kReiseMittelBeritten => eil ? 60 : 40,
    kReiseMittelFuhrwerk => eil ? 37.5 : 30,
    kReiseMittelKutsche => eil ? 62.5 : 50,
    _ => eil ? 45 : 30,
  };
}

/// Tagesstrecke auf dem Fluss: Mittel aus Flusskahn stromauf 20 und stromab
/// 40 (die Richtung kennt Avesmaps nicht).
const double kReiseTagesstreckeFluss = 30;

/// Tagesstrecke auf See (Lastensegler, 12 Stunden am Tag).
const double kReiseTagesstreckeSee = 120;

enum _Abschnitt { land, wasser, umsteigen }

class _Gelaende {
  const _Gelaende(
    this.name,
    this.faktor, {
    this.abschnitt = _Abschnitt.land,
    this.befestigt = true,
    this.tagesstrecke,
  });

  final String name;
  final double faktor;
  final _Abschnitt abschnitt;

  /// Befestigter Weg: Eile möglich, Fuhrwerk und Kutsche fahren voll.
  final bool befestigt;

  /// Feste Tagesstrecke (Wasser), sonst nach Reisemittel.
  final double? tagesstrecke;
}

_Gelaende? _gelaende(String art) => switch (art.toLowerCase()) {
  'reichsstrasse' => const _Gelaende('Reichsstraße', 1.1),
  'strasse' => const _Gelaende('Straße', 1),
  'weg' => const _Gelaende('Weg', .8),
  'pfad' => const _Gelaende('Pfad', .8, befestigt: false),
  'querfeldein' => const _Gelaende('querfeldein', .75, befestigt: false),
  'flussweg' => const _Gelaende(
    'Fluss',
    1,
    abschnitt: _Abschnitt.wasser,
    tagesstrecke: kReiseTagesstreckeFluss,
  ),
  'seeweg' => const _Gelaende(
    'See',
    1,
    abschnitt: _Abschnitt.wasser,
    tagesstrecke: kReiseTagesstreckeSee,
  ),
  'umsteigen' => const _Gelaende(
    'Umsteigen',
    1,
    abschnitt: _Abschnitt.umsteigen,
    befestigt: false,
  ),
  _ => null,
};

/// Eine Zeile der Herleitung: Meilen einer Wegart, Tagesstrecke, Faktoren
/// und Tage.
class ReisezeitZeile {
  /// Erstellt die Zeile.
  const ReisezeitZeile({
    required this.name,
    required this.meilen,
    required this.tagesstrecke,
    required this.faktoren,
    required this.tage,
  });

  /// Wegart, etwa „Reichsstraße“.
  final String name;

  /// Meilen dieser Wegart.
  final double meilen;

  /// Tagesstrecke des Reisemittels in Meilen.
  final double tagesstrecke;

  /// Gelände- und Wetterfaktoren ohne die neutralen.
  final List<double> faktoren;

  /// Tage für diese Wegart.
  final double tage;

  /// Text wie „Reichsstraße 120 Meilen ÷ (30 × 1,1 × 0,9) = 4,0 Tage“.
  String get text {
    final teiler = faktoren.isEmpty
        ? formatiereReiseZahl(tagesstrecke)
        : '(${<String>[formatiereReiseZahl(tagesstrecke), for (final f in faktoren) formatiereReiseZahl(f)].join(' × ')})';
    return '$name ${meilen.round()} Meilen ÷ $teiler = '
        '${formatiereReiseZahl(tage, stellen: 1)} '
        '${tage == 1 ? 'Tag' : 'Tage'}';
  }
}

/// Der Reiseplan eines Wegs nach Regelwerk.
class ReisezeitPlan {
  /// Erstellt den Plan.
  const ReisezeitPlan({
    required this.meilen,
    required this.tage,
    required this.zeilen,
    required this.hinweise,
  });

  /// Ganze Strecke in Meilen.
  final double meilen;

  /// Reisetage ungerundet.
  final double tage;

  /// Herleitung je Wegart.
  final List<ReisezeitZeile> zeilen;

  /// Hinweise, etwa zu Eile oder unbekannten Wegarten.
  final List<String> hinweise;

  /// Ganze Reisetage für die Ankunft (aufgerundet, ohne Strecke null).
  int get ganzeTage => tage <= 0 ? 0 : math.max(1, (tage - 1e-9).ceil());

  /// Die Tage zum Speichern, auf Hundertstel gerundet.
  double get gespeicherteTage => (tage * 100).round() / 100;
}

/// Rechnet den Plan für [weg] mit [mittel], [tempo] und [wetter].
///
/// Etappen gleicher Wegart und gleicher Rechnung fassen sich zu einer Zeile
/// zusammen. Ohne Etappen gilt die ganze Strecke als Straße.
ReisezeitPlan reisezeitPlan({
  required AvesmapsRoute weg,
  String mittel = kReiseMittelFuss,
  String tempo = kReiseTempoNormal,
  String wetter = '',
}) {
  final hinweise = <String>[];
  final wetterEintrag = reiseWetter(wetter);
  final eilGewaehlt = tempo == kReiseTempoEil;
  final eil = eilGewaehlt && !wetterEintrag.verhindertEile;
  if (eilGewaehlt && !eil) {
    hinweise.add(
      '${wetterEintrag.name} vereitelt einen Eilmarsch; gerechnet wird '
      'normales Tempo.',
    );
  }
  final etappen = weg.etappen.isEmpty && weg.meilen > 0
      ? <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Strasse', meilen: weg.meilen),
        ]
      : weg.etappen;

  final zeilen = <String, ReisezeitZeile>{};
  final unbekannt = <String>{};
  var eileUnbefestigt = false;
  var wetterAufWasser = false;
  var tage = 0.0;
  var meilen = 0.0;
  for (final etappe in etappen) {
    if (etappe.meilen <= 0) continue;
    var gelaende = _gelaende(etappe.art);
    if (gelaende == null) {
      unbekannt.add(etappe.art);
      gelaende = _Gelaende(etappe.art, 1);
    }
    final double tagesstrecke;
    final faktoren = <double>[];
    switch (gelaende.abschnitt) {
      case _Abschnitt.wasser:
        tagesstrecke = gelaende.tagesstrecke!;
        if (wetterEintrag.faktor != 1) wetterAufWasser = true;
      case _Abschnitt.umsteigen:
        tagesstrecke = reiseTagesstrecke(kReiseMittelFuss, eil: false);
        if (wetterEintrag.faktor != 1) faktoren.add(wetterEintrag.faktor);
      case _Abschnitt.land:
        final eilHier = eil && gelaende.befestigt;
        if (eil && !gelaende.befestigt) eileUnbefestigt = true;
        // Fuhrwerk und Kutsche fahren auf Pfaden und querfeldein wie zu Fuß.
        final mittelHier =
            !gelaende.befestigt &&
                (mittel == kReiseMittelFuhrwerk ||
                    mittel == kReiseMittelKutsche)
            ? kReiseMittelFuss
            : mittel;
        tagesstrecke = reiseTagesstrecke(mittelHier, eil: eilHier);
        if (gelaende.faktor != 1) faktoren.add(gelaende.faktor);
        if (wetterEintrag.faktor != 1) faktoren.add(wetterEintrag.faktor);
    }
    final produkt = faktoren.fold<double>(1, (a, b) => a * b);
    final etappenTage = etappe.meilen / (tagesstrecke * produkt);
    tage += etappenTage;
    meilen += etappe.meilen;
    final schluessel = '${gelaende.name}|$tagesstrecke|${faktoren.join(',')}';
    final alt = zeilen[schluessel];
    zeilen[schluessel] = ReisezeitZeile(
      name: gelaende.name,
      meilen: (alt?.meilen ?? 0) + etappe.meilen,
      tagesstrecke: tagesstrecke,
      faktoren: faktoren,
      tage: (alt?.tage ?? 0) + etappenTage,
    );
  }
  if (eileUnbefestigt) {
    hinweise.add(
      'Eile nur auf befestigten Wegen; Pfade und querfeldein sind mit '
      'normalem Tempo gerechnet.',
    );
  }
  if (eil) {
    hinweise.add('Ein Eilmarsch ist auf Dauer nur jeden zweiten Tag möglich.');
  }
  if (wetterAufWasser) {
    hinweise.add('Das Wetter ist auf dem Wasser nicht eingerechnet.');
  }
  if (unbekannt.isNotEmpty) {
    hinweise.add(
      'Unbekannte Wegart ${unbekannt.join(', ')} zählt wie eine Straße.',
    );
  }
  return ReisezeitPlan(
    meilen: meilen,
    tage: tage,
    zeilen: List<ReisezeitZeile>.unmodifiable(zeilen.values),
    hinweise: List<String>.unmodifiable(hinweise),
  );
}

/// Zahl mit deutschem Komma, ohne überflüssige Nachkommastellen; mit
/// [stellen] fest gerundet.
String formatiereReiseZahl(double wert, {int? stellen}) {
  final text = stellen != null
      ? wert.toStringAsFixed(stellen)
      : (wert == wert.roundToDouble()
            ? wert.round().toString()
            : wert
                  .toStringAsFixed(2)
                  .replaceFirst(RegExp(r'0+$'), '')
                  .replaceFirst(RegExp(r'\.$'), ''));
  return text.replaceAll('.', ',');
}

/// Text für ganze Tage: „1 Tag“, „6 Tage“.
String reiseTageText(int tage) => tage == 1 ? '1 Tag' : '$tage Tage';

/// Kurzer Plantext, etwa „Plan 6 Tage · zu Fuß · Eilmarsch · Dauerregen“.
String? reisePlanText(HeroReiseAnreise? anreise) {
  final tage = anreise?.geplanteTage;
  if (anreise == null || tage == null) return null;
  final ganz = ReisezeitPlan(
    meilen: 0,
    tage: tage,
    zeilen: const <ReisezeitZeile>[],
    hinweise: const <String>[],
  ).ganzeTage;
  return <String>[
    'Plan ${reiseTageText(ganz)}',
    reiseMittelName(anreise.mittel),
    if (anreise.tempo == kReiseTempoEil) 'Eile',
    if (reiseWetter(anreise.wetter).schluessel.isNotEmpty)
      reiseWetter(anreise.wetter).name,
  ].join(' · ');
}

/// Vergleich von Ist und Plan einer Etappe: „Plan 6 Tage · 3 Tage länger“,
/// oder `null` ohne Plan.
///
/// Das Ist zählt ab der Abreise, sonst ab der vorigen Station.
String? reisePlanVergleichText(ReiseEtappe etappe) {
  final anreise = etappe.station.anreise;
  final geplant = anreise?.geplanteTage;
  if (anreise == null || geplant == null) return null;
  final planTage = ReisezeitPlan(
    meilen: 0,
    tage: geplant,
    zeilen: const <ReisezeitZeile>[],
    hinweise: const <String>[],
  ).ganzeTage;
  final teile = <String>['Plan ${reiseTageText(planTage)}'];
  final ist = anreise.abreise.hasContent
      ? reiseTageZwischenDaten(anreise.abreise, etappe.station.datum)
      : etappe.tageSeitVorher;
  if (ist != null) {
    final diff = ist - planTage;
    if (diff > 0) teile.add('${reiseTageText(diff)} länger');
    if (diff < 0) teile.add('${reiseTageText(-diff)} kürzer');
    if (diff == 0) teile.add('wie geplant');
  }
  return teile.join(' · ');
}

/// Fortlaufende Tagesnummer eines Datums, oder `null`, wenn es unvollständig
/// ist.
int? reiseTagesnummer(HeroAdventureDateValue datum) {
  if (!datum.hasContent) return null;
  final jahr = parseAventurianYear(datum.year);
  final tag = aventurianDayOfYear(
    AventurianDate.fromParts(datum.day, datum.month, datum.year),
  );
  if (jahr == null || tag == null) return null;
  return jahr * aventurianDaysPerYear + tag - 1;
}

/// Tage von [von] bis [bis], oder `null`, wenn eines fehlt.
int? reiseTageZwischenDaten(
  HeroAdventureDateValue von,
  HeroAdventureDateValue bis,
) {
  final a = reiseTagesnummer(von);
  final b = reiseTagesnummer(bis);
  if (a == null || b == null) return null;
  return b - a;
}

/// [datum] plus [tage] Tage, oder `null`, wenn sich das Datum nicht
/// weiterzählen lässt. Unbekannte Felder des Datums bleiben erhalten.
HeroAdventureDateValue? reiseDatumPlus(HeroAdventureDateValue datum, int tage) {
  if (!datum.hasContent) return null;
  final weiter = addAventurianDays(
    AventurianDate.fromParts(datum.day, datum.month, datum.year),
    tage,
  );
  if (weiter == null) return null;
  return datum.copyWith(
    day: weiter.day,
    month: weiter.month,
    year: weiter.year,
  );
}

/// Reisemittel-Vorschlag: beritten, wenn der Held ein Reittier hat, sonst zu
/// Fuß.
String reisemittelVorschlag(HeroSheet held) =>
    held.companions.any((c) => c.typ == BegleiterTyp.reittier)
    ? kReiseMittelBeritten
    : kReiseMittelFuss;

/// Vorschlag für die Abreise: Datum des laufenden Abenteuers, sonst der
/// zeitlich letzten datierten Station; ohne Angabe leer.
HeroAdventureDateValue reiseAbreiseVorschlag(HeroSheet held) {
  final vorschlag = reiseStationVorschlag(held: held, standort: '', id: '');
  if (vorschlag.datum.hasContent) return vorschlag.datum;
  final sortiert = sortiereReiseStationen(held.reiseStationen);
  for (final station in sortiert.reversed) {
    if (station.datum.hasContent) {
      return HeroAdventureDateValue(
        day: station.datum.day,
        month: station.datum.month,
        year: station.datum.year,
      );
    }
  }
  return const HeroAdventureDateValue();
}

/// ID des ersten laufenden Abenteuers, leer ohne.
String laufendesAbenteuerId(HeroSheet held) {
  for (final eintrag in held.adventures) {
    if (eintrag.status == HeroAdventureStatus.current) return eintrag.id;
  }
  return '';
}

bool _gleicherOrt(String a, String b) =>
    bereinigeStandort(a).toLowerCase() == bereinigeStandort(b).toLowerCase();

/// Ein Ort der Reise: Name und optional der Kartenverweis.
class ReiseOrt {
  /// Erstellt den Ort.
  const ReiseOrt({
    required this.name,
    this.ortId = '',
    this.kartenX,
    this.kartenY,
  });

  /// Aus einem Eintrag des Ortsverzeichnisses.
  factory ReiseOrt.aus(OrtEintrag eintrag) => ReiseOrt(
    name: eintrag.name,
    ortId: eintrag.ortId,
    kartenX: eintrag.kartenX,
    kartenY: eintrag.kartenY,
  );

  /// Ortsname.
  final String name;

  /// Avesmaps-Kennung; leer ohne Verweis.
  final String ortId;

  /// Kartenposition Ost-West, oder `null`.
  final double? kartenX;

  /// Kartenposition Süd-Nord, oder `null`.
  final double? kartenY;
}

/// Legt die Ausgangsstation an, wenn die zeitlich letzte Station nicht der
/// Standort [von] ist (Datum = [abreise]). Trägt die letzte Station den
/// Standort ohne Kartenverweis, bekommt sie den Verweis von [von].
HeroSheet reiseMitAusgangsstation({
  required HeroSheet held,
  required ReiseOrt von,
  required HeroAdventureDateValue abreise,
  required String adventureId,
  required String id,
  required DateTime jetzt,
}) {
  final name = bereinigeStandort(von.name);
  if (name.isEmpty) return held;
  final sortiert = sortiereReiseStationen(held.reiseStationen);
  if (sortiert.isNotEmpty && _gleicherOrt(sortiert.last.ort, name)) {
    final letzte = sortiert.last;
    if (letzte.ortId.isNotEmpty || von.ortId.isEmpty) return held;
    return ersetzeReiseStation(
      held,
      letzte.id,
      (s) => s.copyWith(
        ortId: von.ortId,
        kartenX: von.kartenX,
        kartenY: von.kartenY,
        lastModified: jetzt.toUtc(),
      ),
    );
  }
  return fuegeReiseStationHinzu(
    held,
    HeroReiseStation(
      id: id,
      ort: name,
      datum: abreise,
      adventureId: adventureId,
      ortId: von.ortId,
      kartenX: von.kartenX,
      kartenY: von.kartenY,
      lastModified: jetzt.toUtc(),
    ),
  );
}

/// Der Held nach einer Reise von [von] nach [nach]: Ausgangsstation (falls
/// nötig), Ankunftsstation mit Kartenverweis, [ankunft], Abenteuer und
/// [anreise]; mit [abenteuerDatumSetzen] springt das aktuelle Datum des
/// Abenteuers [adventureId] auf die Ankunft.
HeroSheet reiseAntreten({
  required HeroSheet held,
  required ReiseOrt von,
  required ReiseOrt nach,
  required HeroReiseAnreise anreise,
  required HeroAdventureDateValue ankunft,
  required String adventureId,
  required String ausgangsId,
  required String zielId,
  required DateTime jetzt,
  bool abenteuerDatumSetzen = false,
}) {
  var neu = reiseMitAusgangsstation(
    held: held,
    von: von,
    abreise: anreise.abreise,
    adventureId: adventureId,
    id: ausgangsId,
    jetzt: jetzt,
  );
  neu = fuegeReiseStationHinzu(
    neu,
    HeroReiseStation(
      id: zielId,
      ort: bereinigeStandort(nach.name),
      datum: ankunft,
      adventureId: adventureId,
      ortId: nach.ortId,
      kartenX: nach.kartenX,
      kartenY: nach.kartenY,
      anreise: anreise,
      lastModified: jetzt.toUtc(),
    ),
  );
  if (abenteuerDatumSetzen && adventureId.isNotEmpty && ankunft.hasContent) {
    neu = neu.copyWith(
      adventures: <HeroAdventureEntry>[
        for (final a in neu.adventures)
          a.id == adventureId
              ? a.copyWith(
                  currentAventurianDate: a.currentAventurianDate.copyWith(
                    day: ankunft.day,
                    month: ankunft.month,
                    year: ankunft.year,
                  ),
                )
              : a,
      ],
    );
  }
  return neu;
}

/// Die Reise als Zustand „unterwegs“.
HeroUnterwegs unterwegsFuer({
  required ReiseOrt von,
  required ReiseOrt nach,
  required HeroReiseAnreise anreise,
  required String adventureId,
}) {
  return HeroUnterwegs(
    ziel: bereinigeStandort(nach.name),
    zielOrtId: nach.ortId,
    zielKartenX: nach.kartenX,
    zielKartenY: nach.kartenY,
    vonOrt: bereinigeStandort(von.name),
    vonOrtId: von.ortId,
    vonKartenX: von.kartenX,
    vonKartenY: von.kartenY,
    adventureId: adventureId,
    anreise: anreise,
  );
}

/// Das Ziel einer laufenden Reise als [ReiseOrt].
ReiseOrt unterwegsZiel(HeroUnterwegs u) => ReiseOrt(
  name: u.ziel,
  ortId: u.zielOrtId,
  kartenX: u.zielKartenX,
  kartenY: u.zielKartenY,
);

/// Der Ausgangsort einer laufenden Reise als [ReiseOrt].
ReiseOrt unterwegsVon(HeroUnterwegs u) => ReiseOrt(
  name: u.vonOrt,
  ortId: u.vonOrtId,
  kartenX: u.vonKartenX,
  kartenY: u.vonKartenY,
);

/// Wo eine laufende Reise steht.
class UnterwegsLage {
  /// Erstellt die Lage.
  const UnterwegsLage({
    required this.tag,
    required this.geplanteTage,
    required this.anteil,
    this.kartenX,
    this.kartenY,
  });

  /// Reisetag ab 1 (Tag der Abreise), oder `null` ohne lesbare Daten.
  final int? tag;

  /// Geplante ganze Tage, oder `null` ohne Plan.
  final int? geplanteTage;

  /// Zurückgelegter Anteil von 0 bis 1.
  final double anteil;

  /// Geschätzte Kartenposition, oder `null` ohne Kartenpositionen.
  final double? kartenX;

  /// Geschätzte Kartenposition, oder `null`.
  final double? kartenY;

  /// Ob die Lage eine Kartenposition hat.
  bool get hatKartenposition => kartenX != null && kartenY != null;

  /// Text wie „Tag 3 von 6“ oder „Tag 8 · 2 Tage über Plan“.
  String? get text {
    final t = tag;
    final g = geplanteTage;
    if (t == null) return g == null ? null : 'Plan ${reiseTageText(g)}';
    if (g == null) return 'Tag $t';
    if (t > g + 1) return 'Tag $t · ${reiseTageText(t - 1 - g)} über Plan';
    if (t > g) return 'Tag $t · Ankunft erwartet';
    return 'Tag $t von $g';
  }
}

/// Die Lage der Reise [u] am Tag [heute]; die Position folgt der [linie]
/// (nach Länge), sonst der Luftlinie zwischen den Enden.
UnterwegsLage unterwegsLage(
  HeroUnterwegs u, {
  required HeroAdventureDateValue heute,
  List<(double, double)> linie = const <(double, double)>[],
}) {
  final geplant = u.anreise.geplanteTage;
  final ganz = geplant == null
      ? null
      : ReisezeitPlan(
          meilen: 0,
          tage: geplant,
          zeilen: const <ReisezeitZeile>[],
          hinweise: const <String>[],
        ).ganzeTage;
  final vergangen = reiseTageZwischenDaten(u.anreise.abreise, heute);
  final tag = vergangen == null || vergangen < 0 ? null : vergangen + 1;
  final anteil = vergangen == null || geplant == null || geplant <= 0
      ? 0.0
      : (vergangen / geplant).clamp(0.0, 1.0);
  final punkte = linie.length >= 2
      ? linie
      : u.hatKartenpositionen
      ? <(double, double)>[
          (u.vonKartenX!, u.vonKartenY!),
          (u.zielKartenX!, u.zielKartenY!),
        ]
      : const <(double, double)>[];
  final lage = punkteAufLinie(punkte, anteil);
  return UnterwegsLage(
    tag: tag,
    geplanteTage: ganz,
    anteil: anteil,
    kartenX: lage?.$1,
    kartenY: lage?.$2,
  );
}

/// Der Punkt bei [anteil] (0 … 1) der Länge von [punkte], oder `null` ohne
/// Punkte.
(double, double)? punkteAufLinie(List<(double, double)> punkte, double anteil) {
  if (punkte.isEmpty) return null;
  if (punkte.length == 1) return punkte.first;
  final laengen = <double>[];
  var gesamt = 0.0;
  for (var i = 1; i < punkte.length; i++) {
    final dx = punkte[i].$1 - punkte[i - 1].$1;
    final dy = punkte[i].$2 - punkte[i - 1].$2;
    final l = math.sqrt(dx * dx + dy * dy);
    laengen.add(l);
    gesamt += l;
  }
  if (gesamt <= 0) return punkte.first;
  var rest = anteil.clamp(0.0, 1.0) * gesamt;
  for (var i = 0; i < laengen.length; i++) {
    final l = laengen[i];
    if (rest <= l || i == laengen.length - 1) {
      final t = l <= 0 ? 0.0 : (rest / l).clamp(0.0, 1.0);
      final a = punkte[i];
      final b = punkte[i + 1];
      return (a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t);
    }
    rest -= l;
  }
  return punkte.last;
}

/// Name einer Raststation unterwegs: „Rast zwischen Gareth und Punin“.
String reiseRastName(HeroUnterwegs u) => u.vonOrt.isEmpty
    ? 'Rast auf dem Weg nach ${u.ziel}'
    : 'Rast zwischen ${u.vonOrt} und ${u.ziel}';

/// Der Held mit einer Raststation an der geschätzten [lage] am Tag [heute].
///
/// Die Rast trägt keinen Avesmaps-Verweis, nur die geschätzte Position; die
/// Anreise behält Abreise, Wege und Reisemittel, aber nicht den Plan zum Ziel.
HeroSheet reiseUnterwegsAnhalten({
  required HeroSheet held,
  required HeroUnterwegs u,
  required UnterwegsLage lage,
  required HeroAdventureDateValue heute,
  required String ausgangsId,
  required String rastId,
  required DateTime jetzt,
}) {
  final neu = reiseMitAusgangsstation(
    held: held,
    von: unterwegsVon(u),
    abreise: u.anreise.abreise,
    adventureId: u.adventureId,
    id: ausgangsId,
    jetzt: jetzt,
  );
  return fuegeReiseStationHinzu(
    neu,
    HeroReiseStation(
      id: rastId,
      ort: reiseRastName(u),
      datum: heute,
      adventureId: u.adventureId,
      kartenX: lage.kartenX,
      kartenY: lage.kartenY,
      notiz: 'Unterwegs nach ${u.ziel} angehalten.',
      // Der Plan galt dem Ziel, nicht der Rast.
      anreise: u.anreise.copyWith(geplanteTage: null, meilen: null),
      lastModified: jetzt.toUtc(),
    ),
  );
}
