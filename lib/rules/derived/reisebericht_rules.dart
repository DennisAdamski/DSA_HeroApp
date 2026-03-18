import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

// ---------------------------------------------------------------------------
// Kategorie-Definitionen
// ---------------------------------------------------------------------------

/// Alle Reisebericht-Kategorien in Anzeigereihenfolge.
const reiseberichtKategorien = <String, String>{
  'kampferfahrungen': 'Meine Kampferfahrungen',
  'koerperliche_erprobungen': 'Meine körperlichen Erprobungen',
  'gesellschaftliche_erfahrungen': 'Meine gesellschaftlichen Erfahrungen',
  'naturerfahrungen': 'Meine Naturerfahrungen',
  'spirituelle_erfahrungen': 'Meine spirituellen Erfahrungen',
  'magische_erfahrungen': 'Meine magischen Erfahrungen',
};

// ---------------------------------------------------------------------------
// Completion-Checks
// ---------------------------------------------------------------------------

/// Prueft, ob ein einzelner Eintrag (je nach Typ) als abgeschlossen gilt.
bool isReiseberichtEntryComplete(
  ReiseberichtDef def,
  HeroReisebericht state,
  List<ReiseberichtDef> allDefs,
) {
  switch (def.typ) {
    case 'checkpoint':
      return state.checkedIds.contains(def.id);

    case 'multi_requirement':
      return def.anforderungen.every(
        (req) => state.checkedIds.contains(req.id),
      );

    case 'collection_fixed':
      final checked = countFixedCollectionChecked(def, state);
      return checked >= def.festeEintraege.length;

    case 'collection_open':
      if (def.schwelle <= 0) return false;
      final items = state.openEntries[def.id] ?? const [];
      return items.length >= def.schwelle;

    case 'grouped_progression':
      return state.checkedIds.contains(def.id);

    case 'grouped_progression_bonus':
      return _isProgressionGroupComplete(def.gruppeId, state, allDefs);

    case 'meta':
      return _isMetaComplete(def, state, allDefs);

    default:
      return false;
  }
}

/// Zaehlt abgehakte feste Eintraege einer collection_fixed.
int countFixedCollectionChecked(
  ReiseberichtDef def,
  HeroReisebericht state,
) {
  var count = 0;
  for (final eintrag in def.festeEintraege) {
    if (state.checkedIds.contains(eintrag.id)) count++;
  }
  return count;
}

/// Prueft ob die Schwelle einer collection_fixed erreicht ist.
bool isFixedCollectionThresholdMet(
  ReiseberichtDef def,
  HeroReisebericht state,
) {
  if (def.schwelle <= 0) return false;
  return countFixedCollectionChecked(def, state) >= def.schwelle;
}

/// Prueft ob der Bonus einer collection_fixed erreicht ist.
bool isFixedCollectionBonusMet(
  ReiseberichtDef def,
  HeroReisebericht state,
) {
  if (def.bonus == null) return false;
  final bonusSchwelle = def.bonus!.schwelle > 0
      ? def.bonus!.schwelle
      : def.festeEintraege.length;
  return countFixedCollectionChecked(def, state) >= bonusSchwelle;
}

bool _isProgressionGroupComplete(
  String gruppeId,
  HeroReisebericht state,
  List<ReiseberichtDef> allDefs,
) {
  if (gruppeId.isEmpty) return false;
  final stufen = allDefs.where(
    (d) => d.typ == 'grouped_progression' && d.gruppeId == gruppeId,
  );
  return stufen.every((d) => state.checkedIds.contains(d.id));
}

bool _isMetaComplete(
  ReiseberichtDef def,
  HeroReisebericht state,
  List<ReiseberichtDef> allDefs,
) {
  final sameCategory = allDefs.where(
    (d) => d.kategorie == def.kategorie && d.id != def.id && d.typ != 'meta',
  );
  return sameCategory.every(
    (d) => isReiseberichtEntryComplete(d, state, allDefs),
  );
}

// ---------------------------------------------------------------------------
// Reward-Berechnung
// ---------------------------------------------------------------------------

/// Ergebnis einer Reward-Berechnung.
class ReiseberichtRewards {
  const ReiseberichtRewards({
    this.ap = 0,
    this.seRewards = const [],
    this.talentBoni = const [],
    this.eigenschaftsBoni = const [],
    this.newAppliedIds = const {},
  });

  final int ap;
  final List<ReiseberichtSeReward> seRewards;
  final List<ReiseberichtTalentBonus> talentBoni;
  final List<ReiseberichtEigenschaftsBonus> eigenschaftsBoni;
  final Set<String> newAppliedIds;

