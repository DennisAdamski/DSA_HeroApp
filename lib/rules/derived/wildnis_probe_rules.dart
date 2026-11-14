import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

// Regelgrundlage: Wege des Entdeckers S. 112 f. („Nahrung sammeln“, „Kräuter
// Suchen“: Probenmodifikationen nach Sonderfertigkeiten und AsP), Zoo Botanica
// Aventurica S. 58–61 (Jagdtalente: Geländekunde und Ortskenntnis verringern
// die Erschwernis), Wege der Helden S. 276–278 (Geländekunde, Ortskenntnis).
//
// Dieses Modul ist der tätigkeitsneutrale Kern der Wildnisproben (Kräuter
// suchen, Nahrung sammeln, Jagd …). Jede Tätigkeit bringt ihre eigene
// Basiserschwernis (Landschaft, Jahreszeit, Dauer, Beutetier) und ihre
// Auswertung mit; gemeinsam sind die Eigenschaften, der TaW als Poolwert, die
// Erleichterung durch Geländekunde, Ortskenntnis und AsP sowie die TaP*.
//
// Vorzeichen: Die Bücher nennen Erschwernisse (positiv = schwerer, negativ =
// leichter). Die Probe-Engine rechnet mit einem Poolmodifikator (positiv =
// leichter); die Erschwernis geht deshalb negiert in die Probe.

/// Erschwernis durch passende Ortskenntnis (Sonderfertigkeit).
const int kOrtskenntnisErschwernis = -7;

/// AsP, die einen Erschwernispunkt aufwiegen (je 3 eingesetzte AsP −1).
const int kWildnisAspProErleichterung = 3;

/// Welche Geländekunde der Held für das durchsuchte Gelände hat.
enum Gelaendekunde {
  /// Keine passende Geländekunde.
  keine(0),

  /// Ähnliche Geländekunde (Meisterentscheid).
  aehnlich(-1),

  /// Passende Geländekunde.
  passend(-3);

  const Gelaendekunde(this.erschwernis);

  /// Erschwernis der Probe.
  final int erschwernis;
}

/// Geländearten der Sonderfertigkeit Geländekunde (Wege der Helden S. 276 f.).
enum Gelaendeart {
  /// Wald.
  wald('Wald', 'Waldkundig'),

  /// Dschungel.
  dschungel('Dschungel', 'Dschungelkundig'),

  /// Maraskan.
  maraskan('Maraskan', 'Maraskankundig'),

  /// Sumpf.
  sumpf('Sumpf', 'Sumpfkundig'),

  /// Steppe.
  steppe('Steppe', 'Steppenkundig'),

  /// Gebirge.
  gebirge('Gebirge', 'Gebirgskundig'),

  /// Wüste.
  wueste('Wüste', 'Wüstenkundig'),

  /// Eis.
  eis('Eis', 'Eiskundig'),

  /// Höhle.
  hoehle('Höhle', 'Höhlenkundig'),

  /// Meer.
  meer('Meer', 'Meereskundig');

  const Gelaendeart(this.bezeichnung, this.variante);

  /// Anzeigename des Geländes.
  final String bezeichnung;

  /// Variante der Sonderfertigkeit im Katalog (`Waldkundig`).
  final String variante;
}

/// Eine wählbare Landschaft einer Wildnistätigkeit.
///
/// Die Tätigkeit liefert ihre eigene Liste (Kräuter: die Landschaften der
/// Kräutertabellen; Jagd: die Landschaftstabellen der Zoo Botanica). Der Kern
/// kennt nur den Schlüssel, den Anzeigenamen und die Bezüge zur Geländekunde.
class WildnisLandschaft {
  /// Erstellt eine Landschaftsoption.
  const WildnisLandschaft({
    required this.schluessel,
    required this.bezeichnung,
    this.gelaende = const <Gelaendeart>{},
    this.aehnlicheGelaende = const <Gelaendeart>{},
  });

  /// Stabiler Schlüssel innerhalb der Tätigkeit.
  final String schluessel;

  /// Anzeigename.
  final String bezeichnung;

  /// Gelände, für das eine Geländekunde hier **passt**.
  final Set<Gelaendeart> gelaende;

  /// Gelände, für das eine Geländekunde hier **ähnlich** passt
  /// (Meisterentscheid, −1).
  final Set<Gelaendeart> aehnlicheGelaende;
}

/// Eingabe einer Wildnisprobe.
class WildnisProbeEingabe {
  /// Erstellt die Eingabe.
  ///
  /// [taw] ist der Poolwert der Probe, also der TaW **bei der gewählten
  /// Dauer**. [basisErschwernis] ist die tätigkeitsspezifische Erschwernis
  /// (Landschaft, Jahreszeit, Dauer, Beutetier …); positiv = schwerer.
  const WildnisProbeEingabe({
    required this.taw,
    required this.eigenschaften,
    this.basisErschwernis = 0,
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.eingesetzteAsp = 0,
    this.situativeErschwernis = 0,
  });

  /// TaW der Probe nach Dauer.
  final int taw;

  /// Die drei Probeneigenschaften samt Wert.
  final List<ProbeTargetValue> eigenschaften;

