import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

/// Ergebniscontainer fuer alle aggregierten Wundauswirkungen.
class WundEffekte {
  const WundEffekte({
    this.atMalus = 0,
    this.paMalus = 0,
    this.fkMalus = 0,
    this.iniMalus = 0,
    this.kopfIniWuerfelMalus = 0,
    this.gsMalus = 0,
    this.talentProbeMalus = 0,
    this.zauberExtraMalus = 0,
    this.hinweise = const <String>[],
    this.kampfunfaehig = false,
    this.kampfunfaehigeZonen = const <WundZone>[],
    this.unterdrueckteGesamt = 0,
  });

  /// Summe aller AT-Abzuege (Basis + zonenspezifisch).
  final int atMalus;

  /// Summe aller PA-Abzuege.
  final int paMalus;

  /// Summe aller FK-Abzuege.
  final int fkMalus;

  /// Fester INI-Malus aus Basiswunden und zonenspezifischen festen Abzuegen.
  final int iniMalus;

  /// Gewuerfelter INI-Malus aus Kopfwunden (kumulierter 2W6-Wert).
  final int kopfIniWuerfelMalus;

  /// Gesamter INI-Malus (fest + gewuerfelt). Beide Werte sind negativ oder 0.
  int get iniGesamt => iniMalus - kopfIniWuerfelMalus;

  /// GS-Abzuege.
  final int gsMalus;

  /// Erschwernis fuer Talent- und Zauberproben (Basis).
  final int talentProbeMalus;

  /// Zusaetzliche Zauberproben-Erschwernis durch Kopfwunden.
  final int zauberExtraMalus;

  /// Gesamte Zauberproben-Erschwernis.
  int get zauberProbeMalus => talentProbeMalus + zauberExtraMalus;

  /// Informationstexte (z.B. "+W6 SP bei Brustwunde").
  final List<String> hinweise;

  /// Mindestens eine Zone hat 3 Wunden.
  final bool kampfunfaehig;

  /// Zonen mit 3 Wunden (nicht mehr verwendbar).
  final List<WundZone> kampfunfaehigeZonen;

  /// Anzahl insgesamt unterdrueckter Wunden (fuer UI-Anzeige).
  final int unterdrueckteGesamt;
}

/// Berechnet die Wundschwelle des Helden: KO/2 (abgerundet) + Modifikatoren.
int computeWundschwelle({
  required int ko,
  List<HeroTalentModifier> mods = const [],
}) {
  final basis = ko ~/ 2;
  var modSumme = 0;
  for (final m in mods) {
    modSumme += m.modifier;
  }
  return basis + modSumme;
}

