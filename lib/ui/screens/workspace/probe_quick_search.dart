import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zauber_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';

/// Öffnet die Proben-Schnellsuche und führt die gewählte Probe aus.
///
/// Die Suche deckt Eigenschaften, Kampfwerte, Talente und Zauber des Helden
/// ab. Nach der Auswahl wird der bestehende Probendialog inklusive
/// Würfelprotokoll-Persistenz geöffnet.
Future<void> showProbeQuickSearch({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
}) async {
  final candidate = await showDialog<ProbeQuickSearchCandidate>(
    context: context,
    builder: (_) => ProbeQuickSearchDialog(heroId: heroId),
  );
  if (candidate == null || !context.mounted) {
    return;
  }
  await showLoggedProbeDialog(
    context: context,
    ref: ref,
    heroId: heroId,
    request: candidate.buildRequest(),
  );
}

/// Würfelt die Probe eines Protokolleintrags nochmal (SPIEL-05).
///
/// Die Probe wird unter denselben Kandidaten gesucht wie in der Schnellsuche;
/// Titel und Probeart müssen zum [entry] passen. Geöffnet wird der normale
/// Probendialog mit den **aktuellen** Werten des Helden und ohne die damaligen
/// Situationsmodifikatoren, das Ergebnis wird wie jede Probe protokolliert.
///
/// Gibt `false` zurück, wenn die Probe nicht mehr gefunden wird (etwa weil der
/// Zauber inzwischen fehlt) oder der Held noch nicht geladen ist; dann öffnet
/// sich nichts.
Future<bool> wiederholeProbe({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required DiceLogEntry entry,
}) async {
  final hero = ref.read(heroByIdProvider(heroId));
  final snapshot = ref.read(heroComputedProvider(heroId)).valueOrNull;
  final catalog = ref.read(heroRulesCatalogProvider(heroId)).valueOrNull;
  if (hero == null || snapshot == null || catalog == null) {
    return false;
  }
  final candidates = _buildCandidates(
    hero: hero,
    snapshot: snapshot,
    catalogTalents: catalog.talents,
    catalogSpells: catalog.spells,
    talentBeOverride: ref.read(talentBeOverrideProvider(heroId)),
    epicAdvantagesActive: ref.read(heroEpicAdvantagesActiveProvider(heroId)),
  );
  for (final candidate in candidates) {
    final request = candidate.buildRequest();
    if (request.title != entry.title || request.type != entry.type) {
      continue;
    }
    if (!context.mounted) {
      return false;
    }
    await showLoggedProbeDialog(
      context: context,
      ref: ref,
      heroId: heroId,
      request: request,
    );
    return true;
  }
  return false;
}

/// Wie [wiederholeProbe], nennt aber in einer Meldung, wenn sich die Probe
/// nicht wiederholen lässt. Für die Protokollansichten.
Future<void> wiederholeProbeMitHinweis({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required DiceLogEntry entry,
}) async {
  final meldung = ScaffoldMessenger.maybeOf(context);
  final gefunden = await wiederholeProbe(
    context: context,
    ref: ref,
    heroId: heroId,
    entry: entry,
  );
  if (!gefunden) {
    meldung?.showSnackBar(
      const SnackBar(
        content: Text(
          'Diese Probe lässt sich nicht wiederholen: Sie steht nicht mehr im '
          'Bogen.',
        ),
      ),
    );
  }
}

/// Kategorien der Schnellsuche in fester Anzeige-Reihenfolge.
enum ProbeQuickSearchCategory {
  /// Eigenschaftsproben (1W20).
  attribute('Eigenschaften'),

  /// Kampf-Schnellproben (AT/PA/Ausweichen).
  combat('Kampf'),

  /// Talentproben (3W20 mit TaW-Kompensation).
  talent('Talente'),

  /// Zauberproben (3W20 mit ZfW-Kompensation).
  spell('Zauber');

  const ProbeQuickSearchCategory(this.label);

  /// Anzeigename der Kategorie als Gruppenüberschrift.
  final String label;
}

