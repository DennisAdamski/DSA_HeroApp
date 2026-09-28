/// Regelwirkungen strukturierter Vor- und Nachteile (ARCH-02).
///
/// Katalogisierte Eintraege wirken ueber die deklarativen `wirkungen` ihres
/// Katalogeintrags, gefunden ueber die stabile Katalog-ID — ein umbenannter
/// Katalogeintrag wirkt deshalb unveraendert. Freie Eintraege (eigene
/// Merkmale, `LEP+2`, mehrdeutige Alttexte) und Eintraege, deren ID der
/// Katalog nicht (mehr) kennt, wirken wie bisher ueber ihren Text im
/// Modifikator-Parser und den benannten Textregeln. Jedes Fragment gehoert
/// damit genau einem der beiden Wege an; doppelt angewendet wird nichts.
///
/// Ohne Katalog rechnen alle Regeln ueber den Text der Liste
/// ([wirksamerMerkmalText]); `test/rules/hero_merkmal_rules_test.dart`
/// haelt fest, dass beide Wege fuer jeden wirkenden Katalogeintrag gleich
/// rechnen.
library;

import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_trait_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';

/// Verschiebung der Steigerungsspalte durch Begabung oder Unfaehigkeit.
///
/// Ausgewertet in `hero_begabung_rules.dart`; hier nur gesammelt, damit
/// Begabungen wie alle anderen Wirkungen ueber die Katalog-ID laufen.
class LernspaltenWirkung {
  /// Erstellt eine gesammelte Lernspalten-Wirkung.
  const LernspaltenWirkung({
    required this.ziel,
    required this.auswahl,
    required this.betrag,
    required this.quelle,
  });

  /// Zielart, z. B. `talent`, `talentgruppe`, `zauber` oder `merkmal`.
  final String ziel;

  /// Gewaehltes Ziel (Talent-, Gruppen-, Zauber-, Merkmal- oder Ritualname);
  /// leer bei festen Zielen wie `nahkampf` oder `sprachen`.
  final String auswahl;

  /// Spalten guenstiger (Begabung `+1`), negativ = teurer (Unfaehigkeit).
  final int betrag;

  /// Kurztext des Merkmals fuer Hinweise, z. B. `Begabung für Abrichten`.
  final String quelle;
}

/// Summe der deklarativen Wirkungen katalogisierter Merkmale.
class MerkmalWirkungen {
  /// Erstellt ein Wirkungsergebnis; ohne Angaben wirkt nichts.
  const MerkmalWirkungen({
    this.attributeMods = const AttributeModifiers(),
    this.startAttributeMods = const AttributeModifiers(),
    this.statMods = const StatModifiers(),
    this.flink = false,
    this.behaebig = false,
    this.wundschwelleBonus = 0,
    this.lepStufe = 0,
    this.aspStufe = 0,
    this.schlechteRegeneration = false,
    this.astralerBlock = false,
    this.lernspalten = const <LernspaltenWirkung>[],
  });

  /// Eigenschaftsmodifikatoren (laufend).
  final AttributeModifiers attributeMods;

  /// Anteil, der zusaetzlich den Startwert hebt (Herausragende Eigenschaft).
  final AttributeModifiers startAttributeMods;

  /// Modifikatoren abgeleiteter Basiswerte.
  final StatModifiers statMods;

  /// Flink: GS +1 und Ausweichen +1.
  final bool flink;

  /// Behaebig: GS -1 und Ausweichen -1.
  final bool behaebig;

  /// Bonus auf alle Wundschwellenstufen.
  final int wundschwelleBonus;

  /// Stufe der schnellen Heilung (LeP-Regeneration).
  final int lepStufe;

  /// Stufe der astralen Regeneration.
  final int aspStufe;

  /// Schlechte Regeneration.
  final bool schlechteRegeneration;

  /// Astraler Block.
  final bool astralerBlock;

  /// Begabungen und Unfaehigkeiten in Eintragsreihenfolge.
  final List<LernspaltenWirkung> lernspalten;

