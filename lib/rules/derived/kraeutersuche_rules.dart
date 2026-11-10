import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';

// Regelgrundlage: Wege des Entdeckers S. 113 f. („Kräuter Suchen“) und
// S. 114–118 (Landschaftstabellen „Kräuter und ihre Verbreitung“); TaP*-Minimum
// bei gelungener Probe: Basisregelwerk S. 113 f.
//
// Vorzeichen: Die Bücher nennen Erschwernisse (positiv = schwerer, negativ =
// leichter). Die Probe-Engine rechnet mit einem Poolmodifikator (positiv =
// leichter); [kraeuterProbenErschwernis] liefert deshalb die Erschwernis, die
// Probe erhält ihr Negativ.

/// Anzahl der Stunden einer normalen Suche.
const int kKraeuterSucheNormaleStunden = 1;

/// Anzahl der Stunden einer ausführlichen Suche.
const int kKraeuterSucheAusfuehrlicheStunden = 2;

/// Höchste Erleichterung einer einzelnen Kochen-Probe durch Würzkräuter.
const int kWuerzkraeuterMaxErleichterungProKochenProbe = 3;

/// Erschwernis durch passende Ortskenntnis (Sonderfertigkeit).
const int kKraeuterOrtskenntnisErschwernis = -7;

/// Welche Geländekunde der Held für die durchsuchte Landschaft hat.
enum Gelaendekunde {
  /// Keine passende Geländekunde.
  keine(0),

  /// Ähnliche Geländekunde (Meisterentscheid).
  aehnlich(-1),

  /// Passende Geländekunde.
  passend(-3);

  const Gelaendekunde(this.erschwernis);

  /// Erschwernis der Kräuter-Suchen-Probe.
  final int erschwernis;
}

/// Was der Held sucht.
enum KraeuterSuchmodus {
  /// Beliebige Kräuter der Region: die TaP* werden in Funde umgesetzt.
  beliebig,

  /// Ein bestimmtes Kraut (oder eine Heilwirkung): die TaP* ergeben die Zahl
  /// der Grundmengen.
  gezielt,

  /// Würzkräuter: die halben TaP* erleichtern Kochen-Proben.
  wuerz,

  /// Konservierungsmittel: je TaP* ein Tag Haltbarkeit.
  konservierung,
}

/// Wie die Erntezeit der Kräuter berücksichtigt wird.
enum ErntezeitModus {
  /// Nur Kräuter, deren nutzbare Teile im Monat der Suche zu ernten sind (Zoo
  /// Botanica, Herbarium: Angabe „Ernte“). Ohne Monat gilt jedes Kraut.
  nurErntezeit,

  /// Alle Kräuter der Landschaft, unabhängig vom Monat; die Erntezeit steht
  /// nur als Kennzeichnung am Kandidaten.
  alle,
}

/// Jahreszeit zu einem Monatsschlüssel des aventurischen Kalenders.
///
/// Grundlage ist der Sonnenlauf (Geographia Aventurica S. 189): Sommer ab dem
/// 1. Praios (Sonnenwende), Herbst ab dem 1. Travia, Winter ab dem 1. Firun,
/// Frühling ab dem 1. Peraine, je drei Monate. Die Namenlosen Tage schließen
/// das Jahr und zählen zum Frühling (Ende des Rahja-Mondes). Unbekannte
/// Monate ergeben `null`.
Jahreszeit? jahreszeitFuerMonat(String monat) {
  switch (normalizeAventurianMonth(monat)) {
    case 'praios':
    case 'rondra':
    case 'efferd':
      return Jahreszeit.sommer;
    case 'travia':
    case 'boron':
    case 'hesinde':
      return Jahreszeit.herbst;
    case 'firun':
    case 'tsa':
    case 'phex':
      return Jahreszeit.winter;
    case 'peraine':
    case 'ingerimm':
    case 'rahja':
    case aventurianNamenloseTageKey:
      return Jahreszeit.fruehling;
  }
  return null;
}

