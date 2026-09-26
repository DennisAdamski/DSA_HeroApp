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

  // Tabellenziffern halten Menge, Gewicht und Wert spaltenweise untereinander;
  // Proportionalziffern lassen die Spalte sonst sichtbar zittern.
  Widget _zahlenzelle(String text) => Text(
    text,
    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
  );

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
    // Unter Kartograph flacher: die Aktionsspalte ist 88 breit, zwei kompakte
    // Symbolknoepfe umbrachen darin und verdoppelten jede Zeilenhoehe.
    final karto = kartoVariante(context) != null;
    final knopfDichte = karto
        ? const VisualDensity(horizontal: -4, vertical: -4)
        : VisualDensity.compact;
    final knopfSymbol = karto ? 18.0 : null;
    final namensStil = karto
        ? TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )
        : null;
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
                style: namensStil,
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
            _zahlenzelle(
              entry.anzahl.trim().isEmpty ? '–' : entry.anzahl.trim(),
            ),
            _zahlenzelle(_formatWeight(entry.gewichtGramm)),
            _zahlenzelle(_formatValue(entry.wertSilber)),
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
                    visualDensity: knopfDichte,
                    iconSize: knopfSymbol,
                    onPressed: () => _openEditEntryAction(context, index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (!_isCombatLinkedEntry(entry))
                    IconButton(
                      key: ValueKey<String>('inventory-row-delete-$index'),
                      tooltip: 'Löschen',
                      visualDensity: knopfDichte,
                      iconSize: knopfSymbol,
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
      child: PersistedTableColumnLayout(
        tableId: 'inventory.items',
        builder: (context, resizeBinding) => FlexibleTable(
          tableKey: const ValueKey<String>('inventory-table'),
          columnSpecs: _HeroInventoryTabState._columnSpecs,
          columnResize: resizeBinding,
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
          // Anzahl, Gewicht und Wert; rechtsbuendig nur unter Kartograph.
          numerischeSpalten: const <int>{4, 5, 6},
        ),
      ),
    );
  }
}
