import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ortsdetails.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';

// Lage des Standorts auf der Karte von Avesmaps: Ort, Nachbarorte, Gebiete
// und Lageskizze für die Standort-Kachel.
//
// Alles hier rechnet nur mit dem lokal vorliegenden Ortsverzeichnis und den
// Ortsdetails; es gibt keine Kartenbilder (Avesmaps gibt seine Kacheln nicht
// für fremde Apps frei).

/// Eine der acht Himmelsrichtungen.
enum Himmelsrichtung {
  /// Norden.
  n('N', 'Norden'),

  /// Nordosten.
  no('NO', 'Nordosten'),

  /// Osten.
  o('O', 'Osten'),

  /// Südosten.
  so('SO', 'Südosten'),

  /// Süden.
  s('S', 'Süden'),

  /// Südwesten.
  sw('SW', 'Südwesten'),

  /// Westen.
  w('W', 'Westen'),

  /// Nordwesten.
  nw('NW', 'Nordwesten');

  const Himmelsrichtung(this.kurz, this.bezeichnung);

  /// Kürzel, etwa „NO“.
  final String kurz;

  /// Ausgeschriebener Name, etwa „Nordosten“.
  final String bezeichnung;

  /// Richtung von ([vonX], [vonY]) nach ([nachX], [nachY]) im
  /// Kartensystem von Avesmaps (`y` wächst nach Norden).
  static Himmelsrichtung zwischen(
    double vonX,
    double vonY,
    double nachX,
    double nachY,
  ) {
    // Winkel im Uhrzeigersinn ab Norden, 0 … 360.
    final grad =
        (math.atan2(nachX - vonX, nachY - vonY) * 180 / math.pi + 360) % 360;
    return Himmelsrichtung.values[((grad + 22.5) ~/ 45) % 8];
  }
}

/// Rang einer Ortsklasse für Skizze und Beschriftung; größer ist bedeutender.
///
/// Unbekannte Klassen zählen wie ein Dorf.
int ortsklassenRang(String art) => switch (art) {
  'metropole' => 5,
  'grossstadt' => 4,
  'stadt' => 3,
  'kleinstadt' => 2,
  'gebaeude' || 'stadtviertel' => 0,
  _ => 1,
};

/// Ob ein Ort der Karte eine Siedlung ist (kein Gebäude, kein Stadtviertel).
bool istSiedlung(AvesmapsOrt ort) => ortsklassenRang(ort.art) > 0;

/// Der Avesmaps-Ort zum gespeicherten [standort], oder `null`.
///
/// Gesucht wird zuerst im verbundenen Ortsverzeichnis [verzeichnis]
/// (`findeOrt`, tolerant gegen Umlaute): Trägt der Eintrag eine Kennung,
/// gilt der Avesmaps-Ort dazu. Sonst zählt ein Avesmaps-Ort, dessen Name dem
/// Standort ohne Rücksicht auf Groß- und Kleinschreibung gleicht, aber nur,
/// wenn es genau einer ist.
AvesmapsOrt? ortZumStandort(
  String standort,
  List<OrtEintrag> verzeichnis,
  List<AvesmapsOrt> avesmaps,
) {
  final name = bereinigeStandort(standort);
  if (name.isEmpty || avesmaps.isEmpty) return null;
  final eintrag = findeOrt(name, verzeichnis);
  if (eintrag != null && eintrag.ortId.isNotEmpty) {
    for (final ort in avesmaps) {
      if (ort.id == eintrag.ortId) return ort;
    }
  }
  final schluessel = name.toLowerCase();
  AvesmapsOrt? treffer;
  for (final ort in avesmaps) {
    if (ort.name.toLowerCase() != schluessel) continue;
    if (treffer != null) return null;
    treffer = ort;
  }
  return treffer;
}

/// Luftlinie zwischen zwei Orten der Karte in Meilen.
double meilenZwischen(AvesmapsOrt a, AvesmapsOrt b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return math.sqrt(dx * dx + dy * dy) * kMeilenProKarteneinheit;
}

/// Ein Ort in der Nähe des Standorts.
class NaherOrt {
  /// Erstellt den Eintrag.
  const NaherOrt({
    required this.ort,
    required this.meilen,
    required this.richtung,
  });

  /// Der Nachbarort.
  final AvesmapsOrt ort;

  /// Luftlinie vom Standort in Meilen.
  final double meilen;

  /// Richtung vom Standort aus.
  final Himmelsrichtung richtung;

  /// Abstandszeile, etwa „24 Meilen NO“.
  String get abstandText => '${formatiereMeilen(meilen)} ${richtung.kurz}';
}

/// Höchstzahl der Nachbarorte in einer schmalen Kachel.
const int kNaheOrteKurz = 5;

