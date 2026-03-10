import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Bottom Navigation fuer iPhone-Layouts (compact, < 744dp).
///
/// Zeigt bis zu fuenf sichtbare Tabs direkt und optional einen "Mehr"-Eintrag,
/// ueber den weitere Tabs per BottomSheet erreichbar sind.
class WorkspaceBottomNavigation extends StatelessWidget {
  const WorkspaceBottomNavigation({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.onSelectTab,
  });

  /// Sichtbare Tabs in ihrer aktuellen Reihenfolge.
  final List<WorkspaceTabSpec> tabs;

  /// Index des aktuell sichtbaren Tabs.
  final int activeTabIndex;

  /// Callback beim Auswaehlen eines Tabs.
  final ValueChanged<int> onSelectTab;

  /// Anzahl der direkt sichtbaren Tabs in der Bottom Navigation.
  static const int _visibleTabCount = 5;

  @override
  Widget build(BuildContext context) {
    // Aktiver Index: wenn > _visibleTabCount-1, zeige "Mehr" als aktiv.
    final hasOverflow = tabs.length > _visibleTabCount;
    final visibleTabCount = hasOverflow ? _visibleTabCount : tabs.length;
    final clampedIndex = activeTabIndex < visibleTabCount
        ? activeTabIndex
        : visibleTabCount;

    final destinations = <NavigationDestination>[
      for (var i = 0; i < visibleTabCount; i++)
        NavigationDestination(icon: Icon(tabs[i].icon), label: tabs[i].label),
      if (hasOverflow)
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'Mehr',
        ),
    ];

    return NavigationBar(
      selectedIndex: clampedIndex,
      onDestinationSelected: (index) {
        if (index < visibleTabCount) {
          onSelectTab(index);
          return;
        }
        if (hasOverflow) {
          // "Mehr" getippt: zeige uebrige Tabs als BottomSheet.
          _showOverflowSheet(context, visibleTabCount);
        }
      },
      destinations: destinations,
    );
  }

  /// Zeigt die nicht direkt sichtbaren Tabs als BottomSheet an.
  void _showOverflowSheet(BuildContext context, int visibleTabCount) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = visibleTabCount; i < tabs.length; i++)
                ListTile(
                  leading: Icon(tabs[i].icon),
                  title: Text(tabs[i].label),
                  subtitle: Text(tabs[i].helper),
                  selected: activeTabIndex == i,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onSelectTab(i);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