  bool get isEmpty =>
      ap == 0 &&
      seRewards.isEmpty &&
      talentBoni.isEmpty &&
      eigenschaftsBoni.isEmpty;
}

/// Einzelne SE-Belohnung.
class ReiseberichtSeReward {
  const ReiseberichtSeReward({
    required this.sourceId,
    required this.talentName,
  });
  final String sourceId;
  final String talentName;
}

/// Einzelner Talentbonus.
class ReiseberichtTalentBonus {
  const ReiseberichtTalentBonus({
    required this.sourceId,
    required this.talentName,
    required this.wert,
    required this.beschreibung,
  });
  final String sourceId;
  final String talentName;
  final int wert;
  final String beschreibung;
}

/// Einzelner Eigenschaftsbonus.
class ReiseberichtEigenschaftsBonus {
  const ReiseberichtEigenschaftsBonus({
    required this.sourceId,
    required this.eigenschaft,
    required this.wert,
  });
  final String sourceId;
  final String eigenschaft;
  final int wert;
}

/// Berechnet alle noch nicht angewendeten Belohnungen.
ReiseberichtRewards computePendingRewards({
  required List<ReiseberichtDef> catalog,
  required HeroReisebericht state,
}) {
  var totalAp = 0;
  final seRewards = <ReiseberichtSeReward>[];
  final talentBoni = <ReiseberichtTalentBonus>[];
  final eigenschaftsBoni = <ReiseberichtEigenschaftsBonus>[];
  final newAppliedIds = <String>{};

  for (final def in catalog) {
    switch (def.typ) {
      case 'checkpoint':
        _collectCheckpointRewards(
          def, state, totalAp, seRewards, newAppliedIds,
          (ap) => totalAp += ap,
        );

      case 'multi_requirement':
        for (final req in def.anforderungen) {
          if (state.checkedIds.contains(req.id) &&
              !state.appliedRewardIds.contains(req.id)) {
            totalAp += req.ap;
            _collectSeRewards(req.id, req.se, state, seRewards);
            newAppliedIds.add(req.id);
          }
        }

      case 'collection_fixed':
        _collectFixedCollectionRewards(
          def, state, seRewards, talentBoni, newAppliedIds,
          (ap) => totalAp += ap,
        );

      case 'collection_open':
        _collectOpenCollectionRewards(
          def, state, seRewards, newAppliedIds,
          (ap) => totalAp += ap,
        );

      case 'grouped_progression':
        if (state.checkedIds.contains(def.id) &&
            !state.appliedRewardIds.contains(def.id)) {
          totalAp += def.ap;
          _collectSeRewards(def.id, def.se, state, seRewards);
          newAppliedIds.add(def.id);
        }

      case 'grouped_progression_bonus':
        if (_isProgressionGroupComplete(def.gruppeId, state, catalog) &&
            !state.appliedRewardIds.contains(def.id)) {
          _collectSeRewards(def.id, def.se, state, seRewards);
          newAppliedIds.add(def.id);
        }

      case 'meta':
        if (_isMetaComplete(def, state, catalog) &&
            !state.appliedRewardIds.contains(def.id)) {
          totalAp += def.ap;
          _collectSeRewards(def.id, def.se, state, seRewards);
          for (final eb in def.eigenschaftsBonus) {
            final resolved = _resolveEigenschaft(eb, state, def.id);
            if (resolved != null) eigenschaftsBoni.add(resolved);
          }
          newAppliedIds.add(def.id);
        }
    }
  }

  return ReiseberichtRewards(
    ap: totalAp,
    seRewards: seRewards,
    talentBoni: talentBoni,
    eigenschaftsBoni: eigenschaftsBoni,
    newAppliedIds: newAppliedIds,
  );
}

void _collectCheckpointRewards(
  ReiseberichtDef def,
  HeroReisebericht state,
  int currentAp,
  List<ReiseberichtSeReward> seRewards,
  Set<String> newAppliedIds,
  void Function(int) addAp,
) {
  if (state.checkedIds.contains(def.id) &&
      !state.appliedRewardIds.contains(def.id)) {
    addAp(def.ap);
    _collectSeRewards(def.id, def.se, state, seRewards);
    newAppliedIds.add(def.id);
  }
}

