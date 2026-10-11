import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_impact_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_ability_groups.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_waffenmeister_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_visibility_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_activation_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog_actions.dart';

import 'advancement_base_value_tile.dart';
import 'advancement_gottheit_wahl.dart';
import 'advancement_merkmal_sections.dart';
import 'advancement_skill_tree_view.dart';
import 'advancement_talent_groups.dart';
import 'advancement_value_tile.dart';
import 'advancement_specialization_dialog.dart';

import 'package:dsa_heldenverwaltung/rules/derived/advancement_specialization_rules.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Durchsuchbarer Steigerungskatalog auf Basis der ungespeicherten Vorschau.
// Eine Listenzeile bleibt immer sichtbar; darunter wäre der Katalog nur
// noch Kopfzeile und es ließe sich nichts mehr auswählen.
const double _kMindestListenHoehe = 56;

class AdvancementCatalog extends ConsumerStatefulWidget {
  /// Bindet den Katalog an die bereits gestartete Steigerungsrunde des Helden.
  const AdvancementCatalog({super.key, required this.heroId});

  /// Held, dessen Vorschau und Katalog in dieser Runde verwendet werden.
  final String heroId;

  /// Hält Suchtext und Kategorie beim Wechsel einzelner Planungsschritte.
  @override
  ConsumerState<AdvancementCatalog> createState() => _AdvancementCatalogState();
}

/// Arbeitsbereiche der Planung; jeder bündelt Werte und Sonderfertigkeiten
/// eines Themas.
enum _Bereich {
  grundlagen('Grundlagen'),
  talente('Talente'),
  kampf('Kampf'),
  magie('Magie'),
  karma('Karma');

  const _Bereich(this.label);
  final String label;

  List<_Abschnitt> get abschnitte => _Abschnitt.values
      .where((abschnitt) => abschnitt.bereich == this)
      .toList();
}

/// Wie ein Abschnitt seine Einträge zeigt.
enum _Darstellung { werte, baum, merkmale, merkmalskenntnisse }

/// Abschnitt innerhalb eines Bereichs.
///
/// Die Gliederung dient ausschließlich der Navigation, nicht der Regelprüfung.
/// Hauptliste und Erwerbsblatt lesen dieselben Arten und Prädikate, damit
/// kein Eintrag zwischen beiden verlorengeht.
enum _Abschnitt {
  eigenschaften(
    'Eigenschaften & Basiswerte',
    _Bereich.grundlagen,
    _Darstellung.werte,
    [AdvancementKind.attribute, AdvancementKind.boughtStat],
  ),
  vorteile('Vorteile', _Bereich.grundlagen, _Darstellung.merkmale, [
    AdvancementKind.advantage,
  ]),
  nachteile('Nachteile', _Bereich.grundlagen, _Darstellung.merkmale, [
    AdvancementKind.disadvantage,
  ]),
  talente('Talente', _Bereich.talente, _Darstellung.werte, [
    AdvancementKind.talent,
  ]),
  sprachen('Sprachen & Schriften', _Bereich.talente, _Darstellung.werte, [
    AdvancementKind.language,
    AdvancementKind.script,
  ]),
  allgemeineSf('Sonderfertigkeiten', _Bereich.talente, _Darstellung.baum, [
    AdvancementKind.generalAbility,
  ]),
  kampftalente('Kampftalente', _Bereich.kampf, _Darstellung.werte, [
    AdvancementKind.talent,
  ]),
  kampfSf('Sonderfertigkeiten & Manöver', _Bereich.kampf, _Darstellung.baum, [
    AdvancementKind.combatAbility,
    AdvancementKind.maneuver,
  ]),
  zauber('Zauber', _Bereich.magie, _Darstellung.werte, [AdvancementKind.spell]),
  merkmalskenntnisse(
    'Merkmalskenntnisse',
    _Bereich.magie,
    _Darstellung.merkmalskenntnisse,
    [AdvancementKind.magicAbility],
  ),
  magieSf('Sonderfertigkeiten & Rituale', _Bereich.magie, _Darstellung.baum, [
    AdvancementKind.magicAbility,
  ]),
  karmaSf('Sonderfertigkeiten & Liturgien', _Bereich.karma, _Darstellung.baum, [
    AdvancementKind.karmalAbility,
  ]);

