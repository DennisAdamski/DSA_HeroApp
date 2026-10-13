import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';

/// Schlüssel der acht Eigenschaften in Bogenreihenfolge.
const List<String> kEigenschaftSchluessel = <String>[
  'mu',
  'kl',
  'inn',
  'ch',
  'ff',
  'ge',
  'ko',
  'kk',
];

/// Anzeigekürzel je Eigenschaftsschlüssel.
const Map<String, String> kEigenschaftKuerzel = <String, String>{
  'mu': 'MU',
  'kl': 'KL',
  'inn': 'IN',
  'ch': 'CH',
  'ff': 'FF',
  'ge': 'GE',
  'ko': 'KO',
  'kk': 'KK',
};

/// Benannte Herkunft eines Teils der Eigenschaftsmodifikatoren.
class EigenschaftModifikatorQuelle {
  /// Erzeugt eine Quelle; [mods] sind ihre Beiträge je Eigenschaft.
  const EigenschaftModifikatorQuelle({
    required this.bezeichnung,
    required this.mods,
    this.art = HerleitungsArt.modifikator,
    this.quelle,
  });

  /// Anzeigename des Schritts, etwa „Rasse“ oder ein eigener Text.
  final String bezeichnung;

  /// Beiträge dieser Quelle zu allen Eigenschaften.
  final AttributeModifiers mods;

  /// Art des Schritts; temporäre Zauberboni sind [HerleitungsArt.zauber].
  final HerleitungsArt art;

  /// Übergeordnete Herkunft, etwa „Eigener Modifikator“.
  final String? quelle;
}

/// Effektive Eigenschaften eines Helden als [Herleitung]en (ARCH-04).
class EigenschaftHerleitungen {
  /// Erzeugt den Satz aus einer Herleitung je [kEigenschaftSchluessel].
  EigenschaftHerleitungen(Map<String, Herleitung> je)
    : je = Map<String, Herleitung>.unmodifiable(je);

  /// Herleitung je Eigenschaftsschlüssel.
  final Map<String, Herleitung> je;

  /// Herleitung einer Eigenschaft, `null` bei unbekanntem Schlüssel.
  Herleitung? fuer(String key) => je[key];

  /// Die hergeleiteten Werte als [Attributes]; [basis] liefert alle übrigen
  /// Felder (etwa unbekannte JSON-Felder) unverändert.
  Attributes werteAuf(Attributes basis) => basis.copyWith(
    mu: je['mu']!.wert,
    kl: je['kl']!.wert,
    inn: je['inn']!.wert,
    ch: je['ch']!.wert,
    ff: je['ff']!.wert,
    ge: je['ge']!.wert,
    ko: je['ko']!.wert,
    kk: je['kk']!.wert,
  );
}

/// Zerlegt die Eigenschaftsmodifikatoren eines Helden in benannte Quellen.
///
/// Reihenfolge und Summe entsprechen den effektiven Eigenschaften:
/// Text (Herkunft, Vor-/Nachteile), eigene Modifikatoren, Inventar und, nur
/// mit [temporaer], temporäre Zauberboni. [textAufteilung] wird nur
/// verwendet, wenn ihre Summe [textMods] gleicht; sonst bleibt der Textanteil
/// ein Schritt, damit die Herleitung nie vom gerechneten Wert abweicht.
List<EigenschaftModifikatorQuelle> sammleEigenschaftQuellen({
  required AttributeModifiers textMods,
  required Map<String, List<HeroTalentModifier>> eigene,
  List<EigenschaftModifikatorQuelle>? textAufteilung,
  AttributeModifiers inventar = const AttributeModifiers(),
  AttributeModifiers? temporaer,
}) {
  final passend =
      textAufteilung != null && _gleich(_summe(textAufteilung), textMods);
  return <EigenschaftModifikatorQuelle>[
    if (passend)
      ...textAufteilung
    else
      EigenschaftModifikatorQuelle(
        bezeichnung: 'Herkunft, Vor- und Nachteile',
        mods: textMods,
      ),
    ..._eigeneQuellen(eigene),
    EigenschaftModifikatorQuelle(bezeichnung: 'Inventar', mods: inventar),
    if (temporaer != null)
      EigenschaftModifikatorQuelle(
        bezeichnung: 'Temporär',
        mods: temporaer,
        art: HerleitungsArt.zauber,
        quelle: 'Zaubereffekt (etwa Attributo)',
      ),
  ];
}