/// Höchstzahl der Nachbarorte in einer weiten Kachel.
const int kNaheOrteWeit = 10;

/// Die Siedlungen in der Nähe von [mitte], die nächste zuerst.
///
/// Gebäude und Stadtviertel zählen nicht (um Gareth lägen sonst Güter und
/// Schlösser vor jedem Dorf), ebenso der Ort selbst. Bei gleichem Abstand
/// geht der bedeutendere Ort vor, dann der Name.
List<NaherOrt> orteInDerNaehe(
  AvesmapsOrt mitte,
  List<AvesmapsOrt> orte, {
  int limit = kNaheOrteKurz,
}) {
  if (limit <= 0) return const <NaherOrt>[];
  final treffer = <NaherOrt>[
    for (final ort in orte)
      if (ort.id != mitte.id && istSiedlung(ort))
        NaherOrt(
          ort: ort,
          meilen: meilenZwischen(mitte, ort),
          richtung: Himmelsrichtung.zwischen(mitte.x, mitte.y, ort.x, ort.y),
        ),
  ];
  treffer.sort((a, b) {
    var vergleich = a.meilen.compareTo(b.meilen);
    if (vergleich != 0) return vergleich;
    vergleich = ortsklassenRang(b.ort.art)
        .compareTo(ortsklassenRang(a.ort.art));
    if (vergleich != 0) return vergleich;
    return a.ort.name.compareTo(b.ort.name);
  });
  return List<NaherOrt>.unmodifiable(treffer.take(limit));
}

/// Meilenangabe für die Anzeige: unter 10 Meilen mit einer Nachkommastelle
/// („3,6 Meilen“), sonst gerundet („24 Meilen“).
String formatiereMeilen(double meilen) {
  if (meilen < 10) {
    final gerundet = (meilen * 10).round() / 10;
    final text = gerundet == gerundet.roundToDouble()
        ? gerundet.toStringAsFixed(0)
        : gerundet.toStringAsFixed(1).replaceAll('.', ',');
    return '$text ${text == '1' ? 'Meile' : 'Meilen'}';
  }
  return '${meilen.round()} Meilen';
}

/// Gebietszeile der Ortsdetails, innen nach außen, etwa „Alt-Gareth ·
/// Kaisermark Gareth · Königreich Garetien“; leer ohne Gebiete.
///
/// Es zählt die erste Kette. Das äußerste Gebiet (das Reich) entfällt, sobald
/// die Kette mehr als drei Gebiete hat, damit die Zeile kurz bleibt; es steht
/// in [reichDesOrts].
String gebietsZeile(AvesmapsOrtsdetails? details) {
  final kette = _ersteKette(details);
  if (kette.isEmpty) return '';
  final innen = kette.length > 3 ? kette.sublist(1) : kette;
  return innen.reversed.map((g) => g.name).join(' · ');
}

/// Das äußerste Gebiet der ersten Kette (meist das Reich), oder leer.
String reichDesOrts(AvesmapsOrtsdetails? details) {
  final kette = _ersteKette(details);
  return kette.isEmpty ? '' : kette.first.name;
}

List<AvesmapsGebiet> _ersteKette(AvesmapsOrtsdetails? details) {
  final gebiete = details?.gebiete ?? const <List<AvesmapsGebiet>>[];
  return gebiete.isEmpty ? const <AvesmapsGebiet>[] : gebiete.first;
}

/// Rücklink auf die Avesmaps-Karte für einen Ort.
///
/// Folgt der Regel der Seite selbst: Mit Wiki-Artikel öffnet
/// `?siedlung=<Seitenname>` (der Teil hinter `/wiki/` aus [wikiUrl]), ohne
/// Artikel `?place=<Kennung>`. Ohne beides gilt [avesmapsLink] mit dem
/// [name].
Uri? avesmapsOrtLink({String wikiUrl = '', String id = '', String name = ''}) {
  final seite = RegExp(
    r'/wiki/([^?#]+)',
    caseSensitive: false,
  ).firstMatch(wikiUrl)?.group(1);
  if (seite != null && seite.isNotEmpty) {
    return Uri.parse('https://$kAvesmapsHost/?siedlung=$seite');
  }
  if (id.isNotEmpty) {
    return Uri.https(kAvesmapsHost, '/', <String, String>{'place': id});
  }
  return avesmapsLink(name);
}

/// Kartenposition für die Anzeige, etwa „x 551,6 · y 533,0“.
String kartenpositionText(AvesmapsOrt ort) {
  String zahl(double wert) => wert.toStringAsFixed(1).replaceAll('.', ',');
  return 'x ${zahl(ort.x)} · y ${zahl(ort.y)}';
}

