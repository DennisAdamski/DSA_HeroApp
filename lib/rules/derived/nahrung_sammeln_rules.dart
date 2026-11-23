import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

// Regelgrundlage: Wege des Entdeckers S. 112 f. („Nahrung sammeln“: Metatalent
// aus Wildnisleben, Sinnenschärfe und Pflanzenkunde, MU/IN/FF, eine Stunde,
// jede weitere Viertelstunde −1, Region, Geländekunde, Ortskenntnis, AsP;
// Ausbeute: eine nicht haltbare Tagesration, je 3 TaP* eine weitere, oder je
// TaP* eine Haltbarkeitsstufe; Vergiftungsgefahr ohne passende Geländekunde)
// und S. 122 („Haltbarkeit von Pflanzenprodukten“, Stufen 1 bis 4, Klima).
//
// Die Jahreszeit hat bei Nahrung sammeln keinen festen Wert (das Buch nennt
// sie nur als Einfluss); sie bleibt Meisterentscheid über die situative
// Erschwernis.

/// Talente des Metatalents Nahrung sammeln.
const List<String> kNahrungSammelnTalente = <String>[
  'tal_wildnisleben',
  'tal_sinnesschaerfe',
  'tal_pflanzenkunde',
];

/// Talent, das in landwirtschaftlich genutzten Gebieten die Pflanzenkunde
/// ersetzen darf (WdE S. 113, Fußnote).
const String kNahrungSammelnErsatztalent = 'tal_ackerbau';

/// Grunddauer der Suche in Minuten.
const int kNahrungSammelnGrundMinuten = 60;

/// Je so viele Minuten über der Grunddauer sinkt die Erschwernis um 1.
const int kNahrungSammelnMinutenProPunkt = 15;

/// Je so viele TaP* bringen eine weitere Tagesration.
const int kNahrungSammelnTapProRation = 3;

/// Talente der Probe; mit [ackerbau] ersetzt Ackerbau die Pflanzenkunde.
List<String> nahrungSammelnTalente({bool ackerbau = false}) => <String>[
  for (final id in kNahrungSammelnTalente)
    id == 'tal_pflanzenkunde' && ackerbau ? kNahrungSammelnErsatztalent : id,
];

/// Erschwernis durch die Region (WdE S. 113).
int nahrungSammelnRegionsErschwernis(Wildnisregion region) => switch (region) {
  Wildnisregion.lichterWald => -6,
  Wildnisregion.graslandHeide => -4,
  Wildnisregion.dschungel ||
  Wildnisregion.savanneSteppe ||
  Wildnisregion.gebirge => -2,
  Wildnisregion.dichterWald || Wildnisregion.maraskanDschungel => 0,
  Wildnisregion.suempfeSued || Wildnisregion.tundra => 2,
  Wildnisregion.suempfeNord => 4,
  Wildnisregion.hochgebirge => 6,
  Wildnisregion.wueste || Wildnisregion.ewigesEis => 12,
};

/// Erschwernis durch die Dauer: jede volle Viertelstunde über einer Stunde
/// −1; kürzere Suchen gibt es nicht.
int nahrungSammelnDauerErschwernis(int dauerMinuten) {
  if (dauerMinuten < kNahrungSammelnGrundMinuten) {
    throw ArgumentError.value(
      dauerMinuten,
      'dauerMinuten',
      'Nahrung sammeln dauert mindestens eine Stunde.',
    );
  }
  return -((dauerMinuten - kNahrungSammelnGrundMinuten) ~/
      kNahrungSammelnMinutenProPunkt);
}

/// Haltbarkeit von Pflanzenprodukten (WdE S. 122).
enum Haltbarkeitsstufe {
  /// Beeren, druckempfindliches Obst, Pilze.
  eins(1, 'nach einem Tag unappetitlich, nach einem weiteren ungenießbar'),

  /// Weniger empfindliches Obst, weiches Gemüse, Kräuter.
  zwei(2, 'drei bis vier Tage appetitlich, noch einmal so lange genießbar'),

  /// Viele Gemüsesorten, Wurzeln.
  drei(3, 'eine Woche gut, in der Folgewoche noch genießbar'),

  /// Nüsse, Trockenobst.
  vier(4, 'trocken gelagert noch nach Monaten genießbar');

  const Haltbarkeitsstufe(this.stufe, this.dauer);

  /// Stufe 1 bis 4.
  final int stufe;

  /// Wie lange die Nahrung hält (mildes Klima).
  final String dauer;