  /// Fasst die Wirkungen von Vor- und Nachteilen zusammen.
  MerkmalWirkungen kombiniert(MerkmalWirkungen andere) {
    return MerkmalWirkungen(
      attributeMods: attributeMods + andere.attributeMods,
      startAttributeMods: startAttributeMods + andere.startAttributeMods,
      statMods: statMods + andere.statMods,
      flink: flink || andere.flink,
      behaebig: behaebig || andere.behaebig,
      wundschwelleBonus: wundschwelleBonus + andere.wundschwelleBonus,
      lepStufe: math.max(lepStufe, andere.lepStufe),
      aspStufe: math.max(aspStufe, andere.aspStufe),
      schlechteRegeneration:
          schlechteRegeneration || andere.schlechteRegeneration,
      astralerBlock: astralerBlock || andere.astralerBlock,
      lernspalten: List<LernspaltenWirkung>.unmodifiable(<LernspaltenWirkung>[
        ...lernspalten,
        ...andere.lernspalten,
      ]),
    );
  }
}

/// Vor- und Nachteile eines Helden, aufgeloest fuer alle Regelmodule.
class HeroMerkmalAuswertung {
  /// Buendelt Abgleich, Wirkungen und die frei wirkenden Texte.
  const HeroMerkmalAuswertung({
    required this.abgleich,
    required this.vorteilWirkungen,
    required this.nachteilWirkungen,
    required this.freieVorteile,
    required this.freieNachteile,
    required this.vorteilNamen,
    required this.nachteilNamen,
  });

  /// Wirksame Eintraege, Abweichungen und offene Pruefungen.
  final MerkmalAbgleich abgleich;

  /// Wirkungen der katalogisierten Vorteile.
  final MerkmalWirkungen vorteilWirkungen;

  /// Wirkungen der katalogisierten Nachteile.
  final MerkmalWirkungen nachteilWirkungen;

  /// Wirkungen aller katalogisierten Eintraege.
  MerkmalWirkungen get wirkungen =>
      vorteilWirkungen.kombiniert(nachteilWirkungen);

  /// Text der frei wirkenden Vorteile fuer Parser und Namensregeln.
  final String freieVorteile;

  /// Text der frei wirkenden Nachteile.
  final String freieNachteile;

  /// Namen aller Vorteile fuer Erwerbsvoraussetzungen: aktueller
  /// Katalogname und gespeicherter Text.
  final List<String> vorteilNamen;

  /// Namen aller Nachteile fuer Erwerbsvoraussetzungen.
  final List<String> nachteilNamen;
}

/// Wertet die Vor- und Nachteile von [hero] aus.
///
/// Mit [catalog] wirken katalogisierte Eintraege ueber ihre Katalog-ID; ohne
/// Katalog wirkt alles ueber [wirksamerMerkmalText]. Das Ergebnis wird je
/// Held und Katalog gemerkt, weil die Regeln es mehrfach je Berechnung
/// brauchen.
HeroMerkmalAuswertung werteMerkmaleAus(
  HeroSheet hero, {
  RulesCatalog? catalog,
}) {
  final gemerkt = _auswertungen[hero];
  if (gemerkt != null && identical(gemerkt.catalog, catalog)) {
    return gemerkt.auswertung;
  }
  final auswertung = _werteAus(hero, catalog);
  _auswertungen[hero] = (catalog: catalog, auswertung: auswertung);
  return auswertung;
}

final Expando<({RulesCatalog? catalog, HeroMerkmalAuswertung auswertung})>
_auswertungen =
    Expando<({RulesCatalog? catalog, HeroMerkmalAuswertung auswertung})>();

HeroMerkmalAuswertung _werteAus(HeroSheet hero, RulesCatalog? catalog) {
  final katalog = catalog == null ? null : MerkmalKatalog.von(catalog);
  final abgleich = gleicheMerkmaleAb(hero, katalog: katalog);
  if (katalog == null) {
    final vorteile = wirksamerMerkmalText(
      hero.vorteileText,
      hero.vorteilEintraege,
    );
    final nachteile = wirksamerMerkmalText(
      hero.nachteileText,
      hero.nachteilEintraege,
    );
    return HeroMerkmalAuswertung(
      abgleich: abgleich,
      vorteilWirkungen: const MerkmalWirkungen(),
      nachteilWirkungen: const MerkmalWirkungen(),
      freieVorteile: vorteile,
      freieNachteile: nachteile,
      vorteilNamen: _texte(abgleich.vorteile),
      nachteilNamen: _texte(abgleich.nachteile),
    );
  }
  final vorteilRechner = _Rechner();
  final nachteilRechner = _Rechner();
  final freieVorteile = vorteilRechner.wende(abgleich.vorteile, katalog, true);
  final freieNachteile = nachteilRechner.wende(
    abgleich.nachteile,
    katalog,
    false,
  );
  return HeroMerkmalAuswertung(
    abgleich: abgleich,
    vorteilWirkungen: vorteilRechner.ergebnis(),
    nachteilWirkungen: nachteilRechner.ergebnis(),
    freieVorteile: projiziereMerkmalText(freieVorteile),
    freieNachteile: projiziereMerkmalText(freieNachteile),
    vorteilNamen: _namen(abgleich.vorteile, katalog, vorteil: true),
    nachteilNamen: _namen(abgleich.nachteile, katalog, vorteil: false),
  );
}

