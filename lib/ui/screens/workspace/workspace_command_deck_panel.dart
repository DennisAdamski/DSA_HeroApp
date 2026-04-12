import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_badge.dart';
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
    this.onToggleExpanded,
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
  final VoidCallback? onToggleExpanded;

  /// Callback beim Auswaehlen eines Tabs.
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final toggleTooltip = isExpanded
        ? 'Helden-Deck ausblenden'
        : 'Helden-Deck einblenden';
    final toggleIcon = isExpanded
        ? Icons.keyboard_double_arrow_left
        : Icons.keyboard_double_arrow_right;
    final showToggle = onToggleExpanded != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: codex.heroGradientSoft,
        border: Border(right: BorderSide(color: codex.rule)),
      ),
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
                        if (showToggle)
                          IconButton(
                            key: const ValueKey<String>('hero-deck-toggle'),
                            tooltip: toggleTooltip,
                            onPressed: onToggleExpanded,
                            icon: Icon(toggleIcon),
                          ),
                      ],
                    )
                  : showToggle
                  ? Center(
                      child: IconButton(
                        key: const ValueKey<String>('hero-deck-toggle'),
                        tooltip: toggleTooltip,
                        onPressed: onToggleExpanded,
                        icon: Icon(toggleIcon),
                      ),
                    )
                  : const SizedBox(height: 12),
            ),
            if (isExpanded)
              Expanded(
                child: ListView.builder(
                  itemCount: tabs.length,
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final selected = index == activeTabIndex;
                    final dirty = isDirty(tab.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        selected: selected,
                        selectedTileColor: codex.brass.withValues(alpha: 0.14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            codex.panelRadius,
                          ),
                          side: BorderSide(
                            color: selected ? codex.brassMuted : codex.rule,
                          ),
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tab.helper,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (dirty) ...[
                              const SizedBox(height: 6),
                              const CodexBadge(
                                label: 'Ungespeichert',
                                tone: CodexBadgeTone.warning,
                              ),
                            ],
                          ],
                        ),
                        onTap: () => onSelectTab(index),
                      ),
                    );
                  },
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
                                  ? codex.brass.withValues(alpha: 0.14)
                                  : null,
                              borderRadius: BorderRadius.circular(
                                codex.panelRadius,
                              ),
                              border: Border.all(
                                color: selected ? codex.brassMuted : codex.rule,
                              ),
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