void _collectFixedCollectionRewards(
  ReiseberichtDef def,
  HeroReisebericht state,
  List<ReiseberichtSeReward> seRewards,
  List<ReiseberichtTalentBonus> talentBoni,
  Set<String> newAppliedIds,
  void Function(int) addAp,
) {
  // AP pro abgehaktem Eintrag
  for (final eintrag in def.festeEintraege) {
    if (state.checkedIds.contains(eintrag.id) &&
        !state.appliedRewardIds.contains(eintrag.id)) {
      addAp(def.apProEintrag);
      newAppliedIds.add(eintrag.id);
    }
  }

  // Schwellen-Belohnung
  final schwelleId = '${def.id}_schwelle';
  if (def.schwelleBelohnung != null &&
      isFixedCollectionThresholdMet(def, state) &&
      !state.appliedRewardIds.contains(schwelleId)) {
    addAp(def.schwelleBelohnung!.ap);
    _collectSeRewards(schwelleId, def.schwelleBelohnung!.se, state, seRewards);
    for (final tb in def.schwelleBelohnung!.talentBoni) {
      talentBoni.add(ReiseberichtTalentBonus(
        sourceId: schwelleId,
        talentName: tb.talentName,
        wert: tb.wert,
        beschreibung: 'Reisebericht: ${def.name}',
      ));
    }
    newAppliedIds.add(schwelleId);
  }

  // Bonus (z. B. Stadtkenner extrem)
  if (def.bonus != null) {
    final bonusId = def.bonus!.id.isNotEmpty ? def.bonus!.id : '${def.id}_bonus';
    final bonusSchwelle = def.bonus!.schwelle > 0
        ? def.bonus!.schwelle
        : def.festeEintraege.length;
    if (countFixedCollectionChecked(def, state) >= bonusSchwelle &&
        !state.appliedRewardIds.contains(bonusId)) {
      addAp(def.bonus!.ap);
      _collectSeRewards(bonusId, def.bonus!.se, state, seRewards);
      for (final tb in def.bonus!.talentBoni) {
        talentBoni.add(ReiseberichtTalentBonus(
          sourceId: bonusId,
          talentName: tb.talentName,
          wert: tb.wert,
          beschreibung: 'Reisebericht: ${def.bonus!.name}',
        ));
      }
      newAppliedIds.add(bonusId);
    }
  }
}

void _collectOpenCollectionRewards(
  ReiseberichtDef def,
  HeroReisebericht state,
  List<ReiseberichtSeReward> seRewards,
  Set<String> newAppliedIds,
  void Function(int) addAp,
) {
  final items = state.openEntries[def.id] ?? const [];

  // AP pro Item (mit eigener ID pro Index)
  for (var i = 0; i < items.length; i++) {
    final itemId = '${def.id}_item_$i';
    if (!state.appliedRewardIds.contains(itemId)) {
      final itemAp = items[i].ap > 0 ? items[i].ap : def.apProEintrag;
      addAp(itemAp);
      newAppliedIds.add(itemId);
    }
  }

  // SE-Intervall (alle N Eintraege eine SE)
  if (def.seIntervall > 0 && items.isNotEmpty) {
    final seCount = items.length ~/ def.seIntervall;
    for (var s = 0; s < seCount; s++) {
      final seId = '${def.id}_se_$s';
      if (!state.appliedRewardIds.contains(seId)) {
        _collectSeRewards(seId, def.se, state, seRewards);
        newAppliedIds.add(seId);
      }
    }
  }
}

void _collectSeRewards(
  String sourceId,
  List<ReiseberichtSeDef> seDefs,
  HeroReisebericht state,
  List<ReiseberichtSeReward> rewards,
) {
  for (final se in seDefs) {
    if (se.ziel == 'wahl') {
      // Wahl-SE: Nutze die gespeicherte Zuordnung
      final chosen = state.wahlSeZuordnungen[sourceId];
      if (chosen != null && chosen.isNotEmpty) {
        rewards.add(ReiseberichtSeReward(
          sourceId: sourceId,
          talentName: chosen,
        ));
      }
    } else if (se.ziel == 'talent' || se.ziel == 'grundwert') {
      rewards.add(ReiseberichtSeReward(
        sourceId: sourceId,
        talentName: se.name,
      ));
    }
  }
}

ReiseberichtEigenschaftsBonus? _resolveEigenschaft(
  ReiseberichtEigenschaftsBonusDef eb,
  HeroReisebericht state,
  String defId,
) {
  if (eb.eigenschaft == 'wahl') {
    final chosen = state.wahlSeZuordnungen[defId];
    if (chosen == null || chosen.isEmpty) return null;
    // Versuche Eigenschaftscode aufzuloesen
    final code = _eigenschaftCodeFromName(chosen);
    if (code != null) {
      return ReiseberichtEigenschaftsBonus(
        sourceId: defId,
        eigenschaft: code,
        wert: eb.wert,
      );
    }
    return null;
  }
  return ReiseberichtEigenschaftsBonus(
    sourceId: defId,
    eigenschaft: eb.eigenschaft,
    wert: eb.wert,
  );
}