  /// Stufe zum Wert, begrenzt auf 1 bis 4.
  static Haltbarkeitsstufe ausStufe(int stufe) =>
      Haltbarkeitsstufe.values[(stufe < 1 ? 1 : (stufe > 4 ? 4 : stufe)) - 1];
}

/// Eingabe einer Nahrungssuche.
class NahrungSammelnEingabe {
  /// Erstellt die Eingabe.
  ///
  /// [taw] ist der TaW des Metatalents ([nahrungSammelnTalente]),
  /// [eigenschaften] sind MU/IN/FF mit Werten. [haltbarkeitsziel] ist die
  /// Haltbarkeit, die der Sammler anstrebt; jede Stufe über 1 kostet einen
  /// TaP*, der Rest geht in Rationen.
  const NahrungSammelnEingabe({
    required this.region,
    required this.taw,
    required this.eigenschaften,
    this.dauerMinuten = kNahrungSammelnGrundMinuten,
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.eingesetzteAsp = 0,
    this.situativeErschwernis = 0,
    this.haltbarkeitsziel = Haltbarkeitsstufe.eins,
  });

  /// Region der Suche.
  final Wildnisregion region;

  /// TaW Nahrung sammeln.
  final int taw;

  /// Die drei Probeneigenschaften samt Wert.
  final List<ProbeTargetValue> eigenschaften;

  /// Dauer der Suche in Minuten (mindestens 60).
  final int dauerMinuten;

  /// Geländekunde des Helden.
  final Gelaendekunde gelaendekunde;

  /// Passende Ortskenntnis.
  final bool ortskenntnis;

  /// Eingesetzte AsP.
  final int eingesetzteAsp;

  /// Weitere Erschwernis (positiv) oder Erleichterung (negativ).
  final int situativeErschwernis;

  /// Angestrebte Haltbarkeit der Ausbeute.
  final Haltbarkeitsstufe haltbarkeitsziel;
}

/// Die Nahrungssuche als allgemeine Wildnisprobe.
WildnisProbeEingabe nahrungSammelnProbeEingabe(NahrungSammelnEingabe e) =>
    WildnisProbeEingabe(
      taw: e.taw,
      eigenschaften: e.eigenschaften,
      basisErschwernis:
          nahrungSammelnRegionsErschwernis(e.region) +
          nahrungSammelnDauerErschwernis(e.dauerMinuten),
      gelaendekunde: e.gelaendekunde,
      ortskenntnis: e.ortskenntnis,
      eingesetzteAsp: e.eingesetzteAsp,
      situativeErschwernis: e.situativeErschwernis,
    );

/// Gesamterschwernis der Nahrungssuche (positiv = schwerer).
int nahrungSammelnErschwernis(NahrungSammelnEingabe e) =>
    wildnisProbenErschwernis(nahrungSammelnProbeEingabe(e));

/// Baut die Probe „Nahrung sammeln“ (MU/IN/FF, TaW als Pool).
ResolvedProbeRequest baueNahrungSammelnProbe(NahrungSammelnEingabe e) =>
    baueWildnisProbe(
      nahrungSammelnProbeEingabe(e),
      titel: 'Nahrung sammeln',
      regelHinweis: 'Wege des Entdeckers S. 112 f.',
    );

/// Was eine gelungene Nahrungssuche einbringt.
class NahrungSammelnAusbeute {
  /// Erstellt die Ausbeute.
  const NahrungSammelnAusbeute({
    required this.rationen,
    required this.haltbarkeit,
    required this.restpunkte,
  });

  /// Keine Ausbeute (misslungene Probe).
  static const NahrungSammelnAusbeute keine = NahrungSammelnAusbeute(
    rationen: 0,
    haltbarkeit: Haltbarkeitsstufe.eins,
    restpunkte: 0,
  );

  /// Gefundene Tagesrationen.
  final int rationen;

  /// Haltbarkeit der gesamten Ausbeute.
  final Haltbarkeitsstufe haltbarkeit;

  /// TaP*, die weder eine Ration noch eine Stufe ergaben.
  final int restpunkte;
}

/// Setzt [tapStern] in Rationen und Haltbarkeit um.
///
/// Eine gelungene Probe bringt eine nicht haltbare Tagesration (Stufe 1).
/// Zuerst heben TaP* die Haltbarkeit der ganzen Ausbeute je um eine Stufe bis
/// [ziel], die übrigen bringen je 3 eine weitere Ration.
NahrungSammelnAusbeute nahrungSammelnAusbeute(
  int tapStern, {
  Haltbarkeitsstufe ziel = Haltbarkeitsstufe.eins,
}) {
  if (tapStern <= 0) return NahrungSammelnAusbeute.keine;
  final stufen = ziel.stufe - 1 < tapStern ? ziel.stufe - 1 : tapStern;
  final rest = tapStern - stufen;
  return NahrungSammelnAusbeute(
    rationen: 1 + rest ~/ kNahrungSammelnTapProRation,
    haltbarkeit: Haltbarkeitsstufe.ausStufe(1 + stufen),
    restpunkte: rest % kNahrungSammelnTapProRation,
  );
}

