// ignore_for_file: invalid_use_of_protected_member

part of '../hero_inventory_tab.dart';

extension _HeroInventoryEditorRouting on _HeroInventoryTabState {
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
}