/// Erschwernis der Kräuter-Suchen-Probe durch Landschaft und Jahreszeit.
///
/// Die Werte stammen aus der Zeile „Modifikation der Probe nach Jahreszeit“ der
/// Landschaftstabellen (WdE S. 115–118). Sie enthalten bereits den
/// Regionszuschlag des Nahrungssammelns (S. 112); er wird nicht zusätzlich
/// angesetzt.
int kraeuterLandschaftsErschwernis(
  Kraeuterlandschaft landschaft,
  Jahreszeit jahreszeit,
) {
  // Reihenfolge je Eintrag: Frühling, Sommer, Herbst, Winter.
  final werte = switch (landschaft) {
    Kraeuterlandschaft.dichterWald => const <int>[4, 0, 0, 6],
    Kraeuterlandschaft.lichterWald => const <int>[-2, -6, -6, 0],
    Kraeuterlandschaft.dschungel => const <int>[-2, -2, -2, -2],
    Kraeuterlandschaft.maraskanDschungel => const <int>[0, 0, 0, 0],
    Kraeuterlandschaft.suempfeNord => const <int>[6, 4, 4, 8],
    Kraeuterlandschaft.suempfeSued => const <int>[2, 2, 2, 2],
    Kraeuterlandschaft.tundra => const <int>[6, 2, 2, 8],
    Kraeuterlandschaft.graslandHeide => const <int>[0, -4, -4, 2],
    Kraeuterlandschaft.savanneSteppe => const <int>[-2, -2, -2, -2],
    Kraeuterlandschaft.gebirge => const <int>[2, -2, -2, 4],
    Kraeuterlandschaft.hochgebirge => const <int>[10, 6, 6, 12],
    Kraeuterlandschaft.wueste => const <int>[12, 12, 12, 12],
  };
  return werte[switch (jahreszeit) {
    Jahreszeit.fruehling => 0,
    Jahreszeit.sommer => 1,
    Jahreszeit.herbst => 2,
    Jahreszeit.winter => 3,
  }];
}

/// Suchschwierigkeit von „Kräutern aller Art“ in [landschaft], ohne
/// bestimmte Pflanze (etwa für eine Heilwirkung, die nicht in der Zoo Botanica
/// steht).
///
/// Es gilt der Gesamtwert der Tabellenzeile „Suchschwierigkeit von Kräutern
/// aller Art“. Die genannten Summanden ergeben im Buch nicht überall diesen
/// Wert (z. B. Wüste: Bestimmung +2, selten +16 = +6); maßgeblich ist die
/// angegebene Summe.
int kraeuterPauschalSuchschwierigkeit(Kraeuterlandschaft landschaft) {
  return switch (landschaft) {
    Kraeuterlandschaft.lichterWald => 2,
    Kraeuterlandschaft.dschungel => 8,
    _ => 6,
  };
}

/// Suchschwierigkeit eines Krauts bei Vorkommen [vorkommen]: Bestimmung plus
/// Häufigkeitsaufschlag.
int kraeuterSuchschwierigkeit(KrautEintrag kraut, KrautVorkommen vorkommen) {
  return kraut.bestimmung + vorkommen.haeufigkeit.aufschlag;
}

/// TaW der Suche nach Dauer: bei zwei Stunden steigt er um die Hälfte
/// (kaufmännisch gerundet, also bei halben Punkten nach oben).
int kraeuterSuchenTawBeiDauer(int taw, int dauerStunden) {
  if (dauerStunden == kKraeuterSucheNormaleStunden) return taw;
  if (dauerStunden == kKraeuterSucheAusfuehrlicheStunden) {
    return (taw * 3 + (taw >= 0 ? 1 : 0)) ~/ 2;
  }
  throw ArgumentError.value(
    dauerStunden,
    'dauerStunden',
    'Die Suche dauert eine oder zwei Stunden.',
  );
}

/// Eingabe einer Kräutersuche.
class KraeuterSucheEingabe {
  /// Erstellt die Eingabe.
  ///
  /// [taw] ist der TaW „Kräuter Suchen“ bei einstündiger Suche (Mittel aus
  /// Wildnisleben, Sinnesschärfe und Pflanzenkunde, höchstens das Doppelte des
  /// niedrigsten; siehe `computeMetaTalentBaseTaw`). [eigenschaften] sind die
  /// drei Probeneigenschaften mit Werten (laut Buch KL/IN/FF).
  const KraeuterSucheEingabe({
    required this.landschaft,
    required this.jahreszeit,
    required this.taw,
    required this.eigenschaften,
    this.dauerStunden = kKraeuterSucheNormaleStunden,
    this.gelaendekunde = Gelaendekunde.keine,
    this.ortskenntnis = false,
    this.eingesetzteAsp = 0,
    this.situativeErschwernis = 0,
    this.modus = KraeuterSuchmodus.beliebig,
    this.zielKraut = '',
    this.ausgeschlosseneKraeuter = const <String>{},
    this.monat = '',
    this.erntezeitModus = ErntezeitModus.nurErntezeit,
  });

