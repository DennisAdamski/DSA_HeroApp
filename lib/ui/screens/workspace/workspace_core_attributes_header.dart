import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_header_stat_rail.dart';

/// Persistente Kernwerte-Rail ueber dem Tab-Inhalt im kompakten Workspace.
class WorkspaceCoreAttributesHeader extends StatelessWidget {
  /// Erstellt die mobile Standalone-Rail fuer Eigenschaften und Ressourcen.
  const WorkspaceCoreAttributesHeader({
    super.key,
    required this.heroId,
    required this.hero,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer die Berechnung effektiver Werte.
  final HeroSheet hero;

  @override
  Widget build(BuildContext context) {
    return WorkspaceHeaderStatRail(
      key: const ValueKey<String>('workspace-core-attributes-header'),
      heroId: heroId,
      hero: hero,
      variant: WorkspaceHeaderStatRailVariant.standalone,
    );
  }
}
