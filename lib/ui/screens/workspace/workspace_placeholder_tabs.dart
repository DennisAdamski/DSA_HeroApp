import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Identifiziert den Katalogbereich, der in einem Platzhalter-Tab angezeigt wird.
enum WorkspaceCatalogSection {
  /// Zeigt Talente aus dem Regelkatalog.
  talents,

  /// Zeigt Zauber aus dem Regelkatalog.
  spells,

  /// Zeigt Waffen aus dem Regelkatalog.
  weapons,
}

/// Einfacher Platzhalter-Tab fuer noch nicht implementierte Bereiche.
///
/// Zeigt einen Hinweistext, der den Tab-Titel nennt.
class WorkspacePlaceholderTab extends StatelessWidget {
  const WorkspacePlaceholderTab({super.key, required this.title});

  /// Anzeigename des Tabs.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title wird als nächstes ausgearbeitet.'));
  }
}

/// Katalog-Platzhalter-Tab, der Ladestand und Anzahl der Eintraege anzeigt.
///
/// Laedt den Regelkatalog asynchron und zeigt eine Zusammenfassung des
/// angegebenen [section]-Bereichs an.
class WorkspaceCatalogPlaceholderTab extends ConsumerWidget {
  const WorkspaceCatalogPlaceholderTab({
    super.key,
    required this.title,
    required this.section,
  });

  /// Anzeigename des Tabs.
  final String title;

  /// Zu zeigender Katalogbereich.
  final WorkspaceCatalogSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(rulesCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Katalog-Fehler: $error')),
      data: (catalog) {
        final count = switch (section) {
          WorkspaceCatalogSection.talents => catalog.talents.length,
          WorkspaceCatalogSection.spells => catalog.spells.length,
          WorkspaceCatalogSection.weapons => catalog.weapons.length,
        };

        final details = switch (section) {
          WorkspaceCatalogSection.talents =>
            'mit Waffengattung: ${catalog.talents.where((t) => t.weaponCategory.isNotEmpty).length}',
          WorkspaceCatalogSection.spells =>
            'mit Verfuegbarkeit: ${catalog.spells.where((s) => s.availability.isNotEmpty).length}',
          WorkspaceCatalogSection.weapons =>
            'mit Waffengattung: ${catalog.weapons.where((w) => w.weaponCategory.isNotEmpty).length}',
        };

        return Center(
          child: Text(
            '$title: $count Einträge aus ${catalog.version} geladen ($details).',
          ),
        );
      },
    );
  }
}