  /// Durchsuchte Landschaft.
  final Kraeuterlandschaft landschaft;

  /// Jahreszeit der Suche.
  final Jahreszeit jahreszeit;

  /// TaW Kräuter Suchen bei einer Stunde.
  final int taw;

  /// Die drei Probeneigenschaften samt Wert.
  final List<ProbeTargetValue> eigenschaften;

  /// Dauer der Suche: 1 oder 2 Stunden.
  final int dauerStunden;

  /// Geländekunde des Helden.
  final Gelaendekunde gelaendekunde;

  /// Ob der Held die passende Ortskenntnis besitzt.
  final bool ortskenntnis;

  /// Eingesetzte AsP (je 3 AsP −1 Erschwernis).
  final int eingesetzteAsp;

  /// Weitere Erschwernis (positiv) oder Erleichterung (negativ) des Meisters.
  final int situativeErschwernis;

  /// Suchziel.
  final KraeuterSuchmodus modus;

  /// Name des gesuchten Krauts bei [KraeuterSuchmodus.gezielt]; leer sucht eine
  /// Heilwirkung ohne bestimmte Pflanze (Pauschal-Suchschwierigkeit).
  final String zielKraut;

  /// Kräuter, die der Meister für diesen Ort ausschließt (etwa wegen der
  /// Gebietseinschränkung).
  final Set<String> ausgeschlosseneKraeuter;

  /// Monat der Suche (Schlüssel oder Anzeigename); bestimmt, welche Kräuter
  /// geerntet werden können. Leer: Erntezeit unbekannt, alle Kräuter zählen.
  final String monat;

  /// Umgang mit der Erntezeit.
  final ErntezeitModus erntezeitModus;
}

/// Gesamterschwernis der Probe (positiv = schwerer).
///
/// Summe aus Landschaft/Jahreszeit, Geländekunde (−3/−1), passender
/// Ortskenntnis (−7), eingesetzten AsP (je 3 AsP −1) und situativer
/// Erschwernis.
int kraeuterProbenErschwernis(KraeuterSucheEingabe eingabe) {
  return kraeuterLandschaftsErschwernis(
        eingabe.landschaft,
        eingabe.jahreszeit,
      ) +
      eingabe.gelaendekunde.erschwernis +
      (eingabe.ortskenntnis ? kKraeuterOrtskenntnisErschwernis : 0) -
      (eingabe.eingesetzteAsp < 0 ? 0 : eingabe.eingesetzteAsp ~/ 3) +
      eingabe.situativeErschwernis;
}

/// Baut die Talentprobe „Kräuter suchen“ (3W20 gegen die Eigenschaften, TaW
/// nach Dauer als Pool, Erschwernis als negativer Modifikator).
ResolvedProbeRequest baueKraeutersucheProbe(KraeuterSucheEingabe eingabe) {
  if (eingabe.eigenschaften.length != 3) {
    throw ArgumentError.value(
      eingabe.eigenschaften.length,
      'eigenschaften',
      'Die Kräutersuche würfelt gegen genau drei Eigenschaften.',
    );
  }
  return ResolvedProbeRequest(
    type: ProbeType.talent,
    title: 'Kräuter suchen',
    subtitle: eingabe.eigenschaften.map((e) => e.label).join('/'),
    ruleHint: 'Wege des Entdeckers S. 113',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: List<ProbeTargetValue>.unmodifiable(eingabe.eigenschaften),
    basePool: kraeuterSuchenTawBeiDauer(eingabe.taw, eingabe.dauerStunden),
    initialSituationalModifier: -kraeuterProbenErschwernis(eingabe),
  );
}