/// Ein würfelbarer Treffer der Schnellsuche.
///
/// Die Probe wird erst beim Antippen über [buildRequest] aufgelöst, damit die
/// Trefferliste günstig bleibt.
class ProbeQuickSearchCandidate {
  /// Erzeugt einen unveränderlichen Suchtreffer.
  const ProbeQuickSearchCandidate({
    required this.category,
    required this.name,
    required this.detail,
    required this.buildRequest,
  });

  /// Kategorie für Gruppierung und Sortierung.
  final ProbeQuickSearchCategory category;

  /// Anzeigename, gegen den auch gesucht wird.
  final String name;

  /// Sekundärzeile, z. B. Eigenschaftskette und aktueller Wert.
  final String detail;

  /// Baut die aufgelöste Probeanfrage für den Probendialog.
  final ResolvedProbeRequest Function() buildRequest;
}

/// Dialog mit Suchfeld und gruppierter Trefferliste über alle Proben.
class ProbeQuickSearchDialog extends ConsumerStatefulWidget {
  /// Erzeugt den Dialog für einen Helden.
  const ProbeQuickSearchDialog({super.key, required this.heroId});

  /// Ziel-Held, dessen Proben durchsucht werden.
  final String heroId;

  @override
  ConsumerState<ProbeQuickSearchDialog> createState() =>
      _ProbeQuickSearchDialogState();
}

class _ProbeQuickSearchDialogState
    extends ConsumerState<ProbeQuickSearchDialog> {
  String _query = '';

  /// Maximale Trefferanzahl, damit die Liste bedienbar bleibt.
  static const int _maxResults = 40;

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final computedAsync = ref.watch(heroComputedProvider(widget.heroId));
    final catalogAsync = ref.watch(heroRulesCatalogProvider(widget.heroId));
    final talentBeOverride = ref.watch(talentBeOverrideProvider(widget.heroId));
    final epicAdvantagesActive = ref.watch(
      heroEpicAdvantagesActiveProvider(widget.heroId),
    );

    final snapshot = computedAsync.valueOrNull;
    final catalog = catalogAsync.valueOrNull;

    Widget body;
    if (hero == null) {
      body = const _CenteredDialogNotice(text: 'Held nicht gefunden.');
    } else if (snapshot == null || catalog == null) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final candidates = _buildCandidates(
        hero: hero,
        snapshot: snapshot,
        catalogTalents: catalog.talents,
        catalogSpells: catalog.spells,
        talentBeOverride: talentBeOverride,
        epicAdvantagesActive: epicAdvantagesActive,
      );
      body = _buildResultList(_filterCandidates(candidates));
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const ValueKey('probe-quick-search-field'),
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Probe suchen (Talent, Zauber, Eigenschaft …)',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }

  /// Filtert die Kandidaten anhand der normalisierten Sucheingabe.
  ///
  /// Ohne Eingabe bleiben nur Eigenschaften und Kampfwerte sichtbar, damit
  /// der Dialog sofort nutzbare Schnellproben zeigt.
  List<ProbeQuickSearchCandidate> _filterCandidates(
    List<ProbeQuickSearchCandidate> candidates,
  ) {
    final normalizedQuery = _normalizeSearchToken(_query);
    if (normalizedQuery.isEmpty) {
      final defaults = candidates.where(
        (candidate) =>
            candidate.category == ProbeQuickSearchCategory.attribute ||
            candidate.category == ProbeQuickSearchCategory.combat,
      );
      return defaults.toList(growable: false);
    }
    final matches = candidates.where(
      (candidate) =>
          _normalizeSearchToken(candidate.name).contains(normalizedQuery),
    );
    return matches.take(_maxResults).toList(growable: false);
  }

  /// Baut die gruppierte Trefferliste mit Kategorie-Überschriften.
  Widget _buildResultList(List<ProbeQuickSearchCandidate> results) {
    if (results.isEmpty) {
      return const _CenteredDialogNotice(text: 'Keine Probe gefunden.');
    }
    final tiles = <Widget>[];
    ProbeQuickSearchCategory? lastCategory;
    for (final candidate in results) {
      if (candidate.category != lastCategory) {
        lastCategory = candidate.category;
        tiles.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              candidate.category.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        );
      }
      tiles.add(
        ListTile(
          key: ValueKey(
            'probe-quick-search-${candidate.category.name}-${candidate.name}',
          ),
          dense: true,
          leading: const Icon(Icons.casino_outlined, size: 20),
          title: Text(candidate.name),
          subtitle: Text(candidate.detail),
          onTap: () => Navigator.of(context).pop(candidate),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: tiles,
    );
  }
}

/// Zentrierter Hinweistext für Leer- und Fehlerzustände des Dialogs.
class _CenteredDialogNotice extends StatelessWidget {
  const _CenteredDialogNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text)),
    );
  }
}