/// Berechnet alle aggregierten Wundeffekte aus dem aktuellen Wundenzustand.
///
/// Unterdrueckte Wunden verursachen keine Abzuege, zaehlen aber weiterhin
/// fuer Kampfunfaehigkeit (Zone >= 3 Wunden).
WundEffekte computeWundEffekte(WundZustand zustand) {
  final gesamt = zustand.gesamtWunden;
  if (gesamt == 0) return const WundEffekte();

  final effektiv = zustand.gesamtEffektiveWunden;
  final unterdrueckt = zustand.gesamtUnterdrueckt;

  // --- Basisabzuege: pro effektiver (nicht unterdrueckter) Wunde ---
  var atMalus = effektiv * -2;
  var paMalus = effektiv * -2;
  var fkMalus = effektiv * -2;
  var iniMalus = effektiv * -2;
  var gsMalus = effektiv * -1;
  final talentProbeMalus = effektiv * -3;

  // --- Zonenspezifische Zusatzabzuege (nur effektive Wunden) ---
  var zauberExtraMalus = 0;
  final hinweise = <String>[];
  final kampfunfaehigeZonen = <WundZone>[];

  for (final zone in WundZone.values) {
    final wundenTotal = zustand.wundenInZone(zone);
    if (wundenTotal <= 0) continue;
    final wundenEffektiv = zustand.effektiveWundenInZone(zone);

    // Zonenspezifische Abzuege nur fuer effektive Wunden.
    if (wundenEffektiv > 0) {
      switch (zone) {
        case WundZone.kopf:
          atMalus += wundenEffektiv * -1;
          paMalus += wundenEffektiv * -1;
          fkMalus += wundenEffektiv * -1;
          zauberExtraMalus += wundenEffektiv * -3;

        case WundZone.brust:
        case WundZone.bauch:
        case WundZone.ruecken:
          atMalus += wundenEffektiv * -1;
          paMalus += wundenEffektiv * -1;
          fkMalus += wundenEffektiv * -1;

        case WundZone.linkerArm:
        case WundZone.rechterArm:
          atMalus += wundenEffektiv * -2;
          paMalus += wundenEffektiv * -2;
          fkMalus += wundenEffektiv * -4;

        case WundZone.linkesBein:
        case WundZone.rechtesBein:
          atMalus += wundenEffektiv * -1;
          paMalus += wundenEffektiv * -1;
          fkMalus += wundenEffektiv * -2;
          gsMalus += wundenEffektiv * -2;
      }
    }

    // Extraschaden-Hinweise basieren auf Gesamtwunden (physisch vorhanden).
    if (zone == WundZone.brust ||
        zone == WundZone.bauch ||
        zone == WundZone.ruecken) {
      hinweise.add(
        '+${wundenTotal}W6 SP Extraschaden (${wundZoneLabel[zone]})',
      );
    }

    // Kampfunfaehigkeit basiert auf Gesamtwunden (Wunde existiert physisch).
    if (wundenTotal >= maxWundenProZone) {
      kampfunfaehigeZonen.add(zone);
    }
  }

  // Folgeschaden-Hinweise fuer Kopf- und Torso-Zonen ab 3 Wunden
  for (final zone in kampfunfaehigeZonen) {
    final label = wundZoneLabel[zone] ?? zone.name;
    switch (zone) {
      case WundZone.kopf:
      case WundZone.brust:
      case WundZone.bauch:
      case WundZone.ruecken:
        hinweise.add('$label: 1 SP/KR Folgeschaden');
      case WundZone.linkerArm:
      case WundZone.rechterArm:
      case WundZone.linkesBein:
      case WundZone.rechtesBein:
        hinweise.add('$label: nicht mehr verwendbar');
    }
  }

  if (unterdrueckt > 0) {
    hinweise.add('$unterdrueckt Wunde${unterdrueckt > 1 ? 'n' : ''}'
        ' unterdrückt');
  }

  // kopfIniWuerfelMalus proportional zu effektiven Kopfwunden.
  final kopfTotal = zustand.wundenInZone(WundZone.kopf);
  final kopfEffektiv = zustand.effektiveWundenInZone(WundZone.kopf);
  final effektiverKopfIniMalus = kopfTotal > 0 && kopfEffektiv > 0
      ? (zustand.kopfIniMalus * kopfEffektiv / kopfTotal).ceil()
      : 0;

  return WundEffekte(
    atMalus: atMalus,
    paMalus: paMalus,
    fkMalus: fkMalus,
    iniMalus: iniMalus,
    kopfIniWuerfelMalus: effektiverKopfIniMalus,
    gsMalus: gsMalus,
    talentProbeMalus: talentProbeMalus,
    zauberExtraMalus: zauberExtraMalus,
    hinweise: hinweise,
    kampfunfaehig: kampfunfaehigeZonen.isNotEmpty,
    kampfunfaehigeZonen: kampfunfaehigeZonen,
    unterdrueckteGesamt: unterdrueckt,
  );
}

/// Berechnet die SB-Erschwernis fuer das Unterdruecken von Wunden.
///
/// [gesamtWunden] = alle Wunden inkl. der neuen.
/// [neueWunden] = 1 (normal), 2 oder 3 (Mehrfachwunden aus einem Treffer).
///
/// Bei Einzelwunden: 4 × Gesamtwunden.
/// Bei Mehrfachwunden aus einem Treffer: pauschal +8 (2) bzw. +12 (3).
int computeSbUnterdrueckungErschwernis({
  required int gesamtWunden,
  int neueWunden = 1,
}) => switch (neueWunden) {
  1 => 4 * gesamtWunden,
  2 => 8,
  3 => 12,
  _ => 4 * gesamtWunden,
};

/// Konvertiert aggregierte Wundeffekte in [StatModifiers] fuer die
/// zentrale Berechnungspipeline.
///
/// Talent-/Zauberproben-Mali werden hier NICHT abgebildet, da sie
/// ueber `initialSituationalModifier` an Proben uebergeben werden.
StatModifiers wundEffekteToStatModifiers(WundEffekte effekte) {
  return StatModifiers(
    at: effekte.atMalus,
    pa: effekte.paMalus,
    fk: effekte.fkMalus,
    iniBase: effekte.iniMalus - effekte.kopfIniWuerfelMalus,
    gs: effekte.gsMalus,
  );
}
