/// Auswirkung einer Regelprofil-Aktualisierung auf einen Helden (ARCH-04).
///
/// Baut auf dem Katalogvergleich (`regelprofil_vergleich.dart`) auf und
/// beantwortet für einen konkreten Helden zwei Fragen: Welche bereits
/// erworbenen Fähigkeiten stehen nach geänderten Erwerbsvoraussetzungen anders
/// da, und welche erklärbaren Werte (Herleitungen) ändern sich? Beides rechnet
/// mit denselben Regelmodulen wie die Oberfläche; angezeigter und verwendeter
/// Wert sind deshalb dieselben.
///
/// Nichts davon schreibt. Erst [uebernehmeRegelProfil] ändert den Helden, und
/// nur über den Ablauf `RegelProfilUebernehmen`.
library;

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_entry.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung_uebersicht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Wie sich eine geänderte oder entfallene Voraussetzung auf eine Fähigkeit
/// des Helden auswirkt.
enum ErworbenAuswirkung {
  /// Der Held hat die Fähigkeit nicht; die Änderung ist nur eine Information.
  nichtErworben,

  /// Erworben; die offenen Punkte bleiben dieselben.
  unveraendert,

  /// Erworben; mindestens ein Punkt ist nun offen, der es vorher nicht war.
  neuOffen,

  /// Erworben; es sind weniger Punkte offen als vorher.
  nichtMehrOffen,

  /// Erworben, aber der Eintrag fehlt im neuen Katalog.
  entfallen,
}

/// Geänderte Erwerbsvoraussetzung einer Fähigkeit oder eines Manövers.
class VoraussetzungsAenderung {
  /// Bündelt Eintrag, Besitz und Auswirkung.
  const VoraussetzungsAenderung({
    required this.section,
    required this.id,
    required this.name,
    required this.art,
    required this.erworben,
    required this.auswirkung,
    required this.sollVorher,
    required this.sollNachher,
    required this.offeneVorher,
    required this.offeneNachher,
  });

  /// Katalogsektion des Eintrags.
  final CatalogSectionId section;

  /// Stabile Eintrags-ID.
  final String id;

  /// Anzeigename.
  final String name;

  /// [EintragsAenderungsart.geaendert] oder [EintragsAenderungsart.entfernt].
  final EintragsAenderungsart art;

  /// Ob der Held die Fähigkeit oder das Manöver besitzt.
  final bool erworben;

  /// Folge für den Helden.
  final ErworbenAuswirkung auswirkung;

  /// Geforderte Bedingungen im bisherigen Stand (Anzeigetexte).
  final List<String> sollVorher;

  /// Geforderte Bedingungen im vorgeschlagenen Stand.
  final List<String> sollNachher;

  /// Für den Helden offene Punkte im bisherigen Stand; leer, wenn er den
  /// Eintrag nicht besitzt.
  final List<String> offeneVorher;

  /// Für den Helden offene Punkte im vorgeschlagenen Stand.
  final List<String> offeneNachher;
}

/// Ein erklärbarer Wert, der sich durch die Aktualisierung ändert.
class WertAenderung {
  /// Bündelt beide Herleitungen; eine Seite fehlt, wenn der Wert nur auf der
  /// anderen erscheint.
  const WertAenderung({
    required this.id,
    required this.bereich,
    required this.titel,
    required this.vorher,
    required this.nachher,
  });

  /// Stabile Kennung des Werts (siehe `HerleitungsEintrag.id`).
  final String id;

  /// Bereich für die Gruppierung.
  final HerleitungsBereich bereich;

  /// Anzeigename.
  final String titel;

  /// Herleitung im bisherigen Stand; `null`, wenn der Wert neu erscheint.
  final HerleitungsEintrag? vorher;

  /// Herleitung im vorgeschlagenen Stand; `null`, wenn der Wert entfällt.
  final HerleitungsEintrag? nachher;
}

/// Vorschau einer Regelprofil-Aktualisierung für einen Helden.
class RegelProfilVorschau {
  /// Bündelt Katalogvergleich und Heldenauswirkung.
  const RegelProfilVorschau({
    required this.vergleich,
    required this.voraussetzungen,
    required this.werte,
  });

