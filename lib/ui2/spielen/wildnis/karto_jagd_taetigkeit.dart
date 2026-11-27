import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_rationen_taetigkeit.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';

/// Pirsch- oder Ansitzjagd (Wege des Entdeckers S. 107 f.) als
/// Wildnistätigkeit.
///
/// Die Waffe kommt bevorzugt aus den Fernkampfwaffen des Helden; jede Waffe
/// der Tabelle ist ebenfalls wählbar. Scharf- und Meisterschütze erkennt die
/// Tätigkeit am erlernten Manöver für das Waffentalent. Gerechnet wird in
/// `jagd_rules.dart`.
class KartoJagdTaetigkeit extends KartoRationenTaetigkeit {
  /// Tätigkeit für [art].
  const KartoJagdTaetigkeit(this.art);

  /// Pirsch oder Ansitz.
  final Jagdart art;

  @override
  String get id => switch (art) {
    Jagdart.pirsch => 'pirschjagd',
    Jagdart.ansitz => 'ansitzjagd',
  };

  @override
  String get titel => art.titel;

  @override
  IconData get symbol => switch (art) {
    Jagdart.pirsch => Icons.pets_outlined,
    Jagdart.ansitz => Icons.visibility_outlined,
  };

  @override
  String get regelHinweis => art.quelle;

  /// Ohne Waffentalent; [grundTaw] ergänzt das Talent der gewählten Waffe.
  @override
  List<String> get talentKomponenten => jagdGrundtalente(art);

  @override
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      computeMetaTalentBaseTaw(
        talentEntries: held.talents,
        componentTalentIds: jagdTalente(
          art,
          waffe(held, optionen[_waffe]).talentId,
        ),
      );

  @override
  List<AttributeCode> get eigenschaften => const <AttributeCode>[
    AttributeCode.mu,
    AttributeCode.inn,
    AttributeCode.ge,
  ];

  @override
  List<KartoWildnisDauer> get dauern => <KartoWildnisDauer>[
    (
      minuten: art.dauerMinuten,
      text: art.dauerMinuten == 60 ? '1 Stunde' : '1½ Stunden',
    ),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    KartoWildnisOption(
      schluessel: _waffe,
      bezeichnung: 'Waffe',
      standard: '',
      werte: <({String schluessel, String text})>[
        for (final w in kJagdWaffenTabelle) _waffenEintrag(w),
      ],
      dynamischeWerte: (kontext) => <({String schluessel, String text})>[
        for (final w in jagdWaffenDesHelden(kontext.held)) _waffenEintrag(w),
        for (final w in kJagdWaffenTabelle) _waffenEintrag(w),
      ],
      dynamischerStandard: (kontext) => waffe(kontext.held, null).schluessel,
    ),
    KartoWildnisOption(
      schluessel: _schuetze,
      bezeichnung: 'Scharf- und Meisterschütze',
      standard: _auto,
      werte: _schuetzenWerte('wie am Helden'),
      dynamischeWerte: (kontext) =>
          _schuetzenWerte(_erkannteStufe(kontext).bezeichnung),
    ),
    KartoWildnisOption(
      schluessel: _wetter,
      bezeichnung: 'Wetter',
      standard: Jagdwetter.ruhig.name,
      werte: <({String schluessel, String text})>[
        for (final w in Jagdwetter.values)
          (
            schluessel: w.name,
            text: '${w.bezeichnung} (${mitVorzeichen(w.erschwernis)})',
          ),
      ],
    ),
    beuteOption(kJagdSchmackhaftErschwernis),
    KartoWildnisOption(
      schluessel: _segen,
      bezeichnung: 'Göttlicher Beistand',
      standard: 'kein',
      werte: <({String schluessel, String text})>[
        (schluessel: 'kein', text: 'Kein'),
        (
          schluessel: _jagdglueck,
          text: 'Jagdglück (Firun, ${mitVorzeichen(kJagdglueckErschwernis)})',
        ),
      ],
    ),
  ];

  /// Die gewählte Waffe; ohne gültige Wahl die erste Waffe des Helden, sonst
  /// der Kurzbogen der Tabelle.
  JagdWaffe waffe(HeroSheet held, String? schluessel) {
    final eigene = jagdWaffenDesHelden(held);
    for (final w in eigene) {
      if (w.schluessel == schluessel) return w;
    }
    if (schluessel != null) {
      final tabelle = jagdWaffeAusTabelle(schluessel);
      if (tabelle != null) return tabelle;
    }
    return eigene.isNotEmpty
        ? eigene.first
        : jagdWaffeAusTabelle('tabelle:kurzbogen')!;
  }

