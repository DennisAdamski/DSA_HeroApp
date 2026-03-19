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
WundEffekte computeWundEffekte(WundZustand zustand) {
  final gesamt = zustand.gesamtWunden;
  if (gesamt == 0) return const WundEffekte();

  // --- Basisabzuege: pro Wunde, zonenunabhaengig ---
  var atMalus = gesamt * -2;
  var paMalus = gesamt * -2;
  var fkMalus = gesamt * -2;
  var iniMalus = gesamt * -2;
  var gsMalus = gesamt * -1;
  final talentProbeMalus = gesamt * -3;

  // --- Zonenspezifische Zusatzabzuege ---
  var zauberExtraMalus = 0;
  final hinweise = <String>[];
  final kampfunfaehigeZonen = <WundZone>[];

  for (final zone in WundZone.values) {
    final wunden = zustand.wundenInZone(zone);
    if (wunden <= 0) continue;

    switch (zone) {
      case WundZone.kopf:
        atMalus += wunden * -1;
        paMalus += wunden * -1;
        fkMalus += wunden * -1;
        // Fester INI-Teil wird ueber kopfIniWuerfelMalus abgebildet,
        // da der Effekt gewuerfelt ist.
        zauberExtraMalus += wunden * -3;

      case WundZone.brust:
      case WundZone.bauch:
      case WundZone.ruecken:
        atMalus += wunden * -1;
        paMalus += wunden * -1;
        fkMalus += wunden * -1;
        hinweise.add(
          '+${wunden}W6 SP Extraschaden (${wundZoneLabel[zone]})',
        );

      case WundZone.linkerArm:
      case WundZone.rechterArm:
        atMalus += wunden * -2;
        paMalus += wunden * -2;
        fkMalus += wunden * -4;

      case WundZone.linkesBein:
      case WundZone.rechtesBein:
        atMalus += wunden * -1;
        paMalus += wunden * -1;
        fkMalus += wunden * -2;
        gsMalus += wunden * -2;
    }

    if (wunden >= maxWundenProZone) {
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

  return WundEffekte(
    atMalus: atMalus,
    paMalus: paMalus,
    fkMalus: fkMalus,
    iniMalus: iniMalus,
    kopfIniWuerfelMalus: zustand.kopfIniMalus,
    gsMalus: gsMalus,
    talentProbeMalus: talentProbeMalus,
    zauberExtraMalus: zauberExtraMalus,
    hinweise: hinweise,
    kampfunfaehig: kampfunfaehigeZonen.isNotEmpty,
    kampfunfaehigeZonen: kampfunfaehigeZonen,
  );
}

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
