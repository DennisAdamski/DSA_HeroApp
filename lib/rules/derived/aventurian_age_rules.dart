import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Regeln zum aktuellen Alter eines Helden im aventurischen Kalender.
///
/// Das gepflegte Feld `alter` bleibt der Wert aus der Heldenerschaffung. Das
/// hier berechnete Alter ergibt sich dagegen aus dem Geburtsdatum des Helden
/// und dem Datum, an dem seine Kampagne gerade steht.

/// Muster fuer die erste ganze Zahl einer Jahresangabe.
final RegExp _yearPattern = RegExp(r'-?\d+');

/// Liefert die laufende Tagesnummer im Jahr (1 bis 365).
///
/// Zwoelf Monate zu 30 Tagen, danach die fuenf Namenlosen Tage. Fehlt Tag oder
/// Monat, oder liegt der Tag ausserhalb des Monats, ist das Ergebnis `null` —
/// dann kann nur noch die Jahresdifferenz ausgewertet werden.
int? aventurianDayOfYear(AventurianDate date) {
  final monthIndex = aventurianMonthIndex(date.month);
  if (monthIndex == null) {
    return null;
  }

  final day = int.tryParse(date.day.trim());
  if (day == null || day < 1) {
    return null;
  }

  final isNamenloseTage =
      aventurianMonths[monthIndex].value == aventurianNamenloseTageKey;
  final maxDay = isNamenloseTage
      ? aventurianNamenloseTageCount
      : aventurianDaysPerMonth;
  if (day > maxDay) {
    return null;
  }

  return monthIndex * aventurianDaysPerMonth + day;
}

/// Liest die Jahreszahl aus einer Freitextangabe wie `1027` oder `1027 BF`.
int? parseAventurianYear(String rawValue) {
  final match = _yearPattern.firstMatch(rawValue.trim());
  if (match == null) {
    return null;
  }
  return int.tryParse(match.group(0)!);
}

/// Berechnet die vollendeten Lebensjahre zwischen Geburt und Stichtag.
///
/// Beide Jahresangaben sind Pflicht. Sind zusaetzlich beide Tagesnummern
/// bekannt, wird ein noch ausstehender Geburtstag im laufenden Jahr abgezogen;
/// sonst bleibt es bei der reinen Jahresdifferenz. Ein negatives Ergebnis gilt
/// als unplausibel und liefert `null`, damit die UI nichts Falsches anzeigt.
int? computeAventurianAge({
  required AventurianDate geburtsdatum,
  required AventurianDate stichtag,
}) {
  final birthYear = parseAventurianYear(geburtsdatum.year);
  final referenceYear = parseAventurianYear(stichtag.year);
  if (birthYear == null || referenceYear == null) {
    return null;
  }

  var age = referenceYear - birthYear;

  final birthDayOfYear = aventurianDayOfYear(geburtsdatum);
  final referenceDayOfYear = aventurianDayOfYear(stichtag);
  final hasBothDays = birthDayOfYear != null && referenceDayOfYear != null;
  if (hasBothDays && referenceDayOfYear < birthDayOfYear) {
    age -= 1;
  }

  return age < 0 ? null : age;
}

/// Bestimmt das aventurische Datum, an dem die Kampagne des Helden steht.
///
/// Massgeblich sind die laufenden Abenteuer in Listenreihenfolge, je Abenteuer
/// zuerst der aktuelle Stand, dann das Startdatum. Fehlt ein laufendes
/// Abenteuer mit Datum, gilt das zuletzt abgeschlossene. Ohne jede Angabe
/// bleibt das Ergebnis `null`.
AventurianDate? resolveCurrentAdventureDate(HeroSheet hero) {
  final currentAdventures = hero.adventures
      .where((entry) => entry.status == HeroAdventureStatus.current)
      .toList(growable: false);
  for (final adventure in currentAdventures) {
    final date = _firstUsableDate(<HeroAdventureDateValue>[
      adventure.currentAventurianDate,
      adventure.startAventurianDate,
    ]);
    if (date != null) {
      return date;
    }
  }

  final completedAdventures = hero.adventures
      .where((entry) => entry.status == HeroAdventureStatus.completed)
      .toList(growable: false);
  for (final adventure in completedAdventures.reversed) {
    final date = _firstUsableDate(<HeroAdventureDateValue>[
      adventure.endAventurianDate,
      adventure.currentAventurianDate,
      adventure.startAventurianDate,
    ]);
    if (date != null) {
      return date;
    }
  }

  return null;
}

/// Berechnet das aktuelle Alter des Helden, oder `null` bei fehlenden Angaben.
int? computeCurrentHeroAge(HeroSheet hero) {
  return computeHeroAgeForBirthDate(hero, hero.appearance.geburtsdatum);
}

/// Wie [computeCurrentHeroAge], aber mit frei waehlbarem Geburtsdatum.
///
/// Die Uebersicht nutzt diese Variante, um waehrend der Bearbeitung bereits den
/// noch nicht gespeicherten Entwurf auszuwerten.
int? computeHeroAgeForBirthDate(HeroSheet hero, AventurianDate geburtsdatum) {
  if (!geburtsdatum.hasContent) {
    return null;
  }

  final referenceDate = resolveCurrentAdventureDate(hero);
  if (referenceDate == null) {
    return null;
  }

  return computeAventurianAge(
    geburtsdatum: geburtsdatum,
    stichtag: referenceDate,
  );
}

/// Liefert das erste inhaltlich belegte Datum als [AventurianDate].
AventurianDate? _firstUsableDate(List<HeroAdventureDateValue> candidates) {
  for (final candidate in candidates) {
    if (!candidate.hasContent) {
      continue;
    }
    return AventurianDate.fromParts(
      candidate.day,
      candidate.month,
      candidate.year,
    );
  }
  return null;
}
