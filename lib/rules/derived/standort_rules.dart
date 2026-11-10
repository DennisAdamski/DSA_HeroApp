import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Adresse der Avesmaps-Karte (Nachfolger von Avespfade).
///
/// Die Seite lässt sich nicht einbetten (`X-Frame-Options: DENY`); die App
/// verlinkt deshalb nur und übernimmt keine Karten- oder Ortsdaten von
/// Avesmaps. Die Ortsauswahl stammt aus dem Ortsverzeichnis der Wiki
/// Aventurica (siehe [sucheOrte]).
const String kAvesmapsHost = 'avesmaps.de';

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
