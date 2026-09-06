import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/inspector_panel.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_history_panel.dart';

/// Inspector-Seitenleiste fuer den Helden-Workspace.
///
/// Wrapper um [InspectorPanel] – behaelt den historischen Klassennamen, damit
/// vorhandene Konsumenten in `workspace_layout.dart` und `hero_workspace_screen`
/// unveraendert bleiben.
class WorkspaceInspectorPanel extends ConsumerWidget {
  const WorkspaceInspectorPanel({
    super.key,
    required this.heroId,
    required this.isExpanded,
    this.onToggleExpanded,
  });

  final String heroId;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(advancementSessionProvider(heroId));
    if (session != null && isExpanded) {
      return SafeArea(
        child: Column(
          children: [
            if (onToggleExpanded != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey<String>('workspace-details-toggle'),
                  tooltip: 'Details ausblenden',
                  onPressed: onToggleExpanded,
                  icon: const Icon(Icons.chevron_right),
                ),
              ),
            Expanded(child: AdvancementHistoryPanel(heroId: heroId)),
          ],
        ),
      );
    }
    return InspectorPanel(
      heroId: heroId,
      isExpanded: isExpanded,
      onToggleExpanded: onToggleExpanded,
    );
  }
}
