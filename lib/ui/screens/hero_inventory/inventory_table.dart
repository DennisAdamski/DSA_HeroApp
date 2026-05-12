part of '../hero_inventory_tab.dart';

extension _HeroInventoryTable on _HeroInventoryTabState {
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
        columnSpecs: _HeroInventoryTabState._columnSpecs,
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
}