/// TaP* der Probe: bei Misserfolg 0, sonst die übrigen Punkte, mindestens 1
/// (Basisregelwerk S. 113 f.: eine gelungene Probe gilt immer als
/// mindestens 1 TaP*) und höchstens der TaW bei der gewählten Dauer (Wege des
/// Entdeckers S. 106: bei Metatalenten dürfen die TaP* den TaW nicht
/// übersteigen, auch wenn die Probe erleichtert ist).
int kraeuterTapStern(ProbeResult probe) {
  if (!probe.success) return 0;
  final deckel = probe.request.basePool < 1 ? 1 : probe.request.basePool;
  final rest = probe.remainingPool < 1 ? 1 : probe.remainingPool;
  return rest > deckel ? deckel : rest;
}

/// Ob die nutzbaren Teile von [kraut] im Monat [monat] zu ernten sind.
///
/// Ohne Monatsangabe (oder bei unbekanntem Monat) und bei ganzjährig
/// erntbaren Kräutern ist das Ergebnis `true`.
bool krautInErntezeit(KrautEintrag kraut, String monat) {
  final schluessel = normalizeAventurianMonth(monat);
  if (schluessel.isEmpty || kraut.erntemonate.isEmpty) return true;
  return kraut.erntemonate.contains(schluessel);
}

/// Ein möglicher Fund: Kraut oder Landschaft mit Suchschwierigkeit.
class KraeuterKandidat {
  /// Erstellt einen Kandidaten.
  const KraeuterKandidat({
    required this.kraut,
    required this.vorkommen,
    required this.suchschwierigkeit,
    this.inErntezeit = true,
  });

  /// Das Kraut.
  final KrautEintrag kraut;

  /// Das Vorkommen in der durchsuchten Landschaft.
  final KrautVorkommen vorkommen;

  /// Bestimmung plus Häufigkeitsaufschlag.
  final int suchschwierigkeit;

  /// Ob das Kraut im Monat der Suche zu ernten ist (ohne Monat immer `true`).
  final bool inErntezeit;
}

/// Alle Kräuter, die in [landschaft] vorkommen, ohne [ausgeschlossen].
///
/// [monat] setzt nur die Kennzeichnung [KraeuterKandidat.inErntezeit]; das
/// Ausblenden regelt die Suche über [ErntezeitModus].
///
/// Ein Kraut mit mehreren Vorkommen in der Landschaft (z. B. Donf an Seeufern
/// und Flussufern) erscheint mehrfach. Reihenfolge: häufigste zuerst, dann
/// nach Name.
List<KraeuterKandidat> moeglicheKraeuter(
  KraeuterKatalog katalog,
  Kraeuterlandschaft landschaft, {
  Set<String> ausgeschlossen = const <String>{},
  String monat = '',
}) {
  final kandidaten = <KraeuterKandidat>[
    for (final kraut in katalog.kraeuter)
      if (!ausgeschlossen.contains(kraut.name))
        for (final vorkommen in kraut.vorkommen)
          if (vorkommen.landschaft == landschaft)
            KraeuterKandidat(
              kraut: kraut,
              vorkommen: vorkommen,
              suchschwierigkeit: kraeuterSuchschwierigkeit(kraut, vorkommen),
              inErntezeit: krautInErntezeit(kraut, monat),
            ),
  ];
  kandidaten.sort((a, b) {
    final haeufigkeit = a.vorkommen.haeufigkeit.index.compareTo(
      b.vorkommen.haeufigkeit.index,
    );
    return haeufigkeit != 0
        ? haeufigkeit
        : a.kraut.name.compareTo(b.kraut.name);
  });
  return kandidaten;
}

/// Ein Fund der Suche.
class KraeuterFund {
  /// Erstellt einen Fund.
  const KraeuterFund({
    required this.bezeichnung,
    required this.grundmengen,
    this.kraut,
    this.suchschwierigkeit = 0,
  });

  /// Name des Krauts, bei Pauschalsuche die Heilwirkung.
  final String bezeichnung;

  /// Anzahl gefundener Grundmengen.
  final int grundmengen;

  /// Das Kraut aus dem Katalog; `null` bei Pauschalsuche.
  final KrautEintrag? kraut;

  /// Suchschwierigkeit, mit der der Fund verrechnet wurde.
  final int suchschwierigkeit;
}