  /// Tätigkeitsspezifische Erschwernis (positiv = schwerer).
  final int basisErschwernis;

  /// Geländekunde des Helden für die durchsuchte Landschaft.
  final Gelaendekunde gelaendekunde;

  /// Ob der Held die passende Ortskenntnis besitzt.
  final bool ortskenntnis;

  /// Eingesetzte AsP (je 3 AsP −1 Erschwernis).
  final int eingesetzteAsp;

  /// Weitere Erschwernis (positiv) oder Erleichterung (negativ) des Meisters.
  final int situativeErschwernis;
}

/// Gesamterschwernis einer Wildnisprobe (positiv = schwerer).
///
/// Summe aus Basiserschwernis, Geländekunde (−3/−1), passender Ortskenntnis
/// (−7), eingesetzten AsP (je 3 AsP −1) und situativer Erschwernis.
int wildnisProbenErschwernis(WildnisProbeEingabe eingabe) {
  final asp = eingabe.eingesetzteAsp < 0 ? 0 : eingabe.eingesetzteAsp;
  return eingabe.basisErschwernis +
      eingabe.gelaendekunde.erschwernis +
      (eingabe.ortskenntnis ? kOrtskenntnisErschwernis : 0) -
      asp ~/ kWildnisAspProErleichterung +
      eingabe.situativeErschwernis;
}

/// Baut die Talentprobe einer Wildnistätigkeit (3W20 gegen die Eigenschaften,
/// TaW als Pool, Erschwernis als negativer Modifikator).
ResolvedProbeRequest baueWildnisProbe(
  WildnisProbeEingabe eingabe, {
  required String titel,
  required String regelHinweis,
}) {
  if (eingabe.eigenschaften.length != 3) {
    throw ArgumentError.value(
      eingabe.eigenschaften.length,
      'eigenschaften',
      'Eine Wildnisprobe würfelt gegen genau drei Eigenschaften.',
    );
  }
  return ResolvedProbeRequest(
    type: ProbeType.talent,
    title: titel,
    subtitle: eingabe.eigenschaften.map((e) => e.label).join('/'),
    ruleHint: regelHinweis,
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: List<ProbeTargetValue>.unmodifiable(eingabe.eigenschaften),
    basePool: eingabe.taw,
    initialSituationalModifier: -wildnisProbenErschwernis(eingabe),
  );
}

/// TaP* einer Wildnisprobe: bei Misserfolg 0, sonst die übrigen Punkte,
/// mindestens 1 (Basisregelwerk S. 113 f.: eine gelungene Probe gilt immer als
/// mindestens 1 TaP*) und höchstens der TaW der Probe (Wege des Entdeckers
/// S. 106: bei Metatalenten dürfen die TaP* den TaW nicht übersteigen, auch
/// wenn die Probe erleichtert ist).
int wildnisTapStern(ProbeResult probe) {
  if (!probe.success) return 0;
  final deckel = probe.request.basePool < 1 ? 1 : probe.request.basePool;
  final rest = probe.remainingPool < 1 ? 1 : probe.remainingPool;
  return rest > deckel ? deckel : rest;
}

/// Eine Zeile der Ergebnisanzeige einer Wildnistätigkeit.
class WildnisErgebnisZeile {
  /// Erstellt eine Zeile.
  const WildnisErgebnisZeile({
    required this.titel,
    this.detail = '',
    this.erlaeuterung = const <String>[],
    this.quelle = '',
  });

  /// Hauptzeile (z. B. „Donf“).
  final String titel;

  /// Zusatz (z. B. „2 Grundmengen · Suchschwierigkeit 6“).
  final String detail;

  /// Weitere Angaben zum Aufklappen (Wirkung, Erntezeit, Beschreibung …);
  /// leer, wenn es nichts aufzuklappen gibt.
  final List<String> erlaeuterung;

  /// Fundstelle für weitere Angaben; leer ohne Angabe.
  final String quelle;

  /// Ob die Zeile aufklappbare Angaben trägt.
  bool get hatErlaeuterung => erlaeuterung.isNotEmpty || quelle.isNotEmpty;
}

/// Tätigkeitsneutrales Ergebnis einer Wildnisprobe für die Anzeige.
class WildnisErgebnis {
  /// Erstellt ein Ergebnis.
  const WildnisErgebnis({
    required this.probe,
    required this.erschwernis,
    required this.tapStern,
    this.zeilen = const <WildnisErgebnisZeile>[],
    this.hinweis = '',
  });

  /// Die ausgewertete Talentprobe.
  final ProbeResult probe;

  /// Gesamterschwernis (positiv = schwerer).
  final int erschwernis;

  /// TaP* der Probe (0 bei Misserfolg, sonst mindestens 1).
  final int tapStern;

  /// Ausbeute der Tätigkeit (Kräuter, Rationen, Beute …).
  final List<WildnisErgebnisZeile> zeilen;

  /// Erläuterung zu Sonderfällen; leer ohne Besonderheit.
  final String hinweis;

  /// Ob die Probe gelungen ist.
  bool get erfolg => probe.success;
}
