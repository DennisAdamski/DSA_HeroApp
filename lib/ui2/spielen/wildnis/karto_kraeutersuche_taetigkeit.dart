import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kraeutersuche_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/kraeuter_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';

/// Kräuter suchen (Wege des Entdeckers S. 113 f.) als Wildnistätigkeit.
///
/// Die Rechnung steckt in `kraeutersuche_rules.dart`; diese Klasse übersetzt
/// nur zwischen dem allgemeinen [KartoWildnisKontext] und der
/// [KraeuterSucheEingabe].
class KartoKraeutersucheTaetigkeit extends KartoWildnisTaetigkeit {
  /// Die Tätigkeit ist zustandslos.
  const KartoKraeutersucheTaetigkeit();

  @override
  String get id => 'kraeutersuche';

  @override
  String get titel => 'Kräuter suchen';

  @override
  IconData get symbol => Icons.eco_outlined;

  @override
  String get regelHinweis => 'Wege des Entdeckers S. 113 f.';

  @override
  List<String> get talentKomponenten => const <String>[
    'tal_sinnesschaerfe',
    'tal_wildnisleben',
    'tal_pflanzenkunde',
  ];

  /// KL/IN/FF laut Wege des Entdeckers S. 113. Das Meta-Talent
  /// „Kräutersuchen“ im Standardbogen trägt MU/IN/FF (wie Nahrung sammeln)
  /// und wird hier bewusst nicht genutzt.
  @override
  List<AttributeCode> get eigenschaften => const <AttributeCode>[
    AttributeCode.kl,
    AttributeCode.inn,
    AttributeCode.ff,
  ];

  @override
  List<WildnisLandschaft> get landschaften => <WildnisLandschaft>[
    for (final landschaft in Kraeuterlandschaft.values)
      kraeuterLandschaftAlsWildnis(landschaft),
  ];

  @override
  List<KartoWildnisDauer> get dauern => const <KartoWildnisDauer>[
    (stunden: kKraeuterSucheNormaleStunden, text: '1 Stunde'),
    (stunden: kKraeuterSucheAusfuehrlicheStunden, text: '2 Stunden'),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    const KartoWildnisOption(
      schluessel: _ziel,
      bezeichnung: 'Suchziel',
      standard: _zielBeliebig,
      werte: <({String schluessel, String text})>[
        (schluessel: _zielBeliebig, text: 'Beliebige Kräuter'),
        (schluessel: _zielGezielt, text: 'Bestimmtes Kraut oder Heilwirkung'),
        (schluessel: _zielWuerz, text: 'Würzkräuter'),
        (schluessel: _zielKonservierung, text: 'Konservierungsmittel'),
      ],
    ),
    KartoWildnisOption(
      schluessel: _kraut,
      bezeichnung: 'Gesuchtes Kraut',
      standard: '',
      werte: const <({String schluessel, String text})>[
        (schluessel: '', text: 'Heilwirkung ohne bestimmte Pflanze'),
      ],
      sichtbar: (optionen) => optionen[_ziel] == _zielGezielt,
      dynamischeWerte: _krautWerte,
    ),
    const KartoWildnisOption(
      schluessel: _ernte,
      bezeichnung: 'Erntezeit',
      standard: _ernteNur,
      werte: <({String schluessel, String text})>[
        (schluessel: _ernteNur, text: 'Nur Kräuter der Erntezeit'),
        (schluessel: _ernteAlle, text: 'Alle Kräuter der Landschaft'),
      ],
    ),
  ];

  @override
  List<WildnisLandschaft> landschaftenFuerOrt(OrtEintrag ort) =>
      <WildnisLandschaft>[
        for (final landschaft in kraeuterLandschaftenFuerOrt(ort))
          kraeuterLandschaftAlsWildnis(landschaft),
      ];

  @override
  AsyncValue<Object?> beobachteDaten(WidgetRef ref) =>
      ref.watch(kraeuterKatalogProvider);

  @override
  int erschwernis(KartoWildnisKontext kontext) =>
      kraeuterProbenErschwernis(_eingabe(kontext));

