import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hetzjagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_rationen_taetigkeit.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';

/// Hetzjagd vom Pferde aus (Wege des Entdeckers S. 109 f.) als
/// Wildnistätigkeit.
///
/// Wie bei der Pirschjagd kommt die Waffe bevorzugt vom Helden, jede Waffe der
/// Hetz-Tabelle ist ebenfalls wählbar; Scharf-/Meisterschütze und
/// Schnellladen erkennt die Tätigkeit am erlernten Manöver. Die Probe ist
/// nicht wiederholbar; die Kachel sagt es nach dem Wurf. Gerechnet wird in
/// `hetzjagd_rules.dart`.
class KartoHetzjagdTaetigkeit extends KartoRationenTaetigkeit {
  /// Die Tätigkeit ist zustandslos.
  const KartoHetzjagdTaetigkeit();

  @override
  String get id => 'hetzjagd';

  @override
  String get titel => kHetzjagdTitel;

  @override
  IconData get symbol => Icons.speed_outlined;

  @override
  String get regelHinweis => kHetzjagdQuelle;

  /// Ohne Waffentalent; [grundTaw] ergänzt das Talent der gewählten Waffe.
  @override
  List<String> get talentKomponenten => kHetzjagdGrundtalente;

  @override
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      computeMetaTalentBaseTaw(
        talentEntries: held.talents,
        componentTalentIds: hetzjagdTalente(
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
  List<KartoWildnisDauer> get dauern => const <KartoWildnisDauer>[
    (minuten: kHetzjagdDauerMinuten, text: '1 Stunde'),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    KartoWildnisOption(
      schluessel: _waffe,
      bezeichnung: 'Waffe',
      standard: '',
      werte: <({String schluessel, String text})>[
        for (final w in kHetzjagdWaffenTabelle) _waffenEintrag(w),
      ],
      dynamischeWerte: (kontext) => <({String schluessel, String text})>[
        for (final w in hetzjagdWaffenDesHelden(kontext.held))
          _waffenEintrag(w),
        for (final w in kHetzjagdWaffenTabelle) _waffenEintrag(w),
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
      schluessel: _schnellladen,
      bezeichnung: 'Schnellladen',
      standard: _auto,
      werte: _janein('wie am Helden'),
      dynamischeWerte: (kontext) =>
          _janein(_erkanntesSchnellladen(kontext) ? 'ja' : 'nein'),
    ),
    KartoWildnisOption(
      schluessel: _reiter,
      bezeichnung: 'Reiter-Sonderfertigkeiten',
      standard: Reitersonderfertigkeit.keine.name,
      werte: <({String schluessel, String text})>[
        for (final r in Reitersonderfertigkeit.values)
          (
            schluessel: r.name,
            text: r == Reitersonderfertigkeit.keine
                ? r.bezeichnung
                : '${r.bezeichnung} (${mitVorzeichen(r.erleichterung)})',
          ),
      ],
    ),
    KartoWildnisOption(
      schluessel: _zuPferd,
      bezeichnung:
          'Jagd zu Pferde (Reiten $kHetzjagdZuPferdReiten+, Grasland, '
          'Heide, Savanne, Steppe, Tundra)',
      standard: 'nein',
      werte: <({String schluessel, String text})>[
        (schluessel: 'nein', text: 'Nein'),
        (
          schluessel: 'ja',
          text: 'Ja (${mitVorzeichen(kHetzjagdZuPferdErschwernis)})',
        ),
      ],
    ),
    KartoWildnisOption(
      schluessel: _tier,
      bezeichnung: 'Jagdhund, Jagdfalke o. ä. (Meisterentscheid)',
      standard: '0',
      werte: <({String schluessel, String text})>[
        (schluessel: '0', text: 'Kein Jagdtier'),
        for (var n = kHetzjagdTierMin; n <= kHetzjagdTierMax; n++)
          (schluessel: '$n', text: 'Jagdtier (${mitVorzeichen(-n)})'),
      ],
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

  /// Die gewählte Waffe; ohne gültige Wahl die erste Waffe des Helden, die zur
  /// Hetzjagd taugt, sonst der Kurzbogen der Tabelle.
  JagdWaffe waffe(HeroSheet held, String? schluessel) {
    final eigene = hetzjagdWaffenDesHelden(held);
    for (final w in eigene) {
      if (w.schluessel == schluessel) return w;
    }
    if (schluessel != null) {
      final tabelle = hetzjagdWaffeAusTabelle(schluessel);
      if (tabelle != null) return tabelle;
    }
    return eigene.isNotEmpty
        ? eigene.first
        : hetzjagdWaffeAusTabelle('hetz:kurzbogen')!;
  }

  @override
  String? sperrgrund(KartoWildnisKontext kontext) =>
      hetzjagdVoraussetzung(kontext.held) ?? super.sperrgrund(kontext);

  @override
  String auswertungsHinweis(KartoWildnisKontext kontext) =>
      kHetzjagdNichtWiederholbar;

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

  bool _erkanntesSchnellladen(KartoWildnisKontext kontext) => hatSchnellladen(
    kontext.held,
    talentId: waffe(kontext.held, kontext.optionen[_waffe]).talentId,
    catalog: kontext.katalog,
  );

  bool _hatSchnellladen(KartoWildnisKontext kontext) =>
      switch (kontext.optionen[_schnellladen]) {
        'nein' => false,
        'ja' => true,
        _ => _erkanntesSchnellladen(kontext),
      };

  HetzjagdEingabe _eingabe(KartoWildnisKontext kontext) => HetzjagdEingabe(
    region: region(kontext),
    taw: kontext.taw,
    eigenschaften: kontext.eigenschaften,
    waffe: waffe(kontext.held, kontext.optionen[_waffe]),
    reitenTaw: kontext.held.talents['tal_reiten']?.talentValue ?? 0,
    wetter:
        Jagdwetter.values.asNameMap()[kontext.optionen[_wetter]] ??
        Jagdwetter.ruhig,
    nurSchmackhaft: nurSchmackhaft(kontext),
    schuetze: _stufe(kontext),
    schnellladen: _hatSchnellladen(kontext),
    gelaendekunde: kontext.gelaendekunde,
    ortskenntnis: kontext.ortskenntnis,
    eingesetzteAsp: kontext.eingesetzteAsp,
    jagdglueck: kontext.optionen[_segen] == _jagdglueck,
    jagdtier: int.tryParse(kontext.optionen[_tier] ?? '') ?? 0,
    zuPferd: kontext.optionen[_zuPferd] == 'ja',
    reiter:
        Reitersonderfertigkeit.values.asNameMap()[kontext.optionen[_reiter]] ??
        Reitersonderfertigkeit.keine,
    situativeErschwernis: kontext.situativeErschwernis,
  );

  @override
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext) =>
      hetzjagdProbeEingabe(_eingabe(kontext));

  @override
  List<({String text, int wert})> erschwernisTeile(
    KartoWildnisKontext kontext,
  ) {
    final eingabe = _eingabe(kontext);
    final aufstellung = berechneHetzjagdErschwernis(eingabe);
    return <({String text, int wert})>[
      (text: eingabe.waffe.name, wert: eingabe.waffe.modifikator),
      (text: 'Region', wert: hetzjagdRegionsErschwernis(eingabe.region)),
      if (eingabe.wetter != Jagdwetter.ruhig)
        (text: eingabe.wetter.bezeichnung, wert: eingabe.wetter.erschwernis),
      if (eingabe.nurSchmackhaft)
        (text: 'schmackhaft', wert: kJagdSchmackhaftErschwernis),
      if (eingabe.schuetze != Schuetzenstufe.keine || eingabe.schnellladen)
        (text: 'Schützen-SF', wert: aufstellung.schuetze),
      if (eingabe.jagdglueck) (text: 'Jagdglück', wert: kJagdglueckErschwernis),
      if (eingabe.jagdtierWirksam > 0)
        (text: 'Jagdtier', wert: -eingabe.jagdtierWirksam),
      if (eingabe.zuPferdWirksam)
        (text: 'zu Pferde', wert: kHetzjagdZuPferdErschwernis),
      if (eingabe.reiter != Reitersonderfertigkeit.keine)
        (text: 'Reiter-SF', wert: eingabe.reiter.erleichterung),
    ];
  }

  @override
  String erschwernisZusatz(KartoWildnisKontext kontext) {
    final eingabe = _eingabe(kontext);
    final aufstellung = berechneHetzjagdErschwernis(eingabe);
    return <String>[
      if (aufstellung.schuetzeVerfallen > 0)
        '${aufstellung.schuetzeVerfallen} Punkte der Schützen-SF verfallen '
            '(sie gleichen nur Zuschläge außer der Waffe aus)',
      if (eingabe.zuPferd && !eingabe.zuPferdWirksam)
        'Jagd zu Pferde zählt hier nicht (Reiten $kHetzjagdZuPferdReiten+ '
            'und Grasland, Heide, Savanne, Steppe oder Tundra)',
    ].join('; ');
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
  }) => werteHetzjagdAus(_eingabe(kontext), probe);

  static ({String schluessel, String text}) _waffenEintrag(JagdWaffe w) => (
    schluessel: w.schluessel,
    text: w.schluessel.startsWith('held:')
        ? '${w.name} (eigene, ${mitVorzeichen(w.modifikator)}, ${w.herkunft})'
        : '${w.name} (${mitVorzeichen(w.modifikator)})',
  );

  static List<({String schluessel, String text})> _janein(String erkannt) =>
      <({String schluessel, String text})>[
        (schluessel: _auto, text: 'Wie am Helden: $erkannt'),
        (
          schluessel: 'ja',
          text: 'Ja (${mitVorzeichen(kHetzjagdSchnellladenErschwernis)})',
        ),
        (schluessel: 'nein', text: 'Nein'),
      ];

  static List<({String schluessel, String text})> _schuetzenWerte(
    String erkannt,
  ) => <({String schluessel, String text})>[
    (schluessel: _auto, text: 'Wie am Helden: $erkannt'),
    (schluessel: 'keine', text: 'Keine'),
    (
      schluessel: 'scharf',
      text:
          'Scharfschütze '
          '(${mitVorzeichen(Schuetzenstufe.scharfschuetze.hetzErleichterung)})',
    ),
    (
      schluessel: 'meister',
      text:
          'Scharf- und Meisterschütze '
          '(${mitVorzeichen(Schuetzenstufe.meisterschuetze.hetzErleichterung)})',
    ),
  ];

  static const String _waffe = 'waffe';
  static const String _schuetze = 'schuetze';
  static const String _schnellladen = 'schnellladen';
  static const String _reiter = 'reiter';
  static const String _zuPferd = 'zupferd';
  static const String _tier = 'tier';
  static const String _auto = 'auto';
  static const String _wetter = 'wetter';
  static const String _segen = 'segen';
  static const String _jagdglueck = 'jagdglueck';
}