String? _eigenschaftCodeFromName(String name) {
  switch (name.toUpperCase()) {
    case 'MU': return 'mu';
    case 'KL': return 'kl';
    case 'IN': return 'in';
    case 'CH': return 'ch';
    case 'FF': return 'ff';
    case 'GE': return 'ge';
    case 'KO': return 'ko';
    case 'KK': return 'kk';
    default: return null;
  }
}

// ---------------------------------------------------------------------------
// Reward-Anwendung
// ---------------------------------------------------------------------------

/// Wendet berechnete Belohnungen auf den Helden an.
HeroSheet applyReiseberichtRewards({
  required HeroSheet hero,
  required ReiseberichtRewards rewards,
  required HeroReisebericht updatedState,
}) {
  if (rewards.isEmpty) {
    return hero.copyWith(reisebericht: updatedState);
  }

  var apTotal = hero.apTotal + rewards.ap;
  var talents = Map<String, HeroTalentEntry>.of(hero.talents);
  var attributes = hero.attributes;

  // Talent-SE anwenden
  for (final se in rewards.seRewards) {
    final talentId = _findTalentIdByName(se.talentName, talents);
    if (talentId != null && talents.containsKey(talentId)) {
      final entry = talents[talentId]!;
      talents[talentId] = entry.copyWith(
        specialExperiences: entry.specialExperiences + 1,
      );
    }
  }

  // Talent-Boni anwenden
  for (final tb in rewards.talentBoni) {
    final talentId = _findTalentIdByName(tb.talentName, talents);
    if (talentId != null && talents.containsKey(talentId)) {
      final entry = talents[talentId]!;
      final newModifiers = List<HeroTalentModifier>.of(entry.talentModifiers)
        ..add(HeroTalentModifier(modifier: tb.wert, description: tb.beschreibung));
      talents[talentId] = entry.copyWith(talentModifiers: newModifiers);
    }
  }

  // Eigenschafts-Boni anwenden
  for (final eb in rewards.eigenschaftsBoni) {
    attributes = _applyEigenschaftsBonus(attributes, eb.eigenschaft, eb.wert);
  }

  // appliedRewardIds zusammenfuehren
  final mergedApplied = <String>{
    ...updatedState.appliedRewardIds,
    ...rewards.newAppliedIds,
  };

  return hero.copyWith(
    apTotal: apTotal,
    talents: talents,
    attributes: attributes,
    reisebericht: updatedState.copyWith(appliedRewardIds: mergedApplied),
  );
}

/// Nimmt Belohnungen zurueck (Umkehroperation).
HeroSheet revokeReiseberichtRewards({
  required HeroSheet hero,
  required ReiseberichtRewards rewards,
  required HeroReisebericht updatedState,
}) {
  if (rewards.isEmpty) {
    return hero.copyWith(reisebericht: updatedState);
  }

  var apTotal = hero.apTotal - rewards.ap;
  if (apTotal < 0) apTotal = 0;
  var talents = Map<String, HeroTalentEntry>.of(hero.talents);
  var attributes = hero.attributes;

  // Talent-SE entfernen
  for (final se in rewards.seRewards) {
    final talentId = _findTalentIdByName(se.talentName, talents);
    if (talentId != null && talents.containsKey(talentId)) {
      final entry = talents[talentId]!;
      final newSe = (entry.specialExperiences - 1).clamp(0, 999);
      talents[talentId] = entry.copyWith(specialExperiences: newSe);
    }
  }

  // Talent-Boni entfernen (suche nach passender Beschreibung)
  for (final tb in rewards.talentBoni) {
    final talentId = _findTalentIdByName(tb.talentName, talents);
    if (talentId != null && talents.containsKey(talentId)) {
      final entry = talents[talentId]!;
      final newModifiers = List<HeroTalentModifier>.of(entry.talentModifiers);
      final idx = newModifiers.indexWhere(
        (m) => m.description == tb.beschreibung && m.modifier == tb.wert,
      );
      if (idx >= 0) newModifiers.removeAt(idx);
      talents[talentId] = entry.copyWith(talentModifiers: newModifiers);
    }
  }

  // Eigenschafts-Boni entfernen
  for (final eb in rewards.eigenschaftsBoni) {
    attributes = _applyEigenschaftsBonus(attributes, eb.eigenschaft, -eb.wert);
  }

  // appliedRewardIds bereinigen
  final cleanedApplied = <String>{
    ...updatedState.appliedRewardIds,
  }..removeAll(rewards.newAppliedIds);

  return hero.copyWith(
    apTotal: apTotal,
    talents: talents,
    attributes: attributes,
    reisebericht: updatedState.copyWith(appliedRewardIds: cleanedApplied),
  );
}

