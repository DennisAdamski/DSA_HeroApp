import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';

/// Gemeinsame Grundlage der Nahrungsbeschaffung (Wege des Entdeckers
/// S. 106–113): Nahrung sammeln, Pirsch- und Ansitzjagd, Tierfallen, Angeln
/// und Speerfischen.
///
/// Alle teilen die Regionen der Nahrungsbeschaffung ([Wildnisregion]), sind
/// unabhängig von der Jahreszeit, laden keine Daten und übersetzen die TaP*
/// in Tagesrationen. Die Unterklasse liefert nur die Probe als
/// [WildnisProbeEingabe] (oder `null`, wo die Tätigkeit nicht möglich ist) und
/// die Anteile der Erschwernis für die Anzeige; gerechnet wird in
/// `lib/rules/derived/`.
abstract class KartoRationenTaetigkeit extends KartoWildnisTaetigkeit {
  /// Erlaubt konstante Unterklassen.
  const KartoRationenTaetigkeit();

  @override
  bool get brauchtJahreszeit => false;

  @override
  List<WildnisLandschaft> get landschaften => wildnisRegionenAlsLandschaften();

  @override
  List<WildnisLandschaft> landschaftenFuerOrt(OrtEintrag ort) =>
      <WildnisLandschaft>[
        for (final region in wildnisRegionenFuerOrt(ort))
          wildnisRegionAlsLandschaft(region),
      ];

  @override
  AsyncValue<Object?> beobachteDaten(WidgetRef ref) =>
      const AsyncValue<Object?>.data(null);

  /// Die Region der gewählten Landschaft.
  Wildnisregion region(KartoWildnisKontext kontext) =>
      wildnisRegionZuLandschaft(kontext.landschaft);

