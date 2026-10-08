import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_ap_rules.dart';

// ---------------------------------------------------------------------------
// Kategorie-Definitionen
// ---------------------------------------------------------------------------

/// Alle Reisebericht-Kategorien in Anzeigereihenfolge.
const reiseberichtKategorien = <String, String>{
  'kampferfahrungen': 'Kampferfahrung',
  'koerperliche_erprobungen': 'Körperliche Erprobung',
  'gesellschaftliche_erfahrungen': 'Gesellschaftliche Erfahrungen',
  'naturerfahrungen': 'Naturerfahrungen',
  'spirituelle_erfahrungen': 'Spirituelle Erfahrungen',
  'magische_erfahrungen': 'Magische Erfahrungen',
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
int countFixedCollectionChecked(ReiseberichtDef def, HeroReisebericht state) {
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
bool isFixedCollectionBonusMet(ReiseberichtDef def, HeroReisebericht state) {
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
///
/// Gebucht wird jeder Posten, dessen Bedingung in [state] erfüllt ist und
/// dessen ID noch nicht unter den angewendeten Belohnungen steht.
ReiseberichtRewards computePendingRewards({
  required List<ReiseberichtDef> catalog,
  required HeroReisebericht state,
}) {
  return _summe(
    _buchungsposten(catalog, state).where(
      (posten) =>
          posten.erfuellt && !state.appliedRewardIds.contains(posten.id),
    ),
  );
}

// ---------------------------------------------------------------------------
// Buchungsabgleich: neu buchen und zurücknehmen
// ---------------------------------------------------------------------------

/// Was ein Reisebericht-Entwurf am gebuchten Stand ändert.
class ReiseberichtBuchung {
  /// Erstellt den Abgleich.
  const ReiseberichtBuchung({
    this.neu = const ReiseberichtRewards(),
    this.zurueck = const ReiseberichtRewards(),
  });

  /// Neu zu buchende Belohnungen; [ReiseberichtRewards.newAppliedIds] sind
  /// die neu angewendeten IDs.
  final ReiseberichtRewards neu;

  /// Zurückzunehmende Belohnungen; [ReiseberichtRewards.newAppliedIds] sind
  /// die IDs, die aus den angewendeten Belohnungen entfallen.
  final ReiseberichtRewards zurueck;

  /// Ob der Entwurf am gebuchten Stand nichts ändert.
  bool get istLeer =>
      neu.isEmpty &&
      neu.newAppliedIds.isEmpty &&
      zurueck.isEmpty &&
      zurueck.newAppliedIds.isEmpty;
}

/// Gleicht den Reisebericht-[entwurf] mit dem gebuchten Stand [gebucht] ab.
///
/// Neu gebucht wird jeder Posten, der im Entwurf erfüllt und noch nicht
/// angewendet ist. Zurückgenommen wird jeder angewendete Posten, der in
/// [gebucht] erfüllt war und es im Entwurf nicht mehr ist: ein entfernter
/// Haken, eine unterschrittene Schwelle, ein gelöschter offener Eintrag samt
/// davon abhängiger Gruppen- und Meta-Boni. Ändert sich der Inhalt eines
/// angewendeten Postens (gewählte SE, AP eines offenen Eintrags), wird der
/// alte Inhalt zurückgenommen und der neue gebucht.
///
/// Maßgeblich für das Gebuchte sind ausschließlich die angewendeten IDs in
/// [gebucht]; die des Entwurfs zählen nicht. Was schon vorher angewendet,
/// aber nicht mehr erfüllt war, bleibt unangetastet: Zurückgenommen wird
/// nur, was dieser Entwurf ändert.
ReiseberichtBuchung berechneReiseberichtBuchung({
  required List<ReiseberichtDef> catalog,
  required HeroReisebericht gebucht,
  required HeroReisebericht entwurf,
}) {
  final schritte = _buchungsschritte(catalog, gebucht, entwurf);
  return ReiseberichtBuchung(
    neu: _summe(schritte.neu),
    zurueck: _summe(schritte.zurueck),
  );
}

/// Was der Wechsel des Entwurfs von [vorher] zu [nachher] an der Buchung
/// zusätzlich bewirkt, gemessen am gebuchten Stand [gebucht].
///
/// Für die Rückfrage beim Entfernen eines Hakens oder offenen Eintrags:
/// Enthält das Ergebnis Zurücknahmen, nimmt die Änderung bereits gebuchte
/// Belohnungen zurück.
ReiseberichtBuchung reiseberichtBuchungsaenderung({
  required List<ReiseberichtDef> catalog,
  required HeroReisebericht gebucht,
  required HeroReisebericht vorher,
  required HeroReisebericht nachher,
}) {
  final alt = _buchungsschritte(catalog, gebucht, vorher);
  final neu = _buchungsschritte(catalog, gebucht, nachher);
  final alteNeu = {for (final posten in alt.neu) posten.schluessel};
  final alteZurueck = {for (final posten in alt.zurueck) posten.schluessel};
  return ReiseberichtBuchung(
    neu: _summe(neu.neu.where((p) => !alteNeu.contains(p.schluessel))),
    zurueck: _summe(
      neu.zurueck.where((p) => !alteZurueck.contains(p.schluessel)),
    ),
  );
}

/// Bucht den Abgleich [buchung] auf [hero] und übernimmt den [entwurf].
///
/// Erst wird zurückgenommen, dann neu gebucht; die angewendeten IDs ergeben
/// sich aus [gebucht] ohne die zurückgenommenen und mit den neuen.
HeroSheet bucheReisebericht({
  required HeroSheet hero,
  required ReiseberichtBuchung buchung,
  required HeroReisebericht gebucht,
  required HeroReisebericht entwurf,
}) {
  final zustand = entwurf.copyWith(appliedRewardIds: gebucht.appliedRewardIds);
  final zurueckgenommen = revokeReiseberichtRewards(
    hero: hero,
    rewards: buchung.zurueck,
    updatedState: zustand,
  );
  return applyReiseberichtRewards(
    hero: zurueckgenommen,
    rewards: buchung.neu,
    updatedState: zurueckgenommen.reisebericht,
  );
}

/// AP aller in [gebucht] angewendeten Belohnungen.
///
/// Grundlage des Vorschlags für den einmaligen AP-Nachtrag eines Vertrauten
/// (`vertrautenNachtragsvorschlag`).
int gebuchteReiseberichtAp({
  required List<ReiseberichtDef> catalog,
  required HeroReisebericht gebucht,
}) {
  var summe = 0;
  for (final posten in _buchungsposten(catalog, gebucht)) {
    if (gebucht.appliedRewardIds.contains(posten.id)) summe += posten.ap;
  }
  return summe;
}

// Ein buchbarer Posten: eine Belohnungs-ID, ihr Inhalt und ob ihre Bedingung
// im betrachteten Stand erfüllt ist.
class _Posten {
  _Posten(
    this.id, {
    required this.erfuellt,
    this.ap = 0,
    this.se = const <ReiseberichtSeReward>[],
    this.talentBoni = const <ReiseberichtTalentBonus>[],
    this.eigenschaftsBoni = const <ReiseberichtEigenschaftsBonus>[],
  });

  final String id;
  final bool erfuellt;
  final int ap;
  final List<ReiseberichtSeReward> se;
  final List<ReiseberichtTalentBonus> talentBoni;
  final List<ReiseberichtEigenschaftsBonus> eigenschaftsBoni;

  // Inhalt ohne Bedingung; gleich, wenn dieselbe Buchung entstünde.
  late final String inhalt = [
    ap,
    for (final eintrag in se) 'se:${eintrag.talentName}',
    for (final bonus in talentBoni)
      'tb:${bonus.talentName}:${bonus.wert}:${bonus.beschreibung}',
    for (final bonus in eigenschaftsBoni)
      'eb:${bonus.eigenschaft}:${bonus.wert}',
  ].join('|');

  late final String schluessel = '$id#$inhalt';
}

// Neu zu buchende und zurückzunehmende Posten eines Entwurfs.
({List<_Posten> neu, List<_Posten> zurueck}) _buchungsschritte(
  List<ReiseberichtDef> catalog,
  HeroReisebericht gebucht,
  HeroReisebericht entwurf,
) {
  final angewendet = gebucht.appliedRewardIds;
  final imGebuchten = {
    for (final posten in _buchungsposten(catalog, gebucht)) posten.id: posten,
  };
  final imEntwurf = {
    for (final posten in _buchungsposten(catalog, entwurf)) posten.id: posten,
  };
  final neu = <_Posten>[];
  final zurueck = <_Posten>[];
  for (final vorher in imGebuchten.values) {
    if (!vorher.erfuellt || !angewendet.contains(vorher.id)) {
      continue;
    }
    final nachher = imEntwurf[vorher.id];
    if (nachher == null || !nachher.erfuellt) {
      zurueck.add(vorher);
    } else if (nachher.inhalt != vorher.inhalt) {
      zurueck.add(vorher);
      neu.add(nachher);
    }
  }
  for (final posten in imEntwurf.values) {
    if (posten.erfuellt && !angewendet.contains(posten.id)) {
      neu.add(posten);
    }
  }
  return (neu: neu, zurueck: zurueck);
}

ReiseberichtRewards _summe(Iterable<_Posten> posten) {
  var ap = 0;
  final se = <ReiseberichtSeReward>[];
  final talentBoni = <ReiseberichtTalentBonus>[];
  final eigenschaftsBoni = <ReiseberichtEigenschaftsBonus>[];
  final ids = <String>{};
  for (final eintrag in posten) {
    ap += eintrag.ap;
    se.addAll(eintrag.se);
    talentBoni.addAll(eintrag.talentBoni);
    eigenschaftsBoni.addAll(eintrag.eigenschaftsBoni);
    ids.add(eintrag.id);
  }
  return ReiseberichtRewards(
    ap: ap,
    seRewards: se,
    talentBoni: talentBoni,
    eigenschaftsBoni: eigenschaftsBoni,
    newAppliedIds: ids,
  );
}

// Alle buchbaren Posten des Katalogs in Katalogreihenfolge.
List<_Posten> _buchungsposten(
  List<ReiseberichtDef> catalog,
  HeroReisebericht state,
) {
  final posten = <_Posten>[];
  bool abgehakt(String id) => state.checkedIds.contains(id);
  List<ReiseberichtSeReward> seVon(String id, List<ReiseberichtSeDef> defs) {
    final ergebnis = <ReiseberichtSeReward>[];
    _collectSeRewards(id, defs, state, ergebnis);
    return ergebnis;
  }

  List<ReiseberichtTalentBonus> boniVon(
    String id,
    List<ReiseberichtTalentBonusDef> defs,
    String name,
  ) => [
    for (final tb in defs)
      ReiseberichtTalentBonus(
        sourceId: id,
        talentName: tb.talentName,
        wert: tb.wert,
        beschreibung: 'Reisebericht: $name',
      ),
  ];

  for (final def in catalog) {
    switch (def.typ) {
      case 'checkpoint':
      case 'grouped_progression':
        posten.add(
          _Posten(
            def.id,
            erfuellt: abgehakt(def.id),
            ap: def.ap,
            se: seVon(def.id, def.se),
          ),
        );

      case 'multi_requirement':
        for (final req in def.anforderungen) {
          posten.add(
            _Posten(
              req.id,
              erfuellt: abgehakt(req.id),
              ap: req.ap,
              se: seVon(req.id, req.se),
            ),
          );
        }

      case 'collection_fixed':
        for (final eintrag in def.festeEintraege) {
          posten.add(
            _Posten(
              eintrag.id,
              erfuellt: abgehakt(eintrag.id),
              ap: def.apProEintrag,
            ),
          );
        }
        final schwelle = def.schwelleBelohnung;
        if (schwelle != null) {
          final id = '${def.id}_schwelle';
          posten.add(
            _Posten(
              id,
              erfuellt: isFixedCollectionThresholdMet(def, state),
              ap: schwelle.ap,
              se: seVon(id, schwelle.se),
              talentBoni: boniVon(id, schwelle.talentBoni, def.name),
            ),
          );
        }
        final bonus = def.bonus;
        if (bonus != null) {
          final id = bonus.id.isNotEmpty ? bonus.id : '${def.id}_bonus';
          posten.add(
            _Posten(
              id,
              erfuellt: isFixedCollectionBonusMet(def, state),
              ap: bonus.ap,
              se: seVon(id, bonus.se),
              talentBoni: boniVon(id, bonus.talentBoni, bonus.name),
            ),
          );
        }

      case 'collection_open':
        // AP je Eintrag über seine Position; die SE alle N Einträge.
        final items = state.openEntries[def.id] ?? const [];
        for (var i = 0; i < items.length; i++) {
          posten.add(
            _Posten(
              '${def.id}_item_$i',
              erfuellt: true,
              ap: items[i].ap > 0 ? items[i].ap : def.apProEintrag,
            ),
          );
        }
        if (def.seIntervall > 0) {
          final seCount = items.length ~/ def.seIntervall;
          for (var s = 0; s < seCount; s++) {
            final id = '${def.id}_se_$s';
            posten.add(_Posten(id, erfuellt: true, se: seVon(id, def.se)));
          }
        }

      case 'grouped_progression_bonus':
        posten.add(
          _Posten(
            def.id,
            erfuellt: _isProgressionGroupComplete(def.gruppeId, state, catalog),
            se: seVon(def.id, def.se),
          ),
        );

      case 'meta':
        posten.add(
          _Posten(
            def.id,
            erfuellt: _isMetaComplete(def, state, catalog),
            ap: def.ap,
            se: seVon(def.id, def.se),
            eigenschaftsBoni: [
              for (final eb in def.eigenschaftsBonus)
                ?_resolveEigenschaft(eb, state, def.id),
            ],
          ),
        );
    }
  }
  return posten;
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
        rewards.add(
          ReiseberichtSeReward(sourceId: sourceId, talentName: chosen),
        );
      }
    } else if (se.ziel == 'talent' || se.ziel == 'grundwert') {
      rewards.add(
        ReiseberichtSeReward(sourceId: sourceId, talentName: se.name),
      );
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
    case 'MU':
      return 'mu';
    case 'KL':
      return 'kl';
    case 'IN':
      return 'in';
    case 'CH':
      return 'ch';
    case 'FF':
      return 'ff';
    case 'GE':
      return 'ge';
    case 'KO':
      return 'ko';
    case 'KK':
      return 'kk';
    default:
      return null;
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
    return hero.copyWith(
      reisebericht: updatedState.copyWith(
        appliedRewardIds: {
          ...updatedState.appliedRewardIds,
          ...rewards.newAppliedIds,
        },
      ),
    );
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
        ..add(
          HeroTalentModifier(modifier: tb.wert, description: tb.beschreibung),
        );
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

  final ergebnis = hero.copyWith(
    apTotal: apTotal,
    talents: talents,
    attributes: attributes,
    reisebericht: updatedState.copyWith(appliedRewardIds: mergedApplied),
  );
  // Der Vertraute erhält seinen Anteil an den Abenteuer-AP (WdZ S. 125).
  return mitVertrautenApAnteil(ergebnis, rewards.ap);
}

/// Nimmt Belohnungen zurueck (Umkehroperation).
HeroSheet revokeReiseberichtRewards({
  required HeroSheet hero,
  required ReiseberichtRewards rewards,
  required HeroReisebericht updatedState,
}) {
  if (rewards.isEmpty) {
    return hero.copyWith(
      reisebericht: updatedState.copyWith(
        appliedRewardIds: {...updatedState.appliedRewardIds}
          ..removeAll(rewards.newAppliedIds),
      ),
    );
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
  final cleanedApplied = <String>{...updatedState.appliedRewardIds}
    ..removeAll(rewards.newAppliedIds);

  final ergebnis = hero.copyWith(
    apTotal: apTotal,
    talents: talents,
    attributes: attributes,
    reisebericht: updatedState.copyWith(appliedRewardIds: cleanedApplied),
  );
  // Der Vertraute erhält seinen Anteil an den Abenteuer-AP (WdZ S. 125).
  return mitVertrautenApAnteil(ergebnis, -rewards.ap);
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
    case 'mu':
      return attributes.copyWith(mu: attributes.mu + bonus);
    case 'kl':
      return attributes.copyWith(kl: attributes.kl + bonus);
    case 'in':
      return attributes.copyWith(inn: attributes.inn + bonus);
    case 'ch':
      return attributes.copyWith(ch: attributes.ch + bonus);
    case 'ff':
      return attributes.copyWith(ff: attributes.ff + bonus);
    case 'ge':
      return attributes.copyWith(ge: attributes.ge + bonus);
    case 'ko':
      return attributes.copyWith(ko: attributes.ko + bonus);
    case 'kk':
      return attributes.copyWith(kk: attributes.kk + bonus);
    default:
      return attributes;
  }
}
