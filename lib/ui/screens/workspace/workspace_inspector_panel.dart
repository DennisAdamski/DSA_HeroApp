import 'package:flutter/widgets.dart';

import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/inspector_panel.dart';

/// Inspector-Seitenleiste fuer den Helden-Workspace.
///
/// Wrapper um [InspectorPanel] – behaelt den historischen Klassennamen, damit
/// vorhandene Konsumenten in `workspace_layout.dart` und `hero_workspace_screen`
/// unveraendert bleiben.
class WorkspaceInspectorPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InspectorPanel(
      heroId: heroId,
      isExpanded: isExpanded,
      onToggleExpanded: onToggleExpanded,
    );
  }
}