  @override
  String? erschwernisHinweis(KartoWildnisKontext kontext) {
    final ziel = _suchziel(kontext);
    if (ziel == null) return null;
    final kandidat = ziel.kandidat;
    if (kandidat == null) {
      return 'darin ${ziel.bezeichnung}: Suchschwierigkeit '
          '${_mitVorzeichen(ziel.suchschwierigkeit)}';
    }
    final haeufigkeit = kandidat.vorkommen.haeufigkeit;
    return 'darin ${ziel.bezeichnung}: Suchschwierigkeit '
        '${_mitVorzeichen(ziel.suchschwierigkeit)} (Bestimmung '
        '${_mitVorzeichen(kandidat.kraut.bestimmung)}, ${haeufigkeit.bezeichnung} '
        '${_mitVorzeichen(haeufigkeit.aufschlag)})';
  }

  @override
  WildnisErgebnisZeile? zielAngaben(KartoWildnisKontext kontext) {
    final kandidat = _suchziel(kontext)?.kandidat;
    if (kandidat == null) return null;
    return WildnisErgebnisZeile(
      titel: kandidat.kraut.name,
      detail: kandidat.kraut.wirkung,
      erlaeuterung: _erlaeuterung(kandidat),
      quelle: kandidat.kraut.quelle,
    );
  }

  @override
  int tawBeiDauer(KartoWildnisKontext kontext) =>
      kraeuterSuchenTawBeiDauer(kontext.taw, kontext.dauerStunden);

  @override
  ResolvedProbeRequest baueProbe(KartoWildnisKontext kontext) =>
      baueKraeutersucheProbe(_eingabe(kontext));

  @override
  WildnisErgebnis auswerten(
    KartoWildnisKontext kontext,
    ProbeResult probe, {
    required DiceRoller roller,
  }) {
    final katalog = kontext.daten;
    if (katalog is! KraeuterKatalog) {
      throw StateError('Der Kräuterkatalog ist nicht geladen.');
    }
    return kraeuterErgebnisAlsWildnis(
      werteKraeutersucheAus(_eingabe(kontext), katalog, probe, roller: roller),
    );
  }

  @override
  List<WildnisErgebnisZeile> vorschau(KartoWildnisKontext kontext) {
    final katalog = kontext.daten;
    if (katalog is! KraeuterKatalog) return const <WildnisErgebnisZeile>[];
    final eingabe = _eingabe(kontext);
    return <WildnisErgebnisZeile>[
      for (final kandidat in moeglicheKraeuter(
        katalog,
        eingabe.landschaft,
        monat: eingabe.monat,
      ))
        if (kandidat.inErntezeit ||
            eingabe.erntezeitModus == ErntezeitModus.alle)
          WildnisErgebnisZeile(
            titel: kandidat.kraut.name,
            detail:
                '${kandidat.vorkommen.haeufigkeit.bezeichnung} · '
                'Suchschwierigkeit ${kandidat.suchschwierigkeit} · '
                'ab ${2 * (kandidat.suchschwierigkeit < 1 ? 1 : kandidat.suchschwierigkeit)} TaP*'
                '${kandidat.inErntezeit ? '' : ' · außerhalb der Erntezeit'}',
            erlaeuterung: _erlaeuterung(kandidat),
            quelle: kandidat.kraut.quelle,
          ),
    ];
  }

  // Das Suchziel der gezielten Suche, sofern der Katalog geladen ist.
  KraeuterZiel? _suchziel(KartoWildnisKontext kontext) {
    final katalog = kontext.daten;
    if (katalog is! KraeuterKatalog) return null;
    return kraeuterSuchziel(_eingabe(kontext), katalog);
  }

  // Angaben zum Aufklappen: Kurzfakten, Beschreibung, Hinweis auf Sperre.
  static List<String> _erlaeuterung(KraeuterKandidat kandidat) {
    final kraut = kandidat.kraut;
    final vorkommen = kandidat.vorkommen;
    return <String>[
      if (kraut.wirkung.isNotEmpty) 'Wirkung: ${kraut.wirkung}',
      if (kraut.beschreibung.isNotEmpty)
        kraut.beschreibung
      else if (kraut.beschreibungGesperrt)
        'Beschreibung gesperrt: Katalogpasswort erforderlich.',
      'Bestimmung ${_mitVorzeichen(kraut.bestimmung)} · '
          '${vorkommen.haeufigkeit.bezeichnung} '
          '${_mitVorzeichen(vorkommen.haeufigkeit.aufschlag)}'
          '${kraut.bestimmungHinweis.isEmpty ? '' : ' (${kraut.bestimmungHinweis})'}',
      if (vorkommen.hinweis.isNotEmpty) 'Vorkommen: ${vorkommen.hinweis}',
      if (kraut.gebiet.isNotEmpty) 'Gebiet: ${kraut.gebiet}',
      if (kraut.erntezeit.isNotEmpty) 'Erntezeit: ${kraut.erntezeit}',
      if (kraut.grundmenge.isNotEmpty) 'Grundmenge: ${kraut.grundmenge}',
    ];
  }

