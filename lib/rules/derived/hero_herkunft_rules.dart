import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parse_result.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_text_parser.dart';

/// Wirkung einer einzelnen Herkunftsgruppe (Rasse, Kultur oder Profession).
class HerkunftsWirkungen {
  /// Erstellt die Wirkung einer Gruppe.
  const HerkunftsWirkungen({
    this.modifikatoren = const ModifierParseResult(),
    this.aktiviertMagie = false,
    this.aktiviertKarma = false,
    this.brauchtPruefung = false,
  });

  /// Eigenschafts-, Startwert- und Basiswertmodifikatoren sowie unbekannte
  /// Fragmente der Gruppe.
  final ModifierParseResult modifikatoren;

  /// Ob ein Eintrag einen AsP-Code trägt (auch `ASP+0` oder eine Summe 0).
  final bool aktiviertMagie;

  /// Ob ein Eintrag einen KaP-Code trägt (auch `KAP+0` oder eine Summe 0).
  final bool aktiviertKarma;

  /// Ob die Gruppe unsichere Daten enthält (nicht verstandene Einträge oder
  /// Teilstücke), die nur über ihren Kompatibilitätstext gewertet wurden.
  final bool brauchtPruefung;
}

/// Gemeinsame Auswertung aller drei Herkunftsgruppen.
class HerkunftsAuswertung {
  /// Erstellt eine Auswertung.
  const HerkunftsAuswertung(this.jeHerkunft);

  /// Wirkung je Gruppe; enthält immer alle drei.
  final Map<HeroHerkunft, HerkunftsWirkungen> jeHerkunft;

  /// Wirkung einer Gruppe.
  HerkunftsWirkungen fuer(HeroHerkunft herkunft) =>
      jeHerkunft[herkunft] ?? const HerkunftsWirkungen();

  /// Ob irgendeine Gruppe Magie aktiviert.
  bool get aktiviertMagie => jeHerkunft.values.any((w) => w.aktiviertMagie);

  /// Ob irgendeine Gruppe Karma aktiviert.
  bool get aktiviertKarma => jeHerkunft.values.any((w) => w.aktiviertKarma);

  /// Ob irgendeine Gruppe unsichere Daten enthält.
  bool get brauchtPruefung => jeHerkunft.values.any((w) => w.brauchtPruefung);

  /// Summe der drei Gruppen in der Reihenfolge Rasse, Kultur, Profession.
  ///
  /// Unbekannte Fragmente stehen in dieser Reihenfolge, ohne Wiederholung.
  ModifierParseResult get gesamt {
    var attribute = const AttributeModifiers();
    var start = const AttributeModifiers();
    var stats = const StatModifiers();
    final unbekannt = <String>[];
    for (final herkunft in HeroHerkunft.values) {
      final m = fuer(herkunft).modifikatoren;
      attribute = attribute + m.attributeMods;
      start = start + m.startAttributeMods;
      stats = stats + m.statMods;
      for (final fragment in m.unknownFragments) {
        if (!unbekannt.contains(fragment)) {
          unbekannt.add(fragment);
        }
      }
    }
    return ModifierParseResult(
      attributeMods: attribute,
      startAttributeMods: start,
      statMods: stats,
      unknownFragments: List<String>.unmodifiable(unbekannt),
    );
  }
}

// Ergebnisse je Container-Instanz (unveraenderlich) beziehungsweise je
// Texttripel; beide Wege laufen in jedem Neuaufbau der Heldenwerte.
final Expando<HerkunftsAuswertung> _containerCache =
    Expando<HerkunftsAuswertung>('herkunftsAuswertung');
final Map<String, HerkunftsAuswertung> _textCache =
    <String, HerkunftsAuswertung>{};
const int _textCacheMaxEntries = 256;

/// Wertet die Herkunft eines Helden aus.
///
/// Die strukturierte Liste führt: Direkte Einträge (`eigenschaft`/`basiswert`
/// mit gültigem Ziel und Betrag) wirken über [wendeDirektenModifikatorAn] und
/// ignorieren ihren Text. Freie Einträge wirken nur über ihren Text im
/// Herkunftskontext, also wie bisher über den Textparser. Ein Eintrag mit
/// unbekannter Art oder unbrauchbarem Ziel gilt als frei und wirkt dadurch
/// genau einmal über seinen Text.
///
/// Ohne Container, bei unbekannter Containerversion oder nicht verstandener
/// Gruppe rechnet die jeweilige Gruppe über ihren Kompatibilitätstext
/// (`rasseModText` …). Die Aktivierung von Magie und Karma folgt aus den
/// erkannten Codes, nicht aus der Summe.
HerkunftsAuswertung werteHerkunftAus(HeroBackground background) {
  final container = background.herkunftsModifikatoren;
  if (container != null && container.istBearbeitbar) {
    final gemerkt = _containerCache[container];
    if (gemerkt != null && _kompatibilitaetsTexteLeerOderUnbenutzt(container)) {
      return gemerkt;
    }
    final ergebnis = _wertAus(background, container);
    if (_kompatibilitaetsTexteLeerOderUnbenutzt(container)) {
      _containerCache[container] = ergebnis;
    }
    return ergebnis;
  }
  return _ausTexten(background);
}

// Nur Container ohne gesperrte Gruppen sind unabhaengig vom Text; gesperrte
// Gruppen rechnen ueber den Text und duerfen deshalb nicht pro Container
// gemerkt werden.
bool _kompatibilitaetsTexteLeerOderUnbenutzt(
  HeroHerkunftsModifikatoren container,
) {
  return container.unverstandeneGruppen.isEmpty;
}

