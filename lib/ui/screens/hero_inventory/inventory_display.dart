part of '../hero_inventory_tab.dart';

extension _HeroInventoryDisplay on _HeroInventoryTabState {
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
