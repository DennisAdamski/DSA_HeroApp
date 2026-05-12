import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_language_entry.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_value_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents/combat_specialization_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/edit_aware_table_cell.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/steigerungs_dialog.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

part 'hero_talents/hero_talents_cells.dart';
part 'hero_talents/hero_talents_edit_actions.dart';
part 'hero_talents/hero_talents_grouping.dart';
part 'hero_talents/hero_talents_info_card.dart';
part 'hero_talents/hero_talents_mutations.dart';
part 'hero_talents/hero_talents_raise_actions.dart';
part 'hero_talents/hero_talents_tables.dart';
part 'hero_talents/hero_languages_tab.dart';
part 'hero_talents/meta_talent_dialogs.dart';
part 'hero_talents/talent_catalog_table.dart';
part 'hero_talents/talent_detail_dialog.dart';
part 'hero_talents/talent_modifiers_dialog.dart';

enum _TalentTabScope { nonCombat, combat }

class HeroTalentsTab extends _HeroTalentTableTab {
  const HeroTalentsTab({
    super.key,
    required super.heroId,
    super.showInlineActions = true,
    required super.onDirtyChanged,
    required super.onEditingChanged,
    required super.onRegisterDiscard,
    required super.onRegisterEditActions,
  }) : super(scope: _TalentTabScope.nonCombat);
}

class HeroCombatTalentsTab extends _HeroTalentTableTab {
  const HeroCombatTalentsTab({
    super.key,
    required super.heroId,
    super.showInlineActions = true,
    required super.onDirtyChanged,
    required super.onEditingChanged,
    required super.onRegisterDiscard,
    required super.onRegisterEditActions,
  }) : super(scope: _TalentTabScope.combat);
}

