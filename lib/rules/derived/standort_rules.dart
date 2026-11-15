import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Adresse der Avesmaps-Karte (Nachfolger von Avespfade).
///
/// Die Seite lässt sich nicht einbetten (`X-Frame-Options: DENY`); die App
/// verlinkt deshalb die Karte. Die Ortsauswahl stammt aus dem Ortsverzeichnis
/// der Wiki Aventurica, ergänzt um Orte und Kartenpositionen aus Avesmaps
/// (siehe [verbindeOrtsverzeichnisse] und [sucheOrte]).
const String kAvesmapsHost = 'avesmaps.de';

/// Quellenzeile der Ortsauswahl, so mit Avesmaps abgesprochen; steht dort,
/// wo die App Orte und Kartenpositionen zeigt.
const String kOrtsdatenQuellen =
    'Ortsdaten: Wiki Aventurica (CC BY-SA) · '
    'Karte & Ortsdaten: Avesmaps (avesmaps.de)';

/// Adresse der Wiki Aventurica.
const String kWikiAventuricaHost = 'de.wiki-aventurica.de';

/// Höchstlänge eines gespeicherten Standorts.
const int kStandortMaxLaenge = 120;

/// Bereinigt eine Eingabe zum Standort: Leerraum außen entfernt, innere
/// Leerraumfolgen zu einem Leerzeichen, auf [kStandortMaxLaenge] gekürzt.
///
/// Ein leerer Rückgabewert bedeutet „kein Standort“ und wird nicht in den
/// Zustand geschrieben.
String bereinigeStandort(String eingabe) {
  final einzeilig = eingabe.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (einzeilig.length <= kStandortMaxLaenge) return einzeilig;
  return einzeilig.substring(0, kStandortMaxLaenge).trimRight();
}

/// Link auf die Avesmaps-Karte für den Ort [standort] oder `null`.
///
/// Avesmaps öffnet Siedlungen über den Seitennamen im Wiki Aventurica
/// (`?siedlung=Gareth`). Ein Standort, der keine Siedlung ist (etwa
/// „Auf der Reichsstraße“), führt dort ins Leere; die Oberfläche weist darauf
/// hin, statt den Link zu verstecken.
Uri? avesmapsLink(String standort) {
  final name = bereinigeStandort(standort);
  if (name.isEmpty) return null;
  return Uri.https(kAvesmapsHost, '/', <String, String>{'siedlung': name});
}

/// Der Eintrag des Ortsverzeichnisses zu [standort] oder `null`.
///
/// Verglichen wird über [suchFaltung], also ohne Rücksicht auf Groß- und
/// Kleinschreibung und Umlaut-Schreibung. Tragen mehrere Einträge den Namen
/// (etwa Siedlung, Region und Staat „Thorwal“), gilt die Siedlung vor der
/// Region vor dem Staat usw.
OrtEintrag? findeOrt(String standort, List<OrtEintrag> orte) {
  final name = suchFaltung(bereinigeStandort(standort));
  if (name.isEmpty) return null;
  OrtEintrag? bester;
  for (final ort in orte) {
    if (suchFaltung(ort.name) != name) continue;
    if (bester == null || ort.art.index < bester.art.index) bester = ort;
  }
  return bester;
}

/// Link auf die Wiki-Aventurica-Seite des Orts [standort] oder `null`.
///
/// Es gibt nur einen Link für Orte, die das Ortsverzeichnis [orte] kennt: Der
/// Seitenname ist der volle Wiki-Titel (`OrtEintrag.seite`, sonst der Name).
/// Freitext wie „Auf der Reichsstraße“ hat keine Seite und bekommt keinen Link.
Uri? wikiAventuricaLink(String standort, List<OrtEintrag> orte) {
  final ort = findeOrt(standort, orte);
  if (ort == null) return null;
  final titel = (ort.seite.isNotEmpty ? ort.seite : ort.name).replaceAll(
    ' ',
    '_',
  );
  return Uri.https(kWikiAventuricaHost, '/wiki/$titel');
}

/// Höchstzahl der Vorschläge der Ortsauswahl.
const int kOrtVorschlaegeMax = 8;

/// Ob ein Kartenlink für [standort] sinnvoll ist.
///
/// Avesmaps öffnet nur Siedlungen. Trägt das Ortsverzeichnis [orte] den Namen
/// ausschließlich als Region, Staat, Fluss oder Straße, führt der Link ins
/// Leere und entfällt. Unbekannte Namen (Freitext) behalten den Link, weil das
/// Verzeichnis nicht vollständig sein muss.
bool kartenlinkSinnvoll(String standort, List<OrtEintrag> orte) {
  final name = suchFaltung(bereinigeStandort(standort));
  if (name.isEmpty) return false;
  var bekannt = false;
  for (final ort in orte) {
    if (suchFaltung(ort.name) != name) continue;
    if (ort.hatKartenlink) return true;
    bekannt = true;
  }
  return !bekannt;
}