  const _Abschnitt(this.label, this.bereich, this.darstellung, this.kinds);
  final String label;
  final _Bereich bereich;
  final _Darstellung darstellung;
  final List<AdvancementKind> kinds;

  /// Ob eine Option in diesen Abschnitt gehört.
  bool matches(AdvancementOption option) =>
      kinds.contains(option.kind) &&
      switch (this) {
        talente => !option.isCombatTalent,
        kampftalente => option.isCombatTalent,
        merkmalskenntnisse => option.isMerkmalskenntnis,
        magieSf => !option.isMerkmalskenntnis,
        _ => true,
      };

  /// Wertlisten zeigen nur, was der Held führt; Bäume und Merkmale alles.
  AdvancementScope get scope => switch (darstellung) {
    _Darstellung.werte => AdvancementScope.active,
    _ => AdvancementScope.all,
  };

  /// Fester Bereich des Fähigkeitenbaums.
  FaehigkeitenBereich? get baumBereich => switch (this) {
    allgemeineSf => FaehigkeitenBereich.allgemein,
    kampfSf => FaehigkeitenBereich.kampf,
    magieSf => FaehigkeitenBereich.magie,
    karmaSf => FaehigkeitenBereich.karma,
    _ => null,
  };

  bool get supportsActivation => activationLabel.isNotEmpty;

  String get activationLabel => switch (this) {
    talente => 'Talent erlernen',
    sprachen => 'Sprache oder Schrift erlernen',
    kampftalente => 'Kampftalent erlernen',
    zauber => 'Zauber erlernen',
    allgemeineSf => 'Sonderfertigkeit erwerben',
    kampfSf => 'Sonderfertigkeit oder Manöver erwerben',
    magieSf => 'Sonderfertigkeit oder Ritual erwerben',
    karmaSf => 'Sonderfertigkeit oder Liturgie erwerben',
    _ => '',
  };

  String get emptyText => switch (this) {
    talente => 'Noch keine Talente auf dem Heldenbogen.',
    sprachen => 'Noch keine Sprachen oder Schriften auf dem Heldenbogen.',
    kampftalente => 'Noch keine Kampftalente auf dem Heldenbogen.',
    zauber => 'Noch keine Zauber auf dem Heldenbogen.',
    _ => 'Noch keine Sonderfertigkeiten erworben.',
  };
}

/// Abschnittskopf über den zugekauften Basiswerten, abgesetzt von den
/// Eigenschaftskacheln durch eine Linie statt einer weiteren Karte.
class _BasiswertUeberschrift extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Basiswerte',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Zukäufe mit AP',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

class _AdvancementCatalogState extends ConsumerState<AdvancementCatalog> {
  final _searchController = TextEditingController();
  _Abschnitt _abschnitt = _Abschnitt.eigenschaften;

  // Je Bereich der zuletzt gewählte Abschnitt.
  final _letzterAbschnitt = <_Bereich, _Abschnitt>{};
  bool _dialogOpen = false;

