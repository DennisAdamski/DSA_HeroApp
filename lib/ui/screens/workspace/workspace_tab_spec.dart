import 'package:flutter/material.dart';

/// Definiert Metadaten fuer einen einzelnen Workspace-Tab.
///
/// Wird von [workspaceTabs] genutzt, um Label, Icon und Hilfstext
/// fuer Navigation und Inspector bereitzustellen.
class WorkspaceTabSpec {
  const WorkspaceTabSpec({
    required this.label,
    required this.icon,
    required this.helper,
  });

  /// Anzeige-Label des Tabs (z. B. 'Uebersicht').
  final String label;

  /// Icon des Tabs in der Navigation.
  final IconData icon;

  /// Kurzbeschreibung des Tabs fuer den Inspector.
  final String helper;
}

/// Statische Liste aller Workspace-Tabs in der festen Reihenfolge.
///
/// Index 0 = Uebersicht, 1 = Talente, 2 = Kampf, 3 = Magie,
/// 4 = Inventar, 5 = Notizen.
const List<WorkspaceTabSpec> workspaceTabs = <WorkspaceTabSpec>[
  WorkspaceTabSpec(
    label: 'Uebersicht',
    icon: Icons.dashboard_outlined,
    helper: 'Basisdaten und Ressourcen',
  ),
  WorkspaceTabSpec(
    label: 'Talente',
    icon: Icons.auto_stories_outlined,
    helper: 'Talentwerte und Spezialisierungen',
  ),
  WorkspaceTabSpec(
    label: 'Kampf',
    icon: Icons.sports_martial_arts_outlined,
    helper: 'Kampftechniken, Nahkampf, Sonderfertigkeiten, Manoever',
  ),
  WorkspaceTabSpec(
    label: 'Magie',
    icon: Icons.bolt_outlined,
    helper: 'Katalogansicht fuer Zauber',
  ),
  WorkspaceTabSpec(
    label: 'Inventar',
    icon: Icons.inventory_2_outlined,
    helper: 'Ausrüstung und Gegenstaende',
  ),
  WorkspaceTabSpec(
    label: 'Notizen',
    icon: Icons.sticky_note_2_outlined,
    helper: 'Freier Platzhalterbereich',
  ),
];