// ---------------------------------------------------------------------------
// Revocation-Berechnung fuer Bestaetigungsdialog
// ---------------------------------------------------------------------------

/// Berechnet welche Belohnungen bei Ruecknahme eines Eintrags entfernt wuerden.
ReiseberichtRewards computeRevocationRewards({
  required ReiseberichtDef def,
  required List<ReiseberichtDef> catalog,
  required HeroReisebericht state,
}) {
  // Sammle alle IDs die zu diesem Eintrag gehoeren und applied sind
  final idsToRevoke = <String>{};

  switch (def.typ) {
    case 'checkpoint':
      if (state.appliedRewardIds.contains(def.id)) {
        idsToRevoke.add(def.id);
      }

    case 'multi_requirement':
      for (final req in def.anforderungen) {
        if (state.appliedRewardIds.contains(req.id)) {
          idsToRevoke.add(req.id);
        }
      }

    case 'grouped_progression':
      if (state.appliedRewardIds.contains(def.id)) {
        idsToRevoke.add(def.id);
      }
      // Prüfe ob Gruppen-Bonus betroffen
      final gruppenBonus = catalog.where(
        (d) =>
            d.typ == 'grouped_progression_bonus' &&
            d.gruppeId == def.gruppeId,
      );
      for (final gb in gruppenBonus) {
        if (state.appliedRewardIds.contains(gb.id)) {
          idsToRevoke.add(gb.id);
        }
      }
  }

  if (idsToRevoke.isEmpty) return const ReiseberichtRewards();

  // Berechne die zugehoerigen Rewards
  var totalAp = 0;
  final seRewards = <ReiseberichtSeReward>[];
  final talentBoni = <ReiseberichtTalentBonus>[];
  final eigenschaftsBoni = <ReiseberichtEigenschaftsBonus>[];

  for (final id in idsToRevoke) {
    final matchDef = catalog.where((d) => d.id == id).firstOrNull;
    if (matchDef != null) {
      totalAp += matchDef.ap;
      _collectSeRewards(id, matchDef.se, state, seRewards);
    }
    // Check sub-items
    for (final d in catalog) {
      if (d.typ == 'multi_requirement') {
        for (final req in d.anforderungen) {
          if (req.id == id) {
            totalAp += req.ap;
            _collectSeRewards(id, req.se, state, seRewards);
          }
        }
      }
    }
  }

  return ReiseberichtRewards(
    ap: totalAp,
    seRewards: seRewards,
    talentBoni: talentBoni,
    eigenschaftsBoni: eigenschaftsBoni,
    newAppliedIds: idsToRevoke,
  );
}

// ---------------------------------------------------------------------------
// Hilfsfunktionen
// ---------------------------------------------------------------------------

/// Sucht eine Talent-ID anhand des Anzeigenamens.
String? _findTalentIdByName(
  String talentName,
  Map<String, HeroTalentEntry> talents,
) {
  // Exakte Suche ueber die Keys (die IDs enthalten den Namen normalisiert)
  for (final entry in talents.entries) {
    if (entry.key == talentName) return entry.key;
  }
  // Fallback: Case-insensitive Suche
  final needle = talentName.toLowerCase();
  for (final entry in talents.entries) {
    if (entry.key.toLowerCase() == needle) return entry.key;
  }
  return null;
}

Attributes _applyEigenschaftsBonus(
  Attributes attributes,
  String code,
  int bonus,
) {
  switch (code) {
    case 'mu': return attributes.copyWith(mu: attributes.mu + bonus);
    case 'kl': return attributes.copyWith(kl: attributes.kl + bonus);
    case 'in': return attributes.copyWith(inn: attributes.inn + bonus);
    case 'ch': return attributes.copyWith(ch: attributes.ch + bonus);
    case 'ff': return attributes.copyWith(ff: attributes.ff + bonus);
    case 'ge': return attributes.copyWith(ge: attributes.ge + bonus);
    case 'ko': return attributes.copyWith(ko: attributes.ko + bonus);
    case 'kk': return attributes.copyWith(kk: attributes.kk + bonus);
    default: return attributes;
  }
}