/// Baut alle würfelbaren Kandidaten des Helden in Anzeige-Reihenfolge.
List<ProbeQuickSearchCandidate> _buildCandidates({
  required HeroSheet hero,
  required HeroComputedSnapshot snapshot,
  required List<TalentDef> catalogTalents,
  required List<SpellDef> catalogSpells,
  required int? talentBeOverride,
  required bool epicAdvantagesActive,
}) {
  final candidates = <ProbeQuickSearchCandidate>[
    ..._buildAttributeCandidates(
      snapshot.probenEigenschaften,
      snapshot.effectiveAttributes,
    ),
    ..._buildCombatCandidates(snapshot),
    ..._buildTalentCandidates(
      hero: hero,
      snapshot: snapshot,
      catalogTalents: catalogTalents,
      talentBeOverride: talentBeOverride,
      epicAdvantagesActive: epicAdvantagesActive,
    ),
    ..._buildSpellCandidates(
      hero: hero,
      snapshot: snapshot,
      catalogSpells: catalogSpells,
    ),
  ];
  return candidates;
}

/// Baut die acht Eigenschafts-Schnellproben aus den Probenwerten (Wunden
/// eingerechnet); [grundwerte] zeigen den Abzug an.
List<ProbeQuickSearchCandidate> _buildAttributeCandidates(
  Attributes probenEigenschaften,
  Attributes grundwerte,
) {
  final candidates = <ProbeQuickSearchCandidate>[];
  for (final code in AttributeCode.values) {
    final label = attributeCodeKey(code);
    final value = readAttributeValue(probenEigenschaften, code);
    final abzug = value - readAttributeValue(grundwerte, code);
    final wundText = abzug == 0 ? '' : ' (Wunden −${-abzug})';
    candidates.add(
      ProbeQuickSearchCandidate(
        category: ProbeQuickSearchCategory.attribute,
        name: label,
        detail: 'Eigenschaftsprobe · Wert $value$wundText',
        buildRequest: () =>
            buildAttributeProbeRequest(label: label, effectiveValue: value),
      ),
    );
  }
  return candidates;
}

/// Baut AT/PA/Ausweichen-Schnellproben aus der aktiven Kampfvorschau.
List<ProbeQuickSearchCandidate> _buildCombatCandidates(
  HeroComputedSnapshot snapshot,
) {
  final combat = snapshot.combatPreviewStats;
  final candidates = <ProbeQuickSearchCandidate>[
    ProbeQuickSearchCandidate(
      category: ProbeQuickSearchCategory.combat,
      name: 'Attacke',
      detail: 'Haupthand · AT ${combat.at}',
      buildRequest: () => buildCombatCheckProbeRequest(
        type: ProbeType.combatAttack,
        title: 'Schnellprobe: AT',
        targetValue: combat.at,
      ),
    ),
    ProbeQuickSearchCandidate(
      category: ProbeQuickSearchCategory.combat,
      name: 'Parade',
      detail: 'Haupthand · PA ${combat.pa}',
      buildRequest: () => buildCombatCheckProbeRequest(
        type: ProbeType.combatParry,
        title: 'Schnellprobe: PA',
        targetValue: combat.pa,
      ),
    ),
    ProbeQuickSearchCandidate(
      category: ProbeQuickSearchCategory.combat,
      name: 'Ausweichen',
      detail: 'AW ${combat.ausweichen}',
      buildRequest: () => buildCombatCheckProbeRequest(
        type: ProbeType.dodge,
        title: 'Schnellprobe: AW',
        targetValue: combat.ausweichen,
      ),
    ),
  ];
  return candidates;
}

