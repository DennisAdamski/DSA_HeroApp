/// Begabungen und Unfaehigkeiten aus Vor-/Nachteilen und ihre Ziele.
///
/// Katalogisierte Eintraege mit einer `lernspalte`-Wirkung verschieben die
/// Steigerungsspalte ihrer Ziele: ein Talent, eine Talentgruppe, alle Nah-
/// bzw. Fernkampftalente, Sprachen oder Schriften, einen Zauber, alle Zauber
/// mit einem Merkmal oder die Ritualkenntnis einer Tradition. Abgeleitet wird
/// zur Laufzeit; gespeichert wird nichts am Ziel, das manuelle
/// Begabungs-Haekchen (`gifted`) bleibt daneben bestehen.
///
/// Zaehlweise:
/// - Talent-, Gruppen-, Kampfart- und Zauber-Begabung wirken wie das Haekchen:
///   zusammen hoechstens eine Spalte guenstiger und Maximum +5.
/// - Merkmals-Begabungen zaehlen je passendem Merkmal eines Zaubers eine
///   weitere Spalte; Merkmals-Unfaehigkeiten spiegelbildlich.
/// - Uebrige Unfaehigkeiten verteuern zusammen hoechstens eine Spalte und
///   aendern das Maximum nicht.
///
/// Freie oder mehrdeutige Texte wirken nicht: der Textweg kennt keine
/// Lernspalten. Erst die Zuordnung zum Katalog schaltet die Wirkung frei.
library;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals/hero_ritual_category.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ritual_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Begabungen und Unfaehigkeiten, die auf ein einzelnes Ziel wirken.
class LernspaltenBefund {
  /// Erstellt einen Befund; ohne Angaben wirkt nichts.
  const LernspaltenBefund({
    this.begabungen = const <String>[],
    this.zusatzBegabungen = const <String>[],
    this.unfaehigkeiten = const <String>[],
    this.zusatzUnfaehigkeiten = const <String>[],
  });

  /// Befund ohne Wirkung.
  static const LernspaltenBefund keiner = LernspaltenBefund();

  /// Quellen, die wie das Begabungs-Haekchen wirken (gemeinsam eine Spalte).
  final List<String> begabungen;

  /// Quellen, die je Treffer eine weitere Spalte geben (Merkmale).
  final List<String> zusatzBegabungen;

  /// Unfaehigkeiten, die gemeinsam eine Spalte verteuern.
  final List<String> unfaehigkeiten;

  /// Unfaehigkeiten, die je Treffer eine Spalte verteuern (Merkmale).
  final List<String> zusatzUnfaehigkeiten;

  /// Ob eine Begabung aus Vor-/Nachteilen greift.
  bool get abgeleitetBegabt =>
      begabungen.isNotEmpty || zusatzBegabungen.isNotEmpty;

  /// Ob eine Unfaehigkeit greift.
  bool get unfaehig =>
      unfaehigkeiten.isNotEmpty || zusatzUnfaehigkeiten.isNotEmpty;

  /// Ob irgendetwas wirkt.
  bool get wirkt => abgeleitetBegabt || unfaehig;

  /// Alle Begabungsquellen fuer Hinweise.
  List<String> get begabungsQuellen =>
      List<String>.unmodifiable(<String>[...begabungen, ...zusatzBegabungen]);

  /// Alle Unfaehigkeitsquellen fuer Hinweise.
  List<String> get unfaehigkeitsQuellen => List<String>.unmodifiable(<String>[
    ...unfaehigkeiten,
    ...zusatzUnfaehigkeiten,
  ]);

  /// Effektive Begabung fuer das Maximum, zusammen mit dem Haekchen.
  bool istBegabt({required bool gifted}) => gifted || abgeleitetBegabt;

  /// Spalten guenstiger, zusammen mit dem Haekchen.
  int reduktion({required bool gifted}) =>
      (gifted || begabungen.isNotEmpty ? 1 : 0) + zusatzBegabungen.length;

  /// Spalten teurer.
  int get erhoehung =>
      (unfaehigkeiten.isNotEmpty ? 1 : 0) + zusatzUnfaehigkeiten.length;
}

/// Begabungen und Unfaehigkeiten eines Helden, nach Zielart vorsortiert.
class HeroBegabungen {
  HeroBegabungen._(this._wirkungen, this._catalog);