/// Ergebnis einer Kräutersuche.
class KraeuterSucheErgebnis {
  /// Erstellt ein Ergebnis.
  const KraeuterSucheErgebnis({
    required this.probe,
    required this.erschwernis,
    required this.tawBeiDauer,
    required this.tapStern,
    this.funde = const <KraeuterFund>[],
    this.restpunkte = 0,
    this.wuerzPunkte = 0,
    this.haltbarkeitTage = 0,
    this.hinweis = '',
  });

  /// Die ausgewertete Talentprobe.
  final ProbeResult probe;

  /// Gesamterschwernis (positiv = schwerer).
  final int erschwernis;

  /// TaW der Probe nach Suchdauer.
  final int tawBeiDauer;

  /// TaP* der Probe (0 bei Misserfolg, sonst mindestens 1).
  final int tapStern;

  /// Gefundene Kräuter (Modi beliebig und gezielt).
  final List<KraeuterFund> funde;

  /// TaP*, die im Modus beliebig keinem Fund mehr zugeordnet werden konnten.
  final int restpunkte;

  /// Modus Würzkräuter: Gesamtpunkte der Erleichterung (halbe TaP*), je
  /// Kochen-Probe höchstens [kWuerzkraeuterMaxErleichterungProKochenProbe].
  final int wuerzPunkte;

  /// Modus Konservierung: zusätzliche Haltbarkeit in Tagen.
  final int haltbarkeitTage;

  /// Erläuterung zu Sonderfällen, z. B. ein Kraut, das in der Landschaft nicht
  /// vorkommt; leer ohne Besonderheit.
  final String hinweis;

  /// Ob die Probe gelungen ist.
  bool get erfolg => probe.success;
}

/// Führt die Kräutersuche aus: würfelt die Probe mit [roller] und setzt die
/// TaP* je nach Modus in Funde um.
///
/// Modus [KraeuterSuchmodus.beliebig]: Es wird ein Kraut gewählt, dessen
/// Suchschwierigkeit höchstens die Hälfte der verbleibenden TaP* beträgt; die
/// Suchschwierigkeit wird abgezogen, bis nichts mehr passt. Das Buch überlässt
/// die Wahl dem Meister; hier wird nach Häufigkeit gewichtet (sehr häufig 16,
/// häufig 8, gelegentlich 4, selten 2, sehr selten 1) über denselben [roller].
///
/// Modus [KraeuterSuchmodus.gezielt]: Grundmengen = TaP* geteilt durch die
/// halbe Suchschwierigkeit, aufgerundet. Ohne [KraeuterSucheEingabe.zielKraut]
/// gilt die Pauschal-Suchschwierigkeit der Landschaft; ein Kraut, das dort nicht
/// vorkommt, ergibt keinen Fund (Hinweis im Ergebnis).
KraeuterSucheErgebnis fuehreKraeutersucheDurch(
  KraeuterSucheEingabe eingabe,
  KraeuterKatalog katalog, {
  required DiceRoller roller,
}) {
  final request = baueKraeutersucheProbe(eingabe);
  final probe = evaluateProbe(
    request,
    createDigitalProbeRollInput(request, roller: roller),
  );
  return werteKraeutersucheAus(eingabe, katalog, probe, roller: roller);
}

/// Setzt eine bereits ausgewertete [probe] (etwa aus einem manuellen Wurf) in
/// das Ergebnis der Suche um; [roller] wählt im Modus beliebig die Funde.
KraeuterSucheErgebnis werteKraeutersucheAus(
  KraeuterSucheEingabe eingabe,
  KraeuterKatalog katalog,
  ProbeResult probe, {
  required DiceRoller roller,
}) {
  final tap = kraeuterTapStern(probe);
  final erschwernis = kraeuterProbenErschwernis(eingabe);
  final taw = kraeuterSuchenTawBeiDauer(eingabe.taw, eingabe.dauerStunden);
  KraeuterSucheErgebnis ergebnis({
    List<KraeuterFund> funde = const <KraeuterFund>[],
    int restpunkte = 0,
    int wuerzPunkte = 0,
    int haltbarkeitTage = 0,
    String hinweis = '',
  }) => KraeuterSucheErgebnis(
    probe: probe,
    erschwernis: erschwernis,
    tawBeiDauer: taw,
    tapStern: tap,
    funde: funde,
    restpunkte: restpunkte,
    wuerzPunkte: wuerzPunkte,
    haltbarkeitTage: haltbarkeitTage,
    hinweis: hinweis,
  );

  if (tap == 0) return ergebnis();

  switch (eingabe.modus) {
    case KraeuterSuchmodus.wuerz:
      return ergebnis(wuerzPunkte: (tap + 1) ~/ 2);
    case KraeuterSuchmodus.konservierung:
      return ergebnis(haltbarkeitTage: tap);
    case KraeuterSuchmodus.gezielt:
      return _gezielteSuche(eingabe, katalog, tap, ergebnis);
    case KraeuterSuchmodus.beliebig:
      return _beliebigeSuche(eingabe, katalog, tap, roller, ergebnis);
  }
}

