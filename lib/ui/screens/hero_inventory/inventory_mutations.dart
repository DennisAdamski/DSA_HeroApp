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

    // Die Auswahl über den Inhalt merken: Positionen können sich durch einen
    // anderen Schreibweg verschoben haben.
    final auswahl = _selectedIndex;
    final ausgewaehlt = auswahl == null || auswahl == index
        ? null
        : _entries.elementAtOrNull(auswahl);
    // Frisch: nur dieser Eintrag verschwindet; Kampf und Geschossmengen
    // bleiben, wie sie gespeichert sind (ARCH-05).
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Löschen von „${_entryName(entry)}“',
      aenderung: (held) => ohneInventarEintrag(held, entry),
    );
    if (gespeichert == null || !mounted) {
      return;
    }
    final neueAuswahl = ausgewaehlt == null
        ? -1
        : findeGleichenInventarEintrag(
            gespeichert.inventoryEntries,
            ausgewaehlt,
          );
    setState(() {
      _selectedIndex = neueAuswahl < 0 ? null : neueAuswahl;
      _pendingNewEntry = null;
      _editorRevision++;
    });
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
      // Der ID-Verweis zuerst: der Namensverweis traefe bei zwei gleichnamigen
      // Boegen immer den ersten.
      updatedConfig = applyAmmoCountChangeToConfig(
        updatedConfig,
        entry.slotRef ?? entry.sourceRef!,
        count,
      );
    }
    return updatedConfig;
  }

  int _manualEntryCount(List<HeroInventoryEntry> entries) {
    return entries.where((entry) => !_isCombatLinkedEntry(entry)).length;
  }

  /// Setzt einen eingetippten Geldbetrag frisch am gespeicherten Helden.
  Future<void> _saveDukaten(String value) async {
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Dukaten',
      aenderung: (held) => mitDukaten(held, value),
    );
  }

  /// Verschiebt den gespeicherten Geldbetrag um einen Münzschritt.
  Future<void> _verschiebeDukaten(int deltaKreuzer) async {
    await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Dukaten',
      aenderung: (held) => mitDukatenSchritt(held, deltaKreuzer),
    );
  }

  bool _isCombatLinkedEntry(HeroInventoryEntry entry) {
    return entry.sourceRef != null &&
        isCombatLinkedInventorySource(entry.source);
  }
}