/// Baut Talentproben für alle aktiven, würfelbaren Talente des Helden.
///
/// Kampftalente bleiben außen vor, weil sie über AT/PA gewürfelt werden;
/// würfelbar sind nur Talente mit vollständiger Drei-Eigenschaften-Kette.
List<ProbeQuickSearchCandidate> _buildTalentCandidates({
  required HeroSheet hero,
  required HeroComputedSnapshot snapshot,
  required List<TalentDef> catalogTalents,
  required int? talentBeOverride,
  required bool epicAdvantagesActive,
}) {
  final candidates = <ProbeQuickSearchCandidate>[];
  for (final talent in catalogTalents) {
    if (talent.group == 'Kampftalent') {
      continue;
    }
    // Dieselbe TaW*-Rechnung wie im Gefecht (`talent_probe_rules.dart`).
    final wert = talentProbenwertFuer(
      snapshot: snapshot,
      talent: talent,
      epicAdvantagesActive: epicAdvantagesActive,
      talentBeOverride: talentBeOverride,
    );
    if (wert == null) {
      continue;
    }
    final chain = wert.ziele.map((target) => target.label).join('/');
    candidates.add(
      ProbeQuickSearchCandidate(
        category: ProbeQuickSearchCategory.talent,
        name: talent.name,
        detail: '$chain · TaW* ${wert.taw}',
        buildRequest: () => buildTalentProbeRequest(
          title: talent.name,
          targets: wert.ziele,
          basePool: wert.taw,
          spezialisierungen: wert.spezialisierungen,
          tawHerleitung: wert.herleitung.taw,
        ),
      ),
    );
  }
  // Ausweichproben auf verwandte Talente (Meisterentscheid, Basis S. 113).
  for (final e in talentErsatzproben(
    snapshot: snapshot,
    katalog: catalogTalents,
    epicAdvantagesActive: epicAdvantagesActive,
    talentBeOverride: talentBeOverride,
  )) {
    final chain = e.request.targets.map((target) => target.label).join('/');
    candidates.add(
      ProbeQuickSearchCandidate(
        category: ProbeQuickSearchCategory.talent,
        name: e.request.title.replaceFirst('Talentprobe: ', ''),
        detail:
            '$chain · Ausweichen, TaW* ${e.request.basePool} · '
            'Meisterentscheid'
            '${e.option.bedingung == null ? '' : ' · ${e.option.bedingung}'}',
        buildRequest: () => e.request,
      ),
    );
  }
  candidates.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return candidates;
}

/// Baut Zauberproben für alle gelernten Zauber des Helden.
List<ProbeQuickSearchCandidate> _buildSpellCandidates({
  required HeroSheet hero,
  required HeroComputedSnapshot snapshot,
  required List<SpellDef> catalogSpells,
}) {
  if (hero.spells.isEmpty) {
    return const <ProbeQuickSearchCandidate>[];
  }
  final spellDefsById = <String, SpellDef>{
    for (final spell in catalogSpells) spell.id: spell,
  };
  final candidates = <ProbeQuickSearchCandidate>[];
  for (final spellEntry in hero.spells.entries) {
    final spell = spellDefsById[spellEntry.key];
    if (spell == null) {
      continue;
    }
    final wert = zauberProbenwertAus(
      eintrag: spellEntry.value,
      spell: spell,
      probenEigenschaften: snapshot.probenEigenschaften,
    );
    if (wert == null) {
      continue;
    }
    final chain = wert.ziele.map((target) => target.label).join('/');
    candidates.add(
      ProbeQuickSearchCandidate(
        category: ProbeQuickSearchCategory.spell,
        name: spell.name,
        detail: '$chain · ZfW* ${wert.zfw}',
        buildRequest: () => zauberprobeAus(wert: wert, titel: spell.name),
      ),
    );
  }

  candidates.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return candidates;
}

/// Normalisiert Suchtokens für robuste, umlaut-tolerante Vergleiche.
String _normalizeSearchToken(String raw) {
  var text = raw.toLowerCase().trim();
  text = text
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');
  return text.replaceAll(RegExp(r'[^a-z0-9]'), '');
}