  /// Katalogvergleich beider Profile samt Pakethinweisen.
  final RegelProfilVergleich vergleich;

  /// Geänderte Voraussetzungen, nach Sektion und ID geordnet. Entfallene
  /// Einträge erscheinen nur, wenn der Held sie besitzt.
  final List<VoraussetzungsAenderung> voraussetzungen;

  /// Geänderte Werte des Helden (Herleitung vorher/nachher).
  final List<WertAenderung> werte;

  /// Profil, nach dem der Held heute rechnet.
  HeroRegelProfil get von => vergleich.altesProfil;

  /// Vorgeschlagenes Profil.
  HeroRegelProfil get auf => vergleich.neuesProfil;

  /// Erworbene Fähigkeiten, die nun offene Voraussetzungen haben oder
  /// entfallen.
  List<VoraussetzungsAenderung> get betroffeneErworbene => voraussetzungen
      .where(
        (v) =>
            v.auswirkung == ErworbenAuswirkung.neuOffen ||
            v.auswirkung == ErworbenAuswirkung.entfallen,
      )
      .toList(growable: false);

  /// Ob die Übernahme das Profil des Helden ändern würde.
  bool get uebernehmbar => vergleich.profilGeaendert;

  /// Ob irgendetwas zu zeigen ist.
  bool get istLeer =>
      vergleich.istLeer && voraussetzungen.isEmpty && werte.isEmpty;
}

/// Rechnet die Auswirkung von [vergleich] auf [hero].
///
/// [state] liefert den Laufzeitzustand für die Herleitungen; Werte hängen
/// kaum davon ab, brauchen ihn aber für den Snapshot. [talentBeOverride] ist
/// die situative BE-Anpassung der Talente wie in der Berechnungssuche.
RegelProfilVorschau erstelleRegelProfilVorschau({
  required HeroSheet hero,
  required HeroState state,
  required RegelProfilVergleich vergleich,
  int? talentBeOverride,
}) {
  return RegelProfilVorschau(
    vergleich: vergleich,
    voraussetzungen: List<VoraussetzungsAenderung>.unmodifiable(
      _voraussetzungsAenderungen(hero, vergleich),
    ),
    werte: List<WertAenderung>.unmodifiable(
      _wertAenderungen(hero, state, vergleich, talentBeOverride),
    ),
  );
}

/// Setzt das Regelprofil des frisch geladenen Helden [aktuell] auf [auf].
///
/// [von] ist das Profil, auf dessen Grundlage die Vorschau entstand
/// (`null` = der Held folgte den globalen Einstellungen). Ist das gespeicherte
/// Profil inzwischen ein anderes, wirft die Funktion einen [StateError]: Eine
/// Vorschau, die der Nutzer gesehen hat, darf nie ein fremd geändertes Profil
/// überschreiben. Gleicht [auf] dem gespeicherten Profil, kommt [aktuell]
/// unverändert zurück; es gibt nichts zu speichern.
HeroSheet uebernehmeRegelProfil(
  HeroSheet aktuell, {
  required HeroRegelProfil? von,
  required HeroRegelProfil auf,
}) {
  if (aktuell.regelProfil != von) {
    throw StateError(
      'Das Regelprofil des Helden wurde inzwischen geändert. Bitte die '
      'Vorschau neu öffnen.',
    );
  }
  if (aktuell.regelProfil == auf) {
    return aktuell;
  }
  return aktuell.copyWith(regelProfil: auf);
}

/// Führt das Regelprofil des frisch geladenen Helden [aktuell] zurück auf
/// „folgt den globalen Hausregeln“.
///
/// [von] ist das Profil, das der Nutzer vor sich sah. Ist das gespeicherte
/// Profil inzwischen ein anderes, wirft die Funktion einen [StateError] und
/// schreibt nichts. Hat der Held kein Profil mehr, kommt [aktuell] unverändert
/// zurück. Danach gilt wieder der globale Stand; die Werte können sich ändern.
HeroSheet setzeRegelProfilZurueck(
  HeroSheet aktuell, {
  required HeroRegelProfil von,
}) {
  if (aktuell.regelProfil == null) {
    return aktuell;
  }
  if (aktuell.regelProfil != von) {
    throw StateError(
      'Das Regelprofil des Helden wurde inzwischen geändert. Bitte die '
      'Karte neu öffnen.',
    );
  }
  return aktuell.copyWith(regelProfil: null);
}

