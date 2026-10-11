import 'package:dsa_heldenverwaltung/catalog/combat_special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/maneuver_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';

import 'advancement_options.dart';
import 'advancement_skill_tree.dart';

/// Oberste Gliederung des Fähigkeitenbaums. Die Namen entsprechen den
/// Kategorien der Knoten im [AdvancementSkillTree].
enum FaehigkeitenBereich {
  kampf('Kampf'),
  allgemein('Allgemein'),
  magie('Magie'),
  karma('Karma');

  const FaehigkeitenBereich(this.label);
  final String label;
}

/// Thematische Gruppe innerhalb eines Bereichs. Die Reihenfolge der Werte ist
/// die Anzeigereihenfolge und löst Gleichstände bei gemischten Zweigen.
enum FaehigkeitenGruppe {
  kampfGrundlagen('Grundlagen', FaehigkeitenBereich.kampf),
  kampfKetten('Ausweichen, Rüstung & Schild', FaehigkeitenBereich.kampf),
  kampfWaffenmanoever('Waffenmanöver', FaehigkeitenBereich.kampf),
  kampfWaffenlosManoever('Waffenlose Manöver', FaehigkeitenBereich.kampf),
  kampfStile('Kampfstile', FaehigkeitenBereich.kampf),
  kampfMeister('Waffenmeister & Spezialisierung', FaehigkeitenBereich.kampf),
  kampfFernkampf('Fernkampf', FaehigkeitenBereich.kampf),
  kampfSpezial('Spezialkampf', FaehigkeitenBereich.kampf),
  kampfEpisch('Epische Kampffähigkeiten', FaehigkeitenBereich.kampf),
  allgemeinPraxis('Allgemeine Fähigkeiten', FaehigkeitenBereich.allgemein),
  allgemeinEpisch('Epische Fähigkeiten', FaehigkeitenBereich.allgemein),
  magieTraditionen('Traditionen & Rituale', FaehigkeitenBereich.magie),
  magieWerkstatt('Zauberwerkstatt & Thaumaturgie', FaehigkeitenBereich.magie),
  magieBeschwoerung('Beschwörung & Verbotenes', FaehigkeitenBereich.magie),
  magiePraxis('Zauberpraxis', FaehigkeitenBereich.magie),
  magieWeitere('Weitere Magie', FaehigkeitenBereich.magie),
  magieEpisch('Epische Magie', FaehigkeitenBereich.magie),
  karmaPfad('Pfad der Erleuchteten', FaehigkeitenBereich.karma),
  karmaLiturgien('Liturgien', FaehigkeitenBereich.karma),
  karmaGrundlagen('Karmale Grundlagen', FaehigkeitenBereich.karma),
  karmaEpisch('Epische Karmafähigkeiten', FaehigkeitenBereich.karma);

  const FaehigkeitenGruppe(this.label, this.bereich);
  final String label;
  final FaehigkeitenBereich bereich;
}

/// Kampf-SF ohne eigene Katalogkategorie, die für Sondersituationen gelten.
const _spezialkampf = {
  'reiterkampf',
  'kriegsreiterei',
  'turnierreiterei',
  'kampf im wasser',
  'unterwasserkampf',
  'tierkampf',
  'haeuserkaempfer',
};

/// Fernkampf-SF der Hausregel-Pakete, die kein `kampfTyp` tragen.
const _fernkampfFaehigkeiten = {
  'pfeilhagel',
  'handmagazin',
  'nahkampfschuetze',
};

/// Waffenmeister und Spezialisierung sind im Katalog generische Einträge.
const _meisterNamen = {'waffenmeister', 'waffenspezialisierung'};

const _magieTraditionen = {
  'traditionsrituale',
  'traditionsartefakt',
  'elfenmagie',
  'runenmagie',
  'schelmenmagie',
  'kraftlinienmagie',
  'elementarmagie',
  'traummagie',
  'meditationstanz',
  'repraesentation',
  'merkmalskenntnis',
};
const _magieWerkstatt = {'zauberwerkstatt', 'thaumaturgie'};
const _magieBeschwoerung = {'beschwoerung', 'verbotene magie', 'ritual'};
const _magiePraxis = {'regeneration', 'geistestechnik', 'tarnung', 'hellsicht'};

/// Kleinschreibung ohne Umlaute, damit Katalogschreibweisen unerheblich sind.
String _norm(String text) => text
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss');

/// Ordnet eine Fähigkeitsoption ihrer Gruppe zu. Unbekannte oder fehlende
/// Katalogangaben landen immer in der letzten Sammelgruppe ihres Bereichs.
FaehigkeitenGruppe faehigkeitenGruppeFuer(AdvancementOption option) {
  final ability = option.ability;
  switch (option.kind) {
    case AdvancementKind.maneuver:
      final gruppe = ability is ManeuverDef ? _norm(ability.gruppe) : '';
      return switch (gruppe) {
        'waffenlos' => FaehigkeitenGruppe.kampfWaffenlosManoever,
        'fernkampf' => FaehigkeitenGruppe.kampfFernkampf,
        _ => FaehigkeitenGruppe.kampfWaffenmanoever,
      };
    case AdvancementKind.combatAbility:
      return _kampfGruppe(option, ability);
    case AdvancementKind.magicAbility:
      return _magieGruppe(ability);
    case AdvancementKind.karmalAbility:
      return _karmaGruppe(ability);
    default:
      return ability?.nurEpisch == true
          ? FaehigkeitenGruppe.allgemeinEpisch
          : FaehigkeitenGruppe.allgemeinPraxis;
  }
}