  // Eingeklappte Talentgruppen und die Anker, zu denen die Sprungleiste scrollt.
  final _eingeklappt = <TalentGruppe>{};
  final _gruppenAnker = <TalentGruppe, GlobalKey>{
    for (final gruppe in TalentGruppe.values) gruppe: GlobalKey(),
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Magie und Karma erscheinen nur bei passender Befähigung oder Bestand;
  // „Unpassende anzeigen“ hebt das wie im Fähigkeitenbaum auf.
  bool _sichtbar(_Bereich bereich, AdvancementSession session) {
    final hero = session.preview;
    if (hero.showInapplicableSpecialAbilities) return true;
    final activation = computeHeroResourceActivation(
      hero,
      catalog: session.catalog,
    );
    return switch (bereich) {
      _Bereich.magie =>
        activation.magic.isEnabled ||
            hero.representationen.isNotEmpty ||
            hero.ritualCategories.isNotEmpty ||
            hero.spells.isNotEmpty ||
            hero.magicSpecialAbilities.isNotEmpty ||
            hero.merkmalskenntnisse.isNotEmpty,
      _Bereich.karma =>
        activation.divine.isEnabled || hero.gottheit.trim().isNotEmpty,
      _ => true,
    };
  }

  void _waehleBereich(_Bereich bereich) => setState(() {
    _letzterAbschnitt[_abschnitt.bereich] = _abschnitt;
    _abschnitt = _letzterAbschnitt[bereich] ?? bereich.abschnitte.first;
  });

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(advancementSessionProvider(widget.heroId));
    if (session == null) {
      return const Center(child: Text('Keine Steigerungsrunde geöffnet.'));
    }
    final bereiche = _Bereich.values
        .where((bereich) => _sichtbar(bereich, session))
        .toList();
    // Ein ausgeblendeter Bereich fällt auf die Grundlagen zurück.
    final abschnitt = bereiche.contains(_abschnitt.bereich)
        ? _abschnitt
        : _Abschnitt.eigenschaften;
    final query = _searchController.text.trim().toLowerCase();
    final options = ref.watch(
      advancementOptionsProvider((
        heroId: widget.heroId,
        scope: abschnitt.scope,
      )),
    );
    final filtered = options.where((option) {
      return abschnitt.matches(option) &&
          option.label.toLowerCase().contains(query);
    }).toList();
    final plannedTargets = <String>{
      for (final entry in session.entries)
        '${entry.kind.name}:${entry.targetId}',
    };
    final showImpact = abschnitt == _Abschnitt.eigenschaften;
    final showBridge =
        query.isNotEmpty &&
        abschnitt.supportsActivation &&
        abschnitt.darstellung == _Darstellung.werte &&
        !_dialogOpen;
    final aktiveEintraege =
        abschnitt.darstellung == _Darstellung.werte && !showImpact;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Der Kopf behält seine natürliche Höhe, solange sie passt. Erst wenn
        // er der Liste nicht einmal mehr eine Zeile ließe — schmales Gerät,
        // große Schrift —, scrollt er in sich, statt überzulaufen und den
        // Katalog unerreichbar zu machen.
        final maxKopfHoehe = constraints.maxHeight.isFinite
            ? math.max(constraints.maxHeight - _kMindestListenHoehe, 0.0)
            : double.infinity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxKopfHoehe),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titel und Bereiche teilen sich auf breiten
                      // Fenstern eine Zeile; schmal brechen die Bereiche um.
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Steigerungen planen',
                            style: theme.textTheme.titleLarge,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final bereich in bereiche)
                                ChoiceChip(
                                  key: ValueKey(
                                    'advancement-bereich-${bereich.name}',
                                  ),
                                  label: Text(bereich.label),
                                  selected: abschnitt.bereich == bereich,
                                  onSelected: (_) => _waehleBereich(bereich),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Werte und Voraussetzungen verwenden die Vorschau. '
                        'Vorgemerkte Änderungen werden erst beim Übernehmen gespeichert.',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (abschnitt.bereich.abschnitte.length > 1) ...[
                        const SizedBox(height: 8),
                        // Abschnitte laufen waagerecht, damit sie auf
                        // schmalen Geräten keinen Umbruch beanspruchen.
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final eintrag
                                  in abschnitt.bereich.abschnitte)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'advancement-abschnitt-${eintrag.name}',
                                    ),
                                    label: Text(eintrag.label),
                                    selected: abschnitt == eintrag,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) =>
                                        setState(() => _abschnitt = eintrag),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('advancement-search'),
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: '${abschnitt.label} durchsuchen',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Suche löschen',
                                  onPressed: () =>
                                      setState(_searchController.clear),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${filtered.length} '
                            '${aktiveEintraege ? 'aktive Einträge' : 'Einträge'}'
                            ' · ${session.preview.apAvailable} AP verfügbar',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.codexTheme.inkMuted,
                            ),
                          ),
                          if (abschnitt.supportsActivation)
                            OutlinedButton.icon(
                              key: ValueKey(
                                'advancement-activate-${abschnitt.name}',
                              ),
                              onPressed: session.isSaving || _dialogOpen
                                  ? null
                                  : () => _activate(abschnitt, session),
                              icon: const Icon(Icons.add),
                              label: Text(abschnitt.activationLabel),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _abschnittInhalt(
                session,
                abschnitt,
                options: options,
                filtered: filtered,
                plannedTargets: plannedTargets,
                showImpact: showImpact,
                showBridge: showBridge,
                query: query,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _abschnittInhalt(
    AdvancementSession session,
    _Abschnitt abschnitt, {
    required List<AdvancementOption> options,
    required List<AdvancementOption> filtered,
    required Set<String> plannedTargets,
    required bool showImpact,
    required bool showBridge,
    required String query,
  }) {
    final onPlan = session.isSaving || _dialogOpen ? null : _plan;
    switch (abschnitt.darstellung) {
      case _Darstellung.baum:
        final controller = ref.read(
          advancementSessionProvider(widget.heroId).notifier,
        );
        return AdvancementSkillTreeView(
          key: ValueKey('advancement-baum-${abschnitt.name}'),
          session: session,
          options: options.where(abschnitt.matches).toList(growable: false),
          query: query,
          festerBereich: abschnitt.baumBereich,
          kopfZusatz: abschnitt == _Abschnitt.karmaSf
              ? AdvancementGottheitWahl(
                  gottheit: session.preview.gottheit,
                  onChanged: session.isSaving
                      ? null
                      : (gottheit) => _speichereGottheit(controller, gottheit),
                )
              : null,
          onShowInapplicableChanged:
              controller.setShowInapplicableSpecialAbilities,
          onPlan: onPlan,
        );
      case _Darstellung.merkmale:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: AdvancementMerkmalSection(
            session: session,
            options: filtered,
            vorteile: abschnitt == _Abschnitt.vorteile,
            onPlan: onPlan,
          ),
        );
      case _Darstellung.merkmalskenntnisse:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: AdvancementMerkmalskenntnisSection(
            session: session,
            options: filtered,
            onPlan: onPlan,
          ),
        );
      case _Darstellung.werte:
        return _valueCatalog(
          session,
          abschnitt,
          filtered,
          plannedTargets,
          showImpact: showImpact,
          showBridge: showBridge,
          query: query,
        );
    }
  }

  // Fehler beim Speichern der Gottheit erscheinen wie Planungsfehler.
  Future<void> _speichereGottheit(
    AdvancementSessionController controller,
    String gottheit,
  ) async {
    try {
      await controller.setGottheit(gottheit);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  // Eine gemeinsame Kacheldarstellung hält alle numerischen Kategorien kompakt.
  Widget _valueCatalog(
    AdvancementSession session,
    _Abschnitt abschnitt,
    List<AdvancementOption> options,
    Set<String> plannedTargets, {
    required bool showImpact,
    required bool showBridge,
    required String query,
  }) {
    final rules = AdvancementContext(
      hero: session.preview,
      catalog: session.catalog,
    );
    Widget tile(AdvancementOption option, {TalentGruppe? gruppe}) {
      final spec =
          option.kind == AdvancementKind.talent && option.currentValue >= 0
          ? resolveTalentSpecialization(rules, option.targetId, const {
              'action': 'specialization',
            })
          : null;
      final old = session.preview.talents[option.targetId];
      final kampf = abschnitt == _Abschnitt.kampftalente;
      return AdvancementValueTile(
        option: option,
        planned: plannedTargets.contains(
          '${option.kind.name}:${option.targetId}',
        ),
        onPlan: session.isSaving || _dialogOpen ? null : () => _plan(option),
        specialization: spec,
        specializations: spec == null || old == null
            ? const []
            : advancementTalentSpecializations(old),
        onSpecialize: session.isSaving || _dialogOpen
            ? null
            : () => _specialize(option.targetId),
        gruppe: gruppe,
        zusatzZeilen: kampf ? _meisterZeilen(session, option) : const [],
        zusatzAktionen: kampf
            ? _meisterAktionen(session, rules, option)
            : const [],
      );
    }

    Widget baseTile(AdvancementOption option) => AdvancementBaseValueTile(
      option: option,
      planned: plannedTargets.contains(
        '${option.kind.name}:${option.targetId}',
      ),
      onPlan: session.isSaving || _dialogOpen ? null : () => _plan(option),
    );

    Widget tiles(
      List<AdvancementOption> values, {
      double minWidth = 260,
      Widget Function(AdvancementOption option)? builder,
    }) => LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = math.max(
          1,
          (constraints.maxWidth / (minWidth * scale)).floor(),
        );
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in values)
              SizedBox(width: width, child: (builder ?? tile)(option)),
          ],
        );
      },
    );
    final attributes = options
        .where((o) => o.kind == AdvancementKind.attribute)
        .toList();
    final bought = options
        .where((o) => o.kind == AdvancementKind.boughtStat)
        .toList();
    // Talente, Sprachen und Schriften erscheinen nach Gruppen getrennt, damit
    // die gewünschte Gruppe über die Sprungleiste schnell erreichbar ist.
    final gruppiert =
        abschnitt == _Abschnitt.talente || abschnitt == _Abschnitt.sprachen;
    final gruppen = gruppiert
        ? gruppiereTalente(options, session.catalog)
        : const <TalentGruppe, List<AdvancementOption>>{};
    final liste = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showImpact)
            LayoutBuilder(
              builder: (context, constraints) {
                // Eigenschaften und zugekaufte Basiswerte teilen sich den
                // Kachelbereich; die Berechnung steht getrennt daneben bzw.
                // darunter.
                final werte = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    tiles(attributes),
                    if (bought.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _BasiswertUeberschrift(),
                      const SizedBox(height: 10),
                      tiles(bought, minWidth: 190, builder: baseTile),
                    ],
                  ],
                );
                final berechnung = AdvancementImpactPanel(session: session);
                if (constraints.maxWidth < 760 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [werte, const SizedBox(height: 16), berechnung],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: werte),
                    const SizedBox(width: 16),
                    SizedBox(width: 280, child: berechnung),
                  ],
                );
              },
            )
          else if (gruppiert)
            for (final eintrag in gruppen.entries) ...[
              KeyedSubtree(
                key: _gruppenAnker[eintrag.key],
                child: TalentGruppenKopf(
                  gruppe: eintrag.key,
                  anzahl: eintrag.value.length,
                  eingeklappt: _eingeklappt.contains(eintrag.key),
                  onUmschalten: () => setState(() {
                    if (!_eingeklappt.remove(eintrag.key)) {
                      _eingeklappt.add(eintrag.key);
                    }
                  }),
                ),
              ),
              if (!_eingeklappt.contains(eintrag.key))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: tiles(
                    eintrag.value,
                    builder: (option) => tile(option, gruppe: eintrag.key),
                  ),
                ),
              const SizedBox(height: 20),
            ]
          else if (options.isNotEmpty)
            tiles(options),
          if (options.isEmpty) _buildEmptyState(context, abschnitt, query),
          if (showBridge)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('advancement-activate-hint-${abschnitt.name}'),
                onPressed: () => _activate(
                  abschnitt,
                  session,
                  initialQuery: _searchController.text.trim(),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Weitere Treffer im Erwerbsblatt suchen'),
              ),
            ),
        ],
      ),
    );
    if (!gruppiert || gruppen.isEmpty) return liste;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalentGruppenLeiste(
          gruppen: {
            for (final eintrag in gruppen.entries)
              eintrag.key: eintrag.value.length,
          },
          eingeklappt: _eingeklappt,
          onSpringen: _springeZuGruppe,
        ),
        Expanded(child: liste),
      ],
    );
  }

  // Klappt die Gruppe bei Bedarf auf und scrollt ihren Kopf an den oberen Rand.
  void _springeZuGruppe(TalentGruppe gruppe) {
    final wasCollapsed = _eingeklappt.contains(gruppe);
    void scrollen() {
      final anker = _gruppenAnker[gruppe]?.currentContext;
      if (anker == null || !anker.mounted) return;
      Scrollable.ensureVisible(
        anker,
        alignment: 0,
        duration: MediaQuery.disableAnimationsOf(anker)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }

    if (!wasCollapsed) {
      scrollen();
      return;
    }
    setState(() => _eingeklappt.remove(gruppe));
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollen());
  }

  // Der Erwerb nutzt denselben Controller und dieselbe Fehlerrückmeldung wie Steigerungen.
  Future<void> _specialize(String talentId) async {
    final session = ref.read(advancementSessionProvider(widget.heroId));
    if (session == null || session.isSaving || _dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      final entry = await showAdvancementSpecializationDialog(
        context: context,
        session: session,
        talentId: talentId,
      );
      if (entry != null && mounted) {
        ref.read(advancementSessionProvider(widget.heroId).notifier).add(entry);
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  // Bestehende Waffenmeisterschaften stehen direkt am Kampftalent.
  List<String> _meisterZeilen(
    AdvancementSession session,
    AdvancementOption option,
  ) {
    final meister = session.preview.combatConfig.waffenmeisterschaften
        .where((wm) => wm.talentId == option.targetId)
        .map(
          (wm) =>
              wm.weaponType.trim().isEmpty ? 'Waffenmeister' : wm.weaponType,
        )
        .toList();
    final gross = grossmeisterFuerTalent(session.catalog, option.targetId);
    final rules = AdvancementContext(
      hero: session.preview,
      catalog: session.catalog,
    );
    final hatGross =
        gross != null &&
        rules.ownedAbilityIds(AdvancementKind.combatAbility).contains(gross.id);
    return [
      if (meister.isNotEmpty) 'Waffenmeister: ${meister.join(', ')}',
      if (hatGross) gross.name,
    ];
  }

  // Waffenmeister für jedes aktive Kampftalent, der Waffen-Großmeister nur
  // für epische Helden mit Waffenmeisterschaft im Talent.
  List<Widget> _meisterAktionen(
    AdvancementSession session,
    AdvancementContext rules,
    AdvancementOption option,
  ) {
    if (option.currentValue < 0) return const [];
    final gesperrt = session.isSaving || _dialogOpen;
    final meister = resolveWaffenmeister(rules, option.targetId, const {
      'action': kWaffenmeisterAktion,
    });
    final gross = grossmeisterFuerTalent(session.catalog, option.targetId);
    final grossOption = gross == null || !session.preview.isEpisch
        ? null
        : resolveAdvancementOptionIn(
            context: rules,
            kind: AdvancementKind.combatAbility,
            targetId: gross.id,
          );
    return [
      if (meister != null)
        Tooltip(
          message: meister.unavailableReason ?? meister.complexityHint ?? '',
          child: OutlinedButton(
            key: ValueKey('advancement-waffenmeister-${option.targetId}'),
            onPressed: gesperrt || meister.unavailableReason != null
                ? null
                : () => _plan(meister),
            child: const Text('+ Waffenmeister'),
          ),
        ),
      if (grossOption != null && !grossOption.isOwned)
        Tooltip(
          message: grossOption.unavailableReason ?? grossOption.ability!.kosten,
          child: OutlinedButton(
            key: ValueKey('advancement-grossmeister-${option.targetId}'),
            onPressed: gesperrt || grossOption.unavailableReason != null
                ? null
                : () => _plan(grossOption),
            child: const Text('+ Waffen-Großmeister'),
          ),
        ),
    ];
  }

  // Ohne Suchtext ist die Liste nicht gefiltert, sondern schlicht leer.
  Widget _buildEmptyState(
    BuildContext context,
    _Abschnitt abschnitt,
    String query,
  ) {
    if (query.isNotEmpty || !abschnitt.supportsActivation) {
      return const Center(child: Text('Keine passenden Einträge.'));
    }
    return Column(
      key: ValueKey('advancement-empty-${abschnitt.name}'),
      children: [
        Text(abschnitt.emptyText, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'Über „${abschnitt.activationLabel}" nimmst du Einträge auf.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.codexTheme.inkMuted),
        ),
      ],
    );
  }

  // Das Blatt schließt sich selbst; geplant wird erst danach über _plan.
  Future<void> _activate(
    _Abschnitt abschnitt,
    AdvancementSession session, {
    String initialQuery = '',
  }) async {
    if (session.isSaving || _dialogOpen) return;
    final alleAnzeigen = session.preview.showInapplicableSpecialAbilities;
    setState(() => _dialogOpen = true);
    AdvancementOption? picked;
    try {
      picked = await showAdvancementActivationSheet(
        context: context,
        heroId: widget.heroId,
        title: abschnitt.activationLabel,
        kinds: abschnitt.kinds,
        // Fremde Traditionen und Gottheiten bleiben auch hier verborgen,
        // solange „Unpassende anzeigen“ aus ist.
        filter: (option) =>
            abschnitt.matches(option) &&
            (alleAnzeigen || !passtNichtZumHelden(option)),
        initialQuery: initialQuery,
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
    if (picked == null || !mounted) return;
    await _plan(picked);
  }

  // Verhindert doppelte Dialoge und bindet Rückmeldungen an dieselbe Runde.
  Future<void> _plan(AdvancementOption option) async {
    final session = ref.read(advancementSessionProvider(widget.heroId));
    if (session == null || session.isSaving || _dialogOpen) return;
    setState(() => _dialogOpen = true);
    try {
      final entry = await showAdvancementPlanDialog(
        context: context,
        session: session,
        option: option,
      );
      if (entry == null || !mounted) return;
      ref.read(advancementSessionProvider(widget.heroId).notifier).add(entry);
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }
}
