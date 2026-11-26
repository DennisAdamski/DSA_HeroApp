import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';

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

/// Wie stark eine Geländekunde eine bestimmte Tätigkeit erleichtert.
///
/// Fast alle Wildnisproben rechnen passend −3 und ähnlich −1
/// ([GelaendekundeStaffel.standard]); das Aufstellen von Tierfallen kennt
/// −5 und −3 (Wege des Entdeckers S. 111 f.).
class GelaendekundeStaffel {
  /// Erstellt eine Staffel (Erschwernisse, also negativ = leichter).
  const GelaendekundeStaffel({required this.passend, required this.aehnlich});

  /// Passend −3, ähnlich −1 (Nahrung sammeln, Kräuter Suchen, Jagd, Fischen).
  static const GelaendekundeStaffel standard = GelaendekundeStaffel(
    passend: -3,
    aehnlich: -1,
  );

  /// Erschwernis bei passender Geländekunde.
  final int passend;

  /// Erschwernis bei ähnlicher Geländekunde (Meisterentscheid).
  final int aehnlich;

  /// Erschwernis der Stufe [stufe].
  int erschwernis(Gelaendekunde stufe) => switch (stufe) {
    Gelaendekunde.keine => 0,
    Gelaendekunde.aehnlich => aehnlich,
    Gelaendekunde.passend => passend,
  };
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
    this.gelaendekundeStaffel = GelaendekundeStaffel.standard,
  });

  /// TaW der Probe nach Dauer.
  final int taw;

  /// Was die Geländekunde bei dieser Tätigkeit wert ist.
  final GelaendekundeStaffel gelaendekundeStaffel;

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
/// Summe aus Basiserschwernis, Geländekunde (nach
/// [WildnisProbeEingabe.gelaendekundeStaffel], meist −3/−1), passender
/// Ortskenntnis (−7), eingesetzten AsP (je 3 AsP −1) und situativer
/// Erschwernis.
int wildnisProbenErschwernis(WildnisProbeEingabe eingabe) {
  return eingabe.basisErschwernis +
      eingabe.gelaendekundeStaffel.erschwernis(eingabe.gelaendekunde) +
      (eingabe.ortskenntnis ? kOrtskenntnisErschwernis : 0) +
      wildnisAspErschwernis(eingabe.eingesetzteAsp) +
      eingabe.situativeErschwernis;
}

/// Erschwernis durch eingesetzte AsP: je 3 AsP −1, negative Angaben zählen
/// nicht.
int wildnisAspErschwernis(int eingesetzteAsp) =>
    eingesetzteAsp < 0 ? 0 : -(eingesetzteAsp ~/ kWildnisAspProErleichterung);

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
    this.rationen,
    this.funde = const <WildnisPosten>[],
    this.munition,
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

  /// Tagesrationen, die sich ins Inventar buchen lassen; `null`, wenn die
  /// Tätigkeit keine bringt oder die Probe misslang.
  final WildnisPosten? rationen;

  /// Weitere Funde fürs Inventar (gefundene Kräuter, Würz- und
  /// Konservierungsmittel); leer, wenn die Tätigkeit keine bringt.
  final List<WildnisPosten> funde;

  /// Alles, was sich aus diesem Ergebnis ins Inventar buchen lässt.
  List<WildnisPosten> get inventarPosten => <WildnisPosten>[
    ?rationen,
    ...funde,
  ];

  /// Munition, deren Verlust zu würfeln ist (Jagd); `null` ohne.
  final WildnisMunition? munition;

  /// Ob die Probe gelungen ist.
  bool get erfolg => probe.success;
}

/// Ergebnis einer Wildnisprobe, deren TaP* unmittelbar Tagesrationen sind
/// (Pirsch- und Ansitzjagd, Tierfallen, Fischen; Wege des Entdeckers
/// S. 107–112: „Die TaP* … nennt die Zahl der Tagesrationen“).
///
/// [hinweis] erläutert Verbrauch, Wiederholbarkeit und Ähnliches; bei
/// Misserfolg entfällt die Ausbeutezeile. Mit [gegenstand] lassen sich die
/// Rationen als dieser Eintrag ins Inventar buchen ([WildnisErgebnis.rationen],
/// Herkunft [taetigkeit], Beschreibung [beschreibung]); [munition] nennt die
/// Geschosse, deren Verlust zu würfeln ist.
WildnisErgebnis wildnisRationenErgebnis(
  ProbeResult probe, {
  required int erschwernis,
  String hinweis = '',
  String? gegenstand,
  String taetigkeit = '',
  String beschreibung = '',
  WildnisMunition? munition,
}) {
  final tap = wildnisTapStern(probe);
  return WildnisErgebnis(
    probe: probe,
    erschwernis: erschwernis,
    tapStern: tap,
    zeilen: <WildnisErgebnisZeile>[
      if (tap > 0)
        WildnisErgebnisZeile(
          titel: tap == 1 ? '1 Tagesration' : '$tap Tagesrationen',
          detail: 'je TaP* eine Ration',
        ),
    ],
    hinweis: hinweis,
    rationen: gegenstand == null || tap <= 0
        ? null
        : WildnisPosten(
            gegenstand: gegenstand,
            anzahl: tap,
            taetigkeit: taetigkeit,
            beschreibung: beschreibung,
          ),
    munition: munition,
  );
}