FaehigkeitenGruppe _kampfGruppe(AdvancementOption option, Object? ability) {
  final name = _norm(option.label);
  if (ability is! CombatSpecialAbilityDef) {
    return FaehigkeitenGruppe.kampfGrundlagen;
  }
  final kategorie = _norm(ability.kategorie);
  if (ability.kette != null) return FaehigkeitenGruppe.kampfKetten;
  if (_meisterNamen.contains(name) ||
      ability.kampfTyp == 'grossmeister' ||
      kategorie == 'allgemeine waffenmeisterschaft') {
    return FaehigkeitenGruppe.kampfMeister;
  }
  if (ability.isUnarmedCombatStyle || kategorie == 'waffenloser kampfstil') {
    return FaehigkeitenGruppe.kampfStile;
  }
  if (_fernkampfFaehigkeiten.contains(name)) {
    return FaehigkeitenGruppe.kampfFernkampf;
  }
  if (ability.nurEpisch) return FaehigkeitenGruppe.kampfEpisch;
  if (_spezialkampf.contains(name)) return FaehigkeitenGruppe.kampfSpezial;
  return FaehigkeitenGruppe.kampfGrundlagen;
}

FaehigkeitenGruppe _magieGruppe(Object? ability) {
  if (ability is! SpecialAbilityDef) return FaehigkeitenGruppe.magieWeitere;
  if (ability.nurEpisch) return FaehigkeitenGruppe.magieEpisch;
  final kategorie = _norm(ability.kategorie);
  if (_magieTraditionen.contains(kategorie)) {
    return FaehigkeitenGruppe.magieTraditionen;
  }
  if (_magieWerkstatt.contains(kategorie)) {
    return FaehigkeitenGruppe.magieWerkstatt;
  }
  if (_magieBeschwoerung.contains(kategorie)) {
    return FaehigkeitenGruppe.magieBeschwoerung;
  }
  if (_magiePraxis.contains(kategorie)) return FaehigkeitenGruppe.magiePraxis;
  return FaehigkeitenGruppe.magieWeitere;
}

FaehigkeitenGruppe _karmaGruppe(Object? ability) {
  if (ability is! SpecialAbilityDef) return FaehigkeitenGruppe.karmaGrundlagen;
  final kategorie = _norm(ability.kategorie);
  if (ability.typ == 'pfad_der_erleuchteten' ||
      kategorie == 'pfad der erleuchteten') {
    return FaehigkeitenGruppe.karmaPfad;
  }
  if (ability.typ == 'liturgie' || kategorie.endsWith('liturgie')) {
    return FaehigkeitenGruppe.karmaLiturgien;
  }
  if (ability.nurEpisch) return FaehigkeitenGruppe.karmaEpisch;
  return FaehigkeitenGruppe.karmaGrundlagen;
}

/// Inhalt einer Gruppe: zusammenhängende Zweige und freistehende Einträge.
class FaehigkeitenGruppeInhalt {
  /// Fasst die Knoten-IDs zusammen, die dieser Gruppe zugeordnet wurden.
  const FaehigkeitenGruppeInhalt({
    required this.zweige,
    required this.einzelne,
    required this.anzahl,
    required this.erworben,
  });

  /// Zweige mit mindestens einer Verknüpfung, alphabetisch.
  final List<List<String>> zweige;

  /// Knoten ohne Vor- oder Nachstufe, alphabetisch.
  final List<String> einzelne;

  /// Zahl der echten Fähigkeiten (ohne ODER-/UND-Knoten).
  final int anzahl;

  /// Davon bereits erworben oder vorgemerkt.
  final int erworben;
}

