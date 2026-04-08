import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventory_sync_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_filter_bar.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_item_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

const double _widthBreakpoint = 1280;
const double _pagePadding = 12;

/// Inventar-Tab mit direkter Bearbeitung ohne globalen Workspace-Edit-Modus.
class HeroInventoryTab extends ConsumerStatefulWidget {
  /// Erstellt den Inventar-Tab fuer einen einzelnen Helden.
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
  HeroSheet? _latestHero;
  InventoryFilter _filter = InventoryFilter.alle;
  int? _selectedIndex;
  HeroInventoryEntry? _pendingNewEntry;
  int _editorRevision = 0;

  static const List<AdaptiveTableColumnSpec>
  _columnSpecs = <AdaptiveTableColumnSpec>[
    AdaptiveTableColumnSpec(
      minWidth: 180,
      maxWidth: 280,
      flex: 2,
    ), // Gegenstand
    AdaptiveTableColumnSpec(minWidth: 130, maxWidth: 180, flex: 1), // Typ
    AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 150, flex: 1), // Quelle
    AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 220, flex: 1), // Träger
    AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 92), // Anzahl
    AdaptiveTableColumnSpec(minWidth: 88, maxWidth: 120), // Gewicht
    AdaptiveTableColumnSpec(minWidth: 88, maxWidth: 120), // Wert
    AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 280, flex: 2), // Status
    AdaptiveTableColumnSpec(minWidth: 160, maxWidth: 280, flex: 2), // Herkunft
    AdaptiveTableColumnSpec.fixed(88), // Aktion
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _registerWithParent();
      }
    });
  }

  void _registerWithParent() {
    widget.onDirtyChanged(false);
    widget.onEditingChanged(false);
    widget.onRegisterDiscard(_noopWorkspaceAction);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _noopWorkspaceAction,
        save: _noopWorkspaceAction,
        cancel: _noopWorkspaceAction,
        headerActions: <WorkspaceHeaderAction>[
          WorkspaceHeaderAction(
            builder: _buildHeaderAddAction,
            showWhenIdle: true,
          ),
        ],
      ),
    );
  }

  Future<void> _noopWorkspaceAction() async {}

  List<HeroInventoryEntry> get _entries =>
      _latestHero?.inventoryEntries ?? const <HeroInventoryEntry>[];

  List<HeroCompanion> get _companions =>
      _latestHero?.companions ?? const <HeroCompanion>[];

  List<(int, HeroInventoryEntry)> _filteredEntries() {
    final result = <(int, HeroInventoryEntry)>[];
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (matchesInventoryFilter(entry.itemType, entry.source, _filter)) {
        result.add((index, entry));
      }
    }
    return result;
  }

  String _traegerName(HeroInventoryEntry entry) {
    if (entry.traegerTyp != InventoryTraeger.begleiter) {
      return 'Held';
    }

    final id = entry.traegerId;
    if (id == null) {
      return 'Begleiter';
    }

    final companion = _companions.where((item) => item.id == id).firstOrNull;
    if (companion == null) {
      return 'Begleiter';
    }

    final name = companion.name.trim();
    return name.isEmpty ? 'Unbenannter Begleiter' : name;
  }

  Widget _buildHeaderAddAction(BuildContext context) {
    final useCompactButton = MediaQuery.sizeOf(context).width < 720;
    final tooltip = 'Gegenstand hinzufügen';

    if (useCompactButton) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          key: const ValueKey<String>('inventory-header-add'),
          onPressed: () => _openNewEntryAction(context),
          icon: const Icon(Icons.add),
        ),
      );
    }

    return FilledButton(
      key: const ValueKey<String>('inventory-header-add'),
      onPressed: () => _openNewEntryAction(context),
      child: const Text('+ Gegenstand'),
    );
  }

  Future<void> _openNewEntryAction(BuildContext context) async {
    final isWide = MediaQuery.sizeOf(context).width >= _widthBreakpoint;
    final entry = HeroInventoryEntry(itemType: _defaultItemTypeForFilter());

    if (isWide) {
      setState(() {
        _pendingNewEntry = entry;
        _selectedIndex = null;
        _editorRevision++;
      });
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => InventoryItemEditor(
          entry: entry,
          showAppBar: true,
          isNew: true,
          companions: _companions,
          onSaved: (updated) async {
            await _saveNewEntry(updated);
            if (routeContext.mounted) {
              Navigator.of(routeContext).pop();
            }
          },
          onCancelled: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  Future<void> _openEditEntryAction(
    BuildContext context,
    int entryIndex,
  ) async {
    final isWide = MediaQuery.sizeOf(context).width >= _widthBreakpoint;
    if (isWide) {
      setState(() {
        _pendingNewEntry = null;
        _selectedIndex = entryIndex;
        _editorRevision++;
      });
      return;
    }

    final entry = _entries[entryIndex];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => InventoryItemEditor(
          entry: entry,
          showAppBar: true,
          companions: _companions,
          onSaved: (updated) async {
            await _saveUpdatedEntry(entryIndex, updated);
            if (routeContext.mounted) {
              Navigator.of(routeContext).pop();
            }
          },
          onCancelled: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  InventoryItemType _defaultItemTypeForFilter() {
    switch (_filter) {
      case InventoryFilter.ausruestung:
        return InventoryItemType.ausruestung;
      case InventoryFilter.verbrauchsgegenstand:
        return InventoryItemType.verbrauchsgegenstand;
      case InventoryFilter.wertvolles:
        return InventoryItemType.wertvolles;
      case InventoryFilter.sonstiges:
        return InventoryItemType.sonstiges;
      case InventoryFilter.alle:
      case InventoryFilter.waffen:
      case InventoryFilter.geschosse:
        return InventoryItemType.sonstiges;
    }
  }

  Future<void> _saveNewEntry(HeroInventoryEntry entry) async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final nextEntries = List<HeroInventoryEntry>.from(_entries)..add(entry);
    final nextSelectedIndex = _manualEntryCount(nextEntries) - 1;

    await _saveEntries(
      nextEntries,
      changedEntry: entry,
      nextSelectedIndex: nextSelectedIndex,
      clearPendingEntry: true,
    );
  }

  Future<void> _saveUpdatedEntry(int index, HeroInventoryEntry entry) async {
    final hero = _latestHero;
    if (hero == null || index < 0 || index >= _entries.length) {
      return;
    }

    final nextEntries = List<HeroInventoryEntry>.from(_entries);
    nextEntries[index] = entry;

    await _saveEntries(
      nextEntries,
      changedEntry: entry,
      nextSelectedIndex: index,
      clearPendingEntry: true,
    );
  }

  Future<void> _deleteEntry(int index) async {
    final hero = _latestHero;
    if (hero == null || index < 0 || index >= _entries.length) {
      return;
    }

    final entry = _entries[index];
    if (_isCombatLinkedEntry(entry)) {
      return;
    }

    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Gegenstand löschen',
      content: 'Soll „${_entryName(entry)}“ wirklich gelöscht werden?',
      confirmLabel: 'Löschen',
      isDestructive: true,
    );
    if (!mounted || confirmed != AdaptiveConfirmResult.confirm) {
      return;
    }

    final nextEntries = List<HeroInventoryEntry>.from(_entries)
      ..removeAt(index);
    final nextSelectedIndex = _selectedIndex == null
        ? null
        : _selectedIndex == index
        ? null
        : _selectedIndex! > index
        ? _selectedIndex! - 1
        : _selectedIndex;

    await _saveEntries(
      nextEntries,
      nextSelectedIndex: nextSelectedIndex,
      clearPendingEntry: true,
    );
  }

  Future<void> _saveEntries(
    List<HeroInventoryEntry> entries, {
    HeroInventoryEntry? changedEntry,
    int? nextSelectedIndex,
    bool clearPendingEntry = false,
  }) async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final updatedHero = hero.copyWith(
      inventoryEntries: entries,
      combatConfig: _applyInventoryChangesToCombat(hero, entries),
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }

    final shouldResetFilter =
        changedEntry != null &&
        _filter != InventoryFilter.alle &&
        !matchesInventoryFilter(
          changedEntry.itemType,
          changedEntry.source,
          _filter,
        );

    setState(() {
      if (shouldResetFilter) {
        _filter = InventoryFilter.alle;
      }
      _selectedIndex = nextSelectedIndex;
      if (clearPendingEntry) {
        _pendingNewEntry = null;
      }
      _editorRevision++;
    });
  }

  CombatConfig _applyInventoryChangesToCombat(
    HeroSheet hero,
    List<HeroInventoryEntry> entries,
  ) {
    var updatedConfig = applyLinkedInventoryDetailsToConfig(
      hero.combatConfig,
      entries,
    );
    for (final entry in entries) {
      final isProjectile =
          entry.source == InventoryItemSource.geschoss &&
          entry.sourceRef != null;
      if (!isProjectile) {
        continue;
      }

      final count = int.tryParse(entry.anzahl) ?? 0;
      updatedConfig = applyAmmoCountChangeToConfig(
        updatedConfig,
        entry.sourceRef!,
        count,
      );
    }
    return updatedConfig;
  }

  int _manualEntryCount(List<HeroInventoryEntry> entries) {
    return entries.where((entry) => !_isCombatLinkedEntry(entry)).length;
  }

  Future<void> _saveDukaten(String value) async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }

    final normalized = value.trim();
    if (normalized == hero.dukaten.trim()) {
      return;
    }

    await ref
        .read(heroActionsProvider)
        .saveHero(hero.copyWith(dukaten: normalized));
  }

  String _entryName(HeroInventoryEntry entry) {
    final name = entry.gegenstand.trim();
    return name.isEmpty ? 'Unbenannter Gegenstand' : name;
  }

  String _typeLabel(InventoryItemType type) {
    switch (type) {
      case InventoryItemType.ausruestung:
        return 'Ausrüstung';
      case InventoryItemType.verbrauchsgegenstand:
        return 'Verbrauch';
      case InventoryItemType.wertvolles:
        return 'Wertvolles';
      case InventoryItemType.sonstiges:
        return 'Sonstiges';
    }
  }

  String _sourceLabel(InventoryItemSource source) {
    switch (source) {
      case InventoryItemSource.manuell:
        return 'Manuell';
      case InventoryItemSource.waffe:
        return 'Waffe';
      case InventoryItemSource.ruestung:
        return 'Rüstung';
      case InventoryItemSource.geschoss:
        return 'Geschoss';
      case InventoryItemSource.nebenhand:
        return 'Nebenhand';
      case InventoryItemSource.abenteuer:
        return 'Abenteuer';
    }
  }

  String _formatWeight(int gramm) {
    if (gramm <= 0) {
      return '–';
    }

    if (gramm >= 1000) {
      final kilo = gramm / 1000.0;
      final hasDecimal = kilo.truncateToDouble() != kilo;
      final value = kilo.toStringAsFixed(hasDecimal ? 1 : 0);
      return '$value kg';
    }

    return '$gramm g';
  }

  String _formatValue(int silber) {
    if (silber <= 0) {
      return '–';
    }
    return '$silber S';
  }

  List<Widget> _buildStatusWidgets(HeroInventoryEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    if (_isCombatLinkedEntry(entry)) {
      widgets.add(
        _StatusBadge(
          label: 'Verknüpft',
          color: colorScheme.secondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
        ),
      );
    }

    final isEquipment = entry.itemType == InventoryItemType.ausruestung;
    if (entry.istAusgeruestet && isEquipment) {
      widgets.add(
        _StatusBadge(
          label: 'Ausgerüstet',
          color: colorScheme.primaryContainer,
          textColor: colorScheme.onPrimaryContainer,
        ),
      );
    }

    if (entry.modifiers.isNotEmpty && isEquipment) {
      widgets.add(
        _StatusBadge(
          label: '${entry.modifiers.length} Mod.',
          color: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (entry.isMagisch) {
      widgets.add(
        _StatusBadge(
          label: 'Magisch',
          color: colorScheme.tertiaryContainer,
          textColor: colorScheme.onTertiaryContainer,
        ),
      );
    }

    if (entry.isGeweiht) {
      widgets.add(
        _StatusBadge(
          label: 'Geweiht',
          color: colorScheme.secondaryContainer,
          textColor: colorScheme.onSecondaryContainer,
        ),
      );
    }

    if (widgets.isEmpty) {
      return const <Widget>[Text('–')];
    }
    return widgets;
  }

  Widget _buildTable(BuildContext context) {
    final filteredEntries = _filteredEntries();
    if (filteredEntries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Keine Einträge in dieser Kategorie.'),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final rows = <FlexibleTableRow>[];
    for (final (index, entry) in filteredEntries) {
      final isSelected = _selectedIndex == index;
      rows.add(
        FlexibleTableRow(
          key: ValueKey<int>(index),
          backgroundColor: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.22)
              : null,
          cells: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey<String>('inventory-row-open-$index'),
                onPressed: () => _openEditEntryAction(context, index),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _entryName(entry),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Text(_typeLabel(entry.itemType)),
            Text(_sourceLabel(entry.source)),
            Text(_traegerName(entry)),
            Text(entry.anzahl.trim().isEmpty ? '–' : entry.anzahl.trim()),
            Text(_formatWeight(entry.gewichtGramm)),
            Text(_formatValue(entry.wertSilber)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _buildStatusWidgets(entry),
            ),
            Text(
              entry.herkunft.trim().isEmpty ? '–' : entry.herkunft.trim(),
              overflow: TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    key: ValueKey<String>('inventory-row-edit-$index'),
                    tooltip: 'Bearbeiten',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openEditEntryAction(context, index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (!_isCombatLinkedEntry(entry))
                    IconButton(
                      key: ValueKey<String>('inventory-row-delete-$index'),
                      tooltip: 'Löschen',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _deleteEntry(index),
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: FlexibleTable(
        tableKey: const ValueKey<String>('inventory-table'),
        columnSpecs: _columnSpecs,
        headerCells: const <Widget>[
          Text('Gegenstand'),
          Text('Typ'),
          Text('Quelle'),
          Text('Träger'),
          Text('Anzahl'),
          Text('Gewicht'),
          Text('Wert'),
          Text('Status'),
          Text('Herkunft'),
          Text('Aktion'),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildEditorPanel() {
    final pendingEntry = _pendingNewEntry;
    if (pendingEntry != null) {
      return InventoryItemEditor(
        key: ValueKey<String>('inventory-editor-new-$_editorRevision'),
        entry: pendingEntry,
        showAppBar: false,
        isNew: true,
        companions: _companions,
        onSaved: _saveNewEntry,
        onCancelled: () => setState(() => _pendingNewEntry = null),
      );
    }

    final selectedIndex = _selectedIndex;
    if (selectedIndex != null && selectedIndex < _entries.length) {
      return InventoryItemEditor(
        key: ValueKey<String>(
          'inventory-editor-$selectedIndex-$_editorRevision',
        ),
        entry: _entries[selectedIndex],
        showAppBar: false,
        companions: _companions,
        onSaved: (entry) => _saveUpdatedEntry(selectedIndex, entry),
        onCancelled: () => setState(() => _selectedIndex = null),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Gegenstand auswählen oder oben rechts hinzufügen.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    if (hero == null) {
      return const Center(child: Text('Held nicht gefunden.'));
    }

    _latestHero = hero;

    final isWide = MediaQuery.sizeOf(context).width >= _widthBreakpoint;
    final totalWeight = hero.inventoryEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.gewichtGramm,
    );
    final totalValue = hero.inventoryEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.wertSilber,
    );

    final filterBar = InventoryFilterBar(
      activeFilter: _filter,
      onFilterChanged: (filter) => setState(() => _filter = filter),
      totalWeightGramm: totalWeight,
      totalValueSilber: totalValue,
    );
    final table = _buildTable(context);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CodexTabHeader(
                  title: 'Ausrüstungs-Ledger',
                  subtitle:
                      'Traglast, Herkunft und Ausrüstungsstatus in einer direkten Inventartabelle.',
                  assetPath: 'assets/ui/codex/compass_mark.png',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _pagePadding,
                    _pagePadding,
                    _pagePadding,
                    0,
                  ),
                  child: _DukatenField(
                    key: const ValueKey<String>('inventory-dukaten-field'),
                    value: hero.dukaten,
                    onCommit: _saveDukaten,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _pagePadding - 4,
                  ),
                  child: filterBar,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _pagePadding,
                    ),
                    child: table,
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 2,
            child: Container(
              key: const ValueKey<String>('inventory-editor-panel'),
              color: Theme.of(context).colorScheme.surface,
              child: _buildEditorPanel(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CodexTabHeader(
          title: 'Ausrüstungs-Ledger',
          subtitle:
              'Traglast, Wert und Ausrüstungsstatus in einer kompakten Inventartabelle.',
          assetPath: 'assets/ui/codex/compass_mark.png',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _pagePadding,
            _pagePadding,
            _pagePadding,
            0,
          ),
          child: _DukatenField(
            key: const ValueKey<String>('inventory-dukaten-field'),
            value: hero.dukaten,
            onCommit: _saveDukaten,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _pagePadding - 4),
          child: filterBar,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
            child: table,
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;

  bool _isCombatLinkedEntry(HeroInventoryEntry entry) {
    return entry.sourceRef != null &&
        isCombatLinkedInventorySource(entry.source);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: labelStyle?.copyWith(color: textColor)),
    );
  }
}

class _DukatenField extends StatefulWidget {
  const _DukatenField({super.key, required this.value, required this.onCommit});

  final String value;
  final Future<void> Function(String value) onCommit;

  @override
  State<_DukatenField> createState() => _DukatenFieldState();
}

class _DukatenFieldState extends State<_DukatenField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _DukatenField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitIfChanged();
    }
  }

  Future<void> _commitIfChanged() async {
    final nextValue = _controller.text.trim();
    if (nextValue == widget.value.trim()) {
      return;
    }
    await widget.onCommit(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: const InputDecoration(
          labelText: 'Dukaten',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _commitIfChanged(),
        onTapOutside: (_) {
          _commitIfChanged();
          _focusNode.unfocus();
        },
      ),
    );
  }
}