  /// Die Probe als allgemeine Wildnisprobe; `null`, wo die Tätigkeit nicht
  /// möglich ist (etwa Fallenstellen in der Wüste).
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext);

  /// Die tätigkeitseigenen Anteile der Erschwernis (Region, Waffe, Wetter …)
  /// für die Aufschlüsselung; Geländekunde, Ortskenntnis, AsP und die weitere
  /// Erschwernis zeigt die Kachel selbst.
  List<({String text, int wert})> erschwernisTeile(KartoWildnisKontext kontext);

  /// Zusatz zur Aufschlüsselung (etwa ein Verfall der Schützen-SF); leer ohne.
  String erschwernisZusatz(KartoWildnisKontext kontext) => '';

  /// Hinweis nach dem Wurf (Verbrauch, Wiederholbarkeit …); leer ohne.
  String auswertungsHinweis(KartoWildnisKontext kontext) => '';

  /// Ausbeute (Tagesrationen) für [tapStern] TaP*.
  int ausbeuteFuerTap(KartoWildnisKontext kontext, int tapStern) => tapStern;

  /// Name des Inventareintrags für die Rationen (`Wildbret (frisch)`);
  /// `null`, wenn sich nichts buchen lässt.
  String? get inventarGegenstand => null;

  /// Beschreibung des Inventareintrags (Haltbarkeit in der Region).
  String inventarBeschreibung(KartoWildnisKontext kontext) => '';

  @override
  bool get erlaubtHandFund => inventarGegenstand != null;

  /// Name des Eintrags für einen Fund von Hand; Nahrung sammeln benennt ihn
  /// nach der Haltbarkeit.
  String? handFundGegenstand(KartoWildnisKontext kontext) => inventarGegenstand;

  @override
  WildnisPosten? handFund({
    required KartoWildnisKontext? kontext,
    required Object? daten,
    required String? wahl,
    required int menge,
  }) {
    if (kontext == null || menge <= 0) return null;
    final gegenstand = handFundGegenstand(kontext);
    if (gegenstand == null) return null;
    return WildnisPosten(
      gegenstand: gegenstand,
      anzahl: menge,
      taetigkeit: titel,
      beschreibung: inventarBeschreibung(kontext),
    );
  }

  WildnisProbeEingabe _eingabe(KartoWildnisKontext kontext) {
    final eingabe = probeEingabe(kontext);
    if (eingabe == null) {
      throw StateError(sperrgrund(kontext) ?? '$titel ist nicht möglich.');
    }
    return eingabe;
  }

  @override
  String? sperrgrund(KartoWildnisKontext kontext) =>
      probeEingabe(kontext) == null
      ? '$titel ist in der Landschaft „${kontext.landschaft.bezeichnung}“ '
            'nicht möglich ($regelHinweis).'
      : null;

  @override
  int erschwernis(KartoWildnisKontext kontext) {
    final eingabe = probeEingabe(kontext);
    return eingabe == null ? 0 : wildnisProbenErschwernis(eingabe);
  }

  @override
  String? erschwernisHinweis(KartoWildnisKontext kontext) {
    if (probeEingabe(kontext) == null) return null;
    final teile = [
      for (final teil in erschwernisTeile(kontext))
        '${teil.text} ${mitVorzeichen(teil.wert)}',
    ];
    final zusatz = erschwernisZusatz(kontext);
    if (teile.isEmpty && zusatz.isEmpty) return null;
    return <String>[
      if (teile.isNotEmpty) 'darin ${teile.join(' · ')}',
      if (zusatz.isNotEmpty) zusatz,
    ].join('; ');
  }

  @override
  int tawBeiDauer(KartoWildnisKontext kontext) => kontext.taw;

  @override
  ResolvedProbeRequest baueProbe(KartoWildnisKontext kontext) =>
      baueWildnisProbe(
        _eingabe(kontext),
        titel: titel,
        regelHinweis: regelHinweis,
      );

  @override
  WildnisErgebnis auswerten(
    KartoWildnisKontext kontext,
    ProbeResult probe, {
    required DiceRoller roller,
  }) => wildnisRationenErgebnis(
    probe,
    erschwernis: erschwernis(kontext),
    hinweis: auswertungsHinweis(kontext),
    gegenstand: inventarGegenstand,
    taetigkeit: titel,
    beschreibung: inventarBeschreibung(kontext),
  );

  @override
  String vorschauTitel(int anzahl) => 'Aussichten';

  @override
  List<WildnisErgebnisZeile> vorschau(KartoWildnisKontext kontext) {
    if (probeEingabe(kontext) == null) return const <WildnisErgebnisZeile>[];
    final aussicht = wildnisAussicht(
      baueProbe(kontext),
      ausbeute: (tap) => ausbeuteFuerTap(kontext, tap),
    );
    final prozent = (aussicht.erfolgschance * 100).round();
    final erwartet = aussicht.erwarteteAusbeute
        .toStringAsFixed(1)
        .replaceAll('.', ',');
    return <WildnisErgebnisZeile>[
      WildnisErgebnisZeile(titel: 'Erfolgschance', detail: '$prozent %'),
      WildnisErgebnisZeile(
        titel: 'Erwartete Ausbeute',
        detail:
            'Ø $erwartet Tagesrationen · höchstens '
            '${aussicht.hoechsteAusbeute}',
      ),
    ];
  }
}

/// Schlüssel der Beute-Wahl.
const String kBeuteOption = 'beute';

/// Antwort „nur schmackhaftes Fleisch“ der Beute-Wahl.
const String kBeuteSchmackhaft = 'schmackhaft';

/// Die Wahl „Beute: egal / nur schmackhaft“ mit dem Zuschlag [zuschlag].
KartoWildnisOption beuteOption(int zuschlag) => KartoWildnisOption(
  schluessel: kBeuteOption,
  bezeichnung: 'Beute',
  standard: 'egal',
  werte: <({String schluessel, String text})>[
    (schluessel: 'egal', text: 'Egal, auch zähes Wild (±0)'),
    (
      schluessel: kBeuteSchmackhaft,
      text: 'Nur schmackhaftes Fleisch (${mitVorzeichen(zuschlag)})',
    ),
  ],
);

/// Ob die Beute-Wahl auf „nur schmackhaft“ steht.
bool nurSchmackhaft(KartoWildnisKontext kontext) =>
    kontext.optionen[kBeuteOption] == kBeuteSchmackhaft;
