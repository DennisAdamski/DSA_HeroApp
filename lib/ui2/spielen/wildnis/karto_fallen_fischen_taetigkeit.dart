import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fallen_fischen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/jagd_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_rationen_taetigkeit.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/wildnis/karto_wildnis_taetigkeit.dart';

/// Die gemeinsame Eingabe aus dem Kontext.
RationenProbeEingabe _rationenEingabe(
  KartoRationenTaetigkeit taetigkeit,
  KartoWildnisKontext kontext,
) => RationenProbeEingabe(
  region: taetigkeit.region(kontext),
  taw: kontext.taw,
  eigenschaften: kontext.eigenschaften,
  nurSchmackhaft: nurSchmackhaft(kontext),
  gelaendekunde: kontext.gelaendekunde,
  ortskenntnis: kontext.ortskenntnis,
  eingesetzteAsp: kontext.eingesetzteAsp,
  situativeErschwernis: kontext.situativeErschwernis,
);

/// Tierfallen aufstellen (Wege des Entdeckers S. 111 f.): Schlingen über
/// Nacht oder während einer Rast; die Probe fällt beim Kontrollieren.
class KartoTierfallenTaetigkeit extends KartoRationenTaetigkeit {
  /// Die Tätigkeit ist zustandslos.
  const KartoTierfallenTaetigkeit();

  @override
  String get id => 'tierfallen';

  @override
  String get titel => 'Tierfallen stellen';

  @override
  IconData get symbol => Icons.gesture;

  @override
  String get regelHinweis => 'Wege des Entdeckers S. 111 f.';

  @override
  List<String> get talentKomponenten => kTierfallenTalente;

  @override
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      tierfallenTaw(held.talents);

  @override
  List<AttributeCode> get eigenschaften => const <AttributeCode>[
    AttributeCode.kl,
    AttributeCode.inn,
    AttributeCode.ff,
  ];

  @override
  GelaendekundeStaffel get gelaendekundeStaffel => kTierfallenGelaendekunde;

  @override
  List<KartoWildnisDauer> get dauern => const <KartoWildnisDauer>[
    (minuten: 60, text: '1 Stunde (Aufstellen und Kontrolle)'),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    beuteOption(kTierfallenSchmackhaftErschwernis),
  ];

  @override
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext) =>
      tierfallenProbeEingabe(_rationenEingabe(this, kontext));

  @override
  List<({String text, int wert})> erschwernisTeile(
    KartoWildnisKontext kontext,
  ) => <({String text, int wert})>[
    (text: 'Region', wert: tierfallenRegionsErschwernis(region(kontext)) ?? 0),
    if (nurSchmackhaft(kontext))
      (text: 'schmackhaft', wert: kTierfallenSchmackhaftErschwernis),
  ];

  @override
  String auswertungsHinweis(KartoWildnisKontext kontext) =>
      'Mehr Zeit oder helfende Gefährten erlauben weitere Proben, bis alle '
      'guten Plätze belegt sind (Meisterentscheid).';

  @override
  String? get inventarGegenstand => kWildbretGegenstand;

  @override
  String inventarBeschreibung(KartoWildnisKontext kontext) =>
      frischfleischBeschreibung(region(kontext));
}

/// Angeln mit dem Talent Fischen/Angeln (Wege des Entdeckers S. 110), ohne
/// Metatalent.
class KartoAngelnTaetigkeit extends KartoRationenTaetigkeit {
  /// Die Tätigkeit ist zustandslos.
  const KartoAngelnTaetigkeit();

  @override
  String get id => 'angeln';

  @override
  String get titel => 'Angeln';

  @override
  IconData get symbol => Icons.phishing;

  @override
  String get regelHinweis => 'Wege des Entdeckers S. 110';

  @override
  List<String> get talentKomponenten => const <String>[kAngelnTalent];

  @override
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      einzeltalentTaw(held.talents, kAngelnTalent);

  @override
  List<AttributeCode> get eigenschaften => const <AttributeCode>[
    AttributeCode.inn,
    AttributeCode.ff,
    AttributeCode.kk,
  ];

  @override
  List<KartoWildnisDauer> get dauern => const <KartoWildnisDauer>[
    (minuten: 60, text: '1 Stunde'),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    beuteOption(kJagdSchmackhaftErschwernis),
  ];

  @override
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext) =>
      angelnProbeEingabe(_rationenEingabe(this, kontext));

  @override
  List<({String text, int wert})> erschwernisTeile(
    KartoWildnisKontext kontext,
  ) => _fischenTeile(this, kontext);

  @override
  String auswertungsHinweis(KartoWildnisKontext kontext) =>
      'Beliebig viele Versuche; nach mehreren Erfolgen kann das Gewässer '
      'überfischt sein (Meisterentscheid).';

  @override
  String? get inventarGegenstand => kFischGegenstand;

  @override
  String inventarBeschreibung(KartoWildnisKontext kontext) =>
      frischfleischBeschreibung(region(kontext));
}

/// Speerfischen (Wege des Entdeckers S. 110 f.): regungslos im flachen
/// Wasser warten und zustoßen.
class KartoSpeerfischenTaetigkeit extends KartoRationenTaetigkeit {
  /// Die Tätigkeit ist zustandslos.
  const KartoSpeerfischenTaetigkeit();

  @override
  String get id => 'speerfischen';

  @override
  String get titel => 'Speerfischen';

  @override
  IconData get symbol => Icons.waves_outlined;

  @override
  String get regelHinweis => 'Wege des Entdeckers S. 110 f.';

  /// Mit Speere; [grundTaw] nimmt das gewählte Speertalent.
  @override
  List<String> get talentKomponenten =>
      speerfischenTalente(kSpeerfischenSpeertalente.first);