/// Augenzahlen auf 1W20, bei denen ein Sammler ohne passende Geländekunde
/// etwas Giftiges erwischt (WdE S. 112): 19–20, im Dschungel 18–20, auf
/// Maraskan 16–20.
({int von, int bis}) nahrungSammelnGiftwurf(Wildnisregion region) =>
    switch (region) {
      Wildnisregion.maraskanDschungel => (von: 16, bis: 20),
      Wildnisregion.dschungel => (von: 18, bis: 20),
      _ => (von: 19, bis: 20),
    };

/// Wie das Klima der Region die Haltbarkeit verändert (WdE S. 122); leer,
/// wenn die Angaben für mildes Klima gelten.
String nahrungHaltbarkeitKlima(Wildnisregion region) => switch (region) {
  Wildnisregion.dschungel ||
  Wildnisregion.maraskanDschungel ||
  Wildnisregion.suempfeSued => 'Feucht-heißes Klima halbiert die Haltbarkeit.',
  Wildnisregion.tundra || Wildnisregion.hochgebirge =>
    'Kühles Klima verlängert die Haltbarkeit um die Hälfte.',
  Wildnisregion.ewigesEis =>
    'Bei Dauerfrost hält sich die Nahrung, muss nach dem Auftauen aber '
        'sofort gegessen werden.',
  _ => '',
};

/// Wertet eine gelungene oder misslungene Nahrungssuche aus.
///
/// Ohne passende Geländekunde nennt der Hinweis den verdeckten Giftwurf des
/// Meisters; die App würfelt ihn bewusst nicht.
WildnisErgebnis werteNahrungSammelnAus(
  NahrungSammelnEingabe e,
  ProbeResult probe,
) {
  final tap = wildnisTapStern(probe);
  final ausbeute = nahrungSammelnAusbeute(tap, ziel: e.haltbarkeitsziel);
  final gift = nahrungSammelnGiftwurf(e.region);
  final klima = nahrungHaltbarkeitKlima(e.region);
  final hinweise = <String>[
    if (tap > 0 && e.gelaendekunde != Gelaendekunde.passend)
      'Ohne passende Geländekunde würfelt der Meister verdeckt 1W20: bei '
          '${gift.von}–${gift.bis} ist etwas Giftiges dabei (Giftstufe 1W6).',
    if (tap > 0 && klima.isNotEmpty) klima,
  ];
  return WildnisErgebnis(
    probe: probe,
    erschwernis: nahrungSammelnErschwernis(e),
    tapStern: tap,
    zeilen: <WildnisErgebnisZeile>[
      if (ausbeute.rationen > 0)
        WildnisErgebnisZeile(
          titel: ausbeute.rationen == 1
              ? '1 Tagesration'
              : '${ausbeute.rationen} Tagesrationen',
          detail:
              'Haltbarkeit ${ausbeute.haltbarkeit.stufe}: '
              '${ausbeute.haltbarkeit.dauer}',
        ),
      if (ausbeute.restpunkte > 0)
        WildnisErgebnisZeile(
          titel: 'Restpunkte',
          detail:
              '${ausbeute.restpunkte} TaP* (je '
              '$kNahrungSammelnTapProRation eine weitere Ration)',
        ),
    ],
    hinweis: hinweise.join(' '),
    rationen: ausbeute.rationen <= 0
        ? null
        : WildnisRationen(
            gegenstand:
                'Gesammelte Nahrung (Haltbarkeit '
                '${ausbeute.haltbarkeit.stufe})',
            anzahl: ausbeute.rationen,
            taetigkeit: 'Nahrung sammeln',
            beschreibung: <String>[
              'Haltbarkeit ${ausbeute.haltbarkeit.stufe}: '
                  '${ausbeute.haltbarkeit.dauer} (mildes Klima, WdE S. 122).',
              if (klima.isNotEmpty) klima,
              if (e.gelaendekunde != Gelaendekunde.passend)
                'Ohne passende Geländekunde gesammelt: Giftwurf beachten.',
            ].join(' '),
          ),
  );
}
