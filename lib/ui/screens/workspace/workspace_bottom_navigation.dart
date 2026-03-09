import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Bottom Navigation fuer iPhone-Layouts (compact, < 744dp).
///
/// Zeigt die ersten 5 Tabs direkt und einen "Mehr"-Eintrag,
/// ueber den weitere Tabs (Notizen) per BottomSheet erreichbar sind.
class WorkspaceBottomNavigation extends StatelessWidget {
  const WorkspaceBottomNavigation({
    super.key,
    required this.activeTabIndex,
    required this.onSelectTab,
  });

  /// Index des aktuell sichtbaren Tabs.
  final int activeTabIndex;

  /// Callback beim Auswaehlen eines Tabs.
  final ValueChanged<int> onSelectTab;

  /// Anzahl der direkt sichtbaren Tabs in der Bottom Navigation.
  static const int _visibleTabCount = 5;

  @override
  Widget build(BuildContext context) {
    // Aktiver Index: wenn > _visibleTabCount-1, zeige "Mehr" als aktiv.
    final clampedIndex = activeTabIndex < _visibleTabCount
        ? activeTabIndex
        : _visibleTabCount;

    final destinations = <NavigationDestination>[
      for (var i = 0; i < _visibleTabCount; i++)
        NavigationDestination(
          icon: Icon(workspaceTabs[i].icon),
          label: workspaceTabs[i].label,
        ),
      const NavigationDestination(
        icon: Icon(Icons.more_horiz),
        label: 'Mehr',
      ),
    ];

    return NavigationBar(
      selectedIndex: clampedIndex,
      onDestinationSelected: (index) {
        if (index < _visibleTabCount) {
          onSelectTab(index);
          return;
        }
        // "Mehr" getippt: zeige uebrige Tabs als BottomSheet
        _showOverflowSheet(context);
      },
      destinations: destinations,
    );
  }

  /// Zeigt die nicht direkt sichtbaren Tabs als BottomSheet an.
  void _showOverflowSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = _visibleTabCount; i < workspaceTabs.length; i++)
                ListTile(
                  leading: Icon(workspaceTabs[i].icon),
                  title: Text(workspaceTabs[i].label),
                  subtitle: Text(workspaceTabs[i].helper),
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
