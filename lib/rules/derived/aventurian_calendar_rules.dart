import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';

/// Tage in einem aventurischen Jahr: zwoelf Monate zu 30 Tagen plus fuenf
/// Namenlose Tage.
const int aventurianDaysPerYear =
    12 * aventurianDaysPerMonth + aventurianNamenloseTageCount;

/// Muster fuer die erste ganze Zahl einer Jahresangabe.
final RegExp _jahreszahl = RegExp(r'-?\d+');

/// Zaehlt [days] Tage auf [date] drauf (auch negativ) und rollt Monat und Jahr
/// mit.
///
/// Nach dem 30. eines Goettermonats beginnt der naechste; nach Rahja folgen die
/// fuenf Namenlosen Tage, danach das neue Jahr mit dem 1. Praios. Eine
/// vorhandene Jahresschreibweise bleibt erhalten (`1027 BF` wird `1028 BF`).
///
/// Ergibt `null`, wenn das Datum nicht eindeutig lesbar ist: Tag und Monat
/// muessen im Kalender liegen und das Jahr eine Zahl enthalten. Nichts wird
/// geraten.
AventurianDate? addAventurianDays(AventurianDate date, int days) {
  final tagImJahr = aventurianDayOfYear(date);
  final jahr = parseAventurianYear(date.year);
  if (tagImJahr == null || jahr == null) return null;

  final gesamt = (tagImJahr - 1) + days;
  final jahresSchritt = _abgerundet(gesamt, aventurianDaysPerYear);
  final neuerTag = gesamt - jahresSchritt * aventurianDaysPerYear;
  final monat = aventurianMonths[neuerTag ~/ aventurianDaysPerMonth];

  return date.copyWith(
    day: '${neuerTag % aventurianDaysPerMonth + 1}',
    month: monat.value,
    year: date.year.trim().replaceFirstMapped(
      _jahreszahl,
      (_) => '${jahr + jahresSchritt}',
    ),
  );
}

/// Der Folgetag von [date]; siehe [addAventurianDays].
AventurianDate? naechsterAventurischerTag(AventurianDate date) =>
    addAventurianDays(date, 1);

// Ganzzahldivision, die zur negativen Unendlichkeit hin rundet.
int _abgerundet(int zaehler, int nenner) {
  final q = zaehler ~/ nenner;
  return (zaehler % nenner != 0 && zaehler < 0) ? q - 1 : q;
}