  static String _mitVorzeichen(int wert) =>
      wert > 0 ? '+$wert' : (wert < 0 ? '−${-wert}' : '±0');

  // Übersetzt den allgemeinen Kontext in die Eingabe der Kräutersuche.
  //
  // Mit geladenem Katalog trägt die Eingabe die Suchschwierigkeit des
  // Suchziels, damit Erschwernis, Probe und Auswertung übereinstimmen.
  KraeuterSucheEingabe _eingabe(KartoWildnisKontext kontext) {
    final eingabe = _grundeingabe(kontext);
    final katalog = kontext.daten;
    return katalog is KraeuterKatalog
        ? kraeuterEingabeMitZiel(eingabe, katalog)
        : eingabe;
  }

  KraeuterSucheEingabe _grundeingabe(KartoWildnisKontext kontext) {
    final landschaft = Kraeuterlandschaft.ausSchluessel(
      kontext.landschaft.schluessel,
    );
    if (landschaft == null) {
      throw StateError(
        'Unbekannte Landschaft ${kontext.landschaft.schluessel}.',
      );
    }
    return KraeuterSucheEingabe(
      landschaft: landschaft,
      jahreszeit: kontext.jahreszeit,
      taw: kontext.taw,
      eigenschaften: kontext.eigenschaften,
      dauerStunden: kontext.dauerStunden,
      gelaendekunde: kontext.gelaendekunde,
      ortskenntnis: kontext.ortskenntnis,
      eingesetzteAsp: kontext.eingesetzteAsp,
      situativeErschwernis: kontext.situativeErschwernis,
      modus: switch (kontext.optionen[_ziel]) {
        _zielGezielt => KraeuterSuchmodus.gezielt,
        _zielWuerz => KraeuterSuchmodus.wuerz,
        _zielKonservierung => KraeuterSuchmodus.konservierung,
        _ => KraeuterSuchmodus.beliebig,
      },
      zielKraut: kontext.optionen[_kraut] ?? '',
      monat: kontext.monat,
      erntezeitModus: kontext.optionen[_ernte] == _ernteAlle
          ? ErntezeitModus.alle
          : ErntezeitModus.nurErntezeit,
    );
  }

  // Die Kräuter der gewählten Landschaft, jedes einmal, nach Häufigkeit.
  static List<({String schluessel, String text})> _krautWerte(
    KartoWildnisKontext kontext,
  ) {
    final katalog = kontext.daten;
    final landschaft = Kraeuterlandschaft.ausSchluessel(
      kontext.landschaft.schluessel,
    );
    final werte = <({String schluessel, String text})>[
      (schluessel: '', text: 'Heilwirkung ohne bestimmte Pflanze'),
    ];
    if (katalog is! KraeuterKatalog || landschaft == null) return werte;
    final gesehen = <String>{};
    final kandidaten = moeglicheKraeuter(
      katalog,
      landschaft,
      monat: kontext.monat,
    );
    for (final kandidat in kandidaten) {
      final name = kandidat.kraut.name;
      if (gesehen.add(name)) {
        // Mehrere Vorkommen: die Suche nimmt das leichteste.
        final suchschwierigkeit = kandidaten
            .where((k) => k.kraut.name == name)
            .map((k) => k.suchschwierigkeit)
            .reduce((a, b) => a < b ? a : b);
        werte.add((
          schluessel: name,
          text: '$name (Suchschwierigkeit $suchschwierigkeit)',
        ));
      }
    }
    return werte;
  }

  static const String _ziel = 'ziel';
  static const String _zielBeliebig = 'beliebig';
  static const String _zielGezielt = 'gezielt';
  static const String _zielWuerz = 'wuerz';
  static const String _zielKonservierung = 'konservierung';
  static const String _kraut = 'kraut';
  static const String _ernte = 'ernte';
  static const String _ernteNur = 'nur';
  static const String _ernteAlle = 'alle';
}