typedef _ErgebnisBauer = KraeuterSucheErgebnis Function({
  List<KraeuterFund> funde,
  int restpunkte,
  int wuerzPunkte,
  int haltbarkeitTage,
  String hinweis,
});

/// Grundmengen für [tap] bei [suchschwierigkeit]: TaP* geteilt durch die
/// halbe Suchschwierigkeit, aufgerundet. Suchschwierigkeiten unter 1 zählen
/// als 1.
int kraeuterGrundmengen(int tap, int suchschwierigkeit) {
  final schwierigkeit = suchschwierigkeit < 1 ? 1 : suchschwierigkeit;
  return (2 * tap + schwierigkeit - 1) ~/ schwierigkeit;
}

KraeuterSucheErgebnis _gezielteSuche(
  KraeuterSucheEingabe eingabe,
  KraeuterKatalog katalog,
  int tap,
  _ErgebnisBauer ergebnis,
) {
  final ziel = eingabe.zielKraut.trim();
  if (ziel.isEmpty) {
    final schwierigkeit = kraeuterPauschalSuchschwierigkeit(eingabe.landschaft);
    return ergebnis(
      funde: <KraeuterFund>[
        KraeuterFund(
          bezeichnung: 'Heilwirkung (ohne bestimmte Pflanze)',
          grundmengen: kraeuterGrundmengen(tap, schwierigkeit),
          suchschwierigkeit: schwierigkeit,
        ),
      ],
    );
  }
  final alle = moeglicheKraeuter(
    katalog,
    eingabe.landschaft,
    ausgeschlossen: eingabe.ausgeschlosseneKraeuter,
    monat: eingabe.monat,
  ).where((k) => k.kraut.name == ziel).toList();
  if (alle.isEmpty) {
    return ergebnis(
      hinweis:
          '$ziel kommt in dieser Landschaft nicht vor oder ist '
          'ausgeschlossen.',
    );
  }
  final kandidaten = alle.where((k) => _findbar(k, eingabe)).toList();
  if (kandidaten.isEmpty) {
    final erntezeit = alle.first.kraut.erntezeit;
    return ergebnis(
      hinweis:
          '$ziel ist im ${aventurianMonthLabel(eingabe.monat)} nicht zu '
          'ernten${erntezeit.isEmpty ? '' : ' (Erntezeit: $erntezeit)'}.',
    );
  }
  // Mehrere Vorkommen (z. B. Seeufer/Flussufer): das leichteste zählt.
  final leichtestes = kandidaten.reduce(
    (a, b) => b.suchschwierigkeit < a.suchschwierigkeit ? b : a,
  );
  return ergebnis(
    funde: <KraeuterFund>[
      KraeuterFund(
        bezeichnung: leichtestes.kraut.name,
        kraut: leichtestes.kraut,
        grundmengen: kraeuterGrundmengen(tap, leichtestes.suchschwierigkeit),
        suchschwierigkeit: leichtestes.suchschwierigkeit,
      ),
    ],
  );
}

/// Kandidaten der Suche: Landschaft, ohne Ausgeschlossene, nach Erntezeit.
List<KraeuterKandidat> _kandidatenDerSuche(
  KraeuterSucheEingabe eingabe,
  KraeuterKatalog katalog,
) {
  return moeglicheKraeuter(
    katalog,
    eingabe.landschaft,
    ausgeschlossen: eingabe.ausgeschlosseneKraeuter,
    monat: eingabe.monat,
  ).where((k) => _findbar(k, eingabe)).toList();
}