HerkunftsAuswertung _ausTexten(HeroBackground background) {
  final schluessel = [
    background.rasseModText,
    background.kulturModText,
    background.professionModText,
  ].join('\u0001');
  final gemerkt = _textCache[schluessel];
  if (gemerkt != null) {
    return gemerkt;
  }
  final ergebnis = HerkunftsAuswertung({
    for (final herkunft in HeroHerkunft.values)
      herkunft: _wirkungAusText(
        herkunft,
        herkunftsTextVon(background, herkunft),
      ),
  });
  if (_textCache.length >= _textCacheMaxEntries) {
    _textCache.remove(_textCache.keys.first);
  }
  _textCache[schluessel] = ergebnis;
  return ergebnis;
}

HerkunftsAuswertung _wertAus(
  HeroBackground background,
  HeroHerkunftsModifikatoren container,
) {
  return HerkunftsAuswertung({
    for (final herkunft in HeroHerkunft.values)
      herkunft: container.unverstandeneGruppen.containsKey(herkunft.name)
          ? _wirkungAusText(
              herkunft,
              herkunftsTextVon(background, herkunft),
              brauchtPruefung: true,
            )
          : _wirkungAusEintraegen(herkunft, container.eintraegeFuer(herkunft)),
  });
}

HerkunftsWirkungen _wirkungAusText(
  HeroHerkunft herkunft,
  String text, {
  bool brauchtPruefung = false,
}) {
  final codes = normalisierteBasiswertCodes(text);
  return HerkunftsWirkungen(
    modifikatoren: _parseImHerkunftskontext(herkunft, text),
    aktiviertMagie: codes.contains('ASP'),
    aktiviertKarma: codes.contains('KAP'),
    brauchtPruefung: brauchtPruefung,
  );
}

ModifierParseResult _parseImHerkunftskontext(
  HeroHerkunft herkunft,
  String text,
) {
  return parseModifierTexts(
    rasseModText: herkunft == HeroHerkunft.rasse ? text : '',
    kulturModText: herkunft == HeroHerkunft.kultur ? text : '',
    professionModText: herkunft == HeroHerkunft.profession ? text : '',
    vorteileText: '',
    nachteileText: '',
  );
}

HerkunftsWirkungen _wirkungAusEintraegen(
  HeroHerkunft herkunft,
  List<HeroHerkunftsModifikator> eintraege,
) {
  var attribute = const AttributeModifiers();
  var start = const AttributeModifiers();
  var stats = const StatModifiers();
  final unbekannt = <String>[];
  var magie = false;
  var karma = false;
  var pruefen = false;

  void uebernimm(ModifierParseResult ergebnis) {
    attribute = attribute + ergebnis.attributeMods;
    start = start + ergebnis.startAttributeMods;
    stats = stats + ergebnis.statMods;
    for (final fragment in ergebnis.unknownFragments) {
      if (!unbekannt.contains(fragment)) {
        unbekannt.add(fragment);
      }
    }
  }

  void werteText(String text) {
    final codes = normalisierteBasiswertCodes(text);
    magie = magie || codes.contains('ASP');
    karma = karma || codes.contains('KAP');
    uebernimm(_parseImHerkunftskontext(herkunft, text));
  }

  for (final eintrag in eintraege) {
    if (eintrag.istUnverstanden) {
      pruefen = true;
      final roh = eintrag.unverstandeneRohdaten;
      final text = roh is Map ? roh['text'] : null;
      if (text is String) {
        werteText(text);
      }
      continue;
    }
    final direkt = _direkterModifikatorVon(eintrag);
    if (direkt == null) {
      werteText(eintrag.text);
      continue;
    }
    if (direkt.art == HeroHerkunftsModifikatorArt.basiswert) {
      magie = magie || direkt.ziel == 'ASP';
      karma = karma || direkt.ziel == 'KAP';
    }
    uebernimm(wendeDirektenModifikatorAn(direkt));
  }

  return HerkunftsWirkungen(
    modifikatoren: ModifierParseResult(
      attributeMods: attribute,
      startAttributeMods: start,
      statMods: stats,
      unknownFragments: List<String>.unmodifiable(unbekannt),
    ),
    aktiviertMagie: magie,
    aktiviertKarma: karma,
    brauchtPruefung: pruefen,
  );
}

// Ein Eintrag gilt nur dann als direkt, wenn Art, Ziel und Betrag
// zusammenpassen; sonst wirkt er einmal ueber seinen Text.
DirekterModifikator? _direkterModifikatorVon(HeroHerkunftsModifikator eintrag) {
  final betrag = eintrag.betrag;
  if (betrag == null) {
    return null;
  }
  switch (eintrag.art) {
    case HeroHerkunftsModifikatorArt.eigenschaft:
      final code = parseAttributeCode(eintrag.ziel);
      if (code == null) {
        return null;
      }
      return DirekterModifikator(
        art: HeroHerkunftsModifikatorArt.eigenschaft,
        ziel: attributeCodeKey(code),
        betrag: betrag,
      );
    case HeroHerkunftsModifikatorArt.basiswert:
      final ziel = normalisiereModifikatorCode(eintrag.ziel);
      if (!istBekannterBasiswertCode(ziel)) {
        return null;
      }
      return DirekterModifikator(
        art: HeroHerkunftsModifikatorArt.basiswert,
        ziel: ziel,
        betrag: betrag,
      );
    case HeroHerkunftsModifikatorArt.frei:
      return null;
  }
}
