import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

/// Ergebnis einer Subzonen-Aufloesung (z.B. linkes/rechtes Bein).
class TrefferSubZone {
  const TrefferSubZone({required this.zone, required this.label});

  /// Aufgeloeste konkrete [WundZone].
  final WundZone zone;

  /// Anzeigename der aufgeloesten Subzone.
  final String label;
}

/// Typ-Alias fuer die Subzonen-Aufloesung anhand des W20-Wurfs.
typedef SubZoneResolver = TrefferSubZone Function(int roll);

/// Strukturierter Zusatzwurf einer Trefferzone, der separat gewuerfelt wird.
class TrefferzonenZusatzwurf {
  const TrefferzonenZusatzwurf({
    required this.label,
    required this.diceCount,
    this.diceSides = 6,
    this.modifier = 0,
    this.multipliziertMitWunden = false,
  });

  /// Anzeigename des Effekts, z. B. `Extraschaden` oder `INI-Malus`.
  final String label;

  /// Anzahl der Wuerfel des Grundeffekts.
  final int diceCount;

  /// Seitenzahl der Wuerfel. Standard ist `W6`.
  final int diceSides;

  /// Optionaler fester Modifikator auf die Summe.
  final int modifier;

  /// Multipliziert den Effekt mit der gewaehlten Wundenanzahl.
  final bool multipliziertMitWunden;
}

/// Ein einzelner Eintrag in einer Trefferzonen-Tabelle.
class TrefferzonenEintrag {
  const TrefferzonenEintrag({
    required this.zone,
    required this.label,
    required this.gezielterSchlagMod,
    required this.rollMin,
    required this.rollMax,
    required this.wundEffektBeschreibung,
    required this.dritteWundeBeschreibung,
    this.zusatzwuerfeErsteBisDritteWunde = const <TrefferzonenZusatzwurf>[],
    this.zusatzwuerfeDritteWunde = const <TrefferzonenZusatzwurf>[],
    this.subZoneResolver,
  });

  /// Standard-[WundZone] dieses Eintrags.
  final WundZone zone;

  /// Anzeigename der Zone (z.B. "Kopf", "Arme").
  final String label;

  /// Gezielter-Schlag-Erschwernis (z.B. +4, +6).
  final int gezielterSchlagMod;

  /// Untere Grenze des W20-Bereichs (inklusive).
  final int rollMin;

  /// Obere Grenze des W20-Bereichs (inklusive).
  final int rollMax;

  /// Beschreibung der Effekte bei 1. und 2. Wunde.
  final String wundEffektBeschreibung;

  /// Beschreibung der Effekte bei 3. Wunde.
  final String dritteWundeBeschreibung;

  /// Strukturierte Zusatzwuerfe, die pro erlittener Wunde gelten.
  final List<TrefferzonenZusatzwurf> zusatzwuerfeErsteBisDritteWunde;

  /// Strukturierte Zusatzwuerfe, die nur bei der 3. Wunde zusaetzlich gelten.
  final List<TrefferzonenZusatzwurf> zusatzwuerfeDritteWunde;

  /// Optionale Funktion zur Aufloesung in konkrete Subzonen
  /// (z.B. Schildarm/Schwertarm, linkes/rechtes Bein).
  final SubZoneResolver? subZoneResolver;

  /// Prueft, ob [roll] in den W20-Bereich dieses Eintrags faellt.
  bool matchesRoll(int roll) => roll >= rollMin && roll <= rollMax;
}

/// Vollstaendige Trefferzonen-Tabelle fuer einen Koerperbau-Typ.
class TrefferzonenTabelle {
  const TrefferzonenTabelle({
    required this.name,
    required this.eintraege,
    this.rollModifier = 0,
  });

  /// Anzeigename der Tabelle (z.B. "Humanoid", "Vierbeinig").
  final String name;

  /// Alle Zoneneintraege in der Tabelle.
  final List<TrefferzonenEintrag> eintraege;

  /// Globaler Modifikator auf den W20-Wurf (z.B. fuer Kleinwuechsig).
  final int rollModifier;
}

/// Aufgeloestes Ergebnis eines Trefferzonen-Wurfs.
class TrefferzonenErgebnis {
  const TrefferzonenErgebnis({
    required this.roll,
    required this.effektiverRoll,
    required this.eintrag,
    required this.zone,
    required this.label,
  });

  /// Roher W20-Wert.
  final int roll;

  /// Effektiver Wert nach Anwendung des Tabellenmodifikators.
  final int effektiverRoll;

  /// Zugehöriger Tabelleneintrag.
  final TrefferzonenEintrag eintrag;

  /// Aufgelöste konkrete [WundZone].
  final WundZone zone;

  /// Anzeigename der aufgelösten Zone (inkl. Subzone).
  final String label;
}
