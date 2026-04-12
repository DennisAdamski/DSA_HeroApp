import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_badge.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_metric_tile.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_page_scaffold.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Listenbereich der Heldenzentrale fuer Smartphone- und Tablet-Layouts.
class HeroHomeArchivePane extends StatelessWidget {
  /// Erstellt die linke Archivspalte inklusive Zusammenfassung und Heldenliste.
  const HeroHomeArchivePane({
    super.key,
    required this.heroes,
    required this.selectedHeroId,
    required this.layout,
    required this.onSelectHero,
    required this.onExportHero,
    required this.onDeleteHero,
  });

  /// Alle verfuegbaren Helden.
  final List<HeroSheet> heroes;

  /// Aktuell hervorgehobener Held.
  final String? selectedHeroId;

  /// Aktive Layoutklasse der App.
  final AppLayoutClass layout;

  /// Reaktion auf Heldenauswahl.
  final ValueChanged<HeroSheet> onSelectHero;

  /// Exportiert einen einzelnen Helden.
  final ValueChanged<HeroSheet> onExportHero;

  /// Loescht einen einzelnen Helden.
  final ValueChanged<HeroSheet> onDeleteHero;

  @override
  Widget build(BuildContext context) {
    return CodexPageScaffold(
      padding: EdgeInsets.all(layout.contentPadding),
      child: Column(
        children: [
          CodexSectionCard(
            title: 'Heldenarchiv',
            subtitle:
                'Wähle einen Helden aus, um ihn im Workspace zu öffnen oder auf dem iPad zuerst in Ruhe zu prüfen.',
            trailing: CodexBadge(
              label: '${heroes.length} ${heroes.length == 1 ? 'Held' : 'Helden'}',
              tone: CodexBadgeTone.accent,
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                CodexMetricTile(
                  label: 'Archiv',
                  value: heroes.length.toString(),
                  icon: Icons.auto_stories_outlined,
                ),
                CodexMetricTile(
                  label: 'Fokus',
                  value: selectedHeroId == null ? 'Offen' : '1 gewählt',
                  icon: Icons.visibility_outlined,
                  highlight: selectedHeroId != null,
                ),
                CodexMetricTile(
                  label: 'Layout',
                  value: switch (layout) {
                    AppLayoutClass.compact => 'Mobil',
                    AppLayoutClass.tabletPortrait => 'iPad Portrait',
                    AppLayoutClass.tabletLandscape => 'iPad Landscape',
                    AppLayoutClass.desktopWide => 'Breit',
                  },
                  icon: Icons.tablet_mac_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: heroes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final hero = heroes[index];
                return _HeroArchiveTile(
                  hero: hero,
                  selected: selectedHeroId == hero.id,
                  showOpenAffordance: !layout.hasPersistentDetailPane,
                  onTap: () => onSelectHero(hero),
                  onExportHero: () => onExportHero(hero),
                  onDeleteHero: () => onDeleteHero(hero),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArchiveTile extends StatelessWidget {
  const _HeroArchiveTile({
    required this.hero,
    required this.selected,
    required this.showOpenAffordance,
    required this.onTap,
    required this.onExportHero,
    required this.onDeleteHero,
  });

  final HeroSheet hero;
  final bool selected;
  final bool showOpenAffordance;
  final VoidCallback onTap;
  final VoidCallback onExportHero;
  final VoidCallback onDeleteHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.secondaryContainer.withValues(
      alpha: 0.34,
    );

    return Card(
      color: selected ? selectedColor : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                child: Text(
                  heroInitials(hero.name),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hero.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      heroRoleText(hero),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CodexBadge(label: 'Stufe ${hero.level}'),
                        CodexBadge(
                          label: 'AP frei ${hero.apAvailable}',
                          tone: hero.apAvailable > 0
                              ? CodexBadgeTone.success
                              : CodexBadgeTone.neutral,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Held exportieren',
                    icon: const Icon(Icons.upload_file),
                    onPressed: onExportHero,
                  ),
                  IconButton(
                    tooltip: 'Held löschen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDeleteHero,
                  ),
                  if (showOpenAffordance) const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detailvorschau fuer den auf dem iPad ausgewaehlten Helden.
class HeroHomePreviewPanel extends StatelessWidget {
  /// Erstellt die ruhige Lesevorschau fuer einen einzelnen Helden.
  const HeroHomePreviewPanel({
    super.key,
    required this.hero,
    required this.onOpenWorkspace,
    required this.onExportHero,
    required this.onDeleteHero,
  });

  /// Angezeigter Held.
  final HeroSheet hero;

  /// Oeffnet den vollstaendigen Workspace.
  final VoidCallback onOpenWorkspace;

  /// Exportiert den Helden.
  final VoidCallback onExportHero;

  /// Loescht den Helden.
  final VoidCallback onDeleteHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        CodexSectionCard(
          title: hero.name,
          subtitle: heroRoleText(hero),
          trailing: FilledButton.icon(
            onPressed: onOpenWorkspace,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Held öffnen'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (hero.background.rasse.trim().isNotEmpty)
                    CodexBadge(label: hero.background.rasse),
                  if (hero.background.kultur.trim().isNotEmpty)
                    CodexBadge(label: hero.background.kultur),
                  if (hero.background.profession.trim().isNotEmpty)
                    CodexBadge(
                      label: hero.background.profession,
                      tone: CodexBadgeTone.accent,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  CodexMetricTile(
                    label: 'Stufe',
                    value: hero.level.toString(),
                    icon: Icons.workspace_premium_outlined,
                  ),
                  CodexMetricTile(
                    label: 'AP Gesamt',
                    value: hero.apTotal.toString(),
                    icon: Icons.auto_stories_outlined,
                  ),
                  CodexMetricTile(
                    label: 'AP frei',
                    value: hero.apAvailable.toString(),
                    icon: Icons.account_balance_wallet_outlined,
                    highlight: hero.apAvailable > 0,
                  ),
                  CodexMetricTile(
                    label: 'Sozialstatus',
                    value: hero.background.sozialstatus.toString(),
                    icon: Icons.account_balance_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Diese Vorschau dient auf dem iPad als ruhiger Lesezustand. Der vollständige digitale Heldenbogen bleibt einen Schritt tiefer im Workspace erreichbar.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CodexSectionCard(
          title: 'Aktionen',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onOpenWorkspace,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Im Workspace öffnen'),
              ),
              OutlinedButton.icon(
                onPressed: onExportHero,
                icon: const Icon(Icons.upload_file),
                label: const Text('Exportieren'),
              ),
              OutlinedButton.icon(
                onPressed: onDeleteHero,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Löschen'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Liefert die lesbare Rollen-/Herkunftslinie eines Helden.
String heroRoleText(HeroSheet hero) {
  final parts = <String>[
    if (hero.background.profession.trim().isNotEmpty)
      hero.background.profession.trim(),
    if (hero.background.kultur.trim().isNotEmpty) hero.background.kultur.trim(),
    if (hero.background.rasse.trim().isNotEmpty) hero.background.rasse.trim(),
  ];
  if (parts.isEmpty) {
    return 'Unbeschriebener Held';
  }
  return parts.join(' · ');
}

/// Reduziert einen Heldennamen auf zwei Initialen fuer Avatare.
String heroInitials(String name) {
  final initials = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part.substring(0, 1).toUpperCase())
      .join();
  return initials.isEmpty ? '?' : initials;
}