/// Text-Quellen der Eigenschaften nach Herkunft und Merkmalen.
List<EigenschaftModifikatorQuelle> herkunftsEigenschaftQuellen(
  ModifierSourceBreakdown b,
) {
  return <EigenschaftModifikatorQuelle>[
    EigenschaftModifikatorQuelle(
      bezeichnung: 'Rasse',
      mods: b.rasseAttributeMods,
    ),
    EigenschaftModifikatorQuelle(
      bezeichnung: 'Kultur',
      mods: b.kulturAttributeMods,
    ),
    EigenschaftModifikatorQuelle(
      bezeichnung: 'Profession',
      mods: b.professionAttributeMods,
    ),
    EigenschaftModifikatorQuelle(
      bezeichnung: 'Vorteile',
      mods: b.vorteileAttributeMods,
    ),
    EigenschaftModifikatorQuelle(
      bezeichnung: 'Nachteile',
      mods: b.nachteileAttributeMods,
    ),
  ];
}

/// Leitet alle Eigenschaften aus den [gespeichert]en Werten und [quellen] her.
EigenschaftHerleitungen computeEigenschaftHerleitungen({
  required Attributes gespeichert,
  required List<EigenschaftModifikatorQuelle> quellen,
}) {
  return EigenschaftHerleitungen(<String, Herleitung>{
    for (final key in kEigenschaftSchluessel)
      key: Herleitung(
        bezeichnung: kEigenschaftKuerzel[key]!,
        schritte: <HerleitungsSchritt>[
          HerleitungsSchritt(
            bezeichnung: 'Eingetragener Wert',
            betrag: _wert(gespeichert, key),
            art: HerleitungsArt.grundwert,
          ),
          for (final quelle in quellen)
            HerleitungsSchritt(
              bezeichnung: quelle.bezeichnung,
              betrag: attributeModValue(quelle.mods, key),
              art: quelle.art,
              quelle: quelle.quelle,
            ),
        ],
      ),
  });
}

// Eigene (benannte) Modifikatoren: je Eintrag eine Quelle für seinen Wert.
List<EigenschaftModifikatorQuelle> _eigeneQuellen(
  Map<String, List<HeroTalentModifier>> eigene,
) {
  return <EigenschaftModifikatorQuelle>[
    for (final key in kEigenschaftSchluessel)
      for (final eintrag in eigene[key] ?? const <HeroTalentModifier>[])
        EigenschaftModifikatorQuelle(
          bezeichnung: eintrag.description,
          mods: _einzelwert(key, eintrag.modifier),
          quelle: 'Eigener Modifikator',
        ),
  ];
}

AttributeModifiers _summe(Iterable<EigenschaftModifikatorQuelle> quellen) {
  var summe = const AttributeModifiers();
  for (final quelle in quellen) {
    summe = summe + quelle.mods;
  }
  return summe;
}

bool _gleich(AttributeModifiers a, AttributeModifiers b) {
  for (final key in kEigenschaftSchluessel) {
    if (attributeModValue(a, key) != attributeModValue(b, key)) {
      return false;
    }
  }
  return true;
}

// Modifikatorsatz mit genau einer belegten Eigenschaft.
AttributeModifiers _einzelwert(String key, int wert) {
  return switch (key) {
    'mu' => AttributeModifiers(mu: wert),
    'kl' => AttributeModifiers(kl: wert),
    'inn' => AttributeModifiers(inn: wert),
    'ch' => AttributeModifiers(ch: wert),
    'ff' => AttributeModifiers(ff: wert),
    'ge' => AttributeModifiers(ge: wert),
    'ko' => AttributeModifiers(ko: wert),
    'kk' => AttributeModifiers(kk: wert),
    _ => const AttributeModifiers(),
  };
}

int _wert(Attributes a, String key) {
  return switch (key) {
    'mu' => a.mu,
    'kl' => a.kl,
    'inn' => a.inn,
    'ch' => a.ch,
    'ff' => a.ff,
    'ge' => a.ge,
    'ko' => a.ko,
    'kk' => a.kk,
    _ => 0,
  };
}
