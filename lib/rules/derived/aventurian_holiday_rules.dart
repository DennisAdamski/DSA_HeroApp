import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/aventurischer_feiertag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_calendar_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_holiday_data.dart';

/// Tage vor dem Datum, in denen ein Feiertag noch als „in der Nähe“ gilt.
const int feiertageTageDavor = 7;

/// Tage nach dem Datum, in denen ein Feiertag als „in der Nähe“ gilt.
const int feiertageTageDanach = 14;

/// Ein Feiertag samt Abstand zu einem Bezugsdatum.
class FeiertagTreffer {
  /// Erzeugt einen Treffer für [feiertag] mit [abstandTage].
  const FeiertagTreffer({required this.feiertag, required this.abstandTage});

  /// Der gefundene Feiertag.
  final AventurischerFeiertag feiertag;

  /// Tage bis zum (Beginn des) Feiertags: `0` an einem Festtag oder mitten im
  /// Zeitraum, negativ nach dem Ende, positiv davor.
  final int abstandTage;
}

/// Sucht die Feiertage rund um [datum].
///
/// Es zählen Tag und Monat; das Jahr bleibt unbeachtet, weil die Feiertage
/// jährlich wiederkehren. Das Jahr wird zyklisch gelesen: nach den Namenlosen
/// Tagen folgt der 1. Praios. Ist Tag oder Monat nicht lesbar, ist das Ergebnis
/// leer (siehe [aventurianDayOfYear]).
///
/// Ein Feiertag zählt, wenn er höchstens [tageDavor] Tage zurückliegt, höchstens
/// [tageDanach] Tage bevorsteht oder gerade läuft. Das Ergebnis ist nach Abstand
/// sortiert (Vergangenes zuerst), bei gleichem Abstand nach Name. [filter] ist
/// der Haken für spätere Einschränkungen nach Region, Volk oder Kirche; ohne ihn
/// zählen alle Einträge aus [aventurischeFeiertage].
List<FeiertagTreffer> feiertageInDerNaehe(
  AventurianDate datum, {
  int tageDavor = feiertageTageDavor,
  int tageDanach = feiertageTageDanach,
  bool Function(AventurischerFeiertag feiertag)? filter,
}) {
  final tag = aventurianDayOfYear(datum);
  if (tag == null) return const <FeiertagTreffer>[];

  final treffer = <FeiertagTreffer>[];
  for (final feiertag in aventurischeFeiertage) {
    if (filter != null && !filter(feiertag)) continue;
    final abstand = _abstand(feiertag, tag);
    if (abstand >= -tageDavor && abstand <= tageDanach) {
      treffer.add(FeiertagTreffer(feiertag: feiertag, abstandTage: abstand));
    }
  }
  treffer.sort((a, b) {
    final nachAbstand = a.abstandTage.compareTo(b.abstandTage);
    return nachAbstand != 0
        ? nachAbstand
        : a.feiertag.name.compareTo(b.feiertag.name);
  });
  return treffer;
}

// Abstand des Feiertags zum Tag [tag] im Jahr. Liegt er sowohl vor als auch
// hinter dem Tag (Fenster über ein ganzes Jahr), gewinnt der kleinere Betrag,
// bei Gleichstand der bevorstehende.
int _abstand(AventurischerFeiertag feiertag, int tag) {
  final seitBeginn = _modJahr(tag - feiertag.vonTagImJahr);
  if (seitBeginn < feiertag.dauerTage) return 0;

  final bis = _modJahr(feiertag.vonTagImJahr - tag);
  final seitEnde = _modJahr(tag - feiertag.bisTagImJahr);
  return bis <= seitEnde ? bis : -seitEnde;
}

int _modJahr(int tage) => tage % aventurianDaysPerYear;

/// Datum des Feiertags als Text, z. B. `5. Rondra`, `6.–9. Rondra` oder
/// `30. Tsa – 1. Phex`.
String feiertagDatumText(AventurischerFeiertag feiertag) {
  final von = _tagUndMonat(feiertag.vonTagImJahr);
  if (feiertag.istEintaegig) return '${von.tag}. ${von.monat}';
  final bis = _tagUndMonat(feiertag.bisTagImJahr);
  if (von.monat == bis.monat) return '${von.tag}.–${bis.tag}. ${von.monat}';
  return '${von.tag}. ${von.monat} – ${bis.tag}. ${bis.monat}';
}

({int tag, String monat}) _tagUndMonat(int tagImJahr) {
  final index = (tagImJahr - 1) ~/ aventurianDaysPerMonth;
  return (
    tag: (tagImJahr - 1) % aventurianDaysPerMonth + 1,
    monat: aventurianMonths[index].label,
  );
}

/// Abstand als Text: `heute`, `morgen`, `gestern`, `in 3 Tagen` oder
/// `vor 2 Tagen`.
String feiertagAbstandText(int abstandTage) {
  return switch (abstandTage) {
    0 => 'heute',
    1 => 'morgen',
    -1 => 'gestern',
    > 1 => 'in $abstandTage Tagen',
    _ => 'vor ${-abstandTage} Tagen',
  };
}

/// Wo und für wen der Feiertag gilt, als eine Zeile: Gottheit und Verbreitung,
/// soweit angegeben (z. B. `Rondra · zwölfgöttergläubige Lande`).
String feiertagGeltungText(AventurischerFeiertag feiertag) {
  final teile = <String>[
    if (feiertag.gottheit != null) feiertag.gottheit!,
    if (feiertag.verbreitung.isNotEmpty) feiertag.verbreitung,
  ];
  return teile.join(' · ');
}