bool _findbar(KraeuterKandidat kandidat, KraeuterSucheEingabe eingabe) =>
    kandidat.inErntezeit || eingabe.erntezeitModus == ErntezeitModus.alle;

int _gewicht(Kraeuterhaeufigkeit haeufigkeit) => 16 ~/ haeufigkeit.aufschlag;

KraeuterSucheErgebnis _beliebigeSuche(
  KraeuterSucheEingabe eingabe,
  KraeuterKatalog katalog,
  int tap,
  DiceRoller roller,
  _ErgebnisBauer ergebnis,
) {
  final kandidaten = _kandidatenDerSuche(eingabe, katalog);
  final mengen = <String, int>{};
  final reihenfolge = <KraeuterKandidat>[];
  var rest = tap;
  while (true) {
    final passend = kandidaten
        .where((k) => 2 * _mindestens1(k.suchschwierigkeit) <= rest)
        .toList();
    if (passend.isEmpty) break;
    final gesamt = passend.fold<int>(
      0,
      (summe, k) => summe + _gewicht(k.vorkommen.haeufigkeit),
    );
    var wurf = roller.rollDie(gesamt) - 1;
    var gewaehlt = passend.last;
    for (final kandidat in passend) {
      final gewicht = _gewicht(kandidat.vorkommen.haeufigkeit);
      if (wurf < gewicht) {
        gewaehlt = kandidat;
        break;
      }
      wurf -= gewicht;
    }
    rest -= _mindestens1(gewaehlt.suchschwierigkeit);
    if (!mengen.containsKey(gewaehlt.kraut.name)) {
      reihenfolge.add(gewaehlt);
    }
    mengen[gewaehlt.kraut.name] = (mengen[gewaehlt.kraut.name] ?? 0) + 1;
  }
  return ergebnis(
    funde: <KraeuterFund>[
      for (final kandidat in reihenfolge)
        KraeuterFund(
          bezeichnung: kandidat.kraut.name,
          kraut: kandidat.kraut,
          grundmengen: mengen[kandidat.kraut.name]!,
          suchschwierigkeit: kandidat.suchschwierigkeit,
        ),
    ],
    restpunkte: rest,
  );
}

int _mindestens1(int wert) => wert < 1 ? 1 : wert;

/// Verteilung der TaP* einer Kräutersuche über alle 8000 Wurfkombinationen.
///
/// Schlüssel 0 steht für Misserfolg, alle anderen Schlüssel für die TaP* einer
/// gelungenen Probe. Die Werte sind Wahrscheinlichkeiten und summieren sich zu
/// 1.
Map<int, double> kraeuterTapVerteilung(KraeuterSucheEingabe eingabe) {
  final request = baueKraeutersucheProbe(eingabe);
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
        final tap = kraeuterTapStern(probe);
        haeufigkeit[tap] = (haeufigkeit[tap] ?? 0) + 1;
      }
    }
  }
  final schluessel = haeufigkeit.keys.toList()..sort();
  return <int, double>{
    for (final tap in schluessel) tap: haeufigkeit[tap]! / 8000,
  };
}

/// Eine Zeile der Vorschau einer Kräutersuche.
class KraeuterVorschauZeile {
  /// Erstellt eine Zeile.
  const KraeuterVorschauZeile({
    required this.kandidat,
    required this.benoetigteTapFuerFund,
    required this.wahrscheinlichkeitFund,
    required this.erwarteteGrundmengenGezielt,
  });

  /// Kraut, Vorkommen und Suchschwierigkeit.
  final KraeuterKandidat kandidat;

  /// TaP*, die die beliebige Suche mindestens braucht, um dieses Kraut zu
  /// finden (doppelte Suchschwierigkeit).
  final int benoetigteTapFuerFund;

  /// Wahrscheinlichkeit, bei der beliebigen Suche mindestens diese TaP* zu
  /// erreichen.
  final double wahrscheinlichkeitFund;

  /// Erwartete Grundmengen bei gezielter Suche nach diesem Kraut
  /// (Misserfolg zählt 0).
  final double erwarteteGrundmengenGezielt;
}

