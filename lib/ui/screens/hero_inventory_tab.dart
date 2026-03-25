import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_filter_bar.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_edit_controller.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/hero_document.dart';

const double _widthBreakpoint = 1280;
const double _pagePadding = 12;

class HeroInventoryTab extends ConsumerStatefulWidget {
  const HeroInventoryTab({
    super.key,
    required this.heroId,
    required this.onDirtyChanged,
    required this.onEditingChanged,
    required this.onRegisterDiscard,
    required this.onRegisterEditActions,
  });

  final String heroId;
  final void Function(bool isDirty) onDirtyChanged;
  final void Function(bool isEditing) onEditingChanged;
  final void Function(WorkspaceAsyncAction discardAction) onRegisterDiscard;
  final void Function(WorkspaceTabEditActions actions) onRegisterEditActions;

  @override
  ConsumerState<HeroInventoryTab> createState() => _HeroInventoryTabState();
}

class _HeroInventoryTabState extends ConsumerState<HeroInventoryTab>
    with AutomaticKeepAliveClientMixin {
  late final WorkspaceTabEditController _editController;
  HeroSheet? _latestHero;
  List<HeroInventoryEntry> _draft = const [];
  InventoryFilter _filter = InventoryFilter.alle;
  int? _selectedIndex;
  int _editorRevision = 0;
  final TextEditingController _dukatenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editController = WorkspaceTabEditController(
      onDirtyChanged: widget.onDirtyChanged,
      onEditingChanged: widget.onEditingChanged,
      requestRebuild: () {
        if (mounted) setState(() {});
      },
    );
    _dukatenCtrl.addListener(_onDukatenChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _registerWithParent();
    });
  }

  @override
  void dispose() {
    _dukatenCtrl.dispose();
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

  void _onDukatenChanged() {
    if (_editController.isEditing) {
      _editController.markFieldChanged();
    }
  }

  void _syncFromHero(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) return;
    _draft = List.of(hero.inventoryEntries);
    _dukatenCtrl.text = hero.dukaten;
  }

  Future<void> _startEdit() async {
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) return;

    // Ammo-Ruecksync: anzahl-Aenderungen aus Draft in CombatConfig uebertragen
    var updatedConfig = hero.combatConfig;
    for (final entry in _draft) {
      if (entry.source == InventoryItemSource.geschoss &&
          entry.sourceRef != null) {
        final count = int.tryParse(entry.anzahl) ?? 0;
        updatedConfig = applyAmmoCountChangeToConfig(
          updatedConfig,
          entry.sourceRef!,
          count,
        );
      }
    }

    final updatedHero = hero.copyWith(
      dukaten: _dukatenCtrl.text.trim(),
      inventoryEntries: _draft,
      combatConfig: updatedConfig,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) return;

    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inventar gespeichert')));
  }

  Future<void> _cancelChanges() async => _discardChanges();

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncFromHero(hero, force: true);
    }
    setState(() => _selectedIndex = null);
    _editController.markDiscarded();
  }

  void _addEntry() {
    setState(() {
      _draft = [..._draft, const HeroInventoryEntry()];
      _selectedIndex = _draft.length - 1;
      _editorRevision++;
    });
    _editController.markFieldChanged();
  }

  void _updateEntry(int draftIndex, HeroInventoryEntry updated) {
    setState(() {
      final list = List.of(_draft);
      list[draftIndex] = updated;
      _draft = list;
      _editorRevision++;
    });
    _editController.markFieldChanged();
  }

  void _deleteEntry(int draftIndex) {
    setState(() {
      final list = List.of(_draft)..removeAt(draftIndex);
      _draft = list;
      if (_selectedIndex == draftIndex) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > draftIndex) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    _editController.markFieldChanged();
  }

  List<HeroCompanion> get _companions => _latestHero?.companions ?? const [];

  /// Loest den Anzeigenamen des Traeger aus dem Inventar-Eintrag auf.
  /// Gibt null zurueck, wenn der Held selbst der Traeger ist.
  String? _traegerName(HeroInventoryEntry entry) {
    if (entry.traegerTyp != InventoryTraeger.begleiter) return null;
    final id = entry.traegerId;
    if (id == null) return null;
    final companion = _companions.where((c) => c.id == id).firstOrNull;
    if (companion == null) return 'Begleiter';
    return companion.name.isEmpty ? 'Unbenannter Begleiter' : companion.name;
  }

  /// Ordnet einen Inventar-Eintrag in eine nutzungsorientierte Dokumentgruppe ein.
  String _groupLabel(HeroInventoryEntry entry) {
    if (entry.istAusgeruestet || entry.source != InventoryItemSource.manuell) {
      return 'Getragen & einsatzbereit';
    }
    if (entry.itemType == InventoryItemType.verbrauchsgegenstand) {
      return 'Vorräte & Verbrauch';
    }
    if (entry.itemType == InventoryItemType.wertvolles) {
      return 'Wertsachen';
    }
    return 'Sonstiger Besitz';
  }

  int _groupPriority(String label) {
    switch (label) {
      case 'Getragen & einsatzbereit':
        return 0;
      case 'Vorräte & Verbrauch':
        return 1;
      case 'Wertsachen':
        return 2;
      case 'Sonstiger Besitz':
        return 3;
    }
    return 99;
  }

  /// Baut den Seitenkopf fuer Besitz, Geld und Tragegewicht.
  Widget _buildInventoryHeader(int totalWeight, int totalValue) {
    return HeroPageHeader(
      title: 'Besitz',
      subtitle:
          'Getragene Ausrüstung, Vorräte und Wertsachen werden nach ihrem direkten Nutzwert am Spieltisch gruppiert.',
      metrics: [
        HeroMetricChip(label: 'Einträge', value: '${_draft.length}'),
        HeroMetricChip(
          label: 'Gewicht',
          value: '${(totalWeight / 1000).toStringAsFixed(1)} kg',
        ),
        HeroMetricChip(
          label: 'Wert',
          value: '${(totalValue / 10).toStringAsFixed(1)} D',
        ),
        HeroMetricChip(
          label: 'Dukaten',
          value: _dukatenCtrl.text.trim().isEmpty
              ? '-'
              : _dukatenCtrl.text.trim(),
        ),
      ],
    );
  }

  void _selectEntry(int draftIndex, bool isWide, BuildContext context) {
    if (isWide) {
      setState(() {
        _selectedIndex = draftIndex;
        _editorRevision++;
      });
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InventoryItemEditor(
            entry: _draft[draftIndex],
            showAppBar: true,
            companions: _companions,
            onSaved: (updated) {
              Navigator.of(context).pop();
              _updateEntry(draftIndex, updated);
            },
            onCancelled: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;
    _syncFromHero(hero);

    final isEditing = _editController.isEditing;
    final isWide = MediaQuery.sizeOf(context).width >= _widthBreakpoint;
    final totalWeight = _draft.fold(0, (sum, e) => sum + e.gewichtGramm);
    final totalValue = _draft.fold(0, (sum, e) => sum + e.wertSilber);

    final filterBar = InventoryFilterBar(
      activeFilter: _filter,
      onFilterChanged: (f) => setState(() {
        _filter = f;
        _selectedIndex = null;
      }),
      totalWeightGramm: totalWeight,
      totalValueSilber: totalValue,
    );

    final list = _buildList(isEditing, isWide, context);

    if (isWide && isEditing) {
      return _buildWideLayout(filterBar, list, isEditing);
    }
    return _buildNarrowLayout(filterBar, list, isEditing);
  }

  Widget _buildNarrowLayout(Widget filterBar, Widget list, bool isEditing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            _pagePadding,
            _pagePadding,
            0,
          ),
          child: _buildInventoryHeader(
            _draft.fold(0, (sum, entry) => sum + entry.gewichtGramm),
            _draft.fold(0, (sum, entry) => sum + entry.wertSilber),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            _pagePadding,
            _pagePadding,
            0,
          ),
          child: _DukatenField(controller: _dukatenCtrl, isEditing: isEditing),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _pagePadding - 4),
          child: filterBar,
        ),
        const SizedBox(height: 4),
        Expanded(child: list),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.all(_pagePadding),
            child: FilledButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add),
              label: const Text('Gegenstand hinzufügen'),
            ),
          ),
      ],
    );
  }

  Widget _buildWideLayout(Widget filterBar, Widget list, bool isEditing) {
    final selectedIdx = _selectedIndex;
    final showEditor = selectedIdx != null && selectedIdx < _draft.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _pagePadding,
                  _pagePadding,
                  _pagePadding,
                  0,
                ),
                child: _buildInventoryHeader(
                  _draft.fold(0, (sum, entry) => sum + entry.gewichtGramm),
                  _draft.fold(0, (sum, entry) => sum + entry.wertSilber),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _pagePadding,
                  _pagePadding,
                  _pagePadding,
                  0,
                ),
                child: _DukatenField(
                  controller: _dukatenCtrl,
                  isEditing: isEditing,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _pagePadding - 4,
                ),
                child: filterBar,
              ),
              const SizedBox(height: 4),
              Expanded(child: list),
              Padding(
                padding: const EdgeInsets.all(_pagePadding),
                child: FilledButton.icon(
                  onPressed: _addEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Gegenstand hinzufügen'),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        if (showEditor)
          Expanded(
            child: InventoryItemEditor(
              key: ValueKey<String>('editor-$selectedIdx-$_editorRevision'),
              entry: _draft[selectedIdx],
              showAppBar: false,
              companions: _companions,
              onSaved: (updated) => _updateEntry(selectedIdx, updated),
              onCancelled: () => setState(() => _selectedIndex = null),
            ),
          )
        else
          const Expanded(
            child: Center(
              child: Text(
                'Gegenstand auswählen zum Bearbeiten',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildList(bool isEditing, bool isWide, BuildContext context) {
    final filtered = <(int, HeroInventoryEntry)>[];
    for (var i = 0; i < _draft.length; i++) {
      final entry = _draft[i];
      if (matchesInventoryFilter(entry.itemType, entry.source, _filter)) {
        filtered.add((i, entry));
      }
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Keine Einträge in dieser Kategorie.'),
        ),
      );
    }

    final grouped = <String, List<(int, HeroInventoryEntry)>>{};
    for (final item in filtered) {
      final label = _groupLabel(item.$2);
      grouped.putIfAbsent(label, () => <(int, HeroInventoryEntry)>[]).add(item);
    }
    final groupNames = grouped.keys.toList()
      ..sort((a, b) => _groupPriority(a).compareTo(_groupPriority(b)));

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final groupName in groupNames) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              groupName,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          for (final item in grouped[groupName]!)
            InventoryItemCard(
              key: ValueKey<int>(item.$1),
              entry: item.$2,
              isEditing: isEditing,
              traegerName: _traegerName(item.$2),
              onTap: isEditing
                  ? () => _selectEntry(item.$1, isWide, context)
                  : () {},
              onDelete:
                  (isEditing && item.$2.source == InventoryItemSource.manuell)
                  ? () => _deleteEntry(item.$1)
                  : null,
            ),
        ],
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ---------------------------------------------------------------------------
// Hilfs-Widget
// ---------------------------------------------------------------------------

class _DukatenField extends StatelessWidget {
  const _DukatenField({required this.controller, required this.isEditing});

  final TextEditingController controller;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        readOnly: !isEditing,
        decoration: const InputDecoration(
          labelText: 'Dukaten',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