  @override
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      computeMetaTalentBaseTaw(
        talentEntries: held.talents,
        componentTalentIds: speerfischenTalente(
          _speertalent(held, optionen[_talent]),
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
    (minuten: 60, text: '1 Stunde'),
  ];

  @override
  List<KartoWildnisOption> get optionen => <KartoWildnisOption>[
    KartoWildnisOption(
      schluessel: _talent,
      bezeichnung: 'Speertalent',
      standard: '',
      werte: <({String schluessel, String text})>[
        (schluessel: 'tal_speere', text: 'Speere'),
        (schluessel: 'tal_wurfspeere', text: 'Wurfspeere'),
      ],
      dynamischeWerte: (kontext) => <({String schluessel, String text})>[
        for (final id in _speertalenteNachWert(kontext.held))
          (
            schluessel: id,
            text:
                '${id == 'tal_speere' ? 'Speere' : 'Wurfspeere'} '
                '(TaW ${kontext.held.talents[id]?.talentValue ?? 0})',
          ),
      ],
    ),
    KartoWildnisOption(
      schluessel: _speer,
      bezeichnung: 'Waffe',
      standard: Fischspeer.fischspeer.name,
      werte: <({String schluessel, String text})>[
        for (final s in Fischspeer.values)
          (
            schluessel: s.name,
            text: '${s.bezeichnung} (${mitVorzeichen(s.erschwernis)})',
          ),
      ],
    ),
    KartoWildnisOption(
      schluessel: _schuetze,
      bezeichnung: 'Scharfschütze (nur mit Wurfspeeren)',
      standard: 'auto',
      werte: const <({String schluessel, String text})>[
        (schluessel: 'auto', text: 'Wie am Helden'),
        (schluessel: 'nein', text: 'Nein'),
        (schluessel: 'ja', text: 'Ja (−3)'),
      ],
      dynamischeWerte: (kontext) => <({String schluessel, String text})>[
        (
          schluessel: 'auto',
          text: 'Wie am Helden: ${_erkannt(kontext) ? 'ja (−3)' : 'nein'}',
        ),
        (schluessel: 'nein', text: 'Nein'),
        (schluessel: 'ja', text: 'Ja (−3)'),
      ],
    ),
    beuteOption(kJagdSchmackhaftErschwernis),
  ];

  /// Speertalente nach TaW absteigend; das bessere ist die Vorgabe.
  static List<String> _speertalenteNachWert(HeroSheet held) =>
      List<String>.of(kSpeerfischenSpeertalente)..sort(
        (a, b) => (held.talents[b]?.talentValue ?? 0).compareTo(
          held.talents[a]?.talentValue ?? 0,
        ),
      );

  static String _speertalent(HeroSheet held, String? gewaehlt) =>
      kSpeerfischenSpeertalente.contains(gewaehlt)
      ? gewaehlt!
      : _speertalenteNachWert(held).first;

  bool _erkannt(KartoWildnisKontext kontext) {
    final talent = _speertalent(kontext.held, kontext.optionen[_talent]);
    // Scharfschütze ist eine Fernkampf-SF: mit dem Nahkampftalent Speere gilt
    // sie nicht.
    return talent == 'tal_wurfspeere' &&
        schuetzenstufeDesHelden(
              kontext.held,
              talentId: talent,
              catalog: kontext.katalog,
            ) !=
            Schuetzenstufe.keine;
  }

  bool _scharfschuetze(KartoWildnisKontext kontext) =>
      switch (kontext.optionen[_schuetze]) {
        'ja' => true,
        'nein' => false,
        _ => _erkannt(kontext),
      };

  Fischspeer _waffe(KartoWildnisKontext kontext) =>
      Fischspeer.values.asNameMap()[kontext.optionen[_speer]] ??
      Fischspeer.fischspeer;

  @override
  WildnisProbeEingabe? probeEingabe(KartoWildnisKontext kontext) =>
      speerfischenProbeEingabe(
        _rationenEingabe(this, kontext),
        speer: _waffe(kontext),
        scharfschuetze: _scharfschuetze(kontext),
      );

  @override
  List<({String text, int wert})> erschwernisTeile(
    KartoWildnisKontext kontext,
  ) => <({String text, int wert})>[
    ..._fischenTeile(this, kontext),
    (text: _waffe(kontext).bezeichnung, wert: _waffe(kontext).erschwernis),
    if (_scharfschuetze(kontext))
      (text: 'Scharfschütze', wert: kSpeerfischenScharfschuetze),
  ];

  @override
  String auswertungsHinweis(KartoWildnisKontext kontext) =>
      'Nicht wiederholbar: Die Fische sind weit und breit verscheucht.';

  @override
  String? get inventarGegenstand => kFischGegenstand;

  @override
  String inventarBeschreibung(KartoWildnisKontext kontext) =>
      frischfleischBeschreibung(region(kontext));

  static const String _talent = 'talent';
  static const String _speer = 'speer';
  static const String _schuetze = 'schuetze';
}

/// Region und Beute beim Fischen.
List<({String text, int wert})> _fischenTeile(
  KartoRationenTaetigkeit taetigkeit,
  KartoWildnisKontext kontext,
) {
  final region = taetigkeit.region(kontext);
  return <({String text, int wert})>[
    (
      text: switch (region) {
        Wildnisregion.hochgebirge ||
        Wildnisregion.ewigesEis => 'Region (Eis aufhacken)',
        _ => 'Region',
      },
      wert: fischenRegionsErschwernis(region) ?? 0,
    ),
    if (nurSchmackhaft(kontext))
      (text: 'schmackhaft', wert: kJagdSchmackhaftErschwernis),
  ];
}