/// Berechnet die Wirkungen katalogisierter Eintraege ohne Heldenkontext.
///
/// Liefert zusaetzlich die Eintraege, die frei wirken (ohne oder mit
/// unbekannter Katalog-ID).
({MerkmalWirkungen wirkungen, List<HeroMerkmal> frei})
berechneMerkmalWirkungen({
  required List<HeroMerkmal> vorteile,
  required List<HeroMerkmal> nachteile,
  required MerkmalKatalog katalog,
}) {
  final rechner = _Rechner();
  final frei = <HeroMerkmal>[
    ...rechner.wende(vorteile, katalog, true),
    ...rechner.wende(nachteile, katalog, false),
  ];
  return (wirkungen: rechner.ergebnis(), frei: frei);
}

/// Sammelt Wirkungen ueber alle Eintraege.
class _Rechner {
  var _attribute = const AttributeModifiers();
  var _start = const AttributeModifiers();
  var _stats = const StatModifiers();
  var _flink = false;
  var _behaebig = false;
  var _lepStufe = 0;
  var _aspStufe = 0;
  var _schlechteRegeneration = false;
  var _astralerBlock = false;
  final List<LernspaltenWirkung> _lernspalten = <LernspaltenWirkung>[];

  // Wundschwellenboni zaehlen je Katalogeintrag einmal, wie die fruehere
  // Namensregel (`Eisern` zweimal eingetragen bleibt +2).
  final Map<String, int> _wundschwelle = <String, int>{};

  // Wendet [eintraege] an und liefert die, die frei wirken muessen.
  List<HeroMerkmal> wende(
    List<HeroMerkmal> eintraege,
    MerkmalKatalog katalog,
    bool vorteil,
  ) {
    final frei = <HeroMerkmal>[];
    for (final eintrag in eintraege) {
      final def = eintrag.istKatalogisiert
          ? katalog.eintrag(eintrag.katalogId, vorteil: vorteil)
          : null;
      if (def == null) {
        frei.add(eintrag);
        continue;
      }
      for (final wirkung in def.wirkungen) {
        _wende(wirkung, eintrag, def);
      }
    }
    return frei;
  }

  void _wende(HeroTraitEffect wirkung, HeroMerkmal eintrag, HeroTraitDef def) {
    switch (wirkung.art) {
      case HeroTraitEffectArt.basiswert:
        final betrag = merkmalBasiswertBetrag(wirkung, eintrag);
        if (betrag == null) {
          return;
        }
        _stats = _stats + _statMods(wirkung.ziel, betrag);
      case HeroTraitEffectArt.eigenschaft:
        final code = parseAttributeCode(eintrag.auswahl);
        if (code == null) {
          return;
        }
        final betrag = merkmalEigenschaftBetrag(wirkung, eintrag);
        final mods = attributeModifiersFor(code, betrag);
        _attribute = _attribute + mods;
        if (wirkung.startwert) {
          _start = _start + mods;
        }
      case HeroTraitEffectArt.schalter:
        if (wirkung.ziel == 'flink') {
          _flink = true;
        } else if (wirkung.ziel == 'behaebig') {
          _behaebig = true;
        }
      case HeroTraitEffectArt.wundschwelle:
        _wundschwelle[def.id] = wirkung.betrag;
      case HeroTraitEffectArt.rast:
        final stufe = merkmalRastStufe(wirkung, eintrag);
        switch (wirkung.ziel) {
          case 'lepStufe':
            _lepStufe = math.max(_lepStufe, stufe);
          case 'aspStufe':
            _aspStufe = math.max(_aspStufe, stufe);
          case 'schlechteRegeneration':
            _schlechteRegeneration = true;
          case 'astralerBlock':
            _astralerBlock = true;
        }
      case HeroTraitEffectArt.lernspalte:
        if (wirkung.betrag == 0) {
          return;
        }
        _lernspalten.add(
          LernspaltenWirkung(
            ziel: wirkung.ziel,
            auswahl: eintrag.auswahl.trim(),
            betrag: wirkung.betrag,
            quelle: merkmalTextFuer(
              def,
              auswahl: eintrag.auswahl,
              wert: eintrag.wert,
            ),
          ),
        );
      case HeroTraitEffectArt.unbekannt:
        return;
    }
  }