  Schuetzenstufe _erkannteStufe(KartoWildnisKontext kontext) =>
      schuetzenstufeDesHelden(
        kontext.held,
        talentId: waffe(kontext.held, kontext.optionen[_waffe]).talentId,
        catalog: kontext.katalog,
      );

  Schuetzenstufe _stufe(KartoWildnisKontext kontext) =>
      switch (kontext.optionen[_schuetze]) {
        'keine' => Schuetzenstufe.keine,
        'scharf' => Schuetzenstufe.scharfschuetze,
        'meister' => Schuetzenstufe.meisterschuetze,
        _ => _erkannteStufe(kontext),
      };

  JagdEingabe _eingabe(KartoWildnisKontext kontext) => JagdEingabe(
    art: art,
    region: region(kontext),
    taw: kontext.taw,
    eigenschaften: kontext.eigenschaften,
    waffe: waffe(kontext.held, kontext.optionen[_waffe]),
    wetter:
        Jagdwetter.values.asNameMap()[kontext.optionen[_wetter]] ??
        Jagdwetter.ruhig,
    nurSchmackhaft: nurSchmackhaft(kontext),
    schuetze: _stufe(kontext),
    gelaendekunde: kontext.gelaendekunde,
    ortskenntnis: kontext.ortskenntnis,
    eingesetzteAsp: kontext.eingesetzteAsp,
    jagdglueck: kontext.optionen[_segen] == _jagdglueck,
    situativeErschwernis: kontext.situativeErschwernis,
  );

  @override
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext) =>
      jagdProbeEingabe(_eingabe(kontext));

  @override
  List<({String text, int wert})> erschwernisTeile(
    KartoWildnisKontext kontext,
  ) {
    final eingabe = _eingabe(kontext);
    final aufstellung = berechneJagdErschwernis(eingabe);
    return <({String text, int wert})>[
      (text: eingabe.waffe.name, wert: eingabe.waffe.modifikator),
      (text: 'Region', wert: jagdRegionsErschwernis(eingabe.region)),
      if (eingabe.wetter != Jagdwetter.ruhig)
        (text: eingabe.wetter.bezeichnung, wert: eingabe.wetter.erschwernis),
      if (eingabe.nurSchmackhaft)
        (text: 'schmackhaft', wert: kJagdSchmackhaftErschwernis),
      if (eingabe.schuetze != Schuetzenstufe.keine)
        (text: eingabe.schuetze.bezeichnung, wert: aufstellung.schuetze),
      if (eingabe.jagdglueck) (text: 'Jagdglück', wert: kJagdglueckErschwernis),
    ];
  }

  @override
  String erschwernisZusatz(KartoWildnisKontext kontext) {
    final aufstellung = berechneJagdErschwernis(_eingabe(kontext));
    if (aufstellung.schuetzeVerfallen <= 0) return '';
    return '${aufstellung.schuetzeVerfallen} Punkte der Schützen-SF '
        'verfallen (sie gleichen nur Zuschläge außer der Waffe aus)';
  }

  @override
  String? get inventarGegenstand => kWildbretGegenstand;

  @override
  String inventarBeschreibung(KartoWildnisKontext kontext) =>
      frischfleischBeschreibung(region(kontext));

  @override
  WildnisErgebnis auswerten(
    KartoWildnisKontext kontext,
    ProbeResult probe, {
    required DiceRoller roller,
  }) => werteJagdAus(_eingabe(kontext), probe);

  static ({String schluessel, String text}) _waffenEintrag(JagdWaffe w) => (
    schluessel: w.schluessel,
    text: w.schluessel.startsWith('held:')
        ? '${w.name} (eigene, ${mitVorzeichen(w.modifikator)}, ${w.herkunft})'
        : '${w.name} (${mitVorzeichen(w.modifikator)})',
  );

  static List<({String schluessel, String text})> _schuetzenWerte(
    String erkannt,
  ) => <({String schluessel, String text})>[
    (schluessel: _auto, text: 'Wie am Helden: $erkannt'),
    (schluessel: 'keine', text: 'Keine'),
    (
      schluessel: 'scharf',
      text:
          'Scharfschütze '
          '(${mitVorzeichen(Schuetzenstufe.scharfschuetze.jagdErleichterung)})',
    ),
    (
      schluessel: 'meister',
      text:
          'Scharf- und Meisterschütze '
          '(${mitVorzeichen(Schuetzenstufe.meisterschuetze.jagdErleichterung)})',
    ),
  ];

  static const String _waffe = 'waffe';
  static const String _schuetze = 'schuetze';
  static const String _auto = 'auto';
  static const String _wetter = 'wetter';
  static const String _segen = 'segen';
  static const String _jagdglueck = 'jagdglueck';
}