// Fähigkeit oder Manöver aus dem typisierten Katalog.
class _Eintrag {
  const _Eintrag({
    required this.name,
    required this.voraussetzungen,
    required this.erworben,
  });

  final String name;
  final List<SpecialAbilityRequirement> voraussetzungen;
  final bool Function(AdvancementContext) erworben;
}

_Eintrag? _suche(RulesCatalog katalog, CatalogSectionId section, String id) {
  final Iterable<SpecialAbilityEntry> faehigkeiten = switch (section) {
    CatalogSectionId.combatSpecialAbilities => katalog.combatSpecialAbilities,
    CatalogSectionId.generalSpecialAbilities => katalog.generalSpecialAbilities,
    CatalogSectionId.magicSpecialAbilities => katalog.magicSpecialAbilities,
    CatalogSectionId.karmalSpecialAbilities => katalog.karmalSpecialAbilities,
    _ => const <SpecialAbilityEntry>[],
  };
  for (final eintrag in faehigkeiten) {
    if (eintrag.id == id) {
      return _Eintrag(
        name: eintrag.name,
        voraussetzungen: eintrag.voraussetzungenStruktur,
        erworben: (kontext) =>
            istEintragErworben(eintrag, kontext.ownedAbilityNames),
      );
    }
  }
  if (section == CatalogSectionId.maneuvers) {
    for (final manoever in katalog.maneuvers) {
      if (manoever.id == id) {
        return _Eintrag(
          name: manoever.name,
          voraussetzungen: manoever.voraussetzungenStruktur,
          erworben: (kontext) => kontext.ownedManeuverIds.any(
            (owned) => owned == id || owned.startsWith('$id::'),
          ),
        );
      }
    }
  }
  return null;
}

const Set<CatalogSectionId> _voraussetzungsSektionen = <CatalogSectionId>{
  CatalogSectionId.combatSpecialAbilities,
  CatalogSectionId.generalSpecialAbilities,
  CatalogSectionId.magicSpecialAbilities,
  CatalogSectionId.karmalSpecialAbilities,
  CatalogSectionId.maneuvers,
};

bool _aendertVoraussetzung(EintragsAenderung aenderung) {
  if (!_voraussetzungsSektionen.contains(aenderung.section)) {
    return false;
  }
  return switch (aenderung.art) {
    EintragsAenderungsart.entfernt => true,
    EintragsAenderungsart.neu => false,
    EintragsAenderungsart.geaendert => aenderung.felder.any(
      (feld) => feld.pfad.startsWith('voraussetzungen_struktur'),
    ),
  };
}

String _offenText(RequirementCheckResult ergebnis) => ergebnis.istText.isEmpty
    ? ergebnis.sollText
    : '${ergebnis.sollText} (${ergebnis.istText})';

