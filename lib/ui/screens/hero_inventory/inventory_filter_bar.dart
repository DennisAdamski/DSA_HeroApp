import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Aktiver Filtertyp in der Inventar-Ansicht.
enum InventoryFilter {
  alle,
  ausruestung,
  verbrauchsgegenstand,
  wertvolles,
  sonstiges,
  waffen,
  geschosse,
}

/// Leiste mit Filter-Chips und Gewicht-/Wert-Zusammenfassung.
class InventoryFilterBar extends StatelessWidget {
  const InventoryFilterBar({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.totalWeightGramm,
    required this.totalValueSilber,
  });

  final InventoryFilter activeFilter;
  final ValueChanged<InventoryFilter> onFilterChanged;
  final int totalWeightGramm;
  final int totalValueSilber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _chip(context, InventoryFilter.alle, 'Alle'),
              _chip(context, InventoryFilter.ausruestung, 'Ausrüstung'),
              _chip(
                context,
                InventoryFilter.verbrauchsgegenstand,
                'Verbrauchsgegenstände',
              ),
              _chip(context, InventoryFilter.wertvolles, 'Wertvolles'),
              _chip(context, InventoryFilter.sonstiges, 'Sonstiges'),
              _chip(context, InventoryFilter.waffen, 'Waffen (auto)'),
              _chip(context, InventoryFilter.geschosse, 'Geschosse (auto)'),
            ],
          ),
        ),
        if (totalWeightGramm > 0 || totalValueSilber > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Gesamt: ${_formatWeight(totalWeightGramm)} / $totalValueSilber S',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, InventoryFilter filter, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: activeFilter == filter,
        onSelected: (_) => onFilterChanged(filter),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _formatWeight(int gramm) {
    if (gramm >= 1000) {
      final kg = gramm / 1000.0;
      return '${kg.toStringAsFixed(kg.truncateToDouble() == kg ? 0 : 1)} kg';
    }
    return '$gramm g';
  }
}

/// Hilfsfunktion: filtert Inventar-Eintraege nach [InventoryFilter].
bool matchesInventoryFilter(
  InventoryItemType itemType,
  InventoryItemSource source,
  InventoryFilter filter,
) {
  switch (filter) {
    case InventoryFilter.alle:
      return true;
    case InventoryFilter.ausruestung:
      return itemType == InventoryItemType.ausruestung &&
          source != InventoryItemSource.waffe &&
          source != InventoryItemSource.geschoss;
    case InventoryFilter.verbrauchsgegenstand:
      return itemType == InventoryItemType.verbrauchsgegenstand &&
          source != InventoryItemSource.geschoss;
    case InventoryFilter.wertvolles:
      return itemType == InventoryItemType.wertvolles;
    case InventoryFilter.sonstiges:
      return itemType == InventoryItemType.sonstiges;
    case InventoryFilter.waffen:
      return source == InventoryItemSource.waffe;
    case InventoryFilter.geschosse:
      return source == InventoryItemSource.geschoss;
  }
}