  /// Ohne Wirkungen (kein Katalog oder keine passenden Merkmale).
  static final HeroBegabungen leer = HeroBegabungen._(
    const <LernspaltenWirkung>[],
    null,
  );

  final List<LernspaltenWirkung> _wirkungen;
  final RulesCatalog? _catalog;

  /// Ob ueberhaupt eine Begabung oder Unfaehigkeit vorliegt.
  bool get istLeer => _wirkungen.isEmpty;

  /// Befund fuer ein Talent (einschliesslich Kampftalente).
  LernspaltenBefund talent(TalentDef def) {
    if (_wirkungen.isEmpty) {
      return LernspaltenBefund.keiner;
    }
    final name = _schluessel(def.name);
    final gruppe = _schluessel(def.group);
    final typ = _schluessel(def.type);
    return _befund(
      (wirkung) => switch (wirkung.ziel) {
        'talent' => _schluessel(wirkung.auswahl) == name,
        'talentgruppe' => _schluessel(wirkung.auswahl) == gruppe,
        'nahkampf' => typ == 'nahkampf',
        'fernkampf' => typ == 'fernkampf',
        _ => false,
      },
    );
  }

  /// Befund fuer einen Zauber; Merkmale zaehlen je Treffer.
  LernspaltenBefund zauber(SpellDef def) {
    if (_wirkungen.isEmpty) {
      return LernspaltenBefund.keiner;
    }
    final name = _schluessel(def.name);
    final merkmale = parseSpellTraits(def.traits).map(_schluessel).toSet();
    final begabungen = <String>[];
    final zusatzBegabungen = <String>[];
    final unfaehigkeiten = <String>[];
    final zusatzUnfaehigkeiten = <String>[];
    for (final wirkung in _wirkungen) {
      final auswahl = _schluessel(wirkung.auswahl);
      final passtMerkmal =
          wirkung.ziel == 'merkmal' && merkmale.contains(auswahl);
      final passtZauber = wirkung.ziel == 'zauber' && auswahl == name;
      if (!passtMerkmal && !passtZauber) {
        continue;
      }
      if (wirkung.betrag > 0) {
        (passtMerkmal ? zusatzBegabungen : begabungen).add(wirkung.quelle);
      } else {
        (passtMerkmal ? zusatzUnfaehigkeiten : unfaehigkeiten).add(
          wirkung.quelle,
        );
      }
    }
    return LernspaltenBefund(
      begabungen: List<String>.unmodifiable(begabungen),
      zusatzBegabungen: List<String>.unmodifiable(zusatzBegabungen),
      unfaehigkeiten: List<String>.unmodifiable(unfaehigkeiten),
      zusatzUnfaehigkeiten: List<String>.unmodifiable(zusatzUnfaehigkeiten),
    );
  }

  /// Befund fuer alle Sprachen.
  LernspaltenBefund sprachen() => _sprachgruppe('sprachen');

  /// Befund fuer alle Schriften.
  LernspaltenBefund schriften() => _sprachgruppe('schriften');

  LernspaltenBefund _sprachgruppe(String gruppe) {
    if (_wirkungen.isEmpty) {
      return LernspaltenBefund.keiner;
    }
    return _befund(
      (wirkung) => switch (wirkung.ziel) {
        'sprachen' => gruppe == 'sprachen',
        'sprachgruppe' ||
        'talentgruppe' => _schluessel(wirkung.auswahl) == gruppe,
        _ => false,
      },
    );
  }

  /// Befund fuer die Ritualkenntnis einer Ritualkategorie des Helden.
  ///
  /// Ein begabtes Ritual gehoert zu der Kategorie, die es fuehrt, oder deren
  /// Name der Traditionsritual-Sonderfertigkeit mit diesem Ritual entspricht.
  LernspaltenBefund ritualkenntnis(HeroRitualCategory kategorie) {
    if (_wirkungen.isEmpty) {
      return LernspaltenBefund.keiner;
    }
    final gefuehrt = <String>{
      for (final ritual in kategorie.rituals) _schluessel(ritual.name),
    };
    final kategorieName = _ohneKuerzel(kategorie.name);
    return _befund((wirkung) {
      if (wirkung.ziel != 'ritual') {
        return false;
      }
      final ritual = _schluessel(wirkung.auswahl);
      if (ritual.isEmpty) {
        return false;
      }
      if (gefuehrt.contains(ritual)) {
        return true;
      }
      return kategorieName.isNotEmpty &&
          _ritualgruppenVon(ritual).contains(kategorieName);
    });
  }

