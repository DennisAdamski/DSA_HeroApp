import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Art einer deklarativen Vor-/Nachteil-Wirkung im Katalog (`wirkungen`).
///
/// Die Arten bilden genau die Regelwirkungen ab, die frueher per Namenssuche
/// aus `vorteileText`/`nachteileText` gelesen wurden. Ausgewertet werden sie
/// ausschliesslich in `lib/rules/derived/hero_merkmal_rules.dart`.
enum HeroTraitEffectArt {
  /// Abgeleiteter Basiswert (LeP, AuP, AsP, KaP, MR, INI, GS, Ausweichen),
  /// Betrag = Wert des Merkmals × [HeroTraitEffect.jeWert], gekappt.
  basiswert,

  /// Eigenschaft aus der Auswahl (`{choice}` = Kuerzel wie `KK`).
  eigenschaft,

  /// Benannter Schalter mit fester Regelwirkung (`flink`, `behaebig`,
  /// `linkshaender`).
  schalter,

  /// Fester Bonus auf alle Wundschwellenstufen.
  wundschwelle,

  /// Regenerationsstufe oder -einschraenkung bei der Rast.
  rast,

  /// Steigerungsspalte eines Ziels (Begabung/Unfaehigkeit):
  /// [HeroTraitEffect.betrag] Spalten guenstiger, negativ = teurer. Das
  /// konkrete Ziel steht bei Auswahl-Eintraegen in der Auswahl (Talent,
  /// Talentgruppe, Zauber, Merkmal, Ritual, Sprachen/Schriften).
  lernspalte,

  /// Von dieser Version nicht verstandene Art; wirkt nicht.
  unbekannt,
}

/// Deklarative Regelwirkung eines Vor- oder Nachteils.
///
/// Der Katalog beschreibt, *was* ein Merkmal bewirkt; die Rechnung liegt im
/// Regelmodul. So wirkt ein Merkmal ueber seine stabile Katalog-ID, nicht
/// ueber seinen Anzeigenamen, und Hausregel-Pakete koennen Wirkungen per
/// `setFields` anpassen.
class HeroTraitEffect {
  /// Erstellt eine Wirkungsbeschreibung.
  const HeroTraitEffect({
    required this.art,
    this.rohArt = '',
    this.ziel = '',
    this.jeWert = 1,
    this.standard,
    this.max,
    this.betrag = 0,
    this.startwert = false,
  });

  /// Art der Wirkung.
  final HeroTraitEffectArt art;

  /// Gespeicherte Art, auch wenn sie unbekannt ist (fuer `toJson`).
  final String rohArt;

  /// Ziel der Wirkung, z. B. `lep`, `flink` oder `lepStufe`. Bei
  /// [HeroTraitEffectArt.eigenschaft] leer, weil die Auswahl das Ziel ist.
  final String ziel;

  /// Faktor je Wertpunkt; das Vorzeichen traegt die Richtung (Nachteile -1).
  final int jeWert;

  /// Wert, der gilt, wenn das Merkmal keinen Zahlenwert traegt. `null`
  /// bedeutet: ohne Wert keine Wirkung.
  final int? standard;

  /// Obergrenze des Betrags vor Anwendung von [jeWert].
  final int? max;

  /// Fester Betrag fuer [HeroTraitEffectArt.wundschwelle] und
  /// [HeroTraitEffectArt.lernspalte] (Spalten guenstiger).
  final int betrag;

  /// Ob die Wirkung zusaetzlich den Startwert der Eigenschaft hebt.
  final bool startwert;

  /// Liest eine Wirkung tolerant aus dem Katalog-JSON.
  factory HeroTraitEffect.fromJson(Map<String, dynamic> json) {
    final rohArt = readCatalogString(json, 'art', fallback: '');
    final art = HeroTraitEffectArt.values.firstWhere(
      (value) => value.name == rohArt && value != HeroTraitEffectArt.unbekannt,
      orElse: () => HeroTraitEffectArt.unbekannt,
    );
    return HeroTraitEffect(
      art: art,
      rohArt: rohArt,
      ziel: readCatalogString(json, 'ziel', fallback: ''),
      jeWert: readCatalogInt(json, 'jeWert', fallback: 1),
      standard: _leseOptionaleZahl(json, 'standard'),
      max: _leseOptionaleZahl(json, 'max'),
      betrag: readCatalogInt(json, 'betrag', fallback: 0),
      startwert: readCatalogBool(json, 'startwert', fallback: false),
    );
  }

  /// Schreibt die Wirkung zurueck; unbekannte Arten behalten ihren Rohwert.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'art': art == HeroTraitEffectArt.unbekannt ? rohArt : art.name,
      if (ziel.isNotEmpty) 'ziel': ziel,
      if (jeWert != 1) 'jeWert': jeWert,
      if (standard != null) 'standard': standard,
      if (max != null) 'max': max,
      if (betrag != 0) 'betrag': betrag,
      if (startwert) 'startwert': true,
    };
  }
}

/// Bekannte Ziele je Wirkungsart; Katalogtests pruefen dagegen.
const Map<HeroTraitEffectArt, Set<String>> kHeroTraitEffectZiele =
    <HeroTraitEffectArt, Set<String>>{
      HeroTraitEffectArt.basiswert: <String>{
        'lep',
        'au',
        'asp',
        'kap',
        'mr',
        'ini',
        'gs',
        'ausweichen',
      },
      HeroTraitEffectArt.eigenschaft: <String>{''},
      HeroTraitEffectArt.schalter: <String>{
        'flink',
        'behaebig',
        'linkshaender',
      },
      HeroTraitEffectArt.wundschwelle: <String>{''},
      HeroTraitEffectArt.rast: <String>{
        'lepStufe',
        'aspStufe',
        'schlechteRegeneration',
        'astralerBlock',
      },
      HeroTraitEffectArt.lernspalte: <String>{
        'talent',
        'talentgruppe',
        'nahkampf',
        'fernkampf',
        'sprachen',
        'sprachgruppe',
        'zauber',
        'merkmal',
        'ritual',
      },
    };

int? _leseOptionaleZahl(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }
  return null;
}
