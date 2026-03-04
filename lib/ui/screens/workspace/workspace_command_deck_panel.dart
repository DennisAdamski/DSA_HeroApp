import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Seitenleiste fuer den Desktop-Command-Deck-Modus.
///
/// Zeigt alle Workspace-Tabs als auswaehlbare ListTiles mit Dirty-Indikator an.
/// Ersetzt die horizontale TabBar im breiten Layout.
class WorkspaceCommandDeckNavigationPanel extends StatelessWidget {
  const WorkspaceCommandDeckNavigationPanel({
    super.key,
    required this.activeTabIndex,
    required this.isDirty,
    required this.onSelectTab,
  });

  /// Index des aktuell sichtbaren Tabs.
  final int activeTabIndex;

  /// Gibt zurueck, ob ein Tab ungespeicherte Aenderungen hat.
  final bool Function(int tabIndex) isDirty;

  /// Callback beim Auswaehlen eines Tabs.
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: Text(
                'Command Deck',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: workspaceTabs.length,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                itemBuilder: (context, index) {
                  final tab = workspaceTabs[index];
                  final selected = index == activeTabIndex;
                  final dirty = isDirty(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(tab.icon),
                          if (dirty)
                            Positioned(
                              right: -3,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(tab.label),
                      subtitle: Text(
                        tab.helper,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelectTab(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
