import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Seitenleiste fuer den Desktop-Helden-Deck-Modus.
///
/// Zeigt alle Workspace-Tabs als auswaehlbare ListTiles mit Dirty-Indikator an.
/// Ersetzt die horizontale TabBar im breiten Layout.
class WorkspaceCommandDeckNavigationPanel extends StatelessWidget {
  const WorkspaceCommandDeckNavigationPanel({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.isExpanded,
    required this.isDirty,
    required this.onToggleExpanded,
    required this.onSelectTab,
  });

  /// Sichtbare Tabs in ihrer aktuellen Reihenfolge.
  final List<WorkspaceTabSpec> tabs;

  /// Index des aktuell sichtbaren Tabs.
  final int activeTabIndex;

  /// Gibt an, ob das Helden-Deck ausgefahren angezeigt wird.
  final bool isExpanded;

  /// Gibt zurueck, ob ein Tab ungespeicherte Aenderungen hat.
  final bool Function(String tabId) isDirty;

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
    final primaryTabs = tabs.where(_isPrimaryTab).toList(growable: false);
    final secondaryTabs = tabs
        .where((tab) => !_isPrimaryTab(tab))
        .toList(growable: false);

    return ColoredBox(
      color: colorScheme.surface,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Helden Deck',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kapitel und Nebenbereiche',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                  children: [
                    if (primaryTabs.isNotEmpty)
                      _NavigationSection(
                        title: 'Hauptkapitel',
                        tabs: primaryTabs,
                        allTabs: tabs,
                        activeTabIndex: activeTabIndex,
                        isDirty: isDirty,
                        onSelectTab: onSelectTab,
                      ),
                    if (secondaryTabs.isNotEmpty)
                      _NavigationSection(
                        title: 'Nebenbereiche',
                        tabs: secondaryTabs,
                        allTabs: tabs,
                        activeTabIndex: activeTabIndex,
                        isDirty: isDirty,
                        onSelectTab: onSelectTab,
                        compact: true,
                      ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: tabs.length,
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final selected = index == activeTabIndex;
                    final dirty = isDirty(tab.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tooltip(
                        message: tab.label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelectTab(index),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: selected
                                  ? colorScheme.secondaryContainer
                                  : null,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    tab.icon,
                                    color: selected
                                        ? colorScheme.onSecondaryContainer
                                        : null,
                                  ),
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
                            ),
                          ),
                        ),
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

class _NavigationSection extends StatelessWidget {
  const _NavigationSection({
    required this.title,
    required this.tabs,
    required this.allTabs,
    required this.activeTabIndex,
    required this.isDirty,
    required this.onSelectTab,
    this.compact = false,
  });

  final String title;
  final List<WorkspaceTabSpec> tabs;
  final List<WorkspaceTabSpec> allTabs;
  final int activeTabIndex;
  final bool Function(String tabId) isDirty;
  final ValueChanged<int> onSelectTab;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final tab in tabs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ExpandedNavigationTile(
              tab: tab,
              selected: allTabs.indexOf(tab) == activeTabIndex,
              dirty: isDirty(tab.id),
              compact: compact,
              onTap: () => onSelectTab(allTabs.indexOf(tab)),
            ),
          ),
      ],
    );
  }
}

class _ExpandedNavigationTile extends StatelessWidget {
  const _ExpandedNavigationTile({
    required this.tab,
    required this.selected,
    required this.dirty,
    required this.compact,
    required this.onTap,
  });

  final WorkspaceTabSpec tab;
  final bool selected;
  final bool dirty;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    tab.icon,
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.helper,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? colorScheme.onSecondaryContainer.withValues(
                                alpha: 0.82,
                              )
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isPrimaryTab(WorkspaceTabSpec tab) {
  switch (tab.id) {
    case WorkspaceTabIds.overview:
    case WorkspaceTabIds.talents:
    case WorkspaceTabIds.combat:
    case WorkspaceTabIds.magic:
    case WorkspaceTabIds.inventory:
      return true;
    case WorkspaceTabIds.notes:
    case WorkspaceTabIds.reisebericht:
    case WorkspaceTabIds.begleiter:
      return false;
  }
  return false;
}
