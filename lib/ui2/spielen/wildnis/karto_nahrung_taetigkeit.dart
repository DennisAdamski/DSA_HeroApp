import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/nahrung_sammeln_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_ausbeute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_rationen_taetigkeit.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';

/// Nahrung sammeln (Wege des Entdeckers S. 112 f.) als Wildnistätigkeit:
/// Obst, Beeren, Nüsse, Pilze und Wurzeln.
///
/// Die Rechnung steckt in `nahrung_sammeln_rules.dart`; diese Klasse
/// übersetzt nur zwischen [KartoWildnisKontext] und
/// [NahrungSammelnEingabe].
class KartoNahrungSammelnTaetigkeit extends KartoRationenTaetigkeit {
  /// Die Tätigkeit ist zustandslos.
  const KartoNahrungSammelnTaetigkeit();

  @override
  String get id => 'nahrung';

  @override
  String get titel => 'Nahrung sammeln';

  @override
  IconData get symbol => Icons.shopping_basket_outlined;

  @override
  String get regelHinweis => 'Wege des Entdeckers S. 112 f.';

  @override
  List<String> get talentKomponenten => kNahrungSammelnTalente;

  @override
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      computeMetaTalentBaseTaw(
        talentEntries: held.talents,
        componentTalentIds: nahrungSammelnTalente(
          ackerbau: optionen[_talent] == _ackerbau,
        ),
      );

  @override
  List<AttributeCode> get eigenschaften => const <AttributeCode>[
    AttributeCode.mu,
    AttributeCode.inn,
    AttributeCode.ff,
  ];

  /// Eine Stunde, dann in Viertelstunden bis zwei Stunden, danach gröber.
  @override
  List<KartoWildnisDauer> get dauern => <KartoWildnisDauer>[
    for (final minuten in const <int>[60, 75, 90, 105, 120, 150, 180, 240])
      (minuten: minuten, text: _dauerText(minuten)),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    KartoWildnisOption(
      schluessel: _haltbarkeit,
      bezeichnung: 'Haltbarkeit anstreben (je Stufe 1 TaP*)',
      standard: '1',
      werte: <({String schluessel, String text})>[
        for (final stufe in Haltbarkeitsstufe.values)
          (
            schluessel: '${stufe.stufe}',
            text: switch (stufe) {
              Haltbarkeitsstufe.eins => 'Stufe 1: Beeren, Pilze',
              Haltbarkeitsstufe.zwei => 'Stufe 2: Obst, weiches Gemüse',
              Haltbarkeitsstufe.drei => 'Stufe 3: Gemüse, Wurzeln',
              Haltbarkeitsstufe.vier => 'Stufe 4: Nüsse, Trockenobst',
            },
          ),
      ],
    ),
    const KartoWildnisOption(
      schluessel: _talent,
      bezeichnung: 'Gelände',
      standard: 'wild',
      werte: <({String schluessel, String text})>[
        (schluessel: 'wild', text: 'Wildnis (Pflanzenkunde)'),
        (
          schluessel: _ackerbau,
          text: 'Felder und Gärten (Ackerbau statt Pflanzenkunde)',
        ),
      ],
    ),
  ];

  @override
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext) =>
      nahrungSammelnProbeEingabe(_eingabe(kontext));

  @override
  List<({String text, int wert})> erschwernisTeile(
    KartoWildnisKontext kontext,
  ) => <({String text, int wert})>[
    (text: 'Region', wert: nahrungSammelnRegionsErschwernis(region(kontext))),
    if (kontext.dauerMinuten > kNahrungSammelnGrundMinuten)
      (
        text: 'längere Suche',
        wert: nahrungSammelnDauerErschwernis(kontext.dauerMinuten),
      ),
  ];

  @override
  String erschwernisZusatz(KartoWildnisKontext kontext) =>
      'Jahreszeit nach Meisterentscheid';

  @override
  int ausbeuteFuerTap(KartoWildnisKontext kontext, int tapStern) =>
      nahrungSammelnAusbeute(tapStern, ziel: _ziel(kontext)).rationen;

  @override
  WildnisErgebnis auswerten(
    KartoWildnisKontext kontext,
    ProbeResult probe, {
    required DiceRoller roller,
  }) => werteNahrungSammelnAus(_eingabe(kontext), probe);

  @override
  bool get erlaubtHandFund => true;

  @override
  WildnisPosten? handFund({
    required KartoWildnisKontext? kontext,
    required Object? daten,
    required String? wahl,
    required int menge,
  }) {
    if (kontext == null || menge <= 0) return null;
    return nahrungSammelnPosten(
      region: region(kontext),
      rationen: menge,
      haltbarkeit: _ziel(kontext),
      gelaendekunde: kontext.gelaendekunde,
    );
  }

  Haltbarkeitsstufe _ziel(KartoWildnisKontext kontext) =>
      Haltbarkeitsstufe.ausStufe(
        int.tryParse(kontext.optionen[_haltbarkeit] ?? '') ?? 1,
      );

  NahrungSammelnEingabe _eingabe(KartoWildnisKontext kontext) =>
      NahrungSammelnEingabe(
        region: region(kontext),
        taw: kontext.taw,
        eigenschaften: kontext.eigenschaften,
        dauerMinuten: kontext.dauerMinuten,
        gelaendekunde: kontext.gelaendekunde,
        ortskenntnis: kontext.ortskenntnis,
        eingesetzteAsp: kontext.eingesetzteAsp,
        situativeErschwernis: kontext.situativeErschwernis,
        haltbarkeitsziel: _ziel(kontext),
      );

  static String _dauerText(int minuten) {
    final stunden = minuten ~/ 60;
    final rest = minuten % 60;
    final bruch = switch (rest) {
      15 => '¼',
      30 => '½',
      45 => '¾',
      _ => '',
    };
    final zeit = stunden == 1 && bruch.isEmpty
        ? '1 Stunde'
        : '$stunden$bruch Stunden';
    final mod = nahrungSammelnDauerErschwernis(minuten);
    return mod == 0 ? zeit : '$zeit (${mitVorzeichen(mod)})';
  }

  static const String _haltbarkeit = 'haltbarkeit';
  static const String _talent = 'talent';
  static const String _ackerbau = 'ackerbau';
}