  MerkmalWirkungen ergebnis() {
    return MerkmalWirkungen(
      attributeMods: _attribute,
      startAttributeMods: _start,
      statMods: _stats,
      flink: _flink,
      behaebig: _behaebig,
      wundschwelleBonus: _wundschwelle.values.fold(0, (a, b) => a + b),
      lepStufe: _lepStufe,
      aspStufe: _aspStufe,
      schlechteRegeneration: _schlechteRegeneration,
      astralerBlock: _astralerBlock,
      lernspalten: List<LernspaltenWirkung>.unmodifiable(_lernspalten),
    );
  }
}

/// Betrag einer `basiswert`-Wirkung fuer [eintrag]; `null` ohne Wert und
/// ohne Standard (dann wirkt das Merkmal nicht). Geteilt von Rechnung und
/// Anzeige, damit beide dieselbe Kappung verwenden.
int? merkmalBasiswertBetrag(HeroTraitEffect wirkung, HeroMerkmal eintrag) {
  final roh = eintrag.wert ?? wirkung.standard;
  if (roh == null) {
    return null;
  }
  return _kappe(roh.abs(), 0, wirkung.max) * wirkung.jeWert;
}

/// Betrag einer `eigenschaft`-Wirkung fuer [eintrag] (mindestens 1).
int merkmalEigenschaftBetrag(HeroTraitEffect wirkung, HeroMerkmal eintrag) {
  final roh = eintrag.wert?.abs() ?? wirkung.standard ?? 1;
  return _kappe(roh, 1, wirkung.max) * wirkung.jeWert;
}

/// Stufe einer `rast`-Wirkung fuer [eintrag] (mindestens 1).
int merkmalRastStufe(HeroTraitEffect wirkung, HeroMerkmal eintrag) {
  return _kappe(eintrag.wert ?? wirkung.standard ?? 1, 1, wirkung.max);
}

int _kappe(int wert, int minimum, int? maximum) {
  if (wert < minimum) {
    return minimum;
  }
  if (maximum != null && wert > maximum) {
    return maximum;
  }
  return wert;
}

StatModifiers _statMods(String ziel, int betrag) {
  return switch (ziel) {
    'lep' => StatModifiers(lep: betrag),
    'au' => StatModifiers(au: betrag),
    'asp' => StatModifiers(asp: betrag),
    'kap' => StatModifiers(kap: betrag),
    'mr' => StatModifiers(mr: betrag),
    'ini' => StatModifiers(iniBase: betrag),
    'gs' => StatModifiers(gs: betrag),
    'ausweichen' => StatModifiers(ausweichen: betrag),
    _ => const StatModifiers(),
  };
}

List<String> _texte(List<HeroMerkmal> eintraege) {
  return List<String>.unmodifiable(eintraege.map((eintrag) => eintrag.text));
}

// Katalogname (falls bekannt) und gespeicherter Text je Eintrag.
List<String> _namen(
  List<HeroMerkmal> eintraege,
  MerkmalKatalog katalog, {
  required bool vorteil,
}) {
  final namen = <String>[];
  for (final eintrag in eintraege) {
    final def = eintrag.istKatalogisiert
        ? katalog.eintrag(eintrag.katalogId, vorteil: vorteil)
        : null;
    if (def != null) {
      namen.add(
        merkmalTextFuer(def, auswahl: eintrag.auswahl, wert: eintrag.wert),
      );
    }
    namen.add(eintrag.text);
  }
  return List<String>.unmodifiable(namen);
}