/// Verteilt die Fähigkeiten des Baums auf ihre Gruppen und bildet darin die
/// Zweige.
///
/// Jeder Knoten gehört nach [faehigkeitenGruppeFuer] genau einer Gruppe. Das
/// Voraussetzungsnetz des Kampfs hängt als Ganzes zusammen (Ausweichen II
/// verlangt Aufmerksamkeit, Doppelangriff den Beidhändigen Kampf …); eine
/// Zuordnung ganzer Zusammenhänge würde daher fast alles in eine Gruppe ziehen.
/// Ein Zweig besteht deshalb aus den Knoten **einer** Gruppe, die über
/// Voraussetzungen innerhalb der Gruppe zusammenhängen. Voraussetzungen aus
/// anderen Gruppen bleiben in den Erwerbsdetails und im Status sichtbar.
///
/// ODER-/UND- und Textknoten folgen der Gruppe ihres Ziels und entfallen, wenn
/// keine ihrer Voraussetzungen in dieser Gruppe liegt.
///
/// [query] und [bereich] wählen Zweige, in denen mindestens ein Knoten passt;
/// der ganze Zweig bleibt dabei als Zusammenhang sichtbar. [nurErlernbar]
/// behält Zweige mit mindestens einem erlernbaren Knoten.
Map<FaehigkeitenGruppe, FaehigkeitenGruppeInhalt> gruppiereFaehigkeiten({
  required AdvancementSkillTree graph,
  String query = '',
  FaehigkeitenBereich? bereich,
  bool nurErlernbar = false,
}) {
  final gruppeVon = <String, FaehigkeitenGruppe>{};
  for (final node in graph.nodes.values) {
    final option = node.option;
    if (option != null) gruppeVon[node.id] = faehigkeitenGruppeFuer(option);
  }
  final kinder = <String, List<String>>{};
  final eltern = <String, List<String>>{};
  for (final edge in graph.edges) {
    (kinder[edge.from] ??= []).add(edge.to);
    (eltern[edge.to] ??= []).add(edge.from);
  }
  // Knoten ohne eigene Option erben die Gruppe des nächsten echten Ziels.
  FaehigkeitenGruppe? zielGruppe(String id, Set<String> besucht) {
    final bekannt = gruppeVon[id];
    if (bekannt != null) return bekannt;
    if (!besucht.add(id)) return null;
    for (final kind in kinder[id] ?? const <String>[]) {
      final gruppe = zielGruppe(kind, besucht);
      if (gruppe != null) return gruppe;
    }
    return null;
  }

  final mitglieder = <FaehigkeitenGruppe, Set<String>>{};
  for (final id in graph.nodes.keys) {
    final gruppe = zielGruppe(id, <String>{});
    if (gruppe == null) continue;
    gruppeVon[id] = gruppe;
    (mitglieder[gruppe] ??= {}).add(id);
  }

  final result = <FaehigkeitenGruppe, FaehigkeitenGruppeInhalt>{};
  final suche = query.toLowerCase();
  for (final gruppe in FaehigkeitenGruppe.values) {
    final alle = mitglieder[gruppe];
    if (alle == null || (bereich != null && gruppe.bereich != bereich)) {
      continue;
    }
    final behalten = {...alle};
    // Verknüpfungsknoten ohne Voraussetzung in dieser Gruppe wären lose Enden.
    var geaendert = true;
    while (geaendert) {
      geaendert = false;
      for (final id in behalten.toList()) {
        if (graph.nodes[id]!.option != null) continue;
        final vorgaenger = eltern[id] ?? const <String>[];
        if (vorgaenger.isNotEmpty && !vorgaenger.any(behalten.contains)) {
          behalten.remove(id);
          geaendert = true;
        }
      }
    }
    final nachbarn = <String, Set<String>>{
      for (final id in behalten) id: <String>{},
    };
    for (final edge in graph.edges) {
      if (behalten.contains(edge.from) && behalten.contains(edge.to)) {
        nachbarn[edge.from]!.add(edge.to);
        nachbarn[edge.to]!.add(edge.from);
      }
    }
    final offen = {...behalten};
    final zweige = <List<String>>[];
    final einzelne = <String>[];
    var anzahl = 0;
    var erworben = 0;
    while (offen.isNotEmpty) {
      final zeiger = [offen.first];
      final zusammenhang = <String>[];
      while (zeiger.isNotEmpty) {
        final id = zeiger.removeLast();
        if (!offen.remove(id)) continue;
        zusammenhang.add(id);
        zeiger.addAll(nachbarn[id]!);
      }
      final echte = [
        for (final id in zusammenhang)
          if (graph.nodes[id]!.option != null) graph.nodes[id]!,
      ];
      if (echte.isEmpty) continue;
      if (!echte.any((n) => n.label.toLowerCase().contains(suche))) continue;
      if (nurErlernbar &&
          !echte.any((n) => n.status == SkillTreeStatus.available)) {
        continue;
      }
      anzahl += echte.length;
      erworben += echte
          .where(
            (n) =>
                n.status == SkillTreeStatus.owned ||
                n.status == SkillTreeStatus.planned,
          )
          .length;
      if (zusammenhang.length == 1) {
        einzelne.add(zusammenhang.single);
      } else {
        zweige.add(zusammenhang);
      }
    }
    if (anzahl == 0) continue;
    String name(String id) => graph.nodes[id]!.label.toLowerCase();
    String zweigName(List<String> ids) =>
        (ids.where((id) => graph.nodes[id]!.option != null).map(name).toList()
              ..sort())
            .first;
    zweige.sort((a, b) => zweigName(a).compareTo(zweigName(b)));
    einzelne.sort((a, b) => name(a).compareTo(name(b)));
    result[gruppe] = FaehigkeitenGruppeInhalt(
      zweige: zweige,
      einzelne: einzelne,
      anzahl: anzahl,
      erworben: erworben,
    );
  }
  return result;
}
