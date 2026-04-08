import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Karte fuer einen einzelnen Inventar-Eintrag in der Listenansicht.
class InventoryItemCard extends StatelessWidget {
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
  /// Null bedeutet: Held trägt das Item (kein Badge).
  final String? traegerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final isLinked =
        entry.sourceRef != null && isCombatLinkedInventorySource(entry.source);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(codex.panelRadius),
            image: const DecorationImage(
              image: AssetImage('assets/ui/codex/parchment_texture.png'),
              fit: BoxFit.cover,
              opacity: 0.06,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _SourceIcon(source: entry.source),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.gegenstand.isNotEmpty
                                ? entry.gegenstand
                                : '(kein Name)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontStyle: entry.gegenstand.isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isLinked)
                          _SmallChip(
                            label: 'Verknüpft',
                            color: theme.colorScheme.secondaryContainer,
                            textColor: theme.colorScheme.onSecondaryContainer,
                          ),
                        if (entry.istAusgeruestet &&
                            entry.itemType == InventoryItemType.ausruestung)
                          _SmallChip(
                            label: 'Ausgerüstet',
                            color: theme.colorScheme.primaryContainer,
                            textColor: theme.colorScheme.onPrimaryContainer,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SmallChip(
                          label: _typeLabel(entry.itemType),
                          color: theme.colorScheme.surfaceContainerHighest,
                          textColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        if (entry.source == InventoryItemSource.geschoss &&
                            entry.anzahl.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: '×${entry.anzahl}',
                            color: theme.colorScheme.tertiaryContainer,
                            textColor: theme.colorScheme.onTertiaryContainer,
                          ),
                        ],
                        if (entry.modifiers.isNotEmpty &&
                            entry.itemType ==
                                InventoryItemType.ausruestung) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: '${entry.modifiers.length} Mod.',
                            color: theme.colorScheme.surfaceContainerHighest,
                            textColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                        if (entry.isMagisch) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: 'Magisch',
                            color: theme.colorScheme.tertiaryContainer,
                            textColor: theme.colorScheme.onTertiaryContainer,
                          ),
                        ],
                        if (entry.isGeweiht) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: 'Geweiht',
                            color: theme.colorScheme.secondaryContainer,
                            textColor: theme.colorScheme.onSecondaryContainer,
                          ),
                        ],
                        if (traegerName != null) ...[
                          const SizedBox(width: 4),
                          _SmallChip(
                            label: traegerName!,
                            color: theme.colorScheme.secondaryContainer,
                            textColor: theme.colorScheme.onSecondaryContainer,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
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
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Löschen',
                    visualDensity: VisualDensity.compact,
                  ),
              ] else
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.transparent,
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
}

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.source});
  final InventoryItemSource source;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
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
      case InventoryItemSource.abenteuer:
        icon = Icons.menu_book_outlined;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: codex.panelRaised,
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: codex.rule),
      ),
      child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
    );
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
