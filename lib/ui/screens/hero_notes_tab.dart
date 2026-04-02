import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_connection_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/adventure_rewards_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';

part 'hero_notes/hero_notes_sections.dart';
part 'hero_notes/hero_adventures_section.dart';

const double _notesPagePadding = 16;
const double _notesSectionSpacing = 16;
const double _notesFieldSpacing = 12;

const Uuid _uuid = Uuid();

/// Tab für Chroniken, Kontakte und Abenteuer.
class HeroNotesTab extends ConsumerStatefulWidget {
  /// Erzeugt den Tab für Chroniken, Kontakte und Abenteuer eines Helden.
  const HeroNotesTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  /// ID des Helden, dessen Chroniken, Kontakte und Abenteuer geladen werden.
  final String heroId;

  /// Meldet Dirty-Änderungen an den Workspace.
  final void Function(bool isDirty) onDirtyChanged;

  /// Meldet den Edit-Status an den Workspace.
  final void Function(bool isEditing) onEditingChanged;

  /// Registriert die Discard-Aktion des Tabs.
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;

  /// Registriert globale Start-/Save-/Cancel-Aktionen für die AppBar.
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroNotesTab> createState() => _HeroNotesTabState();
}

class _HeroNotesTabState extends ConsumerState<HeroNotesTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final WorkspaceTabEditController _editController;
  late final TabController _innerTabController;

  HeroSheet? _latestHero;
  List<HeroNoteEntry> _draftNotes = <HeroNoteEntry>[];
  List<HeroConnectionEntry> _draftConnections = <HeroConnectionEntry>[];
  List<HeroAdventureEntry> _draftAdventures = <HeroAdventureEntry>[];

  @override
  void initState() {
    super.initState();
    _innerTabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {});
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  @override
  void dispose() {
    _innerTabController.dispose();
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
    _draftNotes = List<HeroNoteEntry>.from(hero.notes);
    _draftConnections = List<HeroConnectionEntry>.from(hero.connections);
    _draftAdventures = List<HeroAdventureEntry>.from(hero.adventures);
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final sanitizedAdventures = _draftAdventures
        .map(_sanitizeAdventure)
        .where((entry) => entry.hasContent)
        .toList(growable: false);
    final validAdventureIds = sanitizedAdventures
        .map((entry) => entry.id.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();

    final sanitizedConnections = cleanupAdventureReferences(
      connections: _draftConnections
          .where(_hasConnectionContent)
          .toList(growable: false),
      validAdventureIds: validAdventureIds,
    );

    final updatedHero = hero.copyWith(
      notes: _draftNotes.where(_hasNoteContent).toList(growable: false),
      connections: sanitizedConnections,
      adventures: sanitizedAdventures,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    _editController.markSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chroniken, Kontakte & Abenteuer gespeichert'),
      ),
    );
  }

  HeroAdventureEntry _sanitizeAdventure(HeroAdventureEntry adventure) {
    return adventure.copyWith(
      notes: adventure.notes.where(_hasNoteContent).toList(growable: false),
      seRewards: adventure.seRewards
          .where((entry) => entry.hasContent)
          .toList(growable: false),
    );
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
    _editController.markDiscarded();
  }

  bool _hasNoteContent(HeroNoteEntry entry) {
    return entry.title.trim().isNotEmpty || entry.description.trim().isNotEmpty;
  }

  bool _hasConnectionContent(HeroConnectionEntry entry) {
    return entry.name.trim().isNotEmpty ||
        entry.ort.trim().isNotEmpty ||
        entry.sozialstatus.trim().isNotEmpty ||
        entry.loyalitaet.trim().isNotEmpty ||
        entry.beschreibung.trim().isNotEmpty ||
        entry.adventureId.trim().isNotEmpty;
  }

  void _markFieldChanged() {
    _editController.markFieldChanged();
  }

  Future<void> _startEditIfNeeded() async {
    if (_editController.isEditing) {
      return;
    }
    await _startEdit();
  }

  Future<void> _addNote() async {
    await _startEditIfNeeded();
    setState(() {
      _draftNotes = List<HeroNoteEntry>.from(_draftNotes)
        ..add(const HeroNoteEntry());
    });
    _markFieldChanged();
  }

  void _removeNote(int index) {
    setState(() {
      _draftNotes = List<HeroNoteEntry>.from(_draftNotes)..removeAt(index);
    });
    _markFieldChanged();
  }

  void _updateNoteTitle(int index, String value) {
    final next = List<HeroNoteEntry>.from(_draftNotes);
    next[index] = next[index].copyWith(title: value);
    setState(() {
      _draftNotes = next;
    });
    _markFieldChanged();
  }

  void _updateNoteDescription(int index, String value) {
    final next = List<HeroNoteEntry>.from(_draftNotes);
    next[index] = next[index].copyWith(description: value);
    setState(() {
      _draftNotes = next;
    });
    _markFieldChanged();
  }

  Future<void> _addConnection() async {
    await _startEditIfNeeded();
    setState(() {
      _draftConnections = List<HeroConnectionEntry>.from(_draftConnections)
        ..add(const HeroConnectionEntry());
    });
    _markFieldChanged();
  }

  void _removeConnection(int index) {
    setState(() {
      _draftConnections = List<HeroConnectionEntry>.from(_draftConnections)
        ..removeAt(index);
    });
    _markFieldChanged();
  }

  void _updateConnection(
    int index, {
    String? name,
    String? ort,
    String? sozialstatus,
    String? loyalitaet,
    String? beschreibung,
    String? adventureId,
  }) {
    final next = List<HeroConnectionEntry>.from(_draftConnections);
    next[index] = next[index].copyWith(
      name: name,
      ort: ort,
      sozialstatus: sozialstatus,
      loyalitaet: loyalitaet,
      beschreibung: beschreibung,
      adventureId: adventureId,
    );
    setState(() {
      _draftConnections = next;
    });
    _markFieldChanged();
  }

  Future<void> _addAdventure() async {
    await _startEditIfNeeded();
    setState(() {
      _draftAdventures = List<HeroAdventureEntry>.from(_draftAdventures)
        ..add(HeroAdventureEntry(id: _uuid.v4()));
      _innerTabController.animateTo(2);
    });
    _markFieldChanged();
  }

  void _removeAdventure(int index) {
    final adventure = _draftAdventures[index];
    if (adventure.rewardsApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Angewendete Abenteuer müssen erst zurückgenommen werden.',
          ),
        ),
      );
      return;
    }

    final nextAdventures = List<HeroAdventureEntry>.from(_draftAdventures)
      ..removeAt(index);
    setState(() {
      _draftAdventures = nextAdventures;
      _draftConnections = cleanupAdventureReferences(
        connections: _draftConnections,
        validAdventureIds: nextAdventures.map((entry) => entry.id),
      );
    });
    _markFieldChanged();
  }

  void _moveAdventure(int index, int direction) {
    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= _draftAdventures.length) {
      return;
    }
    final next = List<HeroAdventureEntry>.from(_draftAdventures);
    final current = next.removeAt(index);
    next.insert(targetIndex, current);
    setState(() {
      _draftAdventures = next;
    });
    _markFieldChanged();
  }

  void _updateAdventure(
    int index, {
    String? title,
    String? summary,
    int? apReward,
    List<HeroNoteEntry>? notes,
    List<HeroAdventureSeReward>? seRewards,
  }) {
    final next = List<HeroAdventureEntry>.from(_draftAdventures);
    next[index] = next[index].copyWith(
      title: title,
      summary: summary,
      apReward: apReward,
      notes: notes,
      seRewards: seRewards,
    );
    setState(() {
      _draftAdventures = next;
    });
    _markFieldChanged();
  }

  void _updateAdventureTitle(int index, String value) {
    _updateAdventure(index, title: value);
  }

  void _updateAdventureSummary(int index, String value) {
    _updateAdventure(index, summary: value);
  }

  void _updateAdventureApReward(int index, String rawValue) {
    final parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    _updateAdventure(index, apReward: parsedValue < 0 ? 0 : parsedValue);
  }

  void _addAdventureNote(int adventureIndex) {
    final adventure = _draftAdventures[adventureIndex];
    final nextNotes = List<HeroNoteEntry>.from(adventure.notes)
      ..add(const HeroNoteEntry());
    _updateAdventure(adventureIndex, notes: nextNotes);
  }

  void _removeAdventureNote(int adventureIndex, int noteIndex) {
    final adventure = _draftAdventures[adventureIndex];
    final nextNotes = List<HeroNoteEntry>.from(adventure.notes)
      ..removeAt(noteIndex);
    _updateAdventure(adventureIndex, notes: nextNotes);
  }

  void _updateAdventureNoteTitle(
    int adventureIndex,
    int noteIndex,
    String value,
  ) {
    final adventure = _draftAdventures[adventureIndex];
    final nextNotes = List<HeroNoteEntry>.from(adventure.notes);
    nextNotes[noteIndex] = nextNotes[noteIndex].copyWith(title: value);
    _updateAdventure(adventureIndex, notes: nextNotes);
  }

  void _updateAdventureNoteDescription(
    int adventureIndex,
    int noteIndex,
    String value,
  ) {
    final adventure = _draftAdventures[adventureIndex];
    final nextNotes = List<HeroNoteEntry>.from(adventure.notes);
    nextNotes[noteIndex] = nextNotes[noteIndex].copyWith(description: value);
    _updateAdventure(adventureIndex, notes: nextNotes);
  }

  void _addAdventureSeReward(int adventureIndex) {
    final adventure = _draftAdventures[adventureIndex];
    final nextRewards = List<HeroAdventureSeReward>.from(adventure.seRewards)
      ..add(const HeroAdventureSeReward(count: 1));
    _updateAdventure(adventureIndex, seRewards: nextRewards);
  }

  void _removeAdventureSeReward(int adventureIndex, int rewardIndex) {
    final adventure = _draftAdventures[adventureIndex];
    final nextRewards = List<HeroAdventureSeReward>.from(adventure.seRewards)
      ..removeAt(rewardIndex);
    _updateAdventure(adventureIndex, seRewards: nextRewards);
  }

  void _updateAdventureSeRewardCount(
    int adventureIndex,
    int rewardIndex,
    String rawValue,
  ) {
    final parsedValue = int.tryParse(rawValue.trim()) ?? 0;
    _updateAdventureSeReward(
      adventureIndex,
      rewardIndex,
      count: parsedValue < 0 ? 0 : parsedValue,
    );
  }

  void _updateAdventureSeRewardType(
    int adventureIndex,
    int rewardIndex,
    HeroAdventureSeTargetType targetType, {
    required HeroSheet hero,
    RulesCatalog? catalog,
  }) {
    final defaultOption = _defaultOptionForTargetType(
      targetType: targetType,
      hero: hero,
      catalog: catalog,
    );
    _updateAdventureSeReward(
      adventureIndex,
      rewardIndex,
      targetType: targetType,
      targetId: defaultOption?.id ?? '',
      targetLabel: defaultOption?.label ?? '',
    );
  }

  void _updateAdventureSeRewardTarget(
    int adventureIndex,
    int rewardIndex, {
    required String targetId,
    required String targetLabel,
  }) {
    _updateAdventureSeReward(
      adventureIndex,
      rewardIndex,
      targetId: targetId,
      targetLabel: targetLabel,
    );
  }

  void _updateAdventureSeReward(
    int adventureIndex,
    int rewardIndex, {
    HeroAdventureSeTargetType? targetType,
    String? targetId,
    String? targetLabel,
    int? count,
  }) {
    final adventure = _draftAdventures[adventureIndex];
    final nextRewards = List<HeroAdventureSeReward>.from(adventure.seRewards);
    nextRewards[rewardIndex] = nextRewards[rewardIndex].copyWith(
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
      count: count,
    );
    _updateAdventure(adventureIndex, seRewards: nextRewards);
  }

  Future<void> _applyAdventureRewardsFor(String adventureId) async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final adventure = _findAdventureById(hero.adventures, adventureId);
    if (adventure == null ||
        !adventure.hasRewards ||
        adventure.rewardsApplied) {
      return;
    }

    final updatedHero = applyAdventureRewards(
      hero: hero,
      adventureId: adventureId,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    _latestHero = updatedHero;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_adventureTitle(adventure)} angewendet')),
    );
  }

  Future<void> _revokeAdventureRewardsFor(String adventureId) async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final check = canRevokeAdventureRewards(
      hero: hero,
      adventureId: adventureId,
    );
    if (!check.isAllowed) {
      if (check.reason.trim().isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(check.reason)));
      }
      return;
    }

    final updatedHero = revokeAdventureRewards(
      hero: hero,
      adventureId: adventureId,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    final adventure = _findAdventureById(hero.adventures, adventureId);
    _latestHero = updatedHero;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_adventureTitle(adventure)} zurückgenommen')),
    );
  }

  HeroAdventureEntry? _findAdventureById(
    List<HeroAdventureEntry> adventures,
    String adventureId,
  ) {
    for (final adventure in adventures) {
      if (adventure.id == adventureId) {
        return adventure;
      }
    }
    return null;
  }

  String _adventureLabelForId(String adventureId) {
    final normalizedId = adventureId.trim();
    if (normalizedId.isEmpty) {
      return '';
    }
    final adventure = _findAdventureById(_draftAdventures, normalizedId);
    if (adventure == null) {
      return '';
    }
    return _adventureTitle(adventure);
  }

  List<_AdventureTargetOption> _buildTalentTargetOptions(
    HeroSheet hero,
    RulesCatalog? catalog,
  ) {
    final optionsById = <String, _AdventureTargetOption>{};

    void addOption(String id, String label) {
      final normalizedId = id.trim();
      final normalizedLabel = label.trim();
      if (normalizedId.isEmpty) {
        return;
      }
      optionsById.putIfAbsent(
        normalizedId,
        () => _AdventureTargetOption(
          id: normalizedId,
          label: normalizedLabel.isEmpty ? normalizedId : normalizedLabel,
        ),
      );
    }

    if (catalog != null) {
      final sortedTalents = List<TalentDef>.from(catalog.talents)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final talent in sortedTalents) {
        addOption(talent.id, talent.name);
      }
    }

    for (final talentId in hero.talents.keys) {
      addOption(talentId, talentId);
    }

    for (final adventure in _draftAdventures) {
      for (final reward in adventure.seRewards) {
        if (reward.targetType != HeroAdventureSeTargetType.talent) {
          continue;
        }
        addOption(reward.targetId, reward.targetLabel);
      }
    }

    final options = optionsById.values.toList(growable: false)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  List<_AdventureTargetOption> _targetOptionsForType({
    required HeroAdventureSeTargetType targetType,
    required HeroSheet hero,
    RulesCatalog? catalog,
  }) {
    return switch (targetType) {
      HeroAdventureSeTargetType.talent => _buildTalentTargetOptions(
        hero,
        catalog,
      ),
      HeroAdventureSeTargetType.grundwert => _grundwertTargetOptions,
      HeroAdventureSeTargetType.eigenschaft => _attributeTargetOptions,
    };
  }

  _AdventureTargetOption? _defaultOptionForTargetType({
    required HeroAdventureSeTargetType targetType,
    required HeroSheet hero,
    RulesCatalog? catalog,
  }) {
    final options = _targetOptionsForType(
      targetType: targetType,
      hero: hero,
      catalog: catalog,
    );
    return options.isEmpty ? null : options.first;
  }

  String _adventureTitle(HeroAdventureEntry? adventure) {
    if (adventure == null || adventure.title.trim().isEmpty) {
      return 'Unbenanntes Abenteuer';
    }
    return adventure.title;
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
    final catalog = ref.watch(rulesCatalogProvider).asData?.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showHeader = constraints.maxHeight >= 140;
        return Column(
          children: [
            if (showHeader)
              const CodexTabHeader(
                title: 'Chroniken, Kontakte & Abenteuer',
                subtitle:
                    'Freie Chroniken, soziale Verbindungen und Abenteueretappen in derselben Codex-Oberfläche.',
                assetPath: 'assets/ui/codex/compass_mark.png',
              ),
            TabBar(
              controller: _innerTabController,
              tabs: const [
                Tab(text: 'Chroniken'),
                Tab(text: 'Kontakte'),
                Tab(text: 'Abenteuer'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _innerTabController,
                children: [
                  _NotesSection(
                    entries: _draftNotes,
                    isEditing: _editController.isEditing,
                    onAdd: _addNote,
                    onRemove: _removeNote,
                    onTitleChanged: _updateNoteTitle,
                    onDescriptionChanged: _updateNoteDescription,
                  ),
                  _ConnectionsSection(
                    entries: _draftConnections,
                    isEditing: _editController.isEditing,
                    adventureOptions: _draftAdventures
                        .map(
                          (entry) => _AdventureTargetOption(
                            id: entry.id,
                            label: _adventureTitle(entry),
                          ),
                        )
                        .toList(growable: false),
                    adventureLabelForId: _adventureLabelForId,
                    onAdd: _addConnection,
                    onRemove: _removeConnection,
                    onChanged: _updateConnection,
                  ),
                  _AdventuresSection(
                    entries: _draftAdventures,
                    isEditing: _editController.isEditing,
                    onAdd: _addAdventure,
                    onRemove: _removeAdventure,
                    onMoveUp: (index) => _moveAdventure(index, -1),
                    onMoveDown: (index) => _moveAdventure(index, 1),
                    onTitleChanged: _updateAdventureTitle,
                    onSummaryChanged: _updateAdventureSummary,
                    onApRewardChanged: _updateAdventureApReward,
                    onAddNote: _addAdventureNote,
                    onRemoveNote: _removeAdventureNote,
                    onAdventureNoteTitleChanged: _updateAdventureNoteTitle,
                    onAdventureNoteDescriptionChanged:
                        _updateAdventureNoteDescription,
                    onAddSeReward: _addAdventureSeReward,
                    onRemoveSeReward: _removeAdventureSeReward,
                    onSeRewardTypeChanged: (adventureIndex, rewardIndex, type) {
                      _updateAdventureSeRewardType(
                        adventureIndex,
                        rewardIndex,
                        type,
                        hero: hero,
                        catalog: catalog,
                      );
                    },
                    onSeRewardTargetChanged: _updateAdventureSeRewardTarget,
                    onSeRewardCountChanged: _updateAdventureSeRewardCount,
                    onApplyRewards: _applyAdventureRewardsFor,
                    onRevokeRewards: _revokeAdventureRewardsFor,
                    targetOptionsForType: (type) => _targetOptionsForType(
                      targetType: type,
                      hero: hero,
                      catalog: catalog,
                    ),
                    revokeCheckForAdventure: (adventureId) =>
                        canRevokeAdventureRewards(
                          hero: hero,
                          adventureId: adventureId,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AdventureTargetOption {
  const _AdventureTargetOption({required this.id, required this.label});

  final String id;
  final String label;
}

const List<_AdventureTargetOption> _attributeTargetOptions =
    <_AdventureTargetOption>[
      _AdventureTargetOption(id: 'mu', label: 'Mut'),
      _AdventureTargetOption(id: 'kl', label: 'Klugheit'),
      _AdventureTargetOption(id: 'inn', label: 'Intuition'),
      _AdventureTargetOption(id: 'ch', label: 'Charisma'),
      _AdventureTargetOption(id: 'ff', label: 'Fingerfertigkeit'),
      _AdventureTargetOption(id: 'ge', label: 'Gewandtheit'),
      _AdventureTargetOption(id: 'ko', label: 'Konstitution'),
      _AdventureTargetOption(id: 'kk', label: 'Körperkraft'),
    ];

const List<_AdventureTargetOption> _grundwertTargetOptions =
    <_AdventureTargetOption>[
      _AdventureTargetOption(id: 'lep', label: 'LeP'),
      _AdventureTargetOption(id: 'au', label: 'Au'),
      _AdventureTargetOption(id: 'asp', label: 'AsP'),
      _AdventureTargetOption(id: 'kap', label: 'KaP'),
      _AdventureTargetOption(id: 'mr', label: 'MR'),
    ];