List<VoraussetzungsAenderung> _voraussetzungsAenderungen(
  HeroSheet hero,
  RegelProfilVergleich vergleich,
) {
  final betroffen = vergleich.eintraege
      .where(_aendertVoraussetzung)
      .toList(growable: false);
  if (betroffen.isEmpty) {
    return const <VoraussetzungsAenderung>[];
  }
  // Je Seite ein Kontext mit dem Katalog dieser Seite; teuer, deshalb erst
  // bei Bedarf und nur einmal.
  final kontextAlt = AdvancementContext(
    hero: hero,
    catalog: vergleich.alt.katalog,
  );
  final kontextNeu = AdvancementContext(
    hero: hero,
    catalog: vergleich.neu.katalog,
  );

  final ergebnis = <VoraussetzungsAenderung>[];
  for (final aenderung in betroffen) {
    final alt = _suche(vergleich.alt.katalog, aenderung.section, aenderung.id);
    final neu = _suche(vergleich.neu.katalog, aenderung.section, aenderung.id);
    final erworbenAlt = alt?.erworben(kontextAlt) ?? false;
    final erworbenNeu = neu?.erworben(kontextNeu) ?? false;
    final erworben = erworbenAlt || erworbenNeu;
    // Ein entfallener Eintrag, den der Held nicht hat, ist schon als
    // entfernter Katalogeintrag im Vergleich zu sehen.
    if (aenderung.art == EintragsAenderungsart.entfernt && !erworben) {
      continue;
    }

    final prueftAlt = alt == null
        ? const <RequirementCheckResult>[]
        : evaluateRequirements(
            alt.voraussetzungen,
            kontextAlt.requirementContext,
          );
    final prueftNeu = neu == null
        ? const <RequirementCheckResult>[]
        : evaluateRequirements(
            neu.voraussetzungen,
            kontextNeu.requirementContext,
          );
    final offeneVorher = erworben
        ? prueftAlt.where((r) => r.istOffen).map(_offenText).toList()
        : const <String>[];
    final offeneNachher = erworben
        ? prueftNeu.where((r) => r.istOffen).map(_offenText).toList()
        : const <String>[];
    final offenAlt = <String>{
      for (final r in prueftAlt.where((r) => r.istOffen)) r.sollText,
    };
    final offenNeu = <String>{
      for (final r in prueftNeu.where((r) => r.istOffen)) r.sollText,
    };

    final ErworbenAuswirkung auswirkung;
    if (!erworben) {
      auswirkung = ErworbenAuswirkung.nichtErworben;
    } else if (neu == null) {
      auswirkung = ErworbenAuswirkung.entfallen;
    } else if (offenNeu.difference(offenAlt).isNotEmpty) {
      auswirkung = ErworbenAuswirkung.neuOffen;
    } else if (offenAlt.difference(offenNeu).isNotEmpty) {
      auswirkung = ErworbenAuswirkung.nichtMehrOffen;
    } else {
      auswirkung = ErworbenAuswirkung.unveraendert;
    }
    ergebnis.add(
      VoraussetzungsAenderung(
        section: aenderung.section,
        id: aenderung.id,
        name: aenderung.name,
        art: aenderung.art,
        erworben: erworben,
        auswirkung: auswirkung,
        sollVorher: List<String>.unmodifiable(prueftAlt.map((r) => r.sollText)),
        sollNachher: List<String>.unmodifiable(
          prueftNeu.map((r) => r.sollText),
        ),
        offeneVorher: List<String>.unmodifiable(offeneVorher),
        offeneNachher: List<String>.unmodifiable(offeneNachher),
      ),
    );
  }
  return ergebnis;
}

List<HerleitungsEintrag> _herleitungen(
  HeroSheet hero,
  HeroState state,
  RegelProfilAufloesung aufloesung,
  int? talentBeOverride,
) {
  // Wie `heroEpicAdvantagesActiveProvider`: nach den wirksamen Paketen des
  // Profils samt Elternkette.
  final epic = aufloesung.aktivePaketIds.contains(EpicRuleKeys.advantages);
  final snapshot = buildHeroComputedSnapshot(
    hero: hero,
    state: state,
    catalog: aufloesung.katalog,
    epicAdvantagesActive: epic,
  );
  return sammleHerleitungenAusSnapshot(
    snapshot,
    katalog: aufloesung.katalog,
    talentBeOverride: talentBeOverride,
    epicAdvantagesActive: epic,
  );
}

List<WertAenderung> _wertAenderungen(
  HeroSheet hero,
  HeroState state,
  RegelProfilVergleich vergleich,
  int? talentBeOverride,
) {
  final vorher = {
    for (final e in _herleitungen(hero, state, vergleich.alt, talentBeOverride))
      e.id: e,
  };
  final nachher = {
    for (final e in _herleitungen(hero, state, vergleich.neu, talentBeOverride))
      e.id: e,
  };
  final ids = <String>[
    ...nachher.keys,
    ...vorher.keys.where((id) => !nachher.containsKey(id)),
  ];
  final ergebnis = <WertAenderung>[];
  for (final id in ids) {
    final a = vorher[id];
    final n = nachher[id];
    if (a != null && n != null && a.ergebnisText == n.ergebnisText) {
      continue;
    }
    final eintrag = (n ?? a)!;
    ergebnis.add(
      WertAenderung(
        id: id,
        bereich: eintrag.bereich,
        titel: eintrag.titel,
        vorher: a,
        nachher: n,
      ),
    );
  }
  return ergebnis;
}