/// Ein Punkt der Lageskizze.
class SkizzenPunkt {
  /// Erstellt den Punkt.
  const SkizzenPunkt({
    required this.ort,
    required this.dx,
    required this.dy,
    required this.rang,
    required this.beschriftet,
  });

  /// Der Ort.
  final AvesmapsOrt ort;

  /// Versatz nach Osten in halben Skizzenhöhen; der Rand liegt beim
  /// Seitenverhältnis der Skizze.
  final double dx;

  /// Versatz nach Norden, −1 … 1.
  final double dy;

  /// Rang der Ortsklasse ([ortsklassenRang]).
  final int rang;

  /// Ob die Skizze den Namen zeigt.
  final bool beschriftet;
}

/// Inhalt der Lageskizze um einen Standort.
class Lageskizze {
  /// Erstellt die Skizze.
  const Lageskizze({
    required this.mitte,
    required this.radiusMeilen,
    required this.punkte,
  });

  /// Der Standort in der Mitte.
  final AvesmapsOrt mitte;

  /// Halbe Kantenlänge der Skizze in Meilen.
  final double radiusMeilen;

  /// Nachbarorte, unwichtige zuerst (die bedeutenden liegen oben).
  final List<SkizzenPunkt> punkte;
}

/// Mögliche Halbmesser der Lageskizze in Meilen, klein vor groß.
const List<double> kSkizzenRadien = <double>[15, 30, 60, 120];

/// Mindestzahl an Siedlungen, ab der ein Halbmesser genügt.
const int kSkizzeMindestOrte = 6;

/// Seitenverhältnis (Breite zu Höhe) der Lageskizze.
const double kSkizzeSeitenverhaeltnis = 1.6;

/// Höchstzahl der Namen in der Skizze.
const int kSkizzeMaxNamen = 6;

/// Stellt die Lageskizze um [mitte] zusammen.
///
/// Der Halbmesser ist der kleinste aus [kSkizzenRadien], in dem mindestens
/// [kSkizzeMindestOrte] Siedlungen liegen, höchstens der größte; er gilt für
/// die halbe Höhe. Gezeigt werden die Siedlungen im Rechteck um die Mitte,
/// das [seitenverhaeltnis] (Breite zu Höhe) mal so breit wie hoch ist. Beschriftet werden bis zu
/// [kSkizzeMaxNamen] Orte ab der Kleinstadt, die bedeutendsten und dann die
/// nächsten zuerst.
Lageskizze lageskizze(
  AvesmapsOrt mitte,
  List<AvesmapsOrt> orte, {
  double seitenverhaeltnis = kSkizzeSeitenverhaeltnis,
}) {
  final siedlungen = <({AvesmapsOrt ort, double meilen})>[
    for (final ort in orte)
      if (ort.id != mitte.id && istSiedlung(ort))
        (ort: ort, meilen: meilenZwischen(mitte, ort)),
  ];
  var radius = kSkizzenRadien.last;
  for (final kandidat in kSkizzenRadien) {
    final anzahl = siedlungen.where((s) => s.meilen <= kandidat).length;
    if (anzahl >= kSkizzeMindestOrte) {
      radius = kandidat;
      break;
    }
  }
  final einheiten = radius / kMeilenProKarteneinheit;
  final innen = <({AvesmapsOrt ort, double meilen, int rang})>[
    for (final s in siedlungen)
      if ((s.ort.x - mitte.x).abs() <= einheiten * seitenverhaeltnis &&
          (s.ort.y - mitte.y).abs() <= einheiten)
        (ort: s.ort, meilen: s.meilen, rang: ortsklassenRang(s.ort.art)),
  ];
  final namen = [
    for (final p in innen)
      if (p.rang >= 2) p,
  ];
  namen.sort((a, b) {
    final vergleich = b.rang.compareTo(a.rang);
    return vergleich != 0 ? vergleich : a.meilen.compareTo(b.meilen);
  });
  final beschriftet = {for (final p in namen.take(kSkizzeMaxNamen)) p.ort.id};
  innen.sort((a, b) {
    final vergleich = a.rang.compareTo(b.rang);
    return vergleich != 0 ? vergleich : b.meilen.compareTo(a.meilen);
  });
  return Lageskizze(
    mitte: mitte,
    radiusMeilen: radius,
    punkte: List<SkizzenPunkt>.unmodifiable(<SkizzenPunkt>[
      for (final p in innen)
        SkizzenPunkt(
          ort: p.ort,
          dx: (p.ort.x - mitte.x) / einheiten,
          dy: (p.ort.y - mitte.y) / einheiten,
          rang: p.rang,
          beschriftet: beschriftet.contains(p.ort.id),
        ),
    ]),
  );
}
