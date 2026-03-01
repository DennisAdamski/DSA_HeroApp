import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/validation/combat_talent_validation.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_be_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

part 'hero_talents/hero_talents_grouping.dart';
part 'hero_talents/hero_talents_info_card.dart';
part 'hero_talents/hero_talents_tables.dart';
part 'hero_talents/hero_talents_cells.dart';

enum _TalentTabScope { nonCombat, combat }

class HeroTalentsTab extends _HeroTalentTableTab {
  const HeroTalentsTab({
    super.key,
    required super.heroId,
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
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final _TalentTabScope scope;
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
  final Map<String, TextEditingController> _cellControllers =
      <String, TextEditingController>{};

  HeroSheet? _latestHero;
  Map<String, HeroTalentEntry> _draftTalents = <String, HeroTalentEntry>{};
  Set<String> _draftHiddenTalentIds = <String>{};
  Set<String> _invalidCombatTalentIds = <String>{};
  String _draftTalentSpecialAbilities = '';
  bool _visibilityMode = false;
  late final TextEditingController _talentSpecialAbilitiesController;

  @override
  void initState() {
    super.initState();
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
      _subTabController = TabController(length: 2, vsync: this);
      _subTabController!.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
    _talentSpecialAbilitiesController = TextEditingController();
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
    _talentSpecialAbilitiesController.dispose();
    _tableRevision.dispose();
    super.dispose();
  }

  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
      ),
    );
  }

  void _syncDraftFromHero(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) {
      return;
    }
    _resetCellControllers();
    _draftTalents = Map<String, HeroTalentEntry>.from(hero.talents);
    _draftHiddenTalentIds = normalizeHiddenTalentIds(hero.hiddenTalentIds);
    _draftTalentSpecialAbilities = hero.talentSpecialAbilities;
    _talentSpecialAbilitiesController.text = _draftTalentSpecialAbilities;
    _invalidCombatTalentIds = <String>{};
    _visibilityMode = false;
  }

  void _resetCellControllers() {
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _cellControllers.clear();
  }

  TextEditingController _controllerFor(
    String talentId,
    String field,
    String initialValue,
  ) {
    final key = _controllerKey(talentId, field);
    return _cellControllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  String _controllerKey(String talentId, String field) {
    return '$talentId::$field';
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _invalidCombatTalentIds = <String>{};
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    if (widget.scope == _TalentTabScope.combat) {
      final catalog = await ref.read(rulesCatalogProvider.future);
      final issues = validateCombatTalentDistribution(
        talents: catalog.talents,
        talentEntries: _draftTalents,
        filter: _matchesScope,
      );
      if (issues.isNotEmpty) {
        if (mounted) {
          setState(() {
            _invalidCombatTalentIds = issues
                .map((entry) => entry.talentId)
                .toSet();
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(issues.first.message)));
        }
        return;
      }
      _invalidCombatTalentIds = <String>{};
    }
    final updatedHero = hero.copyWith(
      talents: Map<String, HeroTalentEntry>.from(_draftTalents),
      hiddenTalentIds: _draftHiddenTalentIds.toList(growable: false),
      talentSpecialAbilities: _draftTalentSpecialAbilities,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }
    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Talente gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _invalidCombatTalentIds = <String>{};
    _editController.markDiscarded();
  }

  HeroTalentEntry _entryForTalent(String talentId) {
    return _draftTalents[talentId] ?? const HeroTalentEntry();
  }

  void _updateIntField(String talentId, String field, String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final current = _entryForTalent(talentId);
    final updated = switch (field) {
      'talentValue' => current.copyWith(talentValue: parsed),
      'atValue' => current.copyWith(atValue: parsed),
      'paValue' => current.copyWith(paValue: parsed),
      'modifier' => current.copyWith(modifier: parsed),
      'specialExperiences' => current.copyWith(specialExperiences: parsed),
      _ => current,
    };
    _draftTalents[talentId] = updated;
    _invalidCombatTalentIds.remove(talentId);
    _markFieldChanged();
  }

  void _updateStringField(String talentId, String field, String raw) {
    final current = _entryForTalent(talentId);
    final updated = switch (field) {
      'specializations' => current.copyWith(
        specializations: raw,
        combatSpecializations: _splitSpecializationTokens(raw),
      ),
      _ => current,
    };
    _draftTalents[talentId] = updated;
    _markFieldChanged();
  }

  void _updateGifted(String talentId, bool value) {
    final current = _entryForTalent(talentId);
    _draftTalents[talentId] = current.copyWith(gifted: value);
    _markFieldChanged();
  }

  void _updateCombatSpecializations(String talentId, List<String> values) {
    final current = _entryForTalent(talentId);
    final normalized = _normalizeStringList(values);
    _draftTalents[talentId] = current.copyWith(
      combatSpecializations: normalized,
      specializations: normalized.join(', '),
    );
    _markFieldChanged();
  }

  void _toggleHidden(String talentId) {
    if (_draftHiddenTalentIds.contains(talentId)) {
      _draftHiddenTalentIds.remove(talentId);
    } else {
      _draftHiddenTalentIds.add(talentId);
    }
    _markFieldChanged();
  }

  void _setHiddenForGroup(List<TalentDef> talents, {required bool hidden}) {
    for (final talent in talents) {
      if (hidden) {
        _draftHiddenTalentIds.add(talent.id);
      } else {
        _draftHiddenTalentIds.remove(talent.id);
      }
    }
    _markFieldChanged();
  }

  void _setVisibilityMode(bool enabled) {
    if (_visibilityMode == enabled) {
      return;
    }
    setState(() {
      _visibilityMode = enabled;
    });
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    _tableRevision.value++;
    _editController.markFieldChanged();
  }

  bool _isHidden(String talentId) => _draftHiddenTalentIds.contains(talentId);

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
          final combatBaseBe = widget.scope == _TalentTabScope.nonCombat
              ? computeCombatPreviewStats(
                  hero,
                  state,
                  catalogTalents: catalog.talents,
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
              final grouped = _groupTalents(relevantTalents);
              final groups = grouped.keys.toList()
                ..sort((a, b) {
                  final pa = _groupPriority(a);
                  final pb = _groupPriority(b);
                  if (pa != pb) {
                    return pa.compareTo(pb);
                  }
                  return a.toLowerCase().compareTo(b.toLowerCase());
                });
              final visibleGroups = groups
                  .where((group) {
                    if (_editController.isEditing || _visibilityMode) {
                      return true;
                    }
                    final talents = grouped[group] ?? const <TalentDef>[];
                    return talents.any((talent) => !_isHidden(talent.id));
                  })
                  .toList(growable: false);

              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                children: [
                  if (widget.scope == _TalentTabScope.nonCombat)
                    _buildTopActionBar(
                      heroId: hero.id,
                      combatBaseBe: combatBaseBe ?? 0,
                      activeTalentBe: activeTalentBe,
                    ),
                  if (widget.scope == _TalentTabScope.combat)
                    _buildCombatVisibilityActionBar(),
                  if (widget.scope == _TalentTabScope.nonCombat)
                    TabBar(
                      controller: _subTabController,
                      tabs: const [
                        Tab(text: 'Talente'),
                        Tab(text: 'Sonderfertigkeiten'),
                      ],
                    ),
                  if (widget.scope == _TalentTabScope.nonCombat &&
                      _subTabController!.index == 1)
                    _buildSpecialAbilitiesTab(),
                  if (widget.scope == _TalentTabScope.combat ||
                      _subTabController?.index == 0)
                  ...visibleGroups.map((group) {
                    final talents = List<TalentDef>.from(grouped[group]!)
                      ..sort(
                        (a, b) => a.name.toLowerCase().compareTo(
                          b.name.toLowerCase(),
                        ),
                      );
                    final showAllTalents = _editController.isEditing || _visibilityMode;
                    final visibleTalents = showAllTalents
                        ? talents
                        : talents
                              .where((talent) => !_isHidden(talent.id))
                              .toList(growable: false);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        childrenPadding: EdgeInsets.zero,
                        title: Text(group),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${visibleTalents.length}/${talents.length} sichtbar',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_visibilityMode)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      TextButton(
                                        key: ValueKey<String>(
                                          'talents-group-show-all-$group',
                                        ),
                                        onPressed: () => _setHiddenForGroup(
                                          talents,
                                          hidden: false,
                                        ),
                                        child: const Text('Alle einblenden'),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        key: ValueKey<String>(
                                          'talents-group-hide-all-$group',
                                        ),
                                        onPressed: () => _setHiddenForGroup(
                                          talents,
                                          hidden: true,
                                        ),
                                        child: const Text('Alle ausblenden'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        children: [
                          widget.scope == _TalentTabScope.combat
                              ? _buildCombatTalentsTable(
                                  talents: visibleTalents,
                                  showVisibilityControls: _visibilityMode,
                                )
                              : _buildTalentsTable(
                                  talents: visibleTalents,
                                  effectiveAttributes: effectiveAttributes!,
                                  activeBaseBe: activeTalentBe,
                                  showVisibilityControls: _visibilityMode,
                                ),
                        ],
                      ),
                    );
                  }),
                ],
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