/// Sucht Vorschläge für die Ortsauswahl in [orte].
///
/// Die Suche ist tolerant gegen Umlaute und Groß-/Kleinschreibung
/// ([suchFaltung]). Rangfolge: gleicher Name, Namensanfang, Wortanfang im
/// Namen, Teilstring im Namen, Treffer in der Region (so listet „Albernia“
/// auch die Orte dort). Bei gleichem Rang gehen Siedlungen vor Regionen,
/// Regionen vor Staaten usw., dann der kürzere, dann der alphabetische Name.
/// Eine leere Eingabe liefert keine Vorschläge.
List<OrtEintrag> sucheOrte(
  String eingabe,
  List<OrtEintrag> orte, {
  int limit = kOrtVorschlaegeMax,
}) {
  final frage = suchFaltung(bereinigeStandort(eingabe));
  if (frage.isEmpty || limit <= 0) return const <OrtEintrag>[];

  final treffer = <({OrtEintrag ort, int rang, String name})>[];
  for (final ort in orte) {
    final name = suchFaltung(ort.name);
    int? rang;
    if (name == frage) {
      rang = 0;
    } else if (name.startsWith(frage)) {
      rang = 1;
    } else if (name.contains(' $frage') || name.contains('-$frage')) {
      rang = 2;
    } else if (name.contains(frage)) {
      rang = 3;
    } else if (ort.region.isNotEmpty &&
        suchFaltung(ort.region).contains(frage)) {
      rang = 4;
    }
    if (rang != null) treffer.add((ort: ort, rang: rang, name: name));
  }
  treffer.sort((a, b) {
    var vergleich = a.rang.compareTo(b.rang);
    if (vergleich != 0) return vergleich;
    vergleich = a.ort.art.index.compareTo(b.ort.art.index);
    if (vergleich != 0) return vergleich;
    vergleich = a.name.length.compareTo(b.name.length);
    if (vergleich != 0) return vergleich;
    return a.name.compareTo(b.name);
  });
  return <OrtEintrag>[for (final t in treffer.take(limit)) t.ort];
}

// Schlüssel für die Gleichheit zweier Ortsnamen. Strenger als [suchFaltung]:
// Ein Verweis auf einen Ort der Karte soll nicht an einer Umlaut-Umschreibung
// hängen, die zwei verschiedene Orte zusammenfallen lässt.
String _namensSchluessel(String name) => bereinigeStandort(name).toLowerCase();

/// Verbindet das Ortsverzeichnis der Wiki Aventurica ([wiki]) mit dem von
/// Avesmaps ([avesmaps]) zu einer Auswahlliste.
///
/// - Eine Siedlung aus [wiki] bekommt Kennung und Kartenposition des
///   gleichnamigen Avesmaps-Orts. Verglichen wird zuerst der volle
///   Wiki-Seitenname (`OrtEintrag.seite`, etwa „Auweiler (Darpatien)“), dann
///   der Name; nur ein eindeutiger Treffer zählt.
/// - Avesmaps-Orte ohne Gegenstück kommen als Siedlung mit ihrer Ortsklasse
///   als Unterart dazu.
/// - Regionen, Staaten, Flüsse und Straßen bleiben unverändert und ohne
///   Position.
///
/// Die Reihenfolge von [wiki] bleibt erhalten, die zusätzlichen Orte folgen
/// in der Reihenfolge von [avesmaps].
List<OrtEintrag> verbindeOrtsverzeichnisse(
  List<OrtEintrag> wiki,
  List<AvesmapsOrt> avesmaps,
) {
  if (avesmaps.isEmpty) return wiki;
  // Je Namen der Avesmaps-Ort, oder `null` bei mehreren gleichnamigen.
  final nachName = <String, AvesmapsOrt?>{};
  for (final ort in avesmaps) {
    final schluessel = _namensSchluessel(ort.name);
    nachName[schluessel] = nachName.containsKey(schluessel) ? null : ort;
  }
  final vergeben = <String>{};
  final ergebnis = <OrtEintrag>[];
  for (final eintrag in wiki) {
    AvesmapsOrt? treffer;
    if (eintrag.art == OrtArt.siedlung) {
      if (eintrag.seite.isNotEmpty) {
        treffer = nachName[_namensSchluessel(eintrag.seite)];
      }
      treffer ??= nachName[_namensSchluessel(eintrag.name)];
    }
    if (treffer == null || !vergeben.add(treffer.id)) {
      ergebnis.add(eintrag);
      continue;
    }
    ergebnis.add(
      eintrag.mitKartenposition(
        ortId: treffer.id,
        kartenX: treffer.x,
        kartenY: treffer.y,
      ),
    );
  }
  for (final ort in avesmaps) {
    if (vergeben.contains(ort.id)) continue;
    ergebnis.add(
      OrtEintrag(
        name: ort.name,
        art: OrtArt.siedlung,
        unterart: ort.artBezeichnung,
        ortId: ort.id,
        kartenX: ort.x,
        kartenY: ort.y,
      ),
    );
  }
  return List<OrtEintrag>.unmodifiable(ergebnis);
}

/// Der Ort der Karte, auf den der eingegebene Ortsname [ort] verweist, oder
/// `null`.
///
/// Hat der Nutzer einen Vorschlag gewählt ([gewaehlt]) und steht dessen Name
/// noch im Feld, gilt dieser. Sonst zählt ein Eintrag aus [orte] mit
/// Kartenposition, dessen Name dem Text gleicht (ohne Rücksicht auf Groß-
/// und Kleinschreibung), sofern es genau einer ist. Gleichnamige Orte
/// verknüpft nur die ausdrückliche Auswahl.
OrtEintrag? ortsVerweisFuer(
  String ort,
  List<OrtEintrag> orte, {
  OrtEintrag? gewaehlt,
}) {
  final schluessel = _namensSchluessel(ort);
  if (schluessel.isEmpty) return null;
  if (gewaehlt != null &&
      gewaehlt.hatKartenposition &&
      _namensSchluessel(gewaehlt.name) == schluessel) {
    return gewaehlt;
  }
  OrtEintrag? treffer;
  for (final eintrag in orte) {
    if (!eintrag.hatKartenposition) continue;
    if (_namensSchluessel(eintrag.name) != schluessel) continue;
    if (treffer != null && treffer.ortId != eintrag.ortId) return null;
    treffer = eintrag;
  }
  return treffer;
}