class _HeroTalentTableTab extends ConsumerStatefulWidget {
  const _HeroTalentTableTab({
    super.key,
    required this.heroId,
    required this.scope,
    required this.showInlineActions,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final _TalentTabScope scope;
  final bool showInlineActions;
  final void Function(bool isDirty) onDirtyChanged;
  final void Function(bool isEditing) onEditingChanged;
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<_HeroTalentTableTab> createState() =>
      _HeroTalentTableTabState();
}

class _HeroTalentTableTabState extends ConsumerState<_HeroTalentTableTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final WorkspaceTabEditController _editController;
  TabController? _subTabController;
  final ValueNotifier<int> _tableRevision = ValueNotifier<int>(0);
  final TextEditingController _searchController = TextEditingController();
  String _talentGroupFilter = '';
  final Map<String, TextEditingController> _cellControllers =
      <String, TextEditingController>{};

  HeroSheet? _latestHero;
  List<TalentDef> _latestCatalogTalents = const <TalentDef>[];
  CatalogRuleResolver _latestCatalogRuleResolver = const CatalogRuleResolver();
  Map<String, HeroTalentEntry> _draftTalents = <String, HeroTalentEntry>{};
  List<HeroMetaTalent> _draftMetaTalents = <HeroMetaTalent>[];
  Set<String> _invalidCombatTalentIds = <String>{};
  List<TalentSpecialAbility> _draftTalentSpecialAbilities =
      <TalentSpecialAbility>[];
  Map<String, HeroLanguageEntry> _draftSprachen = <String, HeroLanguageEntry>{};
  Map<String, HeroScriptEntry> _draftSchriften = <String, HeroScriptEntry>{};
  String _draftMuttersprache = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _talentGroupFilter = _searchController.text;
        });
      }
    });
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    if (widget.scope == _TalentTabScope.nonCombat) {
      _subTabController = TabController(length: 3, vsync: this);
      _subTabController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _subTabController?.dispose();
    _tableRevision.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    UiRebuildObserver.bump('hero_talents_tab');
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;
    _syncDraftFromHero(hero);

    final stateAsync = ref.watch(heroStateProvider(widget.heroId));
    final catalogAsync = ref.watch(rulesCatalogProvider);

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      data: (state) => catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Katalog-Fehler: $error')),
        data: (catalog) {
          _latestCatalogTalents = catalog.talents;
          _latestCatalogRuleResolver = catalog.ruleResolver;
          final combatBaseBe = widget.scope == _TalentTabScope.nonCombat
              ? computeCombatPreviewStats(
                  hero,
                  state,
                  catalogTalents: catalog.talents,
                  catalogManeuvers: catalog.maneuvers,
                  catalogCombatSpecialAbilities: catalog.combatSpecialAbilities,
                ).beKampf
              : null;
          final talentBeOverride = ref.watch(talentBeOverrideProvider(hero.id));
          final activeTalentBe = combatBaseBe == null
              ? 0
              : (talentBeOverride ?? combatBaseBe);
          final relevantTalents = catalog.talents
              .where(_matchesScope)
              .toList(growable: false);
          final effectiveAttributes = widget.scope == _TalentTabScope.nonCombat
              ? computeEffectiveAttributes(
                  hero,
                  tempAttributeMods: state.tempAttributeMods,
                )
              : null;
          return ValueListenableBuilder<int>(
            valueListenable: _tableRevision,
            builder: (context, revision, child) {
              final showTalentsHeader = MediaQuery.sizeOf(context).width >= 600;
              // Nur Talente anzeigen, die im Draft aktiv sind.
              final activeTalents = relevantTalents
                  .where((t) => _draftTalents.containsKey(t.id))
                  .toList(growable: false);
              final grouped = _groupTalents(activeTalents);
              final groups = grouped.keys.toList()
                ..sort((a, b) {
                  final pa = _groupPriority(a);
                  final pb = _groupPriority(b);
                  if (pa != pb) {
                    return pa.compareTo(pb);
                  }
                  return a.toLowerCase().compareTo(b.toLowerCase());
                });
              final filterQuery = _talentGroupFilter.trim().toLowerCase();

              final talentTabChildren = <Widget>[
                  if (showTalentsHeader) ...[
                    CodexTabHeader(
                      title: widget.scope == _TalentTabScope.combat
                          ? 'Kampftechniken'
                          : 'Talente & Bildung',
                      subtitle: widget.scope == _TalentTabScope.combat
                          ? 'AT/PA-Verteilung, Waffengattungen und Spezialisierungen im taktischen Codex.'
                          : 'Talentgruppen, Sonderfertigkeiten sowie Sprachen und Schriften in verdichteter Darstellung.',
                      assetPath: widget.scope == _TalentTabScope.combat
                          ? 'assets/ui/codex/combat_silhouette.png'
                          : 'assets/ui/codex/compass_mark.png',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.scope == _TalentTabScope.nonCombat &&
                      widget.showInlineActions)
                    _buildTopActionBar(
                      heroId: hero.id,
                      combatBaseBe: combatBaseBe ?? 0,
                      activeTalentBe: activeTalentBe,
                    ),
                  if (widget.scope == _TalentTabScope.combat &&
                      widget.showInlineActions)
                    _buildCombatActionBar(allTalents: relevantTalents),
                  if (widget.scope == _TalentTabScope.nonCombat)
                    TabBar(
                      controller: _subTabController,
                      tabs: const [
                        Tab(text: 'Talente'),
                        Tab(text: 'Sonderfertigkeiten'),
                        Tab(text: 'Sprachen & Schriften'),
                      ],
                    ),
                  if (widget.scope == _TalentTabScope.nonCombat &&
                      _subTabController?.index == 0)
                    _buildSearchHeader(
                      allTalents: relevantTalents,
                      allCatalogTalents: catalog.talents,
                    ),
                  if (widget.scope == _TalentTabScope.nonCombat &&
                      _subTabController!.index == 1)
                    _buildSpecialAbilitiesTab(),
                  if (widget.scope == _TalentTabScope.nonCombat &&
                      _subTabController!.index == 2)
                    _SprachenSchriftenTab(
                      heroId: widget.heroId,
                      draftSprachen: _draftSprachen,
                      draftSchriften: _draftSchriften,
                      draftMuttersprache: _draftMuttersprache,
                      alleSprachen: catalog.sprachen,
                      alleSchriften: catalog.schriften,
                      isEditing: _editController.isEditing,
                      onPrepareAddEntry: _ensureEditingSession,
                      onSprachWertChanged: (id, wert) {
                        final entry =
                            _draftSprachen[id] ?? const HeroLanguageEntry();
                        _draftSprachen[id] = entry.copyWith(wert: wert);
                        _markFieldChanged();
                      },
                      onSchriftWertChanged: (id, wert) {
                        final entry =
                            _draftSchriften[id] ?? const HeroScriptEntry();
                        _draftSchriften[id] = entry.copyWith(wert: wert);
                        _markFieldChanged();
                      },
                      onMuttersprachChanged: (id) {
                        setState(() {
                          _draftMuttersprache = _draftMuttersprache == id
                              ? ''
                              : id;
                        });
                        _markFieldChanged();
                      },
                      onAddSprache: (id) {
                        if (!_draftSprachen.containsKey(id)) {
                          _draftSprachen[id] = const HeroLanguageEntry();
                          _markFieldChanged();
                        }
                      },
                      onRemoveSprache: (id) {
                        _draftSprachen.remove(id);
                        if (_draftMuttersprache == id) {
                          _draftMuttersprache = '';
                        }
                        _markFieldChanged();
                      },
                      onAddSchrift: (id) {
                        if (!_draftSchriften.containsKey(id)) {
                          _draftSchriften[id] = const HeroScriptEntry();
                          _markFieldChanged();
                        }
                      },
                      onRemoveSchrift: (id) {
                        _draftSchriften.remove(id);
                        _markFieldChanged();
                      },
                    ),
                  if (widget.scope == _TalentTabScope.combat ||
                      _subTabController?.index == 0)
                    ...groups.expand((group) {
                      final allGroupTalents =
                          List<TalentDef>.from(grouped[group]!)..sort(
                            (a, b) => a.name.toLowerCase().compareTo(
                              b.name.toLowerCase(),
                            ),
                          );
                      final talents = filterQuery.isEmpty
                          ? allGroupTalents
                          : allGroupTalents
                                .where(
                                  (t) => t.name.toLowerCase().contains(
                                    filterQuery,
                                  ),
                                )
                                .toList(growable: false);
                      if (talents.isEmpty) return const <Widget>[];
                      return [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CodexSectionCard(
                            title: group,
                            subtitle: '${talents.length} Talente',
                            child: widget.scope == _TalentTabScope.combat
                                ? _buildCombatTalentsTable(talents: talents)
                                : _buildTalentsTable(
                                    talents: talents,
                                    effectiveAttributes: effectiveAttributes!,
                                    activeBaseBe: activeTalentBe,
                                    inventoryTalentMods:
                                        ref
                                            .watch(
                                              heroComputedProvider(
                                                widget.heroId,
                                              ),
                                            )
                                            .asData
                                            ?.value
                                            .inventoryTalentMods ??
                                        const {},
                                  ),
                          ),
                        ),
                      ];
                    }),
                  if (widget.scope == _TalentTabScope.nonCombat &&
                      (_subTabController?.index == 0) &&
                      _draftMetaTalents.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final visibleMeta = filterQuery.isEmpty
                            ? _draftMetaTalents
                            : _draftMetaTalents
                                  .where(
                                    (m) => m.name.toLowerCase().contains(
                                      filterQuery,
                                    ),
                                  )
                                  .toList(growable: false);
                        if (visibleMeta.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _buildMetaTalentsCard(
                          metaTalents: visibleMeta,
                          catalogTalents: catalog.talents,
                          effectiveAttributes: effectiveAttributes!,
                          activeBaseBe: activeTalentBe,
                        );
                      },
                    ),
              ];
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                itemCount: talentTabChildren.length,
                itemBuilder: (_, index) => talentTabChildren[index],
              );
            },
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
