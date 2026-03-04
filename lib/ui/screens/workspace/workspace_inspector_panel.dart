import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Inspector-Seitenleiste fuer den Desktop-Command-Deck-Modus.
///
/// Zeigt Informationen zum aktiven Tab, Bearbeitungsstatus und Helddaten an.
/// Wird nur im breiten Layout (Command-Deck) neben dem Tab-Inhalt angezeigt.
class WorkspaceInspectorPanel extends StatelessWidget {
  const WorkspaceInspectorPanel({
    super.key,
    required this.hero,
    required this.activeTabIndex,
    required this.isEditing,
    required this.isDirty,
  });

  /// Der aktuell angezeigte Held.
  final HeroSheet hero;

  /// Index des aktuell aktiven Tabs (benoetigt fuer Tab-Metadaten).
  final int activeTabIndex;

  /// Gibt an, ob sich der aktive Tab im Bearbeitungsmodus befindet.
  final bool isEditing;

  /// Gibt an, ob der aktive Tab ungespeicherte Aenderungen hat.
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final tab = workspaceTabs[activeTabIndex];
    final stateText = isEditing ? 'Bearbeitungsmodus' : 'Lesemodus';
    final dirtyText = isDirty ? 'Ungespeicherte Aenderungen' : 'Alles gespeichert';
    final levelText = hero.level.toString();
    final apAvailableText = hero.apAvailable.toString();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Inspector', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tab.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(tab.helper),
                      const SizedBox(height: 10),
                      Chip(label: Text(stateText)),
                      const SizedBox(height: 8),
                      Chip(label: Text(dirtyText)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text('Level: $levelText'),
                      Text('AP verfuegbar: $apAvailableText'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Hinweis: Tab-Wechsel und Zurueck-Navigation behalten den '
                    'bestehenden Discard-Guard bei.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