/// Vorschau ohne Würfeln: für jedes mögliche Kraut die nötigen TaP*, die
/// Fundwahrscheinlichkeit und die erwarteten Grundmengen bei gezielter Suche.
List<KraeuterVorschauZeile> kraeuterVorschau(
  KraeuterSucheEingabe eingabe,
  KraeuterKatalog katalog,
) {
  final verteilung = kraeuterTapVerteilung(eingabe);
  return <KraeuterVorschauZeile>[
    for (final kandidat in moeglicheKraeuter(
      katalog,
      eingabe.landschaft,
      ausgeschlossen: eingabe.ausgeschlosseneKraeuter,
      monat: eingabe.monat,
    ))
      _vorschauZeile(
        kandidat,
        verteilung,
        findbar: _findbar(kandidat, eingabe),
      ),
  ];
}

KraeuterVorschauZeile _vorschauZeile(
  KraeuterKandidat kandidat,
  Map<int, double> verteilung, {
  required bool findbar,
}) {
  final noetig = 2 * _mindestens1(kandidat.suchschwierigkeit);
  var wahrscheinlichkeit = 0.0;
  var erwartet = 0.0;
  // Kräuter außerhalb der Erntezeit sind nicht zu finden: Chance 0.
  if (findbar) {
    verteilung.forEach((tap, p) {
      if (tap >= noetig) wahrscheinlichkeit += p;
      if (tap > 0) {
        erwartet += p * kraeuterGrundmengen(tap, kandidat.suchschwierigkeit);
      }
    });
  }
  return KraeuterVorschauZeile(
    kandidat: kandidat,
    benoetigteTapFuerFund: noetig,
    wahrscheinlichkeitFund: wahrscheinlichkeit,
    erwarteteGrundmengenGezielt: erwartet,
  );
}

/// Landschaften, die zu einem Ort des Ortsverzeichnisses passen.
///
/// Gelesen wird die `unterart` von Regionen (Wald, Sumpf, Steppe, Gebirge …).
/// Mehrdeutige Arten liefern mehrere Kandidaten (Wald: dichter oder lichter
/// Wald; Sumpf: nördlich oder südlich), die der Aufrufer wählen lässt.
/// Siedlungen, Gewässer und unbekannte Arten ergeben eine leere Liste; die
/// Landschaft bleibt dann eine freie Wahl.
List<Kraeuterlandschaft> kraeuterLandschaftenFuerOrt(OrtEintrag ort) {
  if (ort.art != OrtArt.region) return const <Kraeuterlandschaft>[];
  final art = ort.unterart
      .replaceAll(RegExp(r'\s*\(.*\)\s*'), '')
      .trim()
      .toLowerCase();
  return switch (art) {
    'wald' || 'hain' => const <Kraeuterlandschaft>[
      Kraeuterlandschaft.dichterWald,
      Kraeuterlandschaft.lichterWald,
    ],
    'regenwald' => const <Kraeuterlandschaft>[Kraeuterlandschaft.dschungel],
    'sumpf' || 'moor' || 'marschland' => const <Kraeuterlandschaft>[
      Kraeuterlandschaft.suempfeNord,
      Kraeuterlandschaft.suempfeSued,
    ],
    'steppe' || 'savanne' => const <Kraeuterlandschaft>[
      Kraeuterlandschaft.savanneSteppe,
      Kraeuterlandschaft.graslandHeide,
    ],
    'ebene' ||
    'graslandschaft' ||
    'heideland' ||
    'heide' ||
    'wiese' ||
    'auenlandschaft' ||
    'hügelland' ||
    'hügel' ||
    'flusstal' => const <Kraeuterlandschaft>[Kraeuterlandschaft.graslandHeide],
    'gebirge' ||
    'berg' ||
    'berge' ||
    'berggruppe' ||
    'bergkamm' ||
    'hochland' ||
    'tal' ||
    'schlucht' ||
    'klamm' => const <Kraeuterlandschaft>[Kraeuterlandschaft.gebirge],
    'vulkan' || 'hochebene' => const <Kraeuterlandschaft>[
      Kraeuterlandschaft.gebirge,
      Kraeuterlandschaft.hochgebirge,
    ],
    'gletscher' => const <Kraeuterlandschaft>[Kraeuterlandschaft.hochgebirge],
    'wüste' => const <Kraeuterlandschaft>[Kraeuterlandschaft.wueste],
    _ => const <Kraeuterlandschaft>[],
  };
}
