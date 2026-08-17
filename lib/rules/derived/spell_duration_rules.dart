import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';

/// Regeln rund um die Wirkungsdauer laufender Zaubereffekte.
///
/// Die Umsetzung bleibt bewusst einheitenneutral: Kampfrunden, Spielrunden und
/// laengere Zeiteinheiten werden nicht ineinander umgerechnet, weil eine
/// Spielrunde nur ausserhalb des Kampfes sinnvoll in Kampfrunden aufgeht und
/// eine automatische Umrechnung am Spieltisch mehr verwirrt als hilft.

/// Ausgeschriebener Name einer Zeiteinheit (Singular/Plural nach [amount]).
String spellDurationUnitLabel(SpellDurationUnit unit, {int amount = 2}) {
  final isSingular = amount == 1;
  switch (unit) {
    case SpellDurationUnit.aktionen:
      return isSingular ? 'Aktion' : 'Aktionen';
    case SpellDurationUnit.kampfrunden:
      return isSingular ? 'Kampfrunde' : 'Kampfrunden';
    case SpellDurationUnit.spielrunden:
      return isSingular ? 'Spielrunde' : 'Spielrunden';
    case SpellDurationUnit.minuten:
      return isSingular ? 'Minute' : 'Minuten';
    case SpellDurationUnit.stunden:
      return isSingular ? 'Stunde' : 'Stunden';
    case SpellDurationUnit.tage:
      return isSingular ? 'Tag' : 'Tage';
    case SpellDurationUnit.permanent:
      return 'permanent';
  }
}

/// Kurzkuerzel einer Zeiteinheit fuer enge Anzeigen wie Chips und Tabellen.
String spellDurationUnitShortLabel(SpellDurationUnit unit) {
  switch (unit) {
    case SpellDurationUnit.aktionen:
      return 'Akt.';
    case SpellDurationUnit.kampfrunden:
      return 'KR';
    case SpellDurationUnit.spielrunden:
      return 'SR';
    case SpellDurationUnit.minuten:
      return 'Min.';
    case SpellDurationUnit.stunden:
      return 'Std.';
    case SpellDurationUnit.tage:
      return 'Tage';
    case SpellDurationUnit.permanent:
      return 'perm.';
  }
}

/// Lange Beschreibung der Restlaufzeit, z. B. `noch 3 von 5 Kampfrunden`.
///
/// Ohne Wirkungsdauer liefert die Funktion einen neutralen Hinweis, damit die
/// UI keinen Sonderfall behandeln muss.
String describeSpellDuration(SpellDuration? duration) {
  if (duration == null) {
    return 'Wirkungsdauer offen';
  }
  if (duration.isPermanent) {
    return 'Wirkungsdauer permanent';
  }
  if (duration.amount <= 0) {
    return 'Wirkungsdauer offen';
  }
  final unitLabel = spellDurationUnitLabel(duration.unit, amount: duration.amount);
  if (duration.isExpired) {
    return 'abgelaufen (${duration.amount} $unitLabel)';
  }
  return 'noch ${duration.remaining} von ${duration.amount} $unitLabel';
}

/// Kompakte Restlaufzeit fuer Chips, z. B. `noch 3 KR`.
///
/// Liefert `null`, wenn es nichts anzuzeigen gibt (keine oder permanente
/// Wirkungsdauer ohne Ablauf).
String? describeSpellDurationCompact(SpellDuration? duration) {
  if (duration == null || duration.amount <= 0) {
    return null;
  }
  if (duration.isPermanent) {
    return 'permanent';
  }
  if (duration.isExpired) {
    return 'abgelaufen';
  }
  return 'noch ${duration.remaining} ${spellDurationUnitShortLabel(duration.unit)}';
}

/// Zieht [steps] Einheiten von der Restlaufzeit ab (Countdown am Spieltisch).
///
/// Permanente Wirkungsdauern bleiben unveraendert; die Restlaufzeit faellt nie
/// unter null.
SpellDuration advanceSpellDuration(SpellDuration duration, {int steps = 1}) {
  if (duration.isPermanent || steps <= 0) {
    return duration;
  }
  final next = duration.remaining - steps;
  return duration.copyWith(remaining: next < 0 ? 0 : next);
}

/// Setzt die Restlaufzeit wieder auf die volle Wirkungsdauer.
SpellDuration resetSpellDuration(SpellDuration duration) {
  return duration.copyWith(remaining: duration.amount);
}
