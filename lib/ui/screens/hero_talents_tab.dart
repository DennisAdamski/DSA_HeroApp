import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_be_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

enum _TalentTabScope { nonCombat, combat }

class _CombatValidationIssue {
  const _CombatValidationIssue({required this.talentId, required this.message});

  final String talentId;
  final String message;
}

bool isCombatTalent(TalentDef talent) {
  if (talent.group.trim().toLowerCase() == 'kampftalent') {
    return true;
  }
  if (talent.weaponCategory.trim().isNotEmpty) {
    return true;
  }
  final type = talent.type.trim().toLowerCase();
  return type == 'nahkampf' || type == 'fernkampf';
}

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
    with AutomaticKeepAliveClientMixin {
  late final WorkspaceTabEditController _editController;
  final Map<String, TextEditingController> _cellControllers =
      <String, TextEditingController>{};

  HeroSheet? _latestHero;
  Map<String, HeroTalentEntry> _draftTalents = <String, HeroTalentEntry>{};
  Set<String> _draftHiddenTalentIds = <String>{};
  Set<String> _invalidCombatTalentIds = <String>{};
  int? _talentBeOverride;
  late final TextEditingController _talentBeOverrideController;

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
    _talentBeOverrideController = TextEditingController();
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
    _talentBeOverrideController.dispose();
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
    final signature = jsonEncode({
      'talents': hero.talents.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'hiddenTalentIds': hero.hiddenTalentIds,
    });
    if (!_editController.shouldSync(signature, force: force)) {
      return;
    }
    _resetCellControllers();
    _draftTalents = Map<String, HeroTalentEntry>.from(hero.talents);
    _draftHiddenTalentIds = _normalizedHiddenTalentIds(hero.hiddenTalentIds);
    _invalidCombatTalentIds = <String>{};
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
      final issues = _validateCombatTalentDistribution(catalog.talents);
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
      'specialAbilities' => current.copyWith(specialAbilities: raw),
      _ => current,
    };
    _draftTalents[talentId] = updated;
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

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _editController.markFieldChanged();
  }

  bool _isHidden(String talentId) => _draftHiddenTalentIds.contains(talentId);

  void _updateTalentBeOverride(String raw) {
    final trimmed = raw.trim();
    final nextValue = trimmed.isEmpty ? null : int.tryParse(trimmed);
    if (nextValue == _talentBeOverride) {
      return;
    }
    setState(() {
      _talentBeOverride = nextValue;
    });
  }

  void _clearTalentBeOverride() {
    if (_talentBeOverride == null && _talentBeOverrideController.text.isEmpty) {
      return;
    }
    _talentBeOverrideController.clear();
    setState(() {
      _talentBeOverride = null;
    });
  }

  Set<String> _normalizedHiddenTalentIds(Iterable<String> hiddenTalentIds) {
    final normalized = <String>{};
    for (final id in hiddenTalentIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  bool _matchesScope(TalentDef talent) {
    final combat = isCombatTalent(talent);
    return widget.scope == _TalentTabScope.combat ? combat : !combat;
  }

  String _groupName(TalentDef talent) {
    if (widget.scope == _TalentTabScope.combat) {
      final type = talent.type.trim();
      if (type.isEmpty) {
        return 'Kampf (ohne Typ)';
      }
      return type;
    }
    final group = talent.group.trim();
    if (group.isEmpty) {
      return 'Ohne Gruppe';
    }
    return group;
  }

  int _groupPriority(String group) {
    if (widget.scope == _TalentTabScope.combat) {
      final normalized = _normalizeGroupToken(group);
      if (normalized == 'nahkampf') {
        return 0;
      }
      if (normalized == 'fernkampf') {
        return 1;
      }
      return 99;
    }
    final normalized = _normalizeGroupToken(group);
    if (normalized == 'koerperlichetalente' ||
        normalized == 'korperlichetalente') {
      return 0;
    }
    if (normalized == 'gesellschaftlichetalente') {
      return 1;
    }
    if (normalized == 'naturtalente') {
      return 2;
    }
    if (normalized == 'wissenstalente') {
      return 3;
    }
    if (normalized == 'handwerklichetalente') {
      return 4;
    }
    return 99;
  }

  String _normalizeGroupToken(String raw) {
    var text = raw.toLowerCase().trim();
    text = text
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    return text.replaceAll(RegExp(r'[^a-z]'), '');
  }

  Map<String, List<TalentDef>> _groupTalents(List<TalentDef> talents) {
    final grouped = <String, List<TalentDef>>{};
    for (final talent in talents) {
      final group = _groupName(talent);
      grouped.putIfAbsent(group, () => <TalentDef>[]).add(talent);
    }
    return grouped;
  }

  List<String> _splitSpecializationTokens(String raw) {
    return _normalizeStringList(raw.split(RegExp(r'[\n,;]+')));
  }

  List<String> _weaponCategoryOptions(TalentDef talent) {
    return _normalizeStringList(
      talent.weaponCategory.split(RegExp(r'[\n,;]+')),
    );
  }

  List<String> _normalizeStringList(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      normalized.add(trimmed);
    }
    return List<String>.unmodifiable(normalized);
  }

  List<_CombatValidationIssue> _validateCombatTalentDistribution(
    List<TalentDef> talents,
  ) {
    final issues = <_CombatValidationIssue>[];
    final combatTalents = talents.where(_matchesScope);
    for (final talent in combatTalents) {
      final entry = _entryForTalent(talent.id);
      final taw = entry.talentValue;
      final at = entry.atValue;
      final pa = entry.paValue;
      final type = talent.type.trim().toLowerCase();

      if (taw < 0 || at < 0 || pa < 0) {
        issues.add(
          _CombatValidationIssue(
            talentId: talent.id,
            message:
                'Ungueltige Verteilung bei ${talent.name}: TaW, AT und PA muessen >= 0 sein.',
          ),
        );
        continue;
      }

      if (taw == 0) {
        if (at != 0 || pa != 0) {
          issues.add(
            _CombatValidationIssue(
              talentId: talent.id,
              message:
                  'Ungueltige Verteilung bei ${talent.name}: Bei TaW 0 muessen AT und PA ebenfalls 0 sein.',
            ),
          );
        }
        continue;
      }

      if (type == 'nahkampf') {
        if (at + pa != taw) {
          issues.add(
            _CombatValidationIssue(
              talentId: talent.id,
              message:
                  'Ungueltige Verteilung bei ${talent.name}: Bei Nahkampf muss AT + PA = TaW gelten.',
            ),
          );
        }
        continue;
      }

      if (type == 'fernkampf') {
        if (at != taw || pa != 0) {
          issues.add(
            _CombatValidationIssue(
              talentId: talent.id,
              message:
                  'Ungueltige Verteilung bei ${talent.name}: Bei Fernkampf muss AT = TaW und PA = 0 sein.',
            ),
          );
        }
        continue;
      }

      issues.add(
        _CombatValidationIssue(
          talentId: talent.id,
          message:
              'Ungueltiger Talenttyp bei ${talent.name}: "${talent.type}" ist weder Nahkampf noch Fernkampf.',
        ),
      );
    }
    return issues;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          final activeTalentBe = combatBaseBe == null
              ? null
              : (_talentBeOverride ?? combatBaseBe);
          final relevantTalents = catalog.talents
              .where(_matchesScope)
              .toList(growable: false);
          final effectiveAttributes = widget.scope == _TalentTabScope.nonCombat
              ? computeEffectiveAttributes(
                  hero,
                  tempAttributeMods: state.tempAttributeMods,
                )
              : null;
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
                if (_editController.isEditing) {
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
                _buildTalentBeInfoCard(
                  combatBaseBe: combatBaseBe ?? 0,
                  activeTalentBe: activeTalentBe ?? 0,
                ),
              ...visibleGroups.map((group) {
                final talents = List<TalentDef>.from(grouped[group]!)
                  ..sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );
                final visibleTalents = _editController.isEditing
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
                    subtitle: Text(
                      '${visibleTalents.length}/${talents.length} sichtbar',
                    ),
                    children: [
                      widget.scope == _TalentTabScope.combat
                          ? _buildCombatTalentsTable(talents: visibleTalents)
                          : _buildTalentsTable(
                              talents: visibleTalents,
                              effectiveAttributes: effectiveAttributes!,
                              activeBaseBe: activeTalentBe ?? 0,
                            ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTalentBeInfoCard({
    required int combatBaseBe,
    required int activeTalentBe,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'BE (Kampf): ${_formatWholeNumber(combatBaseBe)}',
              key: const ValueKey<String>('talents-be-combat-default'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: TextField(
                key: const ValueKey<String>('talents-be-override-field'),
                controller: _talentBeOverrideController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'BE Override',
                ),
                onChanged: _updateTalentBeOverride,
              ),
            ),
            IconButton(
              key: const ValueKey<String>('talents-be-override-clear'),
              tooltip: 'Temporaere BE zuruecksetzen',
              onPressed: _talentBeOverride == null
                  ? null
                  : _clearTalentBeOverride,
              icon: const Icon(Icons.clear),
            ),
            const SizedBox(width: 6),
            Text(
              'Aktive BE: ${_formatWholeNumber(activeTalentBe)}',
              key: const ValueKey<String>('talents-be-active-value'),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTalentsTable({
    required List<TalentDef> talents,
    required Attributes effectiveAttributes,
    required int activeBaseBe,
  }) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildTalentRow(
          talent: talent,
          effectiveAttributes: effectiveAttributes,
          isEditing: isEditing,
          activeBaseBe: activeBaseBe,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isEditing ? 1900 : 1800),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(220),
              1: const FixedColumnWidth(240),
              2: const FixedColumnWidth(70),
              3: const FixedColumnWidth(60),
              4: const FixedColumnWidth(60),
              5: const FixedColumnWidth(90),
              6: const FixedColumnWidth(90),
              7: const FixedColumnWidth(70),
              8: const FixedColumnWidth(120),
              9: const FixedColumnWidth(70),
              10: const FixedColumnWidth(190),
              11: const FixedColumnWidth(230),
              if (isEditing) 12: const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildCombatTalentsTable({required List<TalentDef> talents}) {
    final isEditing = _editController.isEditing;
    final rows = <TableRow>[
      _buildCombatHeaderRow(isEditing: isEditing),
      ...talents.map(
        (talent) => _buildCombatTalentRow(talent: talent, isEditing: isEditing),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: isEditing ? 1530 : 1440),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(220),
              1: const FixedColumnWidth(300),
              2: const FixedColumnWidth(220),
              3: const FixedColumnWidth(70),
              4: const FixedColumnWidth(60),
              5: const FixedColumnWidth(90),
              6: const FixedColumnWidth(90),
              7: const FixedColumnWidth(90),
              8: const FixedColumnWidth(230),
              if (isEditing) 9: const FixedColumnWidth(90),
            },
            children: rows,
          ),
        ),
      ),
    );
  }

  TableRow _buildHeaderRow({required bool isEditing}) {
    final cells = <Widget>[
      _headerCell('Talent-Name'),
      _headerCell('Eigenschaften'),
      _headerCell('Kompl.'),
      _headerCell('BE'),
      _headerCell('eBE'),
      _headerCell('TaW'),
      _headerCell('max TaW'),
      _headerCell('Mod'),
      _headerCell('TaW berechnet'),
      _headerCell('SE'),
      _headerCell('Spezialisierungen'),
      _headerCell('Sonderfertigkeiten'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildCombatHeaderRow({required bool isEditing}) {
    final cells = <Widget>[
      _headerCell('Talent-Name'),
      _headerCell('Waffengattung'),
      _headerCell('Ersatzweise'),
      _headerCell('Kompl.'),
      _headerCell('BE'),
      _headerCell('TaW'),
      _headerCell('AT'),
      _headerCell('PA'),
      _headerCell('Spezialisierung'),
    ];
    if (isEditing) {
      cells.add(_headerCell('Sichtbar'));
    }
    return TableRow(children: cells);
  }

  TableRow _buildTalentRow({
    required TalentDef talent,
    required Attributes effectiveAttributes,
    required bool isEditing,
    required int activeBaseBe,
  }) {
    final entry = _entryForTalent(talent.id);
    final ebe = computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be);
    final isHidden = _isHidden(talent.id);
    final nameLabel = isEditing && isHidden
        ? '${talent.name} (ausgeblendet)'
        : talent.name;

    final cells = <Widget>[
      _textCell(nameLabel, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(
        _buildShortAttributeLabel(effectiveAttributes, talent.attributes),
      ),
      _textCell(_fallback(talent.steigerung)),
      _textCell(_fallback(talent.be)),
      _textCell(
        _formatWholeNumber(ebe),
        key: ValueKey<String>('talents-field-${talent.id}-ebe-display'),
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue,
        isEditing: isEditing,
      ),
      _textCell('-'),
      _intInputCell(
        talentId: talent.id,
        field: 'modifier',
        value: entry.modifier,
        isEditing: isEditing,
      ),
      _textCell(
        _formatWholeNumber(_calculateComputedTaw(entry, ebe)),
        key: ValueKey<String>('talents-field-${talent.id}-computed-taw'),
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'specialExperiences',
        value: entry.specialExperiences,
        isEditing: isEditing,
      ),
      _textInputCell(
        talentId: talent.id,
        field: 'specializations',
        value: entry.specializations,
        isEditing: isEditing,
      ),
      _textInputCell(
        talentId: talent.id,
        field: 'specialAbilities',
        value: entry.specialAbilities,
        isEditing: isEditing,
      ),
    ];
    if (isEditing) {
      cells.add(_visibilityCell(talentId: talent.id, isHidden: isHidden));
    }

    return TableRow(
      decoration: BoxDecoration(
        color: isHidden && isEditing
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
      ),
      children: cells,
    );
  }

  TableRow _buildCombatTalentRow({
    required TalentDef talent,
    required bool isEditing,
  }) {
    final entry = _entryForTalent(talent.id);
    final isHidden = _isHidden(talent.id);
    final isInvalid = _invalidCombatTalentIds.contains(talent.id);
    final nameLabel = isEditing && isHidden
        ? '${talent.name} (ausgeblendet)'
        : talent.name;

    final cells = <Widget>[
      _textCell(nameLabel, key: ValueKey<String>('talents-row-${talent.id}')),
      _textCell(_fallback(talent.weaponCategory)),
      _textCell(_fallback(talent.alternatives)),
      _textCell(_fallback(talent.steigerung)),
      _textCell(_fallback(talent.be)),
      _intInputCell(
        talentId: talent.id,
        field: 'talentValue',
        value: entry.talentValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'atValue',
        value: entry.atValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _intInputCell(
        talentId: talent.id,
        field: 'paValue',
        value: entry.paValue,
        isEditing: isEditing,
        isError: isInvalid,
      ),
      _combatSpecializationCell(
        talent: talent,
        entry: entry,
        isEditing: isEditing,
      ),
    ];
    if (isEditing) {
      cells.add(_visibilityCell(talentId: talent.id, isHidden: isHidden));
    }

    final rowColor = isInvalid
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
        : (isHidden && isEditing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null);

    return TableRow(
      decoration: BoxDecoration(color: rowColor),
      children: cells,
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }

  Widget _textCell(String text, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Align(alignment: Alignment.centerLeft, child: Text(text)),
    );
  }

  Widget _combatSpecializationCell({
    required TalentDef talent,
    required HeroTalentEntry entry,
    required bool isEditing,
  }) {
    final options = _weaponCategoryOptions(talent);
    final selected = entry.combatSpecializations.isEmpty
        ? _splitSpecializationTokens(entry.specializations)
        : _normalizeStringList(entry.combatSpecializations);
    final label = selected.isEmpty ? '-' : selected.join(', ');
    if (!isEditing) {
      return _textCell(label);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          key: ValueKey<String>('talents-combat-spec-${talent.id}'),
          onPressed: options.isEmpty
              ? null
              : () async {
                  final result = await _showCombatSpecializationDialog(
                    title: 'Spezialisierungen: ${talent.name}',
                    options: options,
                    initialSelected: selected,
                  );
                  if (result == null) {
                    return;
                  }
                  _updateCombatSpecializations(talent.id, result);
                },
          child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Future<List<String>?> _showCombatSpecializationDialog({
    required String title,
    required List<String> options,
    required List<String> initialSelected,
  }) {
    final selected = <String>{...initialSelected};
    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options
                        .map(
                          (entry) => CheckboxListTile(
                            value: selected.contains(entry),
                            title: Text(entry),
                            dense: true,
                            onChanged: (enabled) {
                              setDialogState(() {
                                if (enabled == true) {
                                  selected.add(entry);
                                } else {
                                  selected.remove(entry);
                                }
                              });
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    final normalized = _normalizeStringList(selected);
                    Navigator.of(context).pop(normalized);
                  },
                  child: const Text('Uebernehmen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _intInputCell({
    required String talentId,
    required String field,
    required int value,
    required bool isEditing,
    bool isError = false,
  }) {
    final controller = _controllerFor(talentId, field, value.toString());
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: TextField(
        key: ValueKey<String>('talents-field-$talentId-$field'),
        controller: controller,
        readOnly: !isEditing,
        keyboardType: TextInputType.number,
        decoration: _cellInputDecoration(isError: isError),
        onChanged: isEditing
            ? (raw) => _updateIntField(talentId, field, raw)
            : null,
      ),
    );
  }

  Widget _textInputCell({
    required String talentId,
    required String field,
    required String value,
    required bool isEditing,
  }) {
    final controller = _controllerFor(talentId, field, value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: TextField(
        key: ValueKey<String>('talents-field-$talentId-$field'),
        controller: controller,
        readOnly: !isEditing,
        decoration: _cellInputDecoration(),
        onChanged: isEditing
            ? (raw) => _updateStringField(talentId, field, raw)
            : null,
      ),
    );
  }

  Widget _visibilityCell({required String talentId, required bool isHidden}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: ValueKey<String>('talents-visibility-$talentId'),
        icon: Icon(isHidden ? Icons.visibility_off : Icons.visibility),
        tooltip: isHidden ? 'Talent einblenden' : 'Talent ausblenden',
        onPressed: () => _toggleHidden(talentId),
      ),
    );
  }

  InputDecoration _cellInputDecoration({bool isError = false}) {
    final theme = Theme.of(context).colorScheme;
    final borderColor = isError ? theme.error : theme.outline;
    return InputDecoration(
      isDense: true,
      border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isError ? theme.error : theme.primary),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  String _buildShortAttributeLabel(
    Attributes attributes,
    List<String> attributeNames,
  ) {
    final parts = <String>[];
    for (final name in attributeNames) {
      final code = parseAttributeCode(name);
      if (code == null) {
        parts.add('${name.trim()}: ?');
        continue;
      }
      final value = readAttributeValue(attributes, code);
      parts.add('${_attributeCodeLabel(code)}: $value');
    }
    return parts.join(' | ');
  }

  String _attributeCodeLabel(AttributeCode code) {
    switch (code) {
      case AttributeCode.mu:
        return 'MU';
      case AttributeCode.kl:
        return 'KL';
      case AttributeCode.inn:
        return 'IN';
      case AttributeCode.ch:
        return 'CH';
      case AttributeCode.ff:
        return 'FF';
      case AttributeCode.ge:
        return 'GE';
      case AttributeCode.ko:
        return 'KO';
      case AttributeCode.kk:
        return 'KK';
    }
  }

  int _calculateComputedTaw(HeroTalentEntry entry, int ebe) {
    return entry.talentValue + entry.modifier + ebe;
  }

  String _formatWholeNumber(num value) {
    if (value is int) {
      return value.toString();
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return trimmed;
  }

  @override
  bool get wantKeepAlive => true;
}
