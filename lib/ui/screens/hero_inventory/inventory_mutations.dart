// ignore_for_file: invalid_use_of_protected_member

part of '../hero_inventory_tab.dart';

extension _HeroInventoryMutations on _HeroInventoryTabState {
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

  bool _isCombatLinkedEntry(HeroInventoryEntry entry) {
    return entry.sourceRef != null &&
        isCombatLinkedInventorySource(entry.source);
  }
}
