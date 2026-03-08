import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Seitenleiste fuer den Desktop-Helden-Deck-Modus.
///
/// Zeigt alle Workspace-Tabs als auswaehlbare ListTiles mit Dirty-Indikator an.
/// Ersetzt die horizontale TabBar im breiten Layout.
class WorkspaceCommandDeckNavigationPanel extends StatelessWidget {
  const WorkspaceCommandDeckNavigationPanel({
    super.key,
    required this.activeTabIndex,
    required this.isExpanded,
    required this.isDirty,
    required this.onToggleExpanded,
    required this.onSelectTab,
  });

  /// Index des aktuell sichtbaren Tabs.
  final int activeTabIndex;

  /// Gibt an, ob das Helden-Deck ausgefahren angezeigt wird.
  final bool isExpanded;

  /// Gibt zurueck, ob ein Tab ungespeicherte Aenderungen hat.
  final bool Function(int tabIndex) isDirty;

  /// Schaltet den Ein-/Ausfahrzustand des Helden-Decks um.
  final VoidCallback onToggleExpanded;

  /// Callback beim Auswaehlen eines Tabs.
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final toggleTooltip = isExpanded
        ? 'Helden-Deck ausblenden'
        : 'Helden-Deck einblenden';
    final toggleIcon = isExpanded
        ? Icons.keyboard_double_arrow_left
        : Icons.keyboard_double_arrow_right;

    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isExpanded ? 12 : 4,
                12,
                isExpanded ? 12 : 4,
                8,
              ),
              child: isExpanded
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Helden Deck',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey<String>('hero-deck-toggle'),
                          tooltip: toggleTooltip,
                          onPressed: onToggleExpanded,
                          icon: Icon(toggleIcon),
                        ),
                      ],
                    )
                  : Center(
                      child: IconButton(
                        key: const ValueKey<String>('hero-deck-toggle'),
                        tooltip: toggleTooltip,
                        onPressed: onToggleExpanded,
                        icon: Icon(toggleIcon),
                      ),
                    ),
            ),
            if (isExpanded)
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
                        selectedTileColor: colorScheme.secondaryContainer,
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
                                    color: colorScheme.error,
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
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}
