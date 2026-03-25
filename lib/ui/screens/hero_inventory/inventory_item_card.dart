import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Karte für einen einzelnen Inventar-Eintrag in der Listenansicht.
class InventoryItemCard extends StatelessWidget {
  /// Erstellt die kompakte Dokumentkarte für einen Inventar-Eintrag.
  const InventoryItemCard({
    super.key,
    required this.entry,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
    this.traegerName,
  });

  final HeroInventoryEntry entry;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  /// Anzeigename des Trägers, wenn das Item einem Begleiter zugeordnet ist.
  /// Null bedeutet: Held trägt das Item.
  final String? traegerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLinked = entry.sourceRef != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _SourceIcon(source: entry.source),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.gegenstand.isNotEmpty
                                ? entry.gegenstand
                                : '(kein Name)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontStyle: entry.gegenstand.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        Text(
                          _metaLabel(entry),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallChip(
                          label: _typeLabel(entry.itemType),
                          color: colorScheme.surfaceContainerHighest,
                          textColor: colorScheme.onSurfaceVariant,
                        ),
                        if (isLinked)
                          _SmallChip(
                            label: 'Verknüpft',
                            color: colorScheme.secondaryContainer,
                            textColor: colorScheme.onSecondaryContainer,
                          ),
                        if (entry.istAusgeruestet &&
                            entry.itemType == InventoryItemType.ausruestung)
                          _SmallChip(
                            label: 'Ausgerüstet',
                            color: colorScheme.primaryContainer,
                            textColor: colorScheme.onPrimaryContainer,
                          ),
                        if (entry.source == InventoryItemSource.geschoss &&
                            entry.anzahl.isNotEmpty)
                          _SmallChip(
                            label: '×${entry.anzahl}',
                            color: colorScheme.tertiaryContainer,
                            textColor: colorScheme.onTertiaryContainer,
                          ),
                        if (entry.modifiers.isNotEmpty &&
                            entry.itemType == InventoryItemType.ausruestung)
                          _SmallChip(
                            label: '${entry.modifiers.length} Mod.',
                            color: colorScheme.surfaceContainerHighest,
                            textColor: colorScheme.onSurfaceVariant,
                          ),
                        if (traegerName != null)
                          _SmallChip(
                            label: traegerName!,
                            color: colorScheme.secondaryContainer,
                            textColor: colorScheme.onSecondaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isEditing) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onTap,
                  tooltip: 'Bearbeiten',
                  visualDensity: VisualDensity.compact,
                ),
                if (!isLinked && onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Löschen',
                    visualDensity: VisualDensity.compact,
                  ),
              ] else
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
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

  String _metaLabel(HeroInventoryEntry entry) {
    final parts = <String>[];
    if (entry.gewichtGramm > 0) {
      final kilogramm = entry.gewichtGramm / 1000;
      parts.add(
        kilogramm >= 1
            ? '${kilogramm.toStringAsFixed(1)} kg'
            : '${entry.gewichtGramm} g',
      );
    }
    if (entry.wertSilber > 0) {
      parts.add('${entry.wertSilber} S');
    }
    return parts.join(' · ');
  }
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.source});

  final InventoryItemSource source;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (source) {
      case InventoryItemSource.waffe:
        icon = Icons.sports_martial_arts_outlined;
      case InventoryItemSource.ruestung:
        icon = Icons.shield_outlined;
      case InventoryItemSource.nebenhand:
        icon = Icons.back_hand_outlined;
      case InventoryItemSource.geschoss:
        icon = Icons.arrow_upward_outlined;
      case InventoryItemSource.manuell:
        icon = Icons.inventory_2_outlined;
    }
    return Icon(icon, size: 20, color: Theme.of(context).colorScheme.outline);
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: textColor),
      ),
    );
  }
}