/// Höchstzahl zwischengespeicherter Verteilungen ([wildnisTapVerteilung]).
const int _kVerteilungsSpeicher = 64;

final Map<String, Map<int, double>> _verteilungen =
    <String, Map<int, double>>{};

/// Verteilung der TaP* einer Wildnisprobe über alle 8000 Wurfkombinationen.
///
/// Schlüssel 0 steht für Misserfolg, alle anderen Schlüssel für die TaP* einer
/// gelungenen Probe ([wildnisTapStern]); die Werte summieren sich zu 1. Das
/// Ergebnis hängt nur von Eigenschaften, Pool und Modifikator ab und wird
/// deshalb zwischengespeichert, damit die Vorschau beim Neuzeichnen nicht
/// jedes Mal 8000 Proben auswertet.
Map<int, double> wildnisTapVerteilung(ResolvedProbeRequest request) {
  final schluessel = <Object>[
    request.type.name,
    request.basePool,
    request.initialSituationalModifier,
    for (final ziel in request.targets) ziel.value,
  ].join('|');
  final gemerkt = _verteilungen[schluessel];
  if (gemerkt != null) return gemerkt;

  final haeufigkeit = <int, int>{};
  for (var a = 1; a <= 20; a++) {
    for (var b = 1; b <= 20; b++) {
      for (var c = 1; c <= 20; c++) {
        final probe = evaluateProbe(
          request,
          ProbeRollInput(
            mode: ProbeRollMode.manual,
            diceValues: <int>[a, b, c],
            situationalModifier: request.initialSituationalModifier,
            specializationApplied: false,
          ),
        );
        final tap = wildnisTapStern(probe);
        haeufigkeit[tap] = (haeufigkeit[tap] ?? 0) + 1;
      }
    }
  }
  final sortiert = haeufigkeit.keys.toList()..sort();
  final verteilung = Map<int, double>.unmodifiable(<int, double>{
    for (final tap in sortiert) tap: haeufigkeit[tap]! / 8000,
  });
  if (_verteilungen.length >= _kVerteilungsSpeicher) _verteilungen.clear();
  _verteilungen[schluessel] = verteilung;
  return verteilung;
}

/// Aussichten einer Wildnisprobe vor dem Wurf.
class WildnisAussicht {
  /// Erstellt die Aussicht.
  const WildnisAussicht({
    required this.erfolgschance,
    required this.erwarteteAusbeute,
    required this.hoechsteAusbeute,
  });

  /// Wahrscheinlichkeit einer gelungenen Probe (0 bis 1).
  final double erfolgschance;

  /// Erwartete Ausbeute (Misserfolg zählt 0).
  final double erwarteteAusbeute;

  /// Größte erreichbare Ausbeute.
  final int hoechsteAusbeute;
}

/// Aussichten der Probe [request], wenn [ausbeute] die TaP* einer gelungenen
/// Probe in die Ausbeute übersetzt (etwa Tagesrationen); ohne Angabe zählt
/// jeder TaP* einfach.
WildnisAussicht wildnisAussicht(
  ResolvedProbeRequest request, {
  int Function(int tapStern)? ausbeute,
}) {
  final umrechnung = ausbeute ?? (int tap) => tap;
  var chance = 0.0;
  var erwartet = 0.0;
  var hoechste = 0;
  wildnisTapVerteilung(request).forEach((tap, p) {
    if (tap <= 0) return;
    final menge = umrechnung(tap);
    chance += p;
    erwartet += p * menge;
    if (menge > hoechste) hoechste = menge;
  });
  return WildnisAussicht(
    erfolgschance: chance,
    erwarteteAusbeute: erwartet,
    hoechsteAusbeute: hoechste,
  );
}