  /// Begabungsquellen fuer ein einzelnes Ritual (Marke in der Liste).
  List<String> ritualBegabungen(String ritualName) {
    final ritual = _schluessel(ritualName);
    if (ritual.isEmpty) {
      return const <String>[];
    }
    return List<String>.unmodifiable(<String>[
      for (final wirkung in _wirkungen)
        if (wirkung.ziel == 'ritual' &&
            wirkung.betrag > 0 &&
            _schluessel(wirkung.auswahl) == ritual)
          wirkung.quelle,
    ]);
  }

  // Namen (ohne Kuerzel) der Traditionsritual-Gruppen mit diesem Ritual.
  Set<String> _ritualgruppenVon(String ritual) {
    final catalog = _catalog;
    if (catalog == null) {
      return const <String>{};
    }
    return <String>{
      for (final ability in catalog.magicSpecialAbilities)
        if (_schluessel(ability.kategorie) == 'traditionsrituale' &&
            ability.alleVarianten.any((v) => _schluessel(v) == ritual))
          _ohneKuerzel(ability.name),
    };
  }

  LernspaltenBefund _befund(bool Function(LernspaltenWirkung) passt) {
    final begabungen = <String>[];
    final unfaehigkeiten = <String>[];
    for (final wirkung in _wirkungen) {
      if (!passt(wirkung)) {
        continue;
      }
      (wirkung.betrag > 0 ? begabungen : unfaehigkeiten).add(wirkung.quelle);
    }
    if (begabungen.isEmpty && unfaehigkeiten.isEmpty) {
      return LernspaltenBefund.keiner;
    }
    return LernspaltenBefund(
      begabungen: List<String>.unmodifiable(begabungen),
      unfaehigkeiten: List<String>.unmodifiable(unfaehigkeiten),
    );
  }
}

/// Begabungen und Unfaehigkeiten von [hero].
///
/// Ohne [catalog] wirkt nichts (der Textweg kennt keine Lernspalten). Das
/// Ergebnis wird je Held und Katalog gemerkt; Optionsaufbau und Tabellen
/// fragen es fuer jedes Ziel ab.
HeroBegabungen ermittleBegabungen(
  HeroSheet hero, {
  required RulesCatalog? catalog,
}) {
  if (catalog == null) {
    return HeroBegabungen.leer;
  }
  final gemerkt = _begabungen[hero];
  if (gemerkt != null && identical(gemerkt.catalog, catalog)) {
    return gemerkt.begabungen;
  }
  final wirkungen = werteMerkmaleAus(
    hero,
    catalog: catalog,
  ).wirkungen.lernspalten;
  final begabungen = wirkungen.isEmpty
      ? HeroBegabungen.leer
      : HeroBegabungen._(wirkungen, catalog);
  _begabungen[hero] = (catalog: catalog, begabungen: begabungen);
  return begabungen;
}

final Expando<({RulesCatalog catalog, HeroBegabungen begabungen})> _begabungen =
    Expando<({RulesCatalog catalog, HeroBegabungen begabungen})>();

/// Effektive Lernkomplexitaet einer eigenen Ritualkenntnis.
///
/// Wie bei Talenten: erst verteuern, dann um hoechstens eine Spalte
/// verbilligen. Ritualkenntnisse kennen kein `A*`; `A` ist die Untergrenze.
String effektiveRitualkenntnisKomplexitaet({
  required String basisKomplexitaet,
  required LernspaltenBefund befund,
}) {
  final ergebnis = effectiveTalentLernkomplexitaet(
    basisKomplexitaet: basisKomplexitaet,
    gifted: befund.begabungen.isNotEmpty,
    unfaehigkeitsSchritte: befund.erhoehung,
  );
  if (!kRitualKnowledgeComplexities.contains(ergebnis)) {
    return ergebnis == 'A*' ? 'A' : basisKomplexitaet;
  }
  return ergebnis;
}

String _schluessel(String text) => normalizeSpecialAbilityName(text);

// Name ohne Kuerzel in Klammern und Stern: `Stabzauber (OR)*` → `stabzauber`.
String _ohneKuerzel(String name) {
  return _schluessel(
    name.replaceAll('*', '').replaceAll(RegExp(r'\([^)]*\)'), ''),
  );
}
